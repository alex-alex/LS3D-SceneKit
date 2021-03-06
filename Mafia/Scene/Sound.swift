//
//  Sound.swift
//  Mafia
//
//  Created by Alex Studnička on 06/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

final class Sound {

	enum SourceType: UInt32 {
		case unknown0 = 0, local, unknown, global
	}

	let scene: Scene
	let node: SCNNode
	let sourceType: SourceType

	let audioSource: SCNAudioSource

	init(scene: Scene, node: SCNNode, stream: InputStream, partSize: Int) throws {
		self.scene = scene
		self.node = node

		let _: UInt16 = try stream.read()		// const 0x0010

		let len: UInt32 = try stream.read()
		let sound: String = try stream.read(maxLength: Int(len))
//		print("SOUND src:", objectNode.name, sound)

		let url = mainDirectory.appendingPathComponent("sounds/" + sound.lowercased())
		audioSource = SCNAudioSource(url: url)!
		audioSource.loops = false
		audioSource.load()
		//scene.sounds[objectNode] = source
		//objectNode.runAction(SCNAction.playAudio(source, waitForCompletion: true), forKey: "sound")

		let param1: UInt32 = try stream.read()
		sourceType = SourceType(rawValue: param1)!

		let _: UInt16 = try stream.read()		// const 0x4062
		let _: UInt32 = try stream.read()		// always 10?
		let _: Float = try stream.read()		// 0 - 1 (volume?)
//		audioSource.volume = param4

		let _: UInt16 = try stream.read()		// const 0x4063
		let _: UInt32 = try stream.read()		// always 10?
		let _: UInt32 = try stream.read()		// always 0?

		let _: UInt16 = try stream.read()		// const 0x4064
		let _: UInt32 = try stream.read()		// always 14?
		let _: Float = try stream.read()		// 0.523599, 1.0472
		let _: Float = try stream.read()		// 1.5708

		let _: UInt16 = try stream.read()		// const 0x4068
		let _: UInt32 = try stream.read()		// always 2?

		// F1 - distance from the source of sound to F1 with a constant volume (10)
		let _: Float = try stream.read()
		// F2 - distance from F1 to F2 with decreasing volume (100)
		let _: Float = try stream.read()
		// F3 - volume level at distance F2 (0.1)
		let _: Float = try stream.read()
		// F4 - volume level at distance F1 (0.7)
		let _: Float = try stream.read()

		let _: UInt16 = try stream.read()		// const 0x4067
		let _: UInt32 = try stream.read()		// always 6?

//		let _: UInt16 = try stream.read()		// const 0x00b8

//		stream.currentOffset += partSize - 78 - Int(len)

		let _: [UInt8] = try stream.read(maxLength: partSize - 78 - Int(len))
//		print("sound data:", data.map({ String(format: "%02x", $0) }).joined(separator: " "), "\n\n")
	}

	func play() {
		if sourceType == .global {
			scene.playerNode!.runAction(SCNAction.playAudio(audioSource, waitForCompletion: true), forKey: "sound")
		} else {
			node.runAction(SCNAction.playAudio(audioSource, waitForCompletion: true), forKey: "sound")
		}
	}

}
