//
//  Weapon.swift
//  Mafia
//
//  Created by Alex Studnička on 07/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

final class Weapon: @unchecked Sendable {

	enum Position {
		case hand
		case inventory
	}

	struct Profile {
		let clipSize: Int
		let shotInterval: TimeInterval
		let isFullAuto: Bool
		let range: SCNFloat
		let impulse: SCNFloat
		let pelletCount: Int
		let spread: SCNFloat
		let animationSetId: Int
		let fireSoundName: String?
		let reloadSoundName: String?
	}

	struct Definition {
		let name: String
		let itemKind: Int
		let itemFlags: Int
		let concealment: Int
		let magazineState: Int
		let modelName: String
		let weaponTypeValues: [Int]
		let fireSoundId: Int
		let reloadSoundId: Int
		let handlingStyle: Int
		let clipSize: Int
		let reserveAmmoCapacity: Int
		let projectileMask: Float
		let projectileFragmentation: Float
		let aimDeviation: Float
		let maximumRange: Float
		let damage: Float
		let auxiliaryValue1: Float
		let auxiliaryValue2: Float
		let recoil: Float
		let accuracy: Float
		let cadenceValues: [Int]
		let postShotReloadValues: [Int]
		let profile: Profile?
	}

	private static let recordSize = 188

	let uuid = NSUUID()
	let id: Int
	var clipAmmo: Int = 0
	var restAmmo: Int = 0
	var position: Position = .inventory

	var name: String {
		return definition.name
	}

	var modelName: String {
		return definition.modelName
	}

	var profile: Profile? {
		return definition.profile
	}

	var itemDefinition: Definition {
		return definition
	}

	var isFirearm: Bool {
		return profile != nil
	}

	var isBaseballBat: Bool {
		let normalizedName = name.lowercased()
		let normalizedModelName = modelName.lowercased()
		return normalizedName.contains("bat") ||
			normalizedModelName.contains("2bbat") ||
			normalizedModelName.contains("basb")
	}

	var hasAmmoLoaded: Bool {
		return clipAmmo == -1 || clipAmmo > 0
	}

	var canReload: Bool {
		guard let profile = profile, clipAmmo >= 0, restAmmo > 0 else { return false }
		return clipAmmo < profile.clipSize
	}

	private var definition: Definition {
		guard let definition = Weapon.definitions[id] else {
			fatalError("Missing weapon definition for id \(id)")
		}
		return definition
	}

	private static let definitions: [Int: Definition] = loadDefinitions()

	init(id: Int, clipAmmo: Int = 0, restAmmo: Int = 0) {
		self.id = id
		self.clipAmmo = clipAmmo
		self.restAmmo = restAmmo
	}

	static func hasDefinition(for id: Int) -> Bool {
		return definitions[id] != nil
	}

	static var allDefinitionIds: [Int] {
		return definitions.keys.sorted()
	}

}

private extension Weapon {

	static func loadDefinitions() -> [Int: Definition] {
		let itemURL = mainDirectory.appendingPathComponent("tables/predmety.def")
		guard let data = try? Data(contentsOf: itemURL), data.count >= recordSize else {
			fatalError("Unable to load tables/predmety.def")
		}

		let soundNames = loadSoundNames()
		var definitions: [Int: Definition] = [:]
		for id in 0..<(data.count / recordSize) {
			let offset = id * recordSize
			let name = data.zeroTerminatedString(at: offset, maxLength: 32)
			let itemKind = data.uint8(at: offset + 32)
			let itemFlags = data.uint8(at: offset + 33)
			let concealment = data.uint8(at: offset + 34)
			let magazineState = data.uint8(at: offset + 35)
			let modelName = data.zeroTerminatedString(at: offset + 36, maxLength: 32)
			let weaponTypeValues = stride(from: 68, through: 80, by: 4).map { data.int32(at: offset + $0) }
			let fireSoundId = data.int32(at: offset + 84)
			let reloadSoundId = data.int32(at: offset + 88)
			let handlingStyle = data.int32(at: offset + 92)
			let clipSize = data.int32(at: offset + 96)
			let reserveAmmoCapacity = data.int32(at: offset + 100)
			let projectileMask = data.float32(at: offset + 104)
			let projectileFragmentation = data.float32(at: offset + 108)
			let aimDeviation = data.float32(at: offset + 112)
			let maximumRange = data.float32(at: offset + 116)
			let damage = data.float32(at: offset + 120)
			let auxiliaryValue1 = data.float32(at: offset + 124)
			let auxiliaryValue2 = data.float32(at: offset + 128)
			let recoil = data.float32(at: offset + 132)
			let accuracy = data.float32(at: offset + 136)
			let cadenceValues = stride(from: 140, through: 164, by: 4).map { data.int32(at: offset + $0) }
			let postShotReloadValues = stride(from: 168, through: 184, by: 4).map { data.int32(at: offset + $0) }
			let firstShotIntervalMs = cadenceValues[1]
			let repeatShotIntervalMs = cadenceValues[3]
			let intervalMs = firstShotIntervalMs > 0 ? firstShotIntervalMs : repeatShotIntervalMs
			let animationSetId = weaponTypeValues[0]

			let profile: Profile?
			if handlingStyle > 0, clipSize > 0 {
				let fireSoundName: String?
				if fireSoundId > 0 {
					guard let soundName = soundNames[fireSoundId] else {
						fatalError("Missing sound definition for weapon \(id), sound id \(fireSoundId)")
					}
					fireSoundName = soundName
				} else {
					fireSoundName = nil
				}
				let reloadSoundName: String?
				if reloadSoundId > 0 {
					guard let soundName = soundNames[reloadSoundId] else {
						fatalError("Missing reload sound definition for weapon \(id), sound id \(reloadSoundId)")
					}
					reloadSoundName = soundName
				} else {
					reloadSoundName = nil
				}

				let pelletCount = handlingStyle == 3 && clipSize <= 8 && id != 10 && id != 33 ? 8 : 1
				profile = Profile(
					clipSize: clipSize,
					shotInterval: TimeInterval(max(60, intervalMs)) / 1000,
					isFullAuto: firstShotIntervalMs == 0 && repeatShotIntervalMs > 0,
					range: max(30, min(SCNFloat(maximumRange), 180)),
					impulse: max(8, min(SCNFloat(aimDeviation), 36)),
					pelletCount: pelletCount,
					spread: spreadForWeapon(id: id, weaponClass: handlingStyle, tableSpread: recoil),
					animationSetId: animationSetId,
					fireSoundName: fireSoundName,
					reloadSoundName: reloadSoundName
				)
			} else {
				profile = nil
			}

			definitions[id] = Definition(
				name: name,
				itemKind: itemKind,
				itemFlags: itemFlags,
				concealment: concealment,
				magazineState: magazineState,
				modelName: modelName,
				weaponTypeValues: weaponTypeValues,
				fireSoundId: fireSoundId,
				reloadSoundId: reloadSoundId,
				handlingStyle: handlingStyle,
				clipSize: clipSize,
				reserveAmmoCapacity: reserveAmmoCapacity,
				projectileMask: projectileMask,
				projectileFragmentation: projectileFragmentation,
				aimDeviation: aimDeviation,
				maximumRange: maximumRange,
				damage: damage,
				auxiliaryValue1: auxiliaryValue1,
				auxiliaryValue2: auxiliaryValue2,
				recoil: recoil,
				accuracy: accuracy,
				cadenceValues: cadenceValues,
				postShotReloadValues: postShotReloadValues,
				profile: profile
			)
		}
		return definitions
	}

	static func loadSoundNames() -> [Int: String] {
		let soundURL = mainDirectory.appendingPathComponent("tables/sounds.dat")
		guard let data = try? Data(contentsOf: soundURL) else {
			fatalError("Unable to load tables/sounds.dat")
		}

		var sounds: [Int: String] = [:]
		var offset = 0
		while offset + 18 < data.count {
			defer { offset += 1 }

			let titleLength = data.int32(at: offset)
			guard titleLength > 0, titleLength <= 64 else { continue }

			let titleOffset = offset + 4
			let soundIdOffset = titleOffset + titleLength
			let categoryOffset = soundIdOffset + 4
			let fileLengthOffset = categoryOffset + 6
			guard fileLengthOffset + 4 < data.count else { continue }
			guard data.isPrintableString(at: titleOffset, length: titleLength) else { continue }

			let soundId = data.int32(at: soundIdOffset)
			let categoryId = data.int32(at: categoryOffset)
			let fileLength = data.int32(at: fileLengthOffset)
			let fileOffset = fileLengthOffset + 4
			guard soundId > 0, categoryId >= 0, categoryId < 64, fileLength > 0, fileLength <= 64 else { continue }
			guard fileOffset + fileLength <= data.count else { continue }
			guard data.isPrintableString(at: fileOffset, length: fileLength) else { continue }

			let fileName = data.string(at: fileOffset, length: fileLength)
			guard fileName.lowercased().hasSuffix(".wav") else { continue }
			sounds[soundId] = fileName
		}
		return sounds
	}

	static func spreadForWeapon(id: Int, weaponClass: Int, tableSpread: Float) -> SCNFloat {
		if weaponClass == 3 && id != 10 && id != 33 {
			return id == 12 ? 0.075 : 0.045
		}
		if weaponClass == 2 {
			return 0.003
		}
		if id == 10 || id == 33 {
			return 0.012
		}
		return max(0.004, min(SCNFloat(tableSpread) * 0.015, 0.014))
	}

}

private extension Data {

	func uint8(at offset: Int) -> Int {
		guard offset < count else { return 0 }
		return Int(self[offset])
	}

	func int32(at offset: Int) -> Int {
		guard offset + 4 <= count else { return 0 }
		let value = UInt32(self[offset]) |
			(UInt32(self[offset + 1]) << 8) |
			(UInt32(self[offset + 2]) << 16) |
			(UInt32(self[offset + 3]) << 24)
		return Int(Int32(bitPattern: value))
	}

	func float32(at offset: Int) -> Float {
		guard offset + 4 <= count else { return 0 }
		let bits = UInt32(self[offset]) |
			(UInt32(self[offset + 1]) << 8) |
			(UInt32(self[offset + 2]) << 16) |
			(UInt32(self[offset + 3]) << 24)
		return Float(bitPattern: bits)
	}

	func zeroTerminatedString(at offset: Int, maxLength: Int) -> String {
		guard offset < count else { return "" }
		let end = Swift.min(offset + maxLength, count)
		var bytes: [UInt8] = []
		for index in offset..<end {
			let byte = self[index]
			guard byte != 0 else { break }
			bytes.append(byte)
		}
		return String(bytes: bytes, encoding: .windowsCP1250) ?? String(bytes: bytes, encoding: .isoLatin1) ?? ""
	}

	func string(at offset: Int, length: Int) -> String {
		let end = Swift.min(offset + length, count)
		let bytes = Array(self[offset..<end])
		return String(bytes: bytes, encoding: .windowsCP1250) ?? String(bytes: bytes, encoding: .isoLatin1) ?? ""
	}

	func isPrintableString(at offset: Int, length: Int) -> Bool {
		guard offset >= 0, length > 0, offset + length <= count else { return false }
		for index in offset..<(offset + length) {
			let byte = self[index]
			if byte < 32 || byte == 127 || byte == 0xcc {
				return false
			}
		}
		return true
	}

}
