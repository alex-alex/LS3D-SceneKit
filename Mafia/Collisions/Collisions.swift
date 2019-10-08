//
//  Collisions.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/30/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

struct Reference {
	init(stream: InputStream) throws {
		let _: UInt32 = try stream.read()
//		int32 volumeBufferOffset : 24;
//		int32 volumeType         :  8;
	}
}

struct Cell {
	var numReferences: UInt32
	var height: Float

	init(stream: InputStream) throws {
		numReferences = try stream.read()
		stream.currentOffset += 4
		height = try stream.read()
		stream.currentOffset += 4

		for _ in 0 ..< numReferences {
			_ = try Reference(stream: stream)
		}

		for _ in 0 ..< numReferences {
			let _: UInt8 = try stream.read()
		}

		let padding = numReferences % 4
		if padding != 0 {
			stream.currentOffset += Int(padding)
		}
	}
}

final class Collisions {

	enum Error: Swift.Error {
		case file
	}

	let node = SCNNode()
	let rootNode: SCNNode
	//var names: [(Int, String)] = []
	var nodes: [Int: SCNNode] = [:]

	init(name: String, scene: SCNScene) throws {
		self.rootNode = scene.rootNode

		let url = mainDirectory.appendingPathComponent(name + "/tree.klz")

		guard let stream = InputStream(url: url) else { throw Error.file }
		stream.open()

		try process(stream: stream)
	}

	func getNode(linkId: UInt32) -> SCNNode? {
		return nodes[Int(linkId)]
	}

	func getNodeInternal(type: Int, name: String) -> SCNNode? {
		let comps = name.split(separator: ".")
		if comps.count > 1 {
			guard comps.count == 2 else { fatalError() }
			guard let parent = rootNode.childNode(withName: String(comps[0]), recursively: true) else { return nil }
			let node = parent.childNode(withName: String(comps[1]), recursively: false)
			return node
		} else {
			var node: SCNNode?
			if type == 1 {
				node = rootNode.childNodes[0].childNode(withName: String(comps[0]), recursively: false)
			} else if type == 2 {
				node = rootNode.childNodes[1].childNode(withName: String(comps[0]), recursively: false)
			}

			if node == nil {
//				print("recursive")
				node = rootNode.childNode(withName: String(comps[0]), recursively: true)
			}

			if node == nil {
				print("not found")
			}

//			if i != 1 {
//				print("###", i, name, "#", node?.parent?.name, node?.parent?.parent?.name, node?.parent?.parent?.parent?.name, node?.parent?.parent?.parent?.parent?.name)
//			}

			return node
		}
	}

	// swiftlint:disable:next function_body_length
	private func process(stream: InputStream) throws {
		// KLZ Header

		let str: String = try stream.read(maxLength: 4)
		guard str == "GifC" else { throw Error.file }

		let ver: UInt32 = try stream.read()
		guard ver == 5 else { throw Error.file }

		let _gridDataOffset: UInt32 = try stream.read() // 5484
		let gridDataOffset = Int(_gridDataOffset)
		let _numLinks: UInt32 = try stream.read() // 287
		let numLinks = Int(_numLinks)
		let _: UInt32 = try stream.read() // 379
		let _: UInt32 = try stream.read() // 0

		// Links

		var linkNameOffsetTable: [UInt32] = []
		for _ in 0 ..< numLinks {
			try linkNameOffsetTable.append(stream.read())
		}

		print("numLinks:", numLinks)

		for i in 0 ..< numLinks {
			let startOffset = Int(linkNameOffsetTable[i])
			stream.currentOffset = startOffset
			let linkType: UInt32 = try stream.read()

			let endOffset: Int
			if i < numLinks - 1 {
				endOffset = Int(linkNameOffsetTable[i + 1])
			} else {
				endOffset = gridDataOffset
			}

			let str: String = try stream.read(maxLength: endOffset - startOffset)

			//names.append((Int(linkType), str))

			nodes[i] = getNodeInternal(type: Int(linkType), name: str)
		}

		// Collision Data Header

		stream.currentOffset = gridDataOffset

		let _: Float = try stream.read()		// minX
		let _: Float = try stream.read()		// minY
		let _: Float = try stream.read()		// maxX
		let _: Float = try stream.read()		// maxY
		let _: Float = try stream.read()		// cellWidth
		let _: Float = try stream.read()		// cellLength
		let width: UInt32 = try stream.read()
		let length: UInt32 = try stream.read()
		let _: Float = try stream.read()		// unknown

		//	print("minX:", minX)
		//	print("minY:", minY)
		//	print("maxX:", maxX)
		//	print("maxY:", maxY)
		//	print("cellWidth:", cellWidth)
		//	print("cellLength:", cellLength)
		//	print("width:", width)
		//	print("length:", length)
		//	print("unknown:", unknown)

		//	let box = SCNPlane(width: CGFloat(maxX-minX), height: CGFloat(maxY-minY))
		//	box.firstMaterial = SCNMaterial()
		//	box.firstMaterial?.diffuse.contents = SKColor.black
		//	let node = SCNNode(geometry: box)
		//	node.position = SCNVector3(CGFloat(minX+(maxX-minX)/2), 0, CGFloat(minY+(maxY-minY)/2))
		//	node.eulerAngles = SCNVector3(x: .pi/2, y: 0, z: 0)
		//	node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
		//	treeKlz.node.addChildNode(node)

		stream.currentOffset += 3 * 4

		let numFaces: UInt32 = try stream.read()
		stream.currentOffset += 4
		let numXTOBBs: UInt32 = try stream.read()
		stream.currentOffset += 4
		let numAABBs: UInt32 = try stream.read()
		stream.currentOffset += 4
		let numSpheres: UInt32 = try stream.read()
		stream.currentOffset += 4
		let numOBBs: UInt32 = try stream.read()
		stream.currentOffset += 4
		let numCylinders: UInt32 = try stream.read()
		stream.currentOffset += 4

		stream.currentOffset += 2 * 4

		// Collision Grid Cell Boundaries

		for _ in 0 ... width {
			let _: Float = try stream.read() // x
		}

		for _ in 0 ... length {
			let _: Float = try stream.read() // y
		}

		// Collision Data

		stream.currentOffset += 4

		var nodesVertices: [UInt32: [SCNVector3]] = [:]
		print("=== numFaces:", numFaces)

		for _ in 0 ..< numFaces {
			try autoreleasepool {
				let face = try Triangle(stream: stream)
				if let (node, vertices) = face.getVertices(treeKlz: self) {
					if nodesVertices[node] == nil {
						nodesVertices[node] = vertices
					} else {
						nodesVertices[node]!.append(contentsOf: vertices)
					}
				}
			}
		}

		print("=== Loaded Scene Collision Face Vertices")

		let facesNode = SCNNode()
		for (linkId, vertices) in nodesVertices {
			autoreleasepool {
				guard let _node = getNode(linkId: linkId) else { return }

				let node = SCNNode()
				let verticesSource = SCNGeometrySource(vertices: vertices)
				var indices: [Int32] = []
				for i in 0 ..< Int32(vertices.count) {
					indices.append(i)
				}
				let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
				let geometry = SCNGeometry(sources: [verticesSource], elements: [element])
//				geometry.firstMaterial = SCNMaterial()
//				geometry.firstMaterial?.isDoubleSided = true
//				geometry.firstMaterial?.diffuse.contents = SKColor.random()
				node.transform = _node.worldTransform
				//node.geometry = geometry
				node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: geometry, options: [
					.type: SCNPhysicsShape.ShapeType.concavePolyhedron.rawValue
				]))
				facesNode.addChildNode(node)
			}
		}
		node.addChildNode(facesNode)

		print("=== Loaded Scene Collision Faces")

		for _ in 0 ..< numAABBs {
			try autoreleasepool {
				let box = try AABB(stream: stream)
				node.addChildNode(box.getNode(treeKlz: self))
			}
		}

		for _ in 0 ..< numXTOBBs {
			try autoreleasepool {
				let xtobb = try XTOBB(stream: stream)
				node.addChildNode(xtobb.getNode(treeKlz: self))
			}
		}

		for _ in 0 ..< numCylinders {
			try autoreleasepool {
				let cylinder = try Cylinder(stream: stream)
				node.addChildNode(cylinder.getNode(treeKlz: self))
			}
		}

		for _ in 0 ..< numOBBs {
			try autoreleasepool {
				let obb = try OBB(stream: stream)
				node.addChildNode(obb.getNode(treeKlz: self))
			}
		}

		for _ in 0 ..< numSpheres {
			try autoreleasepool {
				let sphere = try Sphere(stream: stream)
				node.addChildNode(sphere.getNode(treeKlz: self))
			}
		}

		// Collision Grid
		//
		// The primitives defined above are referenced by those cells of the grid that are intersected
		// by the corresponding primitive.
		//
		// There're restrictions on the order in which references may appear in each cell:
		//   - References to primitives (boxes, spheres, ...) need to be stored before references to triangles
		//   - Triangle references need to be sorted according to worldspace x of first indexed vertex
		//     note that first indexed vertex is always the one with smallest worldspace x of the triangle,
		//     see face col data description above
		//
		// Failing to obey these rules causes certain collision data to be ignored

		stream.currentOffset += 4

		/*for _ in 0 ..< length * width {
		let _ = try Cell(stream: stream)
		}*/

		//print("offset:", stream.currentOffset)

		stream.close()
	}

}
