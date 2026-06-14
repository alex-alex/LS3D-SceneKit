//
//  GameRenderer.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

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
		updateCityMusic(deltaTime: deltaTime)
		trafficManager?.update(deltaTime: deltaTime, playerPosition: playerReferencePosition())
		updatePlayerFollowTrail()
		updateHostileNPCs(deltaTime: deltaTime, time: time)

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

	func setCityMusicEnabled(_ isEnabled: Bool) {
		guard isCityMusicEnabled != isEnabled else { return }
		isCityMusicEnabled = isEnabled
		if isEnabled {
			updateCityMusicAvailability()
		} else {
			stopCityMusic(fade: true)
		}
	}

	func setCityTrafficVisible(_ isVisible: Bool) {
		guard isCityTrafficVisible != isVisible else { return }
		isCityTrafficVisible = isVisible
		updateTrafficVisibility()
	}

	func updateTrafficVisibility() {
		trafficManager?.isEnabled = isCityTrafficVisible && !isCutsceneCameraActive
	}

	func updateCityMusicAvailability() {
		if isCutsceneCameraActive {
			stopCityMusic(fade: false)
		} else if isCityMusicEnabled {
			cityMusicUpdateTimer = -1
		}
	}

	func updateCityMusic(deltaTime: TimeInterval) {
		guard isCityMusicEnabled, !isCutsceneCameraActive else { return }
		if cityMusicUpdateTimer >= 0 {
			cityMusicUpdateTimer -= deltaTime
			return
		}
		cityMusicUpdateTimer = 10

		guard let position = playerReferencePosition(),
			  let region = cityMusicRegion(containing: position),
			  region.musicId != cityMusicId else { return }
		playCityMusic(id: region.musicId)
	}

	func cityMusicRegion(containing position: SCNVector3) -> CityMusicRegion? {
		for region in scene.cityMusicRegions.reversed() where containsCityMusicPosition(position, in: region.node) {
			return region
		}
		return nil
	}

	func playCityMusic(id: String) {
		guard let url = mafiaResourceURL(directory: "sounds", name: "music/city_music_\(id).ogg"),
			  let stream = ScriptMusicStream(url: url) else {
			return
		}

		fadeOutCityMusicStream()
		cityMusicStream = stream
		cityMusicId = id
		stream.play()
		stream.fadeVolume(from: 0, to: 0.5, duration: 5)
	}

	func stopCityMusic(fade: Bool) {
		cityMusicUpdateTimer = -1
		cityMusicId = nil
		guard fade else {
			destroyCityMusic()
			return
		}
		fadeOutCityMusicStream()
	}

	func fadeOutCityMusicStream() {
		guard let stream = cityMusicStream else { return }
		cityMusicStream = nil
		stream.fadeVolume(from: 0.5, to: 0, duration: 5)
		cityMusicFadingStreams.append(stream)

		let cleanupId = UUID()
		let cleanup = DispatchWorkItem { [weak self, weak stream] in
			guard let self = self, let stream = stream else { return }
			stream.destroy()
			self.cityMusicFadingStreams.removeAll { $0 === stream }
			self.cityMusicFadeCleanupItems.removeValue(forKey: cleanupId)
		}
		cityMusicFadeCleanupItems[cleanupId] = cleanup
		DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: cleanup)
	}

	func setCityMusicPaused(_ isPaused: Bool) {
		cityMusicStream?.setGamePaused(isPaused)
		for stream in cityMusicFadingStreams {
			stream.setGamePaused(isPaused)
		}
	}

	func destroyCityMusic() {
		for cleanup in cityMusicFadeCleanupItems.values {
			cleanup.cancel()
		}
		cityMusicFadeCleanupItems.removeAll()
		cityMusicStream?.destroy()
		cityMusicStream = nil
		cityMusicId = nil
		for stream in cityMusicFadingStreams {
			stream.destroy()
		}
		cityMusicFadingStreams.removeAll()
	}

	func containsCityMusicPosition(_ position: SCNVector3, in node: SCNNode) -> Bool {
		let localPoint = node.presentation.convertPosition(position, from: nil)
		guard let areaBounds = node.areaBounds else {
			return node.containsWorldPosition(position)
		}
		guard contains(localPoint, min: areaBounds.min, max: areaBounds.max) else { return false }
		guard !areaBounds.vertices.isEmpty, !areaBounds.triangles.isEmpty else { return true }
		return isPointInsideMesh(localPoint, vertices: areaBounds.vertices, triangles: areaBounds.triangles)
	}

	func isPointInsideMesh(_ point: SCNVector3, vertices: [SCNVector3], triangles: [(Int, Int, Int)]) -> Bool {
		let direction = SCNVector3(x: 1, y: 0.00037, z: 0.00019)
		var intersections = 0
		for triangle in triangles {
			guard triangle.0 >= 0, triangle.0 < vertices.count,
				  triangle.1 >= 0, triangle.1 < vertices.count,
				  triangle.2 >= 0, triangle.2 < vertices.count,
				  rayIntersectsTriangle(origin: point, direction: direction, a: vertices[triangle.0], b: vertices[triangle.1], c: vertices[triangle.2]) else {
				continue
			}
			intersections += 1
		}
		return intersections % 2 == 1
	}

	func rayIntersectsTriangle(origin: SCNVector3, direction: SCNVector3, a: SCNVector3, b: SCNVector3, c: SCNVector3) -> Bool {
		let epsilon: SCNFloat = 0.000001
		let edge1 = b - a
		let edge2 = c - a
		let h = cross(direction, edge2)
		let determinant = dot(edge1, h)
		guard abs(determinant) > epsilon else { return false }
		let inverseDeterminant = 1 / determinant
		let s = origin - a
		let u = inverseDeterminant * dot(s, h)
		guard u >= -epsilon, u <= 1 + epsilon else { return false }
		let q = cross(s, edge1)
		let v = inverseDeterminant * dot(direction, q)
		guard v >= -epsilon, u + v <= 1 + epsilon else { return false }
		let t = inverseDeterminant * dot(edge2, q)
		return t > epsilon
	}

	func contains(_ point: SCNVector3, min rawMin: SCNVector3, max rawMax: SCNVector3) -> Bool {
		let minPoint = SCNVector3(x: min(rawMin.x, rawMax.x), y: min(rawMin.y, rawMax.y), z: min(rawMin.z, rawMax.z))
		let maxPoint = SCNVector3(x: max(rawMin.x, rawMax.x), y: max(rawMin.y, rawMax.y), z: max(rawMin.z, rawMax.z))
		return point.x >= minPoint.x && point.x <= maxPoint.x &&
			point.y >= minPoint.y && point.y <= maxPoint.y &&
			point.z >= minPoint.z && point.z <= maxPoint.z
	}

	func updateDiagnostics(deltaTime: TimeInterval) {
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

	func diagnosticsPosition() -> SCNVector3 {
		switch mode {
		case .walk:
			return scene.playerNode?.presentation.worldPosition ?? cameraNode.presentation.worldPosition
		case .car:
			return vehicle?.node.presentation.worldPosition ?? cameraNode.presentation.worldPosition
		case .freeCamera:
			return cameraNode.presentation.worldPosition
		}
	}

	func diagnosticsDetails() -> String? {
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

	func formatDebugValue(_ value: SCNFloat?) -> String {
		guard let value = value else { return "--" }
		return String(format: "%.2f", Double(value))
	}

}
