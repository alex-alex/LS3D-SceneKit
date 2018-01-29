//
//  AnimationLoader.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/16/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

enum AnimationError: Error {
	case file
}

struct MovementFlags: OptionSet {
	let rawValue: UInt32
	static let position		= MovementFlags(rawValue: 2)
	static let rotation		= MovementFlags(rawValue: 4)
	static let scale		= MovementFlags(rawValue: 8)
}

func readRotations(stream: InputStream) throws -> [Int: SCNQuaternion] {
	
	let _animGroupsCount: UInt16 = try stream.read()
	let animGroupsCount = Int(_animGroupsCount)
	
	var timers: [Int] = []
	
	for _ in 0 ..< animGroupsCount {
		let timer: UInt16 = try stream.read()
		timers.append(Int(timer))
	}
	
	if animGroupsCount % 2 == 0 {
		stream.currentOffset += 2
	}
	
	var rotations: [Int: SCNQuaternion] = [:]
	
	for i in 0 ..< animGroupsCount {
		let w: Float = try stream.read()
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		rotations[timers[i]] = SCNQuaternion(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z), w: -SCNFloat(w))
	}
	
	return rotations
}

func readScales(stream: InputStream) throws -> [Int: SCNVector3] {
	
	let _animGroupsCount: UInt16 = try stream.read()
	let animGroupsCount = Int(_animGroupsCount)
	
	var timers: [Int] = []
	
	for _ in 0 ..< animGroupsCount {
		let timer: UInt16 = try stream.read()
		timers.append(Int(timer))
	}
	
	if animGroupsCount % 2 == 0 {
		stream.currentOffset += 2
	}
	
	var scales: [Int: SCNVector3] = [:]
	
	for i in 0 ..< animGroupsCount {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		scales[timers[i]] = SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
	}
	
	return scales
}

func readPositions(stream: InputStream) throws -> [Int: SCNVector3] {
	
	let _animGroupsCount: UInt16 = try stream.read()
	let animGroupsCount = Int(_animGroupsCount)
	
	var timers: [Int] = []
	
	for _ in 0 ..< animGroupsCount {
		let timer: UInt16 = try stream.read()
		timers.append(Int(timer))
	}
	
	if animGroupsCount % 2 == 0 {
		stream.currentOffset += 2
	}
	
	var positions: [Int: SCNVector3] = [:]
	
	for i in 0 ..< animGroupsCount {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		positions[timers[i]] = SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
	}
	
	return positions
}

class Animation {
	let name: String
	let timerMax: Int
	let rotations: [Int: SCNQuaternion]
	let scales: [Int: SCNVector3]
	let positions: [Int: SCNVector3]
	
	var lastScale: SCNVector3? = nil
	
	init(name: String, timerMax: Int, rotations: [Int: SCNQuaternion], scales: [Int: SCNVector3], positions: [Int: SCNVector3]) {
		self.name = name
		self.timerMax = timerMax
		self.rotations = rotations
		self.scales = scales
		self.positions = positions
	}
	
	var action: SCNAction {
		var actions: [SCNAction] = []
		for t in 0 ... timerMax {
			actions.append(SCNAction.sequence([
				SCNAction.run { node in
//					SCNTransaction.begin()
//					SCNTransaction.animationDuration = 0.04
					if let position = self.positions[t] {
						node.position = position
					}
					if let scale = self.scales[t] {
						node.scale = scale
					}
					if let rotation = self.rotations[t] {
						node.orientation = rotation
					}
//					SCNTransaction.commit()
				},
				SCNAction.wait(duration: 0.04)
			]))
		}
		return SCNAction.sequence(actions)
	}
}

func readAnimation(stream: InputStream, timerMax: Int, nameOffset: UInt32, animOffset: UInt32) throws -> Animation {
	let startOffset = stream.currentOffset
	
	stream.currentOffset = Int(nameOffset)
	
	let name: String = try stream.read(maxLength: 100)
	
	stream.currentOffset = Int(animOffset)
	
	let flags = try MovementFlags(rawValue: stream.read())
	
	let rotations: [Int: SCNQuaternion]
	let scales: [Int: SCNVector3]
	let positions: [Int: SCNVector3]
	
	if flags.contains(.rotation) {
		rotations = try readRotations(stream: stream)
	} else {
		rotations = [:]
	}
	
	if flags.contains(.position) {
		positions = try readPositions(stream: stream)
	} else {
		positions = [:]
	}
	
	if flags.contains(.scale) {
		scales = try readScales(stream: stream)
	} else {
		scales = [:]
	}
	
	stream.currentOffset = startOffset
	
	return Animation(name: name, timerMax: timerMax, rotations: rotations, scales: scales, positions: positions)
}

func loadAnimation(named name: String) throws -> ([Animation], TimeInterval) {
	let url = mainDirectory.appendingPathComponent(name.lowercased())
	
	guard let stream = InputStream(url: url) else { throw AnimationError.file }
	stream.open()
	
	let str: String = try stream.read(maxLength: 4)
	guard str == "5DS" else { throw AnimationError.file }
	
	let ver: UInt16 = try stream.read()
	guard ver == 20 else { throw AnimationError.file }
	
	let _: UInt64 = try stream.read() // timestamp
	
	let _: UInt32 = try stream.read() // dataSize
	let objectsCount: UInt16 = try stream.read()
	let timerMax: UInt16 = try stream.read() // 25 units = 1 sec
	
	var animations: [Animation] = []
	
	for _ in 0 ..< objectsCount {
		let nameOffset: UInt32 = try stream.read() + 18
		let animOffset: UInt32 = try stream.read() + 18
		try animations.append(readAnimation(stream: stream, timerMax: Int(timerMax), nameOffset: nameOffset, animOffset: animOffset))
	}
	
	return (animations, Double(timerMax)/25)
}

func playAnimation(named name: String, in node: SCNNode, repeat: Bool = false, animationKey: String? = nil, completionHandler: (() -> Void)? = nil) throws {
//	if name == "anims/walk1.5ds" { print("===============") }
//	if name == "anims/walk1.5ds" { print("playAnimation") }
	let (animations, duration) = try loadAnimation(named: name)
	for animation in animations {
		let node = node.childNode(withName: animation.name, recursively: true)
		if `repeat` {
			node?.runAction(SCNAction.repeatForever(animation.action), forKey: animationKey)
		} else {
			node?.runAction(animation.action, forKey: animationKey)
		}
//		if name == "anims/walk1.5ds" { print(node?.name); print("animationKeys:", node?.animationKeys) }
	}
	node.runAction(SCNAction.wait(duration: duration), completionHandler: completionHandler)
//	if name == "anims/walk1.5ds" { print("===============") }
}

func stopAnimation(named name: String, in node: SCNNode, animationKey: String) throws {
//	if name == "anims/walk1.5ds" { print("===============") }
//	if name == "anims/walk1.5ds" { print("stopAnimation") }
//	let (animations, _) = try loadAnimation(named: name)
//	for animation in animations {
//		let node = node.childNode(withName: animation.name, recursively: true)
//		if name == "anims/walk1.5ds" { print(node?.name); print("animationKeys:", node?.animationKeys) }
//		node?.removeAnimation(forKey: animationKey)
//	}
//	if name == "anims/walk1.5ds" { print("===============") }
}
