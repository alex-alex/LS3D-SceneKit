//
//  ScriptExec.swift
//  Mafia
//
//  Created by Alex Studnička on 07/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

extension Script {
    
	func performCommand(command: (String, [Argument])) {
		switch command.0 {
//		"{"
//		"}"
//		"act_setstate"
//		"autosavegame"
//		"car_muststeal"
//		"car_setspeed"
//		"commandblock"
		case "compareownerwithex":		compareownerwithex(command.1)
		case "console_addtext":			console_addtext(command.1)
		case "createweaponfromframe":	createweaponfromframe(command.1)
		case "ctrl_read":				ctrl_read(command.1)
		case "detector_inrange":		detector_inrange(command.1)
		case "detector_issignal":		detector_issignal(command.1)
		case "detector_setsignal":		detector_setsignal(command.1)
		case "detector_waitforuse":		detector_waitforuse(command.1)
		case "dim_act":					noop()
		case "dim_flt":					noop()
		case "dim_frm":					noop()
//		"door_lock"
		case "end":						end(command.1)
		case "enemy_playanim":			enemy_playanim(command.1)
		case "event":					event(command.1)
//		"event_use_cb"
		case "findactor":				findactor(command.1)
		case "findframe":				findframe(command.1)
		case "frm_seton":				frm_seton(command.1)
//		"garage_enablesteal"
		case "getactorsdist":			getactorsdist(command.1)
		case "getenemyaistate":			getenemyaistate(command.1)
		case "goto":					goto(command.1)
		case "human_anyweaponinhand":	human_anyweaponinhand(command.1)
		case "human_getactanimid":		human_getactanimid(command.1)
		case "human_getproperty":		human_getproperty(command.1)
//		"human_holster"
		case "human_isweapon":			human_isweapon(command.1)
		case "human_talk":				human_talk(command.1)
		case "if":						`if`(command.1)
//		"ifplayerstealcar"
		case "label":					noop()
		case "let":						`let`(command.1)
		case "mission_objectives":		mission_objectives(command.1)
		case "mission_objectivesclear":	mission_objectivesclear(command.1)
//		"player_lockcontrols"
//		"pm_showsymbol"
		case "return":					`return`(command.1)
		case "rnd":						rnd(command.1)
		case "setcompass":				setcompass(command.1)
		case "setevent":				setevent(command.1)
//		"setplayerfireevent"
//		"setplayerhornevent"
		case "wait":					wait(command.1)
		default:						noop(); // print("UNKNOWN COMMAND: \(command.0)")
		}
	}
	
	// ---
	
	func next() {
		queue.asyncAfter(deadline: .now() + 0.02) { //[unowned self] in
			if !self.executingEvent, !self.eventIdQueue.isEmpty {
				self.currentEventId = self.eventIdQueue.removeFirst()
				self.lineBeforeEvent = self.currentLine
				self.executingEvent = true
				self.currentLine = self.events[self.currentEventId!]!
			} else {
				self.currentLine += 1
			}
			self.run()
		}
	}
	
	func goto(label: String) {
		if label == "-1" { return next() }
		guard let line = labels[label] else { fatalError() }
		currentLine = line
		next()
	}
	
	// ----
	
	private func noop() {
		next()
	}
	
	private func compareownerwithex(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let carId = args[1].getValueOrVarValue(vars: vars)
		let label1 = args[2].getString()
		let label2 = args[3].getString()
		if scene.game.mode == .car {
			goto(label: label1)
		} else {
			goto(label: label2)
		}
	}
	
	private func console_addtext(_ args: [Argument]) {
		let txtId = args[0].getValueOrVarValue(vars: vars)
		print("console_addtext:", TextDb.get(txtId) as Any)
		next()
	}
	
	private func createweaponfromframe(_ args: [Argument]) {
		let frmId = args[0].getValueOrVarValue(vars: vars)
		let weaponId = args[1].getValueOrVarValue(vars: vars)
		let clipAmmo = args.count > 2 ? args[2].getValueOrVarValue(vars: vars) : 0
		let restAmmo = args.count > 3 ? args[3].getValueOrVarValue(vars: vars) : 0
		if let frame = frames[frmId] {
			let weapon = Weapon(id: weaponId, clipAmmo: clipAmmo, restAmmo: restAmmo)
			scene.actions.append(.weapon(frame, weapon))
		}
		next()
	}
	
	private func ctrl_read(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let controlStr = args[1].getString()
		if let control = Control(rawValue: controlStr) {
			vars[varId] = (control == scene.game.lastControl || control == .SPEEDLIMIT) ? 1 : 0
		} else {
			vars[varId] = 0
		}
		next()
	}
	
	private func detector_inrange(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let distance = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = (node.distance(to: scene.playerNode!) <= Float(distance)) ? 1 : 0
		next()
	}
	
	private func detector_issignal(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let label1 = args[1].getString()
		let label2 = args[2].getString()
		
		let script: Script
		if actorId == -1 {
			script = self
		} else {
			script = scene.scripts[actors[actorId]!.name!]!
		}
		
		if script.signal {
			goto(label: label1)
		} else {
			goto(label: label2)
		}
	}
	
	private func detector_setsignal(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let val = args[1].getValueOrVarValue(vars: vars)
		
		let script: Script
		if actorId == -1 {
			script = self
		} else {
			script = scene.scripts[actors[actorId]!.name!]!
		}
		
		script.signal = val == 1
	}
	
	private func detector_waitforuse(_ args: [Argument]) {
		if args.count > 0 {
			let str = TextDb.get(Int(args[0].getString())!)!
			scene.actions.append(.action(self, str))
		} else {
			scene.actions.append(.action(self, nil))
		}
	}
	
	private func end(_ args: [Argument]) {
		
	}
	
	private func enemy_playanim(_ args: [Argument]) {
		let animName = args[0].getString()
		try! playAnimation(named: "anims/"+animName.replacingOccurrences(of: "i3d", with: "5DS"), in: node) {
			self.next()
		}
	}
	
	private func event(_ args: [Argument]) {
		if !executingEvent {
			mainInEvent = true
		}
		next()
	}
	
	private func findactor(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		if args.count > 1 {
			let name = args[1].getString()
			if let node = scene.rootNode.childNode(withName: name, recursively: true) {
				actors[actorId] = node
			}
		} else {
			frames[actorId] = self.node
		}
		next()
	}
	
	private func findframe(_ args: [Argument]) {
		let frmId = args[0].getValueOrVarValue(vars: vars)
		if args.count > 1 {
			let name = args[1].getString()
			if let node = scene.rootNode.childNode(withName: name, recursively: true) {
				frames[frmId] = node
			}
		} else {
			frames[frmId] = self.node
		}
		next()
	}
	
	private func frm_seton(_ args: [Argument]) {
		let frmId = args[0].getValueOrVarValue(vars: vars)
		let setOn = args[1].getValueOrVarValue(vars: vars) == 1
		if let frame = frames[frmId] {
			frame.isHidden = !setOn
			frame.isPaused = !setOn
			if setOn, let sound = scene.sounds[frame] {
				sound.play()
			}
		}
		next()
	}
	
	private func getactorsdist(_ args: [Argument]) {
		let actor1Id = args[0].getValueOrVarValue(vars: vars)
		let actor2Id = args[1].getValueOrVarValue(vars: vars)
		let varId = args[2].getValueOrVarValue(vars: vars)
		if actors[actor1Id]!.name == "plechovkac" {
			vars[varId] = 2
		} else {
			let actor1 = actors[actor1Id]!
			if actor1 == scene.playerNode && scene.game.mode == .car {
				vars[varId] = scene.game.vehicle.node.distance(to: actors[actor2Id]!)
			} else {
				vars[varId] = actor1.distance(to: actors[actor2Id]!)
			}
		}
		next()
	}
	
	private func getenemyaistate(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = 0
		next()
	}
	
	private func goto(_ args: [Argument]) {
		let label = args[0].getString()
		goto(label: label)
	}
	
	private func human_anyweaponinhand(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let actor = actors[actorId], let weapons = scene.weapons[actor], weapons.contains(where: { $0.position == .hand }) {
			vars[varId] = 1
		} else {
			vars[varId] = 0
		}
		next()
	}
	
	private func human_getactanimid(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let node = actors[actorId] {
			vars[varId] = scene.pressedJump ? 98 : 0
		}
		next()
	}
	
	private func human_getproperty(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = 0
		next()
	}
	
	private func human_isweapon(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		let weaponId = args[2].getValueOrVarValue(vars: vars)
		if let actor = actors[actorId], let weapons = scene.weapons[actor], weapons.contains(where: { $0.id == weaponId }) {
			vars[varId] = 1
		} else {
			vars[varId] = 0
		}
		next()
	}
	
	private func human_talk(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let soundId = args[1].getString()
//		let _ = args[2].getValueOrVarValue(vars: vars)
		
		if soundId == "21990001" {
			return goto(label: "20")
		}
		
		if let node = actors[actorId] {
			let url = mainDirectory.appendingPathComponent("sounds/\(soundId).wav")
			let source = SCNAudioSource(url: url)!
			source.load()
			node.runAction(SCNAction.playAudio(source, waitForCompletion: true)) {
				self.next()
			}
		} else {
			fatalError()
		}
	}
	
	private func `if`(_ args: [Argument]) {
		let value1 = args[0].getValueOrVarValueFloat(vars: vars)
		
		let opStr = args[1].getString()
		let operation: (Float, Float) -> Bool
		if opStr == "=" {
			operation = (==)
		} else if opStr == "!" {
			operation = (!=)
		} else if opStr == "<" {
			operation = (<)
		} else if opStr == ">" {
			operation = (>)
		} else {
			fatalError()
		}
		
		let value2 = args[2].getValueOrVarValueFloat(vars: vars)
		
		let label1 = args[3].getString()
		let label2 = args[4].getString()
		
		if operation(value1, value2) {
			goto(label: label1)
		} else {
			goto(label: label2)
		}
	}
	
	private func `let`(_ args: [Argument]) {
		guard case .variable(let var1) = args[0] else { fatalError() }
		
		let value2 = args[1].getValueOrVarValueFloat(vars: vars)
		
		if args.count < 3 {
			vars[var1] = value2
			return next()
		}
		
		let opStr = args[2].getString()
		let operation: (Float, Float) -> Float
		if opStr == "+" {
			operation = (+)
		} else if opStr == "-" {
			operation = (-)
		} else if opStr == "*" {
			operation = (*)
		} else if opStr == "/" {
			operation = (/)
		} else {
			fatalError()
		}
		
		let value3 = args[3].getValueOrVarValueFloat(vars: vars)
		
		vars[var1] = operation(value2, value3)
		next()
	}
	
	private func mission_objectives(_ args: [Argument]) {
		let txtId = args[0].getString()
		scene.objectives.append(Int(txtId)!)
		next()
	}
	
	private func mission_objectivesclear(_ args: [Argument]) {
		scene.objectives.removeAll()
		next()
	}
	
	private func `return`(_ args: [Argument]) {
		if executingEvent {
			completionHandler?()
			completionHandler = nil
			currentEventId = nil
			executingEvent = false
			currentLine = lineBeforeEvent
			lineBeforeEvent = 0
		}
		next()
	}
	
	private func rnd(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let upperBound = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = Float(arc4random_uniform(UInt32(upperBound)))
		next()
	}
	
	private func setcompass(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		if frameId == -1 {
			scene.compassNode = nil
		} else {
			scene.compassNode = frames[frameId]
		}
		next()
	}
	
	private func setevent(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let eventId = args[1].getString()
		let labelId = args[2].getString()
		
		if let name = actors[actorId]?.name, let script = scene.scripts[name] {
			script.eventIdQueue.append(eventId)
			goto(label: labelId)
		} else {
			print("set_event: script not found")
			next()
		}
	}
	
	private func wait(_ args: [Argument]) {
		let delay = args[0].getValueOrVarValue(vars: vars)
		queue.asyncAfter(deadline: .now() + .milliseconds(delay), execute: next)
	}
	
}
