//
//  SaveGame.swift
//  Mafia
//
//  Created by Codex on 03/06/2026.
//

import Foundation

struct SaveGameSlot {
	let url: URL
	let profileNumber: Int
	let checkpointCode: Int
	let fileSize: UInt64
	let checkpoint: SaveGameCheckpoint?

	var fileName: String {
		return url.lastPathComponent
	}

	var title: String {
		if let title = checkpointTitle {
			return title
		}

		guard let checkpoint = checkpoint else {
			return String(format: "%03d", checkpointCode)
		}
		return String(format: "%03d  %@", checkpointCode, MissionLoadInfo.title(for: checkpoint.missionFolder))
	}

	var checkpointTitle: String? {
		return TextDb.get(5000 + checkpointCode)
	}

	var detailText: String {
		guard let summary = checkpoint?.summary else { return "" }
		let format = TextDb.get(175) ?? "%d%%, %d.%d.%d, %02d:%02d, %d:%02d:%02d"
		return String(
			format: format,
			Int(summary.healthPercent),
			Int(summary.saveDate.day),
			Int(summary.saveDate.month),
			Int(summary.saveDate.year),
			Int(summary.saveTime.hour),
			Int(summary.saveTime.minute),
			Int(summary.playTime.hours),
			Int(summary.playTime.minutes),
			Int(summary.playTime.seconds)
		)
	}

	var missionFolder: String? {
		return checkpoint?.missionFolder
	}

	var imageName: String {
		return MissionLoadInfo.imageName(for: missionFolder)
	}

	var screenshotURL: URL? {
		let url = mainDirectory.appendingPathComponent(String(format: "maps/shot%03d.bmp", checkpointCode))
		return FileManager.default.fileExists(atPath: url.path) ? url : nil
	}

	var textId: Int {
		guard let missionFolder = missionFolder else { return 0 }
		return MissionLoadInfo.textId(for: missionFolder)
	}
}

struct SaveGameCheckpoint {
	let innerSignature: UInt32
	let version: UInt32
	let checkpointCode: UInt32
	let checkpointMarker: UInt32
	let summary: SaveGameSummary
	let session: SaveGameSession
	let variableBlocks: [SaveGameVariableBlock]
	let entities: [SaveGameEntity]

	let missionFolder: String

	var activePlayerVehicleEntity: SaveGameEntity? {
		return entities.first {
			$0.objectType == .car &&
				$0.playerSlot >= 0 &&
				(($0.payloadPrefix?.stateA ?? 0) & 0x00008000) != 0
		}
	}

	var playerEntity: SaveGameEntity? {
		return entities.first { $0.objectType == .player }
	}

	init(
		innerSignature: UInt32,
		version: UInt32,
		checkpointCode: UInt32,
		checkpointMarker: UInt32,
		summary: SaveGameSummary,
		session: SaveGameSession,
		variableBlocks: [SaveGameVariableBlock],
		entities: [SaveGameEntity]
	) {
		self.innerSignature = innerSignature
		self.version = version
		self.checkpointCode = checkpointCode
		self.checkpointMarker = checkpointMarker
		self.summary = summary
		self.session = session
		self.variableBlocks = variableBlocks
		self.entities = entities
		self.missionFolder = session.missionFolder
	}
}

struct SaveGameSummary {
	let checkpointCode: UInt32
	let saveTimePacked: UInt32
	let saveDatePacked: UInt32
	let healthPercent: UInt32
	let missionTimer: UInt32
	let unknown1C: UInt32

	var saveTimeText: String {
		let parts = packedBytes(saveTimePacked)
		return String(format: "%d:%02d", parts.2, parts.1)
	}

	var saveTime: (hour: UInt32, minute: UInt32, second: UInt32) {
		let parts = packedBytes(saveTimePacked)
		return (parts.2, parts.1, parts.0)
	}

	var saveDateText: String {
		let parts = packedBytes(saveDatePacked)
		let year = UInt32(parts.2) | (UInt32(parts.3) << 8)
		return "\(parts.0).\(parts.1).\(year)"
	}

	var saveDate: (day: UInt32, month: UInt32, year: UInt32) {
		let parts = packedBytes(saveDatePacked)
		return (parts.0, parts.1, UInt32(parts.2) | (UInt32(parts.3) << 8))
	}

	var playTimeText: String {
		let playTime = playTime
		let hours = playTime.hours
		let minutes = playTime.minutes
		let seconds = playTime.seconds
		return String(format: "%uh%02umin %02us", hours, minutes, seconds)
	}

	var playTime: (hours: UInt32, minutes: UInt32, seconds: UInt32) {
		let totalSeconds = missionTimer / 1000
		return (totalSeconds / 3600, (totalSeconds % 3600) / 60, totalSeconds % 60)
	}

	private func packedBytes(_ value: UInt32) -> (UInt32, UInt32, UInt32, UInt32) {
		return (
			value & 0xff,
			(value >> 8) & 0xff,
			(value >> 16) & 0xff,
			(value >> 24) & 0xff
		)
	}
}

struct SaveGameSession {
	let missionFolder: String
	let missionStateSize: UInt32
	let unknown24: UInt32
	let missionStateA: [UInt32]
	let missionStateB: [UInt32]
	let extraStateASize: UInt32
	let extraStateBSize: UInt32
	let globalFlag: UInt32
	let globalValueA: UInt32
	let globalValueB: UInt32
	let globalValueC: UInt32
}

struct SaveGameVariableBlock {
	let name: String
	let offset: Int
	let size: UInt32
	let data: Data
}

struct SaveGameEntity {
	let offset: Int
	let name: String
	let modelName: String
	let objectTypeRawValue: UInt32
	let payloadSize: UInt32
	let playerSlot: Int32
	let payloadPrefix: SaveGameEntityPayloadPrefix?
	let position: SaveGameVector3?
	let doorState: SaveGameDoorState?
	let payload: Data

	var objectType: ObjectDefinitionType? {
		return ObjectDefinitionType(rawValue: objectTypeRawValue)
	}
}

struct SaveGameEntityPayloadPrefix {
	let version: UInt8
	let group: UInt8
	let sceneObjectId: UInt16
	let stateA: UInt32
	let stateB: UInt32
	let stateC: UInt16
	let stateD: UInt8
}

struct SaveGameVector3 {
	let x: Float
	let y: Float
	let z: Float
}

struct SaveGameDoorState {
	let angle: Float
	let rawState: UInt32
	let flags: UInt16
}

struct MissionLoadInfo {
	let missionFolder: String
	let imageName: String
	let textId: Int

	var title: String {
		return TextDb.get(textId) ?? missionFolder
	}

	static func title(for missionFolder: String) -> String {
		return info(for: missionFolder)?.title ?? missionFolder
	}

	static func imageName(for missionFolder: String?) -> String {
		guard let missionFolder = missionFolder,
			  let info = info(for: missionFolder) else {
			return resolveImageName("00menu.tga", fallbackFolder: nil)
		}
		return resolveImageName(info.imageName, fallbackFolder: missionFolder)
	}

	static func imageName(for missionFolder: String, fallbackImageName: String) -> String {
		let fallbackName = fallbackImageName.contains(".") ? fallbackImageName : fallbackImageName + ".tga"
		let imageName = info(for: missionFolder)?.imageName ?? fallbackName
		return resolveImageName(imageName, fallbackFolder: missionFolder)
	}

	static func textId(for missionFolder: String) -> Int {
		return info(for: missionFolder)?.textId ?? 0
	}

	static func loadAll() -> [MissionLoadInfo] {
		return all
	}

	private static func info(for missionFolder: String) -> MissionLoadInfo? {
		return byFolder[missionFolder.lowercased()]
	}

	private static let all: [MissionLoadInfo] = loadLoadDefinitions()
	private static let byFolder: [String: MissionLoadInfo] = {
		var records: [String: MissionLoadInfo] = [:]
		for info in all {
			records[info.missionFolder.lowercased()] = info
		}
		return records
	}()

	private static func loadLoadDefinitions() -> [MissionLoadInfo] {
		let url = mainDirectory.appendingPathComponent("tables/load.def")
		guard let data = try? Data(contentsOf: url) else { return [] }

		let recordSize = 68
		var records: [MissionLoadInfo] = []
		for offset in stride(from: 0, to: data.count - recordSize + 1, by: recordSize) {
			let missionFolder = readString(in: data, at: offset, length: 32)
			guard !missionFolder.isEmpty else { continue }

			let imageName = readString(in: data, at: offset + 32, length: 32)
			let textId = Int(readUInt32(in: data, at: offset + 64))
			records.append(MissionLoadInfo(
				missionFolder: missionFolder,
				imageName: imageName,
				textId: textId
			))
		}
		return records
	}

	private static func readString(in data: Data, at offset: Int, length: Int) -> String {
		guard offset + length <= data.count else { return "" }

		let bytes = data[offset ..< offset + length]
		let trimmed = bytes.prefix { $0 != 0 }
		guard !trimmed.isEmpty else { return "" }

		return String(data: Data(trimmed), encoding: .windowsCP1250) ?? ""
	}

	private static func readUInt32(in data: Data, at offset: Int) -> UInt32 {
		guard offset + 4 <= data.count else { return 0 }

		return UInt32(data[offset]) |
			(UInt32(data[offset + 1]) << 8) |
			(UInt32(data[offset + 2]) << 16) |
			(UInt32(data[offset + 3]) << 24)
	}

	private static func resolveImageName(_ imageName: String, fallbackFolder: String?) -> String {
		if let resolvedName = existingMapImageName(imageName) {
			return resolvedName
		}

		if let fallbackFolder = fallbackFolder,
		   let resolvedName = existingMapImageName(fallbackFolder + ".tga") {
			return resolvedName
		}

		return existingMapImageName("00menu.tga") ?? "00menu.tga"
	}

	private static func existingMapImageName(_ imageName: String) -> String? {
		let directUrl = mainDirectory.appendingPathComponent("maps/" + imageName)
		if FileManager.default.fileExists(atPath: directUrl.path) {
			return imageName
		}

		guard let urls = try? FileManager.default.contentsOfDirectory(
			at: mainDirectory.appendingPathComponent("maps"),
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		) else {
			return nil
		}

		return urls.first { $0.lastPathComponent.lowercased() == imageName.lowercased() }?.lastPathComponent
	}
}

enum SaveGame {
	private static let checkpointSignature = Data([0x47, 0x76, 0x61, 0x53]) // SavG
	private static let nestedCheckpointSignature: UInt32 = 0x47766153 // SavG
	private static let streamSeedA: UInt32 = 0x23101976
	private static let streamSeedB: UInt32 = 0x10072002
	private static let saveHeaderSize = 24
	private static let innerHeaderSize = 24
	private static let summarySize = 0x20
	private static let sessionSize = 0x108
	private static let entityHeaderSize = 0x8c
	private static let entityPayloadPrefixSize = 15

	static func loadSlots() -> [SaveGameSlot] {
		let directory = mainDirectory.appendingPathComponent("savegame")
		guard let urls = try? FileManager.default.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: [.fileSizeKey],
			options: [.skipsHiddenFiles]
		) else {
			return []
		}

		return urls.compactMap(loadSlot)
			.sorted {
				if $0.profileNumber != $1.profileNumber {
					return $0.profileNumber < $1.profileNumber
				}
				return $0.checkpointCode < $1.checkpointCode
			}
	}

	private static func loadSlot(url: URL) -> SaveGameSlot? {
		let fileName = url.lastPathComponent.lowercased()
		guard fileName.hasPrefix("mafia"),
			  fileName.count == "mafia000.000".count,
			  let profileNumber = Int(fileName.dropFirst(5).prefix(3)),
			  let checkpointCode = Int(fileName.suffix(3)) else {
			return nil
		}

		guard let checkpoint = loadCheckpoint(url: url) else { return nil }

		let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
		let fileSize = resourceValues?.fileSize ?? 0
		return SaveGameSlot(
			url: url,
			profileNumber: profileNumber,
			checkpointCode: checkpointCode,
			fileSize: UInt64(max(0, fileSize)),
			checkpoint: checkpoint
		)
	}

	private static func loadCheckpoint(url: URL) -> SaveGameCheckpoint? {
		guard let data = try? Data(contentsOf: url),
			  data.count >= saveHeaderSize + innerHeaderSize + summarySize + sessionSize,
			  data.starts(with: checkpointSignature) else {
			return nil
		}

		var cursor = saveHeaderSize
		let decoder = SaveGameStreamDecoder(data: data, seedA: streamSeedA, seedB: streamSeedB)
		let innerHeader = decoder.readEncoded(offset: cursor, size: innerHeaderSize)
		cursor += innerHeaderSize

		let innerSignature = readUInt32(in: innerHeader, at: 0)
		let version = readUInt32(in: innerHeader, at: 4)
		guard innerSignature == nestedCheckpointSignature,
			  version == 0x10 else {
			return nil
		}

		let summaryData = decoder.readEncoded(offset: cursor, size: summarySize)
		let summary = SaveGameSummary(
			checkpointCode: readUInt32(in: summaryData, at: 0),
			saveTimePacked: readUInt32(in: summaryData, at: 8),
			saveDatePacked: readUInt32(in: summaryData, at: 12),
			healthPercent: readUInt32(in: summaryData, at: 16),
			missionTimer: readUInt32(in: summaryData, at: 20),
			unknown1C: readUInt32(in: summaryData, at: 28)
		)
		cursor += summarySize

		let sessionData = decoder.readEncoded(offset: cursor, size: sessionSize)
		let session = SaveGameSession(
			missionFolder: readString(in: sessionData, at: 0, length: 0x20),
			missionStateSize: readUInt32(in: sessionData, at: 0x20),
			unknown24: readUInt32(in: sessionData, at: 0x24),
			missionStateA: readUInt32Array(in: sessionData, at: 0x28, count: 25),
			missionStateB: readUInt32Array(in: sessionData, at: 0x8c, count: 25),
			extraStateASize: readUInt32(in: sessionData, at: 0xf0),
			extraStateBSize: readUInt32(in: sessionData, at: 0xf4),
			globalFlag: readUInt32(in: sessionData, at: 0xf8),
			globalValueA: readUInt32(in: sessionData, at: 0xfc),
			globalValueB: readUInt32(in: sessionData, at: 0x100),
			globalValueC: readUInt32(in: sessionData, at: 0x104)
		)
		cursor += sessionSize

		guard !session.missionFolder.isEmpty else { return nil }

		var variableBlocks: [SaveGameVariableBlock] = []
		for (name, size) in [
			("mission_state", session.missionStateSize),
			("extra_state_a", session.extraStateASize),
			("extra_state_b", session.extraStateBSize),
		] {
			guard let blockSize = Int(exactly: size),
				  cursor + blockSize <= data.count else {
				return nil
			}
			let blockData = decoder.readEncoded(offset: cursor, size: blockSize)
			variableBlocks.append(SaveGameVariableBlock(name: name, offset: cursor, size: size, data: blockData))
			cursor += blockSize
		}

		var entities: [SaveGameEntity] = []
		while cursor + entityHeaderSize <= data.count {
			let entityOffset = cursor
			let header = decoder.readEncoded(offset: cursor, size: entityHeaderSize)
			let payloadSize = readUInt32(in: header, at: 0x84)
			guard let payloadByteCount = Int(exactly: payloadSize) else { return nil }

			let payloadOffset = cursor + entityHeaderSize
			let payloadEnd = payloadOffset + payloadByteCount
			guard payloadEnd <= data.count else { return nil }

			let payload = decoder.readEncoded(offset: payloadOffset, size: payloadByteCount)
			let objectTypeRawValue = readUInt32(in: header, at: 0x80)
			entities.append(SaveGameEntity(
				offset: entityOffset,
				name: readString(in: header, at: 0, length: 0x40),
				modelName: readString(in: header, at: 0x40, length: 0x40),
				objectTypeRawValue: objectTypeRawValue,
				payloadSize: payloadSize,
				playerSlot: readInt32(in: header, at: 0x88),
				payloadPrefix: readPayloadPrefix(in: payload),
				position: readPosition(objectTypeRawValue: objectTypeRawValue, payload: payload),
				doorState: readDoorState(objectTypeRawValue: objectTypeRawValue, payload: payload),
				payload: payload
			))
			cursor = payloadEnd
		}

		guard cursor == data.count else { return nil }

		return SaveGameCheckpoint(
			innerSignature: innerSignature,
			version: version,
			checkpointCode: readUInt32(in: innerHeader, at: 8),
			checkpointMarker: readUInt32(in: innerHeader, at: 20),
			summary: summary,
			session: session,
			variableBlocks: variableBlocks,
			entities: entities
		)
	}

	private static func readString(in data: Data, at offset: Int, length: Int) -> String {
		guard offset + length <= data.count else { return "" }

		let bytes = data[offset ..< offset + length]
		let trimmed = bytes.prefix { $0 != 0 }
		guard !trimmed.isEmpty else { return "" }

		return String(data: Data(trimmed), encoding: .windowsCP1250) ?? ""
	}

	private static func readUInt32(in data: Data, at offset: Int) -> UInt32 {
		guard offset + 4 <= data.count else { return 0 }

		return UInt32(data[offset]) |
			(UInt32(data[offset + 1]) << 8) |
			(UInt32(data[offset + 2]) << 16) |
			(UInt32(data[offset + 3]) << 24)
	}

	private static func readUInt16(in data: Data, at offset: Int) -> UInt16 {
		guard offset + 2 <= data.count else { return 0 }

		return UInt16(data[offset]) |
			(UInt16(data[offset + 1]) << 8)
	}

	private static func readInt32(in data: Data, at offset: Int) -> Int32 {
		return Int32(bitPattern: readUInt32(in: data, at: offset))
	}

	private static func readFloat32(in data: Data, at offset: Int) -> Float {
		return Float(bitPattern: readUInt32(in: data, at: offset))
	}

	private static func readUInt32Array(in data: Data, at offset: Int, count: Int) -> [UInt32] {
		return (0 ..< count).map { readUInt32(in: data, at: offset + ($0 * 4)) }
	}

	private static func readPayloadPrefix(in payload: Data) -> SaveGameEntityPayloadPrefix? {
		guard payload.count >= entityPayloadPrefixSize else { return nil }

		return SaveGameEntityPayloadPrefix(
			version: payload[0],
			group: payload[1],
			sceneObjectId: readUInt16(in: payload, at: 2),
			stateA: readUInt32(in: payload, at: 4),
			stateB: readUInt32(in: payload, at: 8),
			stateC: readUInt16(in: payload, at: 12),
			stateD: payload[14]
		)
	}

	private static func readPosition(objectTypeRawValue: UInt32, payload: Data) -> SaveGameVector3? {
		let positionOffset: Int
		switch ObjectDefinitionType(rawValue: objectTypeRawValue) {
		case .player:
			positionOffset = 14
		case .car:
			// Dynamic car records use subtype 9 before their transform; static car variants store embedded model data here.
			guard payload.count > 13, payload[13] == 9 else { return nil }
			positionOffset = 21
		default:
			return nil
		}
		guard payload.count >= positionOffset + 12 else { return nil }

		return SaveGameVector3(
			x: readFloat32(in: payload, at: positionOffset),
			y: readFloat32(in: payload, at: positionOffset + 4),
			z: readFloat32(in: payload, at: positionOffset + 8)
		)
	}

	private static func readDoorState(objectTypeRawValue: UInt32, payload: Data) -> SaveGameDoorState? {
		guard objectTypeRawValue == ObjectDefinitionType.door.rawValue,
			  payload.count >= 25 else {
			return nil
		}

		return SaveGameDoorState(
			angle: readFloat32(in: payload, at: 15),
			rawState: readUInt32(in: payload, at: 19),
			flags: readUInt16(in: payload, at: 23)
		)
	}
}

private final class SaveGameStreamDecoder {
	private let data: Data
	private var seedA: UInt32
	private var seedB: UInt32

	init(data: Data, seedA: UInt32, seedB: UInt32) {
		self.data = data
		self.seedA = seedA
		self.seedB = seedB
	}

	func readEncoded(offset: Int, size: Int) -> Data {
		guard offset + size <= data.count else { return Data() }

		var decoded = Data(data[offset ..< offset + size])
		var wordOffset = 0
		while wordOffset + 4 <= decoded.count {
			let encryptedWord = readUInt32(in: decoded, at: wordOffset)
			let plainWord = encryptedWord ^ seedA
			writeUInt32(plainWord, in: &decoded, at: wordOffset)
			seedB = seedB &+ plainWord
			seedA = seedA &+ seedB
			wordOffset += 4
		}

		return decoded
	}

	private func readUInt32(in data: Data, at offset: Int) -> UInt32 {
		guard offset + 4 <= data.count else { return 0 }

		return UInt32(data[offset]) |
			(UInt32(data[offset + 1]) << 8) |
			(UInt32(data[offset + 2]) << 16) |
			(UInt32(data[offset + 3]) << 24)
	}

	private func writeUInt32(_ value: UInt32, in data: inout Data, at offset: Int) {
		guard offset + 4 <= data.count else { return }

		data[offset] = UInt8(value & 0xff)
		data[offset + 1] = UInt8((value >> 8) & 0xff)
		data[offset + 2] = UInt8((value >> 16) & 0xff)
		data[offset + 3] = UInt8((value >> 24) & 0xff)
	}
}
