//
//  Models.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/13/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import Foundation
import SpriteKit
import SceneKit

enum ModelError: Error {
	case file
	case geometry
}

enum FrameType: UInt8 {
	case visual			= 1
	case light			= 2
	case camera			= 3
	case sound			= 4
	case sector			= 5
	case dummy			= 6
	case target			= 7
	case user			= 8
	case model			= 9
	case joint			= 10
	case volume			= 11
	case occluder		= 12
	case scene			= 13
	case area			= 14
	case landscape		= 15
}

enum VisualType: UInt8 {
	case object			= 0
	case litObject		= 1
	case singleMesh		= 2
	case singleMorph	= 3
	case billboard		= 4
	case morph			= 5
	case lens			= 6
	case projector		= 7
	case mirror			= 8
	case emitor			= 9
	case shadow			= 10
	case landpath		= 11
}

struct MaterialFlags: OptionSet {
	let rawValue: UInt32

	static let reflectionTextureMix			= MaterialFlags(rawValue: 1 << 8)
	static let reflectionTextureMixMulti	= MaterialFlags(rawValue: 1 << 9)
	static let reflectionTextureMixAdd		= MaterialFlags(rawValue: 1 << 10)

	// Výpočet odlesku env textury podle osy
//	static let x							= MaterialFlags(rawValue: 1 << 12)
//	static let y							= MaterialFlags(rawValue: 1 << 13)
//	static let z							= MaterialFlags(rawValue: 1 << 14)

	static let addedEffect					= MaterialFlags(rawValue: 1 << 15)

	static let diffuseTexture				= MaterialFlags(rawValue: 1 << 18)
	static let reflectionTexture			= MaterialFlags(rawValue: 1 << 19)

	static let mipMapping					= MaterialFlags(rawValue: 1 << 23)
	static let imageAlpha					= MaterialFlags(rawValue: 1 << 24)
	static let opacityTextureAnimation		= MaterialFlags(rawValue: 1 << 25)
	static let diffuseTextureAnimation		= MaterialFlags(rawValue: 1 << 26)
	static let coloring						= MaterialFlags(rawValue: 1 << 27)
	static let doubleSided					= MaterialFlags(rawValue: 1 << 28)
	static let colorKey						= MaterialFlags(rawValue: 1 << 29)
	static let opacityTexture				= MaterialFlags(rawValue: 1 << 30)
	static let additiveBlend				= MaterialFlags(rawValue: 1 << 31)
}

//var imageCache: NSCache<NSString, UIImage> = NSCache()
var imageCache: [String: UIImage] = [:]
var materials: [SCNMaterial] = []
var geometries: [Int: SCNGeometry] = [:]

//enum GeometryResponse {
//	case geometry(SCNGeometry)
//	case reference(Int)
//
//	var geometry: SCNGeometry? {
//		switch self {
//		case .geometry(let geometry):
//			return geometry
//		case .reference(let id):
//			return geometries[id]
//		}
//	}
//}

func readMirror(stream: InputStream) throws {

	let _ = try SCNVector3(stream: stream) // min
	let _ = try SCNVector3(stream: stream) // max

	for _ in 0 ..< 4 {
		let _: Float = try stream.read()
	}

	var transformationMatrix: [Float] = []
	for _ in 0 ..< 16 {
		try transformationMatrix.append(stream.read())
	}

	let _: Float = try stream.read() // r
	let _: Float = try stream.read() // g
	let _: Float = try stream.read() // b

	let _: Float = try stream.read() // reflectionStrength

	let numVerts: UInt32 = try stream.read()
	let numFaces: UInt32 = try stream.read()

	var positionOfPoint: [SCNVector3] = []
	var vertIndices: [CInt] = []

	for _ in 0 ..< numVerts {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		positionOfPoint.append(SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z)))
	}

	for _ in 0 ..< numFaces * 3 {
		let vertIndice: UInt16 = try stream.read()
		vertIndices.append(CInt(vertIndice))
	}

}

func readSector(stream: InputStream) throws {
//	print("SECTOR")

	let _: (UInt32, UInt32) = try (stream.read(), stream.read()) // flags

	let numVerts: UInt32 = try stream.read()
	let numFaces: UInt32 = try stream.read()

	var positionOfPoint: [SCNVector3] = []
	var vertIndices: [CInt] = []

	for _ in 0 ..< numVerts {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		positionOfPoint.append(SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z)))
	}

	for _ in 0 ..< numFaces * 3 {
		let vertIndice: UInt16 = try stream.read()
		vertIndices.append(CInt(vertIndice))
	}

	let _ = try SCNVector3(stream: stream) // min
	let _ = try SCNVector3(stream: stream) // max

	let numPortals: UInt8 = try stream.read()

	for _ in 0 ..< numPortals {
		let numVerts_p: UInt8 = try stream.read()

		let _ = try SCNVector3(stream: stream) // plane_n

		let _: Float = try stream.read() // plane_d

		let _: UInt32 = try stream.read() // Flags_p

		let _: Float = try stream.read() // nearRange
		let _: Float = try stream.read() // farRange

		var positionOfPoint_p: [SCNVector3] = []
		for _ in 0 ..< numVerts_p {
			try positionOfPoint_p.append(SCNVector3(stream: stream))
		}
	}
}

func readDummy(stream: InputStream) throws -> SCNNode {
	let min = try SCNVector3(stream: stream)
	let max = try SCNVector3(stream: stream)

	let width = max.x - min.x
	let height = max.y - min.y
	let length = max.z - min.z

	let box = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(length), chamferRadius: 0)

	box.firstMaterial = SCNMaterial()
	box.firstMaterial?.diffuse.contents = SKColor.blue
	box.firstMaterial?.transparency = 0.2

	let node = SCNNode(geometry: box)
	node.name = "DUMMY"
	node.isHidden = true
	node.position = SCNVector3(
		x: SCNFloat(min.x + width / 2),
		y: SCNFloat(min.y + height / 2),
		z: SCNFloat(min.z + length / 2)
	)

	return node
}

func readTarget(stream: InputStream) throws {
//	print("TARGET")

	let _: UInt16 = try stream.read()

	let numLinks: UInt8 = try stream.read()

	var links: [UInt16] = []
	for _ in 0 ..< numLinks {
		try links.append(stream.read())
	}
}

func readJoint(stream: InputStream) throws -> (SCNMatrix4, Int) {
	let transformationMatrix = try SCNMatrix4(stream: stream)
	let id: UInt32 = try stream.read()
	return (transformationMatrix, Int(id))
}

@discardableResult
// swiftlint:disable:next function_body_length
func loadModel(named name: String, node: SCNNode = SCNNode()) throws -> SCNNode {

//	print("-- loadModel:", name)

	materials = []
	geometries = [:]

	let mainNode = node

	var url = mainDirectory.appendingPathComponent(name + ".4ds")

	if (try? url.checkResourceIsReachable()) != true {

		var comps = name.components(separatedBy: "/")
		if comps.count > 0 {
			comps[comps.count-1] = comps[comps.count-1].uppercased()
		}

		url = mainDirectory.appendingPathComponent(comps.joined(separator: "/").lowercased() + ".4ds")

		if (try? url.checkResourceIsReachable()) != true {
			print("!!! ERROR:", url.path)
			return node
		}

	}

	guard let stream = InputStream(url: url) else { throw ModelError.file }
	stream.open()

	let str: String = try stream.read(maxLength: 4)
	guard str == "4DS" else { throw ModelError.file }

	let ver: UInt16 = try stream.read()
	guard ver == 29 else { throw ModelError.file }

	let _: UInt64 = try stream.read()

	let materialsCount: UInt16 = try stream.read()
	for i in 0 ..< materialsCount {
		let flags = try MaterialFlags(rawValue: stream.read())

		let material = SCNMaterial()
		material.name = "material_\(i)"
		material.cullMode = .front

		if flags.contains(.doubleSided) {
			material.isDoubleSided = true
		}

		if flags.contains(.additiveBlend) {
			material.blendMode = .add
		}

		if flags.contains(.mipMapping) {
			material.diffuse.mipFilter = .linear
		}

		let ambientR: Float = try stream.read()
		let ambientG: Float = try stream.read()
		let ambientB: Float = try stream.read()
		material.ambient.contents = SKColor(
			red: CGFloat(ambientR),
			green: CGFloat(ambientG),
			blue: CGFloat(ambientB),
			alpha: 1
		)

		let diffuseR: Float = try stream.read()
		let diffuseG: Float = try stream.read()
		let diffuseB: Float = try stream.read()
		material.diffuse.contents = SKColor(
			red: CGFloat(diffuseR),
			green: CGFloat(diffuseG),
			blue: CGFloat(diffuseB),
			alpha: 1
		)

		let _: Float = try stream.read() // emissionR
		let _: Float = try stream.read() // emissionG
		let _: Float = try stream.read() // emissionB
//		material.emission.contents = SKColor(red: CGFloat(emissionR), green: CGFloat(emissionG), blue: CGFloat(emissionB), alpha: 1)

		let opacity: Float = try stream.read()
		material.transparency = CGFloat(opacity)

		if flags.contains(.reflectionTexture) {
			let ratio: Float = try stream.read()
			let textureNameLength: UInt8 = try stream.read()
			let textureName: String = try stream.read(maxLength: Int(textureNameLength))
			let url = mainDirectory.appendingPathComponent("maps/"+textureName)
			#if os(macOS)
				material.reflective.contents = NSImage(contentsOf: url)
			#elseif os(iOS)
				material.reflective.contents = UIImage(contentsOfFile: url.path)
			#endif
			material.reflective.intensity = CGFloat(ratio)
			material.reflective.wrapS = .repeat
			material.reflective.wrapT = .repeat
		}

		if flags.contains(.diffuseTexture) {
			let textureNameLength: UInt8 = try stream.read()
			let textureName: String = (try stream.read(maxLength: Int(textureNameLength))).lowercased()
			let url = mainDirectory.appendingPathComponent("maps/"+textureName)
			let data = try Data(contentsOf: url)

			#if os(macOS)
				if flags.contains(.colorKey) {
					let b = CGFloat(data[54])/255
					let g = CGFloat(data[55])/255
					let r = CGFloat(data[56])/255
					let color = NSColor(red: r, green: g, blue: b, alpha: 1)
					if let source = CGImageSourceCreateWithData(data as CFData, nil),
					   let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
					   let masked = cgImage.removeColor(color.cgColor) {
						material.diffuse.contents = masked.caLayer()
					} else {
						material.diffuse.contents = NSImage(data: data)
					}
				} else {
					material.diffuse.contents = NSImage(data: data)
				}
			#elseif os(iOS)
				if let image = imageCache[textureName] {
					material.diffuse.contents = image
				} else {
					if flags.contains(.colorKey) {
						let b = CGFloat(data[54])/255
						let g = CGFloat(data[55])/255
						let r = CGFloat(data[56])/255
						let color = UIColor(red: r, green: g, blue: b, alpha: 1)
						let image = UIImage(data: data)?.removeColor(color)
						imageCache[textureName] = image
						material.diffuse.contents = image?.cgImage?.caLayer()
					} else {
						let image = UIImage(data: data)
						imageCache[textureName] = image
						material.diffuse.contents = image
					}
				}
			#endif
			material.diffuse.wrapS = .repeat
			material.diffuse.wrapT = .repeat
		}

		if flags.contains(.opacityTexture) {
			let textureNameLength: UInt8 = try stream.read()
			let textureName: String = try stream.read(maxLength: Int(textureNameLength))
			let url = mainDirectory.appendingPathComponent("maps/"+textureName)
			material.transparencyMode = .rgbZero
			#if os(macOS)
				material.transparent.contents = NSImage(contentsOf: url)?.inversed
			#elseif os(iOS)
				material.transparent.contents = UIImage(contentsOfFile: url.path)
			#endif
			material.transparent.wrapS = .repeat
			material.transparent.wrapT = .repeat
		}

		if !flags.contains(.diffuseTexture) && !flags.contains(.opacityTexture) {
			let _: UInt8 = try stream.read()
			assert(true)
		}

		if flags.contains(.opacityTextureAnimation) || flags.contains(.diffuseTextureAnimation) {
			let _: UInt32 = try stream.read()		// numFrames
			let _: UInt16 = try stream.read()		// unknown
			let _: UInt32 = try stream.read()		// delay
			let _: UInt32 = try stream.read()		// unknown2
			let _: UInt32 = try stream.read()		// unknown3
		}

		materials.append(material)
	}

	var meshesDict: [SCNNode: [SingleMesh]] = [:]
	var joints: [Int: (SCNNode, SCNMatrix4)] = [:]

	let _nodesCount: UInt16 = try stream.read()
	let nodesCount = Int(_nodesCount)
	var nodeIds: [Int: SCNNode] = [:]
	for i in 0 ..< nodesCount {

		let node = SCNNode()

		nodeIds[i] = node

		let frameType = try FrameType(forcedRawValue: stream.read())

		let visualType: VisualType
//		let visualFlags: UInt16
		if frameType == .visual {
			visualType = try VisualType(forcedRawValue: stream.read())
			let _: UInt16 = try stream.read() // visualFlags
		} else {
			visualType = .object
//			visualFlags = 0
		}

		let parentId: UInt16 = try stream.read()
		if parentId == 0 {
			mainNode.addChildNode(node)
		} else {
			guard let parent = nodeIds[Int(parentId - 1)] else { throw ModelError.file }
			parent.addChildNode(node)
		}

		node.position = try SCNVector3(stream: stream)
		node.scale = try SCNVector3(stream: stream)
		node.orientation = try SCNQuaternion(stream: stream)

		let _: UInt8 = try stream.read() // cullingFlags
		//node.geometry?.firstMaterial?.cullMode

		let nameLength: UInt8 = try stream.read()
		node.name = try stream.read(maxLength: Int(nameLength))

		let descriptionLength: UInt8 = try stream.read()
		let _: String = try stream.read(maxLength: Int(descriptionLength)) // description
//		print("NODE:", node.name ?? "", "(\(description))")

		switch frameType {
		case .visual:
			switch visualType {
			case .object:
				try readObject(stream: stream, node: node, id: i)
			case .singleMesh:
				let numLODs = try readObject(stream: stream, node: node, id: i)
				meshesDict[node] = try readMesh(stream: stream, node: node, numLODs: numLODs)
			case .singleMorph:
				let numLODs = try readObject(stream: stream, node: node, id: i)
				meshesDict[node] = try readMesh(stream: stream, node: node, numLODs: numLODs)
				try readMorph(stream: stream, node: node, id: i)
			case .billboard:
				try readObject(stream: stream, node: node, id: i)
				let _: UInt32 = try stream.read()	// axis
				let _: UInt8 = try stream.read()	// axisMode
			case .morph:
				try readObject(stream: stream, node: node, id: i)
				try readMorph(stream: stream, node: node, id: i)
			case .lens:
				let numGlows: UInt8 = try stream.read()
				for _ in 0 ..< numGlows {
					let _: Float = try stream.read()	// pos
					let _: UInt16 = try stream.read()	// materialID
				}
			case .mirror:
				try readMirror(stream: stream)
			default:
				assert(true, "other visualType")
			}

		case .sector:
			try readSector(stream: stream)

		case .dummy:
//			print("DUMMY: \(node.name) (\(description))")
			let _ = try readDummy(stream: stream) // _node
			//node.addChildNode(_node)

		case .target:
			try readTarget(stream: stream)

			/*let box = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)
			box.firstMaterial = SCNMaterial()
			box.firstMaterial?.diffuse.contents = SKColor.red
			box.firstMaterial?.transparency = 0.2
			let boxNode = SCNNode(geometry: box)
			node.addChildNode(boxNode)*/

		case .joint:
			let (matrix, id) = try readJoint(stream: stream)
			joints[id] = (node, matrix)

		default:
			assert(true, "other frameType")
		}
	}

	for (node, meshes) in meshesDict {
		let mesh = meshes[0]
		let boneNodes = mesh.boneIds.map({ joints[$0]!.0 })
//		let boneTransforms = mesh.boneIds.map({ NSValue(scnMatrix4: joints[$0]!.1) })
		let boneInverseBindTransforms = mesh.transforms.map({ NSValue(scnMatrix4: $0) })
		node.skinner = SCNSkinner(
			baseGeometry: node.geometry,
			bones: boneNodes,
			boneInverseBindTransforms: boneInverseBindTransforms,
			boneWeights: mesh.boneWeights,
			boneIndices: mesh.boneIndices
		)
	}

	let _animation: UInt8 = try stream.read()
	let animation = _animation == 0 ? false : true
	if animation {
//		print("\(name) animation")
		try playAnimation(named: name + ".5ds", in: mainNode, repeat: true)
	}

	stream.close()

	return mainNode
}
