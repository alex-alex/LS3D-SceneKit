//
//  TextDb.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/15/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import Foundation

final class TextDb {
	
	enum Error: Swift.Error {
		case file
	}
	
	static var db: [UInt32: String] = [:]
	
	static func load(lang: String = "cz") throws {
		let url = mainDirectory.appendingPathComponent("/tables/textdb_\(lang).def")
		
		guard let stream = InputStream(url: url) else { throw Error.file }
		stream.open()
		
		let _textCount: UInt32 = try stream.read()
		let textCount = Int(_textCount)
		
		stream.currentOffset += 4
		
		var positions: [(id: UInt32, pos: UInt32)] = []
		for _ in 0 ..< textCount {
			let textId: UInt32 = try stream.read()
			let textPos: UInt32 = try stream.read()
			positions.append((textId, textPos))
		}
		
		var table: [UInt32: String] = [:]
		for i in 0 ..< textCount {
			let cur = positions[i]
			if i < textCount - 1 {
				let next = positions[i + 1]
				let len = Int(next.pos - cur.pos)
				stream.currentOffset = Int(cur.pos)
				let str: String = try stream.read(maxLength: len, encoding: .windowsCP1250)
				table[cur.id] = str
			}
		}
		
		db = table
	}
	
	static func get(_ val: Int) -> String? {
		return db[UInt32(val)]
	}
	
}
