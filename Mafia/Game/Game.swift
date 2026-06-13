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
	var onMissionChangeRequested: (@Sendable (_ folder: String, _ frameName: String, _ speed: CGFloat?) -> Void)?

	let scnScene = SCNScene()
	let cameraContainer = SCNNode()
	let cameraNode = SCNNode()
	var isCutsceneCameraActive = false {
		didSet {
			guard oldValue != isCutsceneCameraActive else { return }
			trafficManager?.isEnabled = !isCutsceneCameraActive
			setCutsceneOverlayVisible(isCutsceneCameraActive)
		}
	}
	private let ambientLightNode = SCNNode()

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
				scnScene.rootNode.addChildNode(cameraContainer)
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
	private var activeControls: Set<Control> = []
	private let pendingLookLock = NSLock()
	private var pendingLookDeltaX: SCNFloat = 0
	private var pendingLookDeltaY: SCNFloat = 0
	private(set) var arePlayerControlsLocked = false
	private(set) var isGamePaused = false
	let scriptStartTime = Date.timeIntervalSinceReferenceDate
	private weak var renderView: SCNView?
	private var lastUpdateTime: TimeInterval?
	private var smoothedFramesPerSecond: CGFloat = 0
	private let playerExitDistance: SCNFloat = 1.8
	private let playerExitHeightOffset: SCNFloat = 0.5
	private let walkCameraStandingHeight: SCNFloat = 1.35
	private let walkCameraCrouchOffset: SCNFloat = 0.45
	private var carCameraYaw: SCNFloat = 0
	private var carCameraPitch: SCNFloat = 0
	private var carCameraMouseIdleTime: TimeInterval = 0
	private let carCameraMouseIdleDelay: TimeInterval = 0.65
	private let carCameraReturnSpeed: SCNFloat = 3.5
	private let carCameraMoveReturnThreshold: CGFloat = 2
	private let minCarCameraPitch: SCNFloat = -0.45
	private let maxCarCameraPitch: SCNFloat = 0.35
	private let defaultCarCameraPitch: SCNFloat = -0.35
	private let carCameraPosition = SCNVector3(x: 0, y: 4.4, z: -4.9)
	private let carCameraForwardPitch: SCNFloat = 0.46
	private let carCameraReverseSpeedThreshold: SCNFloat = 0.35
	private let carCameraReverseLookSpeed: SCNFloat = 6
	private let carCameraFollowSpeed: SCNFloat = 12
	private let carCameraYawFollowSpeed: SCNFloat = 10
	private var carCameraReverseYaw: SCNFloat = 0
	private var smoothedCarCameraPosition: SCNVector3?
	private var smoothedCarCameraYaw: SCNFloat?
	private var walkCameraYaw: SCNFloat = 0
	private var skyboxNodes: [(node: SCNNode, offset: SCNVector3)] = []
	private let skyboxFallbackNode = SCNNode()
	private var lastActionButtonUpdateTime: TimeInterval = 0
	private var isActionButtonVisible = false
	private var areCollisionWireframesVisible = false
	private let actionButtonUpdateInterval: TimeInterval = 0.15
	private let actionDistanceSquared: Float = 4
	private let vehicleOwnerMatchDistanceSquared: Float = 36
	private let vehicleStoppedSpeedThreshold: CGFloat = 1
	private let playerVehicleDoorAnimationDuration: TimeInterval = 0.25
	private var lastWeaponShotTime: TimeInterval = 0
	private var reloadingWeaponUUID: NSUUID?
	private var weaponReloadEndTime: TimeInterval = 0
	private var didEndMission = false
	var hasEndedMission: Bool {
		return didEndMission
	}
	private var activeBatChargeStartedAt: TimeInterval?
	private let batChargeDuration: TimeInterval = 1.3
	private let batRange: SCNFloat = 2.4
	private let batMinImpulse: SCNFloat = 1.8
	private let batMaxImpulse: SCNFloat = 18
	private var batSwingAnimationIndex = 0
	private var weaponAudioSources: [String: SCNAudioSource] = [:]
	private var pauseMenuOpenSoundSource: SCNAudioSource?
	private var pauseMenuChangeSoundSource: SCNAudioSource?
	private var heldWeaponNode: SCNNode?
	private var heldWeaponUUID: NSUUID?
	private let heldWeaponNodeNamePrefix = "__held_weapon_"
	private var npcHealthLabelNodes: [ObjectIdentifier: SCNNode] = [:]
	private let npcHealthLabelNodeNamePrefix = "__npc_health_label_"
	private let playerVehicleAnimationKey = "__player_vehicle__"
	private var currentPlayerVehicleSittingAnimationName: String?
	private var isPlayerVehicleTransitionActive = false
	private var playerVehicleTransitionControlsWereLocked = false
	private var modeBeforeFreeCamera: Mode = .walk
	private var freeCameraPosition = SCNVector3Zero
	private var freeCameraMovement = SCNVector3Zero
	private var freeCameraYaw: SCNFloat = 0
	private var freeCameraPitch: SCNFloat = 0
	private let freeCameraSpeed: SCNFloat = 16
	private let freeCameraFastSpeed: SCNFloat = 45
	private let minFreeCameraPitch: SCNFloat = -.pi / 2 + 0.01
	private let maxFreeCameraPitch: SCNFloat = .pi / 2 - 0.01
	private let fogBlendSpeed: CGFloat = 0.4
	private let ambientBlendSpeed: CGFloat = 0.9
	private let outdoorAmbientPowerMultiplier: CGFloat = 3
	private var stealEnabledVehicleIds: Set<Int> = []
	private var stealVehicleNodes: [Int: SCNNode] = [:]
	private var stolenVehicleIds: Set<Int> = []
	private var stolenVehicleNodeIds: Set<ObjectIdentifier> = []
	private var activeSteal: (vehicle: Vehicle, startedAt: TimeInterval)?
	private var didEnterCurrentVehicle = false
	private let vehicleStealDuration: TimeInterval = 1.6
	private var playerPhysicsBodyBeforeVehicle: SCNPhysicsBody?
	private var trafficManager: TrafficManager?
	private var roadDebugNode: SCNNode?
	private var roadMapBounds: RoadMapBounds?
	private var environmentSectorNodes: [String: SCNNode] = [:]
	private var missingEnvironmentSectorNames = Set<String>()
	private let isMenuMission: Bool
	private let transitionFrameName: String?
	private let transitionVehicleSpeed: CGFloat?

	init(
		missionName: String,
		transitionFrameName: String? = nil,
		transitionVehicleSpeed: CGFloat? = nil,
		progressHandler: ((CGFloat) -> Void)? = nil
	) throws {
		isMenuMission = missionName.lowercased() == "00menu"
		self.transitionFrameName = transitionFrameName
		self.transitionVehicleSpeed = transitionVehicleSpeed
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
		trafficManager?.isEnabled = !isCutsceneCameraActive
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

	private func spawnPlayer() {
		guard let playerNode = try? loadModel(named: "models/tommy") else { return }

		if let spawnNode = playerSpawnNode() {
			playerNode.transform = spawnNode.worldTransform
		}
		playerNode.name = "tommy"
		playerNode.type = .player
		playerNode.humanEnergy = Float(playerHealth)
		scene.playerNode = playerNode
		scnScene.rootNode.addChildNode(playerNode)
		scene.registerNodeTree(playerNode)
	}

	private func syncInitialPlayerHealthFromMission() {
		guard let playerNode = scene.playerNode else { return }
		playerNode.type = .player
		if playerNode.humanEnergy == nil {
			playerNode.humanEnergy = Float(playerHealth)
		}
		guard let energy = playerNode.humanEnergy else { return }
		playerHealth = max(0, Int(round(energy)))
	}

	private func playerSpawnNode() -> SCNNode? {
		let preferredNames = [
			"emeth_1",
			"player",
			"tommy",
			"start",
			"player_start",
			"start_point"
		]
		for name in preferredNames {
			if let node = scnScene.rootNode.mafiaChildNode(named: name, recursively: true) {
				return node
			}
		}
		return scene.rootNode.childNodes.first
	}

	private func applyMissionTransition() {
		let trimmedFrameName = transitionFrameName?.trimmingCharacters(in: .whitespacesAndNewlines)
		let placementNode = trimmedFrameName.flatMap { frameName -> SCNNode? in
			guard !frameName.isEmpty else { return nil }
			return scene.node(named: frameName) ?? scnScene.rootNode.mafiaChildNode(named: frameName, recursively: true)
		}

		if let speed = transitionVehicleSpeed {
			if let transitionVehicle = vehicle ?? placementNode.flatMap({ scriptedVehicle(for: $0) }) {
				if let placementNode = placementNode {
					let transform = placementNode.presentation.worldTransform
					transitionVehicle.node.transform = transitionVehicle.node.parent?.convertTransform(transform, from: nil) ?? transform
				}
				mode = .car
				syncPlayerToVehicle()
				setVehicleSpeed(transitionVehicle, kilometersPerHour: speed)
				return
			}
		}

		if let placementNode = placementNode, let playerNode = scene.playerNode {
			let transform = placementNode.presentation.worldTransform
			playerNode.transform = playerNode.parent?.convertTransform(transform, from: nil) ?? transform
		}
	}

	private func setVehicleSpeed(_ vehicle: Vehicle, kilometersPerHour speed: CGFloat) {
		let metersPerSecond = SCNFloat(speed / 3.6)
		let forward = vehicle.node.presentation.worldFront.normalized
		let velocity = forward * metersPerSecond
		let chassisBody = vehicle.node.mafiaChildNode(named: "BODY", recursively: false)?.physicsBody
		(chassisBody ?? vehicle.node.physicsBody)?.velocity = velocity
	}

	private func configureCamera(for mode: Mode) {
		if mode == .car {
			guard let vehicle = vehicle else {
				configureCamera(for: .walk)
				return
			}
			cameraContainer.position = vehicle.node.presentation.worldPosition
			cameraNode.position = carCameraPosition
			cameraNode.eulerAngles = SCNVector3(x: carCameraForwardPitch, y: .pi, z: .pi)
			elevation = 0
			resetCarCameraLook()
		} else if mode == .walk {
			cameraContainer.position = SCNVector3(x: 0, y: walkCameraStandingHeight, z: 0)
			cameraContainer.eulerAngles = SCNVector3Zero
			cameraNode.position = SCNVector3(x: 0, y: 1.25, z: -2.8)
			cameraNode.eulerAngles = SCNVector3(x: 0.15, y: .pi, z: .pi)
			walkCameraYaw = 0
			elevation = 0
		} else {
			cameraContainer.position = freeCameraPosition
			cameraContainer.eulerAngles = SCNVector3(x: freeCameraPitch, y: freeCameraYaw, z: 0)
			cameraNode.position = SCNVector3Zero
			cameraNode.eulerAngles = SCNVector3(x: 0, y: .pi, z: .pi)
			elevation = freeCameraPitch
		}

		cameraContainer.eulerAngles.x = elevation
	}

	private func updateWalkCameraHeight(deltaTime: TimeInterval) {
		let targetHeight = walkCameraStandingHeight - (playerController?.isPlayerCrouching == true ? walkCameraCrouchOffset : 0)
		let blend = SCNFloat(min(1, max(0, deltaTime) * 12))
		cameraContainer.position.y += (targetHeight - cameraContainer.position.y) * blend
	}

	func look(deltaX: SCNFloat, deltaY: SCNFloat) {
		guard !isGamePaused, !isCutsceneCameraActive else { return }

		pendingLookLock.lock()
		pendingLookDeltaX += deltaX
		pendingLookDeltaY += deltaY
		pendingLookLock.unlock()
	}

	func clearPendingLook() {
		pendingLookLock.lock()
		pendingLookDeltaX = 0
		pendingLookDeltaY = 0
		pendingLookLock.unlock()
	}

	private func applyPendingLook() {
		let delta = consumePendingLook()
		guard delta.x != 0 || delta.y != 0 else { return }

		switch mode {
		case .walk:
			guard scene.playerNode != nil else { return }
			walkCameraYaw = normalizedAngle(walkCameraYaw - delta.x)
			playerController?.look(deltaX: 0, deltaY: delta.y)
			cameraContainer.eulerAngles.y = walkCameraYaw
		case .car:
			carCameraYaw = normalizedAngle(carCameraYaw - delta.x)
			carCameraPitch = max(minCarCameraPitch, min(maxCarCameraPitch, carCameraPitch + delta.y))
			carCameraMouseIdleTime = 0
			applyCarCameraLook()
		case .freeCamera:
			freeCameraYaw = normalizedAngle(freeCameraYaw - delta.x)
			freeCameraPitch = max(minFreeCameraPitch, min(maxFreeCameraPitch, freeCameraPitch + delta.y))
			cameraContainer.eulerAngles = SCNVector3(x: freeCameraPitch, y: freeCameraYaw, z: 0)
		}
	}

	private func consumePendingLook() -> (x: SCNFloat, y: SCNFloat) {
		pendingLookLock.lock()
		let delta = (x: pendingLookDeltaX, y: pendingLookDeltaY)
		pendingLookDeltaX = 0
		pendingLookDeltaY = 0
		pendingLookLock.unlock()
		return delta
	}

	func toggleFreeCamera() {
		if mode == .freeCamera {
			freeCameraMovement = SCNVector3Zero
			mode = modeBeforeFreeCamera
			return
		}

		modeBeforeFreeCamera = mode
		freeCameraPosition = cameraNode.presentation.worldPosition
		let forward = cameraNode.presentation.worldFront
		freeCameraYaw = atan2(-forward.x, -forward.z)
		freeCameraPitch = asin(max(-1, min(1, forward.y)))
		mode = .freeCamera
	}

	func setFreeCameraMovement(x: SCNFloat, y: SCNFloat, z: SCNFloat, isFast: Bool) {
		let length = sqrt(x * x + y * y + z * z)
		let speed = isFast ? freeCameraFastSpeed : freeCameraSpeed
		if length > 1 {
			freeCameraMovement = SCNVector3(x: x / length * speed, y: y / length * speed, z: z / length * speed)
		} else {
			freeCameraMovement = SCNVector3(x: x * speed, y: y * speed, z: z * speed)
		}
	}

	private func updateFreeCamera(deltaTime: TimeInterval) {
		let dt = SCNFloat(max(0, min(deltaTime, 1.0 / 20.0)))
		guard dt > 0 else { return }

		let transform = cameraContainer.presentation.worldTransform
		let right = SCNVector3(x: transform.m11, y: transform.m12, z: transform.m13)
		let up = SCNVector3(x: transform.m21, y: transform.m22, z: transform.m23)
		let forward = SCNVector3(x: -transform.m31, y: -transform.m32, z: -transform.m33)

		cameraContainer.position.x += (right.x * freeCameraMovement.x + up.x * freeCameraMovement.y + forward.x * freeCameraMovement.z) * dt
		cameraContainer.position.y += (right.y * freeCameraMovement.x + up.y * freeCameraMovement.y + forward.y * freeCameraMovement.z) * dt
		cameraContainer.position.z += (right.z * freeCameraMovement.x + up.z * freeCameraMovement.y + forward.z * freeCameraMovement.z) * dt
	}

	private func normalizedAngle(_ angle: SCNFloat) -> SCNFloat {
		var angle = angle
		let fullTurn = SCNFloat.pi * 2

		while angle > .pi {
			angle -= fullTurn
		}
		while angle < -.pi {
			angle += fullTurn
		}

		return angle
	}

	private func resetCarCameraLook() {
		carCameraYaw = 0
		carCameraPitch = defaultCarCameraPitch
		carCameraReverseYaw = 0
		carCameraMouseIdleTime = 0
	}

	private func resetCarCameraFollow() {
		guard let vehicle = vehicle else { return }

		let position = vehicle.node.presentation.worldPosition
		let yaw = vehicleYaw()

		smoothedCarCameraPosition = position
		smoothedCarCameraYaw = yaw
		applyCarCameraTransform(position: position, yaw: yaw)
	}

	private func updateCarCameraLook(deltaTime: TimeInterval) {
		guard let vehicle = vehicle else { return }

		carCameraMouseIdleTime += deltaTime
		let dt = SCNFloat(max(0, min(deltaTime, 1.0 / 20.0)))
		let reverseTargetYaw = vehicleLongitudinalSpeed() > carCameraReverseSpeedThreshold ? SCNFloat.pi : 0
		let reverseBlend = min(1, carCameraReverseLookSpeed * dt)
		carCameraReverseYaw = normalizedAngle(carCameraReverseYaw + normalizedAngle(reverseTargetYaw - carCameraReverseYaw) * reverseBlend)

		if vehicle.speed > carCameraMoveReturnThreshold,
		   carCameraMouseIdleTime >= carCameraMouseIdleDelay {
			let blend = min(1, carCameraReturnSpeed * dt)
			carCameraYaw += (0 - carCameraYaw) * blend
			carCameraPitch += (defaultCarCameraPitch - carCameraPitch) * blend
		}

		applyCarCameraLook()
	}

	private func applyCarCameraLook() {
		guard let vehicle = vehicle else { return }

		let position = smoothedCarCameraPosition ?? vehicle.node.presentation.worldPosition
		let yaw = smoothedCarCameraYaw ?? vehicleYaw()
		applyCarCameraTransform(position: position, yaw: yaw)
	}

	private func updateCarCameraFollow(deltaTime: TimeInterval) {
		guard let vehicle = vehicle else { return }

		let targetPosition = vehicle.node.presentation.worldPosition
		let targetYaw = vehicleYaw()
		let dt = SCNFloat(max(0, min(deltaTime, 1.0 / 20.0)))
		let positionBlend = min(1, carCameraFollowSpeed * dt)
		let yawBlend = min(1, carCameraYawFollowSpeed * dt)

		let currentPosition = smoothedCarCameraPosition ?? targetPosition
		let currentYaw = smoothedCarCameraYaw ?? targetYaw
		let smoothedPosition = SCNVector3(
			x: currentPosition.x + (targetPosition.x - currentPosition.x) * positionBlend,
			y: currentPosition.y + (targetPosition.y - currentPosition.y) * positionBlend,
			z: currentPosition.z + (targetPosition.z - currentPosition.z) * positionBlend
		)
		let smoothedYaw = normalizedAngle(currentYaw + normalizedAngle(targetYaw - currentYaw) * yawBlend)

		smoothedCarCameraPosition = smoothedPosition
		smoothedCarCameraYaw = smoothedYaw
		applyCarCameraTransform(position: smoothedPosition, yaw: smoothedYaw)
	}

	private func applyCarCameraTransform(position: SCNVector3, yaw: SCNFloat) {
		cameraContainer.position = position
		cameraContainer.eulerAngles = SCNVector3(
			x: carCameraPitch,
			y: yaw + carCameraYaw + carCameraReverseYaw,
			z: 0
		)
	}

	private func vehicleYaw() -> SCNFloat {
		guard let vehicle = vehicle else { return 0 }

		let forward = vehicle.node.presentation.worldFront
		return atan2(-forward.x, -forward.z)
	}

	private func vehicleLongitudinalSpeed() -> SCNFloat {
		guard let vehicle = vehicle else { return 0 }
		let velocity = vehicle.velocity

		let forward = vehicle.node.presentation.worldFront
		return velocity.x * forward.x + velocity.z * forward.z
	}

	private func updateSkyboxPosition() {
		let cameraPosition = cameraNode.presentation.worldPosition
		for skyboxNode in skyboxNodes {
			let position = cameraPosition + skyboxNode.offset
			skyboxNode.node.position = skyboxNode.node.parent?.convertPosition(position, from: nil) ?? position
		}
		skyboxFallbackNode.position = cameraPosition
	}

	private func updateEnvironment(deltaTime: TimeInterval) {
		let cameraPosition = cameraNode.presentation.worldPosition
		let frameTime = CGFloat(max(0, deltaTime))
		let ambientBlend = min(1, frameTime * ambientBlendSpeed)
		let fogBlend = min(1, frameTime * fogBlendSpeed)

		if let ambient = scene.environmentLights.bestMatch(
			kind: .ambient,
			cameraPosition: cameraPosition,
			rootNode: scnScene.rootNode,
			sectorNodes: &environmentSectorNodes,
			missingSectorNames: &missingEnvironmentSectorNames
		) {
			let ambientPower = ambient.power * (ambient.isOutdoorLight ? outdoorAmbientPowerMultiplier : 1)
			let targetColor = ambient.color.multiplied(by: ambientPower)
			ambientLightNode.light?.color = (ambientLightNode.light?.color as? SKColor ?? .black).lerped(to: targetColor, amount: ambientBlend)
			ambientLightNode.light?.intensity = 100
		}

		if let fog = scene.environmentLights.bestMatch(
			kind: .fog,
			cameraPosition: cameraPosition,
			rootNode: scnScene.rootNode,
			sectorNodes: &environmentSectorNodes,
			missingSectorNames: &missingEnvironmentSectorNames
		) {
			let targetColor = fog.color.multiplied(by: fog.power)
			scnScene.fogColor = (scnScene.fogColor as? SKColor ?? .clear).lerped(to: targetColor, amount: fogBlend)
			scnScene.fogStartDistance += (fog.near * 1000 - scnScene.fogStartDistance) * fogBlend
			scnScene.fogEndDistance += (fog.far * 50 - scnScene.fogEndDistance) * fogBlend
		}
	}

	private func configureSkyboxFallback() {
		let textureSet = scnScene.rootNode.skyboxTextureSet() ?? "sky 7"
		let box = SCNBox(width: 600, height: 600, length: 600, chamferRadius: 0)
		let sideMaterials = [
			skyboxMaterial(named: "\(textureSet) 1.bmp"),
			skyboxMaterial(named: "\(textureSet) 2.bmp"),
			skyboxMaterial(named: "\(textureSet) 3.bmp"),
			skyboxMaterial(named: "\(textureSet) 4.bmp")
		]
		let topMaterial = skyboxMaterial(named: "\(textureSet) 5.bmp")
		box.materials = [
			sideMaterials[0],
			sideMaterials[1],
			sideMaterials[2],
			sideMaterials[3],
			topMaterial,
			topMaterial
		]

		skyboxFallbackNode.name = "__skybox_fallback__"
		skyboxFallbackNode.geometry = box
		skyboxFallbackNode.renderingOrder = -1000
		scnScene.rootNode.addChildNode(skyboxFallbackNode)
	}

	private func skyboxMaterial(named textureName: String) -> SCNMaterial {
		let material = SCNMaterial()
		material.lightingModel = .constant
		material.diffuse.contents = loadMapImage(named: textureName)
		material.diffuse.mipFilter = .linear
		material.diffuse.minificationFilter = .linear
		material.diffuse.magnificationFilter = .linear
		material.cullMode = .back
		material.isDoubleSided = true
		material.readsFromDepthBuffer = false
		material.writesToDepthBuffer = false
		return material
	}

	private func teleportPlayerBesideVehicle() {
		guard let playerController = playerController,
			  let vehicle = vehicle else { return }

		let exit = playerExitPlacement(for: vehicle)
		if let playerNode = scene.playerNode {
			if playerNode.parent !== scene.rootNode {
				scene.rootNode.addChildNode(playerNode)
			}
			if playerNode.physicsBody == nil,
			   let playerPhysicsBodyBeforeVehicle = playerPhysicsBodyBeforeVehicle {
				playerNode.physicsBody = playerPhysicsBodyBeforeVehicle
				self.playerPhysicsBodyBeforeVehicle = nil
			}
			clearPlayerVehicleOwner(for: playerNode)
			playerNode.isHidden = false
			playerNode.setHiddenInHierarchy(false)
		}

		playerController.teleport(to: exit.position, yaw: exit.yaw)
	}

	func preservePlayerPhysicsBodyForVehicleEntry(_ playerNode: SCNNode) {
		guard playerPhysicsBodyBeforeVehicle == nil else { return }
		playerPhysicsBodyBeforeVehicle = playerNode.physicsBody
	}

	private func clearPlayerVehicleOwner(for playerNode: SCNNode) {
		scene.humanVehicleOwners[ObjectIdentifier(playerNode)] = nil
	}

	private func playerExitPlacement(for vehicle: Vehicle) -> (position: SCNVector3, yaw: SCNFloat) {
		let vehiclePosition = vehicle.node.presentation.worldPosition
		let vehicleRight = horizontalVehicleRight()
		let exitSide = SCNVector3(x: -vehicleRight.x, y: 0, z: -vehicleRight.z)
		let exitPosition = SCNVector3(
			x: vehiclePosition.x + exitSide.x * playerExitDistance,
			y: vehicleBottomWorldY() + playerExitHeightOffset,
			z: vehiclePosition.z + exitSide.z * playerExitDistance
		)
		let forward = vehicle.node.presentation.worldFront
		return (exitPosition, atan2(-forward.x, -forward.z))
	}

	private func movePlayerIntoVehicle() {
		guard let playerNode = scene.playerNode,
			  let vehicle = vehicle else { return }

		if playerPhysicsBodyBeforeVehicle == nil {
			playerPhysicsBodyBeforeVehicle = playerNode.physicsBody
		}
		playerNode.disablePhysicsInHierarchy()

		let seatPosition = playerSeatPosition(in: vehicle.node)
		vehicle.node.addChildNode(playerNode)
		playerNode.position = seatPosition
		let yaw = vehicleYaw()
		if let playerController = playerController {
			playerController.face(worldYaw: yaw)
		} else {
			playerNode.eulerAngles = SCNVector3Zero
		}
		playerNode.isHidden = false
		playerNode.setHiddenInHierarchy(false)
	}

	private func syncPlayerToVehicle() {
		guard let playerNode = scene.playerNode,
			  let vehicle = vehicle else { return }

		if playerNode.parent !== vehicle.node {
			vehicle.node.addChildNode(playerNode)
		}
		playerNode.position = playerSeatPosition(in: vehicle.node)
		playerNode.isHidden = false
		playerNode.setHiddenInHierarchy(false)
	}

	private func enterVehicleWithAnimation(_ targetVehicle: Vehicle) {
		guard !isPlayerVehicleTransitionActive else { return }

		vehicle = targetVehicle
		guard let playerNode = scene.playerNode,
			  mode == .walk else {
			mode = .car
			return
		}

		playerController?.stop()
		isPlayerVehicleTransitionActive = true
		playerVehicleTransitionControlsWereLocked = arePlayerControlsLocked
		arePlayerControlsLocked = true
		let doorVehicleNode = targetVehicle.scriptNode
		setCarDoorOpen(doorVehicleNode, doorId: 0, percentage: 100, duration: playerVehicleDoorAnimationDuration)
		let finish: @Sendable () -> Void = { [weak self] in
			guard let self = self else { return }
			self.isPlayerVehicleTransitionActive = false
			self.arePlayerControlsLocked = self.playerVehicleTransitionControlsWereLocked
			self.mode = .car
			setCarDoorOpen(doorVehicleNode, doorId: 0, percentage: 0, duration: self.playerVehicleDoorAnimationDuration)
		}

		guard let animationName = vehicleEnterAnimationName() else {
			finish()
			return
		}
		playPlayerVehicleAnimation(named: animationName, in: playerNode, repeat: false, completionHandler: finish)
	}

	private func exitVehicleWithAnimation() {
		guard !isPlayerVehicleTransitionActive,
			  mode == .car else { return }

		isPlayerVehicleTransitionActive = true
		playerVehicleTransitionControlsWereLocked = arePlayerControlsLocked
		arePlayerControlsLocked = true
		stopPlayerVehicleAnimation()
		if let vehicle = vehicle {
			setCarDoorOpen(vehicle.scriptNode, doorId: 0, percentage: 100, duration: playerVehicleDoorAnimationDuration)
		}

		guard let playerNode = scene.playerNode,
			  let animationName = vehicleExitAnimationName() else {
			isPlayerVehicleTransitionActive = false
			arePlayerControlsLocked = playerVehicleTransitionControlsWereLocked
			if let vehicle = vehicle {
				setCarDoorOpen(vehicle.scriptNode, doorId: 0, percentage: 0, duration: playerVehicleDoorAnimationDuration)
			}
			return
		}

		playPlayerVehicleAnimation(named: animationName, in: playerNode, repeat: false) { [weak self] in
			guard let self = self else { return }
			self.isPlayerVehicleTransitionActive = false
			self.arePlayerControlsLocked = self.playerVehicleTransitionControlsWereLocked
			self.mode = .walk
			if let vehicle = self.vehicle {
				setCarDoorOpen(vehicle.scriptNode, doorId: 0, percentage: 0, duration: self.playerVehicleDoorAnimationDuration)
			}
		}
	}

	private func playPlayerVehicleSittingAnimation() {
		guard let playerNode = scene.playerNode,
			  let animationName = vehicleSittingAnimationName() else { return }
		currentPlayerVehicleSittingAnimationName = animationName
		playPlayerVehicleAnimation(named: animationName, in: playerNode, repeat: true)
	}

	private func updatePlayerVehicleSittingAnimation() {
		guard let animationName = vehicleSittingAnimationName(),
			  animationName != currentPlayerVehicleSittingAnimationName else { return }
		playPlayerVehicleSittingAnimation()
	}

	private func playPlayerVehicleAnimation(
		named animationName: String,
		in playerNode: SCNNode,
		repeat shouldRepeat: Bool,
		completionHandler: (@Sendable () -> Void)? = nil
	) {
		do {
			try playPlayerAnimation(
				named: animationName,
				in: playerNode,
				repeat: shouldRepeat,
				animationKey: playerVehicleAnimationKey,
				completionHandler: completionHandler
			)
		} catch {
			completionHandler?()
		}
	}

	private func stopPlayerVehicleAnimation() {
		guard let playerNode = scene.playerNode else { return }
		currentPlayerVehicleSittingAnimationName = nil
		playerNode.removeAction(forKey: playerVehicleAnimationKey)
		playerNode.removeAction(forKey: playerVehicleAnimationKey + ":position")
	}

	private func vehicleEnterAnimationName() -> String? {
		return firstExistingAnimation(named: [
			"anims/AutoSmNas FL.5ds",
			"anims/AutoBigNas FL.5ds"
		])
	}

	private func vehicleExitAnimationName() -> String? {
		return firstExistingAnimation(named: [
			"anims/AutoSmVys FL.5ds",
			"anims/AutoBigVys FL.5ds"
		])
	}

	private func vehicleSittingAnimationName() -> String? {
		if vehicle?.isSteeringWheelTurning == true {
			return firstExistingAnimation(named: [
				"anims/AutoRidicVolant.5ds",
				"anims/AutoRidicStativ.5ds"
			])
		}
		return firstExistingAnimation(named: [
			"anims/AutoRidicStativ.5ds",
			"anims/AutoRidicVolant.5ds"
		])
	}

	private func playerSeatPosition(in body: SCNNode) -> SCNVector3 {
		let bounds = body.boundingBox
		let width = bounds.max.x - bounds.min.x
		let height = bounds.max.y - bounds.min.y
		let length = bounds.max.z - bounds.min.z
		return SCNVector3(
			x: (bounds.min.x + bounds.max.x) / 2 - width * 0.12,
			y: bounds.min.y + height * 0.24,
			z: (bounds.min.z + bounds.max.z) / 2 - length * 0.12
		)
	}

	private func horizontalVehicleRight() -> SCNVector3 {
		guard let vehicle = vehicle else { return SCNVector3(x: 1, y: 0, z: 0) }

		let transform = vehicle.node.presentation.worldTransform
		let right = SCNVector3(x: transform.m11, y: 0, z: transform.m13)
		let length = sqrt(right.x * right.x + right.z * right.z)
		guard length > 0.0001 else { return SCNVector3(x: 1, y: 0, z: 0) }

		return SCNVector3(x: right.x / length, y: 0, z: right.z / length)
	}

	private func vehicleBottomWorldY() -> SCNFloat {
		guard let vehicle = vehicle else { return 0 }

		let bounds = vehicle.node.boundingBox
		let xs = [bounds.min.x, bounds.max.x]
		let ys = [bounds.min.y, bounds.max.y]
		let zs = [bounds.min.z, bounds.max.z]
		var bottom = SCNFloat.greatestFiniteMagnitude

		for x in xs {
			for y in ys {
				for z in zs {
					let point = vehicle.node.presentation.convertPosition(SCNVector3(x: x, y: y, z: z), to: nil)
					bottom = min(bottom, point.y)
				}
			}
		}

		return bottom
	}

	private func updateActionButtonVisibility(at time: TimeInterval) {
		guard time - lastActionButtonUpdateTime >= actionButtonUpdateInterval else { return }
		guard mode == .walk || mode == .car else {
			setActionButtonVisible(false)
			return
		}

		if mode == .car {
			lastActionButtonUpdateTime = time
			setActionButtonVisible(nearestAction()?.isEnabled == true)
			return
		}

		guard let playerNode = scene.playerNode else {
			if mode != .walk {
				setActionButtonVisible(false)
			}
			return
		}

		lastActionButtonUpdateTime = time
		let playerPosition = playerNode.presentation.worldPosition
		var actions = scene.actions
		if let stealAction = stealableVehicleAction() {
			actions.append(stealAction)
		} else if let enterAction = enterableVehicleAction() {
			actions.append(enterAction)
		}
		let hasNearbyAction = actions.contains { action in
			action.isEnabled &&
				action.node.actionSquaredDistance(to: playerPosition) < actionDistanceSquared
		}
		setActionButtonVisible(hasNearbyAction)
	}

	private func setActionButtonVisible(_ isVisible: Bool) {
		guard isActionButtonVisible != isVisible else { return }

		isActionButtonVisible = isVisible
		updateHud { hud in
			hud.setActionButtonVisible(isVisible)
		}
	}

	private func beginVehicleSteal(_ vehicle: Vehicle) {
		guard mode == .walk,
			  activeSteal == nil,
			  !isStolenVehicle(vehicle) else { return }

		activeSteal = (vehicle, Date.timeIntervalSinceReferenceDate)
		updateHud { hud in
			hud.showConsoleText("Stealing car...")
		}
	}

	private func updateVehicleStealing() {
		guard let steal = activeSteal else {
			updateHud { hud in
				hud.updateVehicleStealProgress(0, isVisible: false)
			}
			return
		}

		let elapsed = Date.timeIntervalSinceReferenceDate - steal.startedAt
		updateHud { hud in
			hud.updateVehicleStealProgress(CGFloat(elapsed / self.vehicleStealDuration), isVisible: true)
		}

		guard isControlPressed(.ACTION),
			  mode == .walk,
			  let playerNode = scene.playerNode,
			  steal.vehicle.node.actionSquaredDistance(to: playerNode.presentation.worldPosition) < actionDistanceSquared else {
			activeSteal = nil
			updateHud { hud in
				hud.updateVehicleStealProgress(0, isVisible: false)
			}
			return
		}

		guard elapsed >= vehicleStealDuration else { return }

		if let carId = vehicleStealId(for: steal.vehicle) {
			stolenVehicleIds.insert(carId)
		}
		markVehicleStolen(steal.vehicle)
		activeSteal = nil
		updateHud { hud in
			hud.updateVehicleStealProgress(1, isVisible: false)
		}
		vehicle = steal.vehicle
		updateHud { hud in
			hud.showConsoleText("Car stolen")
		}
	}

	private func vehicleStealId(for vehicle: Vehicle) -> Int? {
		for carId in stealEnabledVehicleIds {
			if let carNode = stealVehicleNodes[carId],
			   isVehicle(vehicle, matching: carNode),
			   !stolenVehicleIds.contains(carId) {
				return carId
			}
		}
		return nil
	}

	private func vehicleStealId(for node: SCNNode) -> Int? {
		for carId in stealEnabledVehicleIds {
			guard let carNode = stealVehicleNodes[carId],
				  !stolenVehicleIds.contains(carId) else { continue }

			let hasMatchingName = carNode.name != nil && carNode.name == node.name
			if carNode === node || hasMatchingName || isNode(node, inside: carNode) || isNode(carNode, inside: node) {
				return carId
			}
		}
		return nil
	}

	private func markVehicleStolen(_ vehicle: Vehicle) {
		stolenVehicleNodeIds.insert(ObjectIdentifier(vehicle.node))
		stolenVehicleNodeIds.insert(ObjectIdentifier(vehicle.scriptNode))
	}

	private func isStolenVehicle(_ vehicle: Vehicle) -> Bool {
		if vehicleStealId(for: vehicle) != nil {
			return false
		}
		return stolenVehicleNodeIds.contains(ObjectIdentifier(vehicle.node)) ||
			stolenVehicleNodeIds.contains(ObjectIdentifier(vehicle.scriptNode))
	}

	private func stealableVehicleAction() -> Action? {
		guard let vehicle = nearestScriptedStealableVehicle() else { return nil }
		return .vehicleSteal(vehicle)
	}

	private func enterableVehicleAction() -> Action? {
		guard let vehicle = nearestScriptedEnterableVehicle() else { return nil }
		return .vehicleEnter(vehicle)
	}

	private func vehicleExitAction() -> Action? {
		guard mode == .car,
			  let vehicle = vehicle,
			  scriptedVehicleActions(for: vehicle).isEmpty,
			  vehicle.speed <= vehicleStoppedSpeedThreshold else { return nil }

		return .vehicleExit(vehicle)
	}

	private func scriptedVehicleActions(for vehicle: Vehicle) -> [Action] {
		let vehiclePosition = vehicle.node.presentation.worldPosition
		return scene.actions
			.filter { action in
				if case .action = action {
					return action.isEnabled && action.node.actionSquaredDistance(to: vehiclePosition) < actionDistanceSquared
				}
				return false
			}
			.sorted { lhs, rhs in
				lhs.node.actionSquaredDistance(to: vehiclePosition) < rhs.node.actionSquaredDistance(to: vehiclePosition)
			}
	}

	private func isVehicle(_ vehicle: Vehicle, matching node: SCNNode) -> Bool {
		return vehicle.node === node ||
			vehicle.scriptNode === node ||
			vehicle.node.name == node.name ||
			vehicle.scriptNode.name == node.name ||
			isNode(vehicle.node, inside: node) ||
			isNode(node, inside: vehicle.scriptNode)
	}

	private func scriptedVehicle(for node: SCNNode) -> Vehicle? {
		if let vehicle = vehicle,
		   isVehicle(vehicle, matching: node) {
			return vehicle
		}

		if let vehicle = vehicle {
			vehicle.updateAudio(isActive: false)
			scnScene.physicsWorld.removeBehavior(vehicle.physicsVehicle)
		}
		guard let scriptedVehicle = Vehicle(scene: scnScene, node: node) else { return nil }
		vehicle = scriptedVehicle
		didEnterCurrentVehicle = false
		return scriptedVehicle
	}

	private func nearestScriptedStealableVehicle() -> Vehicle? {
		guard mode == .walk,
			  let playerNode = scene.playerNode else { return nil }

		let playerPosition = playerNode.presentation.worldPosition
		return stealableVehicleNodes()
			.compactMap { node -> (node: SCNNode, distance: Float)? in
				guard node.actionsEnabledInHierarchy,
					  !isNodeHiddenInHierarchy(node),
					  !isCurrentVehicleNode(node),
					  !isStolenVehicleNode(node) else { return nil }
				return (node, node.actionSquaredDistance(to: playerPosition))
			}
			.filter { $0.distance < actionDistanceSquared }
			.min { $0.distance < $1.distance }
			.flatMap { scriptedVehicle(for: $0.node) }
	}

	private func stealableVehicleNodes() -> [SCNNode] {
		var nodes: [SCNNode] = []
		nodes.append(contentsOf: stealVehicleNodes.values)
		nodes.append(contentsOf: trafficManager?.placedVehicleNodes ?? [])
		scene.rootNode.enumerateChildNodes { node, _ in
			if node.type == .car || node.trafficCarDefinition != nil {
				nodes.append(node)
			}
		}
		var seen = Set<ObjectIdentifier>()
		return nodes.filter { node in
			let id = ObjectIdentifier(node)
			guard !seen.contains(id) else { return false }
			seen.insert(id)
			return true
		}
	}

	private func isCurrentVehicleNode(_ node: SCNNode) -> Bool {
		guard didEnterCurrentVehicle,
			  let vehicle = vehicle else { return false }
		return isVehicle(vehicle, matching: node)
	}

	private func isStolenVehicleNode(_ node: SCNNode) -> Bool {
		if stolenVehicleNodeIds.contains(ObjectIdentifier(node)) {
			return true
		}
		for carId in stolenVehicleIds {
			if let stolenNode = stealVehicleNodes[carId],
			   stolenNode === node || stolenNode.name == node.name || isNode(node, inside: stolenNode) || isNode(stolenNode, inside: node) {
				return true
			}
		}
		return false
	}

	private func nearestScriptedEnterableVehicle() -> Vehicle? {
		guard mode == .walk,
			  let playerNode = scene.playerNode else { return nil }

		let playerPosition = playerNode.presentation.worldPosition
		if let vehicle = vehicle,
		   canEnterCurrentVehicle(),
		   vehicle.node.actionSquaredDistance(to: playerPosition) < actionDistanceSquared {
			return vehicle
		}

		return stealableVehicleNodes()
			.compactMap { node -> (node: SCNNode, distance: Float)? in
				guard node.actionsEnabledInHierarchy,
					  !isNodeHiddenInHierarchy(node),
					  vehicleStealId(for: node) == nil else { return nil }
				return (node, node.actionSquaredDistance(to: playerPosition))
			}
			.filter { $0.distance < actionDistanceSquared }
			.min { $0.distance < $1.distance }
			.flatMap { scriptedVehicle(for: $0.node) }
	}

	func enterScriptedVehicle(_ node: SCNNode) {
		if scriptedVehicle(for: node) != nil {
			mode = .car
		}
	}

	@MainActor func setup(in view: SCNView) {
		renderView = view
		setRenderLoopActive(true)
		hud = HudScene(size: view.bounds.size, game: self)
		view.scene = scnScene
		view.overlaySKScene = hud
		view.delegate = self
		view.pointOfView = cameraNode
		if let playerNode = scene.playerNode {
			view.audioListener = playerNode
		} else {
			view.audioListener = cameraContainer
		}
		refreshPlayerStatusHud()
		scene.startScripts()
	}

	@MainActor func tearDown(from view: SCNView) {
		let tearDownStartTime = CFAbsoluteTimeGetCurrent()
		var lastStepTime = tearDownStartTime
		func logTearDownStep(_ name: String) {
			let now = CFAbsoluteTimeGetCurrent()
			print(String(format: "== Game tearDown %@ %.3fs total %.3fs", name, now - lastStepTime, now - tearDownStartTime))
			lastStepTime = now
		}

		let oldHud = hud
		if view.scene === scnScene {
			view.scene = SCNScene()
		}
		if view.overlaySKScene === oldHud {
			view.overlaySKScene = nil
		}
		view.delegate = nil
		view.pointOfView = nil
		view.audioListener = nil
		view.isPlaying = false
		view.rendersContinuously = false
		logTearDownStep("detach view")
		onMissionEnded = nil
		onMissionRestarted = nil
		onLoadGameRequested = nil
		onMissionChangeRequested = nil
		didEndMission = true
		isGamePaused = true
		scnScene.isPaused = true
		clearPendingLook()
		lastUpdateTime = nil
		playerController?.stop()
		vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
		vehicle?.updateAudio(isActive: false)
		logTearDownStep("stop controllers")
		scene.tearDown()
		logTearDownStep("scene")
		oldHud?.removeAllActions()
		oldHud?.removeAllChildren()
		cameraContainer.removeFromParentNode()
		hud = nil
		renderView = nil
		logTearDownStep("hud")
	}

	func restoreGameplayCamera() {
		cameraContainer.removeFromParentNode()
		configureCamera(for: mode)
		if mode == .walk, let playerNode = scene.playerNode {
			playerNode.addChildNode(cameraContainer)
		} else if mode == .walk {
			scene.rootNode.addChildNode(cameraContainer)
		} else {
			scnScene.rootNode.addChildNode(cameraContainer)
			if mode == .car {
				resetCarCameraFollow()
			}
		}
	}

	private func updateHud(_ update: @escaping @MainActor @Sendable (HudScene) -> Void) {
		guard let hud = hud else { return }
		Task { @MainActor in
			update(hud)
		}
	}

	func showScriptTimer(scriptId: NSUUID, remainingMilliseconds: Float) {
		updateHud { hud in
			hud.showScriptTimer(scriptId: scriptId, remainingMilliseconds: remainingMilliseconds)
		}
	}

	func updateScriptTimer(scriptId: NSUUID, remainingMilliseconds: Float) {
		updateHud { hud in
			hud.updateScriptTimer(scriptId: scriptId, remainingMilliseconds: remainingMilliseconds)
		}
	}

	func hideScriptTimer(scriptId: NSUUID) {
		updateHud { hud in
			hud.hideScriptTimer(scriptId: scriptId)
		}
	}

	func setCutsceneOverlayVisible(_ isVisible: Bool) {
		updateHud { hud in
			hud.setCutsceneOverlayVisible(isVisible)
			if !isVisible {
				hud.setActionButtonVisible(self.isActionButtonVisible)
			}
		}
	}

	func setLoadBlackoutVisible(_ isVisible: Bool) {
		updateHud { hud in
			hud.setLoadBlackoutVisible(isVisible)
		}
	}

	func setScriptBlackoutVisible(_ isVisible: Bool, immediate: Bool) {
		updateHud { hud in
			hud.setScriptBlackoutVisible(isVisible, immediate: immediate)
		}
	}

	func showSubtitleText(_ text: String, duration: TimeInterval = 4) {
		updateHud { hud in
			hud.showSubtitleText(text, duration: duration)
		}
	}

	func showCutsceneSubtitleText(_ text: String, duration: TimeInterval = 4) {
		updateHud { hud in
			hud.showCutsceneSubtitleText(text, duration: duration)
		}
	}

	func setPaused(_ isPaused: Bool, showsPauseScreen: Bool = true) {
		let pauseStateChanged = isGamePaused != isPaused
		if pauseStateChanged {
			if !isPaused {
				setRenderLoopActive(true)
			}
			isGamePaused = isPaused
			scnScene.isPaused = isPaused
			scene.setAudioPaused(isPaused)
			vehicle?.setAudioPaused(isPaused)
			if isPaused {
				playPauseMenuOpenSound()
			}
			scene.setScriptsPaused(isPaused)
			clearPendingLook()
			lastUpdateTime = nil
		}

		updateHud { hud in
			hud.setPauseScreenVisible(isPaused && showsPauseScreen)
		}
		requestRender()

		if pauseStateChanged {
			playerController?.stop()
			vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
			if isPaused {
				setRenderLoopActive(false)
			}
		}
	}

	func requestRender() {
		Task { @MainActor [weak self] in
			#if os(macOS)
			self?.renderView?.needsDisplay = true
			#elseif os(iOS)
			self?.renderView?.setNeedsDisplay()
			#endif
		}
	}

	private func setRenderLoopActive(_ isActive: Bool) {
		Task { @MainActor [weak self] in
			self?.renderView?.isPlaying = isActive
			self?.renderView?.rendersContinuously = isActive
		}
	}

	func endMission(returnsToMainMenu: Bool, message: String?) {
		guard !didEndMission else { return }
		didEndMission = true

		scene.clearActiveRecordPlayback()
		updateHud { hud in
			hud.showMissionEndText(message)
			hud.setScriptBlackoutVisible(true, immediate: false)
		}
		setPaused(true, showsPauseScreen: false)
		playerController?.stop()
		vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
		if returnsToMainMenu {
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
				self?.onMissionEnded?()
			}
		}
	}

	func changeMission(folder: String, frameName: String, speed: Float) {
		guard !didEndMission else { return }
		didEndMission = true
		let transitionSpeed: CGFloat?
		if mode == .car {
			transitionSpeed = speed < 0 ? vehicle?.speed : CGFloat(speed)
		} else {
			transitionSpeed = nil
		}
		scene.setScriptsPaused(true)
		DispatchQueue.main.async {
			self.onMissionChangeRequested?(folder, frameName, transitionSpeed)
		}
	}

	func activateMissionEndOption(at index: Int) {
		guard didEndMission else { return }

		switch index {
		case 0:
			onMissionRestarted?()
		case 1:
			onMissionEnded?()
		default:
			break
		}
	}

	func exitPausedGameToMainMenu() {
		guard isGamePaused else { return }

		onMissionEnded?()
	}

	func restartPausedGame() {
		guard isGamePaused else { return }

		onMissionRestarted?()
	}

	func loadGameFromPauseMenu() {
		guard isGamePaused else { return }

		onLoadGameRequested?()
	}

	private func preloadMenuSounds() {
		pauseMenuOpenSoundSource = loadMenuSound(named: "menuopen.wav")
		pauseMenuChangeSoundSource = loadMenuSound(named: "menuchange.wav")
	}

	private func loadMenuSound(named fileName: String) -> SCNAudioSource? {
		let url = mainDirectory.appendingPathComponent("sounds/\(fileName)")
		guard let source = SCNAudioSource(url: url) else { return nil }
		source.isPositional = false
		source.load()
		return source
	}

	private func playPauseMenuOpenSound() {
		guard let source = pauseMenuOpenSoundSource else { return }
		playPauseMenuSound(source)
	}

	func playInGameMenuChangeSound() {
		guard let source = pauseMenuChangeSoundSource else { return }
		playPauseMenuSound(source)
	}

	private func playPauseMenuSound(_ source: SCNAudioSource) {
		let player = SCNAudioPlayer(source: source)
		player.didFinishPlayback = { [weak self, weak player] in
			DispatchQueue.main.async {
				if let player = player {
					self?.scene.rootNode.removeAudioPlayer(player)
				}
			}
		}
		scene.rootNode.addAudioPlayer(player)
	}

}

extension SCNNode {
	func setHiddenInHierarchy(_ hidden: Bool) {
		isHidden = hidden
		for child in childNodes {
			child.setHiddenInHierarchy(hidden)
		}
	}
}

private extension SCNNode {
	var hasModelContent: Bool {
		if geometry != nil {
			return true
		}
		return childNodes.contains { $0.hasModelContent }
	}

	func firstNode(where matches: (SCNNode) -> Bool) -> SCNNode? {
		if matches(self) {
			return self
		}
		for child in childNodes {
			if let node = child.firstNode(where: matches) {
				return node
			}
		}
		return nil
	}

	func firstResult<Result>(where transform: (SCNNode) -> Result?) -> Result? {
		if let result = transform(self) {
			return result
		}
		for child in childNodes {
			if let result = child.firstResult(where: transform) {
				return result
			}
		}
		return nil
	}

	func hideSkyboxBackdropGeometry() {
		if isSkyboxBackdropNode {
			isHidden = true
			return
		}
		for child in childNodes {
			child.hideSkyboxBackdropGeometry()
		}
	}

	func disablePhysicsInHierarchy() {
		physicsBody = nil
		for child in childNodes {
			child.disablePhysicsInHierarchy()
		}
	}

	var isSkyboxBackdropNode: Bool {
		if isSkyboxBackdropResourceName(name) {
			return true
		}
		return geometry?.materials.contains { material in
			isSkyboxBackdropResourceName(material.name)
		} ?? false
	}

	func skyboxTextureSet() -> String? {
		if let textureSet = skyboxTextureSetName(from: name) {
			return textureSet
		}
		if let materialTextureSet = geometry?.materials.compactMap({ skyboxTextureSetName(from: $0.name) }).first {
			return materialTextureSet
		}
		for child in childNodes {
			if let textureSet = child.skyboxTextureSet() {
				return textureSet
			}
		}
		return nil
	}

	func skyboxNodes(relativeTo cameraPosition: SCNVector3) -> [(node: SCNNode, offset: SCNVector3)] {
		var nodes: [(node: SCNNode, offset: SCNVector3)] = []
		guard !isHidden else { return nodes }
		if isSkyboxNode {
			nodes.append((self, presentation.worldPosition - cameraPosition))
			return nodes
		}
		for child in childNodes {
			nodes.append(contentsOf: child.skyboxNodes(relativeTo: cameraPosition))
		}
		return nodes
	}

	var isSkyboxNode: Bool {
		return followsCamera && parent?.parent?.name == "__cache__"
	}

	func containsWorldPosition(_ position: SCNVector3) -> Bool {
		let bounds = boundingBox
		guard bounds.max.x > bounds.min.x || bounds.max.y > bounds.min.y || bounds.max.z > bounds.min.z else {
			return false
		}

		let localPosition = presentation.convertPosition(position, from: nil)
		return localPosition.x >= bounds.min.x && localPosition.x <= bounds.max.x &&
			localPosition.y >= bounds.min.y && localPosition.y <= bounds.max.y &&
			localPosition.z >= bounds.min.z && localPosition.z <= bounds.max.z
	}

	var hierarchyLevel: Int {
		var level = 0
		var current = parent
		while current != nil {
			level += 1
			current = current?.parent
		}
		return level
	}

	func actionSquaredDistance(to position: SCNVector3) -> Float {
		let bounds = boundingBox
		guard bounds.max.x > bounds.min.x || bounds.max.y > bounds.min.y || bounds.max.z > bounds.min.z else {
			return squaredDistance(to: position)
		}

		let localPosition = presentation.convertPosition(position, from: nil)
		let closest = SCNVector3(
			x: max(bounds.min.x, min(bounds.max.x, localPosition.x)),
			y: max(bounds.min.y, min(bounds.max.y, localPosition.y)),
			z: max(bounds.min.z, min(bounds.max.z, localPosition.z))
		)
		let worldClosest = presentation.convertPosition(closest, to: nil)
		let dx = Float(worldClosest.x - position.x)
		let dy = Float(worldClosest.y - position.y)
		let dz = Float(worldClosest.z - position.z)
		return dx * dx + dy * dy + dz * dz
	}
}

private extension Array where Element == EnvironmentLight {
	func bestMatch(
		kind: EnvironmentLightKind,
		cameraPosition: SCNVector3,
		rootNode: SCNNode,
		sectorNodes: inout [String: SCNNode],
		missingSectorNames: inout Set<String>
	) -> EnvironmentLight? {
		var bestLight: EnvironmentLight?
		var bestLevel = Int.min

		for light in self where light.kind == kind {
			let level: Int
			if let sectorName = light.sectorName,
			   let sectorNode = environmentSectorNode(
				named: sectorName,
				rootNode: rootNode,
				sectorNodes: &sectorNodes,
				missingSectorNames: &missingSectorNames
			   ) {
				guard sectorNode.containsWorldPosition(cameraPosition) else { continue }
				level = sectorName == "Primary Sector" ? 0 : sectorNode.hierarchyLevel
			} else {
				level = light.node.hierarchyLevel
			}

			if level >= bestLevel {
				bestLight = light
				bestLevel = level
			}
		}

		return bestLight
	}

	private func environmentSectorNode(
		named name: String,
		rootNode: SCNNode,
		sectorNodes: inout [String: SCNNode],
		missingSectorNames: inout Set<String>
	) -> SCNNode? {
		if let sectorNode = sectorNodes[name] {
			return sectorNode
		}
		guard !missingSectorNames.contains(name) else { return nil }
		guard let sectorNode = rootNode.mafiaChildNode(named: name, recursively: true) else {
			missingSectorNames.insert(name)
			return nil
		}
		sectorNodes[name] = sectorNode
		return sectorNode
	}
}

private extension EnvironmentLight {
	var isOutdoorLight: Bool {
		guard let sectorName else { return true }
		return sectorName.caseInsensitiveCompare("Primary Sector") == .orderedSame
	}
}

private extension SKColor {
	func multiplied(by value: CGFloat) -> SKColor {
		let components = rgbaComponents
		return SKColor(
			red: min(1, components.red * value),
			green: min(1, components.green * value),
			blue: min(1, components.blue * value),
			alpha: components.alpha
		)
	}

	func lerped(to target: SKColor, amount: CGFloat) -> SKColor {
		let start = rgbaComponents
		let end = target.rgbaComponents
		return SKColor(
			red: start.red + (end.red - start.red) * amount,
			green: start.green + (end.green - start.green) * amount,
			blue: start.blue + (end.blue - start.blue) * amount,
			alpha: start.alpha + (end.alpha - start.alpha) * amount
		)
	}

	var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
		#if os(macOS)
			let color = usingColorSpace(.deviceRGB) ?? self
			return (color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent)
		#elseif os(iOS)
			var red: CGFloat = 0
			var green: CGFloat = 0
			var blue: CGFloat = 0
			var alpha: CGFloat = 0
			getRed(&red, green: &green, blue: &blue, alpha: &alpha)
			return (red, green, blue, alpha)
		#endif
	}
}

private func skyboxTextureSetName(from name: String?) -> String? {
	guard let name = name?.lowercased() else { return nil }
	for component in name.components(separatedBy: "|") where component.hasPrefix("sky ") && component.hasSuffix(".bmp") {
		let parts = component.components(separatedBy: " ")
		guard parts.count >= 3 else { continue }
		return parts.dropLast().joined(separator: " ")
	}
	return nil
}

private func loadMapImage(named name: String) -> Any? {
	guard let url = mafiaMapURL(named: name) else { return nil }
	#if os(macOS)
		return NSImage(contentsOf: url)
	#elseif os(iOS)
		return UIImage(contentsOfFile: url.path)
	#endif
}

// MARK: - SCNSceneRendererDelegate

extension Game: SCNSceneRendererDelegate {

	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		guard !isGamePaused else { return }

		let deltaTime = lastUpdateTime.map { time - $0 } ?? 0
		lastUpdateTime = time
		updateDiagnostics(deltaTime: deltaTime)
		updateHud { hud in
			hud.refreshScriptTimer()
		}

		if isCutsceneCameraActive {
			updateSkyboxPosition()
			updateEnvironment(deltaTime: deltaTime)
			return
		}

		applyPendingLook()

		if mode == .walk {
			if let playerController = playerController {
				let appliedYaw = playerController.turnTowardCameraYaw(walkCameraYaw, deltaTime: deltaTime)
				walkCameraYaw = normalizedAngle(walkCameraYaw - appliedYaw)
			}
			playerController?.update(deltaTime: deltaTime)
			updateWalkCameraHeight(deltaTime: deltaTime)
			cameraContainer.eulerAngles = SCNVector3(
				x: playerController?.cameraPitch ?? 0,
				y: walkCameraYaw,
				z: 0
			)
		} else if mode == .car && vehicle != nil {
			if !isPlayerVehicleTransitionActive {
				syncPlayerToVehicle()
				updatePlayerVehicleSittingAnimation()
			}
			updateCarCameraLook(deltaTime: deltaTime)
			updateCarCameraFollow(deltaTime: deltaTime)
		} else {
			updateFreeCamera(deltaTime: deltaTime)
		}
		updateSkyboxPosition()
		updateEnvironment(deltaTime: deltaTime)
		trafficManager?.update(deltaTime: deltaTime, playerPosition: playerReferencePosition())

		#if os(macOS)

		if mode == .car {
			vehicle?.applyForces()
		}

		#elseif os(iOS)

		if mode == .walk {
			/*let translation = vc.walkGesture.translation(in: vc.view)
			if let playerNode = scene.playerNode {
				let angle = playerNode.presentation.rotation.y * playerNode.presentation.rotation.w - .pi
//				let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 5000)), y: 0, z: max(-1, min(1, Float(-translation.y) / 5000)))
//				scene.playerNode!.position.x -= impulse.x * cos(angle) - impulse.z * sin(angle)
//				scene.playerNode!.position.z += impulse.x * -sin(angle) - impulse.z * cos(angle)
				var impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 50)), y: 0, z: max(-1, min(1, Float(-translation.y) / 50)))
				impulse = SCNVector3(
					x: (impulse.x * cos(angle) - impulse.z * sin(angle))*80,
					y: 0,
					z: (impulse.x * -sin(angle) - impulse.z * cos(angle))*80
				)
				playerNode.physicsBody?.applyForce(impulse, asImpulse: true)
			} else {
				let angle = cameraContainer.presentation.rotation.y * cameraContainer.presentation.rotation.w - .pi
				let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 500)), y: 0, z: max(-1, min(1, Float(-translation.y) / 500)))
				cameraContainer.position.x -= impulse.x * cos(angle) - impulse.z * sin(angle)
				cameraContainer.position.z += impulse.x * -sin(angle) - impulse.z * cos(angle)
			}*/
		} else {
			vehicle?.applyForces()
		}

		#endif

		vehicle?.updateAudio(isActive: mode == .car)

		let vehicleVelocity = vehicle?.velocity ?? SCNVector3Zero
		let vehicleSpeed = sqrt(
			vehicleVelocity.x * vehicleVelocity.x +
			vehicleVelocity.y * vehicleVelocity.y +
			vehicleVelocity.z * vehicleVelocity.z
		)
		let displayedVehicleSpeed = vehicle?.speed ?? 0
		let displayedVehicleForce = vehicle?.force ?? 0
		let isVehicleSpeedVisible = mode == .car && vehicle != nil
		let isSpeedLimiterEnabled = vehicle?.isSpeedLimiterEnabled == true
		updateHud { hud in
			hud.updateVehicleSpeed(
				CGFloat(vehicleSpeed),
				vehicleSpeed: displayedVehicleSpeed,
				force: displayedVehicleForce,
				isVisible: isVehicleSpeedVisible,
				isSpeedLimiterEnabled: isSpeedLimiterEnabled
			)
			hud.updateMapMarker(
				normalizedPosition: self.mapReferencePosition(),
				heading: self.mapReferenceHeading()
			)
			hud.updateMapDestination(normalizedPosition: self.mapCompassDestinationPosition())
		}
		refreshPlayerStatusHud()
		updateNPCHealthLabels()
		updateVehicleStealing()
		updateBatCharge()
		updateFullAutoFire()

		if let node = scene.compassNode,
		   let playerNode = scene.playerNode {
			let p1 = node.presentation.worldPosition
			let p2 = playerNode.presentation.worldPosition
			let target = SCNVector3(x: p1.x - p2.x, y: 0, z: p1.z - p2.z)
			let referenceNode = mode == .car ? vehicle?.node : playerNode
			let referenceTransform = referenceNode?.presentation.worldTransform ?? playerNode.presentation.worldTransform
			let referenceForward = normalizedHorizontalVector(
				SCNVector3(x: referenceTransform.m31, y: 0, z: referenceTransform.m33),
				fallback: SCNVector3(x: 0, y: 0, z: 1)
			)
			let targetAngle = atan2(target.z, target.x)
			let forwardAngle = atan2(referenceForward.z, referenceForward.x)
			let compassRotation = CGFloat(targetAngle - forwardAngle + .pi / 2)
			updateHud { hud in
				hud.setCompassVisible(true)
				hud.compassNeedle.zRotation = compassRotation
			}
		} else {
			updateHud { hud in
				hud.setCompassVisible(false)
			}
		}

		updateActionButtonVisibility(at: time)
	}

	func playerReferencePosition() -> SCNVector3? {
		switch mode {
		case .walk:
			return scene.playerNode?.presentation.worldPosition
		case .car:
			return scene.playerNode?.presentation.worldPosition ?? vehicle?.node.presentation.worldPosition
		case .freeCamera:
			return nil
		}
	}

	func mapReferencePosition() -> CGPoint? {
		guard let position = playerReferencePosition(),
			  let bounds = roadMapBounds else { return nil }

		return bounds.normalizedPoint(for: position)
	}

	func mapCompassDestinationPosition() -> CGPoint? {
		guard let node = scene.compassNode,
			  let bounds = roadMapBounds else { return nil }

		return bounds.normalizedPoint(for: node.presentation.worldPosition)
	}

	func mapReferenceHeading() -> CGFloat? {
		let forward: SCNVector3
		switch mode {
		case .walk:
			if let playerNode = scene.playerNode {
				forward = playerNode.presentation.worldFront
			} else {
				forward = cameraContainer.presentation.worldFront
			}
		case .car:
			if let vehicle = vehicle {
				forward = vehicle.node.presentation.worldFront
			} else if let playerNode = scene.playerNode {
				forward = playerNode.presentation.worldFront
			} else {
				forward = cameraContainer.presentation.worldFront
			}
		case .freeCamera:
			return nil
		}

		return atan2(-CGFloat(forward.x), CGFloat(forward.z)) + .pi
	}

	private func updateDiagnostics(deltaTime: TimeInterval) {
		if deltaTime > 0 {
			let instantFramesPerSecond = CGFloat(1 / deltaTime)
			if smoothedFramesPerSecond == 0 {
				smoothedFramesPerSecond = instantFramesPerSecond
			} else {
				smoothedFramesPerSecond += (instantFramesPerSecond - smoothedFramesPerSecond) * 0.1
			}
		}

		let framesPerSecond = smoothedFramesPerSecond
		let position = diagnosticsPosition()
		let details = diagnosticsDetails()
		updateHud { hud in
			hud.updateDiagnostics(
				framesPerSecond: framesPerSecond,
				position: position,
				details: details
			)
		}
	}

	private func diagnosticsPosition() -> SCNVector3 {
		switch mode {
		case .walk:
			return scene.playerNode?.presentation.worldPosition ?? cameraNode.presentation.worldPosition
		case .car:
			return vehicle?.node.presentation.worldPosition ?? cameraNode.presentation.worldPosition
		case .freeCamera:
			return cameraNode.presentation.worldPosition
		}
	}

	private func diagnosticsDetails() -> String? {
		if mode == .car, let vehicle = vehicle {
			let rayNames = vehicle.debugGroundRayNames
			let rays = rayNames.isEmpty ? "--" : rayNames.prefix(3).joined(separator: " | ")
			let wheelRayNames = vehicle.debugWheelRayNames
			let wheelRays = wheelRayNames.isEmpty ? "--" : wheelRayNames.joined(separator: " | ")
			return String(
				format: "CAR\nbody %.2f  wheel %.2f  force %.0f\nR %@\nW %@",
				Double(vehicle.velocity.length),
				Double(vehicle.speed),
				Double(vehicle.force),
				rays,
				wheelRays
			)
		}

		guard mode == .walk,
			  let debugInfo = playerController?.debugInfo else { return nil }

		let groundY = debugInfo.probedGroundY ?? debugInfo.standingY
		let controllerGroundDelta = debugInfo.controllerY - groundY
		let visualGroundDelta = debugInfo.visualMinY.map { $0 - groundY }
		let visualHeight = debugInfo.visualMinY.flatMap { minY in
			debugInfo.visualMaxY.map { $0 - minY }
		}
		let animationName = debugInfo.currentAirAnimationName ?? debugInfo.currentWalkingAnimationName ?? "none"

		return String(
			format: "DBG %@\nG %.2f  C-G %.2f  V-G %@  VH %@\nvy %.2f  off %.2f  %@\nB %@\nW C %@  V %@  %@",
			areCollisionWireframesVisible ? "wire" : "solid",
			Double(groundY),
			Double(controllerGroundDelta),
			formatDebugValue(visualGroundDelta),
			formatDebugValue(visualHeight),
			Double(debugInfo.verticalVelocity),
			Double(debugInfo.verticalOffset),
			animationName,
			debugInfo.horizontalBlockerName ?? "--",
			formatDebugValue(debugInfo.worstControllerGroundDelta),
			formatDebugValue(debugInfo.worstVisualGroundDelta),
			debugInfo.worstAnimationName ?? "none"
		)
	}

	private func formatDebugValue(_ value: SCNFloat?) -> String {
		guard let value = value else { return "--" }
		return String(format: "%.2f", Double(value))
	}

}

// MARK: - Actions

extension Game {

	func performAction(_ action: Action) {
		switch action {
		case .action(let script, _):
			let index = scene.actions.firstIndex(where: { action in
				if case .action(let _script, _) = action {
					return script.uuid == _script.uuid
				} else {
					return false
				}
			})!
			scene.actions.remove(at: index)

			script.completeActionWait()

		case .weapon(let node, let weapon):
			node.isHidden = true

			let index = scene.actions.firstIndex(where: { action in
				if case .weapon(_, let _weapon) = action {
					return weapon.uuid == _weapon.uuid
				} else {
					return false
				}
			})!
			scene.actions.remove(at: index)

			scene.updateWeapons(for: scene.playerNode!) { weapons in
				for weapon in weapons {
					weapon.position = .inventory
				}
				weapons.append(weapon)
				weapon.position = .hand
			}

			refreshPlayerStatusHud()

		case .door(let node):
			useDoor(node)

		case .vehicleSteal(let vehicle):
			beginVehicleSteal(vehicle)

		case .vehicleEnter(let vehicle):
			enterVehicleWithAnimation(vehicle)

		case .vehicleExit:
			exitVehicleWithAnimation()
		}
	}

	func actionButtonTapped() {
		let actions = availableActions()
		guard let action = actions.first else { return }
		if actions.count > 1 {
			hud.showActionMenu(actions: actions)
		} else {
			performAction(action)
		}
	}

	func playerDidFire() {
		guard !isGamePaused else { return }

		pressControl(.FIRE)
		if equippedPlayerWeapon()?.isBaseballBat == true {
			beginBatCharge()
			return
		}
		if firePlayerWeapon() {
			scene.triggerPlayerFireEvent()
		}
	}

	func playerDidHorn() {
		lastControl = .HORN
		if mode == .car {
			vehicle?.playHorn()
		}
		scene.triggerPlayerHornEvent()
	}

	func toggleSpeedLimiter() {
		pressControl(.SPEEDLIMIT)
		guard let vehicle = vehicle else { return }

		vehicle.isSpeedLimiterEnabled.toggle()
		let message = vehicle.isSpeedLimiterEnabled ? "Speed limiter on" : "Speed limiter off"
		updateHud { hud in
			hud.showConsoleText(message)
		}
	}

	func showObjectives() {
		pressControl(.OBJECTIVES)
		let objectives = scene.objectives
		updateHud { hud in
			hud.showCurrentObjectives(objectives)
		}
	}

	func toggleCollisionWireframes() {
		areCollisionWireframesVisible.toggle()
		scnScene.rootNode
			.mafiaChildNode(named: "__collisions__", recursively: false)?
			.setCollisionWireframesVisible(areCollisionWireframesVisible)
		roadDebugNode?.isHidden = !areCollisionWireframesVisible
		vehicle?.setCollisionDebugVisible(areCollisionWireframesVisible)
		playerController?.setDebugVisualsVisible(areCollisionWireframesVisible)
		let message = "Collision wireframes \(areCollisionWireframesVisible ? "on" : "off")"
		updateHud { hud in
			hud.showConsoleText(message)
		}
	}

	private static func roadDebugNode(for road: Road) -> SCNNode {
		let root = SCNNode()
		root.name = "__road_waypoint_debug__"

		if let routeNode = roadRouteDebugNode(for: road) {
			root.addChildNode(routeNode)
		}

		let waypointMaterial = debugMaterial(color: .magenta, fillMode: .fill)
		for (index, waypoint) in road.waypoints.enumerated() {
			let marker = SCNSphere(radius: 0.18)
			marker.firstMaterial = waypointMaterial
			let node = SCNNode(geometry: marker)
			node.name = "__road_waypoint_\(index)__"
			node.position = raisedRoadDebugPosition(waypoint.position)
			root.addChildNode(node)
		}

		return root
	}

	private static func roadRouteDebugNode(for road: Road) -> SCNNode? {
		let samplesPerSegment = 8
		var vertices: [SCNVector3] = []
		var indices: [Int32] = []
		vertices.reserveCapacity(road.waypoints.count * samplesPerSegment * 2)
		indices.reserveCapacity(road.waypoints.count * samplesPerSegment * 2)

		for (index, waypoint) in road.waypoints.enumerated() {
			guard let nextIndex = road.nextWaypointIndex(after: index, routeSeed: index),
				  road.waypoints.indices.contains(nextIndex),
				  nextIndex != index else { continue }

			let previousIndex = road.previousWaypointIndex(before: index) ?? index
			let futureIndex = road.nextWaypointIndex(after: nextIndex, routeSeed: index) ?? nextIndex
			var previousSample = raisedRoadDebugPosition(waypoint.position)

			for sampleIndex in 1...samplesPerSegment {
				let progress = Float(sampleIndex) / Float(samplesPerSegment)
				let sample = raisedRoadDebugPosition(catmullRom(
					previous: road.waypoints[previousIndex].position,
					start: waypoint.position,
					end: road.waypoints[nextIndex].position,
					future: road.waypoints[futureIndex].position,
					progress: progress
				))
				let startVertexIndex = Int32(vertices.count)
				vertices.append(previousSample)
				vertices.append(sample)
				indices.append(startVertexIndex)
				indices.append(startVertexIndex + 1)
				previousSample = sample
			}
		}

		guard !vertices.isEmpty else { return nil }

		let source = SCNGeometrySource(vertices: vertices)
		let element = SCNGeometryElement(indices: indices, primitiveType: .line)
		let geometry = SCNGeometry(sources: [source], elements: [element])
		geometry.firstMaterial = debugMaterial(color: .cyan)

		let node = SCNNode(geometry: geometry)
		node.name = "__road_waypoint_routes__"
		return node
	}

	private static func raisedRoadDebugPosition(_ position: SCNVector3) -> SCNVector3 {
		return SCNVector3(x: position.x, y: position.y + 0.35, z: position.z)
	}

	private static func catmullRom(
		previous: SCNVector3,
		start: SCNVector3,
		end: SCNVector3,
		future: SCNVector3,
		progress: Float
	) -> SCNVector3 {
		let t = SCNFloat(max(0, min(1, progress)))
		let t2 = t * t
		let t3 = t2 * t
		return SCNVector3(
			x: 0.5 * (
				2 * start.x +
				(-previous.x + end.x) * t +
				(2 * previous.x - 5 * start.x + 4 * end.x - future.x) * t2 +
				(-previous.x + 3 * start.x - 3 * end.x + future.x) * t3
			),
			y: 0.5 * (
				2 * start.y +
				(-previous.y + end.y) * t +
				(2 * previous.y - 5 * start.y + 4 * end.y - future.y) * t2 +
				(-previous.y + 3 * start.y - 3 * end.y + future.y) * t3
			),
			z: 0.5 * (
				2 * start.z +
				(-previous.z + end.z) * t +
				(2 * previous.z - 5 * start.z + 4 * end.z - future.z) * t2 +
				(-previous.z + 3 * start.z - 3 * end.z + future.z) * t3
			)
		)
	}

	private static func debugMaterial(color: SKColor, fillMode: SCNFillMode = .lines) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = color
		material.emission.contents = color
		material.lightingModel = .constant
		material.fillMode = fillMode
		material.isDoubleSided = true
		return material
	}

	func setVehicleStealEnabled(carId: Int, node: SCNNode?, enabled: Bool) {
		if enabled {
			stealEnabledVehicleIds.insert(carId)
			if let node = node {
				stealVehicleNodes[carId] = node
			}
		} else {
			stealEnabledVehicleIds.remove(carId)
			stealVehicleNodes[carId] = nil
			activeSteal = nil
		}
	}

	func markVehicleMustSteal(carId: Int, node: SCNNode?) {
		setVehicleStealEnabled(carId: carId, node: node, enabled: true)
	}

	func didPlayerStealVehicle(carId: Int) -> Bool {
		return stolenVehicleIds.contains(carId)
	}

	func playerOwnerMatches(carNode: SCNNode?) -> Bool {
		guard let carNode = carNode else {
			return mode != .car
		}
		guard mode == .car,
			  let vehicle = vehicle else { return false }

		return isVehicle(vehicle, matching: carNode) ||
			vehicle.node.squaredDistance(to: carNode.presentation.worldPosition) <= vehicleOwnerMatchDistanceSquared ||
			vehicle.scriptNode.squaredDistance(to: carNode.presentation.worldPosition) <= vehicleOwnerMatchDistanceSquared
	}

	func canEnterCurrentVehicle() -> Bool {
		guard let vehicle = vehicle else { return false }
		return vehicleStealId(for: vehicle) == nil
	}

	func pressControl(_ control: Control) {
		guard !arePlayerControlsLocked else { return }
		lastControl = control
		activeControls.insert(control)
	}

	func releaseControl(_ control: Control) {
		activeControls.remove(control)
		if lastControl == control {
			lastControl = nil
		}
		if control == .FIRE {
			releaseBatCharge()
		}
	}

	func isControlPressed(_ control: Control) -> Bool {
		guard !arePlayerControlsLocked else { return false }
		return activeControls.contains(control)
	}

	func consumeLastControl(_ control: Control) -> Bool {
		guard !arePlayerControlsLocked else { return false }
		guard lastControl == control else { return false }
		lastControl = nil
		return true
	}

	func setPlayerControlsLocked(_ isLocked: Bool) {
		arePlayerControlsLocked = isLocked
		if isLocked {
			activeControls.removeAll()
			lastControl = nil
			playerController?.stop()
			vehicle?.updateControls(throttle: 0, brake: true, steering: 0)
		}
	}

	func setPlayerCrouching(_ isCrouching: Bool) {
		if isCrouching {
			pressControl(.CROUCH)
		} else {
			releaseControl(.CROUCH)
		}
		playerController?.setCrouching(isCrouching)
	}

	func holsterPlayerWeapons() {
		guard let playerNode = scene.playerNode else { return }
		let hadHeldWeapon = scene.weapons(for: playerNode).contains { $0.position == .hand }
		let didUpdateWeapons = scene.updateWeaponsIfPresent(for: playerNode) { weapons in
			for weapon in weapons {
				weapon.position = .inventory
			}
		}
		guard didUpdateWeapons else { return }
		if hadHeldWeapon {
			playWeaponToggleAnimation()
		}
		refreshPlayerStatusHud()
	}

	func dropPlayerWeapon() {
		guard let playerNode = scene.playerNode,
			  let weapon = scene.weapons(for: playerNode).first(where: { $0.position == .hand }) else { return }
		dropPlayerWeapon(weapon, from: playerNode)
	}

	func dropPlayerWeapon(_ weapon: Weapon) {
		guard let playerNode = scene.playerNode,
			  scene.weapons(for: playerNode).contains(where: { $0 === weapon }) else { return }
		dropPlayerWeapon(weapon, from: playerNode)
	}

	private func dropPlayerWeapon(_ weapon: Weapon, from playerNode: SCNNode) {
		guard let dropNode = droppedWeaponNode(for: weapon, from: playerNode) else { return }

		playWeaponDropAnimation()
		scene.updateWeaponsIfPresent(for: playerNode) { weapons in
			weapons.removeAll { $0 === weapon }
		}
		weapon.position = .inventory
		scene.rootNode.addChildNode(dropNode)
		scene.actions.append(.weapon(dropNode, weapon))
		let message = "Dropped \(weapon.name)"
		updateHud { hud in
			hud.showConsoleText(message)
		}
		refreshPlayerStatusHud()
	}

	private func droppedWeaponNode(for weapon: Weapon, from playerNode: SCNNode) -> SCNNode? {
		guard let dropNode = loadHeldWeaponModel(for: weapon) else { return nil }

		dropNode.name = "__dropped_weapon_\(weapon.id)__"
		dropNode.physicsBody = nil
		dropNode.disablePhysicsInHierarchy()

		let handPosition = droppedWeaponHandPosition(in: playerNode)
		let groundPosition = droppedWeaponGroundPosition(below: handPosition, playerNode: playerNode)
		let bounds = dropNode.boundingBox
		let groundY = groundPosition.y - min(bounds.min.y, bounds.max.y)
		dropNode.position = scene.rootNode.convertPosition(
			SCNVector3(x: groundPosition.x, y: groundY, z: groundPosition.z),
			from: nil
		)

		let playerForward = playerNode.presentation.worldFront
		dropNode.eulerAngles = SCNVector3(
			x: 0,
			y: atan2(-playerForward.x, -playerForward.z),
			z: 0
		)
		return dropNode
	}

	private func droppedWeaponHandPosition(in playerNode: SCNNode) -> SCNVector3 {
		if let heldWeaponNode = heldWeaponNode,
		   heldWeaponNode.parent != nil {
			return heldWeaponNode.presentation.worldPosition
		}
		return heldWeaponAnchor(in: playerNode).presentation.worldPosition
	}

	private func droppedWeaponGroundPosition(below position: SCNVector3, playerNode: SCNNode) -> SCNVector3 {
		let from = SCNVector3(x: position.x, y: position.y + 1.0, z: position.z)
		let to = SCNVector3(x: position.x, y: position.y - 8.0, z: position.z)
		let hits = scnScene.physicsWorld.rayTestWithSegment(from: from, to: to, options: [
			SCNPhysicsWorld.TestOption.collisionBitMask: PhysicsCategory.playerBlocking,
			SCNPhysicsWorld.TestOption.searchMode: SCNPhysicsWorld.TestSearchMode.all
		])

		for hit in hits where hit.worldNormal.y >= 0.5 && !isNode(hit.node, inside: playerNode) {
			return hit.worldCoordinates
		}
		return SCNVector3(x: position.x, y: playerNode.presentation.worldPosition.y, z: position.z)
	}

	func playerInventoryWeapons() -> [Weapon] {
		guard let playerNode = scene.playerNode else { return [] }
		return scene.weapons(for: playerNode)
	}

	@discardableResult
	func addAllPossiblePlayerInventoryItems() -> Int {
		guard let playerNode = scene.playerNode else { return 0 }

		var addedCount = 0
		var addedMagazineCount = 0
		scene.updateWeapons(for: playerNode) { weapons in
			var existingIds = Set(weapons.map { $0.id })
			for weapon in weapons {
				guard let profile = weapon.profile else { continue }
				weapon.restAmmo += profile.clipSize
				addedMagazineCount += 1
			}
			for id in Weapon.allDefinitionIds where !existingIds.contains(id) {
				let weapon = Weapon(id: id)
				if let profile = weapon.profile {
					weapon.clipAmmo = profile.clipSize
					weapon.restAmmo = profile.clipSize
					addedMagazineCount += 1
				} else {
					weapon.clipAmmo = -1
				}
				weapon.position = .inventory
				weapons.append(weapon)
				existingIds.insert(id)
				addedCount += 1
			}
		}

		if addedCount > 0 || addedMagazineCount > 0 {
			let message = "Added \(addedCount) inventory items, \(addedMagazineCount) magazines"
			updateHud { hud in
				hud.showConsoleText(message)
			}
			refreshPlayerStatusHud()
		} else {
			updateHud { hud in
				hud.showConsoleText("Inventory already has all items")
			}
		}
		return addedCount
	}

	func equipPlayerWeapon(_ selectedWeapon: Weapon?) {
		guard let playerNode = scene.playerNode else { return }
		let currentWeapon = scene.weapons(for: playerNode).first { $0.position == .hand }
		let didChangeWeapon = currentWeapon.map { currentWeapon in
			selectedWeapon.map { currentWeapon !== $0 } ?? true
		} ?? (selectedWeapon != nil)

		scene.updateWeaponsIfPresent(for: playerNode) { weapons in
			for weapon in weapons {
				weapon.position = selectedWeapon.map { weapon === $0 } == true ? .hand : .inventory
			}
		}

		if didChangeWeapon {
			playWeaponToggleAnimation()
		}
		if let selectedWeapon = selectedWeapon {
			let message = "Equipped \(selectedWeapon.name)"
			updateHud { hud in
				hud.showConsoleText(message)
			}
		} else {
			updateHud { hud in
				hud.showConsoleText("Empty hands")
			}
		}
		refreshPlayerStatusHud()
	}

	func reloadPlayerWeapon() {
		guard let weapon = equippedPlayerWeapon(),
			  weapon.canReload,
			  let profile = weapon.profile,
			  !isReloading(weapon) else { return }

		reload(weapon, profile: profile)
	}

	private func reload(_ weapon: Weapon, profile: Weapon.Profile) {
		let now = Date.timeIntervalSinceReferenceDate
		guard !isReloading(weapon, at: now) else { return }

		let loadedAmmo = min(profile.clipSize, weapon.restAmmo)
		weapon.clipAmmo = loadedAmmo
		weapon.restAmmo -= loadedAmmo
		reloadingWeaponUUID = weapon.uuid
		weaponReloadEndTime = now + reloadDuration(weapon: weapon, profile: profile)
		playWeaponAnimation(weapon: weapon, profile: profile, action: "reload")
		playWeaponSound(profile.reloadSoundName)
		refreshPlayerStatusHud()
	}

	func setPlayerHealth(_ health: Int) {
		playerHealth = max(0, health)
		if Thread.isMainThread {
			refreshPlayerStatusHud()
		} else {
			DispatchQueue.main.async {
				self.refreshPlayerStatusHud()
			}
		}
	}

	func playSiderollAnimation(direction: SiderollDirection) {
		guard mode == .walk,
			  scene.playerNode != nil else { return }

		let directionValue: Int
		switch direction {
		case .left:
			directionValue = -1
			scene.noteActionAnimation(id: 98)
		case .right:
			directionValue = 1
			scene.noteActionAnimation(id: 99)
		}

		playerController?.playSideJumpActionAnimation(direction: directionValue, animationKey: "__sideroll__")
	}

	private func updateFullAutoFire() {
		guard isControlPressed(.FIRE),
			  equippedPlayerWeapon()?.profile?.isFullAuto == true else { return }

		if firePlayerWeapon() {
			scene.triggerPlayerFireEvent()
		}
	}

	private func firePlayerWeapon() -> Bool {
		guard !isGamePaused,
			  mode == .walk || mode == .car,
			  let weapon = equippedPlayerWeapon(),
			  weapon.isFirearm,
			  let profile = weapon.profile else { return false }

		let now = Date.timeIntervalSinceReferenceDate
		guard !isReloading(weapon, at: now) else { return false }
		guard now - lastWeaponShotTime >= profile.shotInterval else { return false }

		if !weapon.hasAmmoLoaded {
			if weapon.canReload {
				reload(weapon, profile: profile)
			}
			return false
		}

		lastWeaponShotTime = now
		if weapon.clipAmmo > 0 {
			weapon.clipAmmo -= 1
		}
		refreshPlayerStatusHud()

		for _ in 0..<profile.pelletCount {
			shootFromCamera(profile: profile)
		}
		if let fireAnimationName = playWeaponAnimation(weapon: weapon, profile: profile, action: "fire") {
			scheduleShotgunPumpAnimationIfNeeded(weapon: weapon, afterFireAnimation: fireAnimationName)
		}
		playWeaponSound(profile.fireSoundName)
		showMuzzleFlash()
		return true
	}

	private func isReloading(_ weapon: Weapon, at time: TimeInterval = Date.timeIntervalSinceReferenceDate) -> Bool {
		guard reloadingWeaponUUID == weapon.uuid else { return false }
		if time < weaponReloadEndTime {
			return true
		}
		reloadingWeaponUUID = nil
		weaponReloadEndTime = 0
		return false
	}

	private func reloadDuration(weapon: Weapon, profile: Weapon.Profile) -> TimeInterval {
		let stance = playerController?.isPlayerCrouching == true ? "drep" : "stoj"
		guard let animationName = weaponAnimationName(weapon: weapon, profile: profile, stance: stance, action: "reload"),
			  let animation = try? loadAnimation(named: animationName) else {
			return 1.0
		}
		return max(0.2, animation.1)
	}

	private func beginBatCharge() {
		guard mode == .walk,
			  activeBatChargeStartedAt == nil,
			  equippedPlayerWeapon()?.isBaseballBat == true else { return }

	activeBatChargeStartedAt = Date.timeIntervalSinceReferenceDate
	updateHud { hud in
		hud.updateVehicleStealProgress(0, isVisible: true, label: "Swing force")
	}
	playBaseballBatWindupAnimation()
	}

	private func updateBatCharge() {
		guard let startedAt = activeBatChargeStartedAt else { return }
		guard isControlPressed(.FIRE),
			  mode == .walk,
			  equippedPlayerWeapon()?.isBaseballBat == true else {
			cancelBatCharge()
			return
		}

	let elapsed = Date.timeIntervalSinceReferenceDate - startedAt
	updateHud { hud in
		hud.updateVehicleStealProgress(CGFloat(elapsed / self.batChargeDuration), isVisible: true, label: "Swing force")
	}
	}

	private func releaseBatCharge() {
		guard let startedAt = activeBatChargeStartedAt else { return }

	activeBatChargeStartedAt = nil
	updateHud { hud in
		hud.updateVehicleStealProgress(0, isVisible: false)
	}
		guard mode == .walk,
			  equippedPlayerWeapon()?.isBaseballBat == true else { return }

		let elapsed = Date.timeIntervalSinceReferenceDate - startedAt
		let charge = SCNFloat(max(0.15, min(elapsed / batChargeDuration, 1)))
		playBaseballBatHitAnimation()
		swingBaseballBat(charge: charge)
		scene.triggerPlayerFireEvent()
	}

	private func cancelBatCharge() {
		activeBatChargeStartedAt = nil
		updateHud { hud in
			hud.updateVehicleStealProgress(0, isVisible: false)
		}
	}

	private func updateNPCHealthLabels() {
		var visibleHumanIds = Set<ObjectIdentifier>()
		for humanNode in npcHumanNodes() {
			let id = ObjectIdentifier(humanNode)
			visibleHumanIds.insert(id)
			let labelNode = npcHealthLabelNodes[id] ?? makeNPCHealthLabelNode(for: humanNode)
			npcHealthLabelNodes[id] = labelNode

			if labelNode.parent == nil {
				scene.rootNode.addChildNode(labelNode)
			}
			updateNPCHealthLabel(labelNode, for: humanNode)
		}

		let staleIds = npcHealthLabelNodes.keys.filter { !visibleHumanIds.contains($0) }
		for id in staleIds {
			npcHealthLabelNodes[id]?.removeFromParentNode()
			npcHealthLabelNodes[id] = nil
		}
	}

	private func npcHumanNodes() -> [SCNNode] {
		var nodes: [SCNNode] = []
		collectNPCHumanNodes(in: scene.rootNode, nodes: &nodes)
		return nodes
	}

	private func collectNPCHumanNodes(in node: SCNNode, nodes: inout [SCNNode]) {
		if isNPCHumanNode(node) {
			nodes.append(node)
			return
		}
		for child in node.childNodes {
			collectNPCHumanNodes(in: child, nodes: &nodes)
		}
	}

	private func isNPCHumanNode(_ node: SCNNode) -> Bool {
		guard !isNPCHealthLabelNode(node),
			  node.humanEnergy != nil || node.type.hasDefaultHumanEnergy,
			  !isNode(node, inside: scene.playerNode),
			  !isNodeHiddenInHierarchy(node) else {
			return false
		}
		if node.humanEnergy == nil {
			node.humanEnergy = 100
		}
		return true
	}

	private func makeNPCHealthLabelNode(for humanNode: SCNNode) -> SCNNode {
		let text = SCNText(string: "", extrusionDepth: 0.01)
		text.flatness = 0.2
		text.firstMaterial = npcHealthLabelMaterial()

		let labelNode = SCNNode(geometry: text)
		labelNode.name = "\(npcHealthLabelNodeNamePrefix)\(ObjectIdentifier(humanNode).hashValue)__"
		labelNode.scale = SCNVector3(x: -0.007, y: 0.007, z: 0.007)
		labelNode.constraints = [SCNBillboardConstraint()]
		labelNode.renderingOrder = 1000
		return labelNode
	}

	private func updateNPCHealthLabel(_ labelNode: SCNNode, for humanNode: SCNNode) {
		let health = max(0, Int(round(humanNode.humanEnergy ?? 100)))
		let label = "\(npcDisplayName(for: humanNode))\n\(health)"
		if let text = labelNode.geometry as? SCNText, text.string as? String != label {
			text.string = label
			let bounds = text.boundingBox
			labelNode.pivot = SCNMatrix4MakeTranslation(
				(bounds.min.x + bounds.max.x) / 2,
				bounds.min.y,
				0
			)
		}
		labelNode.position = scene.rootNode.convertPosition(npcHealthLabelPosition(for: humanNode), from: nil)
		labelNode.isHidden = health <= 0
	}

	private func npcDisplayName(for humanNode: SCNNode) -> String {
		let name = humanNode.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		return name.isEmpty ? "<unnamed>" : name
	}

	private func npcHealthLabelPosition(for humanNode: SCNNode) -> SCNVector3 {
		let bounds = humanNode.boundingBox
		let hasBounds = bounds.max.x > bounds.min.x || bounds.max.y > bounds.min.y || bounds.max.z > bounds.min.z
		guard hasBounds else {
			let position = humanNode.presentation.worldPosition
			return SCNVector3(x: position.x, y: position.y + 2.0, z: position.z)
		}

		let localTop = SCNVector3(
			x: (bounds.min.x + bounds.max.x) / 2,
			y: bounds.max.y,
			z: (bounds.min.z + bounds.max.z) / 2
		)
		let worldTop = humanNode.presentation.convertPosition(localTop, to: nil)
		return SCNVector3(x: worldTop.x, y: worldTop.y + 0.35, z: worldTop.z)
	}

	private func npcHealthLabelMaterial() -> SCNMaterial {
		let material = SCNMaterial()
		material.lightingModel = .constant
		material.diffuse.contents = SKColor.white
		material.emission.contents = SKColor.white
		material.isDoubleSided = true
		material.writesToDepthBuffer = false
		return material
	}

	private func swingBaseballBat(charge: SCNFloat) {
		let origin = cameraNode.presentation.worldPosition
		let cameraForward = cameraNode.presentation.worldFront
		let direction = normalized(SCNVector3(x: -cameraForward.x, y: -cameraForward.y, z: -cameraForward.z))
		let target = SCNVector3(
			x: origin.x + direction.x * batRange,
			y: origin.y + direction.y * batRange,
			z: origin.z + direction.z * batRange
		)

		let hits = scnScene.rootNode.hitTestWithSegment(
			from: origin,
			to: target,
			options: [
				SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
				SCNHitTestOption.backFaceCulling.rawValue: false
			]
		)

		for hit in hits {
			if isIgnoredCombatHitNode(hit.node) ||
			   isNode(hit.node, inside: scene.playerNode) ||
			   isNode(hit.node, inside: vehicle?.node) ||
			   isNode(hit.node, inside: heldWeaponNode) {
				continue
			}

			if let hitNode = shootableNode(from: hit.node) {
				let impulse = batMinImpulse + (batMaxImpulse - batMinImpulse) * charge
				let damagedHuman = applyHumanDamage(to: hit.node, amount: impulse)
				if let body = hitNode.physicsBody {
					applyMeleeImpact(
						to: body,
						node: hitNode,
						at: hit.worldCoordinates,
						direction: direction,
						impulse: impulse
					)
				} else if !damagedHuman {
					hitNode.position += SCNVector3(x: direction.x * charge, y: 0.12 * charge, z: direction.z * charge)
				}
				showImpact(at: hit.worldCoordinates, normal: hit.worldNormal)
				return
			}
		}
	}

	private func playBaseballBatWindupAnimation() {
		guard scene.playerNode != nil,
			  let animationName = firstExistingAnimation(named: [
				"anims/boj basb naprah hpt.5ds",
				"anims/boj hpt basb rh.5ds",
				"anims/boj hpt basb lh.5ds"
			  ]) else { return }

		playPlayerActionAnimation(named: animationName, animationKey: "__bat_swing__")
	}

	private func playBaseballBatHitAnimation() {
		guard scene.playerNode != nil else { return }

		let candidates = [
			"anims/boj basb z rh.5ds",
			"anims/boj basb z lh.5ds",
			"anims/boj basb z rs.5ds",
			"anims/boj basb z ls.5ds",
			"anims/boj basb kombo.5ds",
			"anims/boj hpt basb rh.5ds",
			"anims/boj hpt basb lh.5ds",
			"anims/boj hpt basb rs.5ds",
			"anims/boj hpt basb ls.5ds"
		]
		let startIndex = batSwingAnimationIndex % candidates.count
		let orderedCandidates = Array(candidates[startIndex...]) + Array(candidates[..<startIndex])
		guard let animationName = firstExistingAnimation(named: orderedCandidates) else { return }

		batSwingAnimationIndex += 1
		playPlayerActionAnimation(named: animationName, animationKey: "__bat_swing__")
	}

	private func shootFromCamera(profile: Weapon.Profile) {
		let origin = cameraNode.presentation.worldPosition
		let cameraForward = cameraNode.presentation.worldFront
		let direction = spreadDirection(
			from: SCNVector3(x: -cameraForward.x, y: -cameraForward.y, z: -cameraForward.z),
			spread: profile.spread
		)
		let target = SCNVector3(
			x: origin.x + direction.x * profile.range,
			y: origin.y + direction.y * profile.range,
			z: origin.z + direction.z * profile.range
		)
		let hits = scnScene.rootNode.hitTestWithSegment(
			from: origin,
			to: target,
			options: [
				SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
				SCNHitTestOption.backFaceCulling.rawValue: false
			]
		)

		var tracerEnd = target
		for hit in hits {
			if isIgnoredCombatHitNode(hit.node) ||
			   isNode(hit.node, inside: scene.playerNode) ||
			   isNode(hit.node, inside: vehicle?.node) {
				continue
			}

			tracerEnd = hit.worldCoordinates
			if let hitNode = shootableNode(from: hit.node) {
				let damagedHuman = applyHumanDamage(to: hit.node, amount: profile.impulse)
				if let body = hitNode.physicsBody {
					applyShotImpact(
						to: body,
						node: hitNode,
						at: hit.worldCoordinates,
						direction: direction,
						impulse: profile.impulse
					)
				} else if !damagedHuman {
					hitNode.position += SCNVector3(x: direction.x * 1.2, y: 0.2, z: direction.z * 1.2)
				}
			}
			showImpact(at: hit.worldCoordinates, normal: hit.worldNormal)
			showTracer(from: origin, to: tracerEnd)
			return
		}
		showTracer(from: origin, to: tracerEnd)
	}

	private func applyShotImpact(to body: SCNPhysicsBody, node: SCNNode, at hitPosition: SCNVector3, direction: SCNVector3, impulse: SCNFloat) {
		let scaledImpulse = impulse * 0.01
		let linearImpulse = SCNVector3(
			x: direction.x * scaledImpulse,
			y: direction.y * scaledImpulse + min(0.08, scaledImpulse * 0.05),
			z: direction.z * scaledImpulse
		)
		body.applyForce(linearImpulse, at: hitPosition, asImpulse: true)

		guard body.type == .dynamic else { return }

		let center = node.presentation.worldPosition
		let lever = hitPosition - center
		var torqueAxis = cross(lever, linearImpulse)
		if torqueAxis.length < 0.001 {
			torqueAxis = cross(SCNVector3(x: 0, y: 1, z: 0), direction)
		}
		torqueAxis = normalized(torqueAxis)
		let angularImpulse = max(0.02, impulse * 0.004)
		body.applyTorque(
			SCNVector4(x: torqueAxis.x, y: torqueAxis.y, z: torqueAxis.z, w: angularImpulse),
			asImpulse: true
		)
	}

	private func applyMeleeImpact(to body: SCNPhysicsBody, node: SCNNode, at hitPosition: SCNVector3, direction: SCNVector3, impulse: SCNFloat) {
		let linearImpulse = SCNVector3(
			x: direction.x * impulse,
			y: direction.y * impulse + min(1.2, impulse * 0.12),
			z: direction.z * impulse
		)
		body.applyForce(linearImpulse, at: hitPosition, asImpulse: true)

		guard body.type == .dynamic else { return }

		let center = node.presentation.worldPosition
		let lever = hitPosition - center
		var torqueAxis = cross(lever, linearImpulse)
		if torqueAxis.length < 0.001 {
			torqueAxis = cross(SCNVector3(x: 0, y: 1, z: 0), direction)
		}
		torqueAxis = normalized(torqueAxis)
		let angularImpulse = max(0.08, impulse * 0.08)
		body.applyTorque(
			SCNVector4(x: torqueAxis.x, y: torqueAxis.y, z: torqueAxis.z, w: angularImpulse),
			asImpulse: true
		)
	}

	@discardableResult
	private func applyHumanDamage(to node: SCNNode, amount: SCNFloat) -> Bool {
		guard let humanNode = humanNode(from: node) else { return false }

		let currentEnergy = humanNode.humanEnergy ?? 100
		let newEnergy = max(0, currentEnergy - Float(amount))
		humanNode.humanEnergy = newEnergy
		if isNode(humanNode, inside: scene.playerNode) {
			setPlayerHealth(Int(round(newEnergy)))
		}
		return true
	}

	private func humanNode(from node: SCNNode) -> SCNNode? {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.humanEnergy != nil {
				return candidate
			}
			if candidate.type.hasDefaultHumanEnergy {
				candidate.humanEnergy = 100
				return candidate
			}
			current = candidate.parent
		}
		return nil
	}

	func equippedPlayerWeapon() -> Weapon? {
		guard let playerNode = scene.playerNode else { return nil }
		return scene.weapons(for: playerNode).first { $0.position == .hand }
	}

	private func equippedPlayerMovementAnimationSetId() -> Int? {
		guard let weapon = equippedPlayerWeapon() else { return nil }
		return standingPlayerAnimationSetId(for: weapon)
	}

	func refreshPlayerStatusHud() {
		let weapon = equippedPlayerWeapon()
		syncHeldPlayerWeapon(weapon)
		let health = playerHealth
		updateHud { hud in
			hud.updatePlayerStatus(health: health, weapon: weapon)
		}
	}

	private func syncHeldPlayerWeapon(_ weapon: Weapon?) {
		guard let playerNode = scene.playerNode,
			  let weapon = weapon,
			  weapon.isFirearm || weapon.isBaseballBat else {
			removeHeldPlayerWeapon()
			return
		}
		if heldWeaponUUID == weapon.uuid,
		   heldWeaponNode?.parent != nil,
		   staleHeldWeaponNodes(in: playerNode).isEmpty {
			return
		}

		removeHeldPlayerWeapon()
		guard let modelNode = loadHeldWeaponModel(for: weapon) else { return }

		modelNode.name = "\(heldWeaponNodeNamePrefix)\(weapon.id)__"
		modelNode.physicsBody = nil
		modelNode.disablePhysicsInHierarchy()
		let anchor = heldWeaponAnchor(in: playerNode)
		anchor.addChildNode(modelNode)
		positionHeldWeapon(modelNode, weapon: weapon, anchor: anchor, playerNode: playerNode)

		heldWeaponNode = modelNode
		heldWeaponUUID = weapon.uuid
	}

	private func removeHeldPlayerWeapon() {
		heldWeaponNode?.removeFromParentNode()
		if let playerNode = scene.playerNode {
			for node in heldWeaponNodes(in: playerNode) {
				node.removeFromParentNode()
			}
		}
		heldWeaponNode = nil
		heldWeaponUUID = nil
	}

	private func staleHeldWeaponNodes(in rootNode: SCNNode) -> [SCNNode] {
		return heldWeaponNodes(in: rootNode).filter { $0 !== heldWeaponNode }
	}

	private func heldWeaponNodes(in rootNode: SCNNode) -> [SCNNode] {
		var nodes: [SCNNode] = []
		collectHeldWeaponNodes(in: rootNode, nodes: &nodes)
		return nodes
	}

	private func collectHeldWeaponNodes(in node: SCNNode, nodes: inout [SCNNode]) {
		if node.name?.hasPrefix(heldWeaponNodeNamePrefix) == true {
			nodes.append(node)
		}
		for child in node.childNodes {
			collectHeldWeaponNodes(in: child, nodes: &nodes)
		}
	}

	private func loadHeldWeaponModel(for weapon: Weapon) -> SCNNode? {
		let rawModelName = weapon.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !rawModelName.isEmpty else { return nil }

		let normalizedModelName = rawModelName.replacingOccurrences(of: "\\", with: "/")
		let modelName = (normalizedModelName as NSString).deletingPathExtension
		let modelPath = modelName.contains("/") ? modelName : "models/" + modelName
		guard let node = try? loadModel(named: modelPath), node.hasModelContent else { return nil }
		return node
	}

	private func heldWeaponAnchor(in playerNode: SCNNode) -> SCNNode {
		let handNodeNames = [
			"Bip01 R Hand",
			"Bip01 R Forearm",
			"R Hand",
			"Right Hand",
			"rhand",
			"r_hand",
			"hand_r",
			"right_hand",
			"ruka prava",
			"prava ruka"
		]

		for name in handNodeNames {
			if let node = playerNode.mafiaChildNode(named: name, recursively: true) {
				return node
			}
		}
		return playerNode
	}

	private func positionHeldWeapon(_ weaponNode: SCNNode, weapon: Weapon, anchor: SCNNode, playerNode: SCNNode) {
		weaponNode.scale = SCNVector3(x: 1, y: 1, z: 1)
		if anchor === playerNode {
			if weapon.isBaseballBat {
				weaponNode.position = SCNVector3(x: 0.3, y: 0.95, z: -0.12)
				weaponNode.eulerAngles = SCNVector3(x: 0.25, y: .pi / 2, z: .pi / 2)
			} else {
				weaponNode.position = SCNVector3(x: 0.33, y: 1.02, z: -0.18)
				weaponNode.eulerAngles = SCNVector3(x: -0.08, y: .pi / 2, z: -0.18)
			}
		} else {
			if weapon.isBaseballBat {
				weaponNode.position = SCNVector3(x: 0.03, y: -0.06, z: 0.02)
				weaponNode.eulerAngles = SCNVector3(x: 0, y: .pi / 2, z: .pi / 2)
			} else {
				weaponNode.position = SCNVector3(x: 0.05, y: -0.03, z: 0.02)
				weaponNode.eulerAngles = SCNVector3(x: 0, y: .pi / 2, z: 0)
			}
		}
	}

	private func spreadDirection(from direction: SCNVector3, spread: SCNFloat) -> SCNVector3 {
		guard spread > 0 else { return normalized(direction) }

		let cameraTransform = cameraNode.presentation.worldTransform
		let right = normalized(SCNVector3(x: cameraTransform.m11, y: cameraTransform.m12, z: cameraTransform.m13))
		let up = normalized(SCNVector3(x: cameraTransform.m21, y: cameraTransform.m22, z: cameraTransform.m23))
		let xSpread = randomSpread() * spread
		let ySpread = randomSpread() * spread
		return normalized(SCNVector3(
			x: direction.x + right.x * xSpread + up.x * ySpread,
			y: direction.y + right.y * xSpread + up.y * ySpread,
			z: direction.z + right.z * xSpread + up.z * ySpread
		))
	}

	private func randomSpread() -> SCNFloat {
		return SCNFloat(arc4random_uniform(2001)) / 1000 - 1
	}

	private func normalized(_ vector: SCNVector3) -> SCNVector3 {
		let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
		guard length > 0.0001 else { return SCNVector3(x: 0, y: 0, z: -1) }
		return SCNVector3(x: vector.x / length, y: vector.y / length, z: vector.z / length)
	}

	private func dot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNFloat {
		return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
	}

	private func cross(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNVector3 {
		return SCNVector3(
			x: lhs.y * rhs.z - lhs.z * rhs.y,
			y: lhs.z * rhs.x - lhs.x * rhs.z,
			z: lhs.x * rhs.y - lhs.y * rhs.x
		)
	}

	private func normalizedHorizontalVector(_ vector: SCNVector3, fallback: SCNVector3) -> SCNVector3 {
		let length = sqrt(vector.x * vector.x + vector.z * vector.z)
		guard length > 0.0001 else { return fallback }
		return SCNVector3(x: vector.x / length, y: 0, z: vector.z / length)
	}

	private func showMuzzleFlash() {
		let flash = SCNNode()
		flash.name = "__muzzle_flash__"
		flash.position = SCNVector3(x: 0, y: -0.09, z: -0.55)
		cameraNode.addChildNode(flash)

		let core = SCNNode(geometry: SCNSphere(radius: 0.055))
		core.geometry?.firstMaterial = emissiveMaterial(color: SKColor.yellow)
		flash.addChildNode(core)

		let flare = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.32))
		flare.geometry?.firstMaterial = emissiveMaterial(color: SKColor.orange.withAlphaComponent(0.86))
		flare.eulerAngles.x = .pi / 2
		flare.position.z = -0.16
		flash.addChildNode(flare)

		let light = SCNNode()
		light.light = SCNLight()
		light.light?.type = .omni
		light.light?.color = SKColor.orange
		light.light?.intensity = 850
		light.light?.attenuationEndDistance = 6
		flash.addChildNode(light)

		for index in 0..<3 {
			let smoke = SCNNode(geometry: SCNSphere(radius: 0.035 + CGFloat(index) * 0.012))
			smoke.name = "__muzzle_smoke__"
			smoke.geometry?.firstMaterial = transparentMaterial(color: SKColor.lightGray.withAlphaComponent(0.28))
			smoke.position = SCNVector3(
				x: randomSpread() * 0.03,
				y: randomSpread() * 0.025,
				z: -0.12 - SCNFloat(index) * 0.05
			)
			flash.addChildNode(smoke)
			smoke.runAction(SCNAction.group([
				SCNAction.moveBy(x: CGFloat(randomSpread() * 0.04), y: CGFloat(0.04 + randomSpread() * 0.02), z: -0.08, duration: 0.18),
				SCNAction.scale(to: 2.2, duration: 0.18),
				SCNAction.fadeOut(duration: 0.18)
			]))
		}

		flash.runAction(SCNAction.sequence([
			SCNAction.wait(duration: 0.035),
			SCNAction.fadeOut(duration: 0.04),
			SCNAction.removeFromParentNode()
		]))
	}

	private func playWeaponSound(_ soundName: String?) {
		guard let soundName = soundName, !soundName.isEmpty else { return }

		let normalizedName = soundName.lowercased()
		let source: SCNAudioSource
		if let cachedSource = weaponAudioSources[normalizedName] {
			source = cachedSource
		} else {
			guard let url = mafiaResourceURL(directory: "sounds", name: normalizedName),
				  let loadedSource = SCNAudioSource(url: url) else { return }
			loadedSource.load()
			weaponAudioSources[normalizedName] = loadedSource
			source = loadedSource
		}
		scene.playAudio(source, on: cameraNode)
	}

	@discardableResult
	private func playWeaponAnimation(weapon: Weapon, profile: Weapon.Profile, action: String) -> String? {
		guard profile.animationSetId > 0,
			  scene.playerNode != nil else { return nil }

		let stance = playerController?.isPlayerCrouching == true ? "drep" : "stoj"
		guard let animationName = weaponAnimationName(weapon: weapon, profile: profile, stance: stance, action: action) else { return nil }
		playPlayerActionAnimation(named: animationName, animationKey: "__weapon_\(action)__")
		return animationName
	}

	private func playPlayerActionAnimation(named animationName: String, animationKey: String) {
		if let playerController = playerController {
			playerController.playActionAnimation(named: animationName, animationKey: animationKey)
		} else if let playerNode = scene.playerNode {
			try? playPlayerAnimation(named: animationName, in: playerNode, animationKey: animationKey)
		}
	}

	private func playWeaponToggleAnimation() {
		guard let animationName = genericWeaponAnimationName(action: "on off") else { return }
		playPlayerActionAnimation(named: animationName, animationKey: "__weapon_toggle__")
	}

	private func playWeaponDropAnimation() {
		guard let animationName = genericWeaponAnimationName(action: "zahozeni") else { return }
		playPlayerActionAnimation(named: animationName, animationKey: "__weapon_drop__")
	}

	private func genericWeaponAnimationName(action: String) -> String? {
		let stance = playerController?.isPlayerCrouching == true ? "drep" : "stoj"
		var candidates = ["anims/gun \(stance) \(action).5ds"]
		if stance != "stoj" {
			candidates.append("anims/gun stoj \(action).5ds")
		}
		return firstExistingAnimation(named: candidates)
	}

	private func scheduleShotgunPumpAnimationIfNeeded(weapon: Weapon, afterFireAnimation fireAnimationName: String) {
		guard weapon.id == 11 || weapon.id == 34,
			  let playerNode = scene.playerNode else { return }

		let stance = playerController?.isPlayerCrouching == true ? "drep" : "stoj"
		guard let animationName = firstExistingAnimation(named: [
			"anims/gun08 \(stance) Pump.5ds",
			"anims/gun08 stoj Pump.5ds"
		]) else { return }

		let delay = (try? animationDuration(named: fireAnimationName)) ?? 0.2
		playerNode.runAction(SCNAction.sequence([
			SCNAction.wait(duration: delay),
			SCNAction.run { [weak self] _ in
				guard self?.mode == .walk else { return }
				self?.playPlayerActionAnimation(named: animationName, animationKey: "__weapon_pump__")
			}
		]), forKey: "__weapon_pump_schedule__")
	}

	private func weaponAnimationName(weapon: Weapon, profile: Weapon.Profile, stance: String, action: String) -> String? {
		let animationSetIds = weaponAnimationSetCandidates(weapon: weapon, profile: profile, stance: stance)
		let prefersStrafe = action == "fire" &&
			playerController?.isPlayerStrafingForWeaponAnimation == true

		var candidates: [String] = []
		for animationSetId in animationSetIds {
			let animationPrefix = "gun" + String(format: "%02d", animationSetId)
			if prefersStrafe {
				candidates.append("anims/\(animationPrefix) \(stance) \(action) Straf.5ds")
			}
			candidates.append("anims/\(animationPrefix) \(stance) \(action).5ds")
			if stance != "stoj" {
				if prefersStrafe {
					candidates.append("anims/\(animationPrefix) stoj \(action) Straf.5ds")
				}
				candidates.append("anims/\(animationPrefix) stoj \(action).5ds")
			}
		}
		return firstExistingAnimation(named: candidates)
	}

	private func weaponAnimationSetCandidates(weapon: Weapon, profile: Weapon.Profile, stance: String) -> [Int] {
		var animationSetIds = [profile.animationSetId]
		if stance == "drep" {
			animationSetIds.append(crouchedPlayerAnimationSetId(forStandingSetId: standingPlayerAnimationSetId(for: weapon)))
		}
		animationSetIds.append(standingPlayerAnimationSetId(for: weapon))
		return uniqueValidAnimationSetIds(animationSetIds)
	}

	private func standingPlayerAnimationSetId(for weapon: Weapon) -> Int {
		if weapon.isBaseballBat {
			return 1
		}
		switch weapon.id {
		case 6, 7, 8, 9:
			return 2
		case 12:
			return 4
		case 10, 11, 13, 14, 33, 34:
			return 5
		default:
			if let animationSetId = weapon.profile?.animationSetId,
			   (1...8).contains(animationSetId) {
				return animationSetId
			}
			return 1
		}
	}

	private func crouchedPlayerAnimationSetId(forStandingSetId animationSetId: Int) -> Int {
		switch animationSetId {
		case 1:
			return 6
		case 2, 3:
			return 7
		default:
			return 8
		}
	}

	private func uniqueValidAnimationSetIds(_ animationSetIds: [Int]) -> [Int] {
		var seen = Set<Int>()
		var uniqueIds: [Int] = []
		for animationSetId in animationSetIds where (1...8).contains(animationSetId) && !seen.contains(animationSetId) {
			seen.insert(animationSetId)
			uniqueIds.append(animationSetId)
		}
		return uniqueIds
	}

	private func firstExistingAnimation(named candidates: [String]) -> String? {
		return candidates.first { animationExists(named: $0) }
	}

	private func animationExists(named animationName: String) -> Bool {
		let url = mainDirectory.appendingPathComponent(animationName.lowercased())
		return FileManager.default.fileExists(atPath: url.path)
	}

	private func showTracer(from origin: SCNVector3, to target: SCNVector3) {
		let direction = normalized(target - origin)
		let start = origin + SCNVector3(x: direction.x * 0.75, y: direction.y * 0.75, z: direction.z * 0.75)
		let end = target
		guard (end - start).length > 0.2 else { return }

		let tracer = cylinderNode(
			from: start,
			to: end,
			radius: 0.006,
			material: emissiveMaterial(color: SKColor.yellow.withAlphaComponent(0.72))
		)
		tracer.name = "__bullet_tracer__"
		scnScene.rootNode.addChildNode(tracer)
		tracer.runAction(SCNAction.sequence([
			SCNAction.fadeOut(duration: 0.055),
			SCNAction.removeFromParentNode()
		]))
	}

	private func showImpact(at position: SCNVector3, normal: SCNVector3) {
		let surfaceNormal = normalized(normal)
		let liftedPosition = position + SCNVector3(
			x: surfaceNormal.x * 0.012,
			y: surfaceNormal.y * 0.012,
			z: surfaceNormal.z * 0.012
		)

		let impact = SCNNode(geometry: SCNPlane(width: 0.12, height: 0.12))
		impact.name = "__bullet_impact__"
		impact.position = liftedPosition
		impact.geometry?.firstMaterial = transparentMaterial(color: SKColor.black.withAlphaComponent(0.55))
		impact.look(at: liftedPosition + surfaceNormal)
		scnScene.rootNode.addChildNode(impact)
		impact.runAction(SCNAction.sequence([
			SCNAction.wait(duration: 5),
			SCNAction.fadeOut(duration: 0.6),
			SCNAction.removeFromParentNode()
		]))

		let sparkMaterial = emissiveMaterial(color: SKColor.orange)
		for _ in 0..<5 {
			let tangent = normalized(cross(surfaceNormal, abs(surfaceNormal.y) < 0.8 ? SCNVector3(x: 0, y: 1, z: 0) : SCNVector3(x: 1, y: 0, z: 0)))
			let bitangent = normalized(cross(surfaceNormal, tangent))
			let sparkDirection = normalized(SCNVector3(
				x: surfaceNormal.x * 0.7 + tangent.x * randomSpread() + bitangent.x * randomSpread(),
				y: surfaceNormal.y * 0.7 + tangent.y * randomSpread() + bitangent.y * randomSpread(),
				z: surfaceNormal.z * 0.7 + tangent.z * randomSpread() + bitangent.z * randomSpread()
			))
			let sparkEnd = liftedPosition + SCNVector3(
				x: sparkDirection.x * SCNFloat(0.18 + abs(randomSpread()) * 0.22),
				y: sparkDirection.y * SCNFloat(0.18 + abs(randomSpread()) * 0.22),
				z: sparkDirection.z * SCNFloat(0.18 + abs(randomSpread()) * 0.22)
			)
			let spark = cylinderNode(from: liftedPosition, to: sparkEnd, radius: 0.004, material: sparkMaterial)
			spark.name = "__bullet_spark__"
			scnScene.rootNode.addChildNode(spark)
			spark.runAction(SCNAction.sequence([
				SCNAction.group([
					SCNAction.moveBy(x: CGFloat(sparkDirection.x * 0.06), y: CGFloat(sparkDirection.y * 0.06), z: CGFloat(sparkDirection.z * 0.06), duration: 0.12),
					SCNAction.fadeOut(duration: 0.12)
				]),
				SCNAction.removeFromParentNode()
			]))
		}
	}

	private func cylinderNode(from start: SCNVector3, to end: SCNVector3, radius: CGFloat, material: SCNMaterial) -> SCNNode {
		let vector = end - start
		let length = CGFloat(vector.length)
		let node = SCNNode(geometry: SCNCylinder(radius: radius, height: length))
		node.geometry?.firstMaterial = material
		node.position = SCNVector3(
			x: (start.x + end.x) / 2,
			y: (start.y + end.y) / 2,
			z: (start.z + end.z) / 2
		)
		alignYAxis(of: node, to: normalized(vector))
		return node
	}

	private func alignYAxis(of node: SCNNode, to direction: SCNVector3) {
		let yAxis = SCNVector3(x: 0, y: 1, z: 0)
		let axis = cross(yAxis, direction)
		let axisLength = axis.length
		let clampedDot = max(SCNFloat(-1), min(SCNFloat(1), dot(yAxis, direction)))
		if axisLength < 0.0001 {
			node.rotation = clampedDot < 0 ? SCNVector4(x: 1, y: 0, z: 0, w: .pi) : SCNVector4Zero
			return
		}
		node.rotation = SCNVector4(x: axis.x / SCNFloat(axisLength), y: axis.y / SCNFloat(axisLength), z: axis.z / SCNFloat(axisLength), w: acos(clampedDot))
	}

	private func emissiveMaterial(color: SKColor) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = color
		material.emission.contents = color
		material.lightingModel = .constant
		material.isDoubleSided = true
		return material
	}

	private func transparentMaterial(color: SKColor) -> SCNMaterial {
		let material = emissiveMaterial(color: color)
		material.transparency = color.rgbaComponents.alpha
		material.blendMode = .alpha
		material.writesToDepthBuffer = false
		return material
	}

	private func shootableNode(from node: SCNNode) -> SCNNode? {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.humanEnergy != nil || candidate.type.hasDefaultHumanEnergy {
				return candidate
			}
			if candidate.physicsBody?.type == .dynamic {
				return candidate
			}
			if let name = candidate.name?.lowercased(),
			   name.contains("plechovka") || name.contains("target") {
				return candidate
			}
			current = candidate.parent
		}
		return nil
	}

	private func isShotEffectNode(_ node: SCNNode) -> Bool {
		var current: SCNNode? = node
		while let candidate = current {
			if let name = candidate.name, name.hasPrefix("__bullet_") || name.hasPrefix("__muzzle_") {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	private func isIgnoredCombatHitNode(_ node: SCNNode) -> Bool {
		return isShotEffectNode(node) || isNPCHealthLabelNode(node)
	}

	private func isNPCHealthLabelNode(_ node: SCNNode) -> Bool {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.name?.hasPrefix(npcHealthLabelNodeNamePrefix) == true {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	private func isNodeHiddenInHierarchy(_ node: SCNNode) -> Bool {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.isHidden {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	private func isNode(_ node: SCNNode, inside root: SCNNode?) -> Bool {
		guard let root = root else { return false }
		var current: SCNNode? = node
		while let candidate = current {
			if candidate === root {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	func nearestAction() -> Action? {
		return availableActions().first
	}

	func availableActions() -> [Action] {
		if mode == .car {
			guard let vehicle = vehicle else { return [] }
			let scriptedActions = scriptedVehicleActions(for: vehicle)
			if !scriptedActions.isEmpty {
				return scriptedActions
			}
			return vehicleExitAction().map { [$0] } ?? []
		}

		guard mode == .walk,
			  let playerNode = scene.playerNode else { return [] }

		let playerPosition = playerNode.presentation.worldPosition
		var actions = scene.actions
		if let stealAction = stealableVehicleAction() {
			actions.append(stealAction)
		} else if let enterAction = enterableVehicleAction() {
			actions.append(enterAction)
		}
		return actions
			.filter { $0.isEnabled && $0.node.actionSquaredDistance(to: playerPosition) < actionDistanceSquared }
			.sorted { $0.node.actionSquaredDistance(to: playerPosition) < $1.node.actionSquaredDistance(to: playerPosition) }
	}

	private func useDoor(_ node: SCNNode) {
		guard let door = node.doorData else { return }
		guard node.action(forKey: "door") == nil else { return }

		#warning("Lock doors")
		/*if door.isLocked {
			playDoorSound(door.lockedSound, on: node)
			return
		}*/

		let currentEulerAngles = node.eulerAngles
		if door.closedEulerAngles == nil {
			let closedY = door.isOpen ? currentEulerAngles.y - door.initialOpenAngle(forUserSide: door.openDirection) : currentEulerAngles.y
			door.closedEulerAngles = SCNVector3(x: currentEulerAngles.x, y: closedY, z: currentEulerAngles.z)
		}

		let closedEulerAngles = door.closedEulerAngles ?? currentEulerAngles
		let duration: TimeInterval
		let targetEulerAngles: SCNVector3

		if door.isOpen {
			duration = door.closeSpeed
			targetEulerAngles = closedEulerAngles
			playDoorSound(door.closeSound, on: node)
		} else {
			door.openDirection = doorOpenDirection(for: node)
			duration = door.openSpeed
			targetEulerAngles = SCNVector3(
				x: closedEulerAngles.x,
				y: closedEulerAngles.y + door.initialOpenAngle(forUserSide: door.openDirection),
				z: closedEulerAngles.z
			)
			playDoorSound(door.openSound, on: node)
		}

		node.runAction(
			SCNAction.rotateTo(
				x: CGFloat(targetEulerAngles.x),
				y: CGFloat(targetEulerAngles.y),
				z: CGFloat(targetEulerAngles.z),
				duration: duration,
				usesShortestUnitArc: true
			),
			forKey: "door"
		) {
			door.isOpen = !door.isOpen
		}
	}

	private func doorOpenDirection(for node: SCNNode) -> Int {
		guard let playerNode = scene.playerNode else { return 0 }

		let vectorToPlayer = playerNode.presentation.worldPosition - node.presentation.worldPosition
		let forward = node.presentation.worldFront
		let dot = vectorToPlayer.x * forward.x + vectorToPlayer.y * forward.y + vectorToPlayer.z * forward.z
		return dot > 0 ? 0 : 1
	}

	private func playDoorSound(_ soundName: String, on node: SCNNode) {
		guard !soundName.isEmpty else { return }

		let normalizedName = soundName.lowercased().replacingOccurrences(of: ".wav", with: "") + ".wav"
		let url = mainDirectory.appendingPathComponent("sounds/" + normalizedName)
		guard let source = SCNAudioSource(url: url) else { return }
		source.load()
		scene.playAudio(source, on: node)
	}

	func openInventory() {
		updateHud { hud in
			hud.toggleInventory()
		}
	}

}

private struct RoadMapBounds {
	private static let artworkCalibrationOffset = CGPoint(x: -0.06, y: 0.14)

	let minX: SCNFloat
	let maxX: SCNFloat
	let minZ: SCNFloat
	let maxZ: SCNFloat

	init?(road: Road) {
		let positions = road.waypoints.map(\.position) + road.crossroads.map(\.position)
		guard let first = positions.first else { return nil }

		var minX = first.x
		var maxX = first.x
		var minZ = first.z
		var maxZ = first.z
		for position in positions.dropFirst() {
			minX = min(minX, position.x)
			maxX = max(maxX, position.x)
			minZ = min(minZ, position.z)
			maxZ = max(maxZ, position.z)
		}

		guard maxX > minX, maxZ > minZ else { return nil }

		self.minX = minX
		self.maxX = maxX
		self.minZ = minZ
		self.maxZ = maxZ
	}

	func normalizedPoint(for position: SCNVector3) -> CGPoint {
		let x = CGFloat((position.x - minX) / (maxX - minX))
		let y = CGFloat((position.z - minZ) / (maxZ - minZ))
		return CGPoint(
			x: max(0, min(1, x + Self.artworkCalibrationOffset.x)),
			y: max(0, min(1, y + Self.artworkCalibrationOffset.y))
		)
	}
}
