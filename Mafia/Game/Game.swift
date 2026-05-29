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

	enum Mode {
		case walk, car
	}

	var hud: HudScene!

	let scnScene = SCNScene()
	let cameraContainer = SCNNode()
	let cameraNode = SCNNode()

	var mode: Mode = .car {
		didSet {
			cameraContainer.removeFromParentNode()
			configureCamera(for: mode)
			if mode == .walk {
				scene.playerNode?.isHidden = false
				teleportPlayerBesideVehicle()
				scene.playerNode!.addChildNode(cameraContainer)
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

	var vehicle: Vehicle!
	var playerController: PlayerController?
	var elevation: SCNFloat = 0
	var lastControl: Control?
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

	init(missionName: String) throws {
		scnScene.rootNode.name = "__root__"

		let sceneModel = try loadModel(named: "missions/\(missionName)/scene")
		sceneModel.name = "__model__"
		scnScene.rootNode.addChildNode(sceneModel)
		print("== Loaded Scene Model")

		scene = try Scene(named: "missions/"+missionName)

		super.init()

		scene.game = self
		scene.rootNode.name = "__scene__"
		scnScene.rootNode.addChildNode(scene.rootNode)
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

//		if scene.playerNode == nil {
//			//load z mise08-mesto
//			let spawnPoint = scnScene.rootNode.childNode(withName: "emeth_1", recursively: true)!
//			scene.playerNode = try! loadModel(named: "models/tommy")
//			scene.playerNode!.transform = spawnPoint.worldTransform
//			scnScene.rootNode.addChildNode(scene.playerNode!)
//		}

		// -----

		if let playerNode = scene.playerNode {
			playerNode.position.y += 0.5
			playerController = PlayerController(node: playerNode, scene: scnScene)
		}

		// -----

		let carNodeName = "taxi2"
//		let carNodeName = "cad_road"
		let carNode = scene.rootNode.childNode(withName: carNodeName, recursively: true)!
		vehicle = Vehicle(scene: scnScene, node: carNode)

		// -----

		let camera = SCNCamera()
		camera.zFar = 1000

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
	}

	private func configureCamera(for mode: Mode) {
		if mode == .car {
			cameraContainer.position = vehicle.node.presentation.worldPosition
			cameraNode.position = carCameraPosition
			cameraNode.eulerAngles = SCNVector3(x: carCameraForwardPitch, y: .pi, z: .pi)
			elevation = 0
			resetCarCameraLook()
		} else {
			cameraContainer.position = SCNVector3(x: 0, y: 1.35, z: 0)
			cameraNode.position = SCNVector3(x: 0, y: 1.25, z: -2.8)
			cameraNode.eulerAngles = SCNVector3(x: 0.15, y: .pi, z: .pi)
			elevation = 0
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
		}
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
		let position = vehicle.node.presentation.worldPosition
		let yaw = vehicleYaw()

		smoothedCarCameraPosition = position
		smoothedCarCameraYaw = yaw
		applyCarCameraTransform(position: position, yaw: yaw)
	}

	private func updateCarCameraLook(deltaTime: TimeInterval) {
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
		let position = smoothedCarCameraPosition ?? vehicle.node.presentation.worldPosition
		let yaw = smoothedCarCameraYaw ?? vehicleYaw()
		applyCarCameraTransform(position: position, yaw: yaw)
	}

	private func updateCarCameraFollow(deltaTime: TimeInterval) {
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
		let forward = vehicle.node.presentation.worldFront
		return atan2(-forward.x, -forward.z)
	}

	private func vehicleLongitudinalSpeed() -> SCNFloat {
		guard let velocity = vehicle.node.physicsBody?.velocity else { return 0 }

		let forward = vehicle.node.presentation.worldFront
		return velocity.x * forward.x + velocity.z * forward.z
	}

	private func teleportPlayerBesideVehicle() {
		guard let playerController = playerController else { return }

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
		let transform = vehicle.node.presentation.worldTransform
		let right = SCNVector3(x: transform.m11, y: 0, z: transform.m13)
		let length = sqrt(right.x * right.x + right.z * right.z)
		guard length > 0.0001 else { return SCNVector3(x: 1, y: 0, z: 0) }

		return SCNVector3(x: right.x / length, y: 0, z: right.z / length)
	}

	private func vehicleBottomWorldY() -> SCNFloat {
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
	}

	func setPaused(_ isPaused: Bool) {
		guard isGamePaused != isPaused else { return }

		isGamePaused = isPaused
		scnScene.isPaused = isPaused
		lastUpdateTime = nil
		hud?.setPauseScreenVisible(isPaused)
		playerController?.stop()
		vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
	}

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
		} else {
			updateCarCameraLook(deltaTime: deltaTime)
			updateCarCameraFollow(deltaTime: deltaTime)
		}

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
			vehicle.applyForces()
		}

		#endif

		let vehicleVelocity = vehicle.node.physicsBody?.velocity ?? SCNVector3Zero
		let vehicleSpeed = sqrt(
			vehicleVelocity.x * vehicleVelocity.x +
			vehicleVelocity.y * vehicleVelocity.y +
			vehicleVelocity.z * vehicleVelocity.z
		)
		hud.updateVehicleSpeed(
			CGFloat(vehicleSpeed),
			vehicleSpeed: vehicle.speed,
			force: vehicle.force,
			isVisible: mode == .car
		)

		if let node = scene.compassNode {
			let p1 = node.presentation.worldPosition
			let p2 = scene.playerNode!.presentation.worldPosition
			hud.compass.isHidden = false
			let playerAngle: SCNFloat
			if mode == .walk {
				playerAngle = scene.playerNode!.presentation.rotation.y * scene.playerNode!.presentation.rotation.w - .pi
			} else {
				playerAngle = self.vehicle.node.presentation.rotation.y * self.vehicle.node.presentation.rotation.w - .pi/2
			}
			hud.compassNeedle.zRotation = CGFloat(atan2(p2.z - p1.z, p2.x - p1.x) + playerAngle)
		} else {
			hud.compass.isHidden = true
		}

		hud.actionButton.isHidden = scene.actions.filter({ $0.node.distance(to: scene.playerNode!) < 2 }).isEmpty
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
		}
	}

	func actionButtonTapped() {
		/*#if os(iOS)
		let actions = scene.actions.filter({ $0.node.distance(to: scene.playerNode!) < 2 })
		if actions.count == 1 {
			performAction(actions[0])
		} else if actions.count > 1 {
			let alert = UIAlertController(title: "Sebrat / Použít", message: nil, preferredStyle: .alert)
			for action in actions {
				alert.addAction(UIAlertAction(title: action.title, style: .default, handler: { _ in
					self.performAction(action)
				}))
			}
			alert.addAction(UIAlertAction(title: "Zrušit", style: .cancel, handler: nil))
			vc.present(alert, animated: true)
		}
		#endif*/
	}

	func openInventory() {
		/*#if os(iOS)
		let alert = UIAlertController(title: "Inventář", message: nil, preferredStyle: .alert)
		for weapon in scene.weapons[scene.playerNode!] ?? [] {
			alert.addAction(UIAlertAction(title: weapon.name + (weapon.position == .hand ? " (v ruce)" : ""), style: .default, handler: { _ in
				for weapon in self.scene.weapons[self.scene.playerNode!] ?? [] {
					weapon.position = .inventory
				}
				weapon.position = .hand
			}))
		}
		alert.addAction(UIAlertAction(title: "Prázdné ruce", style: .cancel, handler: { _ in
			for weapon in self.scene.weapons[self.scene.playerNode!] ?? [] {
				weapon.position = .inventory
			}
		}))
		vc.present(alert, animated: true)
		#endif*/
	}

}
