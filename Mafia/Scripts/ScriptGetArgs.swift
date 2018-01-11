//
//  ScriptGetArgs.swift
//  Mafia
//
//  Created by Alex Studnička on 07/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

extension Script {
	
	func getArgumentsForCommand(str: String, scanner: Scanner) -> [Argument] {
		switch str {
		case "console_addtext":			return getArgs_console_addtext(scanner)
		case "createweaponfromframe":	return getArgs_createweaponfromframe(scanner)
		case "ctrl_read":				return getArgs_ctrl_read(scanner)
		case "detector_inrange":		return getArgs_detector_inrange(scanner)
		case "detector_issignal":		return getArgs_detector_issignal(scanner)
		case "detector_setsignal":		return getArgs_detector_setsignal(scanner)
		case "detector_waitforuse":		return getArgs_detector_waitforuse(scanner)
		case "enemy_playanim":			return getArgs_enemy_playanim(scanner)
		case "findactor":				return getArgs_findactor(scanner)
		case "findframe":				return getArgs_findframe(scanner)
		case "frm_seton":				return getArgs_frm_seton(scanner)
		case "getactorsdist":			return getArgs_getactorsdist(scanner)
		case "getenemyaistate":			return getArgs_getenemyaistate(scanner)
		case "goto":					return getArgs_goto(scanner)
		case "human_anyweaponinhand":	return getArgs_human_anyweaponinhand(scanner)
		case "human_getactanimid":		return getArgs_human_getactanimid(scanner)
		case "human_getproperty":		return getArgs_human_getproperty(scanner)
		case "human_isweapon":			return getArgs_human_isweapon(scanner)
		case "human_talk":				return getArgs_human_talk(scanner)
		case "if":						return getArgs_if(scanner)
		case "let":						return getArgs_let(scanner)
		case "mission_objectives":		return getArgs_mission_objectives(scanner)
		case "rnd":						return getArgs_rnd(scanner)
		case "setcompass":				return getArgs_setcompass(scanner)
		case "setevent":				return getArgs_setevent(scanner)
		case "wait":					return getArgs_wait(scanner)
		default:						return []
		}
	}
	
	// ----
	
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
		if let txtId = scanParamOptional(scanner) {
			return [.label(txtId)]
		} else {
			return []
		}
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
	
	private func getArgs_human_isweapon(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}
	
	private func getArgs_human_talk(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner), .label(scanParam(scanner))]
		if let val = scanValue(scanner) {
			args.append(.number(val))
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
	
	private func getArgs_mission_objectives(_ scanner: Scanner) -> [Argument] {
		return [.label(scanParam(scanner))]
	}
	
	private func getArgs_rnd(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}
	
	private func getArgs_setcompass(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}
	
	private func getArgs_setevent(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner)), .label(scanParam(scanner))]
	}
	
	private func getArgs_wait(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}
	
	// ----
	
	func scanParamOptional(_ scanner: Scanner) -> String? {
		var str: NSString?
		let charset = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanUpToCharacters(from: charset, into: &str)
		scanner.scanCharacters(from: charset, into: nil)
		return str as String?
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
		guard scanner.scanString("\"", into: nil) else { fatalError() }
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
	
	private func scanValue(_ scanner: Scanner) -> Float? {
		var value: Float = 0
		guard scanner.scanFloat(&value) else { return nil }
		let charset = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanCharacters(from: charset, into: nil)
		return value
	}
	
	private func scanVarOrValueOptional(_ scanner: Scanner) -> Argument? {
		if let varId = scanVar(scanner) {
			return .variable(varId)
		} else if let value = scanValue(scanner) {
			return .number(value)
		} else {
			return nil
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
