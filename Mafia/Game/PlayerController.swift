//
//  PlayerController.swift
//  Mafia
//
//  Created by Codex on 29/05/2026.
//  Copyright © 2026 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

final class PlayerController {

	private let node: SCNNode
	private let scene: SCNScene
	private let stateLock = NSLock()

	private var movement = SCNVector3Zero
	private var turn: SCNFloat = 0
	private var pendingLook: SCNFloat = 0
	private var pendingPitch: SCNFloat = 0
	private var wantsJump = false
	private let baseHeading: SCNFloat
	private var lookYaw: SCNFloat = 0
	private var lookPitch: SCNFloat = 0
	private var horizontalVelocity = SCNVector3Zero
	private var verticalVelocity: SCNFloat = 0
	private var requestedCrouching = false
	private var requestedRunning = false
	private var standingY: SCNFloat
	private var isCrouching = false
	private var isWalkingAnimationPlaying = false
	private var currentWalkingAnimationName: String?
	private var currentAirAnimationName: String?
	private var currentCrouchTransitionAnimationName: String?
	private var crouchTransitionId = 0
	private var isCrouchTransitionPlaying = false
	private var walkingAnimationHoldCount = 0
	private var wasAirborneLastFrame = false
	private var footstepAudio = FootstepAudio()
	var movementAnimationSetProvider: (() -> Int?)?
	private(set) var lastAppliedLook: SCNFloat = 0
	private(set) var lastMovement = SCNVector3Zero
	private(set) var lastDesiredVelocity = SCNVector3Zero
	var debugPosition: SCNVector3 {
		return node.presentation.position
	}
	var debugVelocity: SCNVector3 {
		return horizontalVelocity
	}
	var yaw: SCNFloat {
		return lookYaw
	}
	var cameraPitch: SCNFloat {
		return lookPitch
	}
	var isPlayerCrouching: Bool {
		return requestedCrouchingValue
	}

	private let walkSpeed: SCNFloat = 3.2
	private let runSpeed: SCNFloat = 6.1
	private let crouchSpeed: SCNFloat = 1.45
	private let acceleration: SCNFloat = 14
	private let stopAcceleration: SCNFloat = 24
	private let turnSpeed: SCNFloat = 2.8
	private let jumpSpeed: SCNFloat = 5.2
	private let gravity: SCNFloat = 12
	private let maxStepHeight: SCNFloat = 0.45
	private let maxGroundSnapDistance: SCNFloat = 2.0
	private let groundProbeLift: SCNFloat = 0.55
	private let groundProbeRadius: SCNFloat = 0.22
	private let minGroundNormalY: SCNFloat = 0.65
	private let minLookPitch: SCNFloat = -0.65
	private let maxLookPitch: SCNFloat = 0.45
	private let crouchWalkingAnimationCandidates = [
		"anims/x panika drep chuze.5ds",
		"anims/x panika drep krok.5ds",
		"anims/walk drep.5ds"
	]
	private let walkingAnimationKey = "__walking__"
	private let airAnimationKey = "__air__"
	private let crouchDownAnimationName = "anims/x panika drep dolu.5ds"
	private let crouchUpAnimationName = "anims/x panika drep nahoru.5ds"
	private let crouchAnimationKey = "__crouch__"

	init(node: SCNNode, scene: SCNScene) {
		self.node = node
		self.scene = scene
		baseHeading = PlayerController.worldYaw(for: node)
		standingY = node.presentation.position.y
		configurePhysics()
	}

	func setMovement(x: SCNFloat, z: SCNFloat) {
		let length = sqrt(x * x + z * z)
		if length > 1 {
			movement = SCNVector3(x: x / length, y: 0, z: z / length)
		} else {
			movement = SCNVector3(x: x, y: 0, z: z)
		}
	}

	func setTurn(_ value: SCNFloat) {
		turn = max(-1, min(1, value))
	}

	func look(deltaX: SCNFloat) {
		pendingLook += deltaX
	}

	func look(deltaX: SCNFloat, deltaY: SCNFloat) {
		pendingLook += deltaX
		pendingPitch += deltaY
	}

	func jump() {
		guard !requestedCrouchingValue else { return }
		wantsJump = true
	}

	func setCrouching(_ value: Bool) {
		stateLock.lock()
		defer { stateLock.unlock() }
		requestedCrouching = value
	}

	func setRunning(_ value: Bool) {
		stateLock.lock()
		defer { stateLock.unlock() }
		requestedRunning = value
	}

	func stop() {
		setRunning(false)
		movement = SCNVector3Zero
		turn = 0
		pendingLook = 0
		pendingPitch = 0
		horizontalVelocity = SCNVector3Zero
		verticalVelocity = 0
		wasAirborneLastFrame = false
		stopCurrentAirAnimation()
		updateWalkingAnimation(isMoving: false)
		footstepAudio.reset()
		resetAngularVelocity()
	}

	func playActionAnimation(named animationName: String, animationKey: String) {
		holdWalkingAnimation()
		do {
			try playAnimation(
				named: animationName,
				in: node,
				animationKey: animationKey
			) { [weak self] in
				self?.releaseWalkingAnimationHold()
			}
		} catch {
			releaseWalkingAnimationHold()
		}
	}

	func teleport(to worldPosition: SCNVector3, yaw: SCNFloat) {
		stop()
		node.worldPosition = worldPosition
		face(worldYaw: yaw)
		lookPitch = 0
		standingY = node.position.y
		node.physicsBody?.velocity = SCNVector3Zero
		node.physicsBody?.angularVelocity = SCNVector4Zero
	}

	func face(worldYaw yaw: SCNFloat) {
		applyWorldYaw(yaw)
		lookYaw = normalizedAngle(yaw - baseHeading)
	}

	func turnTowardCameraYaw(_ cameraYaw: SCNFloat, deltaTime: TimeInterval) -> SCNFloat {
		let horizontalInput = sqrt(movement.x * movement.x + movement.z * movement.z)
		guard horizontalInput > 0.01 else { return 0 }

		let dt = SCNFloat(max(0, min(deltaTime, 1.0 / 20.0)))
		let yawOffset = normalizedAngle(cameraYaw)
		let maxStep = turnSpeed * dt
		let appliedYaw = max(-maxStep, min(maxStep, yawOffset))

		lookYaw = normalizedAngle(lookYaw + appliedYaw)
		return appliedYaw
	}

	func update(deltaTime: TimeInterval) {
		applyPendingCrouchChange()
		guard let body = node.physicsBody else { return }

		let dt = SCNFloat(max(0, min(deltaTime, 1.0 / 20.0)))
		lastAppliedLook = pendingLook
		lookYaw += turn * turnSpeed * dt + pendingLook
		lookPitch = max(minLookPitch, min(maxLookPitch, lookPitch + pendingPitch))
		pendingLook = 0
		pendingPitch = 0
		body.angularVelocity = SCNVector4Zero

		let movementHeading = normalizedAngle(baseHeading + lookYaw)
		applyWorldYaw(movementHeading)
		let movementBasis = horizontalMovementBasis()
		let desiredVelocity = SCNVector3(
			x: (movementBasis.right.x * movement.x + movementBasis.forward.x * movement.z) * currentMoveSpeed,
			y: 0,
			z: (movementBasis.right.z * movement.x + movementBasis.forward.z * movement.z) * currentMoveSpeed
		)
		lastMovement = movement
		lastDesiredVelocity = desiredVelocity

		let horizontalSpeed = sqrt(movement.x * movement.x + movement.z * movement.z)
		updateWalkingAnimation(isMoving: horizontalSpeed > 0.01)
		let rate = horizontalSpeed > 0 ? acceleration : stopAcceleration
		let blend = min(1, rate * dt)
		horizontalVelocity.x += (desiredVelocity.x - horizontalVelocity.x) * blend
		horizontalVelocity.z += (desiredVelocity.z - horizontalVelocity.z) * blend

		updateGroundHeight()
		let positionBeforeMove = node.position
		moveHorizontally(dx: horizontalVelocity.x * dt, dz: horizontalVelocity.z * dt)
		let actualHorizontalDelta = SCNVector3(x: node.position.x - positionBeforeMove.x, y: 0, z: node.position.z - positionBeforeMove.z)
		let grounded = isGrounded
		footstepAudio.update(
			on: node,
			distanceMoved: actualHorizontalDelta.horizontalLength,
			isMoving: horizontalSpeed > 0.01,
			isCrouching: isCrouching,
			isGrounded: grounded
		)
		if wantsJump && !isCrouching && grounded {
			verticalVelocity = jumpSpeed
			wasAirborneLastFrame = true
			playJumpStartAnimation()
		}
		wantsJump = false
		verticalVelocity -= gravity * dt
		node.position.y = max(standingY, node.position.y + verticalVelocity * dt)
		updateGroundHeight()
		if node.position.y <= standingY {
			node.position.y = standingY
			verticalVelocity = 0
		}
		updateAirAnimationState()
		body.velocity = SCNVector3Zero
	}

	private func updateWalkingAnimation(isMoving: Bool) {
		guard !isWalkingAnimationHeld else {
			stopCurrentWalkingAnimation()
			isWalkingAnimationPlaying = false
			return
		}

		let animationName = walkingAnimationName(isMoving: isMoving)
		guard currentWalkingAnimationName != animationName else { return }

		stopCurrentWalkingAnimation()

		isWalkingAnimationPlaying = animationName != nil
		if let animationName = animationName {
			try? playAnimation(
				named: animationName,
				in: node,
				repeat: true,
				animationKey: walkingAnimationKey
			)
		}
		currentWalkingAnimationName = animationName
	}

	private var requestedCrouchingValue: Bool {
		stateLock.lock()
		defer { stateLock.unlock() }
		return requestedCrouching
	}

	private func applyPendingCrouchChange() {
		let shouldCrouch = requestedCrouchingValue
		guard shouldCrouch != isCrouching else { return }

		isCrouching = shouldCrouch
		stopCurrentWalkingAnimation()
		if isCrouching {
			wantsJump = false
			wasAirborneLastFrame = false
			stopCurrentAirAnimation()
			playCrouchTransition(named: crouchDownAnimationName)
		} else {
			playCrouchTransition(named: crouchUpAnimationName)
		}
		configurePhysics()
	}

	private func playCrouchTransition(named animationName: String) {
		stopCurrentCrouchTransitionAnimation()
		crouchTransitionId += 1
		let transitionId = crouchTransitionId
		currentCrouchTransitionAnimationName = animationName
		isCrouchTransitionPlaying = true

		do {
			try playAnimation(
				named: animationName,
				in: node,
				animationKey: crouchAnimationKey
			) { [weak self] in
				guard let self = self,
					  self.crouchTransitionId == transitionId else { return }

				self.currentCrouchTransitionAnimationName = nil
				self.isCrouchTransitionPlaying = false
				let isMoving = self.movement.x * self.movement.x + self.movement.z * self.movement.z > 0.0001
				self.updateWalkingAnimation(isMoving: isMoving)
			}
		} catch {
			currentCrouchTransitionAnimationName = nil
			isCrouchTransitionPlaying = false
		}
	}

	private func stopCurrentCrouchTransitionAnimation() {
		guard let animationName = currentCrouchTransitionAnimationName else { return }

		try? stopAnimation(
			named: animationName,
			in: node,
			animationKey: crouchAnimationKey
		)
		currentCrouchTransitionAnimationName = nil
	}

	private func stopCurrentAirAnimation() {
		guard let animationName = currentAirAnimationName else { return }

		try? stopAnimation(
			named: animationName,
			in: node,
			animationKey: airAnimationKey
		)
		currentAirAnimationName = nil
	}

	private func stopCurrentWalkingAnimation() {
		guard let animationName = currentWalkingAnimationName else { return }

		try? stopAnimation(
			named: animationName,
			in: node,
			animationKey: walkingAnimationKey
		)
		currentWalkingAnimationName = nil
	}

	private var isWalkingAnimationHeld: Bool {
		return isCrouchTransitionPlaying || walkingAnimationHoldCount > 0 || currentAirAnimationName != nil
	}

	private func holdWalkingAnimation() {
		walkingAnimationHoldCount += 1
		stopCurrentWalkingAnimation()
		isWalkingAnimationPlaying = false
	}

	private func releaseWalkingAnimationHold() {
		walkingAnimationHoldCount = max(0, walkingAnimationHoldCount - 1)
		guard !isWalkingAnimationHeld else { return }

		let isMoving = movement.x * movement.x + movement.z * movement.z > 0.0001
		updateWalkingAnimation(isMoving: isMoving)
	}

	private func walkingAnimationName(isMoving: Bool) -> String? {
		guard !isAirborneForAnimation else { return nil }

		if isCrouching {
			if isMoving {
				return firstExistingAnimation(named: crouchWalkingAnimationCandidates)
			}
			return idleAnimationName(animationSetId: 8)
		}

		let animationSetId = movementAnimationSetId()
		if !isMoving {
			return turnAnimationName(animationSetId: animationSetId) ?? idleAnimationName(animationSetId: animationSetId)
		}

		return movementAnimationName(animationSetId: animationSetId)
	}

	private func movementAnimationName(animationSetId: Int) -> String? {
		let suffix = "\(animationSetId)"
		let lateral = movement.x
		let forward = movement.z
		let isRunningForward = requestedRunningValue && forward > 0.35

		if forward < -0.35 {
			return firstExistingAnimation(named: [
				"anims/back\(suffix).5ds",
				"anims/back1.5ds"
			])
		}
		if abs(lateral) > 0.35 && abs(forward) <= 0.35 {
			let prefixes = lateral < 0 ? ["strafL", "left"] : ["strafR", "right"]
			return firstExistingAnimation(named: prefixes.flatMap { prefix in
				[
					"anims/\(prefix)\(suffix).5ds",
					"anims/\(prefix)1.5ds"
				]
			})
		}
		let prefix = isRunningForward ? "run" : "walk"
		return firstExistingAnimation(named: [
			"anims/\(prefix)\(suffix).5ds",
			"anims/\(prefix)1.5ds",
			"anims/walk1.5ds"
		])
	}

	private func turnAnimationName(animationSetId: Int) -> String? {
		guard abs(turn) > 0.1 else { return nil }
		return firstExistingAnimation(named: [
			"anims/turn\(animationSetId).5ds",
			"anims/turn1.5ds"
		])
	}

	private func idleAnimationName(animationSetId: Int) -> String? {
		let suffix = String(format: "%02d", animationSetId)
		let variants = ["a", "b", "c", "d"]
		let candidates = variants.map { "anims/breath\(suffix)\($0).5ds" } +
			variants.map { "anims/breath01\($0).5ds" }
		return firstExistingAnimation(named: candidates)
	}

	private func movementAnimationSetId() -> Int {
		if isCrouching {
			return 8
		}
		guard let providedId = movementAnimationSetProvider?(),
			  (1...8).contains(providedId) else {
			return 1
		}
		return providedId
	}

	private func playJumpStartAnimation() {
		stopCurrentWalkingAnimation()
		let suffix = "\(movementAnimationSetId())"
		let directionalPrefix = movement.x < -0.2 ? "jumpL" : movement.x > 0.2 ? "jumpR" : "jump"
		let candidates = [
			"anims/\(directionalPrefix)\(suffix).5ds",
			"anims/jump\(suffix).5ds",
			"anims/jump1.5ds"
		]
		playAirAnimation(named: firstExistingAnimation(named: candidates), repeat: false) { [weak self] in
			self?.playFallLoopAnimationIfNeeded()
		}
	}

	private func playFallLoopAnimationIfNeeded() {
		guard isAirborneForAnimation else { return }
		playAirAnimation(named: firstExistingAnimation(named: [
			"anims/!plachteni.5ds"
		]), repeat: true)
	}

	private func playLandingAnimation() {
		stopCurrentAirAnimation()
		guard let animationName = firstExistingAnimation(named: [
			"anims/!doskok.5ds"
		]) else { return }
		playActionAnimation(named: animationName, animationKey: "__landing__")
	}

	private func playAirAnimation(named animationName: String?, repeat shouldRepeat: Bool, completionHandler: (() -> Void)? = nil) {
		stopCurrentAirAnimation()
		guard let animationName = animationName, animationExists(named: animationName) else {
			completionHandler?()
			return
		}

		currentAirAnimationName = animationName
		do {
			try playAnimation(
				named: animationName,
				in: node,
				repeat: shouldRepeat,
				animationKey: airAnimationKey,
				completionHandler: { [weak self] in
					if shouldRepeat == false && self?.currentAirAnimationName == animationName {
						self?.currentAirAnimationName = nil
					}
					completionHandler?()
				}
			)
		} catch {
			currentAirAnimationName = nil
			completionHandler?()
		}
	}

	private func updateAirAnimationState() {
		let isAirborne = isAirborneForAnimation
		if wasAirborneLastFrame && !isAirborne {
			wasAirborneLastFrame = false
			playLandingAnimation()
			updateWalkingAnimation(isMoving: movement.x * movement.x + movement.z * movement.z > 0.0001)
		} else if isAirborne {
			wasAirborneLastFrame = true
		}
	}

	private var isAirborneForAnimation: Bool {
		return node.position.y > standingY + 0.05 || verticalVelocity > 0.05
	}

	private var currentMoveSpeed: SCNFloat {
		if isCrouching {
			return crouchSpeed
		}
		return requestedRunningValue ? runSpeed : walkSpeed
	}

	private var requestedRunningValue: Bool {
		stateLock.lock()
		defer { stateLock.unlock() }
		return requestedRunning
	}

	private func animationExists(named animationName: String) -> Bool {
		let url = mainDirectory.appendingPathComponent(animationName.lowercased())
		return FileManager.default.fileExists(atPath: url.path)
	}

	private func firstExistingAnimation(named candidates: [String]) -> String? {
		return candidates.first { animationExists(named: $0) }
	}

	private func horizontalMovementBasis() -> (forward: SCNVector3, right: SCNVector3) {
		let transform = node.presentation.worldTransform
		let forward = normalizedHorizontalVector(SCNVector3(x: transform.m31, y: 0, z: transform.m33), fallback: SCNVector3(x: 0, y: 0, z: 1))
		let right = normalizedHorizontalVector(SCNVector3(x: transform.m11, y: 0, z: transform.m13), fallback: SCNVector3(x: 1, y: 0, z: 0))
		return (forward, right)
	}

	private func applyWorldYaw(_ yaw: SCNFloat) {
		let worldForward = SCNVector3(x: -sin(yaw), y: 0, z: -cos(yaw))
		let localForward = node.parent?.presentation.convertVector(worldForward, from: nil) ?? worldForward
		let localYaw = atan2(-localForward.x, -localForward.z)
		node.eulerAngles = SCNVector3(x: 0, y: localYaw, z: 0)
	}

	private static func worldYaw(for node: SCNNode) -> SCNFloat {
		let forward = node.presentation.worldFront
		return atan2(-forward.x, -forward.z)
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

	private func normalizedHorizontalVector(_ vector: SCNVector3, fallback: SCNVector3) -> SCNVector3 {
		let length = sqrt(vector.x * vector.x + vector.z * vector.z)
		guard length > 0.0001 else { return fallback }

		return SCNVector3(x: vector.x / length, y: 0, z: vector.z / length)
	}

	private func moveHorizontally(dx: SCNFloat, dz: SCNFloat) {
		guard dx != 0 || dz != 0 else { return }

		let start = node.position

		node.position.x = start.x + dx
		if isBlockedHorizontally(), !tryStepUp(from: start) {
			node.position.x = start.x
			node.position.y = start.y
			horizontalVelocity.x = 0
		}

		let afterX = node.position
		node.position.z = afterX.z + dz
		if isBlockedHorizontally(), !tryStepUp(from: afterX) {
			node.position.z = afterX.z
			node.position.y = afterX.y
			horizontalVelocity.z = 0
		}
	}

	private func isBlockedHorizontally(ignoringContactsBelow localY: SCNFloat? = nil) -> Bool {
		guard let body = node.physicsBody else { return false }

		scene.physicsWorld.updateCollisionPairs()
		return scene.physicsWorld.contactTest(with: body, options: [
			SCNPhysicsWorld.TestOption.collisionBitMask: PhysicsCategory.playerBlocking
		]).contains { contact in
			let otherNode = contact.nodeA === node ? contact.nodeB : contact.nodeA
			guard otherNode !== node else { return false }

			let normal = contact.contactNormal
			guard abs(normal.y) < minGroundNormalY else { return false }

			if let localY = localY {
				let parent = node.parent
				let localContact = parent?.presentation.convertPosition(contact.contactPoint, from: nil) ?? contact.contactPoint
				if localContact.y <= localY {
					return false
				}
			}

			return true
		}
	}

	private var isGrounded: Bool {
		updateGroundHeight()
		return node.position.y <= standingY + 0.03 && verticalVelocity <= 0
	}

	private func updateGroundHeight() {
		guard let groundY = groundHeight(at: node.position) else { return }

		let verticalDelta = groundY - node.position.y
		if verticalDelta <= maxStepHeight && verticalDelta >= -maxGroundSnapDistance {
			standingY = groundY
		}
	}

	private func tryStepUp(from start: SCNVector3) -> Bool {
		guard verticalVelocity <= 0 else { return false }

		let attemptedPosition = node.position
		node.position = SCNVector3(
			x: attemptedPosition.x,
			y: start.y + maxStepHeight,
			z: attemptedPosition.z
		)

		if isBlockedHorizontally(ignoringContactsBelow: start.y + maxStepHeight + 0.05) {
			node.position.y = start.y
			return false
		}

		guard let groundY = groundHeight(at: node.position) else {
			node.position.y = start.y
			return false
		}

		let stepHeight = groundY - start.y
		guard stepHeight >= -0.03, stepHeight <= maxStepHeight else {
			node.position.y = start.y
			return false
		}

		node.position.y = groundY
		standingY = groundY
		return true
	}

	private func groundHeight(at localPosition: SCNVector3) -> SCNFloat? {
		let parent = node.parent
		let probeOffsets = [
			SCNVector3Zero,
			SCNVector3(x: groundProbeRadius, y: 0, z: 0),
			SCNVector3(x: -groundProbeRadius, y: 0, z: 0),
			SCNVector3(x: 0, y: 0, z: groundProbeRadius),
			SCNVector3(x: 0, y: 0, z: -groundProbeRadius)
		]
		var highestGroundY: SCNFloat?

		for offset in probeOffsets {
			let probePosition = localPosition + offset
			let worldPosition = parent?.presentation.convertPosition(probePosition, to: nil) ?? probePosition
			let from = SCNVector3(x: worldPosition.x, y: worldPosition.y + groundProbeLift, z: worldPosition.z)
			let to = SCNVector3(x: worldPosition.x, y: worldPosition.y - maxGroundSnapDistance, z: worldPosition.z)
			let hits = scene.physicsWorld.rayTestWithSegment(from: from, to: to, options: [
				SCNPhysicsWorld.TestOption.collisionBitMask: PhysicsCategory.playerBlocking,
				SCNPhysicsWorld.TestOption.searchMode: SCNPhysicsWorld.TestSearchMode.all
			])

			for hit in hits where isGroundHit(hit) {
				let localContact = parent?.presentation.convertPosition(hit.worldCoordinates, from: nil) ?? hit.worldCoordinates
				if highestGroundY == nil || localContact.y > highestGroundY! {
					highestGroundY = localContact.y
				}
			}
		}

		return highestGroundY
	}

	private func isGroundHit(_ hit: SCNHitTestResult) -> Bool {
		guard hit.node !== node else { return false }
		return hit.worldNormal.y >= minGroundNormalY
	}

	private func configurePhysics() {
		let radius: CGFloat = 0.28
		let height: CGFloat = isCrouching ? 0.82 : 1.35
		let centerY: SCNFloat = isCrouching ? 0.55 : 0.95

		let cylinderShape = SCNPhysicsShape(geometry: SCNCylinder(radius: radius, height: height), options: nil)
		let lowerSphereShape = SCNPhysicsShape(geometry: SCNSphere(radius: radius), options: nil)
		let upperSphereShape = SCNPhysicsShape(geometry: SCNSphere(radius: radius), options: nil)
		let playerPhysicsShape = SCNPhysicsShape(
			shapes: [cylinderShape, lowerSphereShape, upperSphereShape],
			transforms: [
				NSValue(scnMatrix4: SCNMatrix4MakeTranslation(0, centerY, 0)),
				NSValue(scnMatrix4: SCNMatrix4MakeTranslation(0, centerY - SCNFloat(height / 2), 0)),
				NSValue(scnMatrix4: SCNMatrix4MakeTranslation(0, centerY + SCNFloat(height / 2), 0))
			]
		)

		let body = SCNPhysicsBody(type: .kinematic, shape: playerPhysicsShape)
		body.allowsResting = false
		body.mass = 80
		body.damping = 0
		body.angularDamping = 1
		body.friction = 0
		body.rollingFriction = 0
		body.restitution = 0
		body.continuousCollisionDetectionThreshold = 0.2
		body.categoryBitMask = PhysicsCategory.player
		body.collisionBitMask = PhysicsCategory.playerBlocking
		body.contactTestBitMask = PhysicsCategory.playerBlocking
		node.physicsBody = body
	}

	private func resetAngularVelocity() {
		node.physicsBody?.angularVelocity = SCNVector4Zero
	}

}

private final class FootstepAudio {

	private let standingStepDistance: SCNFloat = 1.15
	private let crouchStepDistance: SCNFloat = 1.45
	private let standingVolume: Float = 0.42
	private let crouchVolume: Float = 0.22
	private let soundName = "07b_chuzeTomdrevo.wav"
	private let maxPlaybackDuration: TimeInterval = 1

	private var distanceSinceStep: SCNFloat = 0
	private var sourceCache: [String: SCNAudioSource] = [:]

	func reset() {
		distanceSinceStep = 0
	}

	func update(on node: SCNNode, distanceMoved: SCNFloat, isMoving: Bool, isCrouching: Bool, isGrounded: Bool) {
		guard isMoving, isGrounded, distanceMoved > 0 else {
			reset()
			return
		}

		distanceSinceStep += distanceMoved
		let stepDistance = isCrouching ? crouchStepDistance : standingStepDistance
		guard distanceSinceStep >= stepDistance else { return }
		distanceSinceStep = 0

		playStep(on: node, volume: isCrouching ? crouchVolume : standingVolume)
	}

	private func playStep(on node: SCNNode, volume: Float) {
		guard let source = audioSource(named: soundName, volume: volume) else { return }
		let player = SCNAudioPlayer(source: source)
		player.didFinishPlayback = { [weak node, weak player] in
			guard let player = player else { return }
			DispatchQueue.main.async {
				node?.removeAudioPlayer(player)
			}
		}
		node.addAudioPlayer(player)

		DispatchQueue.main.asyncAfter(deadline: .now() + maxPlaybackDuration) { [weak node, weak player] in
			guard let player = player else { return }
			node?.removeAudioPlayer(player)
		}
	}

	private func audioSource(named soundName: String, volume: Float) -> SCNAudioSource? {
		let cacheKey = "\(soundName):\(volume)"
		if let source = sourceCache[cacheKey] {
			return source
		}

		let url = mainDirectory.appendingPathComponent("sounds/" + soundName)
		guard FileManager.default.fileExists(atPath: url.path),
			  let source = SCNAudioSource(url: url) else {
			return nil
		}

		source.loops = false
		source.isPositional = true
		source.shouldStream = false
		source.volume = volume
		sourceCache[cacheKey] = source
		return source
	}

}

private extension SCNVector3 {

	var horizontalLength: SCNFloat {
		return sqrt(x * x + z * z)
	}

}
