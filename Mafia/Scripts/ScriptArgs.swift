//
//  ScriptArgs.swift
//  Mafia
//
//  Created by Alex Studnička on 07/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

/*final class ScriptArgs {
		
	private let compareownerwithex: ((Scanner) -> [Argument]) = { scanner in
		return [ScriptArgs.scanVarOrValue(scanner), ScriptArgs.scanVarOrValue(scanner), .label(ScriptArgs.scanParam(scanner)), .label(ScriptArgs.scanParam(scanner))]
	}
	
	// ----
	
	func getArgumentsForCommand(str: String, scanner: Scanner) -> [Argument] {
		let mirror = Mirror(reflecting: self)
		let function = mirror.children.first!.value as! ((Scanner) -> [Argument])
		return function(scanner)
	}
	
	// ----
	
	private static func scanParamOptional(_ scanner: Scanner) -> String? {
		var str: NSString?
		let charset = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanUpToCharacters(from: charset, into: &str)
		scanner.scanCharacters(from: charset, into: nil)
		return str as String?
	}
	
	private static func scanParam(_ scanner: Scanner) -> String {
		guard let ret = scanParamOptional(scanner) else { fatalError() }
		return ret
	}
	
	private static func scanString(_ scanner: Scanner) -> String? {
		var str: NSString?
		let charset = CharacterSet(charactersIn: "\"")
		guard scanner.scanString("\"", into: nil) else { return nil }
		scanner.scanUpToCharacters(from: charset, into: &str)
		guard scanner.scanString("\"", into: nil) else { fatalError() }
		scanner.scanCharacters(from: .whitespaces, into: nil)
		return (str as String?)
	}
	
	private static func scanVar(_ scanner: Scanner) -> Int? {
		var var1 = 0
		guard scanner.scanString("flt[", into: nil) else { return nil }
		guard scanner.scanInt(&var1) else { fatalError() }
		guard scanner.scanString("]", into: nil) else { fatalError() }
		let charset = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanCharacters(from: charset, into: nil)
		return var1
	}
	
	private static func scanValue(_ scanner: Scanner) -> Float? {
		var value: Float = 0
		guard scanner.scanFloat(&value) else { return nil }
		let charset = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanCharacters(from: charset, into: nil)
		return value
	}
	
	private static func scanVarOrValueOptional(_ scanner: Scanner) -> Argument? {
		if let varId = scanVar(scanner) {
			return .variable(varId)
		} else if let value = scanValue(scanner) {
			return .number(value)
		} else {
			return nil
		}
	}
	
	private static func scanVarOrValue(_ scanner: Scanner) -> Argument {
		if let arg = scanVarOrValueOptional(scanner) {
			return arg
		} else {
			fatalError()
		}
	}
	
}*/

extension Script {

	func getArgumentsForCommand(str: String, scanner: Scanner) -> [Argument] {
		switch str {
		case "act_setstate":			return getArgs_act_setstate(scanner)
		case "actor_setplacement":		return getArgs_actor_setplacement(scanner)
		case "car_getspeed":			return getArgs_car_getspeed(scanner)
		case "car_muststeal":			return getArgs_car_muststeal(scanner)
		case "car_repair":				return getArgs_car_repair(scanner)
		case "car_setspeed":			return getArgs_car_setspeed(scanner)
		case "cleardifferences":		return []
		case "commandblock":			return getArgs_commandblock(scanner)
		case "compareownerwithex":		return getArgs_compareownerwithex(scanner)
		case "console_addtext":			return getArgs_console_addtext(scanner)
		case "createweaponfromframe":	return getArgs_createweaponfromframe(scanner)
		case "ctrl_read":				return getArgs_ctrl_read(scanner)
		case "detector_inrange":		return getArgs_detector_inrange(scanner)
		case "detector_issignal":		return getArgs_detector_issignal(scanner)
		case "detector_setsignal":		return getArgs_detector_setsignal(scanner)
		case "detector_waitforuse":		return getArgs_detector_waitforuse(scanner)
		case "door_enableus":			return getArgs_door_enableus(scanner)
		case "door_lock":				return getArgs_door_lock(scanner)
		case "door_open":				return getArgs_door_open(scanner)
		case "endofmission":			return getArgs_endofmission(scanner)
		case "enemy_playanim":			return getArgs_enemy_playanim(scanner)
		case "findactor":				return getArgs_findactor(scanner)
		case "findframe":				return getArgs_findframe(scanner)
		case "frm_seton":				return getArgs_frm_seton(scanner)
		case "garage_enablesteal":		return getArgs_garage_enablesteal(scanner)
		case "getactorsdist":			return getArgs_getactorsdist(scanner)
		case "getenemyaistate":			return getArgs_getenemyaistate(scanner)
		case "goto":					return getArgs_goto(scanner)
		case "human_anyweaponinhand":	return getArgs_human_anyweaponinhand(scanner)
		case "human_getactanimid":		return getArgs_human_getactanimid(scanner)
		case "human_getproperty":		return getArgs_human_getproperty(scanner)
		case "human_holster":			return getArgs_human_holster(scanner)
		case "human_isweapon":			return getArgs_human_isweapon(scanner)
		case "human_setproperty":		return getArgs_human_setproperty(scanner)
		case "human_talk":				return getArgs_human_talk(scanner)
		case "if":						return getArgs_if(scanner)
		case "iffltinrange":			return getArgs_iffltinrange(scanner)
		case "ifplayerstealcar":		return getArgs_ifplayerstealcar(scanner)
		case "iscarusable":				return getArgs_iscarusable(scanner)
		case "let":						return getArgs_let(scanner)
		case "loaddifferences":			return getArgs_loaddifferences(scanner)
		case "mission_objectives":		return getArgs_mission_objectives(scanner)
		case "person_playanim":			return getArgs_person_playanim(scanner)
		case "person_stopanim":			return getArgs_person_stopanim(scanner)
		case "rnd":						return getArgs_rnd(scanner)
		case "recload":					return getArgs_recload(scanner)
		case "recloadfull":				return getArgs_recload(scanner)
		case "recwaitforend":			return []
		case "recunload":				return []
		case "setcompass":				return getArgs_setcompass(scanner)
		case "setevent":				return getArgs_setevent(scanner)
		case "setplayerfireevent":		return getArgs_setplayerevent(scanner)
		case "setplayerhornevent":		return getArgs_setplayerevent(scanner)
		case "subtitle_add":			return getArgs_subtitle_add(scanner)
		case "wait":					return getArgs_wait(scanner)
		case "zatmyse":					return getArgs_zatmyse(scanner)
		default:						return []
		}
	}

	// ----

	private func getArgs_act_setstate(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_actor_setplacement(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_getspeed(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_muststeal(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOptional(scanner) ?? .integer(1)]
	}

	private func getArgs_car_repair(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_car_setspeed(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOptional(scanner) ?? .integer(0)]
	}

	private func getArgs_commandblock(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_compareownerwithex(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), .label(scanParam(scanner)), .label(scanParam(scanner))]
	}

	private func getArgs_console_addtext(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_createweaponfromframe(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner), scanVarOrValue(scanner)]
		if let val = scanVarOrValueOptional(scanner) {
			args.append(val)
		}
		if let val = scanVarOrValueOptional(scanner) {
			args.append(val)
		}
		return args
	}

	private func getArgs_ctrl_read(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_detector_inrange(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_detector_issignal(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner)), .label(scanParam(scanner))]
	}

	private func getArgs_detector_setsignal(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_detector_waitforuse(_ scanner: Scanner) -> [Argument] {
		if let txtId = scanVarOrValueOptional(scanner) {
			return [txtId]
		} else {
			return []
		}
	}

	private func getArgs_door_enableus(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOptional(scanner) ?? .integer(1)]
	}

	private func getArgs_door_lock(_ scanner: Scanner) -> [Argument] {
		var args: [Argument] = []
		while let arg = scanVarOrValueOptional(scanner) {
			args.append(arg)
		}
		return args
	}

	private func getArgs_door_open(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOptional(scanner) ?? .integer(1)]
	}

	private func getArgs_endofmission(_ scanner: Scanner) -> [Argument] {
		var args: [Argument] = []
		while let arg = scanVarOrValueOptional(scanner) {
			args.append(arg)
		}
		return args
	}

	private func getArgs_enemy_playanim(_ scanner: Scanner) -> [Argument] {
		guard let animName = scanString(scanner) else { fatalError() }
		return [.string(animName)]
	}

	private func getArgs_findactor(_ scanner: Scanner) -> [Argument] {
		let actorId = scanVarOrValue(scanner)
		if let name = scanString(scanner) {
			return [actorId, .string(name)]
		} else {
			return [actorId]
		}
	}

	private func getArgs_findframe(_ scanner: Scanner) -> [Argument] {
		let frameId = scanVarOrValue(scanner)
		if let name = scanString(scanner) {
			return [frameId, .string(name)]
		} else {
			return [frameId]
		}
	}

	private func getArgs_frm_seton(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_getactorsdist(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_getenemyaistate(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_goto(_ scanner: Scanner) -> [Argument] {
		return [.label(scanParam(scanner))]
	}

	private func getArgs_human_anyweaponinhand(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_getactanimid(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_getproperty(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_human_holster(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_human_isweapon(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_setproperty(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_human_talk(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner), .label(scanParam(scanner))]
		if let val = scanNumber(scanner) {
			args.append(val)
		}
		return args
	}

	private func getArgs_if(_ scanner: Scanner) -> [Argument] {
		let arg1 = scanVarOrValue(scanner)

		let op: String
		if scanner.scanString("=", into: nil) {
			op = "="
		} else if scanner.scanString("!", into: nil) {
			op = "!"
		} else if scanner.scanString("<", into: nil) {
			op = "<"
		} else if scanner.scanString(">", into: nil) {
			op = ">"
		} else {
			fatalError()
		}
		scanner.scanCharacters(from: .whitespaces, into: nil)

		return [arg1, .label(op), scanVarOrValue(scanner), .label(scanParam(scanner)), .label(scanParam(scanner))]
	}

	private func getArgs_iffltinrange(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_garage_enablesteal(_ scanner: Scanner) -> [Argument] {
		if let param = scanParamOptional(scanner) {
			return [.label(param)]
		}
		return []
	}

	private func getArgs_ifplayerstealcar(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_iscarusable(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_let(_ scanner: Scanner) -> [Argument] {
		guard let var1 = scanVar(scanner) else { fatalError() }

		guard scanner.scanString("=", into: nil) else { fatalError() }
		scanner.scanCharacters(from: .whitespaces, into: nil)

		let arg2 = scanVarOrValue(scanner)

		if scanner.isAtEnd {
			return [.variable(var1), arg2]
		}

		let op: String
		if scanner.scanString("+", into: nil) {
			op = "+"
		} else if scanner.scanString("-", into: nil) {
			op = "-"
		} else if scanner.scanString("*", into: nil) {
			op = "*"
		} else if scanner.scanString("/", into: nil) {
			op = "/"
		} else {
			fatalError()
		}
		scanner.scanCharacters(from: .whitespaces, into: nil)

		return [.variable(var1), arg2, .label(op), scanVarOrValue(scanner)]
	}

	private func getArgs_loaddifferences(_ scanner: Scanner) -> [Argument] {
		guard let name = scanString(scanner) else { fatalError() }
		return [.string(name)]
	}

	private func getArgs_mission_objectives(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_person_playanim(_ scanner: Scanner) -> [Argument] {
		let actorId = scanVarOrValue(scanner)
		guard let animName = scanString(scanner) else { return [actorId] }
		var args: [Argument] = [actorId, .string(animName)]
		while let param = scanParamOptional(scanner) {
			args.append(.label(param))
		}
		return args
	}

	private func getArgs_person_stopanim(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_rnd(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_recload(_ scanner: Scanner) -> [Argument] {
		guard let name = scanString(scanner) else { fatalError() }
		return [.string(name)]
	}

	private func getArgs_setcompass(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_setevent(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner)), .label(scanParam(scanner))]
	}

	private func getArgs_setplayerevent(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_subtitle_add(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_wait(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_zatmyse(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOptional(scanner) ?? .integer(0)]
	}

	// ----

	func scanParamOptional(_ scanner: Scanner) -> String? {
		var str: NSString?
		let charset = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanUpToCharacters(from: charset, into: &str)
		scanner.scanCharacters(from: charset, into: nil)
		return (str as String?)?.trimmingCharacters(in: CharacterSet(charactersIn: "!"))
	}

	func scanParam(_ scanner: Scanner) -> String {
		guard let ret = scanParamOptional(scanner) else { fatalError() }
		return ret
	}

	private func scanString(_ scanner: Scanner) -> String? {
		var str: NSString?
		let charset = CharacterSet(charactersIn: "\"")
		guard scanner.scanString("\"", into: nil) else { return nil }
		scanner.scanUpToCharacters(from: charset, into: &str)
		guard scanner.scanString("\"", into: nil) || scanner.isAtEnd else { fatalError() }
		scanner.scanCharacters(from: .whitespaces, into: nil)
		return (str as String?)
	}

	private func scanVar(_ scanner: Scanner) -> Int? {
		var var1 = 0
		guard scanner.scanString("flt[", into: nil) else { return nil }
		guard scanner.scanInt(&var1) else { fatalError() }
		guard scanner.scanString("]", into: nil) else { fatalError() }
		let charset = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanCharacters(from: charset, into: nil)
		return var1
	}

	private func scanNumber(_ scanner: Scanner) -> Argument? {
		guard let token = scanParamOptional(scanner) else { return nil }
		if token.contains(".") || token.contains("e") || token.contains("E") {
			guard let value = Float(token) else { fatalError() }
			return .number(value)
		}
		if let value = Int(token) {
			return .integer(value)
		}
		guard let value = Float(token) else { fatalError() }
		return .number(value)
	}

	private func scanValue(_ scanner: Scanner) -> Float? {
		guard let number = scanNumber(scanner) else { return nil }
		switch number {
		case .integer(let value):
			return Float(value)
		case .number(let value):
			return value
		default:
			fatalError()
		}
	}

	private func scanVarOrValueOptional(_ scanner: Scanner) -> Argument? {
		if let varId = scanVar(scanner) {
			return .variable(varId)
		} else {
			return scanNumber(scanner)
		}
	}

	private func scanVarOrValue(_ scanner: Scanner) -> Argument {
		if let arg = scanVarOrValueOptional(scanner) {
			return arg
		} else {
			fatalError()
		}
	}

}
