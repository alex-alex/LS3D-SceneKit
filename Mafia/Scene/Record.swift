//
//  Record.swift
//  Mafia
//
//  Created by Alex Studnička on 10/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

private let recordCameraRollScale: Float = 0.1
private let recordCameraMaximumRoll: Float = .pi / 18

struct RecordAnimation {
	let id: Int
	let name: String
}

struct RecordModelBinding {
	let sourceName: String
	let targetName: String
	let extraName: String
}

struct RecordCameraKeyframe {
	let time: TimeInterval
	let position: SCNVector3
	let eulerAngles: SCNVector3
	let fieldOfView: CGFloat?
	let controlPoint1: RecordCameraControlPoint?
	let controlPoint2: RecordCameraControlPoint?
}

struct RecordCameraControlPoint {
	let position: SCNVector3
	let eulerAngles: SCNVector3
	let fieldOfView: CGFloat?
}

struct RecordTimedEvent {
	let time: TimeInterval
	let name: String
	let isStop: Bool
}

struct RecordSpeechEvent {
	let time: TimeInterval
	let soundId: Int

	var fileName: String {
		return String(format: "%08d.wav", soundId)
	}
}

struct RecordAnimationEvent {
	let animationId: Int
	let trackId: Int
	let time: TimeInterval
	let packedTrackId: UInt32
	let interpolationKind: UInt32
	let position: SCNVector3
	let orientationVector: SCNVector3
}

struct RecordTargetLink {
	let groupId: Int
	let role: Int
	let name: String
}

final class Record {

	enum Error: Swift.Error {
		case file
	}

	let name: String
	let animations: [RecordAnimation]
	let modelBindings: [RecordModelBinding]
	let cameraKeyframes: [RecordCameraKeyframe]
	let timedEvents: [RecordTimedEvent]
	let speechEvents: [RecordSpeechEvent]
	let animationEvents: [RecordAnimationEvent]
	let targetLinks: [RecordTargetLink]
	let frameCount: Int
	let payloadOffset: Int

	convenience init(name: String) throws {
		let lowercasedName = name.lowercased()
		let fileName = lowercasedName.hasSuffix(".rep") ? lowercasedName : lowercasedName + ".rep"
		let url = mainDirectory.appendingPathComponent("records/" + fileName)
		try self.init(url: url)
	}

	init(url: URL) throws {
		guard let stream = InputStream(url: url) else { throw Error.file }
		stream.open()
		defer { stream.close() }

		name = url.deletingPathExtension().lastPathComponent

		var header: [UInt32] = []
		for _ in 0 ..< 9 {
			let value: UInt32 = try stream.read()
			header.append(value)
		}

		frameCount = Int(header[0])

		stream.currentOffset = 12
		let modelsCount = header[3]

		stream.currentOffset = 96
		let animationNamesCount: UInt32 = try stream.read()
		stream.currentOffset += 4

		var loadedAnimations: [RecordAnimation] = []
		for _ in 0 ..< animationNamesCount {
			let rawId: UInt32 = try stream.read()
			let animationName: String = try stream.read(maxLength: 48, encoding: .windowsCP1250)
			loadedAnimations.append(RecordAnimation(id: Int(rawId), name: animationName))
		}

		var loadedModelBindings: [RecordModelBinding] = []
		for _ in 0 ..< modelsCount {
			let sourceName: String = try stream.read(maxLength: 36, encoding: .windowsCP1250)
			let targetName: String = try stream.read(maxLength: 36, encoding: .windowsCP1250)
			let extraName: String = try stream.read(maxLength: 36, encoding: .windowsCP1250)
			loadedModelBindings.append(RecordModelBinding(
				sourceName: sourceName,
				targetName: targetName,
				extraName: extraName
			))
		}

		animations = loadedAnimations
		modelBindings = loadedModelBindings
		payloadOffset = stream.currentOffset
		cameraKeyframes = Record.readCameraKeyframes(
			url: url,
			offset: payloadOffset + Int(header[2])
		)
		animationEvents = Record.readAnimationEvents(
			url: url,
			offset: payloadOffset,
			endOffset: payloadOffset + Int(header[2]),
			animationCount: loadedAnimations.count
		)
		targetLinks = Record.readTargetLinks(url: url, finalBlockSize: Int(header[8]))
		timedEvents = Record.readTimedEvents(url: url)
		speechEvents = Record.readSpeechEvents(url: url)
	}

	private static func readCameraKeyframes(url: URL, offset: Int) -> [RecordCameraKeyframe] {
		guard let data = try? Data(contentsOf: url),
			  offset >= 0,
			  offset < data.count else {
			return []
		}

		var keyframes: [RecordCameraKeyframe] = []
		var pendingControlPoint1: RecordCameraControlPoint?
		var pendingControlPoint2: RecordCameraControlPoint?
		let recordSize = 64
		var currentOffset = offset
		while data.hasCameraRecord(at: currentOffset) {
			let kind = data.readUInt32(at: currentOffset + 8)
			switch kind {
			case 1:
				let time = data.readUInt32(at: currentOffset)
				let x = data.readFloat(at: currentOffset + 12)
				let y = data.readFloat(at: currentOffset + 16)
				let z = data.readFloat(at: currentOffset + 20)
				let yaw = data.readFloat(at: currentOffset + 24)
				let pitch = data.readFloat(at: currentOffset + 28)
				let roll = data.readFloat(at: currentOffset + 32)
				let fov = data.readFloat(at: currentOffset + 52)
				if [x, y, z, yaw, pitch, roll].allSatisfy({ $0.isFinite }) {
					keyframes.append(RecordCameraKeyframe(
						time: TimeInterval(time) / 1000.0,
						position: SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z)),
						eulerAngles: recordCameraEulerAngles(yaw: yaw, pitch: pitch, roll: roll),
						fieldOfView: data.recordCameraFieldOfView(from: fov),
						controlPoint1: pendingControlPoint1,
						controlPoint2: pendingControlPoint2
					))
				}
				pendingControlPoint1 = nil
				pendingControlPoint2 = nil

			case 2:
				pendingControlPoint1 = nil
				pendingControlPoint2 = nil

			case 4:
				pendingControlPoint1 = data.readCameraControlPoint(at: currentOffset)

			case 8:
				pendingControlPoint2 = data.readCameraControlPoint(at: currentOffset)

			default:
				break
			}
			currentOffset += recordSize
		}
		return keyframes
	}

	private static func readTimedEvents(url: URL) -> [RecordTimedEvent] {
		guard let data = try? Data(contentsOf: url) else { return [] }
		guard data.count >= 40 else { return [] }

		var acceptedOffsets = Set<Int>()
		var events: [RecordTimedEvent] = []

		for startOffset in stride(from: 0, through: data.count - 40, by: 4) {
			var run: [(offset: Int, event: RecordTimedEvent)] = []
			var currentOffset = startOffset
			while currentOffset + 40 <= data.count,
				  let event = data.readTimedEvent(at: currentOffset) {
				run.append((currentOffset, event))
				currentOffset += 40
			}

			guard run.count >= 5 else { continue }
			for (offset, event) in run where !acceptedOffsets.contains(offset) {
				acceptedOffsets.insert(offset)
				events.append(event)
			}
		}

		return events.sorted { $0.time < $1.time }
	}

	private static func readAnimationEvents(
		url: URL,
		offset: Int,
		endOffset: Int,
		animationCount: Int
	) -> [RecordAnimationEvent] {
		guard animationCount > 0,
			  let data = try? Data(contentsOf: url),
			  offset >= 0,
			  endOffset <= data.count,
			  offset + 36 <= endOffset else {
			return []
		}

		let trackStarts = data.readAnimationTrackStarts(offset: offset, endOffset: endOffset)
		var events: [(offset: Int, event: RecordAnimationEvent)] = []
		for currentOffset in stride(from: offset, through: endOffset - 36, by: 4) {
			guard let event = data.readAnimationEvent(
				at: currentOffset,
				animationCount: animationCount
			) else {
				continue
			}
			events.append((currentOffset, event))
			if let chainedEvent = data.readChainedAnimationEvent(
				at: currentOffset + 40,
				from: event,
				animationCount: animationCount
			) {
				events.append((currentOffset + 40, chainedEvent))
			}
		}
		for currentOffset in stride(from: offset, through: endOffset - 44, by: 4) {
			guard let event = data.readExtendedAnimationEvent(
				at: currentOffset,
				animationCount: animationCount
			) else {
				continue
			}
			events.append((currentOffset, event))
			if let chainedEvent = data.readChainedAnimationEvent(
				at: currentOffset + 44,
				from: event,
				animationCount: animationCount
			) {
				events.append((currentOffset + 44, chainedEvent))
			}
		}
		let eventOffsets = Set(events.map(\.offset))
		for trackStart in trackStarts {
			guard let event = data.readTrackStartAnimationEvent(
				at: trackStart,
				animationCount: animationCount
			),
				  !eventOffsets.contains(trackStart + 44) else {
				continue
			}
			events.append((trackStart + 44, event))
		}

		return events.map { offset, event in
			let trackId = trackStarts.lastIndex { $0 <= offset } ?? -1
			return RecordAnimationEvent(
				animationId: event.animationId,
				trackId: trackId,
				time: event.time,
				packedTrackId: event.packedTrackId,
				interpolationKind: event.interpolationKind,
				position: event.position,
				orientationVector: event.orientationVector
			)
		}.sorted {
			if $0.animationId == $1.animationId {
				return $0.time < $1.time
			}
			return $0.animationId < $1.animationId
		}
	}

	private static func readTargetLinks(url: URL, finalBlockSize: Int) -> [RecordTargetLink] {
		guard finalBlockSize > 4,
			  let data = try? Data(contentsOf: url),
			  finalBlockSize <= data.count else {
			return []
		}

		let offset = data.count - finalBlockSize
		let entryCount = Int(data.readUInt32(at: offset))
		guard entryCount > 0,
			  offset + 4 + entryCount * 36 <= data.count else {
			return []
		}

		var links: [RecordTargetLink] = []
		for index in 0 ..< entryCount {
			let entryOffset = offset + 4 + index * 36
			let timeOrMarker = data.readUInt32(at: entryOffset + 8)
			let groupId = Int(data.readUInt32(at: entryOffset + 12))
			let role = Int(Int32(bitPattern: data.readUInt32(at: entryOffset + 16)))
			guard timeOrMarker == 0,
				  role == 1 || role == -3,
				  let name = data.readTargetLinkName(
					at: entryOffset,
					entryIndex: index,
					entryCount: entryCount
				  ),
				  !name.isEmpty else {
				continue
			}
			links.append(RecordTargetLink(groupId: groupId, role: role, name: name))
		}
		return links
	}

	private static func readSpeechEvents(url: URL) -> [RecordSpeechEvent] {
		guard let data = try? Data(contentsOf: url) else { return [] }
		guard data.count >= 36 else { return [] }

		let entrySize = 36
		var acceptedOffsets = Set<Int>()
		var events: [RecordSpeechEvent] = []

		for startOffset in stride(from: 0, through: data.count - entrySize, by: 4) {
			var run: [(offset: Int, event: RecordSpeechEvent)] = []
			var currentOffset = startOffset
			while currentOffset + entrySize <= data.count,
				  let event = data.readSpeechEvent(at: currentOffset) {
				run.append((currentOffset, event))
				currentOffset += entrySize
			}

			guard run.count >= 3 else { continue }
			for (offset, event) in run where !acceptedOffsets.contains(offset) {
				acceptedOffsets.insert(offset)
				events.append(event)
			}
		}

		return events.sorted { $0.time < $1.time }
	}

}

private extension Data {
	func readUInt32(at offset: Int) -> UInt32 {
		return UInt32(self[offset]) |
			UInt32(self[offset + 1]) << 8 |
			UInt32(self[offset + 2]) << 16 |
			UInt32(self[offset + 3]) << 24
	}

	func readFloat(at offset: Int) -> Float {
		return Float(bitPattern: readUInt32(at: offset))
	}

	func hasCameraRecord(at offset: Int) -> Bool {
		guard offset >= 0, offset + 64 <= count else { return false }

		let time = readUInt32(at: offset)
		let repeatedTime = readUInt32(at: offset + 4)
		let kind = readUInt32(at: offset + 8)
		guard time <= 200_000,
			  repeatedTime <= 200_000,
			  [1, 2, 4, 8].contains(kind) else {
			return false
		}

		if kind == 2 {
			return true
		}

		let x = readFloat(at: offset + 12)
		let y = readFloat(at: offset + 16)
		let z = readFloat(at: offset + 20)
		let yaw = readFloat(at: offset + 24)
		let pitch = readFloat(at: offset + 28)
		let roll = readFloat(at: offset + 32)
		let fieldOfView = readFloat(at: offset + 52)
		guard [x, y, z, yaw, pitch, roll, fieldOfView].allSatisfy({ $0.isFinite }) else {
			return false
		}

		return abs(x) < 100_000 &&
			abs(y) < 100_000 &&
			abs(z) < 100_000 &&
			fieldOfView >= 0 &&
			fieldOfView <= .pi * 1.5
	}

	func readCameraControlPoint(at offset: Int) -> RecordCameraControlPoint? {
		let x = readFloat(at: offset + 12)
		let y = readFloat(at: offset + 16)
		let z = readFloat(at: offset + 20)
		let yaw = readFloat(at: offset + 24)
		let pitch = readFloat(at: offset + 28)
		let roll = readFloat(at: offset + 32)
		let fov = readFloat(at: offset + 52)

		guard [x, y, z, yaw, pitch, roll].allSatisfy({ $0.isFinite }) else { return nil }

		return RecordCameraControlPoint(
			position: SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z)),
			eulerAngles: recordCameraEulerAngles(yaw: yaw, pitch: pitch, roll: roll),
			fieldOfView: recordCameraFieldOfView(from: fov)
		)
	}

	func recordCameraFieldOfView(from rawValue: Float) -> CGFloat? {
		guard rawValue.isFinite, rawValue > 0 else { return nil }
		return CGFloat(Double(rawValue) * 180.0 / Double.pi)
	}

	func readTimedEvent(at offset: Int) -> RecordTimedEvent? {
		let time = readUInt32(at: offset)
		guard time <= 3_600_000 else { return nil }

		let nameData = self[(offset + 4) ..< (offset + 40)]
		let marker = readUInt32(at: offset + 4)
		if marker == 1 {
			guard let name = nameData.dropFirst(4).recordEventName else { return nil }
			return RecordTimedEvent(time: TimeInterval(time) / 1000.0, name: name, isStop: true)
		}

		guard let name = nameData.recordEventName else { return nil }
		return RecordTimedEvent(time: TimeInterval(time) / 1000.0, name: name, isStop: false)
	}

	func readAnimationTrackStarts(offset: Int, endOffset: Int) -> [Int] {
		guard offset >= 0,
			  endOffset <= count,
			  offset + 40 <= endOffset else {
			return []
		}

		var starts: [Int] = []
		for currentOffset in stride(from: offset, through: endOffset - 40, by: 4) {
			if hasAnimationTrackStart(at: currentOffset, positionOffset: 12) ||
				hasAnimationTrackStart(at: currentOffset, positionOffset: 16) {
				if let previousStart = starts.last, currentOffset == previousStart + 4 {
					continue
				}
				starts.append(currentOffset)
			}
		}
		return starts
	}

	func readTrackStartAnimationEvent(at offset: Int, animationCount: Int) -> RecordAnimationEvent? {
		guard let positionOffset = animationTrackStartPositionOffset(at: offset),
			  offset + 48 <= count else {
			return nil
		}

		let markerOffset = offset + 44
		let packedTrackId = readUInt32(at: markerOffset)
		guard isRecordAnimationPackedId(packedTrackId, animationCount: animationCount),
			  readAnimationEvent(at: markerOffset, animationCount: animationCount) == nil,
			  readExtendedAnimationEvent(at: markerOffset, animationCount: animationCount) == nil else {
			return nil
		}

		let animationId = Int(packedTrackId & 0xff)
		let position = SCNVector3(
			x: SCNFloat(readFloat(at: offset + positionOffset)),
			y: SCNFloat(readFloat(at: offset + positionOffset + 4)),
			z: SCNFloat(readFloat(at: offset + positionOffset + 8))
		)
		let orientationVector = SCNVector3(
			x: SCNFloat(readFloat(at: offset + positionOffset + 12)),
			y: SCNFloat(readFloat(at: offset + positionOffset + 16)),
			z: SCNFloat(readFloat(at: offset + positionOffset + 20))
		)

		return RecordAnimationEvent(
			animationId: animationId,
			trackId: -1,
			time: 0,
			packedTrackId: packedTrackId,
			interpolationKind: 1,
			position: position,
			orientationVector: orientationVector
		)
	}

	func animationTrackStartPositionOffset(at offset: Int) -> Int? {
		if hasAnimationTrackStart(at: offset, positionOffset: 12) {
			return 12
		}
		if hasAnimationTrackStart(at: offset, positionOffset: 16) {
			return 16
		}
		return nil
	}

	func hasAnimationTrackStart(at offset: Int, positionOffset: Int) -> Bool {
		guard offset >= 0,
			  offset + positionOffset + 24 <= count else {
			return false
		}

		if positionOffset == 12 {
			guard readUInt32(at: offset) == 0,
				  readUInt32(at: offset + 4) == 0,
				  readUInt32(at: offset + 8) == 1 else {
				return false
			}
		} else {
			guard readUInt32(at: offset) == 0,
				  readUInt32(at: offset + 4) == 0,
				  readUInt32(at: offset + 8) == 0,
				  readUInt32(at: offset + 12) == 1 else {
				return false
			}
		}

		let values = [
			readFloat(at: offset + positionOffset),
			readFloat(at: offset + positionOffset + 4),
			readFloat(at: offset + positionOffset + 8),
			readFloat(at: offset + positionOffset + 12),
			readFloat(at: offset + positionOffset + 16),
			readFloat(at: offset + positionOffset + 20)
		]
		guard values.allSatisfy({ $0.isFinite && abs($0) < 100_000 }) else {
			return false
		}
		let position = SCNVector3(
			x: SCNFloat(values[0]),
			y: SCNFloat(values[1]),
			z: SCNFloat(values[2])
		)
		return vectorLength(position) > 0.001
	}

	func readAnimationEvent(at offset: Int, animationCount: Int) -> RecordAnimationEvent? {
		let packedTrackId = readUInt32(at: offset)
		let time = readUInt32(at: offset + 4)
		let interpolationKind = readUInt32(at: offset + 8)
		guard packedTrackId > 0,
			  packedTrackId <= 0xffff,
			  time <= 3_600_000,
			  interpolationKind == 1 || interpolationKind == 2 else {
			return nil
		}

		let animationId = Int(packedTrackId & 0xff)
		guard animationId < animationCount else { return nil }

		let values = [
			readFloat(at: offset + 12),
			readFloat(at: offset + 16),
			readFloat(at: offset + 20),
			readFloat(at: offset + 24),
			readFloat(at: offset + 28),
			readFloat(at: offset + 32)
		]
		guard values.allSatisfy({ $0.isFinite && abs($0) < 100_000 }) else {
			return nil
		}
		let position = SCNVector3(
			x: SCNFloat(values[0]),
			y: SCNFloat(values[1]),
			z: SCNFloat(values[2])
		)
		let orientationVector = SCNVector3(
			x: SCNFloat(values[3]),
			y: SCNFloat(values[4]),
			z: SCNFloat(values[5])
		)
		guard vectorLength(position) > 0.001 || vectorLength(orientationVector) > 0.001 else {
			return nil
		}

		return RecordAnimationEvent(
			animationId: animationId,
			trackId: -1,
			time: TimeInterval(time) / 1000.0,
			packedTrackId: packedTrackId,
			interpolationKind: interpolationKind,
			position: position,
			orientationVector: orientationVector
		)
	}

	func readExtendedAnimationEvent(at offset: Int, animationCount: Int) -> RecordAnimationEvent? {
		let packedTrackId = readUInt32(at: offset)
		let secondaryTrackId = readUInt32(at: offset + 4)
		let time = readUInt32(at: offset + 8)
		let interpolationKind = readUInt32(at: offset + 12)
		guard packedTrackId > 0,
			  packedTrackId <= 0xffff,
			  secondaryTrackId > 0,
			  (secondaryTrackId <= 0xffff || (secondaryTrackId & 0xffffff00) == 0xcdcdc000),
			  time <= 3_600_000,
			  interpolationKind == 1 || interpolationKind == 2 else {
			return nil
		}
		guard readAnimationEvent(at: offset + 4, animationCount: animationCount) == nil else {
			return nil
		}

		let animationId = Int(packedTrackId & 0xff)
		guard animationId < animationCount else { return nil }

		let values = [
			readFloat(at: offset + 16),
			readFloat(at: offset + 20),
			readFloat(at: offset + 24),
			readFloat(at: offset + 28),
			readFloat(at: offset + 32),
			readFloat(at: offset + 36)
		]
		guard values.allSatisfy({ $0.isFinite && abs($0) < 100_000 }) else {
			return nil
		}
		let position = SCNVector3(
			x: SCNFloat(values[0]),
			y: SCNFloat(values[1]),
			z: SCNFloat(values[2])
		)
		let orientationVector = SCNVector3(
			x: SCNFloat(values[3]),
			y: SCNFloat(values[4]),
			z: SCNFloat(values[5])
		)
		guard vectorLength(position) > 0.001 || vectorLength(orientationVector) > 0.001 else {
			return nil
		}

		return RecordAnimationEvent(
			animationId: animationId,
			trackId: -1,
			time: TimeInterval(time) / 1000.0,
			packedTrackId: packedTrackId,
			interpolationKind: interpolationKind,
			position: position,
			orientationVector: orientationVector
		)
	}

	func readChainedAnimationEvent(
		at offset: Int,
		from baseEvent: RecordAnimationEvent,
		animationCount: Int
	) -> RecordAnimationEvent? {
		guard offset >= 0,
			  offset + 4 <= count else {
			return nil
		}

		guard readAnimationEvent(at: offset, animationCount: animationCount) == nil,
			  readExtendedAnimationEvent(at: offset, animationCount: animationCount) == nil else {
			return nil
		}

		let packedTrackId = readUInt32(at: offset)
		guard isRecordAnimationPackedId(packedTrackId, animationCount: animationCount) else {
			return nil
		}

		let animationId = Int(packedTrackId & 0xff)
		guard animationId != 0,
			  animationId != baseEvent.animationId else {
			return nil
		}

		return RecordAnimationEvent(
			animationId: animationId,
			trackId: -1,
			time: baseEvent.time,
			packedTrackId: packedTrackId,
			interpolationKind: baseEvent.interpolationKind,
			position: baseEvent.position,
			orientationVector: baseEvent.orientationVector
		)
	}

	func isRecordAnimationPackedId(_ packedTrackId: UInt32, animationCount: Int) -> Bool {
		guard packedTrackId > 0 else { return false }
		let animationId = Int(packedTrackId & 0xff)
		guard animationId < animationCount else { return false }

		let highBits = packedTrackId & 0xffffff00
		if highBits == 0x00000400 ||
			highBits == 0x00002400 ||
			highBits == 0x00004400 ||
			highBits == 0x00008400 ||
			highBits == 0x0000a400 ||
			highBits == 0x0000c400 ||
			highBits == 0xcdcdc000 {
			return true
		}

		return false
	}

	func readSpeechEvent(at offset: Int) -> RecordSpeechEvent? {
		let time = readUInt32(at: offset)
		let marker = readUInt32(at: offset + 4)
		let soundId = readUInt32(at: offset + 8)

		guard time <= 3_600_000,
			  marker <= 1,
			  soundId >= 1_000_000,
			  soundId <= 99_999_999 else {
			return nil
		}

		let fileName = String(format: "%08d.wav", Int(soundId))
		let url = mainDirectory.appendingPathComponent("sounds/" + fileName)
		guard FileManager.default.fileExists(atPath: url.path) else {
			return nil
		}

		return RecordSpeechEvent(
			time: TimeInterval(time) / 1000.0,
			soundId: Int(soundId)
		)
	}

	func readTargetLinkName(at offset: Int, entryIndex: Int, entryCount: Int) -> String? {
		var bytes = Array(self[(offset + 20) ..< (offset + 36)])
		if !bytes.contains(0), entryIndex + 1 < entryCount {
			let nextOffset = offset + 36
			let nextTimeOrMarker = readUInt32(at: nextOffset + 8)
			let nextRole = Int(Int32(bitPattern: readUInt32(at: nextOffset + 16)))
			if nextTimeOrMarker == 0, nextRole == 0 {
				for byte in self[nextOffset ..< Swift.min(nextOffset + 4, count)] {
					guard byte >= 0x20, byte != 0xcd else { break }
					bytes.append(byte)
				}
			}
		}
		return bytes.recordFixedString
	}
}

private func recordCameraEulerAngles(yaw: Float, pitch: Float, roll: Float) -> SCNVector3 {
	return SCNVector3(
		x: SCNFloat(pitch),
		y: SCNFloat(yaw),
		z: SCNFloat(recordCameraRoll(from: roll))
	)
}

private func recordCameraRoll(from rawRoll: Float) -> Float {
	guard rawRoll.isFinite else { return 0 }
	let scaledRoll = rawRoll * recordCameraRollScale
	return Swift.max(-recordCameraMaximumRoll, Swift.min(recordCameraMaximumRoll, scaledRoll))
}

private func vectorLength(_ vector: SCNVector3) -> SCNFloat {
	return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

private extension Data.SubSequence {
	var recordFixedString: String? {
		return Array(self).recordFixedString
	}

	var recordEventName: String? {
		var bytes = Array(self)
		while let last = bytes.last, last == 0 || last == 0xcd {
			bytes.removeLast()
		}
		while let first = bytes.first, first == 0 || first == 0xcd {
			bytes.removeFirst()
		}
		guard bytes.count >= 3 else { return nil }
		guard bytes.allSatisfy({ byte in
			byte >= 0x20
		}) else {
			return nil
		}

		let name = String(bytes: bytes, encoding: .windowsCP1250)?
			.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let name = name, name.count >= 3 else { return nil }
		return name
	}
}

private extension Array where Element == UInt8 {
	var recordFixedString: String? {
		var bytes = self
		while let last = bytes.last, last == 0 || last == 0xcd {
			bytes.removeLast()
		}
		guard !bytes.isEmpty,
			  bytes.allSatisfy({ $0 >= 0x20 }) else {
			return nil
		}

		return String(bytes: bytes, encoding: .windowsCP1250)?
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
