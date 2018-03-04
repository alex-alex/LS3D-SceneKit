//
//  CollisionAABB.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

struct AABB {
	var volume: Volume
	var min: SCNVector3
	var max: SCNVector3

	init(stream: InputStream) throws {
		volume = try Volume(stream: stream, hasLink: true)
		min = try SCNVector3(stream: stream)
		max = try SCNVector3(stream: stream)
	}

	func getNode(treeKlz: Collisions) -> SCNNode {
		let node = SCNNode()
		let box = SCNBox(
			width: CGFloat(max.x-min.x),
			height: CGFloat(max.y-min.y),
			length: CGFloat(max.z-min.z),
			chamferRadius: 0
		)
//		box.firstMaterial = SCNMaterial()
//		box.firstMaterial?.cullMode = .front
//		box.firstMaterial?.diffuse.contents = SKColor.red
//		node.geometry = box
		node.position = SCNVector3(
			CGFloat(min.x+(max.x-min.x)/2),
			CGFloat(min.y+(max.y-min.y)/2),
			CGFloat(min.z+(max.z-min.z)/2)
		)
		node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
		return node
	}
}
