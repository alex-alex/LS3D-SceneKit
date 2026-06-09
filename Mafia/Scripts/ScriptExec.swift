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

private func makeScriptNullActorNode() -> SCNNode {
	let node = SCNNode()
	node.name = "NULL"
	return node
}

private extension Argument {
	var isNullLabel: Bool {
		if case .label(let value) = self {
			return value.lowercased() == "null"
		}
		return false
	}
}

extension Script {

	private static let loopYieldInterval: DispatchTimeInterval = .milliseconds(16)
	private static let npcVehiclePassengerAnimationKey = "__npc_vehicle_passenger__"

	func performCommand(command: ScriptCommand) {
		switch command.name {
//		"{"
//		"}"
		case .actSetstate:				act_setstate(command.args)
		case .actorDelete:				actor_delete(command.args)
		case .actorSetpos:				actor_setplacement(command.args)
		case .actorSetplacement:		actor_setplacement(command.args)
		case .cameraGetfov:				camera_getfov(command.args)
		case .cameraSetfov:				camera_setfov(command.args)
		case .cameraSetrange:			camera_setrange(command.args)
		case .carBreakmotor:			car_breakmotor(command.args)
		case .carEnableus:				car_enableus(command.args)
		case .carForcestop:				car_forcestop(command.args)
		case .carGetactlevel:			car_getactlevel(command.args)
		case .carGetseatcount:			car_getseatcount(command.args)
		case .carGetspeed:				car_getspeed(command.args)
		case .carInwater:				car_inwater(command.args)
		case .carLock:					car_lock(command.args)
		case .carLockAll:				car_lock_all(command.args)
		case .carMuststeal:				car_muststeal(command.args)
		case .carRepair:				car_repair(command.args)
		case .carSetactlevel:			car_setactlevel(command.args)
		case .carSetspeed:				car_setspeed(command.args)
		case .cleardifferences:			cleardifferences(command.args)
		case .commandblock:				commandblock(command.args)
		case .compareactors:			compareactors(command.args)
		case .compareframes:			compareframes(command.args)
		case .compareownerwith:			compareownerwith(command.args)
		case .compareownerwithex:		compareownerwithex(command.args)
		case .consoleAddtext:			console_addtext(command.args)
		case .createPhysicalobject:		noop()
		case .createweaponfromframe:		createweaponfromframe(command.args)
		case .ctrlRead:					ctrl_read(command.args)
		case .detectorInrange:			detector_inrange(command.args)
		case .detectorIssignal:			detector_issignal(command.args)
		case .detectorSetsignal:			detector_setsignal(command.args)
		case .detectorWaitforuse:		detector_waitforuse(command.args)
		case .dimAct:					dim_act(command.args)
		case .dimFlt:					dim_flt(command.args)
		case .dimFrm:					dim_frm(command.args)
		case .destroyPhysicalobject:		destroy_physicalobject(command.args)
		case .disablecolls:				disablecolls(command.args)
		case .doorEnableus:				door_enableus(command.args)
		case .doorGetstate:				door_getstate(command.args)
		case .doorLock:					door_lock(command.args)
		case .doorOpen:					door_open(command.args)
		case .end:						end(command.args)
		case .endBang:					end(command.args)
		case .endofmission:				endofmission(command.args)
		case .enemyPlayanim:			enemy_playanim(command.args)
		case .enemyTalk:				enemy_talk(command.args)
		case .enemyWait:				enemy_wait(command.args)
		case .event:					event(command.args)
		case .eventUseCb:				noop()
		case .findactor:				findactor(command.args)
		case .findframe:				findframe(command.args)
		case .getactivecamera:			getactivecamera(command.args)
		case .getactiveplayer:			getactiveplayer(command.args)
		case .getactorframe:			getactorframe(command.args)
		case .frmGetpos:				frm_getpos(command.args)
		case .frmGetnumchildren:		frm_getnumchildren(command.args)
		case .frmGetparent:				frm_getparent(command.args)
		case .frmGetscale:				frm_getscale(command.args)
		case .frmGetworldpos:			frm_getworldpos(command.args)
		case .frmGetworldscale:			frm_getworldscale(command.args)
		case .frmIson:					frm_ison(command.args)
		case .frmSetpos:				frm_setpos(command.args)
		case .frmSeton:					frm_seton(command.args)
		case .frmSetscale:				frm_setscale(command.args)
		case .garageEnablesteal:		garage_enablesteal(command.args)
		case .getactorsdist:			getactorsdist(command.args)
		case .getenemyaistate:			getenemyaistate(command.args)
		case .getframefromactor:		getframefromactor(command.args)
		case .getgametime:				getgametime(command.args)
		case .getPmCrashtime:			get_pm_crashtime(command.args)
		case .getPmFiretime:			get_pm_firetime(command.args)
		case .getPmHumanstate:			get_pm_humanstate(command.args)
		case .getPmState:				get_pm_state(command.args)
		case .getRemoteActor:			get_remote_actor(command.args)
		case .getRemoteFloat:			get_remote_float(command.args)
		case .getRemoteFrame:			get_remote_frame(command.args)
		case .getticktime:				getticktime(command.args)
		case .goto:						goto(command.args)
		case .humanActivateweapon:		human_activateweapon(command.args)
		case .humanAddweapon:			human_addweapon(command.args)
		case .humanAnyweaponinhand:		human_anyweaponinhand(command.args)
		case .humanAnyweaponininventory:	human_anyweaponininventory(command.args)
		case .humanCanaddweapon:		human_canaddweapon(command.args)
		case .humanCandie:				human_candie(command.args)
		case .humanDeath:				human_death(command.args)
		case .humanDelweapon:			human_delweapon(command.args)
		case .humanForceSettocar:		human_force_settocar(command.args)
		case .humanGetactanimid:		human_getactanimid(command.args)
		case .humanGetiteminrhand:		human_getiteminrhand(command.args)
		case .humanGetowner:			human_getowner(command.args)
		case .humanGetproperty:			human_getproperty(command.args)
		case .humanHolster:				human_holster(command.args)
		case .humanIsweapon:			human_isweapon(command.args)
		case .humanSetproperty:			human_setproperty(command.args)
		case .humanTalk:				human_talk(command.args)
		case .`if`:						`if`(command.args)
		case .iffltinrange:				iffltinrange(command.args)
		case .ifplayerstealcar:			ifplayerstealcar(command.args)
		case .introSubtitleAdd:			subtitle_add(command.args)
		case .inventoryClear:			inventory_clear(command.args)
		case .iscarusable:				iscarusable(command.args)
		case .label:					noop()
		case .`let`:					`let`(command.args)
		case .loaddifferences:			loaddifferences(command.args)
		case .mathAbs:					math_abs(command.args)
		case .mathCos:					math_cos(command.args)
		case .mathSin:					math_sin(command.args)
		case .missionObjectives:		mission_objectives(command.args)
		case .missionObjectivesclear:	mission_objectivesclear(command.args)
		case .missionObjectivesremove:	mission_objectivesremove(command.args)
		case .modelCreate:				model_create(command.args)
		case .modelDestroy:				model_destroy(command.args)
		case .modelPlayanim:			model_playanim(command.args)
		case .modelStopanim:			model_stopanim(command.args)
		case .personPlayanim:			person_playanim(command.args)
		case .personStopanim:			person_stopanim(command.args)
		case .playerLockcontrols:		player_lockcontrols(command.args)
		case .playsound:				playsound(command.args)
		case .playsoundstop:			playsoundstop(command.args)
		case .pmShowsymbol:				pm_showsymbol(command.args)
		case .recload:					recload(command.args, full: false)
		case .recloadfull:				recload(command.args, full: true)
		case .recwaitforend:			recwaitforend(command.args)
		case .recunload:				recunload(command.args)
		case .`return`:					`return`(command.args)
		case .returnBang:				`return`(command.args)
		case .rnd:						rnd(command.args)
		case .setcompass:				setcompass(command.args)
		case .setevent:					setevent(command.args)
		case .setnullactor:				setnullactor(command.args)
		case .setnullframe:				setnullframe(command.args)
		case .setplayerfireevent:		setplayerfireevent(command.args)
		case .setplayerhornevent:		setplayerhornevent(command.args)
		case .settimeoutevent:			settimeoutevent(command.args)
		case .getfilmmusic:				getfilmmusic(command.args)
		case .soundGetvolume:			sound_getvolume(command.args)
		case .soundSetvolume:			sound_setvolume(command.args)
		case .soundfade:				soundfade(command.args)
		case .setfilmmusic:				setfilmmusic(command.args)
		case .streamCreate:				stream_create(command.args)
		case .streamDestroy:			stream_destroy(command.args)
		case .streamFadevol:			stream_fadevol(command.args)
		case .streamGetpos:				stream_getpos(command.args)
		case .streamPause:				stream_pause(command.args)
		case .streamPlay:				stream_play(command.args)
		case .streamSetpos:				stream_setpos(command.args)
		case .streamSetloop:			stream_setloop(command.args)
		case .streamStop:				stream_stop(command.args)
		case .subtitleAdd:				subtitle_add(command.args)
		case .timerGetinterval:			timer_getinterval(command.args)
		case .timerSetinterval:			timer_setinterval(command.args)
		case .timeroff:					timeroff(command.args)
		case .timeron:					timeron(command.args)
		case .vectAddVect:				vect_add_vect(command.args)
		case .vectCopy:					vect_copy(command.args)
		case .vectInverse:				vect_inverse(command.args)
		case .vectMagnitude:			vect_magnitude(command.args)
		case .vectMulScl:				vect_mul_scl(command.args)
		case .vectMulVect:				vect_mul_vect(command.args)
		case .vectSet:					vect_set(command.args)
		case .vectSubVect:				vect_sub_vect(command.args)
		case .versionIsEditor:			version_is_editor(command.args)
		case .versionIsGermany:			version_is_germany(command.args)
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
			guard self.canRunForActorState() else {
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
			queue.asyncAfter(deadline: .now() + Self.loopYieldInterval) { [weak self] in
				self?.next()
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
			if let actorState = ActorState(rawValue: state) {
				if actorId == -1 {
					markSelfActorStateApplied()
				}
				target.actorState = actorState
				script(forActorId: actorId)?.setActorState(actorState)
			}
		}
		next()
	}

	private func actor_delete(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		actors[actorId]?.removeFromParentNode()
		actors[actorId] = nil
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

	private func camera_getfov(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		DispatchQueue.main.async {
			let fieldOfView = self.scene.game.cameraNode.camera?.fieldOfView ?? 0
			self.queue.async {
				self.vars[varId] = Float(fieldOfView)
				self.next()
			}
		}
	}

	private func camera_setfov(_ args: [Argument]) {
		let fieldOfView = args[0].getValueOrVarValueFloat(vars: vars)
		DispatchQueue.main.async {
			self.scene.game.cameraNode.camera?.fieldOfView = CGFloat(fieldOfView)
		}
		next()
	}

	private func camera_setrange(_ args: [Argument]) {
		let near = args[0].getValueOrVarValueFloat(vars: vars)
		let far = args[1].getValueOrVarValueFloat(vars: vars)
		DispatchQueue.main.async {
			self.scene.game.cameraNode.camera?.zNear = Double(near)
			self.scene.game.cameraNode.camera?.zFar = Double(far)
		}
		next()
	}

	private func car_enableus(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let enabled = args[1].getValueOrVarValue(vars: vars) != 0
		node(forScriptId: carId)?.actionsEnabled = enabled
		next()
	}

	private func car_breakmotor(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let isBroken = args[1].getValueOrVarValue(vars: vars) != 0
		setCarUsable(carId: carId, isUsable: !isBroken)
		if isBroken {
			stopCarPhysics(carId: carId, brakeCurrentVehicle: true)
		}
		next()
	}

	private func car_forcestop(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		stopCarPhysics(carId: carId, brakeCurrentVehicle: true)
		next()
	}

	private func car_getactlevel(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = carActLevels[carId] ?? 1
		next()
	}

	private func car_getseatcount(_ args: [Argument]) {
		let _ = args[0].getValueOrVarValue(vars: vars) // carId
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = 4
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

	private func car_inwater(_ args: [Argument]) {
		let _ = args[0].getValueOrVarValue(vars: vars) // carId
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = 0
		next()
	}

	private func car_lock(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let locked = args[1].getValueOrVarValue(vars: vars) != 0
		if locked {
			stopCarPhysics(carId: carId, brakeCurrentVehicle: true)
		}
		next()
	}

	private func car_lock_all(_ args: [Argument]) {
		car_lock(args)
	}

	private func car_muststeal(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let enabled = args.count < 2 || args[1].getValueOrVarValue(vars: vars) != 0
		scene.game.setVehicleStealEnabled(carId: carId, node: node(forScriptId: carId), enabled: enabled)
		next()
	}

	private func car_repair(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		setCarUsable(carId: carId, isUsable: true)
		if playerOwnerMatches(carId: carId) {
			scene.game.vehicle?.node.physicsBody?.velocity = SCNVector3Zero
			scene.game.vehicle?.node.physicsBody?.angularVelocity = SCNVector4Zero
		}
		next()
	}

	private func car_setactlevel(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let level = args[1].getValueOrVarValueFloat(vars: vars)
		carActLevels[carId] = level
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
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let label1 = args[2].getString()
		let label2 = args[3].getString()
		let humanMatches: Bool
		let playerMatches: Bool
		if args[1].isNullLabel {
			humanMatches = node(forScriptId: actorId) != nil && ownerNode(forActorId: actorId) == nil
			playerMatches = isPlayerActor(actorId) && (scene.game.mode != .car || scene.game.vehicle == nil)
		} else {
			let carId = args[1].getValueOrVarValue(vars: vars)
			humanMatches = humanOwnerMatches(actorId: actorId, carId: carId)
			playerMatches = isPlayerActor(actorId) && playerOwnerMatches(carId: carId)
		}
		if humanMatches || playerMatches {
			goto(label: label1)
		} else {
			goto(label: label2)
		}
	}

	private func compareactors(_ args: [Argument]) {
		let actor1Id = args[0].getValueOrVarValue(vars: vars)
		let actor2Id = args[1].getValueOrVarValue(vars: vars)
		let varId = args[2].getValueOrVarValue(vars: vars)
		if let actor1 = node(forScriptId: actor1Id),
		   let actor2 = node(forScriptId: actor2Id),
		   actor1 === actor2 {
			vars[varId] = 1
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func compareframes(_ args: [Argument]) {
		let frame1Id = args[0].getValueOrVarValue(vars: vars)
		let frame2Id = args[1].getValueOrVarValue(vars: vars)
		let varId = args[2].getValueOrVarValue(vars: vars)
		if let frame1 = frames[frame1Id],
		   let frame2 = frames[frame2Id],
		   frame1 === frame2 {
			vars[varId] = 1
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func compareownerwith(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let label1 = args[1].getString()
		let label2 = args[2].getString()
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
		let distance = args[1].getValueOrVarValueFloat(vars: vars)
		if let playerPosition = scene.game.playerReferencePosition() {
			vars[varId] = (node.squaredDistance(to: playerPosition) <= distance * distance) ? 1 : 0
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

	private func dim_act(_ args: [Argument]) {
		let count = max(0, args[0].getValueOrVarValue(vars: vars))
		actors.reserveCapacity(count)
		next()
	}

	private func dim_flt(_ args: [Argument]) {
		let count = max(0, args[0].getValueOrVarValue(vars: vars))
		vars.reserveCapacity(count)
		for varId in 0..<count where vars[varId] == nil {
			vars[varId] = 0
		}
		next()
	}

	private func dim_frm(_ args: [Argument]) {
		let count = max(0, args[0].getValueOrVarValue(vars: vars))
		frames.reserveCapacity(count)
		next()
	}

	private func destroy_physicalobject(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		frames[frameId]?.physicsBody = nil
		next()
	}

	private func disablecolls(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		frames[frameId]?.physicsBody = nil
		next()
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

	private func door_getstate(_ args: [Argument]) {
		let targetId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		guard let door = node(forScriptId: targetId)?.doorData else {
			vars[varId] = 0
			next()
			return
		}
		vars[varId] = door.isOpen ? 0 : 1
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
		let reasonTextId = args.count > 1 ? args[1].getValueOrVarValue(vars: vars) : nil
		let text = reasonTextId.flatMap { TextDb.get($0) }
		let reasonDescription = text ?? "<none>"
		let reasonIdDescription = reasonTextId.map(String.init) ?? "<none>"
		print("== Script endofmission: node=\(node.name ?? "unnamed"), returnsToMainMenu=\(returnsToMainMenu), reasonTextId=\(reasonIdDescription), reason=\"\(reasonDescription)\"")
		print("== Script endofmission previous commands: \(recentCommandHistoryDescription(excludingCurrent: true, limit: 12))")
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

	private func enemy_talk(_ args: [Argument]) {
		let actorId: Int
		let soundIdArgument: Argument
		switch args.count {
		case 1:
			actorId = -1
			soundIdArgument = args[0]
		default:
			actorId = args[0].getValueOrVarValue(vars: vars)
			soundIdArgument = args[1]
		}

		let soundId = soundIdArgument.scriptTalkSoundId(vars: vars)
		guard let url = mafiaResourceURL(directory: "sounds", name: "\(soundId).wav"),
			  let source = SCNAudioSource(url: url) else {
			pendingEnemyTalk = nil
			next()
			return
		}

		source.isPositional = true
		source.load()

		let talkOperation = beginPendingEnemyTalk()
		DispatchQueue.main.async {
			let actor = self.node(forScriptId: actorId) ?? self.node
			try? playFaceAnimation(soundName: soundId, in: actor)
			self.scene.playAudio(source, url: url, on: actor) {
				self.completePendingEnemyTalk(talkOperation)
			}
		}
		next()
	}

	private func enemy_wait(_ args: [Argument]) {
		guard let talkOperation = pendingEnemyTalk,
			  !talkOperation.isComplete else {
			next()
			return
		}

		if beginCommandBlockAsyncOperation() {
			talkOperation.waiters.append(finishCommandBlockAsyncOperation)
			next()
		} else {
			talkOperation.waiters.append(next)
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
				if name.lowercased() == "null" {
					actors[actorId] = makeScriptNullActorNode()
				} else if let node = findNode(named: name) {
				actors[actorId] = node
			}
			if name.lowercased() == "tommy" {
				let actor = actors[actorId]
				let player = scene.playerNode
				let actorEnergy = actor?.humanEnergy.map { "\($0)" } ?? "<nil>"
				let playerEnergy = player?.humanEnergy.map { "\($0)" } ?? "<nil>"
				print("== Script findactor Tommy: script=\(self.name), actorId=\(actorId), found=\(actor?.name ?? "<nil>"), isPlayer=\(actor === player), actorEnergy=\(actorEnergy), player=\(player?.name ?? "<nil>"), playerEnergy=\(playerEnergy), playerHealth=\(scene.game.playerHealth)")
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

	private func getactivecamera(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let cameraFrame = SCNNode()
		cameraFrame.name = "__active_camera_\(frameId)"
		cameraFrame.transform = scene.rootNode.convertTransform(scene.game.cameraNode.presentation.worldTransform, from: nil)
		scene.rootNode.addChildNode(cameraFrame)
		frames[frameId] = cameraFrame
		next()
	}

	private func getactiveplayer(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		if let playerNode = scene.playerNode {
			actors[actorId] = playerNode
		}
		next()
	}

	private func getactorframe(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let frameId = args[1].getValueOrVarValue(vars: vars)
		if let actor = node(forScriptId: actorId) {
			frames[frameId] = actor
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

	private func frm_getpos(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let frame = frames[frameId] {
			setVectorVariables(startingAt: varId, vector: frame.position)
		} else {
			setVectorVariables(startingAt: varId, vector: SCNVector3Zero)
		}
		next()
	}

	private func frm_getnumchildren(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = Float(frames[frameId]?.childNodes.count ?? 0)
		next()
	}

	private func frm_getparent(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		guard let parent = frames[frameId]?.parent else {
			vars[varId] = -1
			next()
			return
		}
		if let registeredParent = frames.first(where: { $0.value === parent }) {
			vars[varId] = Float(registeredParent.key)
		} else {
			vars[varId] = -1
		}
		next()
	}

	private func frm_getscale(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let frame = frames[frameId] {
			setVectorVariables(startingAt: varId, vector: frame.scale)
		} else {
			setVectorVariables(startingAt: varId, vector: SCNVector3Zero)
		}
		next()
	}

	private func frm_getworldpos(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let frame = frames[frameId] {
			setVectorVariables(startingAt: varId, vector: frame.presentation.worldPosition)
		} else {
			setVectorVariables(startingAt: varId, vector: SCNVector3Zero)
		}
		next()
	}

	private func frm_getworldscale(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let frame = frames[frameId] {
			setVectorVariables(startingAt: varId, vector: worldScale(of: frame.presentation.worldTransform))
		} else {
			setVectorVariables(startingAt: varId, vector: SCNVector3Zero)
		}
		next()
	}

	private func frm_ison(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let frame = frames[frameId] {
			vars[varId] = frame.isHidden ? 0 : 1
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func frm_setpos(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		frames[frameId]?.position = vectorVariable(startingAt: varId)
		next()
	}

	private func frm_setscale(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		frames[frameId]?.scale = vectorVariable(startingAt: varId)
		next()
	}

	private func getactorsdist(_ args: [Argument]) {
		let actor1Id = args[0].getValueOrVarValue(vars: vars)
		let actor2Id = args[1].getValueOrVarValue(vars: vars)
		let varId = args[2].getValueOrVarValue(vars: vars)
		guard let actor1 = actors[actor1Id],
			  let actor2 = actors[actor2Id] else {
			vars[varId] = 0
			print("== Script getactorsdist: script=\(name), actor1Id=\(actor1Id), actor2Id=\(actor2Id), varId=\(varId), missing actor, value=0")
			next()
			return
		}
		let node1 = liveDistanceNode(for: actor1)
		let node2 = liveDistanceNode(for: actor2)
		let distance = node1.distance(to: node2)
		vars[varId] = distance
		print(
			"== Script getactorsdist: script=\(name), " +
			"actor1=\(actor1Id):\(actor1.name ?? "<unnamed>")->\(node1.name ?? "<unnamed>"), " +
			"actor2=\(actor2Id):\(actor2.name ?? "<unnamed>")->\(node2.name ?? "<unnamed>"), " +
			"varId=\(varId), value=\(String(format: "%.2f", distance))"
		)
		next()
	}

	private func getenemyaistate(_ args: [Argument]) {
		let _ = args[0].getValueOrVarValue(vars: vars) // actorId
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = 0
		next()
	}

	private func getframefromactor(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let actorId = args[1].getValueOrVarValue(vars: vars)
		if let actor = node(forScriptId: actorId) {
			frames[frameId] = actor
		}
		next()
	}

	private func getgametime(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let elapsed = Date.timeIntervalSinceReferenceDate - scene.game.scriptStartTime
		vars[varId] = Float(elapsed * 1000)
		next()
	}

	private func get_pm_crashtime(_ args: [Argument]) {
		get_pm_elapsed_time(args, commandName: "get_pm_crashtime")
	}

	private func get_pm_firetime(_ args: [Argument]) {
		get_pm_elapsed_time(args, commandName: "get_pm_firetime")
	}

	private func get_pm_elapsed_time(_ args: [Argument], commandName: String) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = 0
		next()
	}

	private func get_pm_humanstate(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		vars[varId] = 0
		next()
	}

	private func get_pm_state(_ args: [Argument]) {
		let _ = args[0].getValueOrVarValue(vars: vars) // actorId
		let varId = args[1].getValueOrVarValue(vars: vars)
		let _ = args[2].getValueOrVarValue(vars: vars) // offenseType
		vars[varId] = 0
		next()
	}

	private func get_remote_actor(_ args: [Argument]) {
		let localActorId = args[0].getValueOrVarValue(vars: vars)
		let remoteActorId = args[1].getValueOrVarValue(vars: vars)
		let remoteSourceActorId = args[2].getValueOrVarValue(vars: vars)
		guard let remoteScript = script(forActorId: remoteActorId) else {
			actors[localActorId] = nil
			next()
			return
		}
		readRemoteScript(remoteScript) {
			remoteScript.actors[remoteSourceActorId]
		} completion: { actor in
			self.actors[localActorId] = actor
			self.next()
		}
	}

	private func get_remote_float(_ args: [Argument]) {
		let localVarId = args[0].getValueOrVarValue(vars: vars)
		let remoteActorId = args[1].getValueOrVarValue(vars: vars)
		let remoteVarId = args[2].getValueOrVarValue(vars: vars)
		guard let remoteScript = script(forActorId: remoteActorId) else {
			vars[localVarId] = 0
			next()
			return
		}
		readRemoteScript(remoteScript) {
			remoteScript.vars[remoteVarId] ?? 0
		} completion: { value in
			self.vars[localVarId] = value
			self.next()
		}
	}

	private func get_remote_frame(_ args: [Argument]) {
		let localFrameId = args[0].getValueOrVarValue(vars: vars)
		let remoteActorId = args[1].getValueOrVarValue(vars: vars)
		let remoteFrameId = args[2].getValueOrVarValue(vars: vars)
		guard let remoteScript = script(forActorId: remoteActorId) else {
			frames[localFrameId] = nil
			next()
			return
		}
		readRemoteScript(remoteScript) {
			remoteScript.frames[remoteFrameId]
		} completion: { frame in
			self.frames[localFrameId] = frame
			self.next()
		}
	}

	private func getticktime(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let now = Date.timeIntervalSinceReferenceDate
		vars[varId] = Float((now - lastTickTime) * 1000)
		lastTickTime = now
		next()
	}

	private func goto(_ args: [Argument]) {
		let label = args[0].getString()
		goto(label: label)
	}

	private func human_activateweapon(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let weaponId = args[1].getValueOrVarValue(vars: vars)
		guard let actor = weaponOwnerNode(forScriptId: actorId) else {
			next()
			return
		}
		var didActivateWeapon = false
		scene.updateWeaponsIfPresent(for: actor) { weapons in
			guard let selectedWeapon = weapons.first(where: { $0.id == weaponId }) else { return }
			for weapon in weapons {
				weapon.position = weapon === selectedWeapon ? .hand : .inventory
			}
			didActivateWeapon = true
		}
		if didActivateWeapon {
			refreshPlayerWeaponHudIfNeeded(for: actor)
		}
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
		scene.appendWeapon(weapon, for: actor)
		refreshPlayerWeaponHudIfNeeded(for: actor)
		next()
	}

	private func human_anyweaponinhand(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let actor = weaponOwnerNode(forScriptId: actorId),
		   scene.weapons(for: actor).contains(where: { $0.position == .hand }) {
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
		   !scene.weapons(for: actor).isEmpty {
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

	private func human_candie(_ args: [Argument]) {
		guard args.count > 1 else {
			next()
			return
		}
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if isPlayerActor(actorId) {
			vars[varId] = scene.game.playerHealth > 0 ? 1 : 0
		} else if let actor = node(forScriptId: actorId) {
			vars[varId] = humanEnergy(for: actor) > 0 ? 1 : 0
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func human_death(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		if isPlayerActor(actorId) {
			scene.game.setPlayerHealth(0)
		} else if let actor = node(forScriptId: actorId) {
			humanNode(for: actor)?.humanEnergy = 0
			actor.actorState = .off
			script(forActorId: actorId)?.setActorState(.off)
		}
		next()
	}

	private func human_delweapon(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let weaponId = args[1].getValueOrVarValue(vars: vars)
		if let actor = weaponOwnerNode(forScriptId: actorId) {
			scene.updateWeaponsIfPresent(for: actor) { weapons in
				weapons.removeAll { $0.id == weaponId }
			}
			refreshPlayerWeaponHudIfNeeded(for: actor)
		}
		next()
	}

	private func human_force_settocar(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let carId = args[1].getValueOrVarValue(vars: vars)
		let seatId = args[2].getValueOrVarValue(vars: vars)
		guard let actor = node(forScriptId: actorId),
			  let car = node(forScriptId: carId) else {
			next()
			return
		}

		if isPlayerActor(actorId) {
			scene.game.preservePlayerPhysicsBodyForVehicleEntry(actor)
		}
		scene.humanVehicleOwners[ObjectIdentifier(actor)] = car
		placeHuman(actor, inCar: car, seatId: seatId)
		if !isPlayerActor(actorId) {
			playNpcVehiclePassengerAnimation(in: actor)
		}

		if isPlayerActor(actorId) {
			DispatchQueue.main.async {
				self.scene.game.enterScriptedVehicle(car)
			}
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

	private func human_getiteminrhand(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let actor = weaponOwnerNode(forScriptId: actorId),
		   let weapon = scene.weapons(for: actor).first(where: { $0.position == .hand }) {
			vars[varId] = Float(weapon.id)
		} else {
			vars[varId] = -1
		}
		next()
	}

	private func human_getowner(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		guard node(forScriptId: actorId) != nil,
			  let owner = ownerNode(forActorId: actorId) else {
			actors[varId] = nil
			frames[varId] = nil
			vars[varId] = -1
			next()
			return
		}
		actors[varId] = owner
		frames[varId] = nil
		vars[varId] = Float(varId)
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
		if let actor = weaponOwnerNode(forScriptId: actorId),
		   scene.weapons(for: actor).contains(where: { $0.id == weaponId }) {
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
		guard args.count == 5 else {
			next()
			return
		}
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
			operation = (>=)
		} else {
			fatalError()
		}

		let value2 = args[2].getValueOrVarValueFloat(vars: vars)

		let label1 = args[3].getString()
		let label2 = args[4].getString()
		let result = operation(value1, value2)

		if result {
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

	private func inventory_clear(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		if let actor = weaponOwnerNode(forScriptId: actorId) {
			scene.setWeapons([], for: actor)
			refreshPlayerWeaponHudIfNeeded(for: actor)
		}
		next()
	}

	private func iscarusable(_ args: [Argument]) {
		let carId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		guard carId >= 0 else {
			vars[varId] = 0
			next()
			return
		}
		if let car = node(forScriptId: carId) {
			vars[varId] = isCarUsable(car) ? 1 : 0
		} else {
			vars[varId] = 0
		}
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

	private func math_abs(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		vars[varId] = abs(vars[varId] ?? 0)
		next()
	}

	private func math_cos(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		vars[varId] = cos(vars[varId] ?? 0)
		next()
	}

	private func math_sin(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		vars[varId] = sin(vars[varId] ?? 0)
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

	private func mission_objectivesremove(_ args: [Argument]) {
		let txtId = args[0].getValueOrVarValue(vars: vars)
		scene.objectives.removeAll { $0 == txtId }
		next()
	}

	private func model_create(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let modelName = normalizedModelName(args[1].getString())
		do {
			let model = try loadModel(named: modelName)
			model.name = (modelName as NSString).lastPathComponent
			scene.rootNode.addChildNode(model)
			scene.registerNodeTree(model)
			actors[actorId] = model
		} catch {
			print("Failed to create model '\(modelName)':", error)
		}
		next()
	}

	private func model_destroy(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		actors[actorId]?.removeFromParentNode()
		actors[actorId] = nil
		next()
	}

	private func model_playanim(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let animName = args[1].getString()
		DispatchQueue.main.async {
			if let actor = self.node(forScriptId: actorId) {
				try? playAnimation(named: "anims/"+animName.replacingOccurrences(of: "i3d", with: "5DS"), in: actor)
			}
		}
		next()
	}

	private func model_stopanim(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		if let actor = node(forScriptId: actorId) {
			removeDefaultAnimationActions(in: actor)
		}
		next()
	}

	private func person_playanim(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		guard args.count > 1 else {
			next()
			return
		}
		let animName = args[1].getString()
		DispatchQueue.main.async {
			if let actor = self.node(forScriptId: actorId) {
				try? playAnimation(named: "anims/"+animName.replacingOccurrences(of: "i3d", with: "5DS"), in: actor)
			}
		}
		next()
	}

	private func person_stopanim(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		if let actor = node(forScriptId: actorId) {
			removeDefaultAnimationActions(in: actor)
		}
		next()
	}

	private func player_lockcontrols(_ args: [Argument]) {
		let isLocked = args[0].getValueOrVarValue(vars: vars) != 0
		DispatchQueue.main.async {
			self.scene.game.setPlayerControlsLocked(isLocked)
		}
		next()
	}

	private func playsound(_ args: [Argument]) {
		let soundName = args[0].getString()
		let frameId = args[1].getValueOrVarValue(vars: vars)
		let radius = args[2].getValueOrVarValueFloat(vars: vars)
		let volume = args[3].getValueOrVarValueFloat(vars: vars)
		let playbackVarId = args.count > 4 ? args[4].getValueOrVarValue(vars: vars) : nil

		guard let url = mafiaResourceURL(directory: "sounds", name: soundName),
			  let source = SCNAudioSource(url: url) else {
			if let playbackVarId = playbackVarId {
				vars[playbackVarId] = 0
			}
			next()
			return
		}

		source.volume = volume
		source.isPositional = radius > 0
		source.load()

		let targetNode = frames[frameId] ?? scene.rootNode
		let player = SCNAudioPlayer(source: source)
		let playbackId = nextSoundPlaybackId
		nextSoundPlaybackId += 1
		let playback = ScriptSoundPlayback(node: targetNode, player: player)
		soundPlaybacks[playbackId] = playback
		let scriptQueue = queue
		player.didFinishPlayback = { [weak self, weak playback] in
			guard let playback = playback else { return }
			DispatchQueue.main.async { [weak self] in
				playback.node.removeAudioPlayer(playback.player)
				scriptQueue.async { [weak self] in
					self?.soundPlaybacks[playbackId] = nil
				}
			}
		}
		DispatchQueue.main.async {
			targetNode.addAudioPlayer(player)
		}
		if let playbackVarId = playbackVarId {
			vars[playbackVarId] = Float(playbackId)
		}
		next()
	}

	private func playsoundstop(_ args: [Argument]) {
		let playbackId = args[0].getValueOrVarValue(vars: vars)
		guard let playback = soundPlaybacks.removeValue(forKey: playbackId) else {
			next()
			return
		}
		playback.player.didFinishPlayback = nil
		DispatchQueue.main.async {
			playback.node.removeAudioPlayer(playback.player)
		}
		next()
	}

	private func pm_showsymbol(_ args: [Argument]) {
		let symbolId = args[0].getValueOrVarValue(vars: vars)
		if symbolId != 0 {
			print("pm_showsymbol \(symbolId): police symbol HUD is not implemented")
		}
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
		waitForCutscene(secondsRemaining: duration, lastTick: Date.timeIntervalSinceReferenceDate) { [weak self] in
			guard let self = self else { return }
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

	private func waitForCutscene(
		secondsRemaining: TimeInterval,
		lastTick: TimeInterval,
		completion: @escaping @Sendable () -> Void
	) {
		let interval: TimeInterval = 0.1
		queue.asyncAfter(deadline: .now() + interval) { [weak self] in
			guard let self = self else { return }
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

	private func setnullactor(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		actors[actorId] = nil
		next()
	}

	private func setnullframe(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		frames[frameId] = nil
		next()
	}

	private func setplayerfireevent(_ args: [Argument]) {
		setPlayerEvent(args, keyPath: \.playerFireEvent)
	}

	private func setplayerhornevent(_ args: [Argument]) {
		setPlayerEvent(args, keyPath: \.playerHornEvent)
	}

	private func settimeoutevent(_ args: [Argument]) {
		let actorId = args[0].getValueOrVarValue(vars: vars)
		let eventId = args[1].getString()

		guard actorId != -1, eventId != "-1", let script = script(forActorId: actorId) else {
			timeoutEventBinding = nil
			next()
			return
		}

		timeoutEventBinding = ScriptEventBinding(script: script, eventId: eventId)
		next()
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

	private func sound_getvolume(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let varId = args[1].getValueOrVarValue(vars: vars)
		if let frame = frames[frameId],
		   let sound = scene.sounds[frame] {
			vars[varId] = sound.audioSource.volume
		} else {
			vars[varId] = 0
		}
		next()
	}

	private func sound_setvolume(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let volume = args[1].getValueOrVarValueFloat(vars: vars)
		if let frame = frames[frameId],
		   let sound = scene.sounds[frame] {
			sound.audioSource.volume = volume
		}
		next()
	}

	private func soundfade(_ args: [Argument]) {
		let frameId = args[0].getValueOrVarValue(vars: vars)
		let duration = args[1].getValueOrVarValue(vars: vars)
		let startVolume = args[2].getValueOrVarValueFloat(vars: vars)
		let endVolume = args[3].getValueOrVarValueFloat(vars: vars)
		guard let frame = frames[frameId],
			  let sound = scene.sounds[frame] else {
			next()
			return
		}
		sound.audioSource.volume = startVolume
		fadeSound(sound, from: startVolume, to: endVolume, duration: TimeInterval(max(0, duration)) / 1000)
		next()
	}

	private func stream_create(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let name = args[1].getString()
		guard let url = musicStreamURL(named: name) else {
			print("== Music stream_create failed: missing '\(name)'")
			vars[varId] = 0
			next()
			return
		}
		guard let stream = ScriptMusicStream(url: url) else {
			print("== Music stream_create failed: cannot open '\(url.path)'")
			vars[varId] = 0
			next()
			return
		}

		let streamId = nextStreamId
		nextStreamId += 1
		streams[streamId] = stream
		vars[varId] = Float(streamId)
		print("== Music stream_create: var \(varId) -> stream \(streamId), \(url.lastPathComponent)")
		next()
	}

	private func stream_destroy(_ args: [Argument]) {
		let streamId = musicStreamId(from: args[0])
		if sharedStreamIds.remove(streamId) != nil {
			streams.removeValue(forKey: streamId)
		} else if let stream = streams.removeValue(forKey: streamId) {
			DispatchQueue.main.async {
				stream.destroy()
			}
		}
		next()
	}

	private func stream_fadevol(_ args: [Argument]) {
		let streamId = musicStreamId(from: args[0])
		let duration = args[1].getValueOrVarValue(vars: vars)
		let startVolume = args[2].getValueOrVarValueFloat(vars: vars)
		let endVolume = args[3].getValueOrVarValueFloat(vars: vars)
		if let stream = streams[streamId] {
			print("== Music stream_fadevol: stream \(streamId), \(duration)ms, \(startVolume) -> \(endVolume)")
			DispatchQueue.main.async {
				stream.fadeVolume(
					from: startVolume,
					to: endVolume,
					duration: TimeInterval(max(0, duration)) / 1000
				)
			}
		} else {
			print("== Music stream_fadevol skipped: missing stream \(streamId)")
		}
		next()
	}

	private func stream_getpos(_ args: [Argument]) {
		let streamId = musicStreamId(from: args[0])
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
		let streamId = musicStreamId(from: args[0])
		if let stream = streams[streamId] {
			print("== Music stream_pause: stream \(streamId)")
			DispatchQueue.main.async {
				stream.pause()
			}
		} else {
			print("== Music stream_pause skipped: missing stream \(streamId)")
		}
		next()
	}

	private func stream_play(_ args: [Argument]) {
		let streamId = musicStreamId(from: args[0])
		if let stream = streams[streamId] {
			print("== Music stream_play: stream \(streamId)")
			DispatchQueue.main.async {
				stream.play()
			}
		} else {
			print("== Music stream_play skipped: missing stream \(streamId)")
		}
		next()
	}

	private func stream_setpos(_ args: [Argument]) {
		let streamId = musicStreamId(from: args[0])
		let position = args[1].getValueOrVarValue(vars: vars)
		if let stream = streams[streamId] {
			print("== Music stream_setpos: stream \(streamId), \(position)ms")
			DispatchQueue.main.async {
				stream.setPosition(milliseconds: position)
			}
		} else {
			print("== Music stream_setpos skipped: missing stream \(streamId)")
		}
		next()
	}

	private func getfilmmusic(_ args: [Argument]) {
		let varId = args.first?.getValueOrVarValue(vars: vars) ?? 0
		let slot = args.count > 1 ? args[1].getValueOrVarValue(vars: vars) : 0
		guard let stream = scene.filmMusicStream(at: slot) else {
			print("== Music getfilmmusic missing: slot \(slot), var \(varId)")
			vars[varId] = 0
			next()
			return
		}

		let streamId = nextStreamId
		nextStreamId += 1
		streams[streamId] = stream
		sharedStreamIds.insert(streamId)
		vars[varId] = Float(streamId)
		print("== Music getfilmmusic: slot \(slot) -> stream \(streamId), var \(varId)")
		next()
	}

	private func setfilmmusic(_ args: [Argument]) {
		let streamId = musicStreamId(from: args.first)
		if let stream = streams[streamId] {
			scene.addFilmMusicStream(stream)
			sharedStreamIds.insert(streamId)
			print("== Music setfilmmusic: stream \(streamId)")
		} else {
			print("== Music setfilmmusic skipped: missing stream \(streamId)")
		}
		next()
	}

	private func musicStreamId(from argument: Argument?) -> Int {
		let rawId = argument?.getValueOrVarValue(vars: vars) ?? 0
		if streams[rawId] != nil {
			return rawId
		}
		return Int(vars[rawId] ?? 0)
	}

	private func stream_setloop(_ args: [Argument]) {
		let streamId = musicStreamId(from: args[0])
		let loops = args[1].getValueOrVarValue(vars: vars) != 0
		if let stream = streams[streamId] {
			DispatchQueue.main.async {
				stream.setLoop(loops)
			}
		}
		next()
	}

	private func stream_stop(_ args: [Argument]) {
		let streamId = musicStreamId(from: args[0])
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

	private func timer_getinterval(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		vars[varId] = currentTimerRemainingMilliseconds()
		next()
	}

	private func timer_setinterval(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		startTimer(milliseconds: max(0, vars[varId] ?? 0))
		next()
	}

	private func timeroff(_ args: [Argument]) {
		timerGeneration += 1
		timerEndTime = nil
		timerRemainingMilliseconds = 0
		next()
	}

	private func timeron(_ args: [Argument]) {
		let seconds = args[3].getValueOrVarValueFloat(vars: vars)
		startTimer(milliseconds: max(0, seconds * 1000))
		next()
	}

	private func vect_add_vect(_ args: [Argument]) {
		let targetVarId = args[0].getValueOrVarValue(vars: vars)
		let sourceVarId = args[1].getValueOrVarValue(vars: vars)
		setVectorVariables(startingAt: targetVarId, vector: vectorVariable(startingAt: targetVarId) + vectorVariable(startingAt: sourceVarId))
		next()
	}

	private func vect_copy(_ args: [Argument]) {
		let targetVarId = args[0].getValueOrVarValue(vars: vars)
		let sourceVarId = args[1].getValueOrVarValue(vars: vars)
		setVectorVariables(startingAt: targetVarId, vector: vectorVariable(startingAt: sourceVarId))
		next()
	}

	private func vect_inverse(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		let vector = vectorVariable(startingAt: varId)
		setVectorVariables(startingAt: varId, vector: SCNVector3(x: -vector.x, y: -vector.y, z: -vector.z))
		next()
	}

	private func vect_magnitude(_ args: [Argument]) {
		let vectorVarId = args[0].getValueOrVarValue(vars: vars)
		let targetVarId = args[1].getValueOrVarValue(vars: vars)
		vars[targetVarId] = vectorVariable(startingAt: vectorVarId).length
		next()
	}

	private func vect_mul_scl(_ args: [Argument]) {
		let vectorVarId = args[0].getValueOrVarValue(vars: vars)
		let scalar = args[1].getValueOrVarValueFloat(vars: vars)
		let vector = vectorVariable(startingAt: vectorVarId)
		setVectorVariables(
			startingAt: vectorVarId,
			vector: SCNVector3(x: vector.x * SCNFloat(scalar), y: vector.y * SCNFloat(scalar), z: vector.z * SCNFloat(scalar))
		)
		next()
	}

	private func vect_mul_vect(_ args: [Argument]) {
		let targetVarId = args[0].getValueOrVarValue(vars: vars)
		let sourceVarId = args[1].getValueOrVarValue(vars: vars)
		let target = vectorVariable(startingAt: targetVarId)
		let source = vectorVariable(startingAt: sourceVarId)
		setVectorVariables(
			startingAt: targetVarId,
			vector: SCNVector3(x: target.x * source.x, y: target.y * source.y, z: target.z * source.z)
		)
		next()
	}

	private func vect_set(_ args: [Argument]) {
		let vectorVarId = args[0].getValueOrVarValue(vars: vars)
		let x = args[1].getValueOrVarValueFloat(vars: vars)
		let y = args[2].getValueOrVarValueFloat(vars: vars)
		let z = args[3].getValueOrVarValueFloat(vars: vars)
		setVectorVariables(startingAt: vectorVarId, vector: SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z)))
		next()
	}

	private func vect_sub_vect(_ args: [Argument]) {
		let targetVarId = args[0].getValueOrVarValue(vars: vars)
		let sourceVarId = args[1].getValueOrVarValue(vars: vars)
		setVectorVariables(startingAt: targetVarId, vector: vectorVariable(startingAt: targetVarId) - vectorVariable(startingAt: sourceVarId))
		next()
	}

	private func version_is_editor(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		vars[varId] = 0
		next()
	}

	private func version_is_germany(_ args: [Argument]) {
		let varId = args[0].getValueOrVarValue(vars: vars)
		vars[varId] = 0
		next()
	}

	private func wait(_ args: [Argument]) {
		let delay = args[0].getValueOrVarValue(vars: vars)
		if beginCommandBlockAsyncOperation() {
			queue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
				self?.finishCommandBlockAsyncOperation()
			}
			next()
		} else {
			waitGeneration += 1
			let generation = waitGeneration
			isWaitingForScriptWait = true
			queue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
				guard let self = self else { return }
				guard self.waitGeneration == generation else { return }
				self.isWaitingForScriptWait = false
				self.next()
			}
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
		return scene.node(named: name)
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

	private func readRemoteScript<T: Sendable>(
		_ remoteScript: Script,
		read: @escaping @Sendable () -> T,
		completion: @escaping @Sendable (T) -> Void
	) {
		if remoteScript === self {
			completion(read())
			return
		}
		remoteScript.queue.async {
			let value = read()
			self.queue.async {
				completion(value)
			}
		}
	}

	private func holsterWeapons(for actor: SCNNode) {
		scene.updateWeaponsIfPresent(for: actor) { weapons in
			for weapon in weapons {
				weapon.position = .inventory
			}
		}

		if actor === scene.playerNode || actor.name == scene.playerNode?.name,
		   let playerNode = scene.playerNode {
			scene.updateWeaponsIfPresent(for: playerNode) { weapons in
				for weapon in weapons {
					weapon.position = .inventory
				}
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
		if node(forScriptId: carId)?.name?.lowercased() == "null" {
			return scene.game.mode != .car || scene.game.vehicle == nil
		}
		if let carNode = node(forScriptId: carId) {
			return scene.game.playerOwnerMatches(carNode: carNode)
		}
		return scene.game.mode == .car && scene.game.vehicle != nil
	}

	private func humanOwnerMatches(actorId: Int, carId: Int) -> Bool {
		guard node(forScriptId: actorId) != nil,
			  let car = node(forScriptId: carId) else {
			return false
		}
		guard let owner = ownerNode(forActorId: actorId) else {
			return car.name?.lowercased() == "null"
		}
		return owner === car || owner.name == car.name
	}

	private func ownerNode(forActorId actorId: Int) -> SCNNode? {
		guard let actor = node(forScriptId: actorId) else { return nil }
		if isPlayerActor(actorId), scene.game.mode == .car {
			return scene.game.vehicle?.scriptNode
		}
		return scene.humanVehicleOwners[ObjectIdentifier(actor)]
	}

	private func setCarUsable(carId: Int, isUsable: Bool) {
		guard let car = node(forScriptId: carId) else { return }
		for key in carUsabilityKeys(for: car) {
			if isUsable {
				scene.unusableCarIds.remove(key)
			} else {
				scene.unusableCarIds.insert(key)
			}
		}
	}

	private func isCarUsable(_ car: SCNNode) -> Bool {
		return carUsabilityKeys(for: car).allSatisfy { !scene.unusableCarIds.contains($0) }
	}

	private func carUsabilityKeys(for car: SCNNode) -> Set<ObjectIdentifier> {
		var nodes = Set<SCNNode>([car])
		if let body = car.mafiaChildNode(named: "BODY", recursively: false) {
			nodes.insert(body)
		}
		if car.name?.uppercased() == "BODY", let parent = car.parent {
			nodes.insert(parent)
		}
		return Set(nodes.map(ObjectIdentifier.init))
	}

	private func placeHuman(_ actor: SCNNode, inCar car: SCNNode, seatId: Int) {
		let body = carBodyNode(for: car)
		let bounds = body.boundingBox
		let width = bounds.max.x - bounds.min.x
		let height = bounds.max.y - bounds.min.y
		let length = bounds.max.z - bounds.min.z
		guard width > 0, height > 0, length > 0 else {
			actor.worldPosition = car.presentation.worldPosition
			removePhysicsBodies(from: actor)
			actor.setHiddenInHierarchy(false)
			return
		}

		let isLeftSeat = seatId == 0 || seatId == 2
		let isFrontSeat = seatId == 0 || seatId == 1
		let seatZOffset = isFrontSeat ? -length * 0.12 : -length * 0.28
		let seatPosition = SCNVector3(
			x: (bounds.min.x + bounds.max.x) / 2 + (isLeftSeat ? -width : width) * 0.12,
			y: bounds.min.y + height * 0.24,
			z: (bounds.min.z + bounds.max.z) / 2 + seatZOffset
		)
		removePhysicsBodies(from: actor)
		body.addChildNode(actor)
		actor.position = seatPosition
		actor.eulerAngles = SCNVector3Zero
		actor.setHiddenInHierarchy(false)
	}

	private func playNpcVehiclePassengerAnimation(in actor: SCNNode) {
		actor.removeAction(forKey: Self.npcVehiclePassengerAnimationKey)
		actor.removeAction(forKey: Self.npcVehiclePassengerAnimationKey + ":position")
		try? playAnimation(
			named: "anims/AutoSpolStativ.5ds",
			in: actor,
			repeat: true,
			animationKey: Self.npcVehiclePassengerAnimationKey
		)
	}

	private func carBodyNode(for car: SCNNode) -> SCNNode {
		if let body = car.mafiaChildNode(named: "BODY", recursively: false) {
			return body
		}
		if let liveTransformNode = car.liveTransformNode {
			return liveTransformNode
		}
		return car
	}

	private func liveDistanceNode(for actor: SCNNode) -> SCNNode {
		return actor.liveTransformNode ?? actor
	}

	private func removePhysicsBodies(from node: SCNNode) {
		node.physicsBody = nil
		for child in node.childNodes {
			removePhysicsBodies(from: child)
		}
	}

	private func stopCarPhysics(carId: Int, brakeCurrentVehicle: Bool) {
		if brakeCurrentVehicle, playerOwnerMatches(carId: carId) {
			scene.game.vehicle?.updateControls(throttle: 0, brake: true, steering: 0)
			scene.game.vehicle?.node.physicsBody?.velocity = SCNVector3Zero
			scene.game.vehicle?.node.physicsBody?.angularVelocity = SCNVector4Zero
			return
		}
		node(forScriptId: carId)?.physicsBody?.velocity = SCNVector3Zero
		node(forScriptId: carId)?.physicsBody?.angularVelocity = SCNVector4Zero
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

	private func currentTimerRemainingMilliseconds() -> Float {
		if let timerEndTime = timerEndTime {
			return Float(max(0, timerEndTime - Date.timeIntervalSinceReferenceDate) * 1000)
		}
		return timerRemainingMilliseconds
	}

	private func startTimer(milliseconds: Float) {
		timerGeneration += 1
		timerRemainingMilliseconds = milliseconds
		guard milliseconds > 0 else {
			timerEndTime = nil
			if let timeoutEventBinding = timeoutEventBinding {
				timeoutEventBinding.script.enqueueEvent(timeoutEventBinding.eventId)
			}
			return
		}

		let generation = timerGeneration
		let seconds = TimeInterval(milliseconds) / 1000
		timerEndTime = Date.timeIntervalSinceReferenceDate + seconds
		queue.asyncAfter(deadline: .now() + seconds) { [weak self] in
			guard let self = self else { return }
			guard self.timerGeneration == generation else { return }
			self.timerEndTime = nil
			self.timerRemainingMilliseconds = 0
			guard let timeoutEventBinding = self.timeoutEventBinding else { return }
			timeoutEventBinding.script.enqueueEvent(timeoutEventBinding.eventId)
		}
	}

	private func fadeSound(_ sound: Sound, from startVolume: Float, to endVolume: Float, duration: TimeInterval) {
		guard duration > 0 else {
			sound.audioSource.volume = endVolume
			return
		}
		let startTime = Date.timeIntervalSinceReferenceDate
		scheduleSoundFadeStep(sound, startVolume: startVolume, endVolume: endVolume, duration: duration, startTime: startTime)
	}

	private func scheduleSoundFadeStep(
		_ sound: Sound,
		startVolume: Float,
		endVolume: Float,
		duration: TimeInterval,
		startTime: TimeInterval
	) {
		queue.asyncAfter(deadline: .now() + .milliseconds(50)) { [weak self] in
			guard let self = self else { return }
			let elapsed = Date.timeIntervalSinceReferenceDate - startTime
			let progress = min(1, Float(elapsed / duration))
			sound.audioSource.volume = startVolume + (endVolume - startVolume) * progress
			if progress < 1 {
				self.scheduleSoundFadeStep(
					sound,
					startVolume: startVolume,
					endVolume: endVolume,
					duration: duration,
					startTime: startTime
				)
			}
		}
	}

	private func normalizedModelName(_ name: String) -> String {
		let normalizedName = name
			.replacingOccurrences(of: "\\", with: "/")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let withoutExtension = (normalizedName as NSString).deletingPathExtension
		return withoutExtension.contains("/") ? withoutExtension : "models/" + withoutExtension
	}

	private func setVectorVariables(startingAt varId: Int, vector: SCNVector3) {
		vars[varId] = Float(vector.x)
		vars[varId + 1] = Float(vector.y)
		vars[varId + 2] = Float(vector.z)
	}

	private func vectorVariable(startingAt varId: Int) -> SCNVector3 {
		return SCNVector3(
			x: SCNFloat(vars[varId] ?? 0),
			y: SCNFloat(vars[varId + 1] ?? 0),
			z: SCNFloat(vars[varId + 2] ?? 0)
		)
	}

	private func worldScale(of transform: SCNMatrix4) -> SCNVector3 {
		let x = SCNVector3(x: transform.m11, y: transform.m12, z: transform.m13).length
		let y = SCNVector3(x: transform.m21, y: transform.m22, z: transform.m23).length
		let z = SCNVector3(x: transform.m31, y: transform.m32, z: transform.m33).length
		return SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
	}

	private func beginPendingEnemyTalk() -> ScriptEnemyTalkOperation {
		let operation = ScriptEnemyTalkOperation()
		pendingEnemyTalk = operation
		return operation
	}

	private func completePendingEnemyTalk(_ operation: ScriptEnemyTalkOperation) {
		queue.async {
			operation.isComplete = true
			let waiters = operation.waiters
			operation.waiters.removeAll()
			if self.pendingEnemyTalk === operation {
				self.pendingEnemyTalk = nil
			}
			for waiter in waiters {
				waiter()
			}
		}
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

final class ScriptMusicStream: @unchecked Sendable {

	private let playback: ScriptMusicStreamPlayback

	init?(url: URL) {
		if url.pathExtension.lowercased() == "ogg" {
			guard let playback = ScriptOggMusicStreamPlayback(url: url) else { return nil }
			self.playback = playback
		} else {
			guard let playback = ScriptBufferedMusicStreamPlayback(url: url) else { return nil }
			self.playback = playback
		}
	}

	var positionMilliseconds: Int {
		return playback.positionMilliseconds
	}

	func play() {
		playback.play()
	}

	func pause() {
		playback.pause()
	}

	func stop() {
		playback.stop()
	}

	func setPosition(milliseconds: Int) {
		playback.setPosition(milliseconds: milliseconds)
	}

	func destroy() {
		playback.destroy()
	}

	func setLoop(_ loops: Bool) {
		playback.setLoop(loops)
	}

	func setGamePaused(_ paused: Bool) {
		playback.setGamePaused(paused)
	}

	func fadeVolume(from startVolume: Float, to endVolume: Float, duration: TimeInterval) {
		playback.fadeVolume(from: startVolume, to: endVolume, duration: duration)
	}

}

private protocol ScriptMusicStreamPlayback: AnyObject {
	var positionMilliseconds: Int { get }
	func play()
	func pause()
	func stop()
	func setPosition(milliseconds: Int)
	func destroy()
	func setLoop(_ loops: Bool)
	func setGamePaused(_ paused: Bool)
	func fadeVolume(from startVolume: Float, to endVolume: Float, duration: TimeInterval)
}

private final class ScriptBufferedMusicStreamPlayback: ScriptMusicStreamPlayback, @unchecked Sendable {

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
		guard let buffer = ScriptBufferedMusicStreamPlayback.makeNativeBuffer(url: url) else { return nil }
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

	func setPosition(milliseconds: Int) {
		runOnMain {
			let position = self.clampedPosition(TimeInterval(max(0, milliseconds)) / 1000)
			let wasPlaying = self.playbackState == .playing
			let shouldReschedule = self.playbackState != .stopped
			self.accumulatedPosition = position
			self.startsAt = wasPlaying ? Date.timeIntervalSinceReferenceDate : nil
			if shouldReschedule {
				self.scheduleBuffer()
			}
			if wasPlaying {
				self.playerNode.play()
			}
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
		guard let scheduledBuffer = makeBuffer(from: accumulatedPosition) else {
			stopPlaying(resetPosition: true)
			return
		}
		let options: AVAudioPlayerNodeBufferOptions = loops ? [.loops] : []
		playerNode.scheduleBuffer(scheduledBuffer, at: nil, options: options) { [weak self] in
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

	private func clampedPosition(_ position: TimeInterval) -> TimeInterval {
		return max(0, min(position, duration))
	}

	private func makeBuffer(from position: TimeInterval) -> AVAudioPCMBuffer? {
		let startFrame = min(buffer.frameLength, AVAudioFrameCount((clampedPosition(position) * buffer.format.sampleRate).rounded(.down)))
		let frameCount = buffer.frameLength - startFrame
		guard frameCount > 0,
			  let scheduledBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: frameCount) else {
			return nil
		}

		scheduledBuffer.frameLength = frameCount
		let sourceBuffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
		let destinationBuffers = UnsafeMutableAudioBufferListPointer(scheduledBuffer.mutableAudioBufferList)
		for index in 0..<min(sourceBuffers.count, destinationBuffers.count) {
			let source = sourceBuffers[index]
			let destination = destinationBuffers[index]
			guard let sourceData = source.mData,
				  let destinationData = destination.mData,
				  buffer.frameLength > 0 else { continue }
			let bytesPerFrame = Int(source.mDataByteSize) / Int(buffer.frameLength)
			let byteOffset = Int(startFrame) * bytesPerFrame
			let byteCount = Int(frameCount) * bytesPerFrame
			memcpy(destinationData, sourceData.advanced(by: byteOffset), byteCount)
		}
		return scheduledBuffer
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

	private func runOnMain(_ block: @escaping @Sendable () -> Void) {
		if Thread.isMainThread {
			block()
		} else {
			DispatchQueue.main.async(execute: block)
		}
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

}

private final class ScriptOggMusicStreamPlayback: ScriptMusicStreamPlayback, @unchecked Sendable {

	private enum PlaybackState {
		case stopped
		case playing
		case paused
	}

	private let engine = AVAudioEngine()
	private var sourceNode: AVAudioSourceNode!
	private let lock = NSLock()
	private var stream: OpaquePointer?
	private let sampleRate: Double
	private let duration: TimeInterval
	private let frameCount: Int64
	private var playbackState: PlaybackState = .stopped
	private var loops = false
	private var volume: Float = 1
	private var fadeWorkItem: DispatchWorkItem?
	private var samplePosition: Int64 = 0
	private var isGamePaused = false
	private var wasPlayingBeforeGamePause = false
	private var didLogFirstRender = false
	private var didLogEndOfStream = false

	init?(url: URL) {
		guard let stream = OggVorbisStreamOpen(url.path) else { return nil }

		let channels = OggVorbisStreamGetChannels(stream)
		let sampleRate = OggVorbisStreamGetSampleRate(stream)
		guard channels > 0,
			  sampleRate > 0,
			  let format = AVAudioFormat(
				commonFormat: .pcmFormatFloat32,
				sampleRate: Double(sampleRate),
				channels: AVAudioChannelCount(channels),
				interleaved: false
			  ) else {
			OggVorbisStreamClose(stream)
			return nil
		}

		self.stream = stream
		self.sampleRate = Double(sampleRate)
		self.duration = TimeInterval(OggVorbisStreamGetDuration(stream))
		self.frameCount = Int64(OggVorbisStreamGetFrameCount(stream))

		sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
			self?.render(frameCount: frameCount, audioBufferList: audioBufferList) ?? 0
		}

		engine.attach(sourceNode)
		engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
		do {
			try engine.start()
		} catch {
			OggVorbisStreamClose(stream)
			self.stream = nil
			return nil
		}
	}

	var positionMilliseconds: Int {
		lock.lock()
		let position = sampleRate > 0 ? TimeInterval(samplePosition) / sampleRate : 0
		let isLooping = loops
		let duration = self.duration
		lock.unlock()

		let normalizedPosition = isLooping && duration > 0 ? position.truncatingRemainder(dividingBy: duration) : position
		let clampedPosition = duration > 0 ? min(normalizedPosition, duration) : normalizedPosition
		return Int((max(0, clampedPosition) * 1000).rounded())
	}

	func play() {
		runOnMain {
			self.lock.lock()
			defer { self.lock.unlock() }

			switch self.playbackState {
			case .playing:
				return
			case .paused:
				self.playbackState = .playing
			case .stopped:
				if let stream = self.stream,
				   self.samplePosition > 0 {
					OggVorbisStreamSeek(stream, Int32(max(0, min(self.samplePosition, Int64(Int32.max)))))
				}
				self.playbackState = .playing
			}
		}
	}

	func pause() {
		runOnMain {
			self.lock.lock()
			if self.playbackState == .playing {
				self.playbackState = .paused
			}
			self.lock.unlock()
		}
	}

	func stop() {
		runOnMain {
			self.stopPlaying(resetPosition: true)
		}
	}

	func setPosition(milliseconds: Int) {
		runOnMain {
			let requestedPosition = TimeInterval(max(0, milliseconds)) / 1000
			let frame = Int64((requestedPosition * self.sampleRate).rounded(.down))
			let maxFrame = self.frameCount > 0 ? self.frameCount : Int64(Int32.max)
			let clampedFrame = max(0, min(frame, maxFrame, Int64(Int32.max)))
			self.lock.lock()
			if let stream = self.stream,
			   OggVorbisStreamSeek(stream, Int32(clampedFrame)) {
				self.samplePosition = clampedFrame
			}
			self.lock.unlock()
		}
	}

	func destroy() {
		runOnMain {
			self.fadeWorkItem?.cancel()
			self.fadeWorkItem = nil
			self.engine.stop()

			self.lock.lock()
			if let stream = self.stream {
				OggVorbisStreamClose(stream)
				self.stream = nil
			}
			self.playbackState = .stopped
			self.samplePosition = 0
			self.lock.unlock()
		}
	}

	func setLoop(_ loops: Bool) {
		runOnMain {
			self.lock.lock()
			self.loops = loops
			self.lock.unlock()
		}
	}

	func setGamePaused(_ paused: Bool) {
		runOnMain {
			self.lock.lock()
			defer { self.lock.unlock() }

			if paused {
				guard !self.isGamePaused else { return }
				self.isGamePaused = true
				self.wasPlayingBeforeGamePause = self.playbackState == .playing
				if self.wasPlayingBeforeGamePause {
					self.playbackState = .paused
				}
			} else {
				guard self.isGamePaused else { return }
				self.isGamePaused = false
				guard self.wasPlayingBeforeGamePause else { return }
				self.wasPlayingBeforeGamePause = false
				guard self.playbackState == .paused else { return }
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

	private func render(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
		let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
		lock.lock()
		defer { lock.unlock() }

		guard playbackState == .playing,
			  let stream = stream else {
			fillSilence(buffers: buffers, from: 0, frameCount: frameCount)
			return 0
		}

		var framesWritten: AVAudioFrameCount = 0
		var didSeekForLoop = false
		while framesWritten < frameCount {
			let framesRequested = frameCount - framesWritten
			var channelData: [UnsafeMutablePointer<Float>?] = buffers.map { buffer in
				guard let data = buffer.mData else { return nil }
				return data.assumingMemoryBound(to: Float.self).advanced(by: Int(framesWritten))
			}

			let framesRead = channelData.withUnsafeMutableBufferPointer { pointers in
				OggVorbisStreamRead(stream, pointers.baseAddress, Int32(framesRequested))
			}

			if framesRead > 0 {
				if !didLogFirstRender {
					print("== Music OGG render: first frames \(framesRead), channels \(buffers.count), volume \(volume)")
					didLogFirstRender = true
				}
				applyVolume(buffers: buffers, from: framesWritten, frameCount: AVAudioFrameCount(framesRead))
				framesWritten += AVAudioFrameCount(framesRead)
				samplePosition += Int64(framesRead)
				didSeekForLoop = false
			} else if loops, !didSeekForLoop, OggVorbisStreamSeekStart(stream) {
				samplePosition = 0
				didSeekForLoop = true
			} else {
				if !didLogEndOfStream {
					print("== Music OGG render: end of stream at sample \(samplePosition)")
					didLogEndOfStream = true
				}
				playbackState = .stopped
				OggVorbisStreamSeekStart(stream)
				samplePosition = 0
				fillSilence(buffers: buffers, from: framesWritten, frameCount: frameCount - framesWritten)
				break
			}
		}

		return 0
	}

	private func stopPlaying(resetPosition: Bool) {
		fadeWorkItem?.cancel()
		fadeWorkItem = nil
		lock.lock()
		playbackState = .stopped
		wasPlayingBeforeGamePause = false
		if resetPosition {
			if let stream = stream {
				OggVorbisStreamSeekStart(stream)
			}
			samplePosition = 0
		}
		lock.unlock()
	}

	private func setVolume(_ volume: Float) {
		let clampedVolume = min(1, max(0, volume))
		lock.lock()
		self.volume = clampedVolume
		lock.unlock()
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

	private func fillSilence(
		buffers: UnsafeMutableAudioBufferListPointer,
		from startFrame: AVAudioFrameCount,
		frameCount: AVAudioFrameCount
	) {
		guard frameCount > 0 else { return }
		for buffer in buffers {
			guard let data = buffer.mData else { continue }
			let samples = data.assumingMemoryBound(to: Float.self).advanced(by: Int(startFrame))
			for index in 0..<Int(frameCount) {
				samples[index] = 0
			}
		}
	}

	private func applyVolume(
		buffers: UnsafeMutableAudioBufferListPointer,
		from startFrame: AVAudioFrameCount,
		frameCount: AVAudioFrameCount
	) {
		guard volume != 1, frameCount > 0 else { return }
		for buffer in buffers {
			guard let data = buffer.mData else { continue }
			let samples = data.assumingMemoryBound(to: Float.self).advanced(by: Int(startFrame))
			for index in 0..<Int(frameCount) {
				samples[index] *= volume
			}
		}
	}

	private func runOnMain(_ block: @escaping @Sendable () -> Void) {
		if Thread.isMainThread {
			block()
		} else {
			DispatchQueue.main.async(execute: block)
		}
	}

}
