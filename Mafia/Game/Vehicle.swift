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
	private let tractionAssistSpeedLimit: CGFloat = 2
	private let launchMinimumWheelForceScale: CGFloat = 0.35
	private let reverseLaunchMinimumWheelForceScale: CGFloat = 0.7
	private let centerOfMassYOffset: SCNFloat = -0.45
	private let wheelSuspensionRestLength: CGFloat = 0.18
	private let wheelSuspensionTravel: CGFloat = 0.36
	private let wheelSuspensionStiffness: CGFloat = 32
	private let wheelSuspensionCompression: CGFloat = 16
	private let wheelSuspensionDamping: CGFloat = 24
	private let wheelFrictionSlip: CGFloat = 6
	private let wheelRadiusScale: CGFloat = 1.16
	private let wheelSteeringAxis = SCNVector3(x: 0, y: -1, z: 0)
	private let wheelAxle = SCNVector3(x: 1, y: 0, z: 0)
	private let chassisPhysicsWidthScale: SCNFloat = 0.62
	private let chassisPhysicsHeightScale: SCNFloat = 0.28
	private let chassisPhysicsLengthScale: SCNFloat = 0.58
	private let chassisPhysicsCenterHeight: SCNFloat = 0.72
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

		taxiNode.physicsBody = SCNPhysicsBody(
			type: .dynamic,
			shape: Vehicle.chassisPhysicsShape(
				for: taxiNode,
				widthScale: chassisPhysicsWidthScale,
				heightScale: chassisPhysicsHeightScale,
				lengthScale: chassisPhysicsLengthScale,
				centerHeight: chassisPhysicsCenterHeight
			)
		)
		taxiNode.physicsBody?.allowsResting = false
		taxiNode.physicsBody?.mass = 1000
		taxiNode.physicsBody?.restitution = 0
		taxiNode.physicsBody?.friction = 0.5
		taxiNode.physicsBody?.rollingFriction = 0
		taxiNode.physicsBody?.damping = 0.12
		taxiNode.physicsBody?.angularDamping = 0.8
		taxiNode.physicsBody?.centerOfMassOffset = SCNVector3(x: 0, y: centerOfMassYOffset, z: 0)

		let whl0 = node.childNode(withName: "WHL0", recursively: true)!
		let whr0 = node.childNode(withName: "WHR0", recursively: true)!
		let whl1 = node.childNode(withName: "WHL1", recursively: true)!
		let whr1 = node.childNode(withName: "WHR1", recursively: true)!

		let wheel0 = SCNPhysicsVehicleWheel(node: whl0)
		let wheel1 = SCNPhysicsVehicleWheel(node: whr0)
		let wheel2 = SCNPhysicsVehicleWheel(node: whl1)
		let wheel3 = SCNPhysicsVehicleWheel(node: whr1)

		let wheels = [wheel0, wheel1, wheel2, wheel3]
		let wheelNodes = [whl0, whr0, whl1, whr1]

		for (wheel, wheelNode) in zip(wheels, wheelNodes) {
			wheel.radius = Vehicle.wheelRadius(for: wheelNode) * wheelRadiusScale
		}

		wheel0.connectionPosition = Vehicle.wheelConnectionPosition(for: whl0, wheel: wheel0, restLength: wheelSuspensionRestLength, in: taxiNode)
		wheel1.connectionPosition = Vehicle.wheelConnectionPosition(for: whr0, wheel: wheel1, restLength: wheelSuspensionRestLength, in: taxiNode)
		wheel2.connectionPosition = Vehicle.wheelConnectionPosition(for: whl1, wheel: wheel2, restLength: wheelSuspensionRestLength, in: taxiNode)
		wheel3.connectionPosition = Vehicle.wheelConnectionPosition(for: whr1, wheel: wheel3, restLength: wheelSuspensionRestLength, in: taxiNode)

		physicsVehicle = SCNPhysicsVehicle(chassisBody: taxiNode.physicsBody!, wheels: wheels)
		configure(wheels: wheels)
		scene.physicsWorld.addBehavior(physicsVehicle)
	}

	private static func chassisPhysicsShape(
		for chassisNode: SCNNode,
		widthScale: SCNFloat,
		heightScale: SCNFloat,
		lengthScale: SCNFloat,
		centerHeight: SCNFloat
	) -> SCNPhysicsShape {
		let bounds = chassisNode.boundingBox
		let width = bounds.max.x - bounds.min.x
		let height = bounds.max.y - bounds.min.y
		let length = bounds.max.z - bounds.min.z
		let box = SCNBox(
			width: CGFloat(width * widthScale),
			height: CGFloat(height * heightScale),
			length: CGFloat(length * lengthScale),
			chamferRadius: CGFloat(height * heightScale * 0.18)
		)
		let shapeNode = SCNNode(geometry: box)
		shapeNode.position = SCNVector3(
			x: (bounds.min.x + bounds.max.x) / 2,
			y: bounds.min.y + height * centerHeight,
			z: (bounds.min.z + bounds.max.z) / 2
		)
		return SCNPhysicsShape(node: shapeNode, options: nil)
	}

	private static func wheelRadius(for wheelNode: SCNNode) -> CGFloat {
		let bounds = wheelNode.boundingBox
		let verticalDiameter = bounds.max.y - bounds.min.y
		let longitudinalDiameter = bounds.max.z - bounds.min.z
		let diameter = max(verticalDiameter, longitudinalDiameter)
		return CGFloat(diameter / 2)
	}

	private static func wheelConnectionPosition(for wheelNode: SCNNode, wheel: SCNPhysicsVehicleWheel, restLength: CGFloat, in chassisNode: SCNNode) -> SCNVector3 {
		let rideHeight = SCNFloat(wheel.radius + restLength)
		return wheelNode.convertPosition(SCNVector3(), to: chassisNode) + SCNVector3(x: 0, y: rideHeight, z: 0)
	}

	private func configure(wheels: [SCNPhysicsVehicleWheel]) {
		for wheel in wheels {
			wheel.suspensionRestLength = wheelSuspensionRestLength
			wheel.maximumSuspensionTravel = wheelSuspensionTravel
			wheel.suspensionStiffness = wheelSuspensionStiffness
			wheel.suspensionCompression = wheelSuspensionCompression
			wheel.suspensionDamping = wheelSuspensionDamping
			wheel.frictionSlip = wheelFrictionSlip
			wheel.steeringAxis = wheelSteeringAxis
			wheel.axle = wheelAxle
		}
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

		let launchProgress = min(1, chassisSpeed / tractionAssistSpeedLimit)
		let minimumWheelForceScale = clampedForce > 0 ? reverseLaunchMinimumWheelForceScale : launchMinimumWheelForceScale
		let launchWheelForceScale = minimumWheelForceScale + (1 - minimumWheelForceScale) * launchProgress
		let wheelForce = clampedForce * launchWheelForceScale

		physicsVehicle.applyEngineForce(wheelForce, forWheelAt: 2)
		physicsVehicle.applyEngineForce(wheelForce, forWheelAt: 3)
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
		force = brake ? 0 : -max(-1, min(1, throttle)) * engineForce
	}

}
