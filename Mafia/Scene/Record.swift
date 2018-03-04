//
//  Record.swift
//  Mafia
//
//  Created by Alex Studnička on 10/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

final class Record {

	enum Error: Swift.Error {
		case file
	}

	init(name: String) throws {
		let url = mainDirectory.appendingPathComponent("/records/"+name.lowercased())

		guard let stream = InputStream(url: url) else { throw Error.file }
		stream.open()

		stream.currentOffset += 12
		let modelsCount: Int32 = try stream.read()
		stream.currentOffset += 80

		let animationNamesCount: Int32 = try stream.read()
		stream.currentOffset += 4

		var animations: [String] = []
		for _ in 0 ..< animationNamesCount {
			let _: Int32 = try stream.read()
			let animName: String = try stream.read(maxLength: 48)
			animations.append(animName)
			print("animName:", animName)
		}

		for _ in 0 ..< modelsCount {
			let name1: String = try stream.read(maxLength: 36)
			let name2: String = try stream.read(maxLength: 36)
			stream.currentOffset += 36
			print("NAMES:", name1, name2)
		}
	}

}
