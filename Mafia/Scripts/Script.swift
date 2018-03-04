//
//  Script.swift
//  Mafia
//
//  Created by Alex Studnička on 22/01/2017.
//  Copyright © 2017 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

enum Argument {
//	case empty
	case number(Float)
	case label(String)
	case string(String)
	case variable(Int)

	func getString() -> String {
		if case .string(let str) = self {
			return str
		} else if case .label(let str) = self {
			return str
		} else {
			fatalError()
		}
	}

	func getValueOrVarValueFloat(vars: [Int: Float]) -> Float {
		if case .number(let num) = self {
			return num
		} else if case .variable(let varId) = self {
			return vars[Int(varId)] ?? 0
		} else {
			fatalError()
		}
	}

	func getValueOrVarValue(vars: [Int: Float]) -> Int {
		return Int(getValueOrVarValueFloat(vars: vars))
	}
}

final class Script {

	let uuid = NSUUID()
	let queue: DispatchQueue
	var completionHandler: (() -> Void)?

	var mainInEvent = false

	var eventIdQueue: [String] = []
	var currentEventId: String?
	var lineBeforeEvent: Int = 0
	var executingEvent = false
	var eventCompletionHandler: (() -> Void)?

	let scene: Scene
	let node: SCNNode
	var commands: [(String, [Argument])]!
	var labels: [String: Int] = [:]
	var events: [String: Int] = [:]
	var currentLine: Int = 0

	var frames: [Int: SCNNode] = [:]
	var actors: [Int: SCNNode] = [:]
	var vars: [Int: Float] = [:]

	var signal = false

	init(script: String, scene: Scene, node: SCNNode) {
		self.queue = DispatchQueue(label: "script", qos: .background)
		self.scene = scene
		self.node = node
		self.commands = parse(string: script)
	}

	func parse(string: String) -> [(String, [Argument])] {
//		if node.name == nil {
//			print("==============================")
//			print(string)
//			print("==============================")
//		}

		let lines = string.components(separatedBy: .newlines)
		var parsed: [(String, [Argument])] = []
		var lineNum = 0
		for line in lines {
			let line = line.trimmingCharacters(in: .whitespaces)
			guard !line.isEmpty && !line.hasPrefix("//") else { continue }
			let scanner = Scanner(string: line)
			var _command: NSString?
			scanner.scanUpToCharacters(from: .whitespaces, into: &_command)
			scanner.scanCharacters(from: .whitespaces, into: nil)
			guard let commandStr = (_command as String?)?.lowercased() else { fatalError() }

			if commandStr == "label" {
				let label = scanParam(scanner)
				labels[label] = lineNum
			}
			if commandStr == "event" {
				let label = scanParam(scanner)
				events[label] = lineNum
			}

			let args = getArgumentsForCommand(str: commandStr, scanner: scanner)
			parsed.append((commandStr, args))
			lineNum += 1
		}

		return parsed
	}

	func start() {
//		let allowed = [
//			"xmicro", "blikani radaru", "plechovkac", "Enemy09K", "target", "target2",
//			"Delnik", "Delnik2", "mysi", "pes1", "stavbain", "horn", "vrz1", "policie",
//			"Enemy", "dret", "lekarna", "help", "end", "stop"
//		]

//		guard let name = node.name, [].contains(name) else {
//			print("[SCRIPT]", node.name as Any)
//			return
//		}

//		queue.async(execute: run)
	}

	func run() {
		guard currentLine < commands.endIndex else {
			completionHandler?()
			print("END")
			return
		}

		let command = commands[currentLine]

		if mainInEvent {
			if command.0 == "return" {
				mainInEvent = false
			}
			return next()
		}

		if node.name == "root" {
			print(">>>", command)
		}

		performCommand(command: command)
	}

}
