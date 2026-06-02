//
//  DifferenceFile.swift
//  Mafia
//
//  Created by Codex on 6/1/26.
//

import Foundation
import SceneKit
import SpriteKit

struct DifferenceFileError: Error { }

enum DifferenceRecordKind: UInt16 {
	case object = 100
	case objectDefinition = 200
	case animation = 400
	case script = 500
}

struct DifferenceScript {
	let name: String
	let source: String
}

struct DifferenceSound {
	let name: String
	let fileName: String
	let node: SCNNode
}

final class DifferenceFile {

	let name: String
	let rootNode = SCNNode()
	private(set) var scripts: [String: DifferenceScript] = [:]
	private(set) var sounds: [DifferenceSound] = []
	private(set) var animationStates: [String: Bool] = [:]
	let declaredFileSize: Int
	private var pendingSound: (name: String, fileName: String)?

	convenience init(named name: String) throws {
		let lowercasedName = name.lowercased()
		let fileName = lowercasedName.hasSuffix(".chg") ? lowercasedName : lowercasedName + ".chg"
		let url = mainDirectory.appendingPathComponent("diff/" + fileName)
		try self.init(url: url)
	}

	init(url: URL) throws {
		guard let stream = InputStream(url: url) else { throw DifferenceFileError() }
		stream.open()
		defer { stream.close() }

		let header: UInt16 = try stream.read()
		guard header == 0x04d2 else { throw DifferenceFileError() }

		let fileSize: UInt32 = try stream.read()
		declaredFileSize = Int(fileSize)
		name = url.deletingPathExtension().lastPathComponent
		rootNode.name = "__diff_\(name)__"

		var loadedScripts: [String: DifferenceScript] = [:]
		var loadedSounds: [DifferenceSound] = []
		var loadedAnimationStates: [String: Bool] = [:]
		while stream.currentOffset + 6 <= declaredFileSize {
			let recordStartOffset = stream.currentOffset
			let rawKind: UInt16 = try stream.read()
			let recordSize: UInt32 = try stream.read()
			let recordEndOffset = recordStartOffset + Int(recordSize)
			guard recordSize >= 6, recordEndOffset <= declaredFileSize else {
				stream.currentOffset = declaredFileSize
				break
			}

			switch DifferenceRecordKind(rawValue: rawKind) {
			case .object:
				if let node = try readObject(stream: stream, endOffset: recordEndOffset) {
					if let sound = pendingSound {
						loadedSounds.append(DifferenceSound(name: sound.name, fileName: sound.fileName, node: node))
						pendingSound = nil
					}
					rootNode.addChildNode(node)
				}

			case .script:
				for script in try readScripts(stream: stream, endOffset: recordEndOffset) {
					loadedScripts[script.name] = script
				}

			case .animation:
				if let animationState = try readAnimationState(stream: stream, endOffset: recordEndOffset) {
					loadedAnimationStates[animationState.name] = animationState.isEnabled
				}

			case .objectDefinition, .none:
				break
			}

			stream.currentOffset = recordEndOffset
		}

		scripts = loadedScripts
		sounds = loadedSounds
		animationStates = loadedAnimationStates
	}

	static func availableNames() -> [String] {
		let url = mainDirectory.appendingPathComponent("diff")
		guard let urls = try? FileManager.default.contentsOfDirectory(
			at: url,
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		) else {
			return []
		}

		return urls
			.filter { $0.pathExtension.lowercased() == "chg" }
			.map { $0.deletingPathExtension().lastPathComponent }
			.sorted()
	}

	private func readObject(stream: InputStream, endOffset: Int) throws -> SCNNode? {
		guard stream.currentOffset + 44 <= endOffset else { return nil }

		let rawType: UInt32 = try stream.read()
		let objectType = ObjectType(rawValue: rawType) ?? .object
		let node = SCNNode()
		node.position = try SCNVector3(stream: stream)
		node.scale = try SCNVector3(stream: stream)
		let orientationW: Float = try stream.read()
		let orientationX: Float = try stream.read()
		let orientationY: Float = try stream.read()
		let orientationZ: Float = try stream.read()
		node.orientation = SCNQuaternion(
			x: SCNFloat(orientationX),
			y: SCNFloat(orientationY),
			z: SCNFloat(orientationZ),
			w: -SCNFloat(orientationW)
		)
		node.recordSourcePosition = node.position
		node.recordSourceOrientationVector = SCNVector3(
			x: SCNFloat(orientationW),
			y: SCNFloat(orientationX),
			z: SCNFloat(orientationY)
		)

		node.name = try readLengthPrefixedString(stream: stream, endOffset: endOffset)
		let sectorName = try readLengthPrefixedString(stream: stream, endOffset: endOffset)

		switch objectType {
		case .model:
			let modelName = try readLengthPrefixedString(stream: stream, endOffset: endOffset)
				.lowercased()
				.replacingOccurrences(of: ".i3d", with: "")
			node.vehicleModelName = modelName
			try? loadModel(named: "models/" + modelName, node: node)

		case .sound:
			let soundName = try readLengthPrefixedString(stream: stream, endOffset: endOffset)
			if let nodeName = node.name, !soundName.isEmpty {
				pendingSound = (nodeName, soundName)
			}

		case .light:
			configurePlaceholderLight(node, sectorName: sectorName)

		default:
			break
		}

		return node
	}

	private func readScripts(stream: InputStream, endOffset: Int) throws -> [DifferenceScript] {
		var scripts: [DifferenceScript] = []

		while stream.currentOffset + 9 <= endOffset {
			let _: UInt8 = try stream.read()
			let name = try readLengthPrefixedString(stream: stream, endOffset: endOffset)
			let source = try readLengthPrefixedString(stream: stream, endOffset: endOffset)
			guard !name.isEmpty else { continue }
			scripts.append(DifferenceScript(name: name, source: source))
		}

		return scripts
	}

	private func readAnimationState(
		stream: InputStream,
		endOffset: Int
	) throws -> (name: String, isEnabled: Bool)? {
		let name = try readLengthPrefixedString(stream: stream, endOffset: endOffset)
		guard !name.isEmpty,
			  stream.currentOffset + 4 <= endOffset else {
			return nil
		}

		let isEnabled: UInt32 = try stream.read()
		return (name, isEnabled != 0)
	}

	private func readLengthPrefixedString(stream: InputStream, endOffset: Int) throws -> String {
		guard stream.currentOffset + 4 <= endOffset else { return "" }
		let length: UInt32 = try stream.read()
		let remaining = endOffset - stream.currentOffset
		guard length <= UInt32(remaining) else {
			stream.currentOffset = endOffset
			return ""
		}
		return try stream.read(maxLength: Int(length), encoding: .windowsCP1250)
	}

	private func configurePlaceholderLight(_ node: SCNNode, sectorName _: String) {
		let light = SCNLight()
		light.type = .omni
		light.color = SKColor.white
		light.intensity = 650
		node.light = light
		node.name = node.name ?? "FMV light"
	}

}
