//
//  Mission6RaceTables.swift
//  Mafia
//
//  Created by Codex on 25/06/2026.
//  Copyright © 2026 Alex Studnicka. All rights reserved.
//

import Foundation

struct Mission6RaceTableError: Error { }

struct Mission6RaceCircuit {
	let name: String
	let missionName: String
	let raceCount: UInt32
	let unknown: UInt32
	let bestTimes: [UInt32]
	let qualifyingTimes: [UInt32]
}

struct Mission6RaceChampionship {
	let id: UInt32
	let raceCount: UInt32
	let unknown0: UInt32
	let unknown1: UInt32
	let unknown2: UInt32
	let circuitIndices: [UInt32]
	let circuitSettings: [UInt32]
	let raceCircuitIndices: [UInt32]
	let raceSettings: [UInt32]
}

struct Mission6RaceParticipantProfile {
	let name: String
	let vehicleClass: UInt32
	let skillMultiplier: Float
}

struct Mission6CarcyclopediaRecord {
	let index: Int
	let rawType: UInt32
	let nativeRankCount: UInt32
	let rawFields: [UInt32]

	var nativeRankLimit: UInt32 {
		nativeRankCount == 0 ? 0 : nativeRankCount - 1
	}
}

struct Mission6CarIndexRecord {
	let index: Int
	let key: String
	let modelName: String
	let shadowModelName: String?
	let displayName: String?
	let nativeCollectionMask: UInt32
	let rawFields: [UInt32]
}

final class Mission6RaceTables {
	private static let circuitRecordSize = 0x88
	private static let championshipRecordSize = 0xb8
	private static let carIndexRecordSize = 0xa4
	private static let carcyclopediaRecordSize = 0xcc
	private static let nativeRaceSlotCount = 7
	private static let nativeChampionshipSlotCount = 10

	let circuits: [Mission6RaceCircuit]
	let championships: [Mission6RaceChampionship]
	let carIndex: [Mission6CarIndexRecord]
	let carcyclopedia: [Mission6CarcyclopediaRecord]
	let participantProfiles = Mission6RaceTables.nativeParticipantProfiles

	init() throws {
		circuits = try Self.loadCircuits()
		championships = try Self.loadChampionships()
		carIndex = try Self.loadCarIndex()
		carcyclopedia = try Self.loadCarcyclopedia()
	}

	func circuit(at index: Int) -> Mission6RaceCircuit? {
		guard circuits.indices.contains(index) else { return nil }
		return circuits[index]
	}

	func carcyclopediaRecord(at index: Int) -> Mission6CarcyclopediaRecord? {
		guard carcyclopedia.indices.contains(index) else { return nil }
		return carcyclopedia[index]
	}

	func carIndexRecord(at index: Int) -> Mission6CarIndexRecord? {
		guard carIndex.indices.contains(index) else { return nil }
		return carIndex[index]
	}

	private static func loadCircuits() throws -> [Mission6RaceCircuit] {
		let url = mainDirectory.appendingPathComponent("tables/circuits.def")
		let data = try Data(contentsOf: url)
		guard data.count % circuitRecordSize == 0 else {
			throw Mission6RaceTableError()
		}

		var loadedCircuits: [Mission6RaceCircuit] = []
		loadedCircuits.reserveCapacity(data.count / circuitRecordSize)
		for offset in stride(from: 0, to: data.count, by: circuitRecordSize) {
			loadedCircuits.append(Mission6RaceCircuit(
				name: data.mission6RaceReadNullTerminatedString(at: offset, length: 0x20),
				missionName: data.mission6RaceReadNullTerminatedString(at: offset + 0x20, length: 0x20),
				raceCount: data.mission6RaceReadUInt32LE(at: offset + 0x40),
				unknown: data.mission6RaceReadUInt32LE(at: offset + 0x44),
				bestTimes: data.mission6RaceReadUInt32LEArray(at: offset + 0x48, count: nativeRaceSlotCount),
				qualifyingTimes: data.mission6RaceReadUInt32LEArray(at: offset + 0x68, count: nativeRaceSlotCount)
			))
		}
		return loadedCircuits
	}

	private static func loadChampionships() throws -> [Mission6RaceChampionship] {
		let url = mainDirectory.appendingPathComponent("tables/championship.def")
		let data = try Data(contentsOf: url)
		guard data.count % championshipRecordSize == 0 else {
			throw Mission6RaceTableError()
		}

		var loadedChampionships: [Mission6RaceChampionship] = []
		loadedChampionships.reserveCapacity(data.count / championshipRecordSize)
		for offset in stride(from: 0, to: data.count, by: championshipRecordSize) {
			let circuitCount = Int(data.mission6RaceReadUInt32LE(at: offset + 0x14))
			guard circuitCount <= nativeChampionshipSlotCount else {
				throw Mission6RaceTableError()
			}

			let raceCount = Int(data.mission6RaceReadUInt32LE(at: offset + 0x04))
			guard raceCount <= nativeRaceSlotCount else {
				throw Mission6RaceTableError()
			}

			loadedChampionships.append(Mission6RaceChampionship(
				id: data.mission6RaceReadUInt32LE(at: offset),
				raceCount: UInt32(raceCount),
				unknown0: data.mission6RaceReadUInt32LE(at: offset + 0x08),
				unknown1: data.mission6RaceReadUInt32LE(at: offset + 0x0c),
				unknown2: data.mission6RaceReadUInt32LE(at: offset + 0x10),
				circuitIndices: data.mission6RaceReadUInt32LEArray(at: offset + 0x18, count: circuitCount),
				circuitSettings: data.mission6RaceReadUInt32LEArray(at: offset + 0x40, count: circuitCount),
				raceCircuitIndices: data.mission6RaceReadUInt32LEArray(at: offset + 0x68, count: raceCount),
				raceSettings: data.mission6RaceReadUInt32LEArray(at: offset + 0x90, count: raceCount)
			))
		}
		return loadedChampionships
	}

	private static func loadCarIndex() throws -> [Mission6CarIndexRecord] {
		let url = mainDirectory.appendingPathComponent("tables/carindex.def")
		let data = try Data(contentsOf: url)
		let recordCount = data.count / carIndexRecordSize

		var loadedRecords: [Mission6CarIndexRecord] = []
		loadedRecords.reserveCapacity(recordCount)
		for index in 0..<recordCount {
			let offset = index * carIndexRecordSize
			loadedRecords.append(Mission6CarIndexRecord(
				index: index,
				key: data.mission6RaceReadNullTerminatedString(at: offset, length: 0x20),
				modelName: data.mission6RaceReadNullTerminatedString(at: offset + 0x20, length: 0x20),
				shadowModelName: data.mission6RaceReadNullTerminatedString(at: offset + 0x40, length: 0x20),
				displayName: data.mission6RaceReadNullTerminatedString(at: offset + 0x60, length: 0x40),
				nativeCollectionMask: data.mission6RaceReadUInt32LE(at: offset + 0xa0),
				rawFields: data.mission6RaceReadUInt32LEArray(at: offset, count: carIndexRecordSize / 4)
			))
		}
		return loadedRecords
	}

	private static func loadCarcyclopedia() throws -> [Mission6CarcyclopediaRecord] {
		let url = mainDirectory.appendingPathComponent("tables/carcyclopedia.def")
		let data = try Data(contentsOf: url)
		let recordCount = data.count / carcyclopediaRecordSize

		var loadedRecords: [Mission6CarcyclopediaRecord] = []
		loadedRecords.reserveCapacity(recordCount)
		for index in 0..<recordCount {
			let offset = index * carcyclopediaRecordSize
			loadedRecords.append(Mission6CarcyclopediaRecord(
				index: index,
				rawType: data.mission6RaceReadUInt32LE(at: offset + 0xb0),
				nativeRankCount: data.mission6RaceReadUInt32LE(at: offset + 0xa8),
				rawFields: data.mission6RaceReadUInt32LEArray(at: offset, count: carcyclopediaRecordSize / 4)
			))
		}
		return loadedRecords
	}

	private static let nativeParticipantProfiles: [Mission6RaceParticipantProfile] = [
		Mission6RaceParticipantProfile(name: "Martin Lichtenberg", vehicleClass: 0x3d, skillMultiplier: Float(bitPattern: 0x3f866666)),
		Mission6RaceParticipantProfile(name: "Mark Greenway", vehicleClass: 0x3b, skillMultiplier: Float(bitPattern: 0x3f851eb8)),
		Mission6RaceParticipantProfile(name: "David Vincent", vehicleClass: 0x3c, skillMultiplier: Float(bitPattern: 0x3f83d70a)),
		Mission6RaceParticipantProfile(name: "Peter T\u{e4}gtgren", vehicleClass: 0x3d, skillMultiplier: Float(bitPattern: 0x3f828f5c)),
		Mission6RaceParticipantProfile(name: "Bill Steer", vehicleClass: 0x3a, skillMultiplier: Float(bitPattern: 0x3f8147ae)),
		Mission6RaceParticipantProfile(name: "Chris Barnes", vehicleClass: 0x39, skillMultiplier: Float(bitPattern: 0x3f800000)),
		Mission6RaceParticipantProfile(name: "Kirk Windstein", vehicleClass: 0x3b, skillMultiplier: Float(bitPattern: 0x3f800000)),
		Mission6RaceParticipantProfile(name: "Thomas Warrior", vehicleClass: 0x3c, skillMultiplier: Float(bitPattern: 0x3f800000)),
		Mission6RaceParticipantProfile(name: "Page Hamilton", vehicleClass: 0x3d, skillMultiplier: Float(bitPattern: 0x3f7d70a4)),
		Mission6RaceParticipantProfile(name: "Mick Harris", vehicleClass: 0x3a, skillMultiplier: Float(bitPattern: 0x3f7ae148)),
		Mission6RaceParticipantProfile(name: "Will Rahmer", vehicleClass: 0x39, skillMultiplier: Float(bitPattern: 0x3f7851ec)),
		Mission6RaceParticipantProfile(name: "Ron Royce", vehicleClass: 0x3b, skillMultiplier: Float(bitPattern: 0x3f75c28f)),
		Mission6RaceParticipantProfile(name: "Georgio Popino", vehicleClass: 0x3c, skillMultiplier: Float(bitPattern: 0x3f866666)),
		Mission6RaceParticipantProfile(name: "John Perez", vehicleClass: 0x3d, skillMultiplier: Float(bitPattern: 0x3f733333))
	]
}

private extension Data {
	func mission6RaceReadUInt32LE(at offset: Int) -> UInt32 {
		UInt32(self[offset]) |
			UInt32(self[offset + 1]) << 8 |
			UInt32(self[offset + 2]) << 16 |
			UInt32(self[offset + 3]) << 24
	}

	func mission6RaceReadUInt32LEArray(at offset: Int, count: Int) -> [UInt32] {
		(0..<count).map { mission6RaceReadUInt32LE(at: offset + $0 * 4) }
	}

	func mission6RaceReadNullTerminatedString(at offset: Int, length: Int) -> String {
		let end = Swift.min(offset + length, count)
		let bytes = self[offset..<end]
		let stringBytes = bytes.prefix { $0 != 0 }
		return String(bytes: stringBytes, encoding: .windowsCP1250)
			?? String(bytes: stringBytes, encoding: .isoLatin1)
			?? ""
	}

	func mission6RaceEmbeddedStrings(at offset: Int, length: Int) -> [String] {
		let end = Swift.min(offset + length, count)
		var strings: [String] = []
		var stringStart: Int?

		func isPrintable(_ byte: UInt8) -> Bool {
			(0x20...0x7e).contains(byte) || byte >= 0x80
		}

		func appendString(endingAt stringEnd: Int) {
			guard let start = stringStart, stringEnd - start >= 3 else {
				stringStart = nil
				return
			}
			let bytes = self[start..<stringEnd]
			let string = String(bytes: bytes, encoding: .windowsCP1250)
				?? String(bytes: bytes, encoding: .isoLatin1)
				?? ""
			if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				strings.append(string)
			}
			stringStart = nil
		}

		for index in offset..<end {
			if isPrintable(self[index]) {
				if stringStart == nil {
					stringStart = index
				}
			} else {
				appendString(endingAt: index)
			}
		}
		appendString(endingAt: end)
		return strings
	}
}
