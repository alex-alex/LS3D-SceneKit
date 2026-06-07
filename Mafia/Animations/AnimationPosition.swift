//
//  AnimationPosition.swift
//  Mafia
//
//  Created by Alex Studnička on 17/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

// /anims/*.tck

/*
-------------------------------------------------- ------------
variable type description
-------------------------------------------------- ------------
fileSgn long file signature, constant = 04 00 00 00
startPosX float initial X coordinate of the position of the object (?)
startPosY float Y
startPosZ float Z
endPosX float final X coordinate of the position of the object (?)
endPosY float Y
endPosZ float Z
time long animation duration in msec
frameTime long duration of one frame in msec
posCount long number of intermediate positions of the object
posDesc - block for describing the coordinates of the positions of the object
endSgn long end signature, constant = 00 00 00 00
-------------------------------------------------- ------------

posDesc - block for describing the coordinates of intermediate positions of the object
The following structure is repeated posCount times
-------------------------------------------------- ------------
variable type description
-------------------------------------------------- ------------
PosX float X coordinate of the position of the object
PosY float Y
PosZ float Z
-------------------------------------------------- ------------
*/

struct PositionAnimation {
	private static let defaultFrameDuration: TimeInterval = 1.0 / 25.0

	let name: String
	let startPosition: SCNVector3
	let endPosition: SCNVector3
	let duration: TimeInterval
	let frameDuration: TimeInterval
	let positions: [SCNVector3]

	func applyInitialPose(to node: SCNNode, relativeTo basePosition: SCNVector3) {
		guard let firstPosition = positions.first else { return }
		node.position = basePosition + firstPosition
	}

	func apply(elapsedTime: TimeInterval, to node: SCNNode, relativeTo basePosition: SCNVector3) {
		guard !positions.isEmpty else { return }
		guard positions.count > 1 else {
			node.position = basePosition + positions[0]
			return
		}

		let frameDuration = self.frameDuration > 0 ? self.frameDuration : Self.defaultFrameDuration
		let frame = elapsedTime / frameDuration
		let lowerIndex = max(0, min(positions.count - 1, Int(floor(frame))))
		let progress = SCNFloat(max(0, min(1, frame - Double(lowerIndex))))
		node.position = basePosition + interpolatedPosition(at: lowerIndex, progress: progress)
	}

	private func interpolatedPosition(at index: Int, progress: SCNFloat) -> SCNVector3 {
		let previous = positions[max(0, index - 1)]
		let current = positions[max(0, min(positions.count - 1, index))]
		let next = positions[max(0, min(positions.count - 1, index + 1))]
		let following = positions[max(0, min(positions.count - 1, index + 2))]
		return catmullRom(previous, current, next, following, progress)
	}

	private func catmullRom(
		_ previous: SCNVector3,
		_ current: SCNVector3,
		_ next: SCNVector3,
		_ following: SCNVector3,
		_ progress: SCNFloat
	) -> SCNVector3 {
		let progress2 = progress * progress
		let progress3 = progress2 * progress
		return SCNVector3(
			x: 0.5 * (
				2 * current.x +
				(-previous.x + next.x) * progress +
				(2 * previous.x - 5 * current.x + 4 * next.x - following.x) * progress2 +
				(-previous.x + 3 * current.x - 3 * next.x + following.x) * progress3
			),
			y: 0.5 * (
				2 * current.y +
				(-previous.y + next.y) * progress +
				(2 * previous.y - 5 * current.y + 4 * next.y - following.y) * progress2 +
				(-previous.y + 3 * current.y - 3 * next.y + following.y) * progress3
			),
			z: 0.5 * (
				2 * current.z +
				(-previous.z + next.z) * progress +
				(2 * previous.z - 5 * current.z + 4 * next.z - following.z) * progress2 +
				(-previous.z + 3 * current.z - 3 * next.z + following.z) * progress3
			)
		)
	}
}

private struct LoadedPositionAnimation {
	let animation: PositionAnimation
}

private let loadedPositionAnimationsLock = NSLock()
private var loadedPositionAnimationsByName: [String: LoadedPositionAnimation] = [:]

private func positionAnimationResourceURL(named name: String) -> URL? {
	let normalizedName = name.replacingOccurrences(of: "\\", with: "/")
	let components = normalizedName.split(separator: "/", maxSplits: 1).map(String.init)
	if components.count == 2, components[0].lowercased() == "anims" {
		return mafiaResourceURL(directory: "anims", name: components[1])
	}

	let directURL = mainDirectory.appendingPathComponent(normalizedName.lowercased())
	return FileManager.default.fileExists(atPath: directURL.path) ? directURL : nil
}

func loadPositionAnimation(named name: String) throws -> PositionAnimation {
	let key = name.lowercased()
	loadedPositionAnimationsLock.lock()
	if let cachedAnimation = loadedPositionAnimationsByName[key] {
		loadedPositionAnimationsLock.unlock()
		return cachedAnimation.animation
	}
	loadedPositionAnimationsLock.unlock()

	guard let url = positionAnimationResourceURL(named: name),
		  let stream = InputStream(url: url) else { throw AnimationError.file }
	stream.open()
	defer { stream.close() }

	let magic: UInt32 = try stream.read()
	guard magic == 4 else { throw AnimationError.file }

	let startPosition = try SCNVector3(stream: stream)
	let endPosition = try SCNVector3(stream: stream)
	let durationMilliseconds: UInt32 = try stream.read()
	let frameMilliseconds: UInt32 = try stream.read()
	let positionCount: UInt32 = try stream.read()

	var positions: [SCNVector3] = []
	positions.reserveCapacity(Int(positionCount))
	for _ in 0 ..< positionCount {
		positions.append(try SCNVector3(stream: stream))
	}

	if positions.isEmpty {
		positions = [startPosition, endPosition]
	}

	let animation = PositionAnimation(
		name: name,
		startPosition: startPosition,
		endPosition: endPosition,
		duration: TimeInterval(durationMilliseconds) / 1000.0,
		frameDuration: TimeInterval(frameMilliseconds) / 1000.0,
		positions: positions
	)

	loadedPositionAnimationsLock.lock()
	loadedPositionAnimationsByName[key] = LoadedPositionAnimation(animation: animation)
	loadedPositionAnimationsLock.unlock()
	return animation
}

func positionAnimationExists(named name: String) -> Bool {
	return positionAnimationResourceURL(named: name) != nil
}

func positionAnimationDuration(named name: String) throws -> TimeInterval {
	return try loadPositionAnimation(named: name).duration
}

func playPositionAnimation(
	named name: String,
	in node: SCNNode,
	repeat shouldRepeat: Bool = false,
	animationKey: String? = nil,
	completionHandler: (() -> Void)? = nil
) throws {
	let animation = try loadPositionAnimation(named: name)
	let duration = animation.duration > 0 ? animation.duration : animation.frameDuration * TimeInterval(animation.positions.count)
	guard duration > 0 else {
		animation.applyInitialPose(to: node, relativeTo: node.position)
		completionHandler?()
		return
	}

	let basePosition = node.presentation.position
	let animationAction = SCNAction.customAction(duration: duration) { node, elapsedTime in
		animation.apply(elapsedTime: TimeInterval(elapsedTime), to: node, relativeTo: basePosition)
	}
	if shouldRepeat {
		node.runAction(SCNAction.repeatForever(animationAction), forKey: animationKey)
	} else {
		node.runAction(animationAction, forKey: animationKey)
	}
	node.runAction(SCNAction.wait(duration: duration), completionHandler: completionHandler)
}
