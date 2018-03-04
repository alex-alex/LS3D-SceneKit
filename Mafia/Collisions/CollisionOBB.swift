//
//  CollisionOBB.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

struct OBB {
	var volume: Volume
	var minExtent: SCNVector3
	var maxExtent: SCNVector3
	var transform: SCNMatrix4
	var inverseTransform: SCNMatrix4

	init(stream: InputStream) throws {
		volume = try Volume(stream: stream, hasLink: true)
		minExtent = try SCNVector3(stream: stream)
		maxExtent = try SCNVector3(stream: stream)
		transform = try SCNMatrix4(stream: stream)
		inverseTransform = try SCNMatrix4(stream: stream)
	}

	func getNode(treeKlz: Collisions) -> SCNNode {
		let node = SCNNode()
		let box = SCNBox(
			width: CGFloat(maxExtent.x-minExtent.x),
			height: CGFloat(maxExtent.y-minExtent.y),
			length: CGFloat(maxExtent.z-minExtent.z),
			chamferRadius: 0
		)
//		box.firstMaterial = SCNMaterial()
//		box.firstMaterial?.cullMode = .front
//		box.firstMaterial?.diffuse.contents = SKColor.magenta
//		node.geometry = box
		node.transform = transform
		node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
		return node
	}
}
