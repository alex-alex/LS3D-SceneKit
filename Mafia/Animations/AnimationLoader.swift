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
	private static let frameDuration: TimeInterval = 1.0 / 25.0

	let name: String
	let timerMax: Int
	let rotations: [Int: SCNQuaternion]
	let scales: [Int: SCNVector3]
	let positions: [Int: SCNVector3]

	var lastScale: SCNVector3?

	init(
		name: String,
		timerMax: Int,
		rotations: [Int: SCNQuaternion],
		scales: [Int: SCNVector3],
		positions: [Int: SCNVector3]) {
		self.name = name
		self.timerMax = timerMax
		self.rotations = rotations
		self.scales = scales
		self.positions = positions
	}

	var action: SCNAction {
		let positionKeys = positions.keys.sorted()
		let scaleKeys = scales.keys.sorted()
		let rotationKeys = rotations.keys.sorted()
		let duration = TimeInterval(timerMax) * Animation.frameDuration

		guard duration > 0 else {
			return SCNAction.run { node in
				if let position = self.positions[0] {
					node.position = position
				}
				if let scale = self.scales[0] {
					node.scale = scale
				}
				if let rotation = self.rotations[0] {
					node.orientation = rotation
				}
			}
		}

		return SCNAction.customAction(duration: duration) { node, elapsedTime in
			let tick = CGFloat(elapsedTime / CGFloat(Animation.frameDuration))
			if let position = Animation.interpolatedVector(keys: positionKeys, values: self.positions, at: tick) {
				node.position = position
			}
			if let scale = Animation.interpolatedVector(keys: scaleKeys, values: self.scales, at: tick) {
				node.scale = scale
			}
			if let rotation = Animation.interpolatedQuaternion(keys: rotationKeys, values: self.rotations, at: tick) {
				node.orientation = rotation
			}
		}
	}

	private static func interpolatedVector(keys: [Int], values: [Int: SCNVector3], at tick: CGFloat) -> SCNVector3? {
		guard let firstKey = keys.first else { return nil }
		guard tick >= CGFloat(firstKey) else { return nil }

		var previousKey = firstKey
		for key in keys.dropFirst() {
			guard tick > CGFloat(key) else {
				guard let previousValue = values[previousKey],
					  let nextValue = values[key] else { return values[key] }
				let t = CGFloat(key == previousKey ? 1 : (tick - CGFloat(previousKey)) / CGFloat(key - previousKey))
				return lerp(previousValue, nextValue, t)
			}
			previousKey = key
		}

		return values[previousKey]
	}

	private static func interpolatedQuaternion(keys: [Int], values: [Int: SCNQuaternion], at tick: CGFloat) -> SCNQuaternion? {
		guard let firstKey = keys.first else { return nil }
		guard tick >= CGFloat(firstKey) else { return nil }

		var previousKey = firstKey
		for key in keys.dropFirst() {
			guard tick > CGFloat(key) else {
				guard let previousValue = values[previousKey],
					  let nextValue = values[key] else { return values[key] }
				let t = CGFloat(key == previousKey ? 1 : (tick - CGFloat(previousKey)) / CGFloat(key - previousKey))
				return slerp(previousValue, nextValue, t)
			}
			previousKey = key
		}

		return values[previousKey]
	}

	private static func lerp(_ start: SCNVector3, _ end: SCNVector3, _ t: CGFloat) -> SCNVector3 {
		let amount = SCNFloat(max(0, min(1, t)))
		return SCNVector3(
			x: start.x + (end.x - start.x) * amount,
			y: start.y + (end.y - start.y) * amount,
			z: start.z + (end.z - start.z) * amount
		)
	}

	private static func slerp(_ start: SCNQuaternion, _ end: SCNQuaternion, _ t: CGFloat) -> SCNQuaternion {
		let amount = SCNFloat(max(0, min(1, t)))
		var to = end
		var cosine = start.x * to.x + start.y * to.y + start.z * to.z + start.w * to.w

		if cosine < 0 {
			cosine = -cosine
			to = SCNQuaternion(x: -to.x, y: -to.y, z: -to.z, w: -to.w)
		}

		if cosine > 0.9995 {
			return normalized(SCNQuaternion(
				x: start.x + (to.x - start.x) * amount,
				y: start.y + (to.y - start.y) * amount,
				z: start.z + (to.z - start.z) * amount,
				w: start.w + (to.w - start.w) * amount
			))
		}

		let angle = acos(max(-1, min(1, cosine)))
		let sinAngle = sin(angle)
		guard abs(sinAngle) > 0.0001 else { return start }

		let startScale = sin((1 - amount) * angle) / sinAngle
		let endScale = sin(amount * angle) / sinAngle
		return normalized(SCNQuaternion(
			x: start.x * startScale + to.x * endScale,
			y: start.y * startScale + to.y * endScale,
			z: start.z * startScale + to.z * endScale,
			w: start.w * startScale + to.w * endScale
		))
	}

	private static func normalized(_ quaternion: SCNQuaternion) -> SCNQuaternion {
		let length = sqrt(
			quaternion.x * quaternion.x +
			quaternion.y * quaternion.y +
			quaternion.z * quaternion.z +
			quaternion.w * quaternion.w
		)
		guard length > 0.0001 else { return SCNQuaternion(x: 0, y: 0, z: 0, w: 1) }
		return SCNQuaternion(
			x: quaternion.x / length,
			y: quaternion.y / length,
			z: quaternion.z / length,
			w: quaternion.w / length
		)
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
		try animations.append(readAnimation(
			stream: stream,
			timerMax: Int(timerMax),
			nameOffset: nameOffset,
			animOffset: animOffset)
		)
	}

	return (animations, Double(timerMax)/25)
}

func playAnimation(
	named name: String,
	in node: SCNNode,
	repeat: Bool = false,
	animationKey: String? = nil,
	completionHandler: (() -> Void)? = nil) throws {
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
	let (animations, _) = try loadAnimation(named: name)
	for animation in animations {
		let node = node.childNode(withName: animation.name, recursively: true)
//		if name == "anims/walk1.5ds" { print(node?.name); print("actionKeys:", node?.actionKeys) }
		node?.removeAction(forKey: animationKey)
	}
//	if name == "anims/walk1.5ds" { print("===============") }
}
