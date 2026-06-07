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

private final class WeakNode {
	weak var node: SCNNode?

	init(_ node: SCNNode) {
		self.node = node
	}
}

fileprivate struct AnimationKeyframe<Value> {
	let tick: Int
	let value: Value
}

fileprivate func normalizedKeyframes<Value>(_ keyframes: [AnimationKeyframe<Value>]) -> [AnimationKeyframe<Value>] {
	guard !keyframes.isEmpty else { return [] }

	var isOrdered = true
	for index in 1 ..< keyframes.count where keyframes[index].tick < keyframes[index - 1].tick {
		isOrdered = false
		break
	}

	if isOrdered {
		var normalized: [AnimationKeyframe<Value>] = []
		normalized.reserveCapacity(keyframes.count)
		for keyframe in keyframes {
			if normalized.last?.tick == keyframe.tick {
				normalized[normalized.count - 1] = keyframe
			} else {
				normalized.append(keyframe)
			}
		}
		return normalized
	}

	var valuesByTick: [Int: Value] = [:]
	valuesByTick.reserveCapacity(keyframes.count)
	for keyframe in keyframes {
		valuesByTick[keyframe.tick] = keyframe.value
	}
	return valuesByTick.keys.sorted().compactMap { tick in
		guard let value = valuesByTick[tick] else { return nil }
		return AnimationKeyframe(tick: tick, value: value)
	}
}

fileprivate func readRotations(stream: InputStream) throws -> [AnimationKeyframe<SCNQuaternion>] {

	let _animGroupsCount: UInt16 = try stream.read()
	let animGroupsCount = Int(_animGroupsCount)

	var timers: [Int] = []
	timers.reserveCapacity(animGroupsCount)

	for _ in 0 ..< animGroupsCount {
		let timer: UInt16 = try stream.read()
		timers.append(Int(timer))
	}

	if animGroupsCount % 2 == 0 {
		stream.currentOffset += 2
	}

	var rotations: [AnimationKeyframe<SCNQuaternion>] = []
	rotations.reserveCapacity(animGroupsCount)

	for i in 0 ..< animGroupsCount {
		let w: Float = try stream.read()
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		rotations.append(AnimationKeyframe(
			tick: timers[i],
			value: SCNQuaternion(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z), w: -SCNFloat(w))
		))
	}

	return normalizedKeyframes(rotations)
}

fileprivate func readScales(stream: InputStream) throws -> [AnimationKeyframe<SCNVector3>] {

	let _animGroupsCount: UInt16 = try stream.read()
	let animGroupsCount = Int(_animGroupsCount)

	var timers: [Int] = []
	timers.reserveCapacity(animGroupsCount)

	for _ in 0 ..< animGroupsCount {
		let timer: UInt16 = try stream.read()
		timers.append(Int(timer))
	}

	if animGroupsCount % 2 == 0 {
		stream.currentOffset += 2
	}

	var scales: [AnimationKeyframe<SCNVector3>] = []
	scales.reserveCapacity(animGroupsCount)

	for i in 0 ..< animGroupsCount {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		scales.append(AnimationKeyframe(
			tick: timers[i],
			value: SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
		))
	}

	return normalizedKeyframes(scales)
}

fileprivate func readPositions(stream: InputStream) throws -> [AnimationKeyframe<SCNVector3>] {

	let _animGroupsCount: UInt16 = try stream.read()
	let animGroupsCount = Int(_animGroupsCount)

	var timers: [Int] = []
	timers.reserveCapacity(animGroupsCount)

	for _ in 0 ..< animGroupsCount {
		let timer: UInt16 = try stream.read()
		timers.append(Int(timer))
	}

	if animGroupsCount % 2 == 0 {
		stream.currentOffset += 2
	}

	var positions: [AnimationKeyframe<SCNVector3>] = []
	positions.reserveCapacity(animGroupsCount)

	for i in 0 ..< animGroupsCount {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		positions.append(AnimationKeyframe(
			tick: timers[i],
			value: SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
		))
	}

	return normalizedKeyframes(positions)
}

class Animation {
	private static let frameDuration: TimeInterval = 1.0 / 25.0
	struct Pose {
		let position: SCNVector3?
		let scale: SCNVector3?
		let rotation: SCNQuaternion?
	}

	let name: String
	let timerMax: Int
	fileprivate let rotations: [AnimationKeyframe<SCNQuaternion>]
	fileprivate let scales: [AnimationKeyframe<SCNVector3>]
	fileprivate let positions: [AnimationKeyframe<SCNVector3>]

	var lastScale: SCNVector3?

	fileprivate init(
		name: String,
		timerMax: Int,
		rotations: [AnimationKeyframe<SCNQuaternion>],
		scales: [AnimationKeyframe<SCNVector3>],
		positions: [AnimationKeyframe<SCNVector3>]) {
		self.name = name
		self.timerMax = timerMax
		self.rotations = rotations
		self.scales = scales
		self.positions = positions
	}

	var action: SCNAction {
		let duration = TimeInterval(timerMax) * Animation.frameDuration

		guard duration > 0 else {
			return SCNAction.run { node in
				if let position = self.keyframeValue(at: 0, in: self.positions) {
					node.position = position
				}
				if let scale = self.keyframeValue(at: 0, in: self.scales) {
					node.scale = scale
				}
				if let rotation = self.keyframeValue(at: 0, in: self.rotations) {
					node.orientation = rotation
				}
			}
		}

		return SCNAction.customAction(duration: duration) { node, elapsedTime in
			let tick = CGFloat(elapsedTime / CGFloat(Animation.frameDuration))
			if let position = Animation.interpolatedVector(keyframes: self.positions, at: tick) {
				node.position = position
			}
			if let scale = Animation.interpolatedVector(keyframes: self.scales, at: tick) {
				node.scale = scale
			}
			if let rotation = Animation.interpolatedQuaternion(keyframes: self.rotations, at: tick) {
				node.orientation = rotation
			}
		}
	}

	func apply(elapsedTime: TimeInterval, to node: SCNNode) {
		applyPose(samplePose(elapsedTime: elapsedTime), to: node)
	}

	func samplePose(elapsedTime: TimeInterval) -> Pose {
		let tick = CGFloat(elapsedTime / Animation.frameDuration)
		return Pose(
			position: Animation.interpolatedVector(keyframes: positions, at: tick),
			scale: Animation.interpolatedVector(keyframes: scales, at: tick),
			rotation: Animation.interpolatedQuaternion(keyframes: rotations, at: tick)
		)
	}

	func blend(from pose: Pose, elapsedTime: TimeInterval, transitionDuration: TimeInterval, to node: SCNNode) {
		let targetPose = samplePose(elapsedTime: elapsedTime)
		let amount = Animation.smoothstep(CGFloat(elapsedTime / max(transitionDuration, 0.0001)))
		applyPose(Animation.blendedPose(from: pose, to: targetPose, amount: amount), to: node)
	}

	func blend(
		from pose: Pose,
		toElapsedTime targetElapsedTime: TimeInterval,
		transitionElapsedTime: TimeInterval,
		transitionDuration: TimeInterval,
		to node: SCNNode
	) {
		let targetPose = samplePose(elapsedTime: targetElapsedTime)
		let amount = Animation.smoothstep(CGFloat(transitionElapsedTime / max(transitionDuration, 0.0001)))
		applyPose(Animation.blendedPose(from: pose, to: targetPose, amount: amount), to: node)
	}

	func presentationPose(of node: SCNNode) -> Pose {
		return Pose(
			position: node.presentation.position,
			scale: node.presentation.scale,
			rotation: node.presentation.orientation
		)
	}

	private func applyPose(_ pose: Pose, to node: SCNNode) {
		if let position = pose.position {
			node.position = position
		}
		if let scale = pose.scale {
			node.scale = scale
		}
		if let rotation = pose.rotation {
			node.orientation = rotation
		}
	}

	func applyInitialPose(to node: SCNNode) {
		if let position = positions.first?.value {
			node.position = position
		}
		if let scale = scales.first?.value {
			node.scale = scale
		}
		if let rotation = rotations.first?.value {
			node.orientation = rotation
		}
	}

	private func keyframeValue<Value>(at tick: Int, in keyframes: [AnimationKeyframe<Value>]) -> Value? {
		return keyframes.first { $0.tick == tick }?.value
	}

	private static func interpolatedVector(keyframes: [AnimationKeyframe<SCNVector3>], at tick: CGFloat) -> SCNVector3? {
		guard let bounds = keyframeBounds(in: keyframes, at: tick) else { return nil }
		guard bounds.previous.tick != bounds.next.tick else { return bounds.previous.value }
		let t = CGFloat((tick - CGFloat(bounds.previous.tick)) / CGFloat(bounds.next.tick - bounds.previous.tick))
		return lerp(bounds.previous.value, bounds.next.value, smoothstep(t))
	}

	private static func interpolatedQuaternion(keyframes: [AnimationKeyframe<SCNQuaternion>], at tick: CGFloat) -> SCNQuaternion? {
		guard let bounds = keyframeBounds(in: keyframes, at: tick) else { return nil }
		guard bounds.previous.tick != bounds.next.tick else { return bounds.previous.value }
		let t = CGFloat((tick - CGFloat(bounds.previous.tick)) / CGFloat(bounds.next.tick - bounds.previous.tick))
		return slerp(bounds.previous.value, bounds.next.value, smoothstep(t))
	}

	private static func keyframeBounds<Value>(
		in keyframes: [AnimationKeyframe<Value>],
		at tick: CGFloat
	) -> (previous: AnimationKeyframe<Value>, next: AnimationKeyframe<Value>)? {
		guard let firstKeyframe = keyframes.first else { return nil }
		guard tick >= CGFloat(firstKeyframe.tick) else { return nil }
		guard let lastKeyframe = keyframes.last else { return nil }
		guard tick <= CGFloat(lastKeyframe.tick) else {
			return (lastKeyframe, lastKeyframe)
		}

		var lowerBound = 0
		var upperBound = keyframes.count - 1
		while lowerBound < upperBound {
			let middle = (lowerBound + upperBound) / 2
			if tick > CGFloat(keyframes[middle].tick) {
				lowerBound = middle + 1
			} else {
				upperBound = middle
			}
		}

		let nextIndex = lowerBound
		guard nextIndex > 0 else { return (keyframes[0], keyframes[0]) }
		return (keyframes[nextIndex - 1], keyframes[nextIndex])
	}

	private static func smoothstep(_ t: CGFloat) -> CGFloat {
		let amount = max(0, min(1, t))
		return amount * amount * (3 - 2 * amount)
	}

	private static func lerp(_ start: SCNVector3, _ end: SCNVector3, _ t: CGFloat) -> SCNVector3 {
		let amount = SCNFloat(max(0, min(1, t)))
		return SCNVector3(
			x: start.x + (end.x - start.x) * amount,
			y: start.y + (end.y - start.y) * amount,
			z: start.z + (end.z - start.z) * amount
		)
	}

	private static func blendedPose(from start: Pose, to end: Pose, amount: CGFloat) -> Pose {
		return Pose(
			position: blend(start.position, end.position, amount, lerp),
			scale: blend(start.scale, end.scale, amount, lerp),
			rotation: blend(start.rotation, end.rotation, amount, slerp)
		)
	}

	private static func blend<Value>(
		_ start: Value?,
		_ end: Value?,
		_ amount: CGFloat,
		_ interpolate: (Value, Value, CGFloat) -> Value
	) -> Value? {
		guard let end = end else { return nil }
		guard let start = start else { return end }
		return interpolate(start, end, amount)
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

private struct LoadedAnimation {
	let animations: [Animation]
	let duration: TimeInterval
}

private let loadedAnimationsLock = NSLock()
private var loadedAnimationsByName: [String: LoadedAnimation] = [:]
private let animationTargetCacheLock = NSLock()
private var animationTargetCache: [ObjectIdentifier: [String: WeakNode]] = [:]

func readAnimation(stream: InputStream, timerMax: Int, nameOffset: UInt32, animOffset: UInt32) throws -> Animation {
	let startOffset = stream.currentOffset

	stream.currentOffset = Int(nameOffset)

	let name: String = try stream.read(maxLength: 100)

	stream.currentOffset = Int(animOffset)

	let flags = try MovementFlags(rawValue: stream.read())

	let rotations: [AnimationKeyframe<SCNQuaternion>]
	let scales: [AnimationKeyframe<SCNVector3>]
	let positions: [AnimationKeyframe<SCNVector3>]

	if flags.contains(.rotation) {
		rotations = try readRotations(stream: stream)
	} else {
		rotations = []
	}

	if flags.contains(.position) {
		positions = try readPositions(stream: stream)
	} else {
		positions = []
	}

	if flags.contains(.scale) {
		scales = try readScales(stream: stream)
	} else {
		scales = []
	}

	stream.currentOffset = startOffset

	return Animation(name: name, timerMax: timerMax, rotations: rotations, scales: scales, positions: positions)
}

func loadAnimation(named name: String) throws -> ([Animation], TimeInterval) {
	let key = name.lowercased()
	loadedAnimationsLock.lock()
	if let cachedAnimation = loadedAnimationsByName[key] {
		loadedAnimationsLock.unlock()
		return (cachedAnimation.animations, cachedAnimation.duration)
	}
	loadedAnimationsLock.unlock()

	let url = mainDirectory.appendingPathComponent(key)

	guard let stream = InputStream(url: url) else { throw AnimationError.file }
	stream.open()
	defer { stream.close() }

	let str: String = try stream.read(maxLength: 4)
	guard str == "5DS" else { throw AnimationError.file }

	let ver: UInt16 = try stream.read()
	guard ver == 20 else { throw AnimationError.file }

	let _: UInt64 = try stream.read() // timestamp

	let _: UInt32 = try stream.read() // dataSize
	let objectsCount: UInt16 = try stream.read()
	let timerMax: UInt16 = try stream.read() // 25 units = 1 sec

	var animations: [Animation] = []
	animations.reserveCapacity(Int(objectsCount))

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

	let duration = Double(timerMax) / 25
	loadedAnimationsLock.lock()
	loadedAnimationsByName[key] = LoadedAnimation(animations: animations, duration: duration)
	loadedAnimationsLock.unlock()
	return (animations, duration)
}

func animationDuration(named name: String) throws -> TimeInterval {
	let (_, duration) = try loadAnimation(named: name)
	return duration
}

func applyAnimationInitialPose(named name: String, in node: SCNNode) throws {
	let (animations, _) = try loadAnimation(named: name)
	for animation in animations {
		guard let targetNode = animationTargetNode(named: animation.name, in: node) else { continue }
		animation.applyInitialPose(to: targetNode)
	}
}

func playAnimation(
	named name: String,
	in node: SCNNode,
	repeat: Bool = false,
	animationKey: String? = nil,
	transitionDuration: TimeInterval = 0,
	completionHandler: (() -> Void)? = nil) throws {
//	if name == "anims/walk1.5ds" { print("===============") }
//	if name == "anims/walk1.5ds" { print("playAnimation") }
	let (animations, duration) = try loadAnimation(named: name)
	let matchedAnimations = animations.compactMap { animation -> (animation: Animation, node: SCNNode)? in
		guard let targetNode = animationTargetNode(named: animation.name, in: node) else { return nil }
		return (animation, targetNode)
	}
	if duration > 0, !matchedAnimations.isEmpty {
		let transitionDuration = max(0, min(transitionDuration, duration))
		let startPoses = transitionDuration > 0 ? matchedAnimations.map { matchedAnimation in
			matchedAnimation.animation.presentationPose(of: matchedAnimation.node)
		} : []
		let animationAction = SCNAction.customAction(duration: duration) { _, elapsedTime in
			for (index, matchedAnimation) in matchedAnimations.enumerated() {
				let elapsedTime = TimeInterval(elapsedTime)
				if transitionDuration > 0,
				   !`repeat`,
				   elapsedTime < transitionDuration,
				   startPoses.indices.contains(index) {
					matchedAnimation.animation.blend(
						from: startPoses[index],
						elapsedTime: elapsedTime,
						transitionDuration: transitionDuration,
						to: matchedAnimation.node
					)
				} else {
					matchedAnimation.animation.apply(
						elapsedTime: elapsedTime,
						to: matchedAnimation.node
					)
				}
			}
		}
		if `repeat` {
			if transitionDuration > 0 {
				let transitionAction = SCNAction.customAction(duration: transitionDuration) { _, elapsedTime in
					for (index, matchedAnimation) in matchedAnimations.enumerated() where startPoses.indices.contains(index) {
						matchedAnimation.animation.blend(
							from: startPoses[index],
							toElapsedTime: 0,
							transitionElapsedTime: TimeInterval(elapsedTime),
							transitionDuration: transitionDuration,
							to: matchedAnimation.node
						)
					}
				}
				node.runAction(
					SCNAction.sequence([transitionAction, SCNAction.repeatForever(animationAction)]),
					forKey: animationKey
				)
			} else {
				node.runAction(SCNAction.repeatForever(animationAction), forKey: animationKey)
			}
		} else {
			node.runAction(animationAction, forKey: animationKey)
		}
	} else {
		for matchedAnimation in matchedAnimations {
			matchedAnimation.animation.applyInitialPose(to: matchedAnimation.node)
		}
//		if name == "anims/walk1.5ds" { print(node?.name); print("animationKeys:", node?.animationKeys) }
	}
	if matchedAnimations.isEmpty {
		print("Animation target missing: \(name) root=\(node.name ?? "unnamed") tracks=\(animations.count)")
	}
	node.runAction(SCNAction.wait(duration: duration), completionHandler: completionHandler)
//	if name == "anims/walk1.5ds" { print("===============") }
}

func animationMatchCount(named name: String, in node: SCNNode) throws -> Int {
	let (animations, _) = try loadAnimation(named: name)
	return animations.reduce(0) { count, animation in
		count + (animationTargetNode(named: animation.name, in: node) == nil ? 0 : 1)
	}
}

func stopAnimation(named name: String, in node: SCNNode, animationKey: String) throws {
//	if name == "anims/walk1.5ds" { print("===============") }
//	if name == "anims/walk1.5ds" { print("stopAnimation") }
	node.removeAction(forKey: animationKey)
	let (animations, _) = try loadAnimation(named: name)
	for animation in animations {
		let node = animationTargetNode(named: animation.name, in: node)
//		if name == "anims/walk1.5ds" { print(node?.name); print("actionKeys:", node?.actionKeys) }
		node?.removeAction(forKey: animationKey)
	}
//	if name == "anims/walk1.5ds" { print("===============") }
}

private func animationTargetNode(named name: String, in rootNode: SCNNode) -> SCNNode? {
	let key = name.lowercased()
	let rootIdentifier = ObjectIdentifier(rootNode)

	animationTargetCacheLock.lock()
	if let cachedNode = animationTargetCache[rootIdentifier]?[key]?.node {
		animationTargetCacheLock.unlock()
		if animationTargetNode(cachedNode, isInHierarchyOf: rootNode) {
			return cachedNode
		}
	} else {
		animationTargetCacheLock.unlock()
	}

	let targetNode: SCNNode?
	if rootNode.name?.lowercased() == key {
		targetNode = rootNode
	} else {
		targetNode = rootNode.mafiaChildNode(named: name, recursively: true)
	}

	if let targetNode = targetNode {
		animationTargetCacheLock.lock()
		var rootCache = animationTargetCache[rootIdentifier] ?? [:]
		rootCache[key] = WeakNode(targetNode)
		animationTargetCache[rootIdentifier] = rootCache
		animationTargetCacheLock.unlock()
	}

	return targetNode
}

private func animationTargetNode(_ node: SCNNode, isInHierarchyOf rootNode: SCNNode) -> Bool {
	var currentNode: SCNNode? = node
	while let checkedNode = currentNode {
		if checkedNode === rootNode {
			return true
		}
		currentNode = checkedNode.parent
	}
	return false
}

func clearAnimationTargetCache(for rootNode: SCNNode) {
	animationTargetCacheLock.lock()
	animationTargetCache.removeValue(forKey: ObjectIdentifier(rootNode))
	animationTargetCacheLock.unlock()
}

func clearAnimationTargetCache() {
	animationTargetCacheLock.lock()
	animationTargetCache.removeAll()
	animationTargetCacheLock.unlock()
}
