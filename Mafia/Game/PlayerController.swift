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

	private var movement = SCNVector3Zero
	private var turn: SCNFloat = 0
	private var pendingLook: SCNFloat = 0
	private var wantsJump = false
	private let baseHeading: SCNFloat
	private var lookYaw: SCNFloat = 0
	private var horizontalVelocity = SCNVector3Zero
	private var verticalVelocity: SCNFloat = 0
	private let standingY: SCNFloat
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

	private let walkSpeed: SCNFloat = 3.2
	private let acceleration: SCNFloat = 14
	private let stopAcceleration: SCNFloat = 24
	private let turnSpeed: SCNFloat = 2.8
	private let jumpSpeed: SCNFloat = 5.2

	init(node: SCNNode, scene: SCNScene) {
		self.node = node
		self.scene = scene
		baseHeading = node.presentation.eulerAngles.y
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

	func jump() {
		wantsJump = true
	}

	func stop() {
		movement = SCNVector3Zero
		turn = 0
		horizontalVelocity = SCNVector3Zero
		verticalVelocity = 0
		resetAngularVelocity()
	}

	func update(deltaTime: TimeInterval) {
		guard let body = node.physicsBody else { return }

		let dt = SCNFloat(max(0, min(deltaTime, 1.0 / 20.0)))
		lastAppliedLook = pendingLook
		lookYaw += turn * turnSpeed * dt + pendingLook
		pendingLook = 0
		body.angularVelocity = SCNVector4Zero

		let movementHeading = baseHeading + lookYaw
		node.eulerAngles.y = movementHeading
		let movementBasis = horizontalMovementBasis()
		let desiredVelocity = SCNVector3(
			x: (movementBasis.right.x * movement.x + movementBasis.forward.x * movement.z) * walkSpeed,
			y: 0,
			z: (movementBasis.right.z * movement.x + movementBasis.forward.z * movement.z) * walkSpeed
		)
		lastMovement = movement
		lastDesiredVelocity = desiredVelocity

		let horizontalSpeed = sqrt(movement.x * movement.x + movement.z * movement.z)
		let rate = horizontalSpeed > 0 ? acceleration : stopAcceleration
		let blend = min(1, rate * dt)
		horizontalVelocity.x += (desiredVelocity.x - horizontalVelocity.x) * blend
		horizontalVelocity.z += (desiredVelocity.z - horizontalVelocity.z) * blend

		moveHorizontally(dx: horizontalVelocity.x * dt, dz: horizontalVelocity.z * dt)
		if wantsJump && node.position.y <= standingY + 0.01 {
			verticalVelocity = jumpSpeed
		}
		wantsJump = false
		verticalVelocity -= 12 * dt
		node.position.y = max(standingY, node.position.y + verticalVelocity * dt)
		if node.position.y <= standingY {
			verticalVelocity = 0
		}
		body.velocity = SCNVector3Zero
	}

	private func horizontalMovementBasis() -> (forward: SCNVector3, right: SCNVector3) {
		let transform = node.transform
		let forward = normalizedHorizontalVector(SCNVector3(x: transform.m31, y: 0, z: transform.m33), fallback: SCNVector3(x: 0, y: 0, z: 1))
		let right = normalizedHorizontalVector(SCNVector3(x: transform.m11, y: 0, z: transform.m13), fallback: SCNVector3(x: 1, y: 0, z: 0))
		return (forward, right)
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
		if isBlockedHorizontally() {
			node.position.x = start.x
			horizontalVelocity.x = 0
		}

		let afterX = node.position
		node.position.z = afterX.z + dz
		if isBlockedHorizontally() {
			node.position.z = afterX.z
			horizontalVelocity.z = 0
		}
	}

	private func isBlockedHorizontally() -> Bool {
		guard let body = node.physicsBody else { return false }

		return scene.physicsWorld.contactTest(with: body, options: nil).contains { contact in
			let otherNode = contact.nodeA === node ? contact.nodeB : contact.nodeA
			guard otherNode !== node else { return false }

			let normal = contact.contactNormal
			return abs(normal.y) < 0.65
		}
	}

	private func configurePhysics() {
		let radius: CGFloat = 0.28
		let height: CGFloat = 1.35
		let centerY: SCNFloat = 0.95

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
		node.physicsBody = body
	}

	private func resetAngularVelocity() {
		node.physicsBody?.angularVelocity = SCNVector4Zero
	}

}
