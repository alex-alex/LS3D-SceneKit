//
//  ModelMesh.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

struct SingleMesh {
	let boneIds: [Int]
	let transforms: [SCNMatrix4]
	let boneWeights: SCNGeometrySource
	let boneIndices: SCNGeometrySource
}

func readMesh(stream: InputStream, node: SCNNode, numLODs: Int) throws -> [SingleMesh] {
//	print("readMesh", node.parent?.name)

	var meshes: [SingleMesh] = []
	for lod in 0 ..< numLODs {

		guard let vertexSource = node.geometry?.sources(for: .vertex).first else { fatalError() }

//		let stride = vertexSource.dataStride
//		let offset = vertexSource.dataOffset
//		let componentsPerVector = vertexSource.componentsPerVector
//		let bytesPerVector = componentsPerVector * vertexSource.bytesPerComponent
//		let vertexData = vertexSource.data as NSData

//		let vectors = [SCNVector3](repeating: SCNVector3Zero, count: vertexSource.vectorCount)
//		let vertices = vectors.enumerated().map { (index: Int, element: SCNVector3) -> SCNVector3 in
//			var vectorData = [SCNFloat](repeating: 0, count: componentsPerVector)
//			let loc = index * stride + offset
//			let byteRange = NSMakeRange(index * stride + offset, bytesPerVector)
//			vertexData.getBytes(&vectorData, range: byteRange)
//			return SCNVector3Make(vectorData[0], vectorData[1], vectorData[2])
//		}

//		if node.parent?.name == "TommyHAT" {
//			print("vertices:", vertices.count)
//		}

		let numBones: UInt8 = try stream.read()
		let _: UInt32 = try stream.read() // y

		let _ = try SCNVector3(stream: stream) // min
		let _ = try SCNVector3(stream: stream) // max

//		print("minmax:", minX, minY, minZ, maxX, maxY, maxZ)

//		let filtered = vertices.filter {
//			$0.x > SCNFloat(minX) && $0.x < SCNFloat(maxX) &&
//			$0.y > SCNFloat(minY) && $0.y < SCNFloat(maxY) &&
//			$0.z > SCNFloat(minZ) && $0.z < SCNFloat(maxZ)
//		}

		var boneIds: [Int] = []
		var transforms: [SCNMatrix4] = []

		var boneWeights: [Float] = []
		var boneIndices: [UInt8] = []

		for bone in 0 ..< numBones {
			try transforms.append(SCNMatrix4(stream: stream))

			let x: UInt32 = try stream.read()
			if lod == 0 {
				//				print("X:", x)
			}

			let additionalValuesCount: UInt32 = try stream.read()
			let boneId: UInt32 = try stream.read()
			boneIds.append(Int(boneId))

			let _ = try SCNVector3(stream: stream) // bMin
			let _ = try SCNVector3(stream: stream) // bMax

//			let filtered = vertices.filter {
//				$0.x > SCNFloat(bMinX) && $0.x < SCNFloat(bMaxX) &&
//				$0.y > SCNFloat(bMinY) && $0.y < SCNFloat(bMaxY) &&
//				$0.z > SCNFloat(bMinZ) && $0.z < SCNFloat(bMaxZ)
//			}
//			print("bone minmax:", bMinX, bMinY, bMinZ, bMaxX, bMaxY, bMaxZ)
//			print("filtered:", filtered.count)

//			boneWeights += Array(repeating: 0, count: Int(x))

			var data: [Float] = []
			for _ in 0 ..< additionalValuesCount {
				try data.append(stream.read())
			}

			boneWeights += Array(repeating: 1, count: Int(x + additionalValuesCount))
			boneIndices += Array(repeating: bone, count: Int(x + additionalValuesCount))
		}

		let remaining = vertexSource.vectorCount - boneIndices.count
		if lod == 0 {
//			print("remaining:", remaining)
		}

		boneWeights += Array(repeating: 1, count: Swift.max(remaining, 0))
		boneIndices += Array(repeating: 0, count: Swift.max(remaining, 0))

		let boneWeightsData = Data(bytes: boneWeights, count: boneWeights.count * MemoryLayout<Float>.size)
		let boneWeightsSource = SCNGeometrySource(
			data: boneWeightsData,
			semantic: .boneWeights,
			vectorCount: boneWeights.count,
			usesFloatComponents: true,
			componentsPerVector: 1,
			bytesPerComponent: MemoryLayout<Float>.size,
			dataOffset: 0,
			dataStride: MemoryLayout<Float>.size
		)

		let boneIndicesData = Data(bytes: boneIndices, count: boneIndices.count * MemoryLayout<UInt8>.size)
		let boneIndicesSource = SCNGeometrySource(
			data: boneIndicesData,
			semantic: .boneIndices,
			vectorCount: boneIndices.count,
			usesFloatComponents: false,
			componentsPerVector: 1,
			bytesPerComponent: MemoryLayout<UInt8>.size,
			dataOffset: 0,
			dataStride: MemoryLayout<UInt8>.size
		)

		let mesh = SingleMesh(
			boneIds: boneIds,
			transforms: transforms,
			boneWeights: boneWeightsSource,
			boneIndices: boneIndicesSource
		)
		meshes.append(mesh)
	}
	return meshes
}
