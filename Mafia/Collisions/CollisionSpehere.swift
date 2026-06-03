//
//  CollisionSpehere.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

struct Sphere {
	var volume: Volume
	var position: SCNVector3
	var radius: Float

	init(stream: InputStream) throws {
		volume = try Volume(stream: stream, hasLink: true)
		position = try SCNVector3(stream: stream)
		radius = try stream.read()
	}

	func getNode(treeKlz: Collisions) -> SCNNode {
		let node = SCNNode()
		let sphere = SCNSphere(radius: CGFloat(radius))
		node.geometry = sphere
		node.configureAsCollisionWireframe()
		node.position = position
		node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: sphere, options: nil))
		node.physicsBody?.configureAsWorldCollider()
		return node
	}
}
