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
		case "act_setstate":			act_setstate(command.1)
//		"autosavegame"
		case "actor_setplacement":		actor_setplacement(command.1)
		case "car_getspeed":			car_getspeed(command.1)
		case "car_muststeal":			car_muststeal(command.1)
		case "car_repair":				car_repair(command.1)
		case "car_setspeed":			car_setspeed(command.1)
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
		case "door_enableus":			door_enableus(command.1)
		case "door_lock":				door_lock(command.1)
		case "door_open":				door_open(command.1)
		case "end":						end(command.1)
		case "end!":					end(command.1)
		case "endofmission":			endofmission(command.1)
		case "enemy_playanim":			enemy_playanim(command.1)
		case "event":					event(command.1)
		case "event_use_cb":			noop()
		case "findactor":				findactor(command.1)
		case "findframe":				findframe(command.1)
		case "frm_seton":				frm_seton(command.1)
		case "garage_enablesteal":		garage_enablesteal(command.1)
		case "getactorsdist":			getactorsdist(command.1)
		case "getenemyaistate":			getenemyaistate(command.1)
		case "goto":					goto(command.1)
		case "human_anyweaponinhand":	human_anyweaponinhand(command.1)
		case "human_getactanimid":		human_getactanimid(command.1)
		case "human_getproperty":		human_getproperty(command.1)
		case "human_holster":			human_holster(command.1)
		case "human_isweapon":			human_isweapon(command.1)
		case "human_setproperty":		human_setproperty(command.1)
		case "human_talk":				human_talk(command.1)
		case "if":						`if`(command.1)
		case "iffltinrange":			iffltinrange(command.1)
		case "ifplayerstealcar":		ifplayerstealcar(command.1)
		case "iscarusable":				iscarusable(command.1)
		case "label":					noop()
		case "let":						`let`(command.1)
		case "mission_objectives":		mission_objectives(command.1)
		case "mission_objectivesclear":	mission_objectivesclear(command.1)
		case "person_playanim":			person_playanim(command.1)
		case "person_stopanim":			person_stopanim(command.1)
		case "player_lockcontrols":		noop()
		case "pm_showsymbol":			noop()
		case "return":					`return`(command.1)
		case "return!":					`return`(command.1)
		case "rnd":						rnd(command.1)
		case "setcompass":				setcompass(command.1)
		case "setevent":				setevent(command.1)
		case "setplayerfireevent":		setplayerfireevent(command.1)
		case "setplayerhornevent":		setplayerhornevent(command.1)
		case "wait":					wait(command.1)
		default:						noop(); // print("UNKNOWN COMMAND: \(command.0)")
		}
	}

	// ---

	func next() {
		queue.asyncAfter(deadline: .now() + 0.02) { //[unowned self] in
			guard !self.isPaused else {
				self.hasPendingNext = true
				return
			}

			if !self.executingEvent, !self.eventIdQueue.isEmpty {
				self.currentEventId = self.eventIdQueue.removeFirst()
				self.lineBeforeEvent = self.currentLine
				if let currentEventId = self.currentEventId,
				   let eventLine = self.events[currentEventId] {
					self.executingEvent = true
					self.currentLine = eventLine
				} else {
					self.currentEventId = nil
					self.currentLine += 1
				}
			} else {
				self.currentLine += 1
			}
			self.run()
		}
	}

	func goto(label: String) {
		if label == "-1" { return next() }
		guard let line = labels[label] else {
			next()
			return
		}
		if line + 1 == currentLine {
			next()
			return
		}
		currentLine = line
		next()
	}

	// ----

	private func noop() {
		next()
	}

	private func act_setstate(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let state = args[1].getString().lowercased()
		if let target = node(forScriptId: actorId) {
			target.actionsEnabled = state != "inactive"
		}
		next()
	}

	private func actor_setplacement(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let frameId = args[1].getValueOrVarValue(vars: vars)
		if let actor = node(forScriptId: actorId),
		   let frame = node(forScriptId: frameId) {
			let transform = frame.presentation.worldTransform
			if let parent = actor.parent {
				actor.transform = parent.convertTransform(transform, from: nil)
			} else {
				actor.transform = transform
			}
		}
		next()
	}

	private func car_getspeed(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if playerOwnerMatches(carId: carId), let vehicle = scene.game.vehicle {
			vars[varId] = Float(vehicle.speed)
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func car_muststeal(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let enabled = args.count < 2 || args[1].getValueOrVarValue(vars: vars) != 0
		scene.game.setVehicleStealEnabled(carId: carId, node: node(forScriptId: carId), enabled: enabled)
		next()
	}

	private func car_repair(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		if playerOwnerMatches(carId: carId) {
			scene.game.vehicle?.node.physicsBody?.velocity = SCNVector3Zero
			scene.game.vehicle?.node.physicsBody?.angularVelocity = SCNVector4Zero
		}
		next()
	}

	private func car_setspeed(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let speed = args[1].getValueOrVarValueFloat(vars: vars)
		if speed == 0, playerOwnerMatches(carId: carId) {
			scene.game.vehicle?.updateControls(throttle: 0, brake: true, steering: 0)
			scene.game.vehicle?.node.physicsBody?.velocity = SCNVector3Zero
			scene.game.vehicle?.node.physicsBody?.angularVelocity = SCNVector4Zero
		}
		next()
	}

	private func compareownerwithex(_ args: [Argument]) {
		let _ = args[0].getValueOrVarValue(vars: vars) // actorId
		let carId = args[1].getValueOrVarValue(vars: vars)
		let label1 = args[2].getString()
		let label2 = args[3].getString()
		if playerOwnerMatches(carId: carId) {
			goto(label: label1)
		} else {
			goto(label: label2)
		}
	}

	private func console_addtext(_ args: [Argument]) {
		let txtId = args[0].getValueOrVarValue(vars: vars)
		let text = TextDb.get(txtId) ?? "\(txtId)"
		DispatchQueue.main.async {
			self.scene.game.hud?.showConsoleText(text)
		}
		next()
	}

	private func createweaponfromframe(_ args: [Argument]) {
		let frmId = args[0].getValueOrVarValue(vars: vars)
		let weaponId = args[1].getValueOrVarValue(vars: vars)
		let clipAmmo = args.count > 2 ? args[2].getValueOrVarValue(vars: vars) : 0
		let restAmmo = args.count > 3 ? args[3].getValueOrVarValue(vars: vars) : 0
		if let frame = frames[frmId] {
			let weapon = Weapon(id: weaponId, clipAmmo: clipAmmo, restAmmo: restAmmo)
			if args.count <= 2, let profile = weapon.profile {
				weapon.clipAmmo = profile.clipSize
			}
			scene.actions.append(.weapon(frame, weapon))
		}
		next()
	}

	private func ctrl_read(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let controlStr = args[1].getString()
		if let control = Control(scriptName: controlStr) {
			let normalized = controlStr.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
			let isSecondaryAlias = normalized.hasSuffix("1")
			let isPressed = scene.game.isControlPressed(control)
			let wasPressed = !isSecondaryAlias && (isPressed || scene.game.consumeLastControl(control))
			vars[varId] = wasPressed ? 1 : 0
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func detector_inrange(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let distance = args[1].getValueOrVarValue(vars: vars)
		if let playerNode = scene.playerNode {
			vars[varId] = (node.distance(to: playerNode) <= Float(distance)) ? 1 : 0
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func detector_issignal(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let label1 = args[1].getString()
		let label2 = args[2].getString()

		guard let script = script(forActorId: actorId) else {
			goto(label: label2)
			return
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

		script(forActorId: actorId)?.signal = val == 1
		next()
	}

	private func detector_waitforuse(_ args: [Argument]) {
		if args.count > 0 {
			let txtId = args[0].getValueOrVarValue(vars: vars)
			let str = TextDb.get(txtId)
			scene.actions.append(.action(self, str))
		} else {
			scene.actions.append(.action(self, nil))
		}
	}

	private func door_enableus(_ args: [Argument]) {
		let targetId = args[0].getValueOrVarValue(vars: vars)
		let isEnabled = args[1].getValueOrVarValue(vars: vars) != 0
		guard let target = node(forScriptId: targetId) else {
			next()
			return
		}
		if isEnabled {
			if target.doorData == nil {
				scene.actions.append(.door(target))
			}
		} else {
			for index in scene.actions.indices.reversed() {
				if case .door(let doorNode) = scene.actions[index],
				   doorNode === target {
					scene.actions.remove(at: index)
				}
			}
		}
		next()
	}

	private func door_lock(_ args: [Argument]) {
		guard let targetId = args.first?.getValueOrVarValue(vars: vars) else {
			next()
			return
		}
		let locked = args.count > 1 ? args[1].getValueOrVarValue(vars: vars) != 0 : true
		node(forScriptId: targetId)?.doorData?.isLocked = locked
		next()
	}

	private func door_open(_ args: [Argument]) {
		let targetId = args[0].getValueOrVarValue(vars: vars)
		let shouldOpen = args[1].getValueOrVarValue(vars: vars) != 0
		if let door = node(forScriptId: targetId)?.doorData {
			door.isLocked = false
			door.isOpen = shouldOpen
		}
		next()
	}

	private func end(_ args: [Argument]) {
		isRunning = false
		completionHandler?()
	}

	private func endofmission(_ args: [Argument]) {
		let text = args.count > 1 ? TextDb.get(args[1].getValueOrVarValue(vars: vars)) : nil
		DispatchQueue.main.async {
			self.scene.game.hud?.showConsoleText(text ?? "Mission complete")
		}
		end(args)
	}

	private func enemy_playanim(_ args: [Argument]) {
		let animName = args[0].getString()
		DispatchQueue.main.async {
			try? playAnimation(named: "anims/"+animName.replacingOccurrences(of: "i3d", with: "5DS"), in: self.node)
		}
		next()
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
			if let node = findNode(named: name) {
				actors[actorId] = node
			}
		} else {
			actors[actorId] = self.node
		}
		next()
	}

	private func findframe(_ args: [Argument]) {
		let frmId = args[0].getValueOrVarValue(vars: vars)
		if args.count > 1 {
			let name = args[1].getString()
			if let node = findNode(named: name) {
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
		guard let actor1 = actors[actor1Id],
			  let actor2 = actors[actor2Id] else {
			vars[varId] = 0
			next()
			return
		}
		vars[varId] = actor1.distance(to: actor2)
		next()
	}

	private func getenemyaistate(_ args: [Argument]) {
		let _ = args[0].getValueOrVarValue(vars: vars) // actorId
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
		if let actor = actors[actorId],
			let weapons = scene.weapons[actor],
			weapons.contains(where: { $0.position == .hand }) {
			vars[varId] = 1
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func human_getactanimid(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if actors[actorId] != nil {
			vars[varId] = Float(scene.currentActionAnimationId())
		}
		next()
	}

	private func human_getproperty(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		let property = args[2].getString().lowercased()
		if property == "energy" {
			if isPlayerActor(actorId) {
				vars[varId] = Float(scene.game.playerHealth)
			} else if let actor = node(forScriptId: actorId) {
				vars[varId] = humanEnergy(for: actor)
			} else {
				vars[varId] = 0
			}
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func human_holster(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		guard let actor = node(forScriptId: actorId) else {
			next()
			return
		}
		holsterWeapons(for: actor)
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

	private func human_setproperty(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let value = args[1].getValueOrVarValue(vars: vars)
		let property = args[2].getString().lowercased()
		if property == "energy" {
			if isPlayerActor(actorId) {
				scene.game.setPlayerHealth(value)
			} else if let actor = node(forScriptId: actorId) {
				humanNode(for: actor)?.humanEnergy = max(0, Float(value))
			}
		}
		next()
	}

	private func human_talk(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let soundId = args[1].getString()

		if let url = mafiaResourceURL(directory: "sounds", name: "\(soundId).wav"),
		   let source = SCNAudioSource(url: url) {
			source.isPositional = false
			source.load()
			DispatchQueue.main.async {
				self.scene.playAudio(source, url: url, on: self.scene.rootNode) {
					self.next()
				}
			}
		} else {
			next()
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

	private func iffltinrange(_ args: [Argument]) {
		let value = args[0].getValueOrVarValueFloat(vars: vars)
		let lowerBound = args[1].getValueOrVarValueFloat(vars: vars)
		let upperBound = args[2].getValueOrVarValueFloat(vars: vars)
		let label = args[3].getString()

		if value >= lowerBound && value <= upperBound {
			goto(label: label)
		} else {
			next()
		}
	}

	private func garage_enablesteal(_ args: [Argument]) {
		let enabled = args.first?.getString().uppercased() != "F"
		if enabled {
			for (carId, actor) in actors where actor.type == .car || actor.name?.lowercased() == "taxi2" {
				scene.game.setVehicleStealEnabled(carId: carId, node: actor, enabled: true)
			}
		}
		next()
	}

	private func ifplayerstealcar(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = scene.game.didPlayerStealVehicle(carId: actorId) ? 1 : 0
		next()
	}

	private func iscarusable(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = node(forScriptId: carId) != nil ? 1 : 0
		next()
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
		let txtId = args[0].getValueOrVarValue(vars: vars)
		if txtId >= 0 {
			scene.objectives.append(txtId)
		}
		next()
	}

	private func mission_objectivesclear(_ args: [Argument]) {
		scene.objectives.removeAll()
		next()
	}

	private func person_playanim(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		guard args.count > 1,
			  let actor = node(forScriptId: actorId) else {
			next()
			return
		}
		let animName = args[1].getString()
		DispatchQueue.main.async {
			try? playAnimation(named: "anims/"+animName.replacingOccurrences(of: "i3d", with: "5DS"), in: actor)
		}
		next()
	}

	private func person_stopanim(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		node(forScriptId: actorId)?.removeAllAnimations()
		next()
	}

	private func `return`(_ args: [Argument]) {
		if executingEvent {
			eventCompletionHandler?()
			eventCompletionHandler = nil
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

		if let script = script(forActorId: actorId) {
			script.enqueueEvent(eventId)
			goto(label: labelId)
		} else {
			print("set_event: script not found")
			next()
		}
	}

	private func setplayerfireevent(_ args: [Argument]) {
		setPlayerEvent(args, keyPath: \.playerFireEvent)
	}

	private func setplayerhornevent(_ args: [Argument]) {
		setPlayerEvent(args, keyPath: \.playerHornEvent)
	}

	private func setPlayerEvent(_ args: [Argument], keyPath: ReferenceWritableKeyPath<Scene, ScriptEventBinding?>) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let eventId = args[1].getString()

		guard actorId != -1, eventId != "-1" else {
			scene[keyPath: keyPath] = nil
			next()
			return
		}

		if let script = script(forActorId: actorId) {
			scene[keyPath: keyPath] = ScriptEventBinding(script: script, eventId: eventId)
		} else {
			scene[keyPath: keyPath] = nil
		}
		next()
	}

	private func wait(_ args: [Argument]) {
		let delay = args[0].getValueOrVarValue(vars: vars)
		queue.asyncAfter(deadline: .now() + .milliseconds(delay), execute: next)
	}

	private func findNode(named name: String) -> SCNNode? {
		if name.lowercased() == "root" {
			return node
		}
		return scene.game.scnScene.rootNode.mafiaChildNode(named: name, recursively: true)
	}

	private func node(forScriptId id: Int) -> SCNNode? {
		if id == -1 {
			return node
		}
		return actors[id] ?? frames[id]
	}

	private func script(forActorId actorId: Int) -> Script? {
		if actorId == -1 {
			return self
		}
		guard let actor = actors[actorId] else { return nil }
		if actor === scene.rootNode {
			return scene.initScripts["root"] ?? scene.initScripts.values.first
		}
		guard let name = actor.name else { return nil }
		return scene.scripts[name] ?? scene.initScripts[name]
	}

	private func holsterWeapons(for actor: SCNNode) {
		if let weapons = scene.weapons[actor] {
			for weapon in weapons {
				weapon.position = .inventory
			}
		}

		if actor === scene.playerNode || actor.name == scene.playerNode?.name,
		   let playerNode = scene.playerNode,
		   let weapons = scene.weapons[playerNode] {
			for weapon in weapons {
				weapon.position = .inventory
			}
		}
	}

	private func playerOwnerMatches(carId: Int) -> Bool {
		scene.game.playerOwnerMatches(carNode: node(forScriptId: carId))
	}

	private func isPlayerActor(_ actorId: Int) -> Bool {
		guard let actor = node(forScriptId: actorId),
			  let playerNode = scene.playerNode else { return false }
		return actor === playerNode || actor.name == playerNode.name || actor.name?.lowercased() == "tommyhat"
	}

	private func humanEnergy(for node: SCNNode) -> Float {
		guard let humanNode = humanNode(for: node) else { return 0 }
		return humanNode.humanEnergy ?? 100
	}

	private func humanNode(for node: SCNNode) -> SCNNode? {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.humanEnergy != nil || candidate.type == .player {
				if candidate.humanEnergy == nil {
					candidate.humanEnergy = 100
				}
				return candidate
			}
			current = candidate.parent
		}

		for child in node.childNodes {
			if let humanNode = humanNode(for: child) {
				return humanNode
			}
		}
		return nil
	}

}
