//
//  GameActions.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

// MARK: - Actions

extension Game {

	func performAction(_ action: Action) {
		switch action {
		case .action(let script, _):
			let index = scene.actions.firstIndex(where: { action in
				if case .action(let _script, _) = action {
					return script.uuid == _script.uuid
				} else {
					return false
				}
			})!
			scene.actions.remove(at: index)

			script.completeActionWait()

		case .weapon(let node, let weapon):
			node.isHidden = true

			let index = scene.actions.firstIndex(where: { action in
				if case .weapon(_, let _weapon) = action {
					return weapon.uuid == _weapon.uuid
				} else {
					return false
				}
			})!
			scene.actions.remove(at: index)

			scene.updateWeapons(for: scene.playerNode!) { weapons in
				for weapon in weapons {
					weapon.position = .inventory
				}
				weapons.append(weapon)
				weapon.position = .hand
			}

			refreshPlayerStatusHud()

		case .door(let node):
			useDoor(node)

		case .vehicleSteal(let vehicle):
			beginVehicleSteal(vehicle)

		case .vehicleEnter(let vehicle):
			enterVehicleWithAnimation(vehicle)

		case .vehicleExit:
			exitVehicleWithAnimation()
		}
	}

	func actionButtonTapped() {
		let actions = availableActions()
		guard let action = actions.first else { return }
		if actions.count > 1 {
			hud.showActionMenu(actions: actions)
		} else {
			performAction(action)
		}
	}

	func playerDidFire() {
		guard !isGamePaused, !isCutsceneCameraActive else { return }

		pressControl(.FIRE)
		if equippedPlayerWeapon()?.isBaseballBat == true {
			beginBatCharge()
			return
		}
		if firePlayerWeapon() {
			scene.triggerPlayerFireEvent()
		}
	}

	func playerDidHorn() {
		lastControl = .HORN
		if mode == .car {
			vehicle?.playHorn()
		}
		scene.triggerPlayerHornEvent()
	}

	func toggleSpeedLimiter() {
		pressControl(.SPEEDLIMIT)
		guard let vehicle = vehicle else { return }

		vehicle.isSpeedLimiterEnabled.toggle()
		let message = vehicle.isSpeedLimiterEnabled ? "Speed limiter on" : "Speed limiter off"
		updateHud { hud in
			hud.showConsoleText(message)
		}
	}

	func showObjectives() {
		pressControl(.OBJECTIVES)
		let objectives = scene.objectives
		updateHud { hud in
			hud.showCurrentObjectives(objectives)
		}
	}

	func toggleCollisionWireframes() {
		areCollisionWireframesVisible.toggle()
		scnScene.rootNode
			.mafiaChildNode(named: "__collisions__", recursively: false)?
			.setCollisionWireframesVisible(areCollisionWireframesVisible)
		roadDebugNode?.isHidden = !areCollisionWireframesVisible
		scene.setMission6RaceDebugVisible(areCollisionWireframesVisible)
		vehicle?.setCollisionDebugVisible(areCollisionWireframesVisible)
		playerController?.setDebugVisualsVisible(areCollisionWireframesVisible)
		let message = "Collision wireframes \(areCollisionWireframesVisible ? "on" : "off")"
		updateHud { hud in
			hud.showConsoleText(message)
		}
	}

	static func roadDebugNode(for road: Road) -> SCNNode {
		let root = SCNNode()
		root.name = "__road_waypoint_debug__"

		if let routeNode = roadRouteDebugNode(for: road) {
			root.addChildNode(routeNode)
		}

		let waypointMaterial = debugMaterial(color: .magenta, fillMode: .fill)
		for (index, waypoint) in road.waypoints.enumerated() {
			let marker = SCNSphere(radius: 0.18)
			marker.firstMaterial = waypointMaterial
			let node = SCNNode(geometry: marker)
			node.name = "__road_waypoint_\(index)__"
			node.position = raisedRoadDebugPosition(waypoint.position)
			root.addChildNode(node)
		}

		return root
	}

	static func roadRouteDebugNode(for road: Road) -> SCNNode? {
		var vertices: [SCNVector3] = []
		var indices: [Int32] = []
		var drawnConnections = Set<Int64>()
		vertices.reserveCapacity(road.waypoints.count * 2)
		indices.reserveCapacity(road.waypoints.count * 2)

		for (index, waypoint) in road.waypoints.enumerated() {
			for nextIndex in road.continuationWaypointIndices(from: index)
				where road.waypoints.indices.contains(nextIndex) && nextIndex != index {
				let lowIndex = min(index, nextIndex)
				let highIndex = max(index, nextIndex)
				let connectionKey = (Int64(lowIndex) << 32) | Int64(highIndex)
				guard !drawnConnections.contains(connectionKey) else { continue }

				drawnConnections.insert(connectionKey)
				let startVertexIndex = Int32(vertices.count)
				vertices.append(raisedRoadDebugPosition(waypoint.position))
				vertices.append(raisedRoadDebugPosition(road.waypoints[nextIndex].position))
				indices.append(startVertexIndex)
				indices.append(startVertexIndex + 1)
			}
		}

		guard !vertices.isEmpty else { return nil }

		let source = SCNGeometrySource(vertices: vertices)
		let element = SCNGeometryElement(indices: indices, primitiveType: .line)
		let geometry = SCNGeometry(sources: [source], elements: [element])
		geometry.firstMaterial = debugMaterial(color: .cyan)

		let node = SCNNode(geometry: geometry)
		node.name = "__road_waypoint_routes__"
		return node
	}

	static func raisedRoadDebugPosition(_ position: SCNVector3) -> SCNVector3 {
		return SCNVector3(x: position.x, y: position.y + 0.35, z: position.z)
	}

	static func catmullRom(
		previous: SCNVector3,
		start: SCNVector3,
		end: SCNVector3,
		future: SCNVector3,
		progress: Float
	) -> SCNVector3 {
		let t = SCNFloat(max(0, min(1, progress)))
		let t2 = t * t
		let t3 = t2 * t
		return SCNVector3(
			x: 0.5 * (
				2 * start.x +
				(-previous.x + end.x) * t +
				(2 * previous.x - 5 * start.x + 4 * end.x - future.x) * t2 +
				(-previous.x + 3 * start.x - 3 * end.x + future.x) * t3
			),
			y: 0.5 * (
				2 * start.y +
				(-previous.y + end.y) * t +
				(2 * previous.y - 5 * start.y + 4 * end.y - future.y) * t2 +
				(-previous.y + 3 * start.y - 3 * end.y + future.y) * t3
			),
			z: 0.5 * (
				2 * start.z +
				(-previous.z + end.z) * t +
				(2 * previous.z - 5 * start.z + 4 * end.z - future.z) * t2 +
				(-previous.z + 3 * start.z - 3 * end.z + future.z) * t3
			)
		)
	}

	static func debugMaterial(color: SKColor, fillMode: SCNFillMode = .lines) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = color
		material.emission.contents = color
		material.lightingModel = .constant
		material.fillMode = fillMode
		material.isDoubleSided = true
		return material
	}

	func setVehicleStealEnabled(carId: Int, node: SCNNode?, enabled: Bool) {
		if enabled {
			stealEnabledVehicleIds.insert(carId)
			if let node = node {
				stealVehicleNodes[carId] = node
			}
		} else {
			stealEnabledVehicleIds.remove(carId)
			stealVehicleNodes[carId] = nil
			activeSteal = nil
		}
	}

	func markVehicleMustSteal(carId: Int, node: SCNNode?) {
		setVehicleStealEnabled(carId: carId, node: node, enabled: true)
	}

	func didPlayerStealVehicle(carId: Int) -> Bool {
		return stolenVehicleIds.contains(carId)
	}

	func playerOwnerMatches(carNode: SCNNode?) -> Bool {
		guard let carNode = carNode else {
			return mode != .car
		}
		guard mode == .car,
			  let vehicle = vehicle else { return false }

		return isVehicle(vehicle, matching: carNode) ||
			vehicle.node.squaredDistance(to: carNode.presentation.worldPosition) <= vehicleOwnerMatchDistanceSquared ||
			vehicle.scriptNode.squaredDistance(to: carNode.presentation.worldPosition) <= vehicleOwnerMatchDistanceSquared
	}

	func canEnterCurrentVehicle() -> Bool {
		guard let vehicle = vehicle else { return false }
		return vehicleStealId(for: vehicle) == nil
	}

	func pressControl(_ control: Control) {
		guard !arePlayerControlsLocked else { return }
		lastControl = control
		activeControls.insert(control)
	}

	func releaseControl(_ control: Control) {
		activeControls.remove(control)
		if lastControl == control {
			lastControl = nil
		}
		if control == .FIRE {
			releaseBatCharge()
		}
	}

	func isControlPressed(_ control: Control) -> Bool {
		guard !arePlayerControlsLocked else { return false }
		return activeControls.contains(control)
	}

	func consumeLastControl(_ control: Control) -> Bool {
		guard !arePlayerControlsLocked else { return false }
		guard lastControl == control else { return false }
		lastControl = nil
		return true
	}

	func setPlayerControlsLocked(_ isLocked: Bool) {
		arePlayerControlsLocked = isLocked
		if isLocked {
			activeControls.removeAll()
			lastControl = nil
			playerController?.stop()
			vehicle?.updateControls(throttle: 0, brake: true, steering: 0)
		}
	}

	func setPlayerCrouching(_ isCrouching: Bool) {
		if isCrouching {
			pressControl(.CROUCH)
		} else {
			releaseControl(.CROUCH)
		}
		playerController?.setCrouching(isCrouching)
	}

	func holsterPlayerWeapons() {
		guard let playerNode = scene.playerNode else { return }
		let hadHeldWeapon = scene.weapons(for: playerNode).contains { $0.position == .hand }
		let didUpdateWeapons = scene.updateWeaponsIfPresent(for: playerNode) { weapons in
			for weapon in weapons {
				weapon.position = .inventory
			}
		}
		guard didUpdateWeapons else { return }
		if hadHeldWeapon {
			playWeaponToggleAnimation()
		}
		refreshPlayerStatusHud()
	}

	func dropPlayerWeapon() {
		guard let playerNode = scene.playerNode,
			  let weapon = scene.weapons(for: playerNode).first(where: { $0.position == .hand }) else { return }
		dropPlayerWeapon(weapon, from: playerNode)
	}

	func dropPlayerWeapon(_ weapon: Weapon) {
		guard let playerNode = scene.playerNode,
			  scene.weapons(for: playerNode).contains(where: { $0 === weapon }) else { return }
		dropPlayerWeapon(weapon, from: playerNode)
	}

	func dropPlayerWeapon(_ weapon: Weapon, from playerNode: SCNNode) {
		guard let dropNode = droppedWeaponNode(for: weapon, from: playerNode) else { return }

		playWeaponDropAnimation()
		scene.updateWeaponsIfPresent(for: playerNode) { weapons in
			weapons.removeAll { $0 === weapon }
		}
		weapon.position = .inventory
		scene.rootNode.addChildNode(dropNode)
		scene.actions.append(.weapon(dropNode, weapon))
		let message = "Dropped \(weapon.name)"
		updateHud { hud in
			hud.showConsoleText(message)
		}
		refreshPlayerStatusHud()
	}

	func droppedWeaponNode(for weapon: Weapon, from playerNode: SCNNode) -> SCNNode? {
		guard let dropNode = loadHeldWeaponModel(for: weapon) else { return nil }

		dropNode.name = "__dropped_weapon_\(weapon.id)__"
		dropNode.physicsBody = nil
		dropNode.disablePhysicsInHierarchy()

		let handPosition = droppedWeaponHandPosition(in: playerNode)
		let groundPosition = droppedWeaponGroundPosition(below: handPosition, playerNode: playerNode)
		let bounds = dropNode.boundingBox
		let groundY = groundPosition.y - min(bounds.min.y, bounds.max.y)
		dropNode.position = scene.rootNode.convertPosition(
			SCNVector3(x: groundPosition.x, y: groundY, z: groundPosition.z),
			from: nil
		)

		let playerForward = playerNode.presentation.worldFront
		dropNode.eulerAngles = SCNVector3(
			x: 0,
			y: atan2(-playerForward.x, -playerForward.z),
			z: 0
		)
		return dropNode
	}

	func droppedWeaponHandPosition(in playerNode: SCNNode) -> SCNVector3 {
		if let heldWeaponNode = heldWeaponNode,
		   heldWeaponNode.parent != nil {
			return heldWeaponNode.presentation.worldPosition
		}
		return heldWeaponAnchor(in: playerNode).presentation.worldPosition
	}

	func droppedWeaponGroundPosition(below position: SCNVector3, playerNode: SCNNode) -> SCNVector3 {
		let from = SCNVector3(x: position.x, y: position.y + 1.0, z: position.z)
		let to = SCNVector3(x: position.x, y: position.y - 8.0, z: position.z)
		let hits = scnScene.physicsWorld.rayTestWithSegment(from: from, to: to, options: [
			SCNPhysicsWorld.TestOption.collisionBitMask: PhysicsCategory.playerBlocking,
			SCNPhysicsWorld.TestOption.searchMode: SCNPhysicsWorld.TestSearchMode.all
		])

		for hit in hits where hit.worldNormal.y >= 0.5 && !isNode(hit.node, inside: playerNode) {
			return hit.worldCoordinates
		}
		return SCNVector3(x: position.x, y: playerNode.presentation.worldPosition.y, z: position.z)
	}

	func playerInventoryWeapons() -> [Weapon] {
		guard let playerNode = scene.playerNode else { return [] }
		return scene.weapons(for: playerNode)
	}

	@discardableResult
	func addAllPossiblePlayerInventoryItems() -> Int {
		guard let playerNode = scene.playerNode else { return 0 }

		var addedCount = 0
		var addedMagazineCount = 0
		scene.updateWeapons(for: playerNode) { weapons in
			var existingIds = Set(weapons.map { $0.id })
			for weapon in weapons {
				guard let profile = weapon.profile else { continue }
				weapon.restAmmo += profile.clipSize
				addedMagazineCount += 1
			}
			for id in Weapon.allDefinitionIds where !existingIds.contains(id) {
				let weapon = Weapon(id: id)
				if let profile = weapon.profile {
					weapon.clipAmmo = profile.clipSize
					weapon.restAmmo = profile.clipSize
					addedMagazineCount += 1
				} else {
					weapon.clipAmmo = -1
				}
				weapon.position = .inventory
				weapons.append(weapon)
				existingIds.insert(id)
				addedCount += 1
			}
		}

		if addedCount > 0 || addedMagazineCount > 0 {
			let message = "Added \(addedCount) inventory items, \(addedMagazineCount) magazines"
			updateHud { hud in
				hud.showConsoleText(message)
			}
			refreshPlayerStatusHud()
		} else {
			updateHud { hud in
				hud.showConsoleText("Inventory already has all items")
			}
		}
		return addedCount
	}

	func equipPlayerWeapon(_ selectedWeapon: Weapon?) {
		guard let playerNode = scene.playerNode else { return }
		let currentWeapon = scene.weapons(for: playerNode).first { $0.position == .hand }
		let didChangeWeapon = currentWeapon.map { currentWeapon in
			selectedWeapon.map { currentWeapon !== $0 } ?? true
		} ?? (selectedWeapon != nil)

		scene.updateWeaponsIfPresent(for: playerNode) { weapons in
			for weapon in weapons {
				weapon.position = selectedWeapon.map { weapon === $0 } == true ? .hand : .inventory
			}
		}

		if didChangeWeapon {
			playWeaponToggleAnimation()
		}
		if let selectedWeapon = selectedWeapon {
			let message = "Equipped \(selectedWeapon.name)"
			updateHud { hud in
				hud.showConsoleText(message)
			}
		} else {
			updateHud { hud in
				hud.showConsoleText("Empty hands")
			}
		}
		refreshPlayerStatusHud()
	}

	func reloadPlayerWeapon() {
		guard let weapon = equippedPlayerWeapon(),
			  weapon.canReload,
			  let profile = weapon.profile,
			  !isReloading(weapon) else { return }

		reload(weapon, profile: profile)
	}

	func reload(_ weapon: Weapon, profile: Weapon.Profile) {
		let now = Date.timeIntervalSinceReferenceDate
		guard !isReloading(weapon, at: now) else { return }

		let loadedAmmo = min(profile.clipSize, weapon.restAmmo)
		weapon.clipAmmo = loadedAmmo
		weapon.restAmmo -= loadedAmmo
		reloadingWeaponUUID = weapon.uuid
		weaponReloadEndTime = now + reloadDuration(weapon: weapon, profile: profile)
		playWeaponAnimation(weapon: weapon, profile: profile, action: "reload")
		playWeaponSound(profile.reloadSoundName)
		refreshPlayerStatusHud()
	}

	func setPlayerHealth(_ health: Int) {
		playerHealth = max(0, health)
		if Thread.isMainThread {
			refreshPlayerStatusHud()
		} else {
			DispatchQueue.main.async {
				self.refreshPlayerStatusHud()
			}
		}
	}

	func playerEnergyPreservingInvincibility(requestedEnergy: Float) -> Float {
		let requestedEnergy = max(0, requestedEnergy)
		guard isPlayerInvincibleForTesting else { return requestedEnergy }

		let currentEnergy = scene.playerNode?.humanEnergy ?? playerMaxEnergy
		return max(max(currentEnergy, requestedEnergy), playerMaxEnergy)
	}

	func updatePlayerHealthFromEnergy() {
		guard let energy = scene.playerNode?.humanEnergy else {
			setPlayerHealth(100)
			return
		}
		setPlayerHealth(playerHealthPercent(forEnergy: energy))
	}

	func playerHealthPercent(forEnergy energy: Float) -> Int {
		let percent = Int((max(0, energy) / max(1, playerMaxEnergy) * 100).rounded(.towardZero))
		return energy > 0 && percent == 0 ? 1 : percent
	}

	func playSiderollAnimation(direction: SiderollDirection) {
		guard mode == .walk,
			  scene.playerNode != nil else { return }

		let directionValue: Int
		switch direction {
		case .left:
			directionValue = -1
			scene.noteActionAnimation(id: 98)
		case .right:
			directionValue = 1
			scene.noteActionAnimation(id: 99)
		}

		playerController?.playSideJumpActionAnimation(direction: directionValue, animationKey: "__sideroll__")
	}

	func updateFullAutoFire() {
		guard isControlPressed(.FIRE),
			  equippedPlayerWeapon()?.profile?.isFullAuto == true else { return }

		if firePlayerWeapon() {
			scene.triggerPlayerFireEvent()
		}
	}

	func firePlayerWeapon() -> Bool {
		guard !isGamePaused,
			  !isCutsceneCameraActive,
			  mode == .walk || mode == .car,
			  let weapon = equippedPlayerWeapon(),
			  weapon.isFirearm,
			  let profile = weapon.profile else { return false }

		let now = Date.timeIntervalSinceReferenceDate
		guard !isReloading(weapon, at: now) else { return false }
		guard now - lastWeaponShotTime >= profile.shotInterval else { return false }

		if !weapon.hasAmmoLoaded {
			if weapon.canReload {
				reload(weapon, profile: profile)
			}
			return false
		}

		lastWeaponShotTime = now
		if weapon.clipAmmo > 0 {
			weapon.clipAmmo -= 1
		}
		refreshPlayerStatusHud()

		for _ in 0..<profile.pelletCount {
			shootFromPlayer(profile: profile)
		}
		if let fireAnimationName = playWeaponAnimation(weapon: weapon, profile: profile, action: "fire") {
			scheduleShotgunPumpAnimationIfNeeded(weapon: weapon, afterFireAnimation: fireAnimationName)
		}
		playWeaponSound(profile.fireSoundName)
		showMuzzleFlash()
		return true
	}

	func isReloading(_ weapon: Weapon, at time: TimeInterval = Date.timeIntervalSinceReferenceDate) -> Bool {
		guard reloadingWeaponUUID == weapon.uuid else { return false }
		if time < weaponReloadEndTime {
			return true
		}
		reloadingWeaponUUID = nil
		weaponReloadEndTime = 0
		return false
	}

	func reloadDuration(weapon: Weapon, profile: Weapon.Profile) -> TimeInterval {
		let stance = playerController?.isPlayerCrouching == true ? "drep" : "stoj"
		guard let animationName = weaponAnimationName(weapon: weapon, profile: profile, stance: stance, action: "reload"),
			  let animation = try? loadAnimation(named: animationName) else {
			return 1.0
		}
		return max(0.2, animation.1)
	}

	func beginBatCharge() {
		guard !isCutsceneCameraActive,
			  mode == .walk,
			  activeBatChargeStartedAt == nil,
			  equippedPlayerWeapon()?.isBaseballBat == true else { return }

	activeBatChargeStartedAt = Date.timeIntervalSinceReferenceDate
	updateHud { hud in
		hud.updateVehicleStealProgress(0, isVisible: true, label: "Swing force")
	}
	playBaseballBatWindupAnimation()
	}

	func updateBatCharge() {
		guard let startedAt = activeBatChargeStartedAt else { return }
		guard isControlPressed(.FIRE),
			  mode == .walk,
			  equippedPlayerWeapon()?.isBaseballBat == true else {
			cancelBatCharge()
			return
		}

	let elapsed = Date.timeIntervalSinceReferenceDate - startedAt
	updateHud { hud in
		hud.updateVehicleStealProgress(CGFloat(elapsed / self.batChargeDuration), isVisible: true, label: "Swing force")
	}
	}

	func releaseBatCharge() {
		guard let startedAt = activeBatChargeStartedAt else { return }

	activeBatChargeStartedAt = nil
	updateHud { hud in
		hud.updateVehicleStealProgress(0, isVisible: false)
	}
		guard !isCutsceneCameraActive,
			  mode == .walk,
			  equippedPlayerWeapon()?.isBaseballBat == true else { return }

		let elapsed = Date.timeIntervalSinceReferenceDate - startedAt
		let charge = SCNFloat(max(0.15, min(elapsed / batChargeDuration, 1)))
		playBaseballBatHitAnimation()
		swingBaseballBat(charge: charge)
		scene.triggerPlayerFireEvent()
	}

	func cancelBatCharge() {
		activeBatChargeStartedAt = nil
		updateHud { hud in
			hud.updateVehicleStealProgress(0, isVisible: false)
		}
	}

	func updateNPCHealthLabels() {
		guard Thread.isMainThread else {
			npcHumanNodeSnapshotLock.lock()
			let shouldScheduleUpdate = !isNPCHealthLabelUpdateScheduled
			if shouldScheduleUpdate {
				isNPCHealthLabelUpdateScheduled = true
			}
			npcHumanNodeSnapshotLock.unlock()

			if shouldScheduleUpdate {
				DispatchQueue.main.async {
					self.updateNPCHealthLabels()
				}
			}
			return
		}

		var visibleHumanIds = Set<ObjectIdentifier>()
		for humanNode in npcHumanNodes() {
			let id = ObjectIdentifier(humanNode)
			visibleHumanIds.insert(id)
			let labelNode = npcHealthLabelNodes[id] ?? makeNPCHealthLabelNode(for: humanNode)
			npcHealthLabelNodes[id] = labelNode

			if labelNode.parent == nil {
				scene.rootNode.addChildNode(labelNode)
			}
			updateNPCHealthLabel(labelNode, for: humanNode)
		}

		let staleIds = npcHealthLabelNodes.keys.filter { !visibleHumanIds.contains($0) }
		for id in staleIds {
			npcHealthLabelNodes[id]?.removeFromParentNode()
			npcHealthLabelNodes[id] = nil
		}
		npcHumanNodeSnapshotLock.lock()
		isNPCHealthLabelUpdateScheduled = false
		npcHumanNodeSnapshotLock.unlock()
	}

	func npcHumanNodes() -> [SCNNode] {
		guard Thread.isMainThread else {
			return currentNPCHumanNodeSnapshot()
		}

		return refreshNPCHumanNodeSnapshot()
	}

	func currentNPCHumanNodeSnapshot() -> [SCNNode] {
		npcHumanNodeSnapshotLock.lock()
		let nodes = npcHumanNodeSnapshot
		let shouldScheduleUpdate = !isNPCHumanNodeSnapshotUpdateScheduled
		if shouldScheduleUpdate {
			isNPCHumanNodeSnapshotUpdateScheduled = true
		}
		npcHumanNodeSnapshotLock.unlock()

		if shouldScheduleUpdate {
			DispatchQueue.main.async {
				self.refreshNPCHumanNodeSnapshot()
			}
		}
		return nodes
	}

	@discardableResult
	func refreshNPCHumanNodeSnapshot() -> [SCNNode] {
		var nodes: [SCNNode] = []
		collectNPCHumanNodes(in: scene.rootNode, nodes: &nodes)
		npcHumanNodeSnapshotLock.lock()
		npcHumanNodeSnapshot = nodes
		isNPCHumanNodeSnapshotUpdateScheduled = false
		npcHumanNodeSnapshotLock.unlock()
		return nodes
	}

	func updateHostileNPCs(deltaTime: TimeInterval, time: TimeInterval) {
		let dt = SCNFloat(max(0, min(deltaTime, 1.0 / 20.0)))
		var activeNPCIds = Set<ObjectIdentifier>()

		for npc in npcHumanNodes() {
			let npcId = ObjectIdentifier(npc)
			activeNPCIds.insert(npcId)
			guard npc.actorState.canRunScript,
				  humanHealth(for: npc) > 0 else {
				npc.enemyHostileTargetNode = nil
				npc.enemyFollowState = nil
				continue
			}

			if npc.enemyHostileTargetNode == nil,
			   updateFollowingNPC(npc, deltaTime: dt) {
				continue
			}

			guard let target = npc.enemyHostileTargetNode,
				  humanHealth(for: target) > 0,
				  !isNodeHiddenInHierarchy(target) else {
				npc.enemyHostileTargetNode = nil
				continue
			}

			let npcPosition = npc.presentation.worldPosition
			let targetPosition = target.presentation.worldPosition
			faceNPC(npc, toward: targetPosition)

			if npcEnemyStateIsAfraid(npc) {
				moveNPC(npc, awayFrom: targetPosition, deltaTime: dt)
				continue
			}

			if npcEnemyStateSuppressesHostility(npc) {
				continue
			}

			let distance = horizontalDistance(from: npcPosition, to: targetPosition)
			let equippedWeapon = npcEquippedFirearm(for: npc)
			let attackDistance = npcAttackDistance(for: npc, weapon: equippedWeapon)
			if distance > attackDistance * 0.85 {
				moveNPC(npc, toward: targetPosition, deltaTime: dt)
			}

			if distance <= attackDistance,
			   npcCanAttack(npc, at: time, weapon: equippedWeapon) {
				if let weapon = equippedWeapon, let profile = weapon.profile {
					npcLastAttackTimes[npcId] = time
					npcFireWeapon(weapon, profile: profile, from: npc, at: target)
				} else if distance <= npcMeleeAttackDistance {
					npcLastAttackTimes[npcId] = time
					applyHumanDamage(to: target, amount: npcMeleeDamage)
				}
			}
		}

		for staleId in Array(npcLastAttackTimes.keys) where !activeNPCIds.contains(staleId) {
			npcLastAttackTimes[staleId] = nil
		}
	}

	func updateFollowingNPC(_ npc: SCNNode, deltaTime: SCNFloat) -> Bool {
		guard let followState = npc.enemyFollowState else { return false }
		guard let target = followState.targetNode,
			  !isNodeHiddenInHierarchy(target),
			  humanHealth(for: target) > 0 else {
			npc.enemyFollowState = nil
			return false
		}

		let npcPosition = npc.presentation.worldPosition
		let actualTargetPosition = npcActualFollowTargetPosition(for: target)
		let movementTargetPosition = npcFollowTargetPosition(for: target, follower: npc)
		let actualDistance = npcFollowDistance(from: npcPosition, to: actualTargetPosition)
		let movementDistance = horizontalDistance(from: npcPosition, to: movementTargetPosition)
		let desiredDistance = SCNFloat(max(0, followState.distance))
		faceNPC(npc, toward: actualTargetPosition)

		if actualDistance > max(0.1, desiredDistance) {
			let targetPosition = movementDistance > 0.15 ? movementTargetPosition : actualTargetPosition
			moveNPC(npc, toward: targetPosition, deltaTime: deltaTime)
		}

		if actualDistance <= desiredDistance,
		   let script = followState.returnScript {
			followState.returnScript = nil
			script.completeActionWait()
		}

		return true
	}

	func npcFollowDistance(from lhs: SCNVector3, to rhs: SCNVector3) -> SCNFloat {
		let horizontal = horizontalDistance(from: lhs, to: rhs)
		let vertical = abs(lhs.y - rhs.y)
		guard vertical >= npcFollowTrailVerticalThreshold else { return horizontal }
		return sqrt(horizontal * horizontal + vertical * vertical)
	}

	func npcActualFollowTargetPosition(for target: SCNNode) -> SCNVector3 {
		if target === scene.playerNode,
		   mode == .car,
		   let vehicle = vehicle {
			return vehicle.node.presentation.worldPosition
		}
		if let owner = scene.humanVehicleOwners[ObjectIdentifier(target)] {
			return owner.presentation.worldPosition
		}
		return target.presentation.worldPosition
	}

	func npcFollowTargetPosition(for target: SCNNode, follower: SCNNode) -> SCNVector3 {
		if target === scene.playerNode,
		   mode == .car,
		   let vehicle = vehicle {
			return vehicle.node.presentation.worldPosition
		}
		if isPlayerFollowTarget(target),
		   let trailPosition = npcFollowTrailTargetPosition(for: follower, target: target) {
			return trailPosition
		}
		if let owner = scene.humanVehicleOwners[ObjectIdentifier(target)] {
			return owner.presentation.worldPosition
		}
		return target.presentation.worldPosition
	}

	func updatePlayerFollowTrail() {
		guard let position = playerReferencePosition() else {
			playerFollowTrail.removeAll()
			return
		}
		guard let lastPosition = playerFollowTrail.last else {
			playerFollowTrail.append(position)
			return
		}
		guard horizontalDistance(from: lastPosition, to: position) >= playerFollowTrailMinDistance ||
			  abs(lastPosition.y - position.y) >= npcFollowTrailVerticalThreshold else {
			return
		}

		playerFollowTrail.append(position)
		if playerFollowTrail.count > playerFollowTrailMaxPoints {
			playerFollowTrail.removeFirst(playerFollowTrail.count - playerFollowTrailMaxPoints)
		}
	}

	func isPlayerFollowTarget(_ target: SCNNode) -> Bool {
		return target === scene.playerNode ||
			isNode(target, inside: scene.playerNode) ||
			isNode(scene.playerNode ?? target, inside: target)
	}

	func npcFollowTrailTargetPosition(for follower: SCNNode, target: SCNNode) -> SCNVector3? {
		guard playerFollowTrail.count > 1 else { return nil }

		let followerPosition = follower.presentation.worldPosition
		let targetPosition = target.presentation.worldPosition
		guard abs(targetPosition.y - followerPosition.y) >= npcFollowTrailVerticalThreshold else { return nil }

		var nearestIndex: Int?
		var nearestDistance = SCNFloat.greatestFiniteMagnitude
		for (index, position) in playerFollowTrail.enumerated() {
			guard abs(position.y - followerPosition.y) <= npcFollowTrailAttachHeightTolerance else { continue }
			let distance = horizontalDistance(from: followerPosition, to: position)
			if distance < nearestDistance {
				nearestDistance = distance
				nearestIndex = index
			}
		}

		if nearestIndex == nil {
			for (index, position) in playerFollowTrail.enumerated() {
				let distance = horizontalDistance(from: followerPosition, to: position)
				if distance < nearestDistance {
					nearestDistance = distance
					nearestIndex = index
				}
			}
		}

		guard let nearestIndex = nearestIndex else { return nil }
		guard nearestDistance <= npcFollowTrailAttachDistance else { return nil }
		let targetIndex = min(playerFollowTrail.count - 1, nearestIndex + npcFollowTrailLookAheadPoints)
		return playerFollowTrail[targetIndex]
	}

	func collectNPCHumanNodes(in node: SCNNode, nodes: inout [SCNNode]) {
		if isNPCHumanNode(node) {
			nodes.append(node)
			return
		}
		for child in node.childNodes {
			collectNPCHumanNodes(in: child, nodes: &nodes)
		}
	}

	func npcEquippedFirearm(for npc: SCNNode) -> Weapon? {
		let weapons = scene.weapons(for: npc)
		return weapons.first { $0.position == .hand && $0.isFirearm } ??
			weapons.first { $0.isFirearm }
	}

	func npcAttackDistance(for npc: SCNNode, weapon: Weapon?) -> SCNFloat {
		if npc.enemyHostileAttackDistance > 0 {
			return SCNFloat(npc.enemyHostileAttackDistance)
		}
		if let range = weapon?.profile?.range {
			return max(8, min(range * 0.55, npcDefaultAttackDistance))
		}
		return npcMeleeAttackDistance
	}

	func npcCanAttack(_ npc: SCNNode, at time: TimeInterval, weapon: Weapon?) -> Bool {
		let interval = weapon?.profile?.shotInterval ?? npcMeleeInterval
		return time - (npcLastAttackTimes[ObjectIdentifier(npc)] ?? 0) >= interval
	}

	func npcEnemyStateIsAfraid(_ npc: SCNNode) -> Bool {
		return npc.enemyAIState == "afraid"
	}

	func npcEnemyStateSuppressesHostility(_ npc: SCNNode) -> Bool {
		guard let state = npc.enemyAIState else { return false }
		return state == "fight_guard_nohostile" || state == "no_reaction" || state == "nohostile"
	}

	func moveNPC(_ npc: SCNNode, toward targetPosition: SCNVector3, deltaTime: SCNFloat) {
		guard scene.humanVehicleOwners[ObjectIdentifier(npc)] == nil else { return }
		let position = npc.presentation.worldPosition
		let preferredDirection = normalizedHorizontalVector(targetPosition - position, fallback: SCNVector3Zero)
		let direction = npcSteeredDirection(for: npc, preferredDirection: preferredDirection, targetPosition: targetPosition)
		guard direction.length > 0.0001 else { return }
		applyNPCMovement(npc, direction: direction, deltaTime: deltaTime)
	}

	func moveNPC(_ npc: SCNNode, awayFrom targetPosition: SCNVector3, deltaTime: SCNFloat) {
		guard scene.humanVehicleOwners[ObjectIdentifier(npc)] == nil else { return }
		let position = npc.presentation.worldPosition
		let direction = normalizedHorizontalVector(position - targetPosition, fallback: SCNVector3Zero)
		guard direction.length > 0.0001 else { return }
		applyNPCMovement(npc, direction: direction, deltaTime: deltaTime)
	}

	func applyNPCMovement(_ npc: SCNNode, direction: SCNVector3, deltaTime: SCNFloat) {
		let position = npc.presentation.worldPosition
		let movement = direction * (npcMoveSpeed * deltaTime)
		let nextWorldPosition = npcGroundAdjustedPosition(for: npc, movement: movement)
		if let physicsBody = npc.physicsBody, physicsBody.type == .dynamic {
			physicsBody.velocity = SCNVector3(x: direction.x * npcMoveSpeed, y: physicsBody.velocity.y, z: direction.z * npcMoveSpeed)
			if abs(nextWorldPosition.y - position.y) > 0.001 {
				npc.worldPosition = nextWorldPosition
			}
		} else {
			npc.worldPosition = nextWorldPosition
		}
	}

	func npcSteeredDirection(for npc: SCNNode, preferredDirection: SCNVector3, targetPosition: SCNVector3) -> SCNVector3 {
		guard preferredDirection.length > 0.0001 else { return preferredDirection }

		let currentPosition = npc.presentation.worldPosition
		let currentDistance = horizontalDistance(from: currentPosition, to: targetPosition)
		let targetVerticalDelta = targetPosition.y - currentPosition.y
		let shouldSeekHeightChange = abs(targetVerticalDelta) >= npcVerticalSteeringThreshold
		var bestDirection = preferredDirection
		var bestScore = -SCNFloat.greatestFiniteMagnitude

		for angle in npcSteeringAngles {
			let direction = rotateHorizontalVector(preferredDirection, by: angle)
			let nextPosition = npcLookAheadGroundPosition(
				for: npc,
				direction: direction,
				distance: min(npcMoveSpeed, npcSteeringLookAheadDistance)
			)
			let lookAheadPosition = npcLookAheadGroundPosition(
				for: npc,
				direction: direction,
				distance: npcSteeringLookAheadDistance
			)
			let distanceGain = currentDistance - horizontalDistance(from: nextPosition, to: targetPosition)
			let sidePenalty = abs(angle) * npcSteeringSideStepPenalty
			var score = distanceGain - sidePenalty

			if shouldSeekHeightChange {
				let nextRise = nextPosition.y - currentPosition.y
				let lookAheadRise = lookAheadPosition.y - currentPosition.y
				if targetVerticalDelta > 0 {
					score += max(nextRise, lookAheadRise) * 3
				} else {
					score += max(-nextRise, -lookAheadRise) * 3
				}
			}

			if score > bestScore {
				bestScore = score
				bestDirection = direction
			}
		}

		return bestDirection
	}

	func rotateHorizontalVector(_ vector: SCNVector3, by angle: SCNFloat) -> SCNVector3 {
		let cosine = cos(angle)
		let sine = sin(angle)
		return SCNVector3(
			x: vector.x * cosine - vector.z * sine,
			y: 0,
			z: vector.x * sine + vector.z * cosine
		)
	}

	func npcGroundAdjustedPosition(for npc: SCNNode, movement: SCNVector3) -> SCNVector3 {
		let currentPosition = npc.presentation.worldPosition
		return npcGroundAdjustedPosition(from: currentPosition, excluding: npc, movement: movement)
	}

	func npcLookAheadGroundPosition(for npc: SCNNode, direction: SCNVector3, distance: SCNFloat) -> SCNVector3 {
		var position = npc.presentation.worldPosition
		var remainingDistance = distance
		let stepDistance = max(0.15, npcGroundProbeRadius * 1.5)

		while remainingDistance > 0 {
			let step = min(stepDistance, remainingDistance)
			position = npcGroundAdjustedPosition(from: position, excluding: npc, movement: direction * step)
			remainingDistance -= step
		}

		return position
	}

	func npcGroundAdjustedPosition(from currentPosition: SCNVector3, excluding npc: SCNNode, movement: SCNVector3) -> SCNVector3 {
		var nextPosition = SCNVector3(
			x: currentPosition.x + movement.x,
			y: currentPosition.y,
			z: currentPosition.z + movement.z
		)
		guard let groundY = npcGroundWorldY(at: nextPosition, excluding: npc) else {
			return nextPosition
		}

		let deltaY = groundY - currentPosition.y
		if deltaY <= npcMaxStepUp && deltaY >= -npcMaxStepDown {
			nextPosition.y = groundY
		}
		return nextPosition
	}

	func npcGroundWorldY(at worldPosition: SCNVector3, excluding npc: SCNNode) -> SCNFloat? {
		let probeOffsets = [
			SCNVector3Zero,
			SCNVector3(x: npcGroundProbeRadius, y: 0, z: 0),
			SCNVector3(x: -npcGroundProbeRadius, y: 0, z: 0),
			SCNVector3(x: 0, y: 0, z: npcGroundProbeRadius),
			SCNVector3(x: 0, y: 0, z: -npcGroundProbeRadius)
		]
		var highestGroundY: SCNFloat?

		for offset in probeOffsets {
			let probePosition = worldPosition + offset
			let from = SCNVector3(x: probePosition.x, y: probePosition.y + npcGroundProbeLift, z: probePosition.z)
			let to = SCNVector3(x: probePosition.x, y: probePosition.y - npcGroundProbeDrop, z: probePosition.z)
			let physicsHits = scnScene.physicsWorld.rayTestWithSegment(from: from, to: to, options: [
				SCNPhysicsWorld.TestOption.collisionBitMask: PhysicsCategory.playerBlocking,
				SCNPhysicsWorld.TestOption.searchMode: SCNPhysicsWorld.TestSearchMode.all
			])
			for hit in physicsHits where isNPCGroundHit(hit, excluding: npc) {
				if highestGroundY == nil || hit.worldCoordinates.y > highestGroundY! {
					highestGroundY = hit.worldCoordinates.y
				}
			}

			let visualHits = scnScene.rootNode.hitTestWithSegment(
				from: from,
				to: to,
				options: [
					SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
					SCNHitTestOption.backFaceCulling.rawValue: false,
					SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.all.rawValue
				]
			)
			for hit in visualHits where isNPCGroundHit(hit, excluding: npc) {
				if highestGroundY == nil || hit.worldCoordinates.y > highestGroundY! {
					highestGroundY = hit.worldCoordinates.y
				}
			}
		}

		return highestGroundY
	}

	func isNPCGroundHit(_ hit: SCNHitTestResult, excluding npc: SCNNode) -> Bool {
		guard hit.worldNormal.y >= npcMinGroundNormalY else { return false }
		guard !isNode(hit.node, inside: npc),
			  !isCollisionDebugNode(hit.node) else { return false }
		return true
	}

	func isCollisionDebugNode(_ node: SCNNode) -> Bool {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.name == "__collisions__" ||
			   candidate.name == "__player_debug__" ||
			   candidate.name?.hasPrefix("__vehicle_collision_debug__") == true {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	func faceNPC(_ npc: SCNNode, toward targetPosition: SCNVector3) {
		let position = npc.presentation.worldPosition
		let dx = targetPosition.x - position.x
		let dz = targetPosition.z - position.z
		guard abs(dx) > 0.001 || abs(dz) > 0.001 else { return }

		let length = sqrt(dx * dx + dz * dz)
		let worldForward = SCNVector3(x: -dx / length, y: 0, z: -dz / length)
		let localForward = npc.parent?.presentation.convertVector(worldForward, from: nil) ?? worldForward
		let localYaw = atan2(-localForward.x, -localForward.z)
		npc.eulerAngles = SCNVector3(x: 0, y: localYaw, z: 0)
	}

	func npcFireWeapon(_ weapon: Weapon, profile: Weapon.Profile, from npc: SCNNode, at target: SCNNode) {
		if !weapon.hasAmmoLoaded {
			guard weapon.canReload else { return }
			let loadedAmmo = min(profile.clipSize, weapon.restAmmo)
			weapon.clipAmmo = loadedAmmo
			weapon.restAmmo -= loadedAmmo
		}

		let origin = npcMuzzlePosition(for: npc)
		let targetPosition = npcAimPosition(for: target)
		let direction = spreadDirection(from: targetPosition - origin, spread: profile.spread * 0.45)
		let end = origin + direction * profile.range
		let hits = scnScene.rootNode.hitTestWithSegment(
			from: origin,
			to: end,
			options: [
				SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
				SCNHitTestOption.backFaceCulling.rawValue: false
			]
		)

		var tracerEnd = end
		for hit in hits {
			if isIgnoredCombatHitNode(hit.node) ||
			   isNode(hit.node, inside: npc) {
				continue
			}

			tracerEnd = hit.worldCoordinates
			notifyDetectorHit(for: hit.node)
			if let hitNode = shootableNode(from: hit.node) {
				let damagedHuman = applyHumanDamage(to: hit.node, amount: profile.impulse)
				if let body = hitNode.physicsBody {
					applyShotImpact(to: body, node: hitNode, at: hit.worldCoordinates, direction: direction, impulse: profile.impulse)
				} else if !damagedHuman {
					hitNode.position += SCNVector3(x: direction.x * 1.2, y: 0.2, z: direction.z * 1.2)
				}
			}
			showImpact(at: hit.worldCoordinates, normal: hit.worldNormal)
			break
		}

		showTracer(from: origin, to: tracerEnd)
		playWeaponSound(profile.fireSoundName, on: npc)
		if weapon.clipAmmo > 0 {
			weapon.clipAmmo -= 1
		}
		if !weapon.hasAmmoLoaded, weapon.canReload {
			weapon.clipAmmo = min(profile.clipSize, weapon.restAmmo)
			weapon.restAmmo -= weapon.clipAmmo
		}
	}

	func npcMuzzlePosition(for npc: SCNNode) -> SCNVector3 {
		let position = npc.presentation.worldPosition
		let bounds = npc.presentation.boundingBox
		let height = bounds.max.y > bounds.min.y ? bounds.max.y - bounds.min.y : 1.7
		let forward = npc.presentation.worldFront
		return SCNVector3(
			x: position.x - forward.x * 0.45,
			y: position.y + min(max(height * 0.72, 1.1), 1.55),
			z: position.z - forward.z * 0.45
		)
	}

	func npcAimPosition(for target: SCNNode) -> SCNVector3 {
		let position = target.presentation.worldPosition
		let bounds = target.presentation.boundingBox
		let height = bounds.max.y > bounds.min.y ? bounds.max.y - bounds.min.y : 1.7
		return SCNVector3(x: position.x, y: position.y + min(max(height * 0.65, 1.0), 1.45), z: position.z)
	}

	func humanHealth(for node: SCNNode) -> Float {
		if isNode(node, inside: scene.playerNode) {
			return scene.playerNode?.humanEnergy ?? Float(playerHealth)
		}
		if let humanNode = humanNode(from: node) {
			return humanNode.humanEnergy ?? 0
		}
		if node.enemyFollowState != nil || node.enemyHostileTargetNode != nil {
			node.humanEnergy = 100
			return 100
		}
		return 0
	}

	func horizontalDistance(from lhs: SCNVector3, to rhs: SCNVector3) -> SCNFloat {
		let dx = lhs.x - rhs.x
		let dz = lhs.z - rhs.z
		return sqrt(dx * dx + dz * dz)
	}

	func isNPCHumanNode(_ node: SCNNode) -> Bool {
		let hasEnemyAI = node.enemyFollowState != nil || node.enemyHostileTargetNode != nil
		guard !isNPCHealthLabelNode(node),
			  node.humanEnergy != nil || node.type.hasDefaultHumanEnergy || hasEnemyAI,
			  !isNode(node, inside: scene.playerNode),
			  !isNodeHiddenInHierarchy(node) else {
			return false
		}
		if node.humanEnergy == nil {
			node.humanEnergy = 100
		}
		return true
	}

	func makeNPCHealthLabelNode(for humanNode: SCNNode) -> SCNNode {
		let text = SCNText(string: "", extrusionDepth: 0.01)
		text.flatness = 0.2
		text.firstMaterial = npcHealthLabelMaterial()

		let labelNode = SCNNode(geometry: text)
		labelNode.name = "\(npcHealthLabelNodeNamePrefix)\(ObjectIdentifier(humanNode).hashValue)__"
		labelNode.scale = SCNVector3(x: -0.007, y: 0.007, z: 0.007)
		labelNode.constraints = [SCNBillboardConstraint()]
		labelNode.renderingOrder = 1000
		return labelNode
	}

	func updateNPCHealthLabel(_ labelNode: SCNNode, for humanNode: SCNNode) {
		let health = max(0, Int(round(humanNode.humanEnergy ?? 100)))
		let label = "\(npcDisplayName(for: humanNode))\n\(health)"
		if let text = labelNode.geometry as? SCNText, text.string as? String != label {
			text.string = label
			let bounds = text.boundingBox
			labelNode.pivot = SCNMatrix4MakeTranslation(
				(bounds.min.x + bounds.max.x) / 2,
				bounds.min.y,
				0
			)
		}
		labelNode.position = scene.rootNode.convertPosition(npcHealthLabelPosition(for: humanNode), from: nil)
		labelNode.isHidden = health <= 0
	}

	func npcDisplayName(for humanNode: SCNNode) -> String {
		let name = humanNode.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		return name.isEmpty ? "<unnamed>" : name
	}

	func npcHealthLabelPosition(for humanNode: SCNNode) -> SCNVector3 {
		let bounds = humanNode.boundingBox
		let hasBounds = bounds.max.x > bounds.min.x || bounds.max.y > bounds.min.y || bounds.max.z > bounds.min.z
		guard hasBounds else {
			let position = humanNode.presentation.worldPosition
			return SCNVector3(x: position.x, y: position.y + 2.0, z: position.z)
		}

		let localTop = SCNVector3(
			x: (bounds.min.x + bounds.max.x) / 2,
			y: bounds.max.y,
			z: (bounds.min.z + bounds.max.z) / 2
		)
		let worldTop = humanNode.presentation.convertPosition(localTop, to: nil)
		return SCNVector3(x: worldTop.x, y: worldTop.y + 0.35, z: worldTop.z)
	}

	func npcHealthLabelMaterial() -> SCNMaterial {
		let material = SCNMaterial()
		material.lightingModel = .constant
		material.diffuse.contents = SKColor.white
		material.emission.contents = SKColor.white
		material.isDoubleSided = true
		material.writesToDepthBuffer = false
		return material
	}

	func swingBaseballBat(charge: SCNFloat) {
		let origin = cameraNode.presentation.worldPosition
		let cameraForward = cameraNode.presentation.worldFront
		let direction = normalized(SCNVector3(x: -cameraForward.x, y: -cameraForward.y, z: -cameraForward.z))
		let target = SCNVector3(
			x: origin.x + direction.x * batRange,
			y: origin.y + direction.y * batRange,
			z: origin.z + direction.z * batRange
		)

		let hits = scnScene.rootNode.hitTestWithSegment(
			from: origin,
			to: target,
			options: [
				SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
				SCNHitTestOption.backFaceCulling.rawValue: false
			]
		)

		for hit in hits {
			if isIgnoredCombatHitNode(hit.node) ||
			   isNode(hit.node, inside: scene.playerNode) ||
			   isNode(hit.node, inside: vehicle?.node) ||
			   isNode(hit.node, inside: heldWeaponNode) {
				continue
			}

			if let hitNode = shootableNode(from: hit.node) {
				let impulse = batMinImpulse + (batMaxImpulse - batMinImpulse) * charge
				let damagedHuman = applyHumanDamage(to: hit.node, amount: impulse)
				if let body = hitNode.physicsBody {
					applyMeleeImpact(
						to: body,
						node: hitNode,
						at: hit.worldCoordinates,
						direction: direction,
						impulse: impulse
					)
				} else if !damagedHuman {
					hitNode.position += SCNVector3(x: direction.x * charge, y: 0.12 * charge, z: direction.z * charge)
				}
				showImpact(at: hit.worldCoordinates, normal: hit.worldNormal)
				return
			}
		}
	}

	func playBaseballBatWindupAnimation() {
		guard scene.playerNode != nil,
			  let animationName = firstExistingAnimation(named: [
				"anims/boj basb naprah hpt.5ds",
				"anims/boj hpt basb rh.5ds",
				"anims/boj hpt basb lh.5ds"
			  ]) else { return }

		playPlayerActionAnimation(named: animationName, animationKey: "__bat_swing__")
	}

	func playBaseballBatHitAnimation() {
		guard scene.playerNode != nil else { return }

		let candidates = [
			"anims/boj basb z rh.5ds",
			"anims/boj basb z lh.5ds",
			"anims/boj basb z rs.5ds",
			"anims/boj basb z ls.5ds",
			"anims/boj basb kombo.5ds",
			"anims/boj hpt basb rh.5ds",
			"anims/boj hpt basb lh.5ds",
			"anims/boj hpt basb rs.5ds",
			"anims/boj hpt basb ls.5ds"
		]
		let startIndex = batSwingAnimationIndex % candidates.count
		let orderedCandidates = Array(candidates[startIndex...]) + Array(candidates[..<startIndex])
		guard let animationName = firstExistingAnimation(named: orderedCandidates) else { return }

		batSwingAnimationIndex += 1
		playPlayerActionAnimation(named: animationName, animationKey: "__bat_swing__")
	}

	func shootFromPlayer(profile: Weapon.Profile) {
		guard let playerNode = scene.playerNode else { return }

		let origin = playerShotOrigin(for: playerNode)
		let cameraForward = cameraNode.presentation.worldFront
		let direction = spreadDirection(
			from: SCNVector3(x: -cameraForward.x, y: -cameraForward.y, z: -cameraForward.z),
			spread: profile.spread
		)
		let target = SCNVector3(
			x: origin.x + direction.x * profile.range,
			y: origin.y + direction.y * profile.range,
			z: origin.z + direction.z * profile.range
		)
		let hits = scnScene.rootNode.hitTestWithSegment(
			from: origin,
			to: target,
			options: [
				SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
				SCNHitTestOption.backFaceCulling.rawValue: false
			]
		)

		var tracerEnd = target
		for hit in hits {
			if isIgnoredCombatHitNode(hit.node) ||
			   isNode(hit.node, inside: scene.playerNode) ||
			   isNode(hit.node, inside: vehicle?.node) ||
			   isNode(hit.node, inside: heldWeaponNode) {
				continue
			}

			tracerEnd = hit.worldCoordinates
			notifyDetectorHit(for: hit.node)
			if let hitNode = shootableNode(from: hit.node) {
				let damagedHuman = applyHumanDamage(to: hit.node, amount: profile.impulse)
				if let body = hitNode.physicsBody {
					applyShotImpact(
						to: body,
						node: hitNode,
						at: hit.worldCoordinates,
						direction: direction,
						impulse: profile.impulse
					)
				} else if !damagedHuman {
					hitNode.position += SCNVector3(x: direction.x * 1.2, y: 0.2, z: direction.z * 1.2)
				}
			}
			showImpact(at: hit.worldCoordinates, normal: hit.worldNormal)
			showTracer(from: origin, to: tracerEnd)
			return
		}
		showTracer(from: origin, to: tracerEnd)
	}

	func playerShotOrigin(for playerNode: SCNNode) -> SCNVector3 {
		if let heldWeaponNode = heldWeaponNode,
		   heldWeaponNode.parent != nil {
			return heldWeaponNode.presentation.worldPosition
		}

		let position = playerNode.presentation.worldPosition
		let bounds = playerNode.presentation.boundingBox
		let height = bounds.max.y > bounds.min.y ? bounds.max.y - bounds.min.y : 1.7
		let forward = playerNode.presentation.worldFront
		return SCNVector3(
			x: position.x - forward.x * 0.35,
			y: position.y + min(max(height * 0.62, 0.95), 1.45),
			z: position.z - forward.z * 0.35
		)
	}

	func applyShotImpact(to body: SCNPhysicsBody, node: SCNNode, at hitPosition: SCNVector3, direction: SCNVector3, impulse: SCNFloat) {
		let scaledImpulse = impulse * 0.01
		let linearImpulse = SCNVector3(
			x: direction.x * scaledImpulse,
			y: direction.y * scaledImpulse + min(0.08, scaledImpulse * 0.05),
			z: direction.z * scaledImpulse
		)
		body.applyForce(linearImpulse, at: hitPosition, asImpulse: true)

		guard body.type == .dynamic else { return }

		let center = node.presentation.worldPosition
		let lever = hitPosition - center
		var torqueAxis = cross(lever, linearImpulse)
		if torqueAxis.length < 0.001 {
			torqueAxis = cross(SCNVector3(x: 0, y: 1, z: 0), direction)
		}
		torqueAxis = normalized(torqueAxis)
		let angularImpulse = max(0.02, impulse * 0.004)
		body.applyTorque(
			SCNVector4(x: torqueAxis.x, y: torqueAxis.y, z: torqueAxis.z, w: angularImpulse),
			asImpulse: true
		)
	}

	func applyMeleeImpact(to body: SCNPhysicsBody, node: SCNNode, at hitPosition: SCNVector3, direction: SCNVector3, impulse: SCNFloat) {
		let linearImpulse = SCNVector3(
			x: direction.x * impulse,
			y: direction.y * impulse + min(1.2, impulse * 0.12),
			z: direction.z * impulse
		)
		body.applyForce(linearImpulse, at: hitPosition, asImpulse: true)

		guard body.type == .dynamic else { return }

		let center = node.presentation.worldPosition
		let lever = hitPosition - center
		var torqueAxis = cross(lever, linearImpulse)
		if torqueAxis.length < 0.001 {
			torqueAxis = cross(SCNVector3(x: 0, y: 1, z: 0), direction)
		}
		torqueAxis = normalized(torqueAxis)
		let angularImpulse = max(0.08, impulse * 0.08)
		body.applyTorque(
			SCNVector4(x: torqueAxis.x, y: torqueAxis.y, z: torqueAxis.z, w: angularImpulse),
			asImpulse: true
		)
	}

	@discardableResult
	func applyHumanDamage(to node: SCNNode, amount: SCNFloat) -> Bool {
		guard let humanNode = humanNode(from: node) else { return false }

		let currentEnergy = humanNode.humanEnergy ?? 100
		if isNode(humanNode, inside: scene.playerNode), isPlayerInvincibleForTesting {
			humanNode.humanEnergy = playerEnergyPreservingInvincibility(requestedEnergy: currentEnergy)
			updatePlayerHealthFromEnergy()
			return true
		}

		let newEnergy = max(0, currentEnergy - Float(amount))
		humanNode.humanEnergy = newEnergy
		if isNode(humanNode, inside: scene.playerNode) {
			updatePlayerHealthFromEnergy()
		}
		return true
	}

	func humanNode(from node: SCNNode) -> SCNNode? {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.humanEnergy != nil {
				return candidate
			}
			if candidate.type.hasDefaultHumanEnergy {
				candidate.humanEnergy = 100
				return candidate
			}
			current = candidate.parent
		}
		return nil
	}

	func equippedPlayerWeapon() -> Weapon? {
		guard let playerNode = scene.playerNode else { return nil }
		return scene.weapons(for: playerNode).first { $0.position == .hand }
	}

	func equippedPlayerMovementAnimationSetId() -> Int? {
		guard let weapon = equippedPlayerWeapon() else { return nil }
		return standingPlayerAnimationSetId(for: weapon)
	}

	func refreshPlayerStatusHud() {
		let weapon = equippedPlayerWeapon()
		syncHeldPlayerWeapon(weapon)
		let health = playerHealth
		updateHud { hud in
			hud.updatePlayerStatus(health: health, weapon: weapon)
		}
	}

	func syncHeldPlayerWeapon(_ weapon: Weapon?) {
		guard let playerNode = scene.playerNode,
			  let weapon = weapon,
			  weapon.isFirearm || weapon.isBaseballBat else {
			removeHeldPlayerWeapon()
			return
		}
		if heldWeaponUUID == weapon.uuid,
		   heldWeaponNode?.parent != nil,
		   staleHeldWeaponNodes(in: playerNode).isEmpty {
			return
		}

		removeHeldPlayerWeapon()
		guard let modelNode = loadHeldWeaponModel(for: weapon) else { return }

		modelNode.name = "\(heldWeaponNodeNamePrefix)\(weapon.id)__"
		modelNode.physicsBody = nil
		modelNode.disablePhysicsInHierarchy()
		let anchor = heldWeaponAnchor(in: playerNode)
		anchor.addChildNode(modelNode)
		positionHeldWeapon(modelNode, weapon: weapon, anchor: anchor, playerNode: playerNode)

		heldWeaponNode = modelNode
		heldWeaponUUID = weapon.uuid
	}

	func removeHeldPlayerWeapon() {
		heldWeaponNode?.removeFromParentNode()
		if let playerNode = scene.playerNode {
			for node in heldWeaponNodes(in: playerNode) {
				node.removeFromParentNode()
			}
		}
		heldWeaponNode = nil
		heldWeaponUUID = nil
	}

	func staleHeldWeaponNodes(in rootNode: SCNNode) -> [SCNNode] {
		return heldWeaponNodes(in: rootNode).filter { $0 !== heldWeaponNode }
	}

	func heldWeaponNodes(in rootNode: SCNNode) -> [SCNNode] {
		var nodes: [SCNNode] = []
		collectHeldWeaponNodes(in: rootNode, nodes: &nodes)
		return nodes
	}

	func collectHeldWeaponNodes(in node: SCNNode, nodes: inout [SCNNode]) {
		if node.name?.hasPrefix(heldWeaponNodeNamePrefix) == true {
			nodes.append(node)
		}
		for child in node.childNodes {
			collectHeldWeaponNodes(in: child, nodes: &nodes)
		}
	}

	func loadHeldWeaponModel(for weapon: Weapon) -> SCNNode? {
		let rawModelName = weapon.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !rawModelName.isEmpty else { return nil }

		let normalizedModelName = rawModelName.replacingOccurrences(of: "\\", with: "/")
		let modelName = (normalizedModelName as NSString).deletingPathExtension
		let modelPath = modelName.contains("/") ? modelName : "models/" + modelName
		guard let node = try? loadModel(named: modelPath), node.hasModelContent else { return nil }
		return node
	}

	func heldWeaponAnchor(in playerNode: SCNNode) -> SCNNode {
		let handNodeNames = [
			"Bip01 R Hand",
			"Bip01 R Forearm",
			"R Hand",
			"Right Hand",
			"rhand",
			"r_hand",
			"hand_r",
			"right_hand",
			"ruka prava",
			"prava ruka"
		]

		for name in handNodeNames {
			if let node = playerNode.mafiaChildNode(named: name, recursively: true) {
				return node
			}
		}
		return playerNode
	}

	func positionHeldWeapon(_ weaponNode: SCNNode, weapon: Weapon, anchor: SCNNode, playerNode: SCNNode) {
		weaponNode.scale = SCNVector3(x: 1, y: 1, z: 1)
		if anchor === playerNode {
			if weapon.isBaseballBat {
				weaponNode.position = SCNVector3(x: 0.3, y: 0.95, z: -0.12)
				weaponNode.eulerAngles = SCNVector3(x: 0.25, y: .pi / 2, z: .pi / 2)
			} else {
				weaponNode.position = SCNVector3(x: 0.33, y: 1.02, z: -0.18)
				weaponNode.eulerAngles = SCNVector3(x: -0.08, y: .pi / 2, z: -0.18)
			}
		} else {
			if weapon.isBaseballBat {
				weaponNode.position = SCNVector3(x: 0.03, y: -0.06, z: 0.02)
				weaponNode.eulerAngles = SCNVector3(x: 0, y: .pi / 2, z: .pi / 2)
			} else {
				weaponNode.position = SCNVector3(x: 0.05, y: -0.03, z: 0.02)
				weaponNode.eulerAngles = SCNVector3(x: 0, y: .pi / 2, z: 0)
			}
		}
	}

	func spreadDirection(from direction: SCNVector3, spread: SCNFloat) -> SCNVector3 {
		guard spread > 0 else { return normalized(direction) }

		let cameraTransform = cameraNode.presentation.worldTransform
		let right = normalized(SCNVector3(x: cameraTransform.m11, y: cameraTransform.m12, z: cameraTransform.m13))
		let up = normalized(SCNVector3(x: cameraTransform.m21, y: cameraTransform.m22, z: cameraTransform.m23))
		let xSpread = randomSpread() * spread
		let ySpread = randomSpread() * spread
		return normalized(SCNVector3(
			x: direction.x + right.x * xSpread + up.x * ySpread,
			y: direction.y + right.y * xSpread + up.y * ySpread,
			z: direction.z + right.z * xSpread + up.z * ySpread
		))
	}

	func randomSpread() -> SCNFloat {
		return SCNFloat(arc4random_uniform(2001)) / 1000 - 1
	}

	func normalized(_ vector: SCNVector3) -> SCNVector3 {
		let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
		guard length > 0.0001 else { return SCNVector3(x: 0, y: 0, z: -1) }
		return SCNVector3(x: vector.x / length, y: vector.y / length, z: vector.z / length)
	}

	func dot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNFloat {
		return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
	}

	func cross(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNVector3 {
		return SCNVector3(
			x: lhs.y * rhs.z - lhs.z * rhs.y,
			y: lhs.z * rhs.x - lhs.x * rhs.z,
			z: lhs.x * rhs.y - lhs.y * rhs.x
		)
	}

	func normalizedHorizontalVector(_ vector: SCNVector3, fallback: SCNVector3) -> SCNVector3 {
		let length = sqrt(vector.x * vector.x + vector.z * vector.z)
		guard length > 0.0001 else { return fallback }
		return SCNVector3(x: vector.x / length, y: 0, z: vector.z / length)
	}

	func showMuzzleFlash() {
		let flash = SCNNode()
		flash.name = "__muzzle_flash__"
		flash.position = SCNVector3(x: 0, y: -0.09, z: -0.55)
		cameraNode.addChildNode(flash)

		let core = SCNNode(geometry: SCNSphere(radius: 0.055))
		core.geometry?.firstMaterial = emissiveMaterial(color: SKColor.yellow)
		flash.addChildNode(core)

		let flare = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.32))
		flare.geometry?.firstMaterial = emissiveMaterial(color: SKColor.orange.withAlphaComponent(0.86))
		flare.eulerAngles.x = .pi / 2
		flare.position.z = -0.16
		flash.addChildNode(flare)

		let light = SCNNode()
		light.light = SCNLight()
		light.light?.type = .omni
		light.light?.color = SKColor.orange
		light.light?.intensity = 850
		light.light?.attenuationEndDistance = 6
		flash.addChildNode(light)

		for index in 0..<3 {
			let smoke = SCNNode(geometry: SCNSphere(radius: 0.035 + CGFloat(index) * 0.012))
			smoke.name = "__muzzle_smoke__"
			smoke.geometry?.firstMaterial = transparentMaterial(color: SKColor.lightGray.withAlphaComponent(0.28))
			smoke.position = SCNVector3(
				x: randomSpread() * 0.03,
				y: randomSpread() * 0.025,
				z: -0.12 - SCNFloat(index) * 0.05
			)
			flash.addChildNode(smoke)
			smoke.runAction(SCNAction.group([
				SCNAction.moveBy(x: CGFloat(randomSpread() * 0.04), y: CGFloat(0.04 + randomSpread() * 0.02), z: -0.08, duration: 0.18),
				SCNAction.scale(to: 2.2, duration: 0.18),
				SCNAction.fadeOut(duration: 0.18)
			]))
		}

		flash.runAction(SCNAction.sequence([
			SCNAction.wait(duration: 0.035),
			SCNAction.fadeOut(duration: 0.04),
			SCNAction.removeFromParentNode()
		]))
	}

	func playWeaponSound(_ soundName: String?, on node: SCNNode? = nil) {
		guard let soundName = soundName, !soundName.isEmpty else { return }

		let normalizedName = soundName.lowercased()
		let source: SCNAudioSource
		if let cachedSource = weaponAudioSources[normalizedName] {
			source = cachedSource
		} else {
			guard let url = mafiaResourceURL(directory: "sounds", name: normalizedName),
				  let loadedSource = SCNAudioSource(url: url) else { return }
			loadedSource.load()
			weaponAudioSources[normalizedName] = loadedSource
			source = loadedSource
		}
		scene.playAudio(source, on: node ?? cameraNode)
	}

	@discardableResult
	func playWeaponAnimation(weapon: Weapon, profile: Weapon.Profile, action: String) -> String? {
		guard profile.animationSetId > 0,
			  scene.playerNode != nil else { return nil }

		let stance = playerController?.isPlayerCrouching == true ? "drep" : "stoj"
		guard let animationName = weaponAnimationName(weapon: weapon, profile: profile, stance: stance, action: action) else { return nil }
		playPlayerActionAnimation(named: animationName, animationKey: "__weapon_\(action)__")
		return animationName
	}

	func playPlayerActionAnimation(named animationName: String, animationKey: String) {
		if let playerController = playerController {
			playerController.playActionAnimation(named: animationName, animationKey: animationKey)
		} else if let playerNode = scene.playerNode {
			try? playPlayerAnimation(named: animationName, in: playerNode, animationKey: animationKey)
		}
	}

	func playWeaponToggleAnimation() {
		guard let animationName = genericWeaponAnimationName(action: "on off") else { return }
		playPlayerActionAnimation(named: animationName, animationKey: "__weapon_toggle__")
	}

	func playWeaponDropAnimation() {
		guard let animationName = genericWeaponAnimationName(action: "zahozeni") else { return }
		playPlayerActionAnimation(named: animationName, animationKey: "__weapon_drop__")
	}

	func genericWeaponAnimationName(action: String) -> String? {
		let stance = playerController?.isPlayerCrouching == true ? "drep" : "stoj"
		var candidates = ["anims/gun \(stance) \(action).5ds"]
		if stance != "stoj" {
			candidates.append("anims/gun stoj \(action).5ds")
		}
		return firstExistingAnimation(named: candidates)
	}

	func scheduleShotgunPumpAnimationIfNeeded(weapon: Weapon, afterFireAnimation fireAnimationName: String) {
		guard weapon.id == 11 || weapon.id == 34,
			  let playerNode = scene.playerNode else { return }

		let stance = playerController?.isPlayerCrouching == true ? "drep" : "stoj"
		guard let animationName = firstExistingAnimation(named: [
			"anims/gun08 \(stance) Pump.5ds",
			"anims/gun08 stoj Pump.5ds"
		]) else { return }

		let delay = (try? animationDuration(named: fireAnimationName)) ?? 0.2
		playerNode.runAction(SCNAction.sequence([
			SCNAction.wait(duration: delay),
			SCNAction.run { [weak self] _ in
				guard self?.mode == .walk else { return }
				self?.playPlayerActionAnimation(named: animationName, animationKey: "__weapon_pump__")
			}
		]), forKey: "__weapon_pump_schedule__")
	}

	func weaponAnimationName(weapon: Weapon, profile: Weapon.Profile, stance: String, action: String) -> String? {
		let animationSetIds = weaponAnimationSetCandidates(weapon: weapon, profile: profile, stance: stance)
		let prefersStrafe = action == "fire" &&
			playerController?.isPlayerStrafingForWeaponAnimation == true

		var candidates: [String] = []
		for animationSetId in animationSetIds {
			let animationPrefix = "gun" + String(format: "%02d", animationSetId)
			if prefersStrafe {
				candidates.append("anims/\(animationPrefix) \(stance) \(action) Straf.5ds")
			}
			candidates.append("anims/\(animationPrefix) \(stance) \(action).5ds")
			if stance != "stoj" {
				if prefersStrafe {
					candidates.append("anims/\(animationPrefix) stoj \(action) Straf.5ds")
				}
				candidates.append("anims/\(animationPrefix) stoj \(action).5ds")
			}
		}
		return firstExistingAnimation(named: candidates)
	}

	func weaponAnimationSetCandidates(weapon: Weapon, profile: Weapon.Profile, stance: String) -> [Int] {
		var animationSetIds = [profile.animationSetId]
		if stance == "drep" {
			animationSetIds.append(crouchedPlayerAnimationSetId(forStandingSetId: standingPlayerAnimationSetId(for: weapon)))
		}
		animationSetIds.append(standingPlayerAnimationSetId(for: weapon))
		return uniqueValidAnimationSetIds(animationSetIds)
	}

	func standingPlayerAnimationSetId(for weapon: Weapon) -> Int {
		if weapon.isBaseballBat {
			return 1
		}
		switch weapon.id {
		case 6, 7, 8, 9:
			return 2
		case 12:
			return 4
		case 10, 11, 13, 14, 33, 34:
			return 5
		default:
			if let animationSetId = weapon.profile?.animationSetId,
			   (1...8).contains(animationSetId) {
				return animationSetId
			}
			return 1
		}
	}

	func crouchedPlayerAnimationSetId(forStandingSetId animationSetId: Int) -> Int {
		switch animationSetId {
		case 1:
			return 6
		case 2, 3:
			return 7
		default:
			return 8
		}
	}

	func uniqueValidAnimationSetIds(_ animationSetIds: [Int]) -> [Int] {
		var seen = Set<Int>()
		var uniqueIds: [Int] = []
		for animationSetId in animationSetIds where (1...8).contains(animationSetId) && !seen.contains(animationSetId) {
			seen.insert(animationSetId)
			uniqueIds.append(animationSetId)
		}
		return uniqueIds
	}

	func firstExistingAnimation(named candidates: [String]) -> String? {
		return candidates.first { animationExists(named: $0) }
	}

	func animationExists(named animationName: String) -> Bool {
		let url = mainDirectory.appendingPathComponent(animationName.lowercased())
		return FileManager.default.fileExists(atPath: url.path)
	}

	func showTracer(from origin: SCNVector3, to target: SCNVector3) {
		let direction = normalized(target - origin)
		let start = origin + SCNVector3(x: direction.x * 0.75, y: direction.y * 0.75, z: direction.z * 0.75)
		let end = target
		guard (end - start).length > 0.2 else { return }

		let tracer = cylinderNode(
			from: start,
			to: end,
			radius: 0.006,
			material: emissiveMaterial(color: SKColor.yellow.withAlphaComponent(0.72))
		)
		tracer.name = "__bullet_tracer__"
		scnScene.rootNode.addChildNode(tracer)
		tracer.runAction(SCNAction.sequence([
			SCNAction.fadeOut(duration: 0.055),
			SCNAction.removeFromParentNode()
		]))
	}

	func showImpact(at position: SCNVector3, normal: SCNVector3) {
		let surfaceNormal = normalized(normal)
		let liftedPosition = position + SCNVector3(
			x: surfaceNormal.x * 0.012,
			y: surfaceNormal.y * 0.012,
			z: surfaceNormal.z * 0.012
		)

		let impact = SCNNode(geometry: SCNPlane(width: 0.12, height: 0.12))
		impact.name = "__bullet_impact__"
		impact.position = liftedPosition
		impact.geometry?.firstMaterial = transparentMaterial(color: SKColor.black.withAlphaComponent(0.55))
		impact.look(at: liftedPosition + surfaceNormal)
		scnScene.rootNode.addChildNode(impact)
		impact.runAction(SCNAction.sequence([
			SCNAction.wait(duration: 5),
			SCNAction.fadeOut(duration: 0.6),
			SCNAction.removeFromParentNode()
		]))

		let sparkMaterial = emissiveMaterial(color: SKColor.orange)
		for _ in 0..<5 {
			let tangent = normalized(cross(surfaceNormal, abs(surfaceNormal.y) < 0.8 ? SCNVector3(x: 0, y: 1, z: 0) : SCNVector3(x: 1, y: 0, z: 0)))
			let bitangent = normalized(cross(surfaceNormal, tangent))
			let sparkDirection = normalized(SCNVector3(
				x: surfaceNormal.x * 0.7 + tangent.x * randomSpread() + bitangent.x * randomSpread(),
				y: surfaceNormal.y * 0.7 + tangent.y * randomSpread() + bitangent.y * randomSpread(),
				z: surfaceNormal.z * 0.7 + tangent.z * randomSpread() + bitangent.z * randomSpread()
			))
			let sparkEnd = liftedPosition + SCNVector3(
				x: sparkDirection.x * SCNFloat(0.18 + abs(randomSpread()) * 0.22),
				y: sparkDirection.y * SCNFloat(0.18 + abs(randomSpread()) * 0.22),
				z: sparkDirection.z * SCNFloat(0.18 + abs(randomSpread()) * 0.22)
			)
			let spark = cylinderNode(from: liftedPosition, to: sparkEnd, radius: 0.004, material: sparkMaterial)
			spark.name = "__bullet_spark__"
			scnScene.rootNode.addChildNode(spark)
			spark.runAction(SCNAction.sequence([
				SCNAction.group([
					SCNAction.moveBy(x: CGFloat(sparkDirection.x * 0.06), y: CGFloat(sparkDirection.y * 0.06), z: CGFloat(sparkDirection.z * 0.06), duration: 0.12),
					SCNAction.fadeOut(duration: 0.12)
				]),
				SCNAction.removeFromParentNode()
			]))
		}
	}

	func cylinderNode(from start: SCNVector3, to end: SCNVector3, radius: CGFloat, material: SCNMaterial) -> SCNNode {
		let vector = end - start
		let length = CGFloat(vector.length)
		let node = SCNNode(geometry: SCNCylinder(radius: radius, height: length))
		node.geometry?.firstMaterial = material
		node.position = SCNVector3(
			x: (start.x + end.x) / 2,
			y: (start.y + end.y) / 2,
			z: (start.z + end.z) / 2
		)
		alignYAxis(of: node, to: normalized(vector))
		return node
	}

	func alignYAxis(of node: SCNNode, to direction: SCNVector3) {
		let yAxis = SCNVector3(x: 0, y: 1, z: 0)
		let axis = cross(yAxis, direction)
		let axisLength = axis.length
		let clampedDot = max(SCNFloat(-1), min(SCNFloat(1), dot(yAxis, direction)))
		if axisLength < 0.0001 {
			node.rotation = clampedDot < 0 ? SCNVector4(x: 1, y: 0, z: 0, w: .pi) : SCNVector4Zero
			return
		}
		node.rotation = SCNVector4(x: axis.x / SCNFloat(axisLength), y: axis.y / SCNFloat(axisLength), z: axis.z / SCNFloat(axisLength), w: acos(clampedDot))
	}

	func emissiveMaterial(color: SKColor) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = color
		material.emission.contents = color
		material.lightingModel = .constant
		material.isDoubleSided = true
		return material
	}

	func transparentMaterial(color: SKColor) -> SCNMaterial {
		let material = emissiveMaterial(color: color)
		material.transparency = color.rgbaComponents.alpha
		material.blendMode = .alpha
		material.writesToDepthBuffer = false
		return material
	}

	func shootableNode(from node: SCNNode) -> SCNNode? {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.humanEnergy != nil || candidate.type.hasDefaultHumanEnergy {
				return candidate
			}
			if candidate.physicsBody?.type == .dynamic {
				return candidate
			}
			if let name = candidate.name?.lowercased(),
			   name.contains("plechovka") || name.contains("target") {
				return candidate
			}
			current = candidate.parent
		}
		return nil
	}

	func notifyDetectorHit(for hitNode: SCNNode) {
		guard !scene.detectorHitWaits.isEmpty else { return }

		var completedScripts: [Script] = []
		scene.detectorHitWaits.removeAll { wait in
			guard let script = wait.script,
				  let detectorNode = wait.node else {
				return true
			}
			let matches = hitNode === detectorNode ||
				isNode(hitNode, inside: detectorNode) ||
				isNode(detectorNode, inside: hitNode)
			if matches {
				completedScripts.append(script)
				return true
			}
			return false
		}
		for script in completedScripts {
			script.completeActionWait()
		}
	}

	func isShotEffectNode(_ node: SCNNode) -> Bool {
		var current: SCNNode? = node
		while let candidate = current {
			if let name = candidate.name, name.hasPrefix("__bullet_") || name.hasPrefix("__muzzle_") {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	func isIgnoredCombatHitNode(_ node: SCNNode) -> Bool {
		return isShotEffectNode(node) || isNPCHealthLabelNode(node)
	}

	func isNPCHealthLabelNode(_ node: SCNNode) -> Bool {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.name?.hasPrefix(npcHealthLabelNodeNamePrefix) == true {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	func isNodeHiddenInHierarchy(_ node: SCNNode) -> Bool {
		var current: SCNNode? = node
		while let candidate = current {
			if candidate.isHidden {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	func isNode(_ node: SCNNode, inside root: SCNNode?) -> Bool {
		guard let root = root else { return false }
		var current: SCNNode? = node
		while let candidate = current {
			if candidate === root {
				return true
			}
			current = candidate.parent
		}
		return false
	}

	func nearestAction() -> Action? {
		return availableActions().first
	}

	func availableActions() -> [Action] {
		if mode == .car {
			guard let vehicle = vehicle else { return [] }
			let scriptedActions = scriptedVehicleActions(for: vehicle)
			if !scriptedActions.isEmpty {
				return scriptedActions
			}
			return vehicleExitAction().map { [$0] } ?? []
		}

		guard mode == .walk,
			  let playerNode = scene.playerNode else { return [] }

		let playerPosition = playerNode.presentation.worldPosition
		var actions = scene.actions
		if let stealAction = stealableVehicleAction() {
			actions.append(stealAction)
		} else if let enterAction = enterableVehicleAction() {
			actions.append(enterAction)
		}
		return actions
			.filter { $0.isEnabled && $0.node.actionSquaredDistance(to: playerPosition) < actionDistanceSquared }
			.sorted { $0.node.actionSquaredDistance(to: playerPosition) < $1.node.actionSquaredDistance(to: playerPosition) }
	}

	func useDoor(_ node: SCNNode) {
		guard let door = node.doorData else { return }
		guard node.action(forKey: "door") == nil else { return }

		if door.isLocked {
			playDoorSound(door.lockedSound, on: node)
			return
		}

		let currentEulerAngles = node.eulerAngles
		if door.closedEulerAngles == nil {
			let closedY = door.isOpen ? currentEulerAngles.y - door.initialOpenAngle(forUserSide: door.openDirection) : currentEulerAngles.y
			door.closedEulerAngles = SCNVector3(x: currentEulerAngles.x, y: closedY, z: currentEulerAngles.z)
		}

		let closedEulerAngles = door.closedEulerAngles ?? currentEulerAngles
		let duration: TimeInterval
		let targetEulerAngles: SCNVector3

		if door.isOpen {
			duration = door.closeSpeed
			targetEulerAngles = closedEulerAngles
			playDoorSound(door.closeSound, on: node)
		} else {
			door.openDirection = doorOpenDirection(for: node)
			duration = door.openSpeed
			targetEulerAngles = SCNVector3(
				x: closedEulerAngles.x,
				y: closedEulerAngles.y + door.initialOpenAngle(forUserSide: door.openDirection),
				z: closedEulerAngles.z
			)
			playDoorSound(door.openSound, on: node)
		}

		node.runAction(
			SCNAction.rotateTo(
				x: CGFloat(targetEulerAngles.x),
				y: CGFloat(targetEulerAngles.y),
				z: CGFloat(targetEulerAngles.z),
				duration: duration,
				usesShortestUnitArc: true
			),
			forKey: "door"
		) {
			door.isOpen = !door.isOpen
		}
	}

	func doorOpenDirection(for node: SCNNode) -> Int {
		guard let playerNode = scene.playerNode else { return 0 }

		let vectorToPlayer = playerNode.presentation.worldPosition - node.presentation.worldPosition
		let forward = node.presentation.worldFront
		let dot = vectorToPlayer.x * forward.x + vectorToPlayer.y * forward.y + vectorToPlayer.z * forward.z
		return dot > 0 ? 0 : 1
	}

	func playDoorSound(_ soundName: String, on node: SCNNode) {
		guard !soundName.isEmpty else { return }

		let normalizedName = soundName.lowercased().replacingOccurrences(of: ".wav", with: "") + ".wav"
		let url = mainDirectory.appendingPathComponent("sounds/" + normalizedName)
		guard let source = SCNAudioSource(url: url) else { return }
		source.load()
		scene.playAudio(source, on: node)
	}

	func openInventory() {
		updateHud { hud in
			hud.toggleInventory()
		}
	}

}
