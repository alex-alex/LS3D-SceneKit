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
		guard let checkpoint = checkpoint else {
			return String(format: "%03d  Unsupported checkpoint", checkpointCode)
		}
		return String(format: "%03d  %@", checkpointCode, MissionLoadInfo.title(for: checkpoint.missionFolder))
	}

	var missionFolder: String? {
		return checkpoint?.missionFolder
	}

	var imageName: String {
		return MissionLoadInfo.imageName(for: missionFolder)
	}

	var textId: Int {
		guard let missionFolder = missionFolder else { return 0 }
		return MissionLoadInfo.textId(for: missionFolder)
	}
}

struct SaveGameCheckpoint {
	let missionFolder: String
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

		guard hasCheckpointSignature(url: url) else { return nil }

		let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
		let fileSize = resourceValues?.fileSize ?? 0
		return SaveGameSlot(
			url: url,
			profileNumber: profileNumber,
			checkpointCode: checkpointCode,
			fileSize: UInt64(max(0, fileSize)),
			checkpoint: checkpoints[checkpointCode]
		)
	}

	private static func hasCheckpointSignature(url: URL) -> Bool {
		guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
		defer {
			handle.closeFile()
		}
		return handle.readData(ofLength: checkpointSignature.count) == checkpointSignature
	}

	private static func checkpoint(_ missionFolder: String) -> SaveGameCheckpoint {
		return SaveGameCheckpoint(missionFolder: missionFolder)
	}

	private static let checkpoints: [Int: SaveGameCheckpoint] = [
		0: checkpoint("mise01"),
		5: checkpoint("mise02a-taxi"),
		10: checkpoint("mise02a-taxi"),
		15: checkpoint("mise02a-taxi"),
		20: checkpoint("mise02a-taxi"),
		25: checkpoint("mise02a-taxi"),
		30: checkpoint("mise02-saliery"),
		35: checkpoint("mise03-saliery"),
		40: checkpoint("mise03-saliery"),
		45: checkpoint("mise03-morello"),
		50: checkpoint("mise04-saliery"),
		55: checkpoint("mise04-mesto"),
		60: checkpoint("mise04-motorest"),
		65: checkpoint("mise04-krajina"),
		70: checkpoint("mise05-saliery"),
		75: checkpoint("mise05-mesto"),
		80: checkpoint("mise06-autodrom"),
		85: checkpoint("mise06-mesto"),
		90: checkpoint("mise06-saliery"),
		95: checkpoint("mise06-saliery"),
		100: checkpoint("mise06-mesto"),
		105: checkpoint("mise06-autodrom"),
		110: checkpoint("mise06-autodrom"),
		115: checkpoint("mise06-mesto"),
		125: checkpoint("mise07-saliery"),
		130: checkpoint("mise07-sara"),
		131: checkpoint("mise07-sara"),
		135: checkpoint("mise07b-saliery"),
		140: checkpoint("mise07b-saliery"),
		145: checkpoint("mise07b-chuligani"),
		146: checkpoint("mise07b-chuligani"),
		150: checkpoint("mise08-mesto"),
		155: checkpoint("mise08-hotel"),
		160: checkpoint("mise08-hotel"),
		165: checkpoint("mise08-kostel"),
		170: checkpoint("mise08-kostel"),
		185: checkpoint("mise09-saliery"),
		190: checkpoint("mise09-mesto"),
		195: checkpoint("mise09-krajina"),
		197: checkpoint("mise09-krajina"),
		200: checkpoint("mise09-mesto"),
		205: checkpoint("mise09-prejimka"),
		220: checkpoint("mise09-mesto"),
		223: checkpoint("mise09-mesto"),
		225: checkpoint("mise10-saliery"),
		230: checkpoint("mise10-mesto"),
		235: checkpoint("mise10-mesto"),
		240: checkpoint("mise10-letiste"),
		243: checkpoint("mise10-letiste"),
		245: checkpoint("mise10-letiste"),
		260: checkpoint("mise10-mesto"),
		263: checkpoint("mise10-mesto"),
		265: checkpoint("mise11-saliery"),
		270: checkpoint("mise11-mesto"),
		275: checkpoint("mise11-vila"),
		277: checkpoint("mise11-vila"),
		280: checkpoint("mise11-vila"),
		285: checkpoint("mise12-saliery"),
		290: checkpoint("mise12-garage"),
		295: checkpoint("mise12-mesto"),
		300: checkpoint("mise12-saliery"),
		310: checkpoint("mise13-mesto"),
		315: checkpoint("mise13-restaurace"),
		320: checkpoint("mise13-mesto2"),
		325: checkpoint("mise13-zradce"),
		330: checkpoint("mise14-saliery"),
		335: checkpoint("mise14-mesto"),
		340: checkpoint("mise14-parnik"),
		345: checkpoint("mise15-saliery"),
		350: checkpoint("mise15-mesto"),
		355: checkpoint("mise15-saliery"),
		360: checkpoint("mise15-mesto"),
		370: checkpoint("mise15-mesto"),
		372: checkpoint("mise15-mesto"),
		375: checkpoint("mise15-mesto"),
		380: checkpoint("mise15-pristav"),
		385: checkpoint("mise15-pristav"),
		390: checkpoint("mise15-saliery"),
		405: checkpoint("mise15-mesto"),
		407: checkpoint("mise15-mesto"),
		410: checkpoint("mise16-saliery"),
		415: checkpoint("mise16-mesto"),
		425: checkpoint("mise16-krajina"),
		430: checkpoint("mise16-letiste"),
		435: checkpoint("mise16-saliery"),
		450: checkpoint("mise16-mesto"),
		452: checkpoint("mise16-mesto"),
		455: checkpoint("mise17-saliery"),
		460: checkpoint("mise17-mesto"),
		465: checkpoint("mise17-vezeni"),
		466: checkpoint("mise17-vezeni"),
		470: checkpoint("mise17-saliery"),
		485: checkpoint("mise17-mesto"),
		487: checkpoint("mise17-mesto"),
		490: checkpoint("mise18-saliery"),
		495: checkpoint("mise18-mesto"),
		497: checkpoint("mise18-mesto"),
		500: checkpoint("mise18-pristav"),
		505: checkpoint("mise18-pristav"),
		510: checkpoint("mise19-pauli"),
		515: checkpoint("mise19-mesto"),
		520: checkpoint("mise19-banka"),
		525: checkpoint("mise19-mesto"),
		530: checkpoint("mise19-mesto"),
		532: checkpoint("mise19-mesto"),
		535: checkpoint("mise19-banka"),
		540: checkpoint("mise19-mesto"),
		545: checkpoint("mise20-pauli"),
		550: checkpoint("mise20-mesto"),
		555: checkpoint("mise20-mesto"),
		557: checkpoint("mise20-mesto"),
		560: checkpoint("mise20-galery"),
		561: checkpoint("mise20-galery"),
		584: checkpoint("freeride"),
		585: checkpoint("extreme"),
		590: checkpoint("extreme")
	]
}
