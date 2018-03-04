//
//  CollisionXTOBB.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

struct XTOBB {
	var volume: Volume
	var min: SCNVector3
	var max: SCNVector3
	var minExtent: SCNVector3
	var maxExtent: SCNVector3
	var transform: SCNMatrix4
	var inverseTransform: SCNMatrix4

	init(stream: InputStream) throws {
		volume = try Volume(stream: stream, hasLink: true)
		min = try SCNVector3(stream: stream)
		max = try SCNVector3(stream: stream)
		minExtent = try SCNVector3(stream: stream)
		maxExtent = try SCNVector3(stream: stream)
		transform = try SCNMatrix4(stream: stream)
		inverseTransform = try SCNMatrix4(stream: stream)
	}

	func getNode(treeKlz: Collisions) -> SCNNode {
		guard let _node = treeKlz.getNode(linkId: volume.linkId!) else { return SCNNode() }

		let node = SCNNode()
//		let box = SCNBox(width: CGFloat(maxExtent.x-minExtent.x), height: CGFloat(maxExtent.y-minExtent.y), length: CGFloat(maxExtent.z-minExtent.z), chamferRadius: 0)
//		box.firstMaterial = SCNMaterial()
//		box.firstMaterial?.cullMode = .front
//		box.firstMaterial?.diffuse.contents = SKColor.green
//		node.geometry = box
//		node.transform = transform

		if volume.mtlId == 41 {
			let shape = SCNPhysicsShape(node: _node, options: [:])
			_node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
		} else {
//			let convertedTransform = _node.convertTransform(transform, from: treeKlz.rootNode)
//			let shape = SCNPhysicsShape(shapes: [SCNPhysicsShape(geometry: box, options: nil)], transforms: [NSValue(scnMatrix4: transform)])
//			node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))

//			let shape = SCNPhysicsShape(node: _node, options: [
//				SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron
//			])
//			_node.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
		}

		return node
	}
}
