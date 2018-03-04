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

	//var volume: Volume
	var vertices: [VertexLink] = []
	//var plane: Plane

	init(stream: InputStream) throws {
		//volume = try Volume(stream: stream, hasLink: false)
		stream.currentOffset += 4

		for _ in 0 ..< 3 {
			try vertices.append(VertexLink(stream: stream))
		}

		//plane = try Plane(stream: stream)
		stream.currentOffset += 16
	}

	func getVertices(treeKlz: Collisions) -> (UInt32, [SCNVector3])? {
		var newVertices: [SCNVector3] = []
		for vertex in vertices {
			guard let vertexNode = treeKlz.getNode(linkId: UInt32(vertex.linkIndex)),
				let nodeGeometry = vertexNode.geometry,
				let vertexSource = nodeGeometry.sources(for: .vertex).first,
				vertex.vertexBufferIndex < vertexSource.vectorCount else { continue }

			let nsData = vertexSource.data as NSData
			let vertexOffset = vertexSource.dataOffset + Int(vertex.vertexBufferIndex) * vertexSource.dataStride

			var x: Float = 0
			var y: Float = 0
			var z: Float = 0

			nsData.getBytes(&x, range: NSRange(location: vertexOffset, length: 4))
			nsData.getBytes(&y, range: NSRange(location: vertexOffset+4, length: 4))
			nsData.getBytes(&z, range: NSRange(location: vertexOffset+8, length: 4))

			newVertices.append(SCNVector3(x, y, z))
		}

		if newVertices.count == 3 {
			return (UInt32(vertices[0].linkIndex), newVertices)
		}

		return nil
	}
}
