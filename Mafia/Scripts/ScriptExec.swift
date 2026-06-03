//
//  ScriptExec.swift
//  Mafia
//
//  Created by Alex Studnička on 07/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import AVFoundation
import SceneKit

extension Script {

	private static let loopYieldInterval: DispatchTimeInterval = .milliseconds(16)

	func performCommand(command: ScriptCommand) {
		switch command.name {
//		"{"
//		"}"
		case .actSetstate:				act_setstate(command.args)
//		"autosavegame"
		case .actorSetplacement:		actor_setplacement(command.args)
		case .carGetspeed:				car_getspeed(command.args)
		case .carMuststeal:				car_muststeal(command.args)
		case .carRepair:				car_repair(command.args)
		case .carSetspeed:				car_setspeed(command.args)
		case .cleardifferences:			cleardifferences(command.args)
		case .commandblock:				commandblock(command.args)
		case .compareownerwithex:		compareownerwithex(command.args)
		case .consoleAddtext:			console_addtext(command.args)
		case .createweaponfromframe:		createweaponfromframe(command.args)
		case .ctrlRead:					ctrl_read(command.args)
		case .detectorInrange:			detector_inrange(command.args)
		case .detectorIssignal:			detector_issignal(command.args)
		case .detectorSetsignal:			detector_setsignal(command.args)
		case .detectorWaitforuse:		detector_waitforuse(command.args)
		case .dimAct:					noop()
		case .dimFlt:					noop()
		case .dimFrm:					noop()
		case .doorEnableus:				door_enableus(command.args)
		case .doorLock:					door_lock(command.args)
		case .doorOpen:					door_open(command.args)
		case .end:						end(command.args)
		case .endBang:					end(command.args)
		case .endofmission:				endofmission(command.args)
		case .enemyPlayanim:			enemy_playanim(command.args)
		case .event:					event(command.args)
		case .eventUseCb:				noop()
		case .findactor:				findactor(command.args)
		case .findframe:				findframe(command.args)
		case .frmSeton:					frm_seton(command.args)
		case .garageEnablesteal:		garage_enablesteal(command.args)
		case .getactorsdist:			getactorsdist(command.args)
		case .getenemyaistate:			getenemyaistate(command.args)
		case .goto:						goto(command.args)
		case .humanActivateweapon:		human_activateweapon(command.args)
		case .humanAddweapon:			human_addweapon(command.args)
		case .humanAnyweaponinhand:		human_anyweaponinhand(command.args)
		case .humanAnyweaponininventory:	human_anyweaponininventory(command.args)
		case .humanCanaddweapon:		human_canaddweapon(command.args)
		case .humanGetactanimid:		human_getactanimid(command.args)
		case .humanGetproperty:			human_getproperty(command.args)
		case .humanHolster:				human_holster(command.args)
		case .humanIsweapon:			human_isweapon(command.args)
		case .humanSetproperty:			human_setproperty(command.args)
		case .humanTalk:				human_talk(command.args)
		case .`if`:						`if`(command.args)
		case .iffltinrange:				iffltinrange(command.args)
		case .ifplayerstealcar:			ifplayerstealcar(command.args)
		case .introSubtitleAdd:			subtitle_add(command.args)
		case .iscarusable:				iscarusable(command.args)
		case .label:					noop()
		case .`let`:					`let`(command.args)
		case .loaddifferences:			loaddifferences(command.args)
		case .missionObjectives:		mission_objectives(command.args)
		case .missionObjectivesclear:	mission_objectivesclear(command.args)
		case .personPlayanim:			person_playanim(command.args)
		case .personStopanim:			person_stopanim(command.args)
		case .playerLockcontrols:		noop()
		case .pmShowsymbol:				noop()
		case .recload:					recload(command.args, full: false)
		case .recloadfull:				recload(command.args, full: true)
		case .recwaitforend:			recwaitforend(command.args)
		case .recunload:				recunload(command.args)
		case .`return`:					`return`(command.args)
		case .returnBang:				`return`(command.args)
		case .rnd:						rnd(command.args)
		case .setcompass:				setcompass(command.args)
		case .setevent:					setevent(command.args)
		case .setplayerfireevent:		setplayerfireevent(command.args)
		case .setplayerhornevent:		setplayerhornevent(command.args)
		case .streamCreate:				stream_create(command.args)
		case .streamDestroy:			stream_destroy(command.args)
		case .streamFadevol:			stream_fadevol(command.args)
		case .streamGetpos:				stream_getpos(command.args)
		case .streamPause:				stream_pause(command.args)
		case .streamPlay:				stream_play(command.args)
		case .streamSetloop:			stream_setloop(command.args)
		case .streamStop:				stream_stop(command.args)
		case .subtitleAdd:				subtitle_add(command.args)
		case .wait:						wait(command.args)
		case .zatmyse:					zatmyse(command.args)
		case .unknown:					noop(); // print("UNKNOWN COMMAND: \(command.rawName)")
		}
	}

	// ---

	func next() {
		queue.async { //[unowned self] in
			guard !self.isPaused else {
				self.hasPendingNext = true
				return
			}

			if !self.executingEvent, self.commandBlockDepth == 0, let eventId = self.dequeueEventId() {
				self.currentEventId = eventId
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
			/*if commandBlockDepth > 0 {
				fatalError("Unknown label '\(label)' in commandblock")
			}*/
			next()
			return
		}
		if line + 1 == currentLine {
			next()
			return
		}
		let isBackwardJump = line < currentLine
		currentLine = line
		if isBackwardJump {
			queue.asyncAfter(deadline: .now() + Self.loopYieldInterval) {
				self.next()
			}
		} else {
			next()
		}
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

	private func cleardifferences(_ args: [Argument]) {
		scene.clearDifferenceFiles()
		next()
	}

	private func commandblock(_ args: [Argument]) {
		let mode = args[0].getValueOrVarValue(vars: vars)
		switch mode {
		case 0:
			if commandBlockDepth == 1 && pendingCommandBlockAsyncOperations > 0 {
				isWaitingForCommandBlockAsyncOperations = true
				return
			}
			commandBlockDepth -= 1

		case 1:
			commandBlockDepth += 1

		default:
			fatalError("Unsupported commandblock value \(mode)")
		}
		next()
	}

	private var isExecutingCommandBlock: Bool {
		return commandBlockDepth > 0
	}

	private func beginCommandBlockAsyncOperation() -> Bool {
		guard isExecutingCommandBlock else { return false }
		pendingCommandBlockAsyncOperations += 1
		return true
	}

	private func finishCommandBlockAsyncOperation() {
		queue.async {
			guard self.pendingCommandBlockAsyncOperations > 0 else { return }
			self.pendingCommandBlockAsyncOperations -= 1
			guard self.isWaitingForCommandBlockAsyncOperations,
				  self.pendingCommandBlockAsyncOperations == 0 else {
				return
			}
			self.isWaitingForCommandBlockAsyncOperations = false
			self.commandBlockDepth -= 1
			self.next()
		}
	}

	func completeActionWait() {
		queue.async {
			if self.isExecutingCommandBlock || self.isWaitingForCommandBlockAsyncOperations {
				self.finishCommandBlockAsyncOperation()
			} else {
				self.next()
			}
		}
	}

	private func compareownerwithex(_ args: [Argument]) {
		let _ = args[0].getValueOrVarValue(vars: vars) // actorId
		let carId = args[1].getValueOrVarValue(vars: vars)
		let label1 = args[2].getString()
		let label2 = args[3].getString()
		if playerOwnerMatches(carId: carId) {
			goto(label: label2)
		} else {
			goto(label: label1)
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
		let waitsForCommandBlock = beginCommandBlockAsyncOperation()
		if args.count > 0 {
			let txtId = args[0].getValueOrVarValue(vars: vars)
			let str = TextDb.get(txtId)
			scene.actions.append(.action(self, str))
		} else {
			scene.actions.append(.action(self, nil))
		}
		if waitsForCommandBlock {
			next()
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
		let returnsToMainMenu = args.first?.getValueOrVarValue(vars: vars) == 1
		let text = args.count > 1 ? TextDb.get(args[1].getValueOrVarValue(vars: vars)) : nil
		DispatchQueue.main.async {
			self.scene.game.endMission(returnsToMainMenu: returnsToMainMenu, message: text)
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

	private func human_activateweapon(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let weaponId = args[1].getValueOrVarValue(vars: vars)
		guard let actor = weaponOwnerNode(forScriptId: actorId),
			  let weapons = scene.weapons[actor],
			  let selectedWeapon = weapons.first(where: { $0.id == weaponId }) else {
			next()
			return
		}
		for weapon in weapons {
			weapon.position = weapon === selectedWeapon ? .hand : .inventory
		}
		refreshPlayerWeaponHudIfNeeded(for: actor)
		next()
	}

	private func human_addweapon(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let weaponId = args[1].getValueOrVarValue(vars: vars)
		let clipAmmo = args[2].getValueOrVarValue(vars: vars)
		let restAmmo = args[3].getValueOrVarValue(vars: vars)
		guard let actor = weaponOwnerNode(forScriptId: actorId),
			  canAddWeapon(weaponId: weaponId) else {
			next()
			return
		}
		let weapon = Weapon(id: weaponId, clipAmmo: clipAmmo, restAmmo: restAmmo)
		weapon.position = .inventory
		if scene.weapons[actor] == nil {
			scene.weapons[actor] = []
		}
		scene.weapons[actor]?.append(weapon)
		refreshPlayerWeaponHudIfNeeded(for: actor)
		next()
	}

	private func human_anyweaponinhand(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let actor = weaponOwnerNode(forScriptId: actorId),
			let weapons = scene.weapons[actor],
			weapons.contains(where: { $0.position == .hand }) {
			vars[varId] = 1
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func human_anyweaponininventory(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let actor = weaponOwnerNode(forScriptId: actorId),
		   let weapons = scene.weapons[actor],
		   !weapons.isEmpty {
			vars[varId] = 1
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func human_canaddweapon(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let weaponId = args[1].getValueOrVarValue(vars: vars)
		let varId = args[2].getValueOrVarValue(vars: vars)
		if weaponOwnerNode(forScriptId: actorId) != nil, canAddWeapon(weaponId: weaponId) {
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
		if let actor = weaponOwnerNode(forScriptId: actorId), let weapons = scene.weapons[actor], weapons.contains(where: { $0.id == weaponId }) {
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
			let waitsForCommandBlock = beginCommandBlockAsyncOperation()
			DispatchQueue.main.async {
				if let actor = self.node(forScriptId: actorId) {
					try? playFaceAnimation(soundName: soundId, in: actor)
				}
				self.scene.playAudio(source, url: url, on: self.scene.rootNode) {
					if waitsForCommandBlock {
						self.finishCommandBlockAsyncOperation()
					} else {
						self.next()
					}
				}
			}
			if waitsForCommandBlock {
				next()
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

	private func loaddifferences(_ args: [Argument]) {
		let name = args[0].getString()
		let waitsForCommandBlock = beginCommandBlockAsyncOperation()
		scene.loadDifferenceFileAsync(named: name) { result in
			if case .failure(let error) = result {
				print("Failed to load differences '\(name)':", error)
			}
			if waitsForCommandBlock {
				self.finishCommandBlockAsyncOperation()
			}
		}
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

	private func recload(_ args: [Argument], full: Bool) {
		let name = args[0].getString()
		let waitsForCommandBlock = beginCommandBlockAsyncOperation()
		scene.loadRecordAsync(named: name, full: full) { result in
			self.queue.async {
				switch result {
				case .success:
					if waitsForCommandBlock {
						self.finishCommandBlockAsyncOperation()
					} else {
						self.next()
					}

				case .failure(let error):
					print("Failed to load record '\(name)':", error)
					if waitsForCommandBlock {
						self.finishCommandBlockAsyncOperation()
					} else {
						self.next()
					}
				}
			}
		}
		if waitsForCommandBlock {
			next()
		}
	}

	private func recwaitforend(_ args: [Argument]) {
		let duration = scene.activeRecordPlaybackDuration()
		print("== Record script wait for end: \(String(format: "%.2f", duration))s")
		scene.setCutsceneScriptsPaused(true, except: [self])
		guard duration > 0 else {
			scene.setCutsceneScriptsPaused(false)
			next()
			return
		}
		let waitsForCommandBlock = beginCommandBlockAsyncOperation()
		waitForCutscene(secondsRemaining: duration, lastTick: Date.timeIntervalSinceReferenceDate) {
			if waitsForCommandBlock {
				self.finishCommandBlockAsyncOperation()
			} else {
				self.next()
			}
		}
		if waitsForCommandBlock {
			next()
		}
	}

	private func waitForCutscene(secondsRemaining: TimeInterval, lastTick: TimeInterval, completion: @escaping () -> Void) {
		let interval: TimeInterval = 0.1
		queue.asyncAfter(deadline: .now() + interval) {
			let now = Date.timeIntervalSinceReferenceDate
			let elapsed = self.scene.game.isGamePaused ? 0 : now - lastTick
			let remaining = secondsRemaining - elapsed
			guard remaining > 0, !self.scene.consumeCutsceneSkipRequest() else {
				self.scene.setCutsceneScriptsPaused(false)
				completion()
				return
			}
			self.waitForCutscene(secondsRemaining: remaining, lastTick: now, completion: completion)
		}
	}

	private func recunload(_ args: [Argument]) {
		scene.unloadRecords()
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

	private func stream_create(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let name = args[1].getString()
		guard let url = musicStreamURL(named: name),
			  let stream = ScriptMusicStream(url: url) else {
			vars[varId] = 0
			next()
			return
		}

		let streamId = nextStreamId
		nextStreamId += 1
		streams[streamId] = stream
		vars[varId] = Float(streamId)
		next()
	}

	private func stream_destroy(_ args: [Argument]) {
		let streamId = args[0].getValueOrVarValue(vars: vars)
		if let stream = streams.removeValue(forKey: streamId) {
			DispatchQueue.main.async {
				stream.destroy()
			}
		}
		next()
	}

	private func stream_fadevol(_ args: [Argument]) {
		let streamId = args[0].getValueOrVarValue(vars: vars)
		let duration = args[1].getValueOrVarValue(vars: vars)
		let startVolume = args[2].getValueOrVarValueFloat(vars: vars)
		let endVolume = args[3].getValueOrVarValueFloat(vars: vars)
		if let stream = streams[streamId] {
			DispatchQueue.main.async {
				stream.fadeVolume(
					from: startVolume,
					to: endVolume,
					duration: TimeInterval(max(0, duration)) / 1000
				)
			}
		}
		next()
	}

	private func stream_getpos(_ args: [Argument]) {
		let streamId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		DispatchQueue.main.async {
			let position = self.streams[streamId]?.positionMilliseconds ?? 0
			self.queue.async {
				self.vars[varId] = Float(position)
				self.next()
			}
		}
	}

	private func stream_pause(_ args: [Argument]) {
		let streamId = args[0].getValueOrVarValue(vars: vars)
		if let stream = streams[streamId] {
			DispatchQueue.main.async {
				stream.pause()
			}
		}
		next()
	}

	private func stream_play(_ args: [Argument]) {
		let streamId = args[0].getValueOrVarValue(vars: vars)
		if let stream = streams[streamId] {
			DispatchQueue.main.async {
				stream.play()
			}
		}
		next()
	}

	private func stream_setloop(_ args: [Argument]) {
		let streamId = args[0].getValueOrVarValue(vars: vars)
		let loops = args[1].getValueOrVarValue(vars: vars) != 0
		if let stream = streams[streamId] {
			DispatchQueue.main.async {
				stream.setLoop(loops)
			}
		}
		next()
	}

	private func stream_stop(_ args: [Argument]) {
		let streamId = args[0].getValueOrVarValue(vars: vars)
		if let stream = streams[streamId] {
			DispatchQueue.main.async {
				stream.stop()
			}
		}
		next()
	}

	private func subtitle_add(_ args: [Argument]) {
		let txtId = args[0].getValueOrVarValue(vars: vars)
		let text = TextDb.get(txtId) ?? "\(txtId)"
		scene.game.showSubtitleText(text)
		next()
	}

	private func wait(_ args: [Argument]) {
		let delay = args[0].getValueOrVarValue(vars: vars)
		if beginCommandBlockAsyncOperation() {
			queue.asyncAfter(deadline: .now() + .milliseconds(delay), execute: finishCommandBlockAsyncOperation)
			next()
		} else {
			queue.asyncAfter(deadline: .now() + .milliseconds(delay), execute: next)
		}
	}

	private func zatmyse(_ args: [Argument]) {
		let isVisible = args[0].getValueOrVarValue(vars: vars) == 1
		let isImmediate = args.count > 1 && args[1].getValueOrVarValue(vars: vars) == 1
		scene.game.setScriptBlackoutVisible(isVisible, immediate: isImmediate)
		next()
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

	private func weaponOwnerNode(forScriptId id: Int) -> SCNNode? {
		guard let actor = node(forScriptId: id) else { return nil }
		if isPlayerActor(id), let playerNode = scene.playerNode {
			return playerNode
		}
		return actor
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

	private func canAddWeapon(weaponId: Int) -> Bool {
		return Weapon.hasDefinition(for: weaponId)
	}

	private func refreshPlayerWeaponHudIfNeeded(for actor: SCNNode) {
		guard let playerNode = scene.playerNode,
			  actor === playerNode || actor.name == playerNode.name else { return }
		scene.game.refreshPlayerStatusHud()
	}

	private func playerOwnerMatches(carId: Int) -> Bool {
		if let carNode = node(forScriptId: carId) {
			return scene.game.playerOwnerMatches(carNode: carNode)
		}
		return scene.game.mode == .car && scene.game.vehicle != nil
	}

	private func isPlayerActor(_ actorId: Int) -> Bool {
		guard let actor = node(forScriptId: actorId),
			  let playerNode = scene.playerNode else { return false }
		return actor === playerNode || actor.name == playerNode.name || actor.name?.lowercased() == "tommyhat"
	}

	private func musicStreamURL(named name: String) -> URL? {
		let normalizedName = name
			.replacingOccurrences(of: "\\", with: "/")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let soundsPrefix = "sounds/"
		let soundRelativeName: String
		if normalizedName.lowercased().hasPrefix(soundsPrefix) {
			soundRelativeName = String(normalizedName.dropFirst(soundsPrefix.count))
		} else if normalizedName.contains("/") {
			soundRelativeName = normalizedName
		} else {
			soundRelativeName = "music/" + normalizedName
		}
		return mafiaResourceURL(directory: "sounds", name: soundRelativeName)
	}

	private func humanEnergy(for node: SCNNode) -> Float {
		guard let humanNode = humanNode(for: node) else { return 0 }
		return humanNode.humanEnergy ?? 100
	}

	private func humanNode(for node: SCNNode) -> SCNNode? {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.humanEnergy != nil || candidate.type.hasDefaultHumanEnergy {
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

final class ScriptMusicStream {

	private enum PlaybackState {
		case stopped
		case playing
		case paused
	}

	private let engine = AVAudioEngine()
	private let playerNode = AVAudioPlayerNode()
	private let buffer: AVAudioPCMBuffer
	private var playbackState: PlaybackState = .stopped
	private var startsAt: TimeInterval?
	private var accumulatedPosition: TimeInterval = 0
	private var loops = false
	private var volume: Float = 1
	private var fadeWorkItem: DispatchWorkItem?
	private var playbackGeneration = 0
	private var isGamePaused = false
	private var wasPlayingBeforeGamePause = false

	private var duration: TimeInterval {
		return TimeInterval(buffer.frameLength) / buffer.format.sampleRate
	}

	init?(url: URL) {
		guard let buffer = ScriptMusicStream.makeBuffer(url: url) else { return nil }
		self.buffer = buffer

		engine.attach(playerNode)
		engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
		playerNode.volume = volume
		do {
			try engine.start()
		} catch {
			return nil
		}
	}

	var positionMilliseconds: Int {
		let position = currentPosition()
		return Int((position * 1000).rounded())
	}

	func play() {
		runOnMain {
			switch self.playbackState {
			case .playing:
				return

			case .paused:
				self.startsAt = Date.timeIntervalSinceReferenceDate
				self.playerNode.play()
				self.playbackState = .playing

			case .stopped:
				self.accumulatedPosition = 0
				self.startsAt = Date.timeIntervalSinceReferenceDate
				self.playbackState = .playing
				self.scheduleBuffer()
				self.playerNode.play()
			}
		}
	}

	func pause() {
		runOnMain {
			guard self.playbackState == .playing else { return }
			self.pausePlayback()
		}
	}

	func stop() {
		runOnMain {
			self.stopPlaying(resetPosition: true)
		}
	}

	func destroy() {
		stop()
		runOnMain {
			self.engine.stop()
		}
	}

	func setLoop(_ loops: Bool) {
		runOnMain {
			guard self.loops != loops else { return }
			self.loops = loops
			guard self.playbackState == .playing else { return }
			self.accumulatedPosition = 0
			self.startsAt = Date.timeIntervalSinceReferenceDate
			self.scheduleBuffer()
			self.playerNode.play()
		}
	}

	func setGamePaused(_ paused: Bool) {
		runOnMain {
			if paused {
				guard !self.isGamePaused else { return }
				self.isGamePaused = true
				self.wasPlayingBeforeGamePause = self.playbackState == .playing
				if self.wasPlayingBeforeGamePause {
					self.pausePlayback()
				}
			} else {
				guard self.isGamePaused else { return }
				self.isGamePaused = false
				guard self.wasPlayingBeforeGamePause else { return }
				self.wasPlayingBeforeGamePause = false
				guard self.playbackState == .paused else { return }
				self.startsAt = Date.timeIntervalSinceReferenceDate
				self.playerNode.play()
				self.playbackState = .playing
			}
		}
	}

	func fadeVolume(from startVolume: Float, to endVolume: Float, duration: TimeInterval) {
		runOnMain {
			self.fadeWorkItem?.cancel()
			self.setVolume(startVolume)
			guard duration > 0 else {
				self.setVolume(endVolume)
				return
			}
			self.scheduleFadeStep(startVolume: startVolume, endVolume: endVolume, duration: duration, startTime: Date.timeIntervalSinceReferenceDate)
		}
	}

	private func scheduleBuffer() {
		playbackGeneration += 1
		let generation = playbackGeneration
		playerNode.stop()
		let options: AVAudioPlayerNodeBufferOptions = loops ? [.loops] : []
		playerNode.scheduleBuffer(buffer, at: nil, options: options) { [weak self] in
			DispatchQueue.main.async {
				guard let self = self,
					  self.playbackGeneration == generation,
					  !self.loops else { return }
				self.stopPlaying(resetPosition: true)
			}
		}
	}

	private func stopPlaying(resetPosition: Bool) {
		fadeWorkItem?.cancel()
		fadeWorkItem = nil
		wasPlayingBeforeGamePause = false
		if resetPosition {
			accumulatedPosition = 0
		}
		startsAt = nil
		playbackState = .stopped
		playbackGeneration += 1
		playerNode.stop()
	}

	private func pausePlayback() {
		accumulatedPosition = currentPosition()
		startsAt = nil
		playerNode.pause()
		playbackState = .paused
	}

	private func currentPosition() -> TimeInterval {
		let position: TimeInterval
		if playbackState == .playing, let startsAt = startsAt {
			position = accumulatedPosition + Date.timeIntervalSinceReferenceDate - startsAt
		} else {
			position = accumulatedPosition
		}

		if loops, duration > 0 {
			return position.truncatingRemainder(dividingBy: duration)
		}
		return max(0, min(position, duration))
	}

	private func setVolume(_ volume: Float) {
		let clampedVolume = min(1, max(0, volume))
		self.volume = clampedVolume
		playerNode.volume = clampedVolume
	}

	private func scheduleFadeStep(startVolume: Float, endVolume: Float, duration: TimeInterval, startTime: TimeInterval) {
		let workItem = DispatchWorkItem { [weak self] in
			guard let self = self else { return }
			let elapsed = Date.timeIntervalSinceReferenceDate - startTime
			let progress = min(1, max(0, Float(elapsed / duration)))
			self.setVolume(startVolume + (endVolume - startVolume) * progress)
			guard progress < 1 else {
				self.fadeWorkItem = nil
				return
			}
			self.scheduleFadeStep(startVolume: startVolume, endVolume: endVolume, duration: duration, startTime: startTime)
		}
		fadeWorkItem = workItem
		DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(16), execute: workItem)
	}

	private func runOnMain(_ block: @escaping () -> Void) {
		if Thread.isMainThread {
			block()
		} else {
			DispatchQueue.main.async(execute: block)
		}
	}

	private static func makeBuffer(url: URL) -> AVAudioPCMBuffer? {
		if url.pathExtension.lowercased() == "ogg" {
			return makeOggBuffer(url: url)
		}
		return makeNativeBuffer(url: url)
	}

	private static func makeNativeBuffer(url: URL) -> AVAudioPCMBuffer? {
		guard let file = try? AVAudioFile(forReading: url),
			  file.length <= AVAudioFramePosition(UInt32.max),
			  let buffer = AVAudioPCMBuffer(
				pcmFormat: file.processingFormat,
				frameCapacity: AVAudioFrameCount(file.length)
			  ) else {
			return nil
		}
		do {
			try file.read(into: buffer)
			return buffer
		} catch {
			return nil
		}
	}

	private static func makeOggBuffer(url: URL) -> AVAudioPCMBuffer? {
		var decoded = OggVorbisDecodedAudio(channels: 0, sampleRate: 0, frameCount: 0, samples: nil)
		guard OggVorbisDecodeFile(url.path, &decoded) else { return nil }
		defer {
			OggVorbisFreeDecodedAudio(&decoded)
		}

		guard decoded.channels > 0,
			  decoded.sampleRate > 0,
			  decoded.frameCount > 0,
			  let samples = decoded.samples,
			  let format = AVAudioFormat(
				commonFormat: .pcmFormatFloat32,
				sampleRate: Double(decoded.sampleRate),
				channels: AVAudioChannelCount(decoded.channels),
				interleaved: false
			  ),
			  let buffer = AVAudioPCMBuffer(
				pcmFormat: format,
				frameCapacity: AVAudioFrameCount(decoded.frameCount)
			  ),
			  let channelData = buffer.floatChannelData else {
			return nil
		}

		buffer.frameLength = AVAudioFrameCount(decoded.frameCount)
		let channelCount = Int(decoded.channels)
		let frameCount = Int(decoded.frameCount)
		for frameIndex in 0..<frameCount {
			for channelIndex in 0..<channelCount {
				channelData[channelIndex][frameIndex] = samples[frameIndex * channelCount + channelIndex]
			}
		}
		return buffer
	}

}
