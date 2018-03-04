//
//  SceneCache.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/14/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

final class SceneCache {
	
	enum Error: Swift.Error {
		case file
	}
	
	let node = SCNNode()
	
	init?(name: String) throws {
		let url = mainDirectory.appendingPathComponent(name + "/cache.bin")
		
		guard (try? url.checkResourceIsReachable()) == true else { return nil }
		
		guard let stream = InputStream(url: url) else { throw Error.file }
		stream.open()
		
		var modelCache: [String: SCNNode] = [:]
		
		let header: Int16 = try stream.read()
		guard header == 0x01f4 else { throw Error.file }
		
		let _fileSize: Int32 = try stream.read()
		let fileSize = Int(_fileSize)
		
		let _: Int32 = try stream.read()
		
		while stream.currentOffset < fileSize {
			
			let baseNode = SCNNode()
			
			let startOffset = stream.currentOffset
			
			let baseSgn: UInt16 = try stream.read()
			guard baseSgn == 0x03e8 else { throw Error.file }
			
			let _baseSize: UInt32 = try stream.read()
			let baseSize = Int(_baseSize)
			
			let baseNameSize: UInt32 = try stream.read()
			baseNode.name = try stream.read(maxLength: Int(baseNameSize))
			
			stream.currentOffset += 0x4c
			
			while stream.currentOffset < (startOffset + baseSize) {
				
				let objNode = SCNNode()
				
				let objSgn: UInt16 = try stream.read()
				guard objSgn == 0x07d0 else { throw Error.file }
				
				let _: UInt32 = try stream.read() // _objSize
				//let objSize = Int(_objSize)
				
				let objNameSize: UInt32 = try stream.read()
				var objName: String = try stream.read(maxLength: Int(objNameSize))
				objName = objName.lowercased().replacingOccurrences(of: ".i3d", with: "")
				
				if let model = modelCache[objName] {
					objNode.addChildNode(model.clone())
				} else {
					let modelNode = try loadModel(named: "models/" + objName)
					objNode.addChildNode(modelNode)
					modelCache[objName] = modelNode
				}
				
				let positionX: Float = try stream.read()
				let positionY: Float = try stream.read()
				let positionZ: Float = try stream.read()
				objNode.position = SCNVector3(x: SCNFloat(positionX), y: SCNFloat(positionY), z: SCNFloat(positionZ))
				
				let rotationW: Float = try stream.read()
				let rotationX: Float = try stream.read()
				let rotationY: Float = try stream.read()
				let rotationZ: Float = try stream.read()
				objNode.orientation = SCNQuaternion(x: SCNFloat(rotationX), y: SCNFloat(rotationY), z: SCNFloat(rotationZ), w: -SCNFloat(rotationW))
				
				let scaleX: Float = try stream.read()
				let scaleY: Float = try stream.read()
				let scaleZ: Float = try stream.read()
				objNode.scale = SCNVector3(x: SCNFloat(scaleX), y: SCNFloat(scaleY), z: SCNFloat(scaleZ))
				
				stream.currentOffset += 16
				
				baseNode.addChildNode(objNode)
				
			}
			
			node.addChildNode(baseNode)
		}
		
		stream.close()
	}
	
}
