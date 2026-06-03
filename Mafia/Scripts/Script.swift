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

	var scriptLogDescription: String {
		switch self {
		case .integer(let value):
			return "\(value)"
		case .number(let value):
			return String(format: "%g", value)
		case .label(let value):
			return value
		case .string(let value):
			let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
			return "\"\(escapedValue)\""
		case .variable(let value):
			return "flt[\(value)]"
		}
	}

	func scriptTalkSoundId(vars: [Int: Float]) -> String {
		switch self {
		case .label(let value), .string(let value):
			return value
		default:
			return "\(getValueOrVarValue(vars: vars))"
		}
	}
}

enum ScriptCommandName: String {
	case actSetstate = "act_setstate"
	case actorDelete = "actor_delete"
	case actorSetpos = "actor_setpos"
	case actorSetplacement = "actor_setplacement"
	case cameraGetfov = "camera_getfov"
	case cameraSetfov = "camera_setfov"
	case cameraSetrange = "camera_setrange"
	case carGetspeed = "car_getspeed"
	case carEnableus = "car_enableus"
	case carForcestop = "car_forcestop"
	case carGetactlevel = "car_getactlevel"
	case carGetseatcount = "car_getseatcount"
	case carInwater = "car_inwater"
	case carLock = "car_lock"
	case carLockAll = "car_lock_all"
	case carMuststeal = "car_muststeal"
	case carRepair = "car_repair"
	case carSetactlevel = "car_setactlevel"
	case carSetspeed = "car_setspeed"
	case cleardifferences
	case commandblock
	case compareactors
	case compareframes
	case compareownerwith
	case compareownerwithex
	case consoleAddtext = "console_addtext"
	case createPhysicalobject = "create_physicalobject"
	case createweaponfromframe
	case ctrlRead = "ctrl_read"
	case detectorInrange = "detector_inrange"
	case detectorIssignal = "detector_issignal"
	case detectorSetsignal = "detector_setsignal"
	case detectorWaitforuse = "detector_waitforuse"
	case dimAct = "dim_act"
	case dimFlt = "dim_flt"
	case dimFrm = "dim_frm"
	case destroyPhysicalobject = "destroy_physicalobject"
	case disablecolls
	case doorEnableus = "door_enableus"
	case doorGetstate = "door_getstate"
	case doorLock = "door_lock"
	case doorOpen = "door_open"
	case end
	case endBang = "end!"
	case endofmission
	case enemyPlayanim = "enemy_playanim"
	case enemyTalk = "enemy_talk"
	case enemyWait = "enemy_wait"
	case event
	case eventUseCb = "event_use_cb"
	case findactor
	case findframe
	case getactivecamera
	case getactiveplayer
	case getactorframe
	case getfilmmusic
	case frmGetpos = "frm_getpos"
	case frmGetnumchildren = "frm_getnumchildren"
	case frmGetparent = "frm_getparent"
	case frmGetscale = "frm_getscale"
	case frmGetworldpos = "frm_getworldpos"
	case frmGetworldscale = "frm_getworldscale"
	case frmIson = "frm_ison"
	case frmSetpos = "frm_setpos"
	case frmSeton = "frm_seton"
	case frmSetscale = "frm_setscale"
	case garageEnablesteal = "garage_enablesteal"
	case getactorsdist
	case getenemyaistate
	case getframefromactor
	case getgametime
	case getRemoteActor = "get_remote_actor"
	case getRemoteFloat = "get_remote_float"
	case getRemoteFrame = "get_remote_frame"
	case getticktime
	case goto
	case humanActivateweapon = "human_activateweapon"
	case humanAddweapon = "human_addweapon"
	case humanAnyweaponinhand = "human_anyweaponinhand"
	case humanAnyweaponininventory = "human_anyweaponininventory"
	case humanCanaddweapon = "human_canaddweapon"
	case humanCandie = "human_candie"
	case humanDeath = "human_death"
	case humanDelweapon = "human_delweapon"
	case humanGetactanimid = "human_getactanimid"
	case humanGetiteminrhand = "human_getiteminrhand"
	case humanGetowner = "human_getowner"
	case humanGetproperty = "human_getproperty"
	case humanHolster = "human_holster"
	case humanForceSettocar = "human_force_settocar"
	case humanIsweapon = "human_isweapon"
	case humanSetproperty = "human_setproperty"
	case humanTalk = "human_talk"
	case `if` = "if"
	case iffltinrange
	case ifplayerstealcar
	case introSubtitleAdd = "intro_subtitle_add"
	case inventoryClear = "inventory_clear"
	case iscarusable
	case label
	case `let` = "let"
	case loaddifferences
	case mathAbs = "math_abs"
	case mathCos = "math_cos"
	case mathSin = "math_sin"
	case missionObjectives = "mission_objectives"
	case missionObjectivesclear = "mission_objectivesclear"
	case missionObjectivesremove = "mission_objectivesremove"
	case modelCreate = "model_create"
	case modelDestroy = "model_destroy"
	case modelPlayanim = "model_playanim"
	case modelStopanim = "model_stopanim"
	case personPlayanim = "person_playanim"
	case personStopanim = "person_stopanim"
	case playerLockcontrols = "player_lockcontrols"
	case playsound
	case playsoundstop
	case pmShowsymbol = "pm_showsymbol"
	case recload
	case recloadfull
	case recwaitforend
	case recunload
	case `return` = "return"
	case returnBang = "return!"
	case rnd
	case setcompass
	case setevent
	case setfilmmusic
	case setnullactor
	case setnullframe
	case setplayerfireevent
	case setplayerhornevent
	case settimeoutevent
	case soundGetvolume = "sound_getvolume"
	case soundSetvolume = "sound_setvolume"
	case soundfade
	case streamCreate = "stream_create"
	case streamDestroy = "stream_destroy"
	case streamFadevol = "stream_fadevol"
	case streamGetpos = "stream_getpos"
	case streamPause = "stream_pause"
	case streamPlay = "stream_play"
	case streamSetloop = "stream_setloop"
	case streamStop = "stream_stop"
	case subtitleAdd = "subtitle_add"
	case timerGetinterval = "timer_getinterval"
	case timerSetinterval = "timer_setinterval"
	case timeroff
	case timeron
	case vectAddVect = "vect_add_vect"
	case vectCopy = "vect_copy"
	case vectInverse = "vect_inverse"
	case vectMagnitude = "vect_magnitude"
	case vectMulScl = "vect_mul_scl"
	case vectMulVect = "vect_mul_vect"
	case vectSet = "vect_set"
	case vectSubVect = "vect_sub_vect"
	case versionIsEditor = "version_is_editor"
	case versionIsGermany = "version_is_germany"
	case wait
	case zatmyse
	case unknown
}

final class ScriptEnemyTalkOperation {
	var isComplete = false
	var waiters: [() -> Void] = []
}

final class ScriptSoundPlayback {
	let node: SCNNode
	let player: SCNAudioPlayer

	init(node: SCNNode, player: SCNAudioPlayer) {
		self.node = node
		self.player = player
	}
}

struct ScriptCommand {
	let name: ScriptCommandName
	let rawName: String
	let args: [Argument]

	var scriptLogDescription: String {
		guard !args.isEmpty else { return rawName }
		return rawName + " " + args.map(\.scriptLogDescription).joined(separator: ", ")
	}
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
	var commandBlockDepth = 0
	var pendingCommandBlockAsyncOperations = 0
	var isWaitingForCommandBlockAsyncOperations = false
	var didApplySelfActorState = false

	var frames: [Int: SCNNode] = [:]
	var actors: [Int: SCNNode] = [:]
	var vars: [Int: Float] = [:]
	var carActLevels: [Int: Float] = [:]
	var soundPlaybacks: [Int: ScriptSoundPlayback] = [:]
	var nextSoundPlaybackId = 1
	var streams: [Int: ScriptMusicStream] = [:]
	var nextStreamId = 1
	var pendingEnemyTalk: ScriptEnemyTalkOperation?
	var lastTickTime = Date.timeIntervalSinceReferenceDate
	var timeoutEventBinding: ScriptEventBinding?
	var timerEndTime: TimeInterval?
	var timerRemainingMilliseconds: Float = 0
	var timerGeneration = 0

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
		for (sourceLineIndex, rawLine) in lines.enumerated() {
			let line = rawLine.trimmingCharacters(in: .whitespaces)
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

			let args = getArgumentsForCommand(str: commandStr, scanner: scanner, sourceLine: line, lineNumber: sourceLineIndex + 1)
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

	func applyDeclaredInitialActorState() {
		guard let command = commands.first,
			  command.name == .actSetstate,
			  command.args.count >= 2,
			  command.args[0].getValueOrVarValue(vars: vars) == -1,
			  let state = ActorState(rawValue: command.args[1].getString().lowercased()) else {
			return
		}
		node.actorState = state
	}

	func markSelfActorStateApplied() {
		didApplySelfActorState = true
	}

	func setActorState(_ state: ActorState) {
		node.actorState = state
		queue.async {
			guard state.canRunScript else { return }
			guard self.isRunning else {
				guard !self.commands.isEmpty else { return }
				self.isRunning = true
				self.run()
				return
			}
			if self.hasPendingNext {
				self.hasPendingNext = false
				self.next()
			} else if self.hasPendingRun {
				self.hasPendingRun = false
				self.run()
			}
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

	func setAudioPaused(_ paused: Bool) {
		queue.async {
			for stream in self.streams.values {
				stream.setGamePaused(paused)
			}
		}
	}

	func run() {
		guard !isPaused else {
			hasPendingRun = true
			return
		}
		guard canRunForActorState() else {
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
			guard commandBlockDepth == 0 else {
				fatalError("Unterminated commandblock")
			}
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

		print(">>> [\(node.name ?? "unnamed")] \(command.scriptLogDescription)")

		performCommand(command: command)
	}

	var hasQueuedEvent: Bool {
		return eventIdQueueStartIndex < eventIdQueue.count
	}

	func canRunForActorState() -> Bool {
		if node.actorState.canRunScript {
			return true
		}
		guard !didApplySelfActorState,
			  let selfActorStateLine = commands.firstIndex(where: { command in
			command.name == .actSetstate &&
			command.args.count >= 2 &&
			command.args[0].getValueOrVarValue(vars: vars) == -1
		}) else {
			return false
		}
		return currentLine <= selfActorStateLine
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
