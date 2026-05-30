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

final class Game: NSObject {

	enum DodgeDirection {
		case left
		case right
	}

	enum Mode {
		case walk, car, freeCamera
	}

	var hud: HudScene!

	let scnScene = SCNScene()
	let cameraContainer = SCNNode()
	let cameraNode = SCNNode()
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
				scnScene.rootNode.addChildNode(cameraContainer)
				playerController?.stop()
				vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
				vehicle?.applyForces()
			} else if mode == .walk {
				scene.playerNode?.isHidden = false
				if oldValue != .freeCamera {
					teleportPlayerBesideVehicle()
				}
				if let playerNode = scene.playerNode {
					playerNode.addChildNode(cameraContainer)
				} else {
					scene.rootNode.addChildNode(cameraContainer)
				}
				playerController?.stop()
				vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
				vehicle?.applyForces()
			} else {
				playerController?.stop()
				scene.playerNode?.isHidden = true
				scnScene.rootNode.addChildNode(cameraContainer)
				resetCarCameraFollow()
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
	private(set) var isGamePaused = false
	private var lastUpdateTime: TimeInterval?
	private let playerExitDistance: SCNFloat = 1.8
	private let playerExitHeightOffset: SCNFloat = 0.5
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
	private var skyboxNodes: [(node: SCNNode, offset: SCNVector3)] = []
	private let skyboxFallbackNode = SCNNode()
	private var lastActionButtonUpdateTime: TimeInterval = 0
	private var isActionButtonVisible = false
	private let actionButtonUpdateInterval: TimeInterval = 0.15
	private let actionDistanceSquared: Float = 4
	private var lastWeaponShotTime: TimeInterval = 0
	private var weaponAudioSources: [String: SCNAudioSource] = [:]
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
	private var stealEnabledVehicleIds: Set<Int> = []
	private var stealVehicleNodes: [Int: SCNNode] = [:]
	private var stolenVehicleIds: Set<Int> = []
	private var activeSteal: (vehicle: Vehicle, startedAt: TimeInterval)?
	private let vehicleStealDuration: TimeInterval = 1.6

	init(missionName: String) throws {
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

		scene = try Scene(named: "missions/"+missionName)

		super.init()

		scene.game = self
		scene.rootNode.name = "__scene__"
		scnScene.rootNode.addChildNode(scene.rootNode)
		scene.resolvePendingDoors(in: scnScene.rootNode)
		scene.resolvePendingPhysicalObjects(in: scnScene.rootNode)
		scene.resolvePendingScripts(in: scnScene.rootNode)
		scene.resolvePendingObjectTypes(in: scnScene.rootNode)
		print("== Loaded Scene")

		if let sceneCache = try SceneCache(name: "missions/"+missionName) {
			scnScene.rootNode.addChildNode(sceneCache.node)
			sceneCache.node.name = "__cache__"
			print("== Loaded Scene Cache")
		}

		let collisions = try Collisions(name: "missions/"+missionName, scene: scnScene)
		collisions.node.name = "__colliions__"
		scnScene.rootNode.addChildNode(collisions.node)
		print("== Loaded Scene Collisions")

//		let floorNode = SCNNode()
//		floorNode.opacity = 0
//		let floor = SCNFloor()
//		floor.reflectivity = 0
//		floorNode.geometry = floor
//		floorNode.physicsBody = SCNPhysicsBody.static()
//		scnScene.rootNode.addChildNode(floorNode)

		// -----

		if scene.playerNode == nil {
			spawnPlayer()
		}

		// -----

		if let playerNode = scene.playerNode {
			playerNode.position.y += 0.5
			playerController = PlayerController(node: playerNode, scene: scnScene)
		}

		// -----

		vehicle = findVehicle()

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
	}

	private func spawnPlayer() {
		guard let playerNode = try? loadModel(named: "models/tommy") else { return }

		if let spawnNode = playerSpawnNode() {
			playerNode.transform = spawnNode.worldTransform
		}
		playerNode.name = "tommy"
		scene.playerNode = playerNode
		scnScene.rootNode.addChildNode(playerNode)
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

	private func findVehicle() -> Vehicle? {
		let preferredNames = [
			"cad_road",
			"taxi2"
		]
		for name in preferredNames {
			if let node = scnScene.rootNode.mafiaChildNode(named: name, recursively: true),
			   node.hasModelContent,
			   let vehicle = Vehicle(scene: scnScene, node: node) {
				return vehicle
			}
		}

		return scnScene.rootNode.firstResult { node in
			guard node.type == .car && node.hasModelContent else { return nil }
			return Vehicle(scene: scnScene, node: node)
		}
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
			cameraContainer.position = SCNVector3(x: 0, y: 1.35, z: 0)
			cameraNode.position = SCNVector3(x: 0, y: 1.25, z: -2.8)
			cameraNode.eulerAngles = SCNVector3(x: 0.15, y: .pi, z: .pi)
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

	func look(deltaX: SCNFloat, deltaY: SCNFloat) {
		guard !isGamePaused else { return }

		switch mode {
		case .walk:
			guard scene.playerNode != nil else { return }
			playerController?.look(deltaX: deltaX, deltaY: deltaY)
		case .car:
			carCameraYaw = normalizedAngle(carCameraYaw - deltaX)
			carCameraPitch = max(minCarCameraPitch, min(maxCarCameraPitch, carCameraPitch + deltaY))
			carCameraMouseIdleTime = 0
			applyCarCameraLook()
		case .freeCamera:
			freeCameraYaw = normalizedAngle(freeCameraYaw - deltaX)
			freeCameraPitch = max(minFreeCameraPitch, min(maxFreeCameraPitch, freeCameraPitch + deltaY))
			cameraContainer.eulerAngles = SCNVector3(x: freeCameraPitch, y: freeCameraYaw, z: 0)
		}
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
		guard let velocity = vehicle.node.physicsBody?.velocity else { return 0 }

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

		if let ambient = scene.environmentLights.bestMatch(kind: .ambient, cameraPosition: cameraPosition, rootNode: scnScene.rootNode) {
			let targetColor = ambient.color.multiplied(by: ambient.power)
			ambientLightNode.light?.color = (ambientLightNode.light?.color as? SKColor ?? .black).lerped(to: targetColor, amount: ambientBlend)
			ambientLightNode.light?.intensity = 100
		}

		if let fog = scene.environmentLights.bestMatch(kind: .fog, cameraPosition: cameraPosition, rootNode: scnScene.rootNode) {
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

		let vehiclePosition = vehicle.node.presentation.worldPosition
		let exitSide = horizontalVehicleRight()
		let exitPosition = SCNVector3(
			x: vehiclePosition.x + exitSide.x * playerExitDistance,
			y: vehicleBottomWorldY() + playerExitHeightOffset,
			z: vehiclePosition.z + exitSide.z * playerExitDistance
		)
		let forward = vehicle.node.presentation.worldFront
		let yaw = atan2(-forward.x, -forward.z)
		playerController.teleport(to: exitPosition, yaw: yaw)
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
		guard mode == .walk,
			  let playerNode = scene.playerNode,
			  time - lastActionButtonUpdateTime >= actionButtonUpdateInterval else {
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
			action.node.actionSquaredDistance(to: playerPosition) < actionDistanceSquared
		}
		setActionButtonVisible(hasNearbyAction)
	}

	private func setActionButtonVisible(_ isVisible: Bool) {
		guard isActionButtonVisible != isVisible else { return }

		isActionButtonVisible = isVisible
		hud.actionButton.isHidden = !isVisible
	}

	private func beginVehicleSteal(_ vehicle: Vehicle) {
		guard mode == .walk,
			  activeSteal == nil,
			  vehicleStealId(for: vehicle) != nil else { return }

		activeSteal = (vehicle, Date.timeIntervalSinceReferenceDate)
		hud?.showConsoleText("Stealing car...")
	}

	private func updateVehicleStealing() {
		guard let steal = activeSteal else { return }
		guard isControlPressed(.ACTION),
			  mode == .walk,
			  let playerNode = scene.playerNode,
			  steal.vehicle.node.actionSquaredDistance(to: playerNode.presentation.worldPosition) < actionDistanceSquared else {
			activeSteal = nil
			return
		}

		guard Date.timeIntervalSinceReferenceDate - steal.startedAt >= vehicleStealDuration,
			  let carId = vehicleStealId(for: steal.vehicle) else { return }

		stolenVehicleIds.insert(carId)
		activeSteal = nil
		vehicle = steal.vehicle
		mode = .car
		hud?.showConsoleText("Car stolen")
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

	private func stealableVehicleAction() -> Action? {
		guard let vehicle = vehicle,
			  vehicleStealId(for: vehicle) != nil else { return nil }

		return .vehicleSteal(vehicle)
	}

	private func enterableVehicleAction() -> Action? {
		guard let vehicle = vehicle,
			  canEnterCurrentVehicle() else { return nil }

		return .vehicleEnter(vehicle)
	}

	private func isVehicle(_ vehicle: Vehicle, matching node: SCNNode) -> Bool {
		return vehicle.node === node ||
			vehicle.scriptNode === node ||
			vehicle.node.name == node.name ||
			vehicle.scriptNode.name == node.name ||
			isNode(vehicle.node, inside: node) ||
			isNode(node, inside: vehicle.scriptNode)
	}

	func setup(in view: SCNView) {
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

	func setPaused(_ isPaused: Bool, showsPauseScreen: Bool = true) {
		let pauseStateChanged = isGamePaused != isPaused
		if pauseStateChanged {
			isGamePaused = isPaused
			scnScene.isPaused = isPaused
			scene.setScriptsPaused(isPaused)
			lastUpdateTime = nil
		}

		hud?.setPauseScreenVisible(isPaused && showsPauseScreen)

		if pauseStateChanged {
			playerController?.stop()
			vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
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
		if followsCamera {
			return true
		}
		if isSkyboxResourceName(name) {
			return true
		}
		return geometry?.materials.contains { material in
			isSkyboxResourceName(material.name)
		} ?? false
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
	func bestMatch(kind: EnvironmentLightKind, cameraPosition: SCNVector3, rootNode: SCNNode) -> EnvironmentLight? {
		var bestLight: EnvironmentLight?
		var bestLevel = Int.min

		for light in self where light.kind == kind {
			let level: Int
			if let sectorName = light.sectorName,
			   let sectorNode = rootNode.mafiaChildNode(named: sectorName, recursively: true) {
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

		if mode == .walk {
			playerController?.update(deltaTime: deltaTime)
			cameraContainer.eulerAngles = SCNVector3(
				x: playerController?.cameraPitch ?? 0,
				y: 0,
				z: 0
			)
		} else if mode == .car && vehicle != nil {
			updateCarCameraLook(deltaTime: deltaTime)
			updateCarCameraFollow(deltaTime: deltaTime)
		} else {
			updateFreeCamera(deltaTime: deltaTime)
		}
		updateSkyboxPosition()
		updateEnvironment(deltaTime: deltaTime)

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

		let vehicleVelocity = vehicle?.node.physicsBody?.velocity ?? SCNVector3Zero
		let vehicleSpeed = sqrt(
			vehicleVelocity.x * vehicleVelocity.x +
			vehicleVelocity.y * vehicleVelocity.y +
			vehicleVelocity.z * vehicleVelocity.z
		)
		hud.updateVehicleSpeed(
			CGFloat(vehicleSpeed),
			vehicleSpeed: vehicle?.speed ?? 0,
			force: vehicle?.force ?? 0,
			isVisible: mode == .car && vehicle != nil
		)
		refreshPlayerStatusHud()
		updateVehicleStealing()

		if let node = scene.compassNode,
		   let playerNode = scene.playerNode {
			let p1 = node.presentation.worldPosition
			let p2 = playerNode.presentation.worldPosition
			hud.compass.isHidden = false
			let target = SCNVector3(x: p1.x - p2.x, y: 0, z: p1.z - p2.z)
			let cameraTransform = cameraNode.presentation.worldTransform
			let cameraRight = normalizedHorizontalVector(
				SCNVector3(x: cameraTransform.m11, y: 0, z: cameraTransform.m13),
				fallback: SCNVector3(x: 1, y: 0, z: 0)
			)
			let cameraForward = normalizedHorizontalVector(
				cameraNode.presentation.worldFront,
				fallback: SCNVector3(x: 0, y: 0, z: -1)
			)
			let screenX = target.x * cameraRight.x + target.z * cameraRight.z
			let screenY = target.x * cameraForward.x + target.z * cameraForward.z
			hud.compassNeedle.zRotation = CGFloat(atan2(screenY, screenX))
		} else {
			hud.compass.isHidden = true
		}

		updateActionButtonVisibility(at: time)
	}

}

// MARK: - Actions

extension Game {

	func performAction(_ action: Action) {
		switch action {
		case .action(let script, _):
			let index = scene.actions.index(where: { action in
				if case .action(let _script, _) = action {
					return script.uuid == _script.uuid
				} else {
					return false
				}
			})!
			scene.actions.remove(at: index)

			script.next()

		case .weapon(let node, let weapon):
			node.isHidden = true

			let index = scene.actions.index(where: { action in
				if case .weapon(_, let _weapon) = action {
					return weapon.uuid == _weapon.uuid
				} else {
					return false
				}
			})!
			scene.actions.remove(at: index)

			if scene.weapons[scene.playerNode!] == nil {
				scene.weapons[scene.playerNode!] = []
			}

			for weapon in scene.weapons[scene.playerNode!]! {
				weapon.position = .inventory
			}

			scene.weapons[scene.playerNode!]!.append(weapon)
			weapon.position = .hand

		case .door(let node):
			useDoor(node)

		case .vehicleSteal(let vehicle):
			beginVehicleSteal(vehicle)

		case .vehicleEnter:
			mode = .car
		}
	}

	func actionButtonTapped() {
		guard let action = nearestAction() else { return }
		performAction(action)
	}

	func playerDidFire() {
		lastControl = .FIRE
		firePlayerWeapon()
		scene.triggerPlayerFireEvent()
	}

	func playerDidHorn() {
		lastControl = .HORN
		scene.triggerPlayerHornEvent()
	}

	func toggleSpeedLimiter() {
		pressControl(.SPEEDLIMIT)
		guard let vehicle = vehicle else { return }

		vehicle.isSpeedLimiterEnabled.toggle()
		hud?.showConsoleText(vehicle.isSpeedLimiterEnabled ? "Speed limiter on" : "Speed limiter off")
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

		return isVehicle(vehicle, matching: carNode)
	}

	func canEnterCurrentVehicle() -> Bool {
		guard let vehicle = vehicle else { return false }
		return vehicleStealId(for: vehicle) == nil
	}

	func pressControl(_ control: Control) {
		lastControl = control
		activeControls.insert(control)
	}

	func releaseControl(_ control: Control) {
		activeControls.remove(control)
	}

	func isControlPressed(_ control: Control) -> Bool {
		return activeControls.contains(control)
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
		guard let playerNode = scene.playerNode,
			  let weapons = scene.weapons[playerNode] else { return }
		for weapon in weapons {
			weapon.position = .inventory
		}
		refreshPlayerStatusHud()
	}

	func dropPlayerWeapon() {
		guard let playerNode = scene.playerNode,
			  var weapons = scene.weapons[playerNode],
			  let index = weapons.firstIndex(where: { $0.position == .hand }) else { return }

		let weapon = weapons.remove(at: index)
		weapon.position = .inventory
		scene.weapons[playerNode] = weapons

		if let dropNode = scene.rootNode.childNode(withName: "2bbat", recursively: true) {
			dropNode.isHidden = false
			scene.actions.append(.weapon(dropNode, weapon))
		}
		hud?.showConsoleText("Dropped \(weapon.name)")
		refreshPlayerStatusHud()
	}

	func playerInventoryWeapons() -> [Weapon] {
		guard let playerNode = scene.playerNode else { return [] }
		return scene.weapons[playerNode] ?? []
	}

	func equipPlayerWeapon(_ selectedWeapon: Weapon?) {
		guard let playerNode = scene.playerNode,
			  let weapons = scene.weapons[playerNode] else { return }

		for weapon in weapons {
			weapon.position = selectedWeapon.map { weapon === $0 } == true ? .hand : .inventory
		}

		if let selectedWeapon = selectedWeapon {
			hud?.showConsoleText("Equipped \(selectedWeapon.name)")
		} else {
			hud?.showConsoleText("Empty hands")
		}
		refreshPlayerStatusHud()
	}

	func reloadPlayerWeapon() {
		guard let weapon = equippedPlayerWeapon(), weapon.canReload, let profile = weapon.profile else { return }

		let neededAmmo = profile.clipSize - weapon.clipAmmo
		let loadedAmmo = min(neededAmmo, weapon.restAmmo)
		weapon.clipAmmo += loadedAmmo
		weapon.restAmmo -= loadedAmmo
		playWeaponSound(profile.reloadSoundName)
		hud?.showConsoleText("\(weapon.name): \(weapon.clipAmmo)/\(weapon.restAmmo)")
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

	func playDodgeAnimation(direction: DodgeDirection) {
		guard mode == .walk,
			  let playerNode = scene.playerNode else { return }

		let animationName: String
		let animationId: Int
		switch direction {
		case .left:
			animationName = "anims/left1.5ds"
			animationId = 98
		case .right:
			animationName = "anims/right1.5ds"
			animationId = 99
		}

		scene.noteActionAnimation(id: animationId)
		try? playAnimation(named: animationName, in: playerNode, animationKey: "__dodge__")
	}

	private func firePlayerWeapon() {
		guard mode == .walk,
			  let weapon = equippedPlayerWeapon(),
			  weapon.isFirearm,
			  let profile = weapon.profile else { return }

		let now = Date.timeIntervalSinceReferenceDate
		guard now - lastWeaponShotTime >= profile.shotInterval else { return }

		guard weapon.hasAmmoLoaded else {
			hud?.showConsoleText("\(weapon.name): empty")
			return
		}

		lastWeaponShotTime = now
		if weapon.clipAmmo > 0 {
			weapon.clipAmmo -= 1
		}
		refreshPlayerStatusHud()

		for _ in 0..<profile.pelletCount {
			shootFromCamera(profile: profile)
		}
		playWeaponSound(profile.fireSoundName)
		showMuzzleFlash()
	}

	private func shootFromCamera(profile: Weapon.Profile) {
		let origin = cameraNode.presentation.worldPosition
		let direction = spreadDirection(from: cameraNode.presentation.worldFront, spread: profile.spread)
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
			if isShotEffectNode(hit.node) ||
			   isNode(hit.node, inside: scene.playerNode) ||
			   isNode(hit.node, inside: vehicle?.node) {
				continue
			}

			tracerEnd = hit.worldCoordinates
			if let hitNode = shootableNode(from: hit.node) {
				let impulse = SCNVector3(
					x: direction.x * profile.impulse,
					y: direction.y * profile.impulse + 1.5,
					z: direction.z * profile.impulse
				)
				if hitNode.physicsBody != nil {
					hitNode.physicsBody?.applyForce(impulse, at: hit.worldCoordinates, asImpulse: true)
				} else {
					hitNode.position += SCNVector3(x: direction.x * 1.2, y: 0.2, z: direction.z * 1.2)
				}
			}
			showImpact(at: hit.worldCoordinates, normal: hit.worldNormal)
			showTracer(from: origin, to: tracerEnd)
			return
		}
		showTracer(from: origin, to: tracerEnd)
	}

	func equippedPlayerWeapon() -> Weapon? {
		guard let playerNode = scene.playerNode,
			  let weapons = scene.weapons[playerNode] else { return nil }
		return weapons.first { $0.position == .hand }
	}

	func refreshPlayerStatusHud() {
		hud?.updatePlayerStatus(health: playerHealth, weapon: equippedPlayerWeapon())
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
		cameraNode.runAction(SCNAction.playAudio(source, waitForCompletion: false), forKey: "__weapon_fire_sound__")
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
		guard mode == .walk,
			  let playerNode = scene.playerNode else { return nil }

		let playerPosition = playerNode.presentation.worldPosition
		var actions = scene.actions
		if let stealAction = stealableVehicleAction() {
			actions.append(stealAction)
		} else if let enterAction = enterableVehicleAction() {
			actions.append(enterAction)
		}
		return actions
			.filter { $0.node.actionSquaredDistance(to: playerPosition) < actionDistanceSquared }
			.min { $0.node.actionSquaredDistance(to: playerPosition) < $1.node.actionSquaredDistance(to: playerPosition) }
	}

	private func useDoor(_ node: SCNNode) {
		guard let door = node.doorData else { return }
		guard node.action(forKey: "door") == nil else { return }

		if door.isLocked {
			playDoorSound(door.lockedSound, on: node)
			return
		}

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
		node.runAction(SCNAction.playAudio(source, waitForCompletion: false), forKey: "doorSound")
	}

	func openInventory() {
		hud?.toggleInventory()
	}

}
