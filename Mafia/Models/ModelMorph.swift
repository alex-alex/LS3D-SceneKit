//
//  ModelMorph.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

extension ModelLoadParser {

func readMorph(stream: InputStream, node: SCNNode, id: Int) throws {
	let frameCount: UInt8 = try stream.read()
	guard frameCount > 0 else { return }

	let lodCount: UInt8 = try stream.read()
	let _: UInt8 = try stream.read()

	guard let baseGeometry = node.geometry,
		  let baseVertices = baseGeometry.vectors(for: .vertex) else {
		try skipMorphPayload(stream: stream, frameCount: Int(frameCount), lodCount: Int(lodCount))
		return
	}
	let baseNormals = baseGeometry.vectors(for: .normal)
	let baseTextureCoordinates = baseGeometry.textureCoordinates
	let morpher = SCNMorpher()
	var morphFrameVertices = [[SCNVector3]]()
	var morphFrameNormals = [[SCNVector3]]()
	var morphVertexLinks = [Int]()

	for lod in 0 ..< lodCount {
		let vertexCount: UInt16 = try stream.read()
		var frameVertices = Array(
			repeating: [SCNVector3](),
			count: Int(frameCount)
		)
		var frameNormals = Array(
			repeating: [SCNVector3](),
			count: Int(frameCount)
		)

		for _ in 0 ..< vertexCount {
			for frame in 0 ..< Int(frameCount) {
				let pointPosition = try SCNVector3(stream: stream)
				let normal = try SCNVector3(stream: stream)
				if lod == 0 {
					frameNormals[frame].append(normal)
					frameVertices[frame].append(pointPosition)
				}
			}
		}

		if frameCount > 0, vertexCount > 0 {
			let _: UInt8 = try stream.read()
		}

		var vertexLinks: [Int] = []
		for _ in 0 ..< vertexCount {
			let vertexLink: UInt16 = try stream.read()
			if lod == 0 {
				vertexLinks.append(Int(vertexLink))
			}
		}

		guard lod == 0 else { continue }
		morphFrameVertices = frameVertices
		morphFrameNormals = frameNormals
		morphVertexLinks = vertexLinks
	}

	for _ in 0 ..< 10 {
		let _: Float = try stream.read()
	}

	for frame in 0 ..< Int(frameCount) {
		var vertices = baseVertices
		var normals = baseNormals ?? []
		for (index, vertexLink) in morphVertexLinks.enumerated() where vertexLink < vertices.count {
			vertices[vertexLink] = morphFrameVertices[frame][index]
			if !normals.isEmpty, vertexLink < normals.count {
				normals[vertexLink] = morphFrameNormals[frame][index]
			}
		}

		var geometrySources = [SCNGeometrySource(vertices: vertices)]
		if !normals.isEmpty {
			geometrySources.append(SCNGeometrySource(normals: normals))
		}
		if let baseTextureCoordinates = baseTextureCoordinates {
			geometrySources.append(baseTextureCoordinates)
		}
		let geometry = SCNGeometry(sources: geometrySources, elements: baseGeometry.allGeometryElements)
		geometry.materials = baseGeometry.materials
		morpher.targets.append(geometry)
	}

	for index in 0 ..< morpher.targets.count {
		morpher.setWeight(0, forTargetAt: index)
	}
	node.morpher = morpher
}

}

private func skipMorphPayload(stream: InputStream, frameCount: Int, lodCount: Int) throws {
	for _ in 0 ..< lodCount {
		let vertexCount: UInt16 = try stream.read()
		stream.currentOffset += frameCount * Int(vertexCount) * 24
		if frameCount > 0, vertexCount > 0 {
			stream.currentOffset += 1
		}
		stream.currentOffset += Int(vertexCount) * 2
	}

	stream.currentOffset += 40
}

private extension SCNGeometry {
	var allGeometryElements: [SCNGeometryElement] {
		return (0 ..< elementCount).map { element(at: $0) }
	}

	func vectors(for semantic: SCNGeometrySource.Semantic) -> [SCNVector3]? {
		guard let source = sources(for: semantic).first,
			  source.componentsPerVector >= 3,
			  source.usesFloatComponents,
			  source.bytesPerComponent == MemoryLayout<Float>.size else {
			return nil
		}

		let data = source.data
		return (0 ..< source.vectorCount).map { index in
			let offset = source.dataOffset + index * source.dataStride
			return SCNVector3(
				x: SCNFloat(data.float32(at: offset)),
				y: SCNFloat(data.float32(at: offset + source.bytesPerComponent)),
				z: SCNFloat(data.float32(at: offset + source.bytesPerComponent * 2))
			)
		}
	}

	var textureCoordinates: SCNGeometrySource? {
		return sources(for: .texcoord).first
	}
}

private extension Data {
	func float32(at offset: Int) -> Float {
		let value = UInt32(self[offset]) |
			UInt32(self[offset + 1]) << 8 |
			UInt32(self[offset + 2]) << 16 |
			UInt32(self[offset + 3]) << 24
		return Float(bitPattern: value)
	}
}
