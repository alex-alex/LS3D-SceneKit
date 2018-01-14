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

enum VolumeType: UInt8 {
	case face			= 0
	case face1			= 1
	case face2			= 2
	case face3			= 3
	case face4			= 4
	case face5			= 5
	case face6			= 6
	case face7			= 7
	
	case XTOBB			= 0x80
	case AABB			= 0x81
	case sphere			= 0x82
	case OBB			= 0x83
	case cylinder		= 0x84
}

struct Plane {
	var n: SCNVector3
	var d: Float
	init(stream: InputStream) throws {
		n = try SCNVector3(stream: stream)
		d = try stream.read()
	}
}

struct Volume {
	var type: VolumeType
	var sortInfo: UInt8
	var flags: UInt8
	var mtlId: UInt8
	var linkId: UInt32?
	
	init(stream: InputStream, hasLink: Bool) throws {
		type = try VolumeType(forcedRawValue: stream.read())
		sortInfo = try stream.read()
		flags = try stream.read()
		mtlId = try stream.read()
		
		if hasLink {
			let _linkId: UInt32 = try stream.read()
			linkId = _linkId
		} else {
			linkId = nil
		}
	}
}

struct Triangle {
	struct VertexLink {
		var vertexBufferIndex: UInt16
		var linkIndex: UInt16
		init(stream: InputStream) throws {
			vertexBufferIndex = try stream.read()
			linkIndex = try stream.read()
		}
	}
	
	var volume: Volume
	var vertices: [VertexLink] = []
	var plane: Plane
	
	init(stream: InputStream) throws {
		volume = try Volume(stream: stream, hasLink: false)
		
		for _ in 0 ..< 3 {
			try vertices.append(VertexLink(stream: stream))
		}
		
		plane = try Plane(stream: stream)
	}
	
	func getVertices(treeKlz: Collisions) -> (SCNNode, [SCNVector3])? {
		var newVertices: [SCNVector3] = []
		for vertex in vertices {
			guard let vertexNode = treeKlz.getNode(linkId: UInt32(vertex.linkIndex)),
				  let nodeGeometry = vertexNode.geometry,
				  let vertexSource = nodeGeometry.getGeometrySources(for: .vertex).first,
				  vertex.vertexBufferIndex < vertexSource.vectorCount else { continue }
			
			let nsData = vertexSource.data as NSData
			let vertexOffset = vertexSource.dataOffset + Int(vertex.vertexBufferIndex) * vertexSource.dataStride
			
			var x: Float = 0
			var y: Float = 0
			var z: Float = 0
			
			nsData.getBytes(&x, range: NSMakeRange(vertexOffset, 4))
			nsData.getBytes(&y, range: NSMakeRange(vertexOffset+4, 4))
			nsData.getBytes(&z, range: NSMakeRange(vertexOffset+8, 4))
			
			newVertices.append(SCNVector3(x, y, z))
		}
		
		if newVertices.count == 3, let _node = treeKlz.getNode(linkId: UInt32(vertices[0].linkIndex)), _node.physicsBody == nil {
			return (_node, newVertices)
		}
		
		return nil
	}
}

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
		let box = SCNBox(width: CGFloat(max.x-min.x), height: CGFloat(max.y-min.y), length: CGFloat(max.z-min.z), chamferRadius: 0)
		box.firstMaterial = SCNMaterial()
		box.firstMaterial?.cullMode = .front
		box.firstMaterial?.diffuse.contents = SKColor.red
//		node.geometry = box
		node.position = SCNVector3(CGFloat(min.x+(max.x-min.x)/2), CGFloat(min.y+(max.y-min.y)/2), CGFloat(min.z+(max.z-min.z)/2))
		node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
		return node
	}
}

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
		
//		if volume.mtlId == 41 {
//			let shape = SCNPhysicsShape(node: _node, options: [:])
//			_node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
//		} else {
//			let convertedTransform = _node.convertTransform(transform, from: treeKlz.rootNode)
//			let shape = SCNPhysicsShape(shapes: [SCNPhysicsShape(geometry: box, options: nil)], transforms: [NSValue(scnMatrix4: transform)])
//			node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
			let shape = SCNPhysicsShape(node: _node, options: [
				SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron
			])
			_node.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
//		}
		
		return node
	}
}

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
		cylinder.firstMaterial = SCNMaterial()
		cylinder.firstMaterial?.cullMode = .front
		cylinder.firstMaterial?.diffuse.contents = SKColor.blue
//		node.geometry = cylinder
		node.position = SCNVector3(position.x, 0, position.y)
		node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: cylinder, options: nil))
		return node
	}
}

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
		let box = SCNBox(width: CGFloat(maxExtent.x-minExtent.x), height: CGFloat(maxExtent.y-minExtent.y), length: CGFloat(maxExtent.z-minExtent.z), chamferRadius: 0)
		box.firstMaterial = SCNMaterial()
		box.firstMaterial?.cullMode = .front
		box.firstMaterial?.diffuse.contents = SKColor.magenta
//		node.geometry = box
		node.transform = transform
		node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
		return node
	}
}

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
		sphere.firstMaterial = SCNMaterial()
		sphere.firstMaterial?.cullMode = .front
		sphere.firstMaterial?.diffuse.contents = SKColor.cyan
//		node.geometry = sphere
		node.position = position
		node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: sphere, options: nil))
		return node
	}
}

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
	var names: [(Int, String)] = []
	
	init(name: String, scene: SCNScene) throws {
		self.rootNode = scene.rootNode
		
		let url = mainDirectory.appendingPathComponent(name + "/tree.klz")
		
		guard let stream = InputStream(url: url) else { throw Error.file }
		stream.open()
		
		try process(stream: stream)
	}
	
	func getNode(linkId: UInt32) -> SCNNode? {
		let (_, name) = names[Int(linkId)]
		
		let comps = name.split(separator: ".")
		if comps.count > 1 {
			guard comps.count == 2 else { fatalError() }
			guard let parent = rootNode.childNode(withName: String(comps[0]), recursively: true) else { return nil }
			return parent.childNode(withName: String(comps[1]), recursively: false)
		} else {
			return rootNode.childNode(withName: name, recursively: true)
		}
	}
	
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
			
			names.append((Int(linkType), str))
		}
		
		// Collision Data Header
		
		stream.currentOffset = gridDataOffset
		
		let minX: Float = try stream.read()
		let minY: Float = try stream.read()
		let maxX: Float = try stream.read()
		let maxY: Float = try stream.read()
		let cellWidth: Float = try stream.read()
		let cellLength: Float = try stream.read()
		let width: UInt32 = try stream.read()
		let length: UInt32 = try stream.read()
		let unknown: Float = try stream.read()
		
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
			let x: Float = try stream.read()
		}
		
		for _ in 0 ... length {
			let y: Float = try stream.read()
		}
		
		// Collision Data
		
		stream.currentOffset += 4
		
		var nodesVertices: [SCNNode: [SCNVector3]] = [:]
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
		
		/*let faceCollisionsNode = SCNNode()
		let shape = SCNPhysicsShape(node: facesNode, options: [:])
		faceCollisionsNode.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
		treeKlz.node.addChildNode(faceCollisionsNode)*/
		
		let facesNode = SCNNode()
		for (_node, vertices) in nodesVertices {
			autoreleasepool {
				let node = SCNNode()
				let verticesSource = SCNGeometrySource(vertices: vertices)
				var indices: [Int32] = []
				for i in 0 ..< Int32(vertices.count) {
					indices.append(i)
				}
				let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
				let geometry = SCNGeometry(sources: [verticesSource], elements: [element])
				geometry.firstMaterial = SCNMaterial()
				geometry.firstMaterial?.isDoubleSided = true
				geometry.firstMaterial?.diffuse.contents = SKColor.random()
				node.transform = _node.worldTransform
				//node.geometry = geometry
				node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: geometry, options: [
					.type: SCNPhysicsShape.ShapeType.concavePolyhedron.rawValue
				]))
				facesNode.addChildNode(node)
			}
		}
		node.addChildNode(facesNode)
		
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
