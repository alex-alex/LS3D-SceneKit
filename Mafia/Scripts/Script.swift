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
	case integer(Int)
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
		if case .integer(let num) = self {
			return Float(num)
		} else if case .number(let num) = self {
			return num
		} else if case .variable(let varId) = self {
			return vars[Int(varId)] ?? 0
		} else if case .label(let str) = self, let num = Float(str) {
			return num
		} else if case .string(let str) = self, let num = Float(str) {
			return num
		} else {
			fatalError()
		}
	}

	func getValueOrVarValue(vars: [Int: Float]) -> Int {
		if case .integer(let num) = self {
			return num
		} else if case .number(let num) = self {
			return Int(num)
		} else if case .label(let str) = self, let num = Int(str) {
			return num
		} else if case .string(let str) = self, let num = Int(str) {
			return num
		}
		return Int(getValueOrVarValueFloat(vars: vars))
	}
}

enum ScriptCommandName: String {
	case actSetstate = "act_setstate"
	case actorSetplacement = "actor_setplacement"
	case carGetspeed = "car_getspeed"
	case carMuststeal = "car_muststeal"
	case carRepair = "car_repair"
	case carSetspeed = "car_setspeed"
	case cleardifferences
	case compareownerwithex
	case consoleAddtext = "console_addtext"
	case createweaponfromframe
	case ctrlRead = "ctrl_read"
	case detectorInrange = "detector_inrange"
	case detectorIssignal = "detector_issignal"
	case detectorSetsignal = "detector_setsignal"
	case detectorWaitforuse = "detector_waitforuse"
	case dimAct = "dim_act"
	case dimFlt = "dim_flt"
	case dimFrm = "dim_frm"
	case doorEnableus = "door_enableus"
	case doorLock = "door_lock"
	case doorOpen = "door_open"
	case end
	case endBang = "end!"
	case endofmission
	case enemyPlayanim = "enemy_playanim"
	case event
	case eventUseCb = "event_use_cb"
	case findactor
	case findframe
	case frmSeton = "frm_seton"
	case garageEnablesteal = "garage_enablesteal"
	case getactorsdist
	case getenemyaistate
	case goto
	case humanAnyweaponinhand = "human_anyweaponinhand"
	case humanGetactanimid = "human_getactanimid"
	case humanGetproperty = "human_getproperty"
	case humanHolster = "human_holster"
	case humanIsweapon = "human_isweapon"
	case humanSetproperty = "human_setproperty"
	case humanTalk = "human_talk"
	case `if` = "if"
	case iffltinrange
	case ifplayerstealcar
	case iscarusable
	case label
	case `let` = "let"
	case loaddifferences
	case missionObjectives = "mission_objectives"
	case missionObjectivesclear = "mission_objectivesclear"
	case personPlayanim = "person_playanim"
	case personStopanim = "person_stopanim"
	case playerLockcontrols = "player_lockcontrols"
	case pmShowsymbol = "pm_showsymbol"
	case recload
	case recloadfull
	case recunload
	case `return` = "return"
	case returnBang = "return!"
	case rnd
	case setcompass
	case setevent
	case setplayerfireevent
	case setplayerhornevent
	case subtitleAdd = "subtitle_add"
	case wait
	case zatmyse
	case unknown
}

struct ScriptCommand {
	let name: ScriptCommandName
	let rawName: String
	let args: [Argument]
}

final class Script {

	let uuid = NSUUID()
	let queue: DispatchQueue
	var completionHandler: (() -> Void)?

	var mainInEvent = false

	var eventIdQueue: [String] = []
	var eventIdQueueStartIndex = 0
	var currentEventId: String?
	var lineBeforeEvent: Int = 0
	var executingEvent = false
	var eventCompletionHandler: (() -> Void)?

	let scene: Scene
	let node: SCNNode
	var commands: [ScriptCommand]!
	var labels: [String: Int] = [:]
	var events: [String: Int] = [:]
	var currentLine: Int = 0
	var isRunning = false
	var isPaused = false
	var hasPendingRun = false
	var hasPendingNext = false

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

	func parse(string: String) -> [ScriptCommand] {
//		if node.name == nil {
//			print("==============================")
//			print(string)
//			print("==============================")
//		}

		let lines = string.components(separatedBy: .newlines)
		var parsed: [ScriptCommand] = []
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
			parsed.append(ScriptCommand(name: ScriptCommandName(rawValue: commandStr) ?? .unknown, rawName: commandStr, args: args))
			lineNum += 1
		}

		return parsed
	}

	func start() {
		queue.async {
			guard !self.isRunning, !self.commands.isEmpty else { return }
			self.isRunning = true
			self.run()
		}
	}

	func enqueueEvent(_ eventId: String) {
		queue.async {
			self.eventIdQueue.append(eventId)
			guard !self.isRunning else { return }
			self.isRunning = true
			self.run()
		}
	}

	func setPaused(_ paused: Bool) {
		queue.async {
			guard self.isPaused != paused else { return }

			self.isPaused = paused
			if !paused {
				if self.hasPendingNext {
					self.hasPendingNext = false
					self.next()
				} else if self.hasPendingRun {
					self.hasPendingRun = false
					self.run()
				}
			}
		}
	}

	func run() {
		guard !isPaused else {
			hasPendingRun = true
			return
		}
		hasPendingRun = false

		guard !commands.isEmpty else {
			isRunning = false
			completionHandler?()
			return
		}

		guard currentLine < commands.endIndex else {
			if hasQueuedEvent {
				currentLine = commands.endIndex - 1
				next()
				return
			}
			isRunning = false
			completionHandler?()
			print("END")
			return
		}

		let command = commands[currentLine]

		if mainInEvent {
			if command.name == .`return` || command.name == .returnBang {
				mainInEvent = false
			}
			return next()
		}

		print(">>> [\(node.name ?? "unnamed")] \(command.rawName) \(command.args)")

		performCommand(command: command)
	}

	var hasQueuedEvent: Bool {
		return eventIdQueueStartIndex < eventIdQueue.count
	}

	func dequeueEventId() -> String? {
		guard hasQueuedEvent else { return nil }
		let eventId = eventIdQueue[eventIdQueueStartIndex]
		eventIdQueueStartIndex += 1
		if eventIdQueueStartIndex > 32 && eventIdQueueStartIndex * 2 >= eventIdQueue.count {
			eventIdQueue.removeFirst(eventIdQueueStartIndex)
			eventIdQueueStartIndex = 0
		}
		return eventId
	}

}
