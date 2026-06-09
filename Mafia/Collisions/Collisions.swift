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
			stream.currentOffset += Int(4 - padding)
		}
	}
}

private final class SceneNodeLookup {
	private var nodesByName: [String: [SCNNode]] = [:]

	init(rootNode: SCNNode) {
		index(rootNode)
	}

	func firstNode(named name: String) -> SCNNode? {
		return nodesByName[name]?.first
	}

	func firstNode(named name: String, in rootNode: SCNNode) -> SCNNode? {
		return nodesByName[name]?.first { $0.isDescendantNode(of: rootNode) }
	}

	func directChild(named name: String, in node: SCNNode) -> SCNNode? {
		return node.childNodes.first { $0.name == name }
	}

	private func index(_ node: SCNNode) {
		if let name = node.name {
			nodesByName[name, default: []].append(node)
		}

		for child in node.childNodes {
			index(child)
		}
	}
}

private struct VehicleRaycastGroundPatch {
	let center: SCNVector3
	let tangent: SCNVector3
	let normal: SCNVector3
	let bitangent: SCNVector3
	let width: SCNFloat
	let length: SCNFloat
}

final class Collisions {

	enum Error: Swift.Error {
		case file
	}

	let node = SCNNode()
	let rootNode: SCNNode
	private let nodeLookup: SceneNodeLookup
	private let vehicleRaycastGroundThickness: SCNFloat = 0.01
	private let vehicleRaycastGroundClearance: SCNFloat = 0.01
	private let vehicleRaycastGroundMargin: SCNFloat = 0.05
	private let vehicleWallProxyMinHeight: SCNFloat = 0.45
	private let vehicleWallProxyThickness: SCNFloat = 0.08
	private let vehicleWallProxyMargin: SCNFloat = 0.08
	//var names: [(Int, String)] = []
	var nodes: [Int: SCNNode] = [:]

	init(name: String, scene: SCNScene) throws {
		self.rootNode = scene.rootNode
		self.nodeLookup = SceneNodeLookup(rootNode: scene.rootNode)

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
			guard let parent = nodeLookup.firstNode(named: String(comps[0])) else { return nil }
			return nodeLookup.directChild(named: String(comps[1]), in: parent)
		} else {
			var node: SCNNode?
			if type == 1 {
				node = rootNode.collisionLinkRoot(for: type)
					.flatMap { nodeLookup.directChild(named: String(comps[0]), in: $0) }
			} else if type == 2 {
				node = rootNode.collisionLinkRoot(for: type)
					.flatMap { nodeLookup.directChild(named: String(comps[0]), in: $0) }
			}

			if node == nil {
//				print("recursive")
				node = nodeLookup.firstNode(named: String(comps[0]))
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
		var vehicleRaycastGroundPatches: [VehicleRaycastGroundPatch] = []
		var vehicleWallProxyPatches: [VehicleRaycastGroundPatch] = []
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
				if let vertices = face.getWorldVertices(treeKlz: self),
				   let patch = vehicleRaycastGroundPatch(for: vertices) {
					vehicleRaycastGroundPatches.append(patch)
				}
				if let vertices = face.getWorldVertices(treeKlz: self),
				   let patch = vehicleWallProxyPatch(for: vertices) {
					vehicleWallProxyPatches.append(patch)
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
				node.geometry = geometry
				node.configureAsCollisionWireframe()
				node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: geometry, options: [
					.type: SCNPhysicsShape.ShapeType.concavePolyhedron
				]))
				node.physicsBody?.configureAsWorldCollider()
				facesNode.addChildNode(node)
			}
		}
		node.addChildNode(facesNode)
		addVehicleRaycastGround(from: vehicleRaycastGroundPatches)
		addVehicleWallProxy(from: vehicleWallProxyPatches)

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

	private func vehicleRaycastGroundPatch(for vertices: [SCNVector3]) -> VehicleRaycastGroundPatch? {
		guard vertices.count == 3 else { return nil }

		let firstEdge = vertices[1] - vertices[0]
		let secondEdge = vertices[2] - vertices[0]
		var normal = firstEdge.cross(secondEdge).normalized
		guard abs(normal.y) > 0.35 else { return nil }
		if normal.y < 0 {
			normal = SCNVector3(x: -normal.x, y: -normal.y, z: -normal.z)
		}

		let tangent = firstEdge.normalized
		guard tangent.length > 0.0001 else { return nil }

		let bitangent = normal.cross(tangent).normalized
		let centroid = SCNVector3(
			x: (vertices[0].x + vertices[1].x + vertices[2].x) / 3,
			y: (vertices[0].y + vertices[1].y + vertices[2].y) / 3,
			z: (vertices[0].z + vertices[1].z + vertices[2].z) / 3
		)

		let projected = vertices.map { vertex -> (u: SCNFloat, v: SCNFloat) in
			let offset = vertex - centroid
			return (dot(offset, tangent), dot(offset, bitangent))
		}
		guard let minU = projected.map({ $0.u }).min(),
			  let maxU = projected.map({ $0.u }).max(),
			  let minV = projected.map({ $0.v }).min(),
			  let maxV = projected.map({ $0.v }).max() else { return nil }

		let center = centroid +
			tangent * ((minU + maxU) / 2) +
			bitangent * ((minV + maxV) / 2) -
			normal * (vehicleRaycastGroundThickness / 2 + vehicleRaycastGroundClearance)

		return VehicleRaycastGroundPatch(
			center: center,
			tangent: tangent,
			normal: normal,
			bitangent: bitangent,
			width: max(maxU - minU + vehicleRaycastGroundMargin, vehicleRaycastGroundMargin),
			length: max(maxV - minV + vehicleRaycastGroundMargin, vehicleRaycastGroundMargin)
		)
	}

	private func vehicleWallProxyPatch(for vertices: [SCNVector3]) -> VehicleRaycastGroundPatch? {
		guard vertices.count == 3 else { return nil }

		let firstEdge = vertices[1] - vertices[0]
		let secondEdge = vertices[2] - vertices[0]
		let normal = firstEdge.cross(secondEdge).normalized
		guard abs(normal.y) <= 0.35 else { return nil }
		let minY = vertices.map { $0.y }.min() ?? 0
		let maxY = vertices.map { $0.y }.max() ?? 0
		guard maxY - minY >= vehicleWallProxyMinHeight else { return nil }

		let tangent = firstEdge.normalized
		guard tangent.length > 0.0001 else { return nil }

		let bitangent = normal.cross(tangent).normalized
		let centroid = SCNVector3(
			x: (vertices[0].x + vertices[1].x + vertices[2].x) / 3,
			y: (vertices[0].y + vertices[1].y + vertices[2].y) / 3,
			z: (vertices[0].z + vertices[1].z + vertices[2].z) / 3
		)

		let projected = vertices.map { vertex -> (u: SCNFloat, v: SCNFloat) in
			let offset = vertex - centroid
			return (dot(offset, tangent), dot(offset, bitangent))
		}
		guard let minU = projected.map({ $0.u }).min(),
			  let maxU = projected.map({ $0.u }).max(),
			  let minV = projected.map({ $0.v }).min(),
			  let maxV = projected.map({ $0.v }).max() else { return nil }

		let center = centroid +
			tangent * ((minU + maxU) / 2) +
			bitangent * ((minV + maxV) / 2)

		return VehicleRaycastGroundPatch(
			center: center,
			tangent: tangent,
			normal: normal,
			bitangent: bitangent,
			width: max(maxU - minU + vehicleWallProxyMargin, vehicleWallProxyMargin),
			length: max(maxV - minV + vehicleWallProxyMargin, vehicleWallProxyMargin)
		)
	}

	private func addVehicleRaycastGround(from patches: [VehicleRaycastGroundPatch]) {
		guard !patches.isEmpty else { return }

		let groundNode = SCNNode()
		groundNode.name = "__vehicle_raycast_ground__"

		var shapes: [SCNPhysicsShape] = []
		var transforms: [NSValue] = []
		shapes.reserveCapacity(patches.count)
		transforms.reserveCapacity(patches.count)

		for patch in patches {
			let box = SCNBox(
				width: CGFloat(patch.width),
				height: CGFloat(vehicleRaycastGroundThickness),
				length: CGFloat(patch.length),
				chamferRadius: 0
			)
			shapes.append(SCNPhysicsShape(geometry: box, options: nil))
			let transform = SCNMatrix4(
				m11: patch.tangent.x, m12: patch.tangent.y, m13: patch.tangent.z, m14: 0,
				m21: patch.normal.x, m22: patch.normal.y, m23: patch.normal.z, m24: 0,
				m31: patch.bitangent.x, m32: patch.bitangent.y, m33: patch.bitangent.z, m34: 0,
				m41: patch.center.x, m42: patch.center.y, m43: patch.center.z, m44: 1
			)
			transforms.append(NSValue(scnMatrix4: transform))

			let debugNode = SCNNode(geometry: box)
			debugNode.transform = transform
			debugNode.configureAsCollisionWireframe()
			groundNode.addChildNode(debugNode)
		}

		groundNode.physicsBody = SCNPhysicsBody(
			type: .static,
			shape: SCNPhysicsShape(shapes: shapes, transforms: transforms)
		)
		groundNode.physicsBody?.configureAsVehicleRaycastGroundCollider()
		groundNode.physicsBody?.friction = 0
		groundNode.physicsBody?.restitution = 0
		groundNode.physicsBody?.rollingFriction = 0
		node.addChildNode(groundNode)

		print("=== Loaded Vehicle Raycast Ground Patches:", patches.count)
	}

	private func addVehicleWallProxy(from patches: [VehicleRaycastGroundPatch]) {
		guard !patches.isEmpty else { return }

		let wallNode = SCNNode()
		wallNode.name = "__vehicle_wall_proxy__"

		var shapes: [SCNPhysicsShape] = []
		var transforms: [NSValue] = []
		shapes.reserveCapacity(patches.count)
		transforms.reserveCapacity(patches.count)

		for patch in patches {
			let box = SCNBox(
				width: CGFloat(patch.width),
				height: CGFloat(vehicleWallProxyThickness),
				length: CGFloat(patch.length),
				chamferRadius: 0
			)
			shapes.append(SCNPhysicsShape(geometry: box, options: nil))
			transforms.append(NSValue(scnMatrix4: SCNMatrix4(
				m11: patch.tangent.x, m12: patch.tangent.y, m13: patch.tangent.z, m14: 0,
				m21: patch.normal.x, m22: patch.normal.y, m23: patch.normal.z, m24: 0,
				m31: patch.bitangent.x, m32: patch.bitangent.y, m33: patch.bitangent.z, m34: 0,
				m41: patch.center.x, m42: patch.center.y, m43: patch.center.z, m44: 1
			)))
		}

		wallNode.physicsBody = SCNPhysicsBody(
			type: .static,
			shape: SCNPhysicsShape(shapes: shapes, transforms: transforms)
		)
		wallNode.physicsBody?.configureAsVehicleRaycastGroundCollider()
		wallNode.physicsBody?.friction = 0
		wallNode.physicsBody?.restitution = 0
		wallNode.physicsBody?.rollingFriction = 0
		node.addChildNode(wallNode)

		print("=== Loaded Vehicle Wall Proxy Patches:", patches.count)
	}

	private func dot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNFloat {
		return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
	}

}
