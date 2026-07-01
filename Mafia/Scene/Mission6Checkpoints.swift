//
//  Mission6Checkpoints.swift
//  Mafia
//
//  Created by Codex on 25/06/2026.
//  Copyright © 2026 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

struct Mission6CheckpointError: Error { }

struct Mission6CheckpointLink {
	let checkpointIndex: UInt16
	let kind: UInt16
	let distance: Float
}

struct Mission6Checkpoint {
	let index: Int
	let position: SCNVector3
	let type: UInt16
	let flags: UInt16
	let speed: UInt32
	let bestTime: UInt32
	let rawRuntimeFlags: UInt8
	let runtimeFlags: UInt8
	let links: [Mission6CheckpointLink]
}

final class Mission6Checkpoints {
	private static let signature: UInt32 = 0x01abcedf
	private static let fixedRecordSize = 0x1e
	private static let linkRecordSize = 8

	let checkpoints: [Mission6Checkpoint]

	init?(name: String) throws {
		let url = mainDirectory.appendingPathComponent(name + "/check.bin")
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }

		let data = try Data(contentsOf: url)
		guard data.count >= 8,
			  data.mission6CheckpointReadUInt32LE(at: 0) == Self.signature else {
			throw Mission6CheckpointError()
		}

		let checkpointCount = Int(data.mission6CheckpointReadUInt32LE(at: 4))
		let fixedRecordsOffset = 8
		let linksOffset = fixedRecordsOffset + checkpointCount * Self.fixedRecordSize
		guard linksOffset <= data.count else {
			throw Mission6CheckpointError()
		}

		var rawRecords: [(
			position: SCNVector3,
			type: UInt16,
			flags: UInt16,
			speed: UInt32,
			bestTime: UInt32,
			rawRuntimeFlags: UInt8,
			linkCount: Int
		)] = []
		rawRecords.reserveCapacity(checkpointCount)
		for index in 0..<checkpointCount {
			let offset = fixedRecordsOffset + index * Self.fixedRecordSize
			rawRecords.append((
				position: SCNVector3(
					x: SCNFloat(data.mission6CheckpointReadFloat32LE(at: offset)),
					y: SCNFloat(data.mission6CheckpointReadFloat32LE(at: offset + 4)),
					z: SCNFloat(data.mission6CheckpointReadFloat32LE(at: offset + 8))
				),
				type: data.mission6CheckpointReadUInt16LE(at: offset + 12),
				flags: data.mission6CheckpointReadUInt16LE(at: offset + 14),
				speed: data.mission6CheckpointReadUInt32LE(at: offset + 16),
				bestTime: data.mission6CheckpointReadUInt32LE(at: offset + 20),
				rawRuntimeFlags: data[offset + 28],
				linkCount: Int(data[offset + 29])
			))
		}

		var linkOffset = linksOffset
		var loadedCheckpoints: [Mission6Checkpoint] = []
		loadedCheckpoints.reserveCapacity(checkpointCount)
		for (index, rawRecord) in rawRecords.enumerated() {
			let linkByteCount = rawRecord.linkCount * Self.linkRecordSize
			guard linkOffset + linkByteCount <= data.count else {
				throw Mission6CheckpointError()
			}

			var links: [Mission6CheckpointLink] = []
			links.reserveCapacity(rawRecord.linkCount)
			for linkIndex in 0..<rawRecord.linkCount {
				let offset = linkOffset + linkIndex * Self.linkRecordSize
				let checkpointIndex = data.mission6CheckpointReadUInt16LE(at: offset)
				guard Int(checkpointIndex) < checkpointCount else {
					throw Mission6CheckpointError()
				}
				links.append(Mission6CheckpointLink(
					checkpointIndex: checkpointIndex,
					kind: data.mission6CheckpointReadUInt16LE(at: offset + 2),
					distance: data.mission6CheckpointReadFloat32LE(at: offset + 4)
				))
			}
			linkOffset += linkByteCount

			loadedCheckpoints.append(Mission6Checkpoint(
				index: index,
				position: rawRecord.position,
				type: rawRecord.type,
				flags: rawRecord.flags,
				speed: rawRecord.speed,
				bestTime: rawRecord.bestTime,
				rawRuntimeFlags: rawRecord.rawRuntimeFlags,
				runtimeFlags: 0,
				links: links
			))
		}

		guard linkOffset == data.count else {
			throw Mission6CheckpointError()
		}
		checkpoints = loadedCheckpoints
	}
}

private extension Data {
	func mission6CheckpointReadUInt16LE(at offset: Int) -> UInt16 {
		UInt16(self[offset]) |
			UInt16(self[offset + 1]) << 8
	}

	func mission6CheckpointReadUInt32LE(at offset: Int) -> UInt32 {
		UInt32(self[offset]) |
			UInt32(self[offset + 1]) << 8 |
			UInt32(self[offset + 2]) << 16 |
			UInt32(self[offset + 3]) << 24
	}

	func mission6CheckpointReadFloat32LE(at offset: Int) -> Float {
		Float(bitPattern: mission6CheckpointReadUInt32LE(at: offset))
	}
}
