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

	var force: CGFloat = 0
	var vehicleSteering: CGFloat = 0 {
		didSet {
			if vehicleSteering < -0.6 {
				vehicleSteering = -0.6
			}
			if vehicleSteering > 0.6 {
				vehicleSteering = 0.6
			}
		}
	}

	init(scene: SCNScene, node: SCNNode) {
		//self.node = node

		let taxiNode = node.childNode(withName: "BODY", recursively: false)!
		self.node = taxiNode

		/*let orphans = taxiNodeX.childNodes.filter({ node -> Bool in
			guard let name = node.name else { return true }
			return !["BODY", "DWHL0", "DWHR0", "DWHL1", "DWHR1"].contains(name)
		})
		print("orphans:", orphans)*/

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

		let wheelHalfWidth = 1 * (whl0.boundingBox.max.x - whl0.boundingBox.min.x)

		wheel0.connectionPosition = whl0.convertPosition(SCNVector3(), to: taxiNode) + SCNVector3(-wheelHalfWidth, 0, 0)
		wheel1.connectionPosition = whr0.convertPosition(SCNVector3(), to: taxiNode) + SCNVector3( wheelHalfWidth, 0, 0)
		wheel2.connectionPosition = whl1.convertPosition(SCNVector3(), to: taxiNode) + SCNVector3(-wheelHalfWidth, 0, 0)
		wheel3.connectionPosition = whr1.convertPosition(SCNVector3(), to: taxiNode) + SCNVector3( wheelHalfWidth, 0, 0)

		physicsVehicle = SCNPhysicsVehicle(chassisBody: taxiNode.physicsBody!, wheels: [
			wheel0, wheel1, wheel2, wheel3
		])
		scene.physicsWorld.addBehavior(physicsVehicle)
	}

	func applyForces() {
		physicsVehicle.setSteeringAngle(vehicleSteering, forWheelAt: 0)
		physicsVehicle.setSteeringAngle(vehicleSteering, forWheelAt: 1)

		physicsVehicle.applyEngineForce(force, forWheelAt: 2)
		physicsVehicle.applyEngineForce(force, forWheelAt: 3)
	}

}
