//
//  MaterialDef.swift
//  Mafia
//
//  Created by Codex on 03/06/2026.
//  Copyright 2026 Alex Studnicka. All rights reserved.
//

import Foundation

struct MaterialDef {
	enum Error: Swift.Error {
		case malformedFile
	}

	static let recordSize = 368
	static let nameSize = 32
	static let payloadSize = recordSize - nameSize

	let id: UInt8
	let name: String
	let payload: Data

	static let crashCollisionId: UInt8 = 41

	static let all: [MaterialDef] = {
		do {
			return try load()
		} catch {
			fatalError("Unable to load tables/materials.def: \(error)")
		}
	}()

	static let byId: [UInt8: MaterialDef] = {
		var values: [UInt8: MaterialDef] = [:]
		for material in all {
			values[material.id] = material
		}
		return values
	}()

	static func get(_ id: UInt8) -> MaterialDef? {
		return byId[id]
	}

	static func name(for id: UInt8) -> String? {
		return get(id)?.name
	}

	static func load(url: URL = mainDirectory.appendingPathComponent("tables/materials.def")) throws -> [MaterialDef] {
		let data = try Data(contentsOf: url)
		guard data.count % recordSize == 0 else { throw Error.malformedFile }

		var materials: [MaterialDef] = []
		materials.reserveCapacity(data.count / recordSize)

		for index in 0 ..< data.count / recordSize {
			let offset = index * recordSize
			guard let id = UInt8(exactly: index) else { throw Error.malformedFile }
			let name = data.zeroTerminatedString(at: offset, maxLength: nameSize)
			let payloadStart = offset + nameSize
			let payloadEnd = payloadStart + payloadSize
			let payload = data.subdata(in: payloadStart..<payloadEnd)
			materials.append(MaterialDef(id: id, name: name, payload: payload))
		}

		return materials
	}
}

private extension Data {
	func zeroTerminatedString(at offset: Int, maxLength: Int) -> String {
		guard offset >= 0, offset < count else { return "" }
		let end = Swift.min(offset + maxLength, count)
		var bytes: [UInt8] = []
		for index in offset ..< end {
			let byte = self[index]
			guard byte != 0 else { break }
			bytes.append(byte)
		}
		return String(bytes: bytes, encoding: .windowsCP1250) ?? String(bytes: bytes, encoding: .isoLatin1) ?? ""
	}
}
