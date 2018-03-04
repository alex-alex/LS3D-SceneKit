//
//  CollisionCylinder.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

struct Cylinder {
	var volume: Volume
	var position: CGPoint
	var radius: Float

	init(stream: InputStream) throws {
		volume = try Volume(stream: stream, hasLink: true)
		position = try CGPoint(stream: stream)
		radius = try stream.read()
	}

	func getNode(treeKlz: Collisions) -> SCNNode {
		//let _node = treeKlz.getNode(linkId: volume.linkId!)
		let node = SCNNode()
		let cylinder = SCNCylinder(radius: CGFloat(radius), height: 1000)
//		cylinder.firstMaterial = SCNMaterial()
//		cylinder.firstMaterial?.cullMode = .front
//		cylinder.firstMaterial?.diffuse.contents = SKColor.blue
//		node.geometry = cylinder
		node.position = SCNVector3(position.x, 0, position.y)
		node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: cylinder, options: nil))
		return node
	}
}
