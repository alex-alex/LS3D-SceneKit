//
//  CollisionTriangle.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

struct Plane {
	var n: SCNVector3 // swiftlint:disable:this identifier_name
	var d: Float // swiftlint:disable:this identifier_name
	init(stream: InputStream) throws {
		n = try SCNVector3(stream: stream)
		d = try stream.read()
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

	func getVertices(treeKlz: Collisions) -> (UInt32, [SCNVector3])? {
		var localVertices: [(node: SCNNode, position: SCNVector3)] = []
		for vertex in vertices {
			guard let localVertex = localVertex(for: vertex, treeKlz: treeKlz) else { continue }
			localVertices.append(localVertex)
		}

		guard localVertices.count == 3 else { return nil }

		let worldVertices = localVertices.map { $0.node.convertPosition($0.position, to: nil) }
		let worldPlaneNormal = localVertices[0].node.convertVector(plane.n, to: nil).normalized
		if dot(triangleNormal(for: worldVertices).normalized, worldPlaneNormal) < 0 {
			localVertices.swapAt(1, 2)
		}

		return (UInt32(vertices[0].linkIndex), localVertices.map { $0.position })
	}

	func getWorldVertices(treeKlz: Collisions) -> [SCNVector3]? {
		return getWorldVerticesWithLinkIds(treeKlz: treeKlz)?.vertices
	}

	func getWorldVerticesWithLinkIds(treeKlz: Collisions) -> (vertices: [SCNVector3], linkIds: [UInt16])? {
		var worldVertices: [SCNVector3] = []
		var linkIds: [UInt16] = []
		for vertex in vertices {
			guard let localVertex = localVertex(for: vertex, treeKlz: treeKlz) else { continue }
			worldVertices.append(localVertex.node.convertPosition(localVertex.position, to: nil))
			linkIds.append(vertex.linkIndex)
		}

		return worldVertices.count == 3 ? (worldVertices, linkIds) : nil
	}

	private func localVertex(for vertex: VertexLink, treeKlz: Collisions) -> (node: SCNNode, position: SCNVector3)? {
		guard let vertexNode = treeKlz.getNode(linkId: UInt32(vertex.linkIndex)),
			let nodeGeometry = vertexNode.geometry,
			let vertexSource = nodeGeometry.sources(for: .vertex).first,
			vertex.vertexBufferIndex < vertexSource.vectorCount else { return nil }

		let nsData = vertexSource.data as NSData
		let vertexOffset = vertexSource.dataOffset + Int(vertex.vertexBufferIndex) * vertexSource.dataStride

		var x: Float = 0
		var y: Float = 0
		var z: Float = 0

		nsData.getBytes(&x, range: NSRange(location: vertexOffset, length: 4))
		nsData.getBytes(&y, range: NSRange(location: vertexOffset+4, length: 4))
		nsData.getBytes(&z, range: NSRange(location: vertexOffset+8, length: 4))

		return (vertexNode, SCNVector3(x, y, z))
	}

	private func triangleNormal(for vertices: [SCNVector3]) -> SCNVector3 {
		let firstEdge = vertices[1] - vertices[0]
		let secondEdge = vertices[2] - vertices[0]
		return firstEdge.cross(secondEdge)
	}

	private func dot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNFloat {
		return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
	}
}
