//
//  Vehicle.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

final class Vehicle {

	let node: SCNNode
	let physicsVehicle: SCNPhysicsVehicle

	private let maximumSteering: CGFloat = 0.55
	private let engineForce: CGFloat = 6500
	private let brakeForce: CGFloat = 260
	private let idleBrakeForce: CGFloat = 8
	private let tractionAssistSpeedLimit: CGFloat = 0.35
	private let tractionAssistScale: CGFloat = 0.15
	private let wheelLateralOffsetScale: SCNFloat = 0.85
	private let resetHeight: SCNFloat = 1.2
	private var isBraking = false

	var force: CGFloat = 0
	var speed: CGFloat {
		return CGFloat(abs(physicsVehicle.speedInKilometersPerHour))
	}
	private var chassisSpeed: CGFloat {
		guard let velocity = node.physicsBody?.velocity else { return 0 }
		return CGFloat(sqrt(
			velocity.x * velocity.x +
			velocity.y * velocity.y +
			velocity.z * velocity.z
		))
	}
	var vehicleSteering: CGFloat = 0 {
		didSet {
			if vehicleSteering < -maximumSteering {
				vehicleSteering = -maximumSteering
			}
			if vehicleSteering > maximumSteering {
				vehicleSteering = maximumSteering
			}
		}
	}

	init(scene: SCNScene, node: SCNNode) {
		let taxiNode = node.childNode(withName: "BODY", recursively: false)!
		self.node = taxiNode

		Vehicle.attachChassisVisuals(from: node, to: taxiNode)

		taxiNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
		taxiNode.physicsBody?.allowsResting = false
		taxiNode.physicsBody?.mass = 1000
		taxiNode.physicsBody?.restitution = 0.1
		taxiNode.physicsBody?.friction = 0.5
		taxiNode.physicsBody?.rollingFriction = 0

		let whl0 = node.childNode(withName: "WHL0", recursively: true)!
		let whr0 = node.childNode(withName: "WHR0", recursively: true)!
		let whl1 = node.childNode(withName: "WHL1", recursively: true)!
		let whr1 = node.childNode(withName: "WHR1", recursively: true)!

		let wheel0 = SCNPhysicsVehicleWheel(node: whl0)
		let wheel1 = SCNPhysicsVehicleWheel(node: whr0)
		let wheel2 = SCNPhysicsVehicleWheel(node: whl1)
		let wheel3 = SCNPhysicsVehicleWheel(node: whr1)

		let wheelLateralOffset = (whl0.boundingBox.max.x - whl0.boundingBox.min.x) * wheelLateralOffsetScale

		wheel0.connectionPosition = whl0.convertPosition(SCNVector3(), to: taxiNode) + SCNVector3(-wheelLateralOffset, 0, 0)
		wheel1.connectionPosition = whr0.convertPosition(SCNVector3(), to: taxiNode) + SCNVector3( wheelLateralOffset, 0, 0)
		wheel2.connectionPosition = whl1.convertPosition(SCNVector3(), to: taxiNode) + SCNVector3(-wheelLateralOffset, 0, 0)
		wheel3.connectionPosition = whr1.convertPosition(SCNVector3(), to: taxiNode) + SCNVector3( wheelLateralOffset, 0, 0)

		physicsVehicle = SCNPhysicsVehicle(chassisBody: taxiNode.physicsBody!, wheels: [
			wheel0, wheel1, wheel2, wheel3
		])
		scene.physicsWorld.addBehavior(physicsVehicle)
	}

	private static func attachChassisVisuals(from vehicleRoot: SCNNode, to chassisNode: SCNNode) {
		let detachedWheelNames: Set<String> = ["WHL0", "WHR0", "WHL1", "WHR1"]

		for childNode in vehicleRoot.childNodes {
			guard childNode !== chassisNode else { continue }
			guard !detachedWheelNames.contains(childNode.name ?? "") else { continue }

			let worldTransform = childNode.worldTransform
			chassisNode.addChildNode(childNode)
			childNode.transform = chassisNode.convertTransform(worldTransform, from: nil)
		}
	}

	func applyForces() {
		physicsVehicle.setSteeringAngle(vehicleSteering, forWheelAt: 0)
		physicsVehicle.setSteeringAngle(vehicleSteering, forWheelAt: 1)

		let clampedForce = max(-engineForce, min(engineForce, force))
		let brakingForce = isBraking ? brakeForce : (clampedForce == 0 ? idleBrakeForce : 0)

		for wheelIndex in 0..<4 {
			physicsVehicle.applyBrakingForce(0, forWheelAt: wheelIndex)
			physicsVehicle.applyEngineForce(0, forWheelAt: wheelIndex)
			physicsVehicle.applyBrakingForce(brakingForce, forWheelAt: wheelIndex)
		}

		physicsVehicle.applyEngineForce(clampedForce, forWheelAt: 2)
		physicsVehicle.applyEngineForce(clampedForce, forWheelAt: 3)

		if clampedForce != 0 && chassisSpeed < tractionAssistSpeedLimit {
			let forward = node.presentation.worldFront
			let assistForce = SCNFloat(clampedForce * tractionAssistScale)
			let assist = SCNVector3(
				x: forward.x * assistForce,
				y: 0,
				z: forward.z * assistForce
			)
			node.physicsBody?.applyForce(assist, at: node.presentation.worldPosition, asImpulse: false)
		}
	}

	func resetUpright() {
		let currentPosition = node.presentation.position
		let forward = node.presentation.worldFront
		let yaw = atan2(-forward.x, -forward.z)

		node.physicsBody?.clearAllForces()
		node.physicsBody?.velocity = SCNVector3Zero
		node.physicsBody?.angularVelocity = SCNVector4Zero
		node.position = SCNVector3(
			x: currentPosition.x,
			y: currentPosition.y + resetHeight,
			z: currentPosition.z
		)
		node.eulerAngles = SCNVector3(x: 0, y: yaw, z: 0)
		updateControls(throttle: 0, brake: false, steering: 0)
		applyForces()
	}

	func updateControls(throttle: CGFloat, brake: Bool, steering: CGFloat) {
		isBraking = brake
		vehicleSteering = steering * maximumSteering
		force = brake ? 0 : max(-1, min(1, throttle)) * engineForce
	}

}
