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
private let recordCameraCutTimeEpsilon: TimeInterval = 0.005

struct RecordAnimation {
	let id: Int
	let name: String
}

struct RecordModelBinding {
	let sourceName: String
	let targetName: String
	let extraName: String
	let transformEvents: [RecordAnimationEvent]
}

private struct RecordModelBindingMetadata {
	let sourceName: String
	let targetName: String
	let chunkSizes: [Int]
	let durationMilliseconds: Int
	let sampleDataLength: Int
	let sampleDataOffset: Int
}

struct RecordCameraKeyframe {
	let time: TimeInterval
	let position: SCNVector3
	let focusPosition: SCNVector3
	let roll: SCNFloat
	let fieldOfView: CGFloat?
	let outgoingControlPoint: RecordCameraControlPoint?
	let incomingControlPoint: RecordCameraControlPoint?
	let hasCutMarker: Bool
}

struct RecordCameraControlPoint {
	let position: SCNVector3
	let focusPosition: SCNVector3
	let roll: SCNFloat
	let fieldOfView: CGFloat?
}

private struct RecordCameraChunk {
	let time: TimeInterval
	let kind: UInt32
	let position: SCNVector3
	let roll: SCNFloat
	let fieldOfView: CGFloat?
}

private struct RecordCameraFocusChunk {
	let time: TimeInterval
	let kind: UInt32
	let position: SCNVector3
}

private struct RecordCameraPositionSample {
	let time: TimeInterval
	let position: SCNVector3
	let roll: SCNFloat
	let fieldOfView: CGFloat?
	let hasCutMarker: Bool
}

private struct RecordCameraFocusSample {
	let time: TimeInterval
	let position: SCNVector3
	let hasCutMarker: Bool
}

struct RecordTimedEvent {
	let time: TimeInterval
	let name: String
	let isStop: Bool
}

struct RecordSpeechEvent {
	let time: TimeInterval
	let channelId: UInt32
	let soundId: Int
	let speakerFrameName: String?

	var fileName: String {
		return String(format: "%08d.wav", soundId)
	}
}

private enum RecordDialogChunk {
	case binding(time: TimeInterval, channelId: UInt32, frameName: String)
	case speech(time: TimeInterval, channelId: UInt32, soundId: Int)
	case ignored
}

struct RecordAnimationEvent {
	let animationId: Int
	let trackId: Int
	let time: TimeInterval
	let animationStartOffset: TimeInterval
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
	let headerKey: Int
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

		headerKey = Int(header[0])

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

		var bindingMetadata: [RecordModelBindingMetadata] = []
		for _ in 0 ..< modelsCount {
			let sourceName: String = try stream.read(maxLength: 36, encoding: .windowsCP1250)
			let targetName: String = try stream.read(maxLength: 36, encoding: .windowsCP1250)
			let chunkSize0: UInt32 = try stream.read()
			let chunkSize1: UInt32 = try stream.read()
			let chunkSize2: UInt32 = try stream.read()
			let chunkSize3: UInt32 = try stream.read()
			let chunkSizes: [Int] = [
				Int(chunkSize0),
				Int(chunkSize1),
				Int(chunkSize2),
				Int(chunkSize3)
			]
			let _: UInt32 = try stream.read()
			let deactivationMilliseconds: UInt32 = try stream.read()
			let _: UInt32 = try stream.read()
			let streamLength: UInt32 = try stream.read()
			let streamOffset: UInt32 = try stream.read()
			bindingMetadata.append(RecordModelBindingMetadata(
				sourceName: sourceName,
				targetName: targetName,
				chunkSizes: chunkSizes,
				durationMilliseconds: Int(deactivationMilliseconds),
				sampleDataLength: Int(streamLength),
				sampleDataOffset: Int(streamOffset)
			))
		}

		let loadedPayloadOffset = stream.currentOffset
		let recordData = try? Data(contentsOf: url)
		let loadedModelBindings = bindingMetadata.enumerated().map { index, metadata in
			RecordModelBinding(
				sourceName: metadata.sourceName,
				targetName: metadata.targetName,
				extraName: "",
				transformEvents: recordData?.readBindingTransformEvents(
					metadata: metadata,
					payloadOffset: loadedPayloadOffset,
					bindingIndex: index
				) ?? []
			)
		}
		animations = loadedAnimations
		modelBindings = loadedModelBindings
		payloadOffset = loadedPayloadOffset
		cameraKeyframes = Record.readCameraKeyframes(
			url: url,
			offset: payloadOffset + Int(header[2]),
			cameraCount: Int(header[5]),
			focusCount: Int(header[6])
		)
		animationEvents = Record.readAnimationEvents(
			url: url,
			payloadOffset: payloadOffset,
			metadata: bindingMetadata,
			animationCount: loadedAnimations.count
		)
		targetLinks = Record.readTargetLinks(url: url, finalBlockSize: Int(header[8]))
		timedEvents = Record.readTimedEvents(url: url)
		speechEvents = Record.readSpeechEvents(url: url, modelBindings: loadedModelBindings)
	}

	private static func readCameraKeyframes(
		url: URL,
		offset: Int,
		cameraCount: Int,
		focusCount: Int
	) -> [RecordCameraKeyframe] {
		guard let data = try? Data(contentsOf: url),
			  offset >= 0,
			  offset < data.count else {
			return []
		}

		let cameraChunks = data.readCameraChunks(offset: offset, count: cameraCount)
		let focusChunks = data.readCameraFocusChunks(offset: offset + cameraCount * 64, count: focusCount)
		guard !cameraChunks.isEmpty, !focusChunks.isEmpty else { return [] }

		let cameraSamples = Record.cameraPositionSamples(from: cameraChunks)
		let focusSamples = Record.cameraFocusSamples(from: focusChunks)
		guard !cameraSamples.isEmpty, !focusSamples.isEmpty else { return [] }

		let keyTimes = Set(cameraSamples.map(\.time) + focusSamples.map(\.time)).sorted()
		return keyTimes.compactMap { time in
			guard let cameraSample = Record.cameraPositionSample(at: time, in: cameraSamples),
				  let focusSample = Record.cameraFocusSample(at: time, in: focusSamples) else {
				return nil
			}

			return RecordCameraKeyframe(
				time: time,
				position: cameraSample.position,
				focusPosition: focusSample.position,
				roll: cameraSample.roll,
				fieldOfView: cameraSample.fieldOfView,
				outgoingControlPoint: nil,
				incomingControlPoint: nil,
				hasCutMarker: cameraSample.hasCutMarker || focusSample.hasCutMarker
			)
		}
	}

	private static func cameraPositionSamples(
		from chunks: [RecordCameraChunk]
	) -> [RecordCameraPositionSample] {
		var samples: [RecordCameraPositionSample] = []
		var pendingCutTime: TimeInterval?
		var pendingIncomingControlChunk: RecordCameraChunk?
		var pendingOutgoingControlTime: TimeInterval?

		for chunk in chunks {
			switch chunk.kind {
			case 1:
				if let cutTime = pendingCutTime,
				   let controlChunk = pendingIncomingControlChunk,
				   abs(cutTime - chunk.time) <= 0.001,
				   abs(cutTime - controlChunk.time) <= 0.001,
				   samples.last.map({ controlChunk.time >= $0.time + 0.001 }) ?? true {
					samples.append(RecordCameraPositionSample(
						time: controlChunk.time,
						position: controlChunk.position,
						roll: controlChunk.roll,
						fieldOfView: controlChunk.fieldOfView,
						hasCutMarker: false
					))
					samples.append(RecordCameraPositionSample(
						time: cutTime + recordCameraCutTimeEpsilon,
						position: chunk.position,
						roll: chunk.roll,
						fieldOfView: chunk.fieldOfView,
						hasCutMarker: true
					))
					pendingCutTime = nil
					pendingIncomingControlChunk = nil
					pendingOutgoingControlTime = nil
					continue
				}

				if let cutTime = pendingCutTime,
				   cutTime < chunk.time - 0.001 {
					if let controlChunk = pendingIncomingControlChunk,
					   abs(cutTime - controlChunk.time) <= 0.001,
					   samples.last.map({ controlChunk.time > $0.time + 0.001 }) ?? true {
						samples.append(RecordCameraPositionSample(
							time: controlChunk.time,
							position: controlChunk.position,
							roll: controlChunk.roll,
							fieldOfView: controlChunk.fieldOfView,
							hasCutMarker: false
						))
					}
					samples.append(RecordCameraPositionSample(
						time: cutTime + recordCameraCutTimeEpsilon,
						position: chunk.position,
						roll: chunk.roll,
						fieldOfView: chunk.fieldOfView,
						hasCutMarker: true
					))
					pendingCutTime = nil
					pendingIncomingControlChunk = nil
					pendingOutgoingControlTime = nil
					continue
				}

				if let previousSample = samples.last,
				   previousSample.hasCutMarker,
				   chunk.time <= previousSample.time + 0.002 {
					pendingCutTime = nil
					pendingIncomingControlChunk = nil
					pendingOutgoingControlTime = nil
					continue
				}

				if let controlChunk = pendingIncomingControlChunk,
				   let cutTime = pendingCutTime,
				   abs(cutTime - controlChunk.time) <= 0.001,
				   samples.last.map({ controlChunk.time > $0.time + 0.001 }) ?? true,
				   controlChunk.time < chunk.time - 0.001 {
					samples.append(RecordCameraPositionSample(
						time: controlChunk.time,
						position: controlChunk.position,
						roll: controlChunk.roll,
						fieldOfView: controlChunk.fieldOfView,
						hasCutMarker: false
					))
				}

				let hasCutMarker = cameraHasResetControl(
					at: chunk.time,
					previousTime: samples.last?.time,
					cutTime: pendingCutTime,
					incomingControlTime: pendingIncomingControlChunk?.time,
					outgoingControlTime: pendingOutgoingControlTime
				)
				samples.append(RecordCameraPositionSample(
					time: chunk.time,
					position: chunk.position,
					roll: chunk.roll,
					fieldOfView: chunk.fieldOfView,
					hasCutMarker: hasCutMarker
				))
				pendingCutTime = nil
				pendingIncomingControlChunk = nil
				pendingOutgoingControlTime = nil

			case 2:
				pendingCutTime = chunk.time

			case 4:
				pendingIncomingControlChunk = chunk

			case 8:
				pendingOutgoingControlTime = chunk.time

			default:
				break
			}
		}

		return samples
	}

	private static func cameraFocusSamples(
		from chunks: [RecordCameraFocusChunk]
	) -> [RecordCameraFocusSample] {
		var samples: [RecordCameraFocusSample] = []
		var pendingCutTime: TimeInterval?
		var pendingIncomingControlChunk: RecordCameraFocusChunk?
		var pendingOutgoingControlTime: TimeInterval?

		for chunk in chunks {
			switch chunk.kind {
			case 1:
				if let cutTime = pendingCutTime,
				   let controlChunk = pendingIncomingControlChunk,
				   abs(cutTime - chunk.time) <= 0.001,
				   abs(cutTime - controlChunk.time) <= 0.001,
				   samples.last.map({ controlChunk.time >= $0.time + 0.001 }) ?? true {
					samples.append(RecordCameraFocusSample(
						time: controlChunk.time,
						position: controlChunk.position,
						hasCutMarker: false
					))
					samples.append(RecordCameraFocusSample(
						time: cutTime + recordCameraCutTimeEpsilon,
						position: chunk.position,
						hasCutMarker: true
					))
					pendingCutTime = nil
					pendingIncomingControlChunk = nil
					pendingOutgoingControlTime = nil
					continue
				}

				if let cutTime = pendingCutTime,
				   cutTime < chunk.time - 0.001 {
					if let controlChunk = pendingIncomingControlChunk,
					   abs(cutTime - controlChunk.time) <= 0.001,
					   samples.last.map({ controlChunk.time > $0.time + 0.001 }) ?? true {
						samples.append(RecordCameraFocusSample(
							time: controlChunk.time,
							position: controlChunk.position,
							hasCutMarker: false
						))
					}
					samples.append(RecordCameraFocusSample(
						time: cutTime + recordCameraCutTimeEpsilon,
						position: chunk.position,
						hasCutMarker: true
					))
					pendingCutTime = nil
					pendingIncomingControlChunk = nil
					pendingOutgoingControlTime = nil
					continue
				}

				if let previousSample = samples.last,
				   previousSample.hasCutMarker,
				   chunk.time <= previousSample.time + 0.002 {
					pendingCutTime = nil
					pendingIncomingControlChunk = nil
					pendingOutgoingControlTime = nil
					continue
				}

				if let controlChunk = pendingIncomingControlChunk,
				   let cutTime = pendingCutTime,
				   abs(cutTime - controlChunk.time) <= 0.001,
				   samples.last.map({ controlChunk.time > $0.time + 0.001 }) ?? true,
				   controlChunk.time < chunk.time - 0.001 {
					samples.append(RecordCameraFocusSample(
						time: controlChunk.time,
						position: controlChunk.position,
						hasCutMarker: false
					))
				}

				let hasCutMarker = cameraHasResetControl(
					at: chunk.time,
					previousTime: samples.last?.time,
					cutTime: pendingCutTime,
					incomingControlTime: pendingIncomingControlChunk?.time,
					outgoingControlTime: pendingOutgoingControlTime
				)
				samples.append(RecordCameraFocusSample(
					time: chunk.time,
					position: chunk.position,
					hasCutMarker: hasCutMarker
				))
				pendingCutTime = nil
				pendingIncomingControlChunk = nil
				pendingOutgoingControlTime = nil

			case 2:
				pendingCutTime = chunk.time

			case 4:
				pendingIncomingControlChunk = chunk

			case 8:
				pendingOutgoingControlTime = chunk.time

			default:
				break
			}
		}

		return samples
	}

	private static func cameraPositionSample(
		at time: TimeInterval,
		in samples: [RecordCameraPositionSample]
	) -> RecordCameraPositionSample? {
		if let exactSample = samples.first(where: { abs($0.time - time) < 0.001 }) {
			return exactSample
		}
		guard let bounds = recordSampleBounds(in: samples, at: time) else { return nil }
		let from = bounds.from
		let to = bounds.to
		if to.hasCutMarker {
			return RecordCameraPositionSample(
				time: time,
				position: from.position,
				roll: from.roll,
				fieldOfView: from.fieldOfView,
				hasCutMarker: false
			)
		}

		let progress = SCNFloat(bounds.progress)
		let fromFieldOfView = from.fieldOfView ?? to.fieldOfView
		let toFieldOfView = to.fieldOfView ?? from.fieldOfView
		let fieldOfView: CGFloat?
		if let fromFieldOfView = fromFieldOfView,
		   let toFieldOfView = toFieldOfView {
			fieldOfView = fromFieldOfView + (toFieldOfView - fromFieldOfView) * CGFloat(progress)
		} else {
			fieldOfView = nil
		}

		return RecordCameraPositionSample(
			time: time,
			position: recordLerpVector(from.position, to.position, progress),
			roll: recordLerpAngle(from.roll, to.roll, progress),
			fieldOfView: fieldOfView,
			hasCutMarker: false
		)
	}

	private static func cameraFocusSample(
		at time: TimeInterval,
		in samples: [RecordCameraFocusSample]
	) -> RecordCameraFocusSample? {
		if let exactSample = samples.first(where: { abs($0.time - time) < 0.001 }) {
			return exactSample
		}
		guard let bounds = recordSampleBounds(in: samples, at: time) else { return nil }
		let from = bounds.from
		let to = bounds.to
		if to.hasCutMarker {
			return RecordCameraFocusSample(time: time, position: from.position, hasCutMarker: false)
		}

		return RecordCameraFocusSample(
			time: time,
			position: recordLerpVector(
				from.position,
				to.position,
				SCNFloat(bounds.progress)
			),
			hasCutMarker: false
		)
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
		payloadOffset: Int,
		metadata: [RecordModelBindingMetadata],
		animationCount: Int
	) -> [RecordAnimationEvent] {
		guard animationCount > 0,
			  let data = try? Data(contentsOf: url) else {
			return []
		}

		return metadata.enumerated().flatMap { index, metadata in
			data.readBindingAnimationEvents(
				metadata: metadata,
				payloadOffset: payloadOffset,
				bindingIndex: index,
				animationCount: animationCount
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

	private static func readSpeechEvents(
		url: URL,
		modelBindings: [RecordModelBinding]
	) -> [RecordSpeechEvent] {
		guard let data = try? Data(contentsOf: url) else { return [] }
		guard data.count >= 36 else { return [] }

		let entrySize = 36
		var acceptedOffsets = Set<Int>()
		var frameNameByChannelId: [UInt32: String] = [:]
		let validFrameNames = Set(
			modelBindings
				.flatMap { [$0.sourceName, $0.targetName] }
				.map { $0.lowercased() }
		)
		var events: [RecordSpeechEvent] = []

		for startOffset in stride(from: 0, through: data.count - entrySize, by: 4) {
			var run: [(offset: Int, chunk: RecordDialogChunk)] = []
			var currentOffset = startOffset
			while currentOffset + entrySize <= data.count,
				  let chunk = data.readDialogChunk(
					at: currentOffset,
					validFrameNames: validFrameNames
				  ) {
				run.append((currentOffset, chunk))
				currentOffset += entrySize
			}

			guard run.count >= 3 else { continue }
			for (offset, chunk) in run where !acceptedOffsets.contains(offset) {
				acceptedOffsets.insert(offset)
				switch chunk {
				case let .binding(_, channelId, frameName):
					frameNameByChannelId[channelId] = frameName
				case let .speech(time, channelId, soundId):
					events.append(RecordSpeechEvent(
						time: time,
						channelId: channelId,
						soundId: soundId,
						speakerFrameName: frameNameByChannelId[channelId]
					))
				case .ignored:
					break
				}
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

	func readCameraChunks(offset: Int, count cameraCount: Int) -> [RecordCameraChunk] {
		let recordSize = 64
		guard offset >= 0,
			  cameraCount > 0,
			  offset + cameraCount * recordSize <= count else {
			return []
		}

		return (0 ..< cameraCount).compactMap { index in
			let recordOffset = offset + index * recordSize
			let kind = readUInt32(at: recordOffset + 8)
			guard [1, 2, 4, 8].contains(kind) else { return nil }

			let time = readUInt32(at: recordOffset)
			let x = readFloat(at: recordOffset + 12)
			let y = readFloat(at: recordOffset + 16)
			let z = readFloat(at: recordOffset + 20)
			let roll = readFloat(at: recordOffset + 32)
			let fov = readFloat(at: recordOffset + 52)
			guard [x, y, z, roll, fov].allSatisfy({ $0.isFinite }) else { return nil }

			return RecordCameraChunk(
				time: TimeInterval(time) / 1000.0,
				kind: kind,
				position: SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z)),
				roll: SCNFloat(recordCameraRoll(from: roll)),
				fieldOfView: recordCameraFieldOfView(from: fov)
			)
		}
	}

	func readCameraFocusChunks(offset: Int, count focusCount: Int) -> [RecordCameraFocusChunk] {
		let recordSize = 56
		guard offset >= 0,
			  focusCount > 0,
			  offset + focusCount * recordSize <= count else {
			return []
		}

		return (0 ..< focusCount).compactMap { index in
			let recordOffset = offset + index * recordSize
			let kind = readUInt32(at: recordOffset + 8)
			guard [1, 2, 4, 8].contains(kind) else { return nil }

			let time = readUInt32(at: recordOffset)
			let x = readFloat(at: recordOffset + 12)
			let y = readFloat(at: recordOffset + 16)
			let z = readFloat(at: recordOffset + 20)
			guard [x, y, z].allSatisfy({ $0.isFinite }) else { return nil }

			return RecordCameraFocusChunk(
				time: TimeInterval(time) / 1000.0,
				kind: kind,
				position: SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
			)
		}
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

	func readBindingTransformEvents(
		metadata: RecordModelBindingMetadata,
		payloadOffset: Int,
		bindingIndex: Int
	) -> [RecordAnimationEvent] {
		let trackId = -bindingIndex - 1
		let animationId = -bindingIndex - 1
		return readTransformChunks(metadata: metadata, payloadOffset: payloadOffset).map { chunk in
			RecordAnimationEvent(
				animationId: animationId,
				trackId: trackId,
				time: chunk.time,
				animationStartOffset: 0,
				packedTrackId: 0,
				interpolationKind: chunk.type,
				position: chunk.position,
				orientationVector: chunk.orientationVector
			)
		}.sorted { $0.time < $1.time }
	}

	func readBindingAnimationEvents(
		metadata: RecordModelBindingMetadata,
		payloadOffset: Int,
		bindingIndex: Int,
		animationCount: Int
	) -> [RecordAnimationEvent] {
		return readTransformChunks(metadata: metadata, payloadOffset: payloadOffset).compactMap { chunk in
			guard let auxiliary = chunk.auxiliary,
				  auxiliary & 0x400 != 0 else {
				return nil
			}

			let animationId = Int(auxiliary & 0x3ff)
			guard animationId < animationCount else { return nil }
			return RecordAnimationEvent(
				animationId: animationId,
				trackId: bindingIndex,
				time: chunk.time,
				animationStartOffset: chunk.animationStartOffset,
				packedTrackId: auxiliary,
				interpolationKind: chunk.type,
				position: chunk.position,
				orientationVector: chunk.orientationVector
			)
		}
	}

	private struct RecordTransformChunk {
		let time: TimeInterval
		let type: UInt32
		let position: SCNVector3
		let orientationVector: SCNVector3
		let auxiliary: UInt32?
		let animationStartOffset: TimeInterval
	}

	private func readTransformChunks(
		metadata: RecordModelBindingMetadata,
		payloadOffset: Int
	) -> [RecordTransformChunk] {
		guard metadata.sampleDataOffset >= 0,
			  metadata.sampleDataLength >= 8 else {
			return []
		}

		let dataStart = payloadOffset + metadata.sampleDataOffset
		let dataEnd = dataStart + metadata.sampleDataLength
		guard dataStart >= 0,
			  dataEnd <= count else {
			return []
		}

		let durationMilliseconds = Swift.max(0, metadata.durationMilliseconds)
		var chunks: [RecordTransformChunk] = []
		var offset = dataStart + 8
		while offset + 8 <= dataEnd {
			let time = readUInt32(at: offset)
			let type = readUInt32(at: offset + 4)
			guard type < metadata.chunkSizes.count else { break }
			let chunkSize = metadata.chunkSizes[Int(type)]
			guard chunkSize >= 40,
				  offset + chunkSize <= dataEnd else {
				break
			}
			guard durationMilliseconds == 0 || time <= durationMilliseconds else {
				offset += chunkSize
				continue
			}

			let values = [
				readFloat(at: offset + 8),
				readFloat(at: offset + 12),
				readFloat(at: offset + 16),
				readFloat(at: offset + 20),
				readFloat(at: offset + 24),
				readFloat(at: offset + 28),
				readFloat(at: offset + 32)
			]
			guard values.allSatisfy({ $0.isFinite && abs($0) < 100_000 }) else {
				offset += chunkSize
				continue
			}

			let auxiliary = chunkSize >= 40 ? readUInt32(at: offset + 36) : nil
			let rawAnimationOffset = chunkSize >= 44 ? readUInt32(at: offset + 40) & 0xfff : 0
			chunks.append(RecordTransformChunk(
				time: TimeInterval(time) / 1000.0,
				type: type,
				position: SCNVector3(
					x: SCNFloat(values[0]),
					y: SCNFloat(values[1]),
					z: SCNFloat(values[2])
				),
				orientationVector: SCNVector3(
					x: SCNFloat(values[3]),
					y: SCNFloat(values[4]),
					z: SCNFloat(values[5])
				),
				auxiliary: auxiliary,
				animationStartOffset: TimeInterval(rawAnimationOffset) * 0.04
			))
			offset += chunkSize
		}
		return chunks
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
				animationStartOffset: 0,
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
				animationStartOffset: 0,
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
				animationStartOffset: 0,
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
				animationStartOffset: baseEvent.animationStartOffset,
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

	func readDialogChunk(
		at offset: Int,
		validFrameNames: Set<String>
	) -> RecordDialogChunk? {
		let time = readUInt32(at: offset)
		let channelId = readUInt32(at: offset + 4)
		let dialogId = readUInt32(at: offset + 8)

		guard time <= 3_600_000 else {
			return nil
		}

		if dialogId == 1 {
			let frameName = readString(at: offset + 12, maxLength: 24, encoding: .windowsCP1250)
			guard validFrameNames.contains(frameName.lowercased()) else { return nil }
			return .binding(
				time: TimeInterval(time) / 1000.0,
				channelId: channelId,
				frameName: frameName
			)
		}

		if dialogId == 0 || dialogId == UInt32.max {
			return .ignored
		}

		guard dialogId >= 1_000_000,
			  dialogId <= 99_999_999 else {
			return nil
		}

		let fileName = String(format: "%08d.wav", Int(dialogId))
		let url = mainDirectory.appendingPathComponent("sounds/" + fileName)
		guard FileManager.default.fileExists(atPath: url.path) else {
			return nil
		}

		return .speech(
			time: TimeInterval(time) / 1000.0,
			channelId: channelId,
			soundId: Int(dialogId)
		)
	}

	func readString(
		at offset: Int,
		maxLength: Int,
		encoding: String.Encoding = .utf8
	) -> String {
		guard offset >= 0,
			  maxLength > 0,
			  offset + maxLength <= count else {
			return ""
		}

		var bytes = Array(self[offset ..< offset + maxLength])
		if let terminatorIndex = bytes.firstIndex(of: 0) {
			bytes.removeSubrange(terminatorIndex...)
		}
		guard !bytes.isEmpty else { return "" }
		return String(data: Data(bytes), encoding: encoding) ?? ""
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

private func recordCameraRoll(from rawRoll: Float) -> Float {
	guard rawRoll.isFinite else { return 0 }
	let scaledRoll = rawRoll * recordCameraRollScale
	return Swift.max(-recordCameraMaximumRoll, Swift.min(recordCameraMaximumRoll, scaledRoll))
}

private func recordLerpVector(_ start: SCNVector3, _ end: SCNVector3, _ amount: SCNFloat) -> SCNVector3 {
	let clampedAmount = max(0, min(1, amount))
	return SCNVector3(
		x: start.x + (end.x - start.x) * clampedAmount,
		y: start.y + (end.y - start.y) * clampedAmount,
		z: start.z + (end.z - start.z) * clampedAmount
	)
}

private func recordLerpAngle(_ start: SCNFloat, _ end: SCNFloat, _ amount: SCNFloat) -> SCNFloat {
	let clampedAmount = max(0, min(1, amount))
	let fullTurn = SCNFloat.pi * 2
	var delta = end - start
	while delta > .pi {
		delta -= fullTurn
	}
	while delta < -.pi {
		delta += fullTurn
	}
	return start + delta * clampedAmount
}

private func cameraHasResetControl(
	at time: TimeInterval,
	previousTime: TimeInterval?,
	cutTime: TimeInterval?,
	incomingControlTime: TimeInterval?,
	outgoingControlTime: TimeInterval?
) -> Bool {
	guard let previousTime = previousTime,
		  time > previousTime + 0.001 else {
		return false
	}

	if let cutTime = cutTime,
	   abs(cutTime - time) <= 0.001 {
		return true
	}

	if let cutTime = cutTime,
	   let incomingControlTime = incomingControlTime,
	   cutTime > previousTime + 0.001,
	   cutTime < time - 0.001,
	   incomingControlTime > time + 0.001 {
		return true
	}

	return outgoingControlTime.map { $0 <= previousTime + 0.001 } ?? false
}

private func recordSampleBounds(
	in samples: [RecordCameraPositionSample],
	at time: TimeInterval
) -> (from: RecordCameraPositionSample, to: RecordCameraPositionSample, progress: CGFloat)? {
	guard let first = samples.first else { return nil }
	guard time > first.time else { return (first, first, 0) }

	var previous = first
	for sample in samples.dropFirst() {
		guard time > sample.time else {
			let duration = sample.time - previous.time
			let progress = duration > 0 ? CGFloat((time - previous.time) / duration) : 1
			return (previous, sample, max(0, min(1, progress)))
		}
		previous = sample
	}

	return (previous, previous, 0)
}

private func recordSampleBounds(
	in samples: [RecordCameraFocusSample],
	at time: TimeInterval
) -> (from: RecordCameraFocusSample, to: RecordCameraFocusSample, progress: CGFloat)? {
	guard let first = samples.first else { return nil }
	guard time > first.time else { return (first, first, 0) }

	var previous = first
	for sample in samples.dropFirst() {
		guard time > sample.time else {
			let duration = sample.time - previous.time
			let progress = duration > 0 ? CGFloat((time - previous.time) / duration) : 1
			return (previous, sample, max(0, min(1, progress)))
		}
		previous = sample
	}

	return (previous, previous, 0)
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
