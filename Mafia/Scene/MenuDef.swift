//
//  MenuDef.swift
//  Mafia
//
//  Created by Codex on 03/06/2026.
//  Copyright 2026 Alex Studnicka. All rights reserved.
//

import Foundation
import CoreGraphics

struct MenuDefControl {
	let id: UInt32
	let type: String
	let position: CGPoint
	let scaleX: Float
	let scaleY: Float
	let textId: UInt32
	let textColor: UInt32
	let backgroundColor: UInt32
}

final class MenuDef {

	enum Screen: Int {
		case mainMenu = 6
		case gameMenu = 7
		case loadGame = 12
		case gameOver = 48
	}

	enum Error: Swift.Error {
		case file
		case malformedFile
	}

	static let recordSize = 36

	let controls: [MenuDefControl]

	init(url: URL = mainDirectory.appendingPathComponent("tables/menu.def")) throws {
		guard let stream = InputStream(url: url) else { throw Error.file }
		stream.open()
		defer { stream.close() }

		let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
		guard let fileSize = attributes[.size] as? NSNumber else { throw Error.file }
		guard fileSize.intValue % MenuDef.recordSize == 0 else { throw Error.malformedFile }

		var controls: [MenuDefControl] = []
		controls.reserveCapacity(fileSize.intValue / MenuDef.recordSize)

		while stream.currentOffset < fileSize.intValue {
			controls.append(try MenuDef.readControl(stream: stream))
		}

		self.controls = controls
	}

	func controls(for screen: Screen) -> [MenuDefControl] {
		var screens: [[MenuDefControl]] = []
		var currentScreen: [MenuDefControl] = []

		for control in controls {
			currentScreen.append(control)
			if control.type == "pots" {
				screens.append(currentScreen)
				currentScreen.removeAll()
			}
		}

		if !currentScreen.isEmpty {
			screens.append(currentScreen)
		}

		guard screens.indices.contains(screen.rawValue) else { return [] }
		return screens[screen.rawValue]
	}

	private static func readControl(stream: InputStream) throws -> MenuDefControl {
		let id: UInt32 = try stream.read()
		let type = try stream.read(maxLength: 4, encoding: .ascii)
		let position = try CGPoint(stream: stream)
		let scaleX: Float = try stream.read()
		let scaleY: Float = try stream.read()
		let textId: UInt32 = try stream.read()
		let textColor: UInt32 = try stream.read()
		let backgroundColor: UInt32 = try stream.read()

		return MenuDefControl(
			id: id,
			type: type,
			position: position,
			scaleX: scaleX,
			scaleY: scaleY,
			textId: textId,
			textColor: textColor,
			backgroundColor: backgroundColor
		)
	}

}
