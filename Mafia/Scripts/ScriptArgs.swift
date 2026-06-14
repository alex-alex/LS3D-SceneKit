//
//  ScriptArgs.swift
//  Mafia
//
//  Created by Alex Studnička on 07/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

private let scriptArgumentParseContextKey = "ScriptArgumentParseContext"

private func scriptArgumentFatalError(_ message: String, file: StaticString = #file, line: UInt = #line) -> Never {
	if let scriptArgumentParseContext = Thread.current.threadDictionary[scriptArgumentParseContextKey] as? String {
		fatalError("\(message) while parsing \(scriptArgumentParseContext)", file: file, line: line)
	} else {
		fatalError(message, file: file, line: line)
	}
}

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

	func getArgumentsForCommand(str: String, scanner: Scanner, sourceLine: String? = nil, lineNumber: Int? = nil) -> [Argument] {
		if let sourceLine {
			if let lineNumber {
				Thread.current.threadDictionary[scriptArgumentParseContextKey] = "line \(lineNumber), command '\(str)': \(sourceLine)"
			} else {
				Thread.current.threadDictionary[scriptArgumentParseContextKey] = "command '\(str)': \(sourceLine)"
			}
		} else {
			Thread.current.threadDictionary[scriptArgumentParseContextKey] = "command '\(str)'"
		}
		defer { Thread.current.threadDictionary.removeObject(forKey: scriptArgumentParseContextKey) }

		switch str {
		case "act_setstate":			return getArgs_act_setstate(scanner)
		case "actor_delete":			return getArgs_actor_delete(scanner)
		case "actor_duplicate":		return getArgs_actor_duplicate(scanner)
		case "actor_setdir":			return getArgs_actor_setdir(scanner)
		case "actor_setpos":			return getArgs_actor_setplacement(scanner)
		case "actor_setplacement":		return getArgs_actor_setplacement(scanner)
		case "actorupdateplacement":	return getArgs_actorupdateplacement(scanner)
		case "camera_getfov":			return getArgs_camera_getfov(scanner)
		case "camera_lock":				return getArgs_camera_lock(scanner)
		case "camera_setfov":			return getArgs_camera_setfov(scanner)
		case "camera_setrange":			return getArgs_camera_setrange(scanner)
		case "camera_unlock":			return []
		case "car_breakmotor":			return getArgs_car_breakmotor(scanner)
		case "car_calm":				return getArgs_car_calm(scanner)
		case "car_enableus":			return getArgs_car_enableus(scanner)
		case "car_forcestop":			return getArgs_car_forcestop(scanner)
		case "car_getactlevel":			return getArgs_car_getactlevel(scanner)
		case "car_getseatcount":		return getArgs_car_getseatcount(scanner)
		case "car_getspeed":			return getArgs_car_getspeed(scanner)
		case "car_inwater":				return getArgs_car_inwater(scanner)
		case "car_lock":				return getArgs_car_lock(scanner)
		case "car_lock_all":			return getArgs_car_lock_all(scanner)
		case "car_muststeal":			return getArgs_car_muststeal(scanner)
		case "car_repair":				return getArgs_car_repair(scanner)
		case "car_disable_uo":			return getArgs_car_disable_uo(scanner)
		case "car_setdestroymotor":		return getArgs_car_setdestroymotor(scanner)
		case "car_setdooropen":			return getArgs_car_setdooropen(scanner)
		case "car_setactlevel":			return getArgs_car_setactlevel(scanner)
		case "car_setspeed":			return getArgs_car_setspeed(scanner)
		case "change_mission":			return getArgs_change_mission(scanner)
		case "citymusic_off":			return []
		case "citymusic_on":			return []
		case "cleardifferences":		return []
		case "commandblock":			return getArgs_commandblock(scanner)
		case "compareactors":			return getArgs_compareactors(scanner)
		case "compareframes":			return getArgs_compareframes(scanner)
		case "compareownerwith":		return getArgs_compareownerwith(scanner)
		case "compareownerwithex":		return getArgs_compareownerwithex(scanner)
		case "console_addtext":			return getArgs_console_addtext(scanner)
		case "create_physicalobject":	return getArgs_create_physicalobject(scanner)
		case "createweaponfromframe":	return getArgs_createweaponfromframe(scanner)
		case "ctrl_read":				return getArgs_ctrl_read(scanner)
		case "debug_text":				return getArgs_debug_text(scanner)
		case "detector_inrange":		return getArgs_detector_inrange(scanner)
		case "detector_issignal":		return getArgs_detector_issignal(scanner)
		case "detector_setsignal":		return getArgs_detector_setsignal(scanner)
		case "detector_waitforhit":		return []
		case "detector_waitforuse":		return getArgs_detector_waitforuse(scanner)
		case "dialog_begin":			return getArgs_dialog_begin(scanner)
		case "dialog_camswitch":		return getArgs_dialog_camswitch(scanner)
		case "dialog_end":				return []
		case "dim_act":					return getArgs_dim(scanner)
		case "dim_flt":					return getArgs_dim(scanner)
		case "dim_frm":					return getArgs_dim(scanner)
		case "destroy_physicalobject":	return getArgs_destroy_physicalobject(scanner)
		case "disablecolls":			return getArgs_disablecolls(scanner)
		case "door_enableus":			return getArgs_door_enableus(scanner)
		case "door_getstate":			return getArgs_door_getstate(scanner)
		case "door_lock":				return getArgs_door_lock(scanner)
		case "door_open":				return getArgs_door_open(scanner)
		case "endofmission":			return getArgs_endofmission(scanner)
		case "enemy_action_fire":		return getArgs_enemy_action_fire(scanner)
		case "enemy_action_follow":		return getArgs_enemy_action_follow(scanner)
		case "enemy_actionsclear":		return []
		case "enemy_brainwash":			return []
		case "enemy_car_moveto":		return getArgs_enemy_car_moveto(scanner)
		case "enemy_forcescript":		return getArgs_enemy_forcescript(scanner)
		case "enemy_group_add":			return getArgs_enemy_group_add(scanner)
		case "enemy_group_addcar":		return getArgs_enemy_group_addcar(scanner)
		case "enemy_group_chcipni_hajzle": return getArgs_enemy_group_chcipni_hajzle(scanner)
		case "enemy_group_del":			return getArgs_enemy_group_del(scanner)
		case "enemy_group_new":			return getArgs_enemy_group_new(scanner)
		case "enemy_lockstate":			return getArgs_enemy_lockstate(scanner)
		case "enemy_look":				return getArgs_enemy_look(scanner)
		case "enemy_lookto":			return getArgs_enemy_look(scanner)
		case "enemy_move":				return getArgs_enemy_move(scanner)
		case "enemy_move_to_car":		return getArgs_enemy_move_to_car(scanner)
		case "enemy_naserse":			return getArgs_enemy_naserse(scanner)
		case "enemy_podvadim_jak":		return getArgs_enemy_podvadim_jak(scanner)
		case "enemy_playanim":			return getArgs_enemy_playanim(scanner)
		case "enemy_shut_up":			return []
		case "enemy_stopanim":			return []
		case "enemy_talk":				return getArgs_enemy_talk(scanner)
		case "enemy_use_detector":		return getArgs_enemy_use_detector(scanner)
		case "enemy_usecar":			return getArgs_enemy_usecar(scanner)
		case "enemy_vidim":				return []
		case "enemy_wait":				return []
		case "event_use_cb":			return getArgs_event_use_cb(scanner)
		case "findactor":				return getArgs_findactor(scanner)
		case "findframe":				return getArgs_findframe(scanner)
		case "getactivecamera":			return getArgs_getactivecamera(scanner)
		case "getactiveplayer":			return getArgs_getactiveplayer(scanner)
		case "getangleactortoactor":	return getArgs_getangleactortoactor(scanner)
		case "getactorframe":			return getArgs_getactorframe(scanner)
		case "getfilmmusic":			return getArgs_getfilmmusic(scanner)
		case "frm_getpos":				return getArgs_frm_getpos(scanner)
		case "frm_getnumchildren":		return getArgs_frm_getnumchildren(scanner)
		case "frm_getparent":			return getArgs_frm_getparent(scanner)
		case "frm_getscale":			return getArgs_frm_getscale(scanner)
		case "frm_getworldpos":			return getArgs_frm_getworldpos(scanner)
		case "frm_getworldscale":		return getArgs_frm_getworldscale(scanner)
		case "frm_ison":				return getArgs_frm_ison(scanner)
		case "frm_setpos":				return getArgs_frm_setpos(scanner)
		case "frm_seton":				return getArgs_frm_seton(scanner)
		case "frm_setscale":			return getArgs_frm_setscale(scanner)
		case "garage_enablesteal":		return getArgs_garage_enablesteal(scanner)
		case "getactorsdist":			return getArgs_getactorsdist(scanner)
		case "getenemyaistate":			return getArgs_getenemyaistate(scanner)
		case "getframefromactor":		return getArgs_getframefromactor(scanner)
		case "getgametime":				return getArgs_getgametime(scanner)
		case "get_pm_crashtime":		return getArgs_get_pm_time(scanner)
		case "get_pm_firetime":			return getArgs_get_pm_time(scanner)
		case "get_pm_humanstate":		return getArgs_get_pm_humanstate(scanner)
		case "get_pm_state":			return getArgs_get_pm_state(scanner)
		case "get_remote_actor":		return getArgs_get_remote_actor(scanner)
		case "get_remote_float":		return getArgs_get_remote_float(scanner)
		case "get_remote_frame":		return getArgs_get_remote_frame(scanner)
		case "getticktime":				return getArgs_getticktime(scanner)
		case "goto":					return getArgs_goto(scanner)
		case "gosub":					return getArgs_goto(scanner)
		case "human_activateweapon":	return getArgs_human_activateweapon(scanner)
		case "human_addweapon":			return getArgs_human_addweapon(scanner)
		case "human_anyweaponinhand":	return getArgs_human_anyweaponinhand(scanner)
		case "human_anyweaponininventory":	return getArgs_human_anyweaponininventory(scanner)
		case "human_canaddweapon":		return getArgs_human_canaddweapon(scanner)
		case "human_candie":			return getArgs_human_candie(scanner)
		case "human_death":				return getArgs_human_death(scanner)
		case "human_delweapon":			return getArgs_human_delweapon(scanner)
		case "human_fromcar":			return getArgs_human_fromcar(scanner)
		case "human_force_settocar":	return getArgs_human_force_settocar(scanner)
		case "human_getactanimid":		return getArgs_human_getactanimid(scanner)
		case "human_getiteminrhand":		return getArgs_human_getiteminrhand(scanner)
		case "human_getowner":			return getArgs_human_getowner(scanner)
		case "human_getproperty":		return getArgs_human_getproperty(scanner)
		case "human_getseatidx":		return getArgs_human_getseatidx(scanner)
		case "human_holster":			return getArgs_human_holster(scanner)
		case "human_isweapon":			return getArgs_human_isweapon(scanner)
		case "human_looktoactor":		return getArgs_human_looktoactor(scanner)
		case "human_setproperty":		return getArgs_human_setproperty(scanner)
		case "human_talk":				return getArgs_human_talk(scanner)
		case "if":						return getArgs_if(scanner)
		case "iffltinrange":			return getArgs_iffltinrange(scanner)
		case "ifplayerstealcar":		return getArgs_ifplayerstealcar(scanner)
		case "intro_subtitle_add":		return getArgs_subtitle_add(scanner)
		case "inventory_clear":			return getArgs_inventory_clear(scanner)
		case "iscarusable":				return getArgs_iscarusable(scanner)
		case "ispointinarea":			return getArgs_ispointinarea(scanner)
		case "let":						return getArgs_let(scanner)
		case "loaddifferences":			return getArgs_loaddifferences(scanner)
		case "math_abs":				return getArgs_math_abs(scanner)
		case "math_cos":				return getArgs_math_cos(scanner)
		case "math_sin":				return getArgs_math_sin(scanner)
		case "mission_objectives":		return getArgs_mission_objectives(scanner)
		case "mission_objectivesclear":	return []
		case "mission_objectivesremove":	return getArgs_mission_objectives(scanner)
		case "model_create":			return getArgs_model_create(scanner)
		case "model_destroy":			return getArgs_model_destroy(scanner)
		case "model_playanim":			return getArgs_model_playanim(scanner)
		case "model_stopanim":			return getArgs_model_stopanim(scanner)
		case "person_playanim":			return getArgs_person_playanim(scanner)
		case "person_stopanim":			return getArgs_person_stopanim(scanner)
		case "player_lockcontrols":		return getArgs_player_lockcontrols(scanner)
		case "playsound":				return getArgs_playsound(scanner)
		case "playsoundstop":			return getArgs_playsoundstop(scanner)
		case "policeitchforplayer":		return getArgs_policeitchforplayer(scanner)
		case "pm_showsymbol":			return getArgs_pm_showsymbol(scanner)
		case "recaddactor":				return getArgs_recaddactor(scanner)
		case "recclear":				return []
		case "rnd":						return getArgs_rnd(scanner)
		case "recload":					return getArgs_recload(scanner)
		case "recloadfull":				return getArgs_recload(scanner)
		case "recwaitforend":			return []
		case "recunload":				return []
		case "setcompass":				return getArgs_setcompass(scanner)
		case "setcitytrafficvisible":	return getArgs_setcitytrafficvisible(scanner)
		case "setevent":				return getArgs_setevent(scanner)
		case "setfilmmusic":			return getArgs_setfilmmusic(scanner)
		case "setnullactor":			return getArgs_setnullactor(scanner)
		case "setnullframe":			return getArgs_setnullframe(scanner)
		case "setplayerfireevent":		return getArgs_setplayerevent(scanner)
		case "setplayerhornevent":		return getArgs_setplayerevent(scanner)
		case "settimeoutevent":			return getArgs_settimeoutevent(scanner)
		case "sound_getvolume":			return getArgs_sound_getvolume(scanner)
		case "sound_setvolume":			return getArgs_sound_setvolume(scanner)
		case "soundfade":				return getArgs_soundfade(scanner)
		case "stream_create":			return getArgs_stream_create(scanner)
		case "stream_destroy":			return getArgs_stream_destroy(scanner)
		case "stream_fadevol":			return getArgs_stream_fadevol(scanner)
		case "stream_getpos":			return getArgs_stream_getpos(scanner)
		case "stream_pause":			return getArgs_stream_pause(scanner)
		case "stream_play":				return getArgs_stream_play(scanner)
		case "stream_setpos":			return getArgs_stream_setpos(scanner)
		case "stream_setloop":			return getArgs_stream_setloop(scanner)
		case "stream_stop":				return getArgs_stream_stop(scanner)
		case "subtitle_add":			return getArgs_subtitle_add(scanner)
		case "timer_getinterval":		return getArgs_timer_getinterval(scanner)
		case "timer_setinterval":		return getArgs_timer_setinterval(scanner)
		case "timeroff":				return []
		case "timeron":					return getArgs_timeron(scanner)
		case "vect_add_vect":			return getArgs_vect_add_vect(scanner)
		case "vect_copy":				return getArgs_vect_copy(scanner)
		case "vect_inverse":			return getArgs_vect_inverse(scanner)
		case "vect_magnitude":			return getArgs_vect_magnitude(scanner)
		case "vect_mul_scl":			return getArgs_vect_mul_scl(scanner)
		case "vect_mul_vect":			return getArgs_vect_mul_vect(scanner)
		case "vect_set":				return getArgs_vect_set(scanner)
		case "vect_sub_vect":			return getArgs_vect_sub_vect(scanner)
		case "version_is_editor":		return getArgs_version_is_editor(scanner)
		case "version_is_germany":		return getArgs_version_is_germany(scanner)
		case "vlvp":					return getArgs_vlvp(scanner)
		case "wait":					return getArgs_wait(scanner)
		case "zatmyse":					return getArgs_zatmyse(scanner)
		default:						return []
		}
	}

	// ----

	private func getArgs_act_setstate(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_actor_delete(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_actor_duplicate(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_actor_setdir(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_actor_setplacement(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_actorupdateplacement(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_camera_getfov(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_camera_lock(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_camera_setfov(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_camera_setrange(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_enableus(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_disable_uo(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_setdestroymotor(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_setdooropen(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_breakmotor(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_calm(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_car_forcestop(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_car_getactlevel(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_getseatcount(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_getspeed(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_inwater(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_lock(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_lock_all(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_muststeal(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOptional(scanner) ?? .integer(1)]
	}

	private func getArgs_car_repair(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_car_setactlevel(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_car_setspeed(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOptional(scanner) ?? .integer(0)]
	}

	private func getArgs_change_mission(_ scanner: Scanner) -> [Argument] {
		let folder = scanString(scanner) ?? scanParam(scanner)
		let frameName = scanString(scanner) ?? scanParam(scanner)
		return [.string(folder), .string(frameName), scanVarOrValue(scanner)]
	}

	private func getArgs_commandblock(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_compareactors(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_compareframes(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_compareownerwith(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner)), .label(scanParam(scanner))]
	}

	private func getArgs_compareownerwithex(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOrNull(scanner), .label(scanParam(scanner)), .label(scanParam(scanner))]
	}

	private func getArgs_console_addtext(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_create_physicalobject(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
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

	private func getArgs_setcitytrafficvisible(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_debug_text(_ scanner: Scanner) -> [Argument] {
		return [.string(scanString(scanner) ?? scanParam(scanner))]
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

	private func getArgs_dialog_begin(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_dialog_camswitch(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_dim(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_destroy_physicalobject(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_disablecolls(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_door_enableus(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValueOptional(scanner) ?? .integer(1)]
	}

	private func getArgs_door_getstate(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
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
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_enemy_action_fire(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner)]
		if let attackDistance = scanVarOrValueOptional(scanner) {
			args.append(attackDistance)
		}
		return args
	}

	private func getArgs_enemy_action_follow(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner), scanVarOrValue(scanner)]
		while let option = scanParamOptional(scanner) {
			args.append(.label(option))
		}
		return args
	}

	private func getArgs_enemy_forcescript(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_enemy_car_moveto(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner), scanVarOrValue(scanner)]
		if let movementMode = scanParamOptional(scanner) {
			args.append(.label(movementMode))
		}
		return args
	}

	private func getArgs_enemy_group_add(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner), scanVarOrValue(scanner)]
		if let role = scanParamOptional(scanner) {
			args.append(parseVarOrNumberToken(role) ?? .label(role))
		}
		return args
	}

	private func getArgs_enemy_group_addcar(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner), scanVarOrValue(scanner)]
		if let value = scanVarOrValueOptional(scanner) {
			args.append(value)
		}
		return args
	}

	private func getArgs_enemy_group_chcipni_hajzle(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_enemy_group_del(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner)]
		if let value = scanVarOrValueOptional(scanner) {
			args.append(value)
		}
		return args
	}

	private func getArgs_enemy_group_new(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_enemy_lockstate(_ scanner: Scanner) -> [Argument] {
		return [.string(scanString(scanner) ?? scanParam(scanner))]
	}

	private func getArgs_enemy_playanim(_ scanner: Scanner) -> [Argument] {
		guard let animName = scanString(scanner) else { scriptArgumentFatalError("Expected animation name") }
		return [.string(animName)]
	}

	private func getArgs_enemy_look(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_enemy_move(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner)]
		if let movementMode = scanParamOptional(scanner) {
			args.append(.label(movementMode))
		}
		return args
	}

	private func getArgs_enemy_move_to_car(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner), scanVarOrValue(scanner)]
		if let movementMode = scanParamOptional(scanner) {
			args.append(.label(movementMode))
		}
		return args
	}

	private func getArgs_enemy_naserse(_ scanner: Scanner) -> [Argument] {
		var args = [scanVarOrValue(scanner)]
		if let attackDistance = scanVarOrValueOptional(scanner) {
			args.append(attackDistance)
		}
		return args
	}

	private func getArgs_enemy_podvadim_jak(_ scanner: Scanner) -> [Argument] {
		guard let value = scanParamOptional(scanner) else { return [.integer(1)] }
		return [.label(value)]
	}

	private func getArgs_enemy_usecar(_ scanner: Scanner) -> [Argument] {
		guard let carId = scanVarOrValueOptional(scanner) else { return [] }
		return [carId, scanVarOrValue(scanner)]
	}

	private func getArgs_enemy_talk(_ scanner: Scanner) -> [Argument] {
		var args: [Argument] = []
		while let arg = scanVarOrValueOptional(scanner) {
			args.append(arg)
		}
		guard !args.isEmpty else { scriptArgumentFatalError("Expected at least one enemy_talk argument") }
		return args
	}

	private func getArgs_enemy_use_detector(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_event_use_cb(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
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

	private func getArgs_getactivecamera(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_getactiveplayer(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_getangleactortoactor(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_getactorframe(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_getpos(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_getnumchildren(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_getparent(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_getscale(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_getworldpos(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_getworldscale(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_ison(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_setpos(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_seton(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_frm_setscale(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_getactorsdist(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_getenemyaistate(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_getframefromactor(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_getgametime(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_get_pm_state(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_get_pm_time(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_get_pm_humanstate(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_get_remote_actor(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_get_remote_float(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_get_remote_frame(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_getticktime(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_goto(_ scanner: Scanner) -> [Argument] {
		return [scanLabelTarget(scanner)]
	}

	private func getArgs_human_activateweapon(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_addweapon(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_anyweaponinhand(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_anyweaponininventory(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_canaddweapon(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_candie(_ scanner: Scanner) -> [Argument] {
		let actorId = scanVarOrValue(scanner)
		guard let varId = scanVarOrValueOptional(scanner) else { return [actorId] }
		return [actorId, varId]
	}

	private func getArgs_human_death(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_human_delweapon(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_force_settocar(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_fromcar(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_getactanimid(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_getiteminrhand(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_getowner(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_getproperty(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_human_getseatidx(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_human_holster(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_human_looktoactor(_ scanner: Scanner) -> [Argument] {
		var args: [Argument] = []
		while let arg = scanVarOrValueOptional(scanner) {
			args.append(arg)
		}
		return args
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
		let startIndex = scanner.string.index(scanner.string.startIndex, offsetBy: scanner.scanLocation)
		let rawCondition = String(scanner.string[startIndex...])
		guard let operatorIndex = rawCondition.firstIndex(where: { "=!<>".contains($0) }) else {
			scriptArgumentFatalError("Expected comparison operator")
		}

		let token1 = rawCondition[..<operatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
		let op = String(rawCondition[operatorIndex])
		let remainingTokens = rawCondition[rawCondition.index(after: operatorIndex)...]
			.split(whereSeparator: { $0 == "," || $0.isWhitespace })
			.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "!")) }

		guard let arg1 = parseVarOrNumberToken(token1),
			  remainingTokens.count >= 3,
			  let arg2 = parseVarOrNumberToken(String(remainingTokens[0])) else { return [] }
		let label1 = String(remainingTokens[1])
		let label2 = String(remainingTokens[2])
		return [arg1, .label(op), arg2, .label(label1), .label(label2)]
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

	private func getArgs_ispointinarea(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_inventory_clear(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_let(_ scanner: Scanner) -> [Argument] {
		guard let var1 = scanVar(scanner) else { scriptArgumentFatalError("Expected assignment variable") }

		guard scanner.scanString("=", into: nil) else { scriptArgumentFatalError("Expected assignment operator") }
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
			scriptArgumentFatalError("Expected arithmetic operator")
		}
		scanner.scanCharacters(from: .whitespaces, into: nil)

		return [.variable(var1), arg2, .label(op), scanVarOrValue(scanner)]
	}

	private func getArgs_loaddifferences(_ scanner: Scanner) -> [Argument] {
		guard let name = scanString(scanner) else { scriptArgumentFatalError("Expected differences name") }
		return [.string(name)]
	}

	private func getArgs_math_abs(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_math_cos(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_math_sin(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_mission_objectives(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_model_create(_ scanner: Scanner) -> [Argument] {
		let actorId = scanVarOrValue(scanner)
		guard let name = scanString(scanner) else { scriptArgumentFatalError("Expected model name") }
		return [actorId, .string(name)]
	}

	private func getArgs_model_destroy(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_model_playanim(_ scanner: Scanner) -> [Argument] {
		let actorId = scanVarOrValue(scanner)
		guard let animName = scanString(scanner) else { scriptArgumentFatalError("Expected animation name") }
		return [actorId, .string(animName)]
	}

	private func getArgs_model_stopanim(_ scanner: Scanner) -> [Argument] {
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

	private func getArgs_player_lockcontrols(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_playsound(_ scanner: Scanner) -> [Argument] {
		guard let soundName = scanString(scanner) else { scriptArgumentFatalError("Expected sound name") }
		var args: [Argument] = [
			.string(soundName),
			scanVarOrValue(scanner),
			scanVarOrValue(scanner),
			scanVarOrValue(scanner)
		]
		if let playbackVarId = scanVarOrValueOptional(scanner) {
			args.append(playbackVarId)
		}
		return args
	}

	private func getArgs_playsoundstop(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_policeitchforplayer(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_pm_showsymbol(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_rnd(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_recaddactor(_ scanner: Scanner) -> [Argument] {
		let actorId = scanVarOrValue(scanner)
		let name = scanString(scanner) ?? scanParam(scanner)
		return [actorId, .string(name)]
	}

	private func getArgs_recload(_ scanner: Scanner) -> [Argument] {
		guard let name = scanString(scanner) else { scriptArgumentFatalError("Expected record name") }
		return [.string(name)]
	}

	private func getArgs_setcompass(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_setevent(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner)), .label(scanParam(scanner))]
	}

	private func getArgs_setnullactor(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_setnullframe(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_setplayerevent(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_settimeoutevent(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), .label(scanParam(scanner))]
	}

	private func getArgs_sound_getvolume(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_sound_setvolume(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_soundfade(_ scanner: Scanner) -> [Argument] {
		return [
			scanVarOrValue(scanner),
			scanVarOrValue(scanner),
			scanVarOrValue(scanner),
			scanVarOrValue(scanner)
		]
	}

	private func getArgs_stream_create(_ scanner: Scanner) -> [Argument] {
		let varId = scanVarOrValue(scanner)
		guard let name = scanString(scanner) else { scriptArgumentFatalError("Expected stream name") }
		return [varId, .string(name)]
	}

	private func getArgs_stream_destroy(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_stream_fadevol(_ scanner: Scanner) -> [Argument] {
		return [
			scanVarOrValue(scanner),
			scanVarOrValue(scanner),
			scanVarOrValue(scanner),
			scanVarOrValue(scanner)
		]
	}

	private func getArgs_stream_getpos(_ scanner: Scanner) -> [Argument] {
		let streamId = scanVarOrValue(scanner)
		let varId = scanVarOrValue(scanner)
		return [streamId, varId]
	}

	private func getArgs_stream_pause(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_stream_play(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_stream_setpos(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_stream_setloop(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_stream_stop(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_getfilmmusic(_ scanner: Scanner) -> [Argument] {
		return getArgs_optionalStreamId(scanner)
	}

	private func getArgs_setfilmmusic(_ scanner: Scanner) -> [Argument] {
		return getArgs_optionalStreamId(scanner)
	}

	private func getArgs_optionalStreamId(_ scanner: Scanner) -> [Argument] {
		var args: [Argument] = []
		while let arg = scanVarOrValueOptional(scanner) {
			args.append(arg)
		}
		return args
	}

	private func getArgs_subtitle_add(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_timer_getinterval(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_timer_setinterval(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_timeron(_ scanner: Scanner) -> [Argument] {
		return [
			scanVarOrValue(scanner),
			scanVarOrValue(scanner),
			scanVarOrValue(scanner),
			scanVarOrValue(scanner)
		]
	}

	private func getArgs_vect_add_vect(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_vect_copy(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_vect_inverse(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_vect_magnitude(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_vect_mul_scl(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_vect_mul_vect(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_vect_set(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_vect_sub_vect(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner), scanVarOrValue(scanner)]
	}

	private func getArgs_version_is_editor(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_version_is_germany(_ scanner: Scanner) -> [Argument] {
		return [scanVarOrValue(scanner)]
	}

	private func getArgs_vlvp(_ scanner: Scanner) -> [Argument] {
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
		guard let ret = scanParamOptional(scanner) else { scriptArgumentFatalError("Expected parameter") }
		return ret
	}

	private func scanString(_ scanner: Scanner) -> String? {
		var str: NSString?
		let charset = CharacterSet(charactersIn: "\"")
		guard scanner.scanString("\"", into: nil) else { return nil }
		scanner.scanUpToCharacters(from: charset, into: &str)
		guard scanner.scanString("\"", into: nil) || scanner.isAtEnd else { scriptArgumentFatalError("Expected closing quote") }
		let separator = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanCharacters(from: separator, into: nil)
		return (str as String?) ?? ""
	}

	private func scanVar(_ scanner: Scanner) -> Int? {
		var var1 = 0
		guard scanner.scanString("flt[", into: nil) else { return nil }
		guard scanner.scanInt(&var1) else { scriptArgumentFatalError("Expected variable index") }
		guard scanner.scanString("]", into: nil) else { scriptArgumentFatalError("Expected closing variable bracket") }
		let charset = CharacterSet(charactersIn: ",").union(.whitespaces)
		scanner.scanCharacters(from: charset, into: nil)
		return var1
	}

	private func parseVarOrNumberToken(_ token: String) -> Argument? {
		if token.hasPrefix("flt["), token.hasSuffix("]") {
			let indexStart = token.index(token.startIndex, offsetBy: 4)
			let indexEnd = token.index(before: token.endIndex)
			guard let varId = Int(token[indexStart..<indexEnd]) else { return nil }
			return .variable(varId)
		}
		if token.contains(".") || token.contains("e") || token.contains("E") {
			guard let value = Float(token) else { return nil }
			return .number(value)
		}
		if let value = Int(token) {
			return .integer(value)
		}
		guard let value = Float(token) else { return nil }
		return .number(value)
	}

	private func scanNumber(_ scanner: Scanner) -> Argument? {
		guard let token = scanParamOptional(scanner) else { return nil }
		if token.contains(".") || token.contains("e") || token.contains("E") {
			guard let value = Float(token) else { scriptArgumentFatalError("Expected numeric value, got '\(token)'") }
			return .number(value)
		}
		if let value = Int(token) {
			return .integer(value)
		}
		guard let value = Float(token) else { scriptArgumentFatalError("Expected numeric value, got '\(token)'") }
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
			scriptArgumentFatalError("Expected numeric value")
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
			scriptArgumentFatalError("Expected variable or numeric value")
		}
	}

	private func scanLabelTarget(_ scanner: Scanner) -> Argument {
		let token = scanParam(scanner)
		return parseVarOrNumberToken(token) ?? .label(token)
	}

	private func scanVarOrValueOrNull(_ scanner: Scanner) -> Argument {
		if let varId = scanVar(scanner) {
			return .variable(varId)
		}
		guard let token = scanParamOptional(scanner) else { scriptArgumentFatalError("Expected variable, numeric value, or NULL") }
		if token.lowercased() == "null" {
			return .label(token)
		}
		guard let arg = parseVarOrNumberToken(token) else { scriptArgumentFatalError("Expected variable, numeric value, or NULL, got '\(token)'") }
		return arg
	}

}
