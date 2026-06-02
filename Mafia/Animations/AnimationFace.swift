//
//  AnimationFace.swift
//  Mafia
//
//  Created by Alex Studnička on 17/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

// /tables/dat/*.dat

/*
-------------------------------------------------- ----------
variable type description
-------------------------------------------------- ----------
recCount long number of frames describing animation elements
unknown 4 byte constant 01 00 00 00
record1 8 byte first frame
	...
recordN 8 byte and last
-------------------------------------------------- ----------
		
recordX - frame describes the position of the lips, eyebrows, eyes
-------------------------------------------------- ----------
variable type description
-------------------------------------------------- ----------
wideMouth byte pulls his lips into a tube.  From the 00-lip in a line, to the FF-duckface.
openMouth byte mouth opening width.  00-says clenched teeth .. FF-mouth does not close.
lipsConers byte corners of the lips.  00-raised .. FF-lowered
eyelid byte movement of the upper eyelid.  00-raised .. FF-lowered
openEye byte size of eyes.  00-closed .. FF-very large
eyebrow byte raises his eyebrows.  00-very high .. FF-does not raise.
unknown 2 byte Constant 01 01
-------------------------------------------------- ----------
*/

struct FaceAnimationFrame {
	let wideMouth: UInt8
	let openMouth: UInt8
	let lipsCorners: UInt8
	let eyelid: UInt8
	let openEye: UInt8
	let eyebrow: UInt8

	var weights: [CGFloat] {
		return [
			CGFloat(openMouth) / 255.0,
			CGFloat(wideMouth) / 255.0,
			CGFloat(lipsCorners) / 255.0,
		]
	}
}

struct FaceAnimation {
	let frames: [FaceAnimationFrame]

	var duration: TimeInterval {
		return TimeInterval(frames.count) / 25.0
	}

	func weights(at elapsedTime: TimeInterval, duration: TimeInterval) -> [CGFloat] {
		let frameWeights = frames.map(\.weights)
		guard let firstWeights = frameWeights.first else { return [] }

		let neutralWeights = Array(repeating: CGFloat(0), count: firstWeights.count)
		let samples = [neutralWeights] + frameWeights + [neutralWeights]
		let progress = max(0, min(1, elapsedTime / duration))
		let samplePosition = progress * TimeInterval(samples.count - 1)
		let sampleIndex = min(samples.count - 2, Int(samplePosition))
		let blend = CGFloat(samplePosition - TimeInterval(sampleIndex))

		return interpolatedFaceWeights(
			from: samples[sampleIndex],
			to: samples[sampleIndex + 1],
			blend: blend
		)
	}
}

private func interpolatedFaceWeights(from startWeights: [CGFloat], to endWeights: [CGFloat], blend: CGFloat) -> [CGFloat] {
	let count = min(startWeights.count, endWeights.count)
	return (0 ..< count).map { index in
		startWeights[index] + (endWeights[index] - startWeights[index]) * blend
	}
}

private let loadedFaceAnimationsLock = NSLock()
private var loadedFaceAnimationsByName: [String: FaceAnimation] = [:]

func loadFaceAnimation(named name: String) throws -> FaceAnimation {
	let key = name.lowercased()
	loadedFaceAnimationsLock.lock()
	if let cachedAnimation = loadedFaceAnimationsByName[key] {
		loadedFaceAnimationsLock.unlock()
		return cachedAnimation
	}
	loadedFaceAnimationsLock.unlock()

	guard let url = faceAnimationURL(named: name),
		  let stream = InputStream(url: url) else {
		throw AnimationError.file
	}
	stream.open()
	defer { stream.close() }

	let frameCount: UInt32 = try stream.read()
	let _: UInt32 = try stream.read()
	var frames: [FaceAnimationFrame] = []
	frames.reserveCapacity(Int(frameCount))
	for _ in 0 ..< frameCount {
		let wideMouth: UInt8 = try stream.read()
		let openMouth: UInt8 = try stream.read()
		let lipsCorners: UInt8 = try stream.read()
		let eyelid: UInt8 = try stream.read()
		let openEye: UInt8 = try stream.read()
		let eyebrow: UInt8 = try stream.read()
		let _: UInt8 = try stream.read()
		let _: UInt8 = try stream.read()
		frames.append(FaceAnimationFrame(
			wideMouth: wideMouth,
			openMouth: openMouth,
			lipsCorners: lipsCorners,
			eyelid: eyelid,
			openEye: openEye,
			eyebrow: eyebrow
		))
	}

	let animation = FaceAnimation(frames: frames)
	loadedFaceAnimationsLock.lock()
	loadedFaceAnimationsByName[key] = animation
	loadedFaceAnimationsLock.unlock()
	return animation
}

func playFaceAnimation(
	named name: String,
	in node: SCNNode,
	duration requestedDuration: TimeInterval? = nil,
	animationKey: String = "__face__"
) throws {
	let animation = try loadFaceAnimation(named: name)
	guard !animation.frames.isEmpty else { return }
	guard let morphNode = node.skinnedMorpherNode else { return }
	morphNode.morpher?.calculationMode = .normalized

	let duration = max(requestedDuration ?? animation.duration, 1.0 / 25.0)
	let action = SCNAction.customAction(duration: duration) { _, elapsedTime in
		morphNode.setFaceMorphWeights(
			animation.weights(
				at: TimeInterval(elapsedTime),
				duration: duration
			)
		)
	}
	let reset = SCNAction.run { _ in
		morphNode.resetFaceMorphWeights()
	}

	morphNode.removeAction(forKey: animationKey)
	morphNode.runAction(SCNAction.sequence([action, reset]), forKey: animationKey)
}

func playFaceAnimation(
	soundId: Int,
	in node: SCNNode,
	duration: TimeInterval? = nil,
	animationKey: String = "__face__"
) throws {
	try playFaceAnimation(
		named: String(format: "%08d.dat", soundId),
		in: node,
		duration: duration,
		animationKey: animationKey
	)
}

func playFaceAnimation(
	soundName: String,
	in node: SCNNode,
	duration: TimeInterval? = nil,
	animationKey: String = "__face__"
) throws {
	let baseName = (soundName as NSString).deletingPathExtension
	let candidates = faceAnimationNameCandidates(for: baseName)
	var lastError: Error = AnimationError.file
	for candidate in candidates {
		do {
			try playFaceAnimation(
				named: candidate,
				in: node,
				duration: duration,
				animationKey: animationKey
			)
			return
		} catch {
			lastError = error
		}
	}
	throw lastError
}

func hasFaceAnimation(soundId: Int) -> Bool {
	return faceAnimationURL(named: String(format: "%08d.dat", soundId)) != nil
}

func hasFaceAnimationTarget(in node: SCNNode) -> Bool {
	return node.skinnedMorpherNode != nil
}

private func faceAnimationURL(named name: String) -> URL? {
	return mafiaResourceURL(directory: "tables/dat", name: name)
}

private func faceAnimationNameCandidates(for baseName: String) -> [String] {
	var candidates = [baseName + ".dat"]
	if let soundId = Int(baseName) {
		candidates.append(String(format: "%08d.dat", soundId))
	}

	var seen = Set<String>()
	return candidates.filter { candidate in
		let key = candidate.lowercased()
		guard !seen.contains(key) else { return false }
		seen.insert(key)
		return true
	}
}

private extension SCNNode {
	var skinnedMorpherNode: SCNNode? {
		if let morpher = morpher,
		   !morpher.targets.isEmpty,
		   skinner != nil {
			return self
		}
		return childNodes.compactMap { $0.skinnedMorpherNode }.first
	}

	func setFaceMorphWeights(_ weights: [CGFloat]) {
		guard let morpher = morpher else { return }
		let targetCount = min(morpher.targets.count, weights.count)
		for index in 0 ..< targetCount {
			morpher.setWeight(weights[index], forTargetAt: index)
		}
		for index in targetCount ..< morpher.targets.count {
			morpher.setWeight(0, forTargetAt: index)
		}
	}

	func resetFaceMorphWeights() {
		guard let morpher = morpher else { return }
		for index in 0 ..< morpher.targets.count {
			morpher.setWeight(0, forTargetAt: index)
		}
	}
}
