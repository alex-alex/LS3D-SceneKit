//
//  Game.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

struct MissionTransitionCharacterState {
	let actorState: ActorState
	let humanEnergy: Float?
}

struct MissionTransitionWeaponState {
	let id: Int
	let clipAmmo: Int
	let restAmmo: Int
	let position: Weapon.Position

	init(_ weapon: Weapon) {
		id = weapon.id
		clipAmmo = weapon.clipAmmo
		restAmmo = weapon.restAmmo
		position = weapon.position
	}

	func makeWeapon() -> Weapon {
		let weapon = Weapon(id: id, clipAmmo: clipAmmo, restAmmo: restAmmo)
		weapon.position = position
		return weapon
	}
}

final class MissionTransitionState: @unchecked Sendable {
	private let lock = NSLock()
	private var characters: [Int: MissionTransitionCharacterState] = [:]
	private var inventories: [Int: [MissionTransitionWeaponState]] = [:]
	private var missionNumber = 0

	func pushCharacter(_ state: MissionTransitionCharacterState, actorId: Int) {
		lock.lock()
		defer { lock.unlock() }
		characters[actorId] = state
	}

	func character(actorId: Int) -> MissionTransitionCharacterState? {
		lock.lock()
		defer { lock.unlock() }
		return characters[actorId]
	}

	func pushInventory(_ weapons: [Weapon], actorId: Int) {
		let state = weapons.map(MissionTransitionWeaponState.init)
		lock.lock()
		defer { lock.unlock() }
		inventories[actorId] = state
	}

	func inventory(actorId: Int) -> [Weapon]? {
		lock.lock()
		defer { lock.unlock() }
		return inventories[actorId]?.map { $0.makeWeapon() }
	}

	func setMissionNumber(_ value: Int) {
		lock.lock()
		defer { lock.unlock() }
		missionNumber = value
	}

	func getMissionNumber() -> Int {
		lock.lock()
		defer { lock.unlock() }
		return missionNumber
	}

	func setMissionNumberIfDefault(_ value: Int) {
		lock.lock()
		defer { lock.unlock() }
		if missionNumber == 0 {
			missionNumber = value
		}
	}
}

final class Game: NSObject, @unchecked Sendable {

	enum SiderollDirection {
		case left
		case right
	}

	enum Mode {
		case walk, car, freeCamera
	}

	var hud: HudScene!
	var onMissionEnded: (@Sendable () -> Void)?
	var onMissionRestarted: (@Sendable () -> Void)?
	var onLoadGameRequested: (@Sendable () -> Void)?
	var onMissionChangeRequested: (@Sendable (_ folder: String, _ frameName: String, _ speed: CGFloat?, _ state: MissionTransitionState) -> Void)?

	let scnScene = SCNScene()
	let cameraContainer = SCNNode()
	let cameraNode = SCNNode()
	var isCutsceneCameraActive = false {
		didSet {
			guard oldValue != isCutsceneCameraActive else { return }
			if isCutsceneCameraActive {
				activeControls.remove(.FIRE)
				if lastControl == .FIRE {
					lastControl = nil
				}
				if activeBatChargeStartedAt != nil {
					cancelBatCharge()
				}
			}
			updateTrafficVisibility()
			updateCityMusicAvailability()
			setCutsceneOverlayVisible(isCutsceneCameraActive)
		}
	}
	var isCityTrafficVisible = true
	let ambientLightNode = SCNNode()

	var mode: Mode = .walk {
		didSet {
			if mode == .car && vehicle == nil {
				mode = .walk
				return
			}

			cameraContainer.removeFromParentNode()
			configureCamera(for: mode)
			if mode == .freeCamera {
				VehicleSoundLog.log("Game mode changed to freeCamera; vehicle audio inactive")
				scnScene.rootNode.addChildNode(cameraContainer)
				playerController?.stop()
				stopPlayerVehicleAnimation()
				vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
				vehicle?.applyForces()
				vehicle?.updateAudio(isActive: false)
			} else if mode == .walk {
				VehicleSoundLog.log("Game mode changed to walk; vehicle audio inactive")
				scene.playerNode?.isHidden = false
				scene.playerNode?.setHiddenInHierarchy(false)
				if oldValue != .freeCamera {
					teleportPlayerBesideVehicle()
				}
				if let playerNode = scene.playerNode {
					playerNode.addChildNode(cameraContainer)
				} else {
					scene.rootNode.addChildNode(cameraContainer)
				}
				playerController?.stop()
				stopPlayerVehicleAnimation()
				vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
				vehicle?.applyForces()
				vehicle?.updateAudio(isActive: false)
			} else {
				VehicleSoundLog.log("Game mode changed to car; vehicle audio active")
				didEnterCurrentVehicle = true
				playerController?.stop()
				movePlayerIntoVehicle()
				playPlayerVehicleSittingAnimation()
				if cameraContainer.parent !== scnScene.rootNode {
					scnScene.rootNode.addChildNode(cameraContainer)
				}
				resetCarCameraFollow()
				vehicle?.updateAudio(isActive: true)
			}
		}
	}

	let scene: Scene

	var vehicle: Vehicle?
	var playerController: PlayerController?
	var elevation: SCNFloat = 0
	var lastControl: Control?
	var playerHealth = 100
	var playerMaxEnergy: Float = 100
	var isPlayerInvincibleForTesting = true
	var activeControls: Set<Control> = []
	let pendingLookLock = NSLock()
	var pendingLookDeltaX: SCNFloat = 0
	var pendingLookDeltaY: SCNFloat = 0
	var arePlayerControlsLocked = false
	var isGamePaused = false
	let scriptStartTime = Date.timeIntervalSinceReferenceDate
	weak var renderView: SCNView?
	var lastUpdateTime: TimeInterval?
	var smoothedFramesPerSecond: CGFloat = 0
	let playerExitDistance: SCNFloat = 1.8
	let playerExitHeightOffset: SCNFloat = 0.5
	let walkCameraStandingHeight: SCNFloat = 1.35
	let walkCameraCrouchOffset: SCNFloat = 0.45
	var carCameraYaw: SCNFloat = 0
	var carCameraPitch: SCNFloat = 0
	var carCameraMouseIdleTime: TimeInterval = 0
	let carCameraMouseIdleDelay: TimeInterval = 0.65
	let carCameraReturnSpeed: SCNFloat = 3.5
	let carCameraMoveReturnThreshold: CGFloat = 2
	let minCarCameraPitch: SCNFloat = -0.45
	let maxCarCameraPitch: SCNFloat = 0.35
	let defaultCarCameraPitch: SCNFloat = -0.35
	let carCameraPosition = SCNVector3(x: 0, y: 4.4, z: -4.9)
	let carCameraForwardPitch: SCNFloat = 0.46
	let carCameraReverseSpeedThreshold: SCNFloat = 0.35
	let carCameraReverseLookSpeed: SCNFloat = 6
	let carCameraFollowSpeed: SCNFloat = 12
	let carCameraYawFollowSpeed: SCNFloat = 10
	var carCameraReverseYaw: SCNFloat = 0
	var smoothedCarCameraPosition: SCNVector3?
	var smoothedCarCameraYaw: SCNFloat?
	var walkCameraYaw: SCNFloat = 0
	var skyboxNodes: [(node: SCNNode, offset: SCNVector3)] = []
	let skyboxFallbackNode = SCNNode()
	var lastActionButtonUpdateTime: TimeInterval = 0
	var isActionButtonVisible = false
	var areCollisionWireframesVisible = false
	let actionButtonUpdateInterval: TimeInterval = 0.15
	let actionDistanceSquared: Float = 4
	let vehicleOwnerMatchDistanceSquared: Float = 36
	let vehicleStoppedSpeedThreshold: CGFloat = 1
	let playerVehicleDoorAnimationDuration: TimeInterval = 0.25
	var lastWeaponShotTime: TimeInterval = 0
	var reloadingWeaponUUID: NSUUID?
	var weaponReloadEndTime: TimeInterval = 0
	var didEndMission = false
	var hasEndedMission: Bool {
		return didEndMission
	}
	var activeBatChargeStartedAt: TimeInterval?
	let batChargeDuration: TimeInterval = 1.3
	let batRange: SCNFloat = 2.4
	let batMinImpulse: SCNFloat = 1.8
	let batMaxImpulse: SCNFloat = 18
	var batSwingAnimationIndex = 0
	var weaponAudioSources: [String: SCNAudioSource] = [:]
	var pauseMenuOpenSoundSource: SCNAudioSource?
	var pauseMenuChangeSoundSource: SCNAudioSource?
	var heldWeaponNode: SCNNode?
	var heldWeaponUUID: NSUUID?
	let heldWeaponNodeNamePrefix = "__held_weapon_"
	var npcLastAttackTimes: [ObjectIdentifier: TimeInterval] = [:]
	let npcDefaultAttackDistance: SCNFloat = 20
	let npcMeleeAttackDistance: SCNFloat = 2.2
	let npcMeleeDamage: SCNFloat = 5
	let npcMeleeInterval: TimeInterval = 0.9
	let npcMoveSpeed: SCNFloat = 2.2
	let npcGroundProbeLift: SCNFloat = 1.2
	let npcGroundProbeDrop: SCNFloat = 2.4
	let npcGroundProbeRadius: SCNFloat = 0.24
	let npcMaxStepUp: SCNFloat = 1.05
	let npcMaxStepDown: SCNFloat = 2.0
	let npcMinGroundNormalY: SCNFloat = 0.55
	let npcVerticalSteeringThreshold: SCNFloat = 0.65
	let npcSteeringLookAheadDistance: SCNFloat = 1.8
	let npcSteeringSideStepPenalty: SCNFloat = 0.12
	let npcSteeringAngles: [SCNFloat] = [
		0,
		SCNFloat.pi / 6,
		-SCNFloat.pi / 6,
		SCNFloat.pi / 3,
		-SCNFloat.pi / 3,
		SCNFloat.pi / 2,
		-SCNFloat.pi / 2
	]
	var playerFollowTrail: [SCNVector3] = []
	let playerFollowTrailMinDistance: SCNFloat = 0.85
	let playerFollowTrailMaxPoints = 90
	let npcFollowTrailVerticalThreshold: SCNFloat = 0.7
	let npcFollowTrailAttachDistance: SCNFloat = 12
	let npcFollowTrailAttachHeightTolerance: SCNFloat = 0.9
	let npcFollowTrailLookAheadPoints = 8
	let npcHumanNodeSnapshotLock = NSLock()
	var npcHumanNodeSnapshot: [SCNNode] = []
	var isNPCHumanNodeSnapshotUpdateScheduled = false
	var isNPCHealthLabelUpdateScheduled = false
	var npcHealthLabelNodes: [ObjectIdentifier: SCNNode] = [:]
	let npcHealthLabelNodeNamePrefix = "__npc_health_label_"
	let playerVehicleAnimationKey = "__player_vehicle__"
	var currentPlayerVehicleSittingAnimationName: String?
	var isPlayerVehicleTransitionActive = false
	var playerVehicleTransitionControlsWereLocked = false
	var modeBeforeFreeCamera: Mode = .walk
	var freeCameraPosition = SCNVector3Zero
	var freeCameraMovement = SCNVector3Zero
	var freeCameraYaw: SCNFloat = 0
	var freeCameraPitch: SCNFloat = 0
	let freeCameraSpeed: SCNFloat = 16
	let freeCameraFastSpeed: SCNFloat = 45
	let minFreeCameraPitch: SCNFloat = -.pi / 2 + 0.01
	let maxFreeCameraPitch: SCNFloat = .pi / 2 - 0.01
	let fogBlendSpeed: CGFloat = 0.4
	let ambientBlendSpeed: CGFloat = 0.9
	let outdoorAmbientPowerMultiplier: CGFloat = 3
	var stealEnabledVehicleIds: Set<Int> = []
	var stealVehicleNodes: [Int: SCNNode] = [:]
	var stolenVehicleIds: Set<Int> = []
	var stolenVehicleNodeIds: Set<ObjectIdentifier> = []
	var activeSteal: (vehicle: Vehicle, startedAt: TimeInterval)?
	var didEnterCurrentVehicle = false
	let vehicleStealDuration: TimeInterval = 1.6
	var playerPhysicsBodyBeforeVehicle: SCNPhysicsBody?
	var trafficManager: TrafficManager?
	var roadDebugNode: SCNNode?
	var roadMapBounds: RoadMapBounds?
	var environmentSectorNodes: [String: SCNNode] = [:]
	var missingEnvironmentSectorNames = Set<String>()
	var isCityMusicEnabled = true
	var cityMusicUpdateTimer: TimeInterval = -1
	var cityMusicStream: ScriptMusicStream?
	var cityMusicId: String?
	var cityMusicFadingStreams: [ScriptMusicStream] = []
	var cityMusicFadeCleanupItems: [UUID: DispatchWorkItem] = [:]
	let isMenuMission: Bool
	let saveGameCheckpoint: SaveGameCheckpoint?
	let transitionFrameName: String?
	let transitionVehicleSpeed: CGFloat?
	let missionTransitionState: MissionTransitionState

	init(
		missionName: String,
		saveGameCheckpoint: SaveGameCheckpoint? = nil,
		transitionFrameName: String? = nil,
		transitionVehicleSpeed: CGFloat? = nil,
		missionTransitionState: MissionTransitionState = MissionTransitionState(),
		progressHandler: ((CGFloat) -> Void)? = nil
	) throws {
		isMenuMission = missionName.lowercased() == "00menu"
		self.saveGameCheckpoint = saveGameCheckpoint
		self.transitionFrameName = transitionFrameName
		self.transitionVehicleSpeed = transitionVehicleSpeed
		self.missionTransitionState = missionTransitionState
		progressHandler?(0.05)
		scnScene.rootNode.name = "__root__"
		ambientLightNode.name = "__ambient_environment__"
		ambientLightNode.light = SCNLight()
		ambientLightNode.light?.type = .ambient
		ambientLightNode.light?.color = SKColor.black
		ambientLightNode.light?.intensity = 0
		scnScene.rootNode.addChildNode(ambientLightNode)
		scnScene.fogDensityExponent = 1

		let sceneModel = try loadModel(named: "missions/\(missionName)/scene")
		sceneModel.name = "__model__"
		scnScene.rootNode.addChildNode(sceneModel)
		print("== Loaded Scene Model")
		progressHandler?(0.25)

		scene = try Scene(named: "missions/"+missionName)
		progressHandler?(0.45)

		super.init()

		preloadMenuSounds()

		scene.game = self
		scene.rootNode.name = "__scene__"
		scnScene.rootNode.addChildNode(scene.rootNode)
		scene.resolvePendingDoors(in: scnScene.rootNode)
		scene.resolvePendingPhysicalObjects(in: scnScene.rootNode)
		scene.resolvePendingScripts(in: scnScene.rootNode)
		scene.resolvePendingObjectTypes(in: scnScene.rootNode)
		print("== Loaded Scene")
		progressHandler?(0.58)

		if let sceneCache = try SceneCache(name: "missions/"+missionName) {
			scnScene.rootNode.addChildNode(sceneCache.node)
			sceneCache.node.name = "__cache__"
			print("== Loaded Scene Cache")
		}
		progressHandler?(0.72)

		if let collisions = try? Collisions(name: "missions/"+missionName, scene: scnScene) {
			collisions.node.name = "__collisions__"
			scnScene.rootNode.addChildNode(collisions.node)
			print("== Loaded Scene Collisions")
		} else {
			print("== Skipped Scene Collisions")
		}
		progressHandler?(0.85)

			if let missionEffects = try? MissionEffects(name: "missions/"+missionName) {
			missionEffects.node.name = "__effects__"
			scnScene.rootNode.addChildNode(missionEffects.node)
			print("== Loaded Mission Effects")
		} else {
			print("== Skipped Mission Effects")
		}

		let road: Road? = (try? Road(name: "missions/"+missionName)) ?? nil
		if let road = road {
			roadMapBounds = RoadMapBounds(road: road)
			let debugNode = Game.roadDebugNode(for: road)
			debugNode.isHidden = true
			scnScene.rootNode.addChildNode(debugNode)
			roadDebugNode = debugNode
		}
		trafficManager = TrafficManager(road: road, trafficSettings: scene.trafficSettings, scene: scnScene)
		updateTrafficVisibility()
		if road != nil {
			print("== Loaded Road")
		}

//		let floorNode = SCNNode()
//		floorNode.opacity = 0
//		let floor = SCNFloor()
//		floor.reflectivity = 0
//		floorNode.geometry = floor
//		floorNode.physicsBody = SCNPhysicsBody.static()
//		scnScene.rootNode.addChildNode(floorNode)

		// -----

		if isMenuMission {
			scene.playerNode?.removeFromParentNode()
			scene.playerNode = nil
		} else if scene.playerNode == nil {
			print("== Player Node missing after scene resolve; spawning fallback")
			spawnPlayer()
		} else {
			let playerName = scene.playerNode?.name ?? "<unnamed>"
			let playerEnergy = scene.playerNode?.humanEnergy.map { "\($0)" } ?? "<nil>"
			print("== Player Node from mission: \(playerName), energy=\(playerEnergy)")
		}
		syncInitialPlayerHealthFromMission()

		if !isMenuMission, scene.playerNode != nil {
			PlayerController.preloadAnimations()
		}
		progressHandler?(0.88)

		// -----

		if let playerNode = scene.playerNode {
			let controller = PlayerController(node: playerNode, scene: scnScene)
			controller.movementAnimationSetProvider = { [weak self] in
				self?.equippedPlayerMovementAnimationSetId()
			}
			controller.setDebugVisualsVisible(areCollisionWireframesVisible)
			playerController = controller
		}

		// -----

		restoreSaveGameCheckpointIfNeeded()
		applyMissionTransition()

		// -----

		let camera = SCNCamera()
		camera.zFar = 650

		cameraNode.camera = camera
		cameraNode.scale = SCNVector3(x: 1, y: -1, z: 1)

		configureCamera(for: mode)
		cameraContainer.addChildNode(cameraNode)

		if mode == .walk {
			if let playerNode = scene.playerNode {
				playerNode.addChildNode(cameraContainer)
			} else {
				scene.rootNode.addChildNode(cameraContainer)
			}
		} else {
			scnScene.rootNode.addChildNode(cameraContainer)
			resetCarCameraFollow()
		}
		scene.playerNode?.isHidden = mode == .car
		configureSkyboxFallback()
		scnScene.rootNode.hideSkyboxBackdropGeometry()
		skyboxNodes = scnScene.rootNode.skyboxNodes(relativeTo: cameraNode.presentation.worldPosition)
		updateSkyboxPosition()
		progressHandler?(1)
	}

}
