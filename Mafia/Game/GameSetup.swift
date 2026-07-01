//
//  GameSetup.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

private extension SaveGameVector3 {
	var scnVector3: SCNVector3 {
		return SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
	}
}

extension Game {

	func spawnPlayer() {
		guard let playerNode = try? loadModel(named: "models/tommy") else { return }

		if let spawnNode = playerSpawnNode() {
			playerNode.transform = spawnNode.worldTransform
		}
		playerNode.name = "tommy"
		playerNode.type = .player
		playerNode.humanEnergy = playerMaxEnergy
		scene.playerNode = playerNode
		scnScene.rootNode.addChildNode(playerNode)
		scene.registerNodeTree(playerNode)
	}

	func syncInitialPlayerHealthFromMission() {
		guard let playerNode = scene.playerNode else { return }
		playerNode.type = .player
		if playerNode.humanEnergy == nil {
			playerNode.humanEnergy = playerMaxEnergy
		}
		guard let energy = playerNode.humanEnergy else { return }
		playerMaxEnergy = max(1, energy)
		updatePlayerHealthFromEnergy()
	}

	func playerSpawnNode() -> SCNNode? {
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

	func applyMissionTransition() {
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

	func restoreSaveGameCheckpointIfNeeded() {
		guard let checkpoint = saveGameCheckpoint else { return }

		restoreSaveGamePlayerPosition(from: checkpoint)
		restoreSaveGamePlayerHealth(from: checkpoint)
		restoreSaveGameVehicleIfNeeded(from: checkpoint)
		scene.restoreSaveGameScriptStates(from: checkpoint)
	}

	func restoreSaveGamePlayerPosition(from checkpoint: SaveGameCheckpoint) {
		guard let position = checkpoint.playerEntity?.position,
			  let playerNode = scene.playerNode else { return }

		if let playerController = playerController {
			playerController.teleport(to: position.scnVector3, yaw: worldYaw(of: playerNode))
		} else {
			setWorldPosition(position.scnVector3, for: playerNode)
		}
		print("== Savegame player position restored: \(position.x), \(position.y), \(position.z)")
	}

	func restoreSaveGamePlayerHealth(from checkpoint: SaveGameCheckpoint) {
		let healthPercent = max(0, Int(checkpoint.summary.healthPercent))
		let restoredEnergy = playerMaxEnergy * Float(healthPercent) / 100
		scene.playerNode?.humanEnergy = playerEnergyPreservingInvincibility(requestedEnergy: restoredEnergy)
		updatePlayerHealthFromEnergy()
	}

	func restoreSaveGameVehicleIfNeeded(from checkpoint: SaveGameCheckpoint) {
		guard transitionVehicleSpeed == nil,
			  let entity = checkpoint.activePlayerVehicleEntity else { return }

		guard let carNode = scene.node(named: entity.name) ?? scnScene.rootNode.mafiaChildNode(named: entity.name, recursively: true) else {
			print("== Savegame vehicle '\(entity.name)' not found in mission scene")
			return
		}

		guard scriptedVehicle(for: carNode) != nil else {
			print("== Savegame vehicle '\(entity.name)' is not usable as a vehicle")
			return
		}

		if let position = entity.position {
			setWorldPosition(position.scnVector3, for: carNode)
			print("== Savegame vehicle position restored: \(entity.name) \(position.x), \(position.y), \(position.z)")
		}
		mode = .car
		syncPlayerToVehicle()
		print("== Savegame vehicle restored: \(entity.name)")
	}

	func setWorldPosition(_ position: SCNVector3, for node: SCNNode) {
		node.position = node.parent?.convertPosition(position, from: nil) ?? position
	}

	func worldYaw(of node: SCNNode) -> SCNFloat {
		let forward = node.presentation.worldFront
		return atan2(-forward.x, -forward.z)
	}

	func setVehicleSpeed(_ vehicle: Vehicle, kilometersPerHour speed: CGFloat) {
		let metersPerSecond = SCNFloat(speed / 3.6)
		let forward = vehicle.node.presentation.worldFront.normalized
		let velocity = forward * metersPerSecond
		let chassisBody = vehicle.node.mafiaChildNode(named: "BODY", recursively: false)?.physicsBody
		(chassisBody ?? vehicle.node.physicsBody)?.velocity = velocity
	}

	func configureCamera(for mode: Mode) {
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

	func updateWalkCameraHeight(deltaTime: TimeInterval) {
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

	func applyPendingLook() {
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

	func consumePendingLook() -> (x: SCNFloat, y: SCNFloat) {
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

	func updateFreeCamera(deltaTime: TimeInterval) {
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

	func normalizedAngle(_ angle: SCNFloat) -> SCNFloat {
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

	func resetCarCameraLook() {
		carCameraYaw = 0
		carCameraPitch = defaultCarCameraPitch
		carCameraReverseYaw = 0
		carCameraMouseIdleTime = 0
	}

	func resetCarCameraFollow() {
		guard let vehicle = vehicle else { return }

		let position = vehicle.node.presentation.worldPosition
		let yaw = vehicleYaw()

		smoothedCarCameraPosition = position
		smoothedCarCameraYaw = yaw
		applyCarCameraTransform(position: position, yaw: yaw)
	}

	func updateCarCameraLook(deltaTime: TimeInterval) {
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

	func applyCarCameraLook() {
		guard let vehicle = vehicle else { return }

		let position = smoothedCarCameraPosition ?? vehicle.node.presentation.worldPosition
		let yaw = smoothedCarCameraYaw ?? vehicleYaw()
		applyCarCameraTransform(position: position, yaw: yaw)
	}

	func updateCarCameraFollow(deltaTime: TimeInterval) {
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

	func applyCarCameraTransform(position: SCNVector3, yaw: SCNFloat) {
		cameraContainer.position = position
		cameraContainer.eulerAngles = SCNVector3(
			x: carCameraPitch,
			y: yaw + carCameraYaw + carCameraReverseYaw,
			z: 0
		)
	}

	func vehicleYaw() -> SCNFloat {
		guard let vehicle = vehicle else { return 0 }

		let forward = vehicle.node.presentation.worldFront
		return atan2(-forward.x, -forward.z)
	}

	func vehicleLongitudinalSpeed() -> SCNFloat {
		guard let vehicle = vehicle else { return 0 }
		let velocity = vehicle.velocity

		let forward = vehicle.node.presentation.worldFront
		return velocity.x * forward.x + velocity.z * forward.z
	}

	func updateSkyboxPosition() {
		let cameraPosition = cameraNode.presentation.worldPosition
		for skyboxNode in skyboxNodes {
			let position = cameraPosition + skyboxNode.offset
			skyboxNode.node.position = skyboxNode.node.parent?.convertPosition(position, from: nil) ?? position
		}
		skyboxFallbackNode.position = cameraPosition
	}

	func updateEnvironment(deltaTime: TimeInterval) {
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

	func configureSkyboxFallback() {
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

	func skyboxMaterial(named textureName: String) -> SCNMaterial {
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

	func teleportPlayerBesideVehicle() {
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

	func clearPlayerVehicleOwner(for playerNode: SCNNode) {
		scene.humanVehicleOwners[ObjectIdentifier(playerNode)] = nil
	}

	func playerExitPlacement(for vehicle: Vehicle) -> (position: SCNVector3, yaw: SCNFloat) {
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

	func movePlayerIntoVehicle() {
		guard let playerNode = scene.playerNode,
			  let vehicle = vehicle else { return }

		if playerPhysicsBodyBeforeVehicle == nil {
			playerPhysicsBodyBeforeVehicle = playerNode.physicsBody
		}
		playerNode.disablePhysicsInHierarchy()

		let seatPosition = playerSeatPosition(in: vehicle.node)
		if playerNode.parent !== vehicle.node {
			vehicle.node.addChildNode(playerNode)
		}
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

	func syncPlayerToVehicle() {
		guard let playerNode = scene.playerNode,
			  let vehicle = vehicle else { return }

		if playerNode.parent !== vehicle.node {
			vehicle.node.addChildNode(playerNode)
		}
		playerNode.position = playerSeatPosition(in: vehicle.node)
		playerNode.isHidden = false
		playerNode.setHiddenInHierarchy(false)
	}

	func enterVehicleWithAnimation(_ targetVehicle: Vehicle) {
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

	func exitVehicleWithAnimation() {
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

	func playPlayerVehicleSittingAnimation() {
		guard let playerNode = scene.playerNode,
			  let animationName = vehicleSittingAnimationName() else { return }
		currentPlayerVehicleSittingAnimationName = animationName
		playPlayerVehicleAnimation(named: animationName, in: playerNode, repeat: true)
	}

	func updatePlayerVehicleSittingAnimation() {
		guard let animationName = vehicleSittingAnimationName(),
			  animationName != currentPlayerVehicleSittingAnimationName else { return }
		playPlayerVehicleSittingAnimation()
	}

	func playPlayerVehicleAnimation(
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

	func stopPlayerVehicleAnimation() {
		guard let playerNode = scene.playerNode else { return }
		currentPlayerVehicleSittingAnimationName = nil
		playerNode.removeAction(forKey: playerVehicleAnimationKey)
		playerNode.removeAction(forKey: playerVehicleAnimationKey + ":position")
	}

	func vehicleEnterAnimationName() -> String? {
		return firstExistingAnimation(named: [
			"anims/AutoSmNas FL.5ds",
			"anims/AutoBigNas FL.5ds"
		])
	}

	func vehicleExitAnimationName() -> String? {
		return firstExistingAnimation(named: [
			"anims/AutoSmVys FL.5ds",
			"anims/AutoBigVys FL.5ds"
		])
	}

	func vehicleSittingAnimationName() -> String? {
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

	func playerSeatPosition(in body: SCNNode) -> SCNVector3 {
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

	func horizontalVehicleRight() -> SCNVector3 {
		guard let vehicle = vehicle else { return SCNVector3(x: 1, y: 0, z: 0) }

		let transform = vehicle.node.presentation.worldTransform
		let right = SCNVector3(x: transform.m11, y: 0, z: transform.m13)
		let length = sqrt(right.x * right.x + right.z * right.z)
		guard length > 0.0001 else { return SCNVector3(x: 1, y: 0, z: 0) }

		return SCNVector3(x: right.x / length, y: 0, z: right.z / length)
	}

	func vehicleBottomWorldY() -> SCNFloat {
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

	func updateActionButtonVisibility(at time: TimeInterval) {
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

	func setActionButtonVisible(_ isVisible: Bool) {
		guard isActionButtonVisible != isVisible else { return }

		isActionButtonVisible = isVisible
		updateHud { hud in
			hud.setActionButtonVisible(isVisible)
		}
	}

	func beginVehicleSteal(_ vehicle: Vehicle) {
		guard mode == .walk,
			  activeSteal == nil,
			  !isStolenVehicle(vehicle) else { return }

		activeSteal = (vehicle, Date.timeIntervalSinceReferenceDate)
		updateHud { hud in
			hud.showConsoleText("Stealing car...")
		}
	}

	func updateVehicleStealing() {
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

	func vehicleStealId(for vehicle: Vehicle) -> Int? {
		for carId in stealEnabledVehicleIds {
			if let carNode = stealVehicleNodes[carId],
			   isVehicle(vehicle, matching: carNode),
			   !stolenVehicleIds.contains(carId) {
				return carId
			}
		}
		return nil
	}

	func vehicleStealId(for node: SCNNode) -> Int? {
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

	func markVehicleStolen(_ vehicle: Vehicle) {
		stolenVehicleNodeIds.insert(ObjectIdentifier(vehicle.node))
		stolenVehicleNodeIds.insert(ObjectIdentifier(vehicle.scriptNode))
	}

	func isStolenVehicle(_ vehicle: Vehicle) -> Bool {
		if vehicleStealId(for: vehicle) != nil {
			return false
		}
		return stolenVehicleNodeIds.contains(ObjectIdentifier(vehicle.node)) ||
			stolenVehicleNodeIds.contains(ObjectIdentifier(vehicle.scriptNode))
	}

	func stealableVehicleAction() -> Action? {
		guard let vehicle = nearestScriptedStealableVehicle() else { return nil }
		return .vehicleSteal(vehicle)
	}

	func enterableVehicleAction() -> Action? {
		guard let vehicle = nearestScriptedEnterableVehicle() else { return nil }
		return .vehicleEnter(vehicle)
	}

	func vehicleExitAction() -> Action? {
		guard mode == .car,
			  let vehicle = vehicle,
			  scriptedVehicleActions(for: vehicle).isEmpty,
			  vehicle.speed <= vehicleStoppedSpeedThreshold else { return nil }

		return .vehicleExit(vehicle)
	}

	func scriptedVehicleActions(for vehicle: Vehicle) -> [Action] {
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

	func isVehicle(_ vehicle: Vehicle, matching node: SCNNode) -> Bool {
		return vehicle.node === node ||
			vehicle.scriptNode === node ||
			vehicle.node.name == node.name ||
			vehicle.scriptNode.name == node.name ||
			isNode(vehicle.node, inside: node) ||
			isNode(node, inside: vehicle.scriptNode)
	}

	func scriptedVehicle(for node: SCNNode) -> Vehicle? {
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

	func nearestScriptedStealableVehicle() -> Vehicle? {
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

	func stealableVehicleNodes() -> [SCNNode] {
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
			return !isMission6OpponentRaceCarNode(node)
		}
	}

	func isMission6OpponentRaceCarNode(_ node: SCNNode) -> Bool {
		guard let name = node.name?.lowercased(),
			  name.hasPrefix("racing_car") else {
			return false
		}
		return name != "racing_car0"
	}

	func isCurrentVehicleNode(_ node: SCNNode) -> Bool {
		guard didEnterCurrentVehicle,
			  let vehicle = vehicle else { return false }
		return isVehicle(vehicle, matching: node)
	}

	func isStolenVehicleNode(_ node: SCNNode) -> Bool {
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

	func nearestScriptedEnterableVehicle() -> Vehicle? {
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

	func completeScriptedPlayerVehicleExit(position: SCNVector3, yaw: SCNFloat) {
		guard let playerNode = scene.playerNode else { return }

		stopPlayerVehicleAnimation()
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
		vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
		vehicle?.applyForces()
		vehicle?.updateAudio(isActive: false)
		vehicle = nil
		mode = .walk
		playerController?.teleport(to: position, yaw: yaw)
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
		destroyCityMusic()
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

	func updateHud(_ update: @escaping @MainActor @Sendable (HudScene) -> Void) {
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
			setCityMusicPaused(isPaused)
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

	func setRenderLoopActive(_ isActive: Bool) {
		Task { @MainActor [weak self] in
			self?.renderView?.isPlaying = isActive
			self?.renderView?.rendersContinuously = isActive
		}
	}

	func endMission(returnsToMainMenu: Bool, message: String?) {
		guard !didEndMission else { return }
		didEndMission = true

		if returnsToMainMenu {
			DispatchQueue.main.async { [weak self] in
				self?.onMissionEnded?()
			}
			return
		}

		scene.clearActiveRecordPlayback()
		updateHud { hud in
			hud.showMissionEndText(message)
			hud.setScriptBlackoutVisible(true, immediate: false)
		}
		setPaused(true, showsPauseScreen: false)
		playerController?.stop()
		vehicle?.updateControls(throttle: 0, brake: false, steering: 0)
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
			self.onMissionChangeRequested?(folder, frameName, transitionSpeed, self.missionTransitionState)
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

	func preloadMenuSounds() {
		pauseMenuOpenSoundSource = loadMenuSound(named: "menuopen.wav")
		pauseMenuChangeSoundSource = loadMenuSound(named: "menuchange.wav")
	}

	func loadMenuSound(named fileName: String) -> SCNAudioSource? {
		let url = mainDirectory.appendingPathComponent("sounds/\(fileName)")
		guard let source = SCNAudioSource(url: url) else { return nil }
		source.isPositional = false
		source.load()
		return source
	}

	func playPauseMenuOpenSound() {
		guard let source = pauseMenuOpenSoundSource else { return }
		playPauseMenuSound(source)
	}

	func playInGameMenuChangeSound() {
		guard let source = pauseMenuChangeSoundSource else { return }
		playPauseMenuSound(source)
	}

	func playPauseMenuSound(_ source: SCNAudioSource) {
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
