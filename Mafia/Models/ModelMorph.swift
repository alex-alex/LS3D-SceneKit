//
//  ModelMorph.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

func readMorph(stream: InputStream, node: SCNNode, id: Int) throws {
	let numTargets: UInt8 = try stream.read()
	let numChannels: UInt8 = try stream.read()
	let _: UInt8 = try stream.read()

	guard numTargets > 0 else { return }

	let morpher = SCNMorpher()

	for _ in 0 ..< numChannels {
		let numVerts: UInt16 = try stream.read()

		var vertices: [SCNVector3] = []
		var normals: [SCNVector3] = []
		var vertIndices: [[CInt]] = []

		if numVerts > 0 {
			for _ in 0 ..< numVerts {
				for _ in 0 ..< numTargets {
					let pointPosition = try SCNVector3(stream: stream)
					vertices.append(pointPosition)

					let normal = try SCNVector3(stream: stream)
					normals.append(normal)
				}
			}

			let unknown: UInt8 = try stream.read()

			if unknown != 0 {
				var _vertIndices: [CInt] = []
				for _ in 0 ..< numVerts {
					let vertIndice: UInt16 = try stream.read()
					_vertIndices.append(CInt(vertIndice))
				}
				vertIndices.append(_vertIndices)
			}
		}

		let geometrySources = [
			SCNGeometrySource(vertices: vertices),
			SCNGeometrySource(normals: normals)
		]

		let geometryElements = vertIndices.map({ SCNGeometryElement(indices: $0, primitiveType: .triangles) })

		let geometry = SCNGeometry(sources: geometrySources, elements: geometryElements)
//		_geometry.materials = meshMaterials
		morpher.targets.append(geometry)
	}

	for _ in 0 ..< 10 {
		let _: Float = try stream.read()
	}

	node.morpher = morpher
}
