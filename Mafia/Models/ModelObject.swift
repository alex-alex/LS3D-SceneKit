//
//  ModelObject.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

@discardableResult
func readObject(stream: InputStream, node: SCNNode, id: Int) throws -> Int {

	let instanceId: UInt16 = try stream.read()
	guard instanceId == 0 else {
		let id = Int(instanceId - 1)
		if let geometry = geometries[id] {
			node.geometry = geometry
		}
		return 0
	}

	let numLODs: UInt8 = try stream.read()
	for lod in 0 ..< numLODs {
		let _: Float = try stream.read() // clippingRange

		let numVerts: UInt16 = try stream.read()

		var vertices: [SCNVector3] = []
		var normals: [SCNVector3] = []
		var textureCoordinates: [CGPoint] = []

		for _ in 0 ..< numVerts {
			let pointPosition = try SCNVector3(stream: stream)
			vertices.append(pointPosition)

			let normal = try SCNVector3(stream: stream)
			normals.append(normal)

			let texturePosition = try CGPoint(stream: stream)
			textureCoordinates.append(texturePosition)
		}

		var meshMaterials: [SCNMaterial] = []
		let _vertIndicesCount: UInt8 = try stream.read()
		let vertIndicesCount = Int(_vertIndicesCount)
		var vertIndices = [[CInt]](repeating: [], count: vertIndicesCount)

		for j in 0 ..< vertIndicesCount {
			let numFaces: UInt16 = try stream.read()
			for _ in 0 ..< numFaces * 3 {
				let vertIndice: UInt16 = try stream.read()
				vertIndices[j].append(CInt(vertIndice))
			}

			let _materialID: UInt16 = try stream.read()
			let materialID = Int(_materialID)

			if lod == 0 {
				let material: SCNMaterial
				if materialID > 0 {
					material = materials[materialID - 1]
				} else {
					material = SCNMaterial()
					material.transparency = 0
				}
				meshMaterials.append(material)
			}
		}

		if lod == 0 {
			let geometrySources = [
				SCNGeometrySource(vertices: vertices),
				SCNGeometrySource(normals: normals),
				SCNGeometrySource(textureCoordinates: textureCoordinates)
			]

			let geometryElements = vertIndices.map({ SCNGeometryElement(indices: $0, primitiveType: .triangles) })

			let _geometry = SCNGeometry(sources: geometrySources, elements: geometryElements)
			_geometry.materials = meshMaterials

//			_geometry.levelsOfDetail = []
			geometries[id] = _geometry
			node.geometry = _geometry
		} else {
//			let worldSpaceDistance = (10000 - CGFloat(clippingRange)) / 1000
//			print("worldSpaceDistance:", worldSpaceDistance)
//			let lod = SCNLevelOfDetail(geometry: _geometry, worldSpaceDistance: worldSpaceDistance)
//			_geometry.levelsOfDetail?.append(lod)
		}

	}

	return Int(numLODs)
}
