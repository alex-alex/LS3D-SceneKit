//
//  Vehicle.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import AVFoundation
import SceneKit

final class Vehicle {

	let scriptNode: SCNNode
	let node: SCNNode
	let physicsVehicle: SCNPhysicsVehicle

	private let maximumSteering: CGFloat = 0.32
	private let engineForce: CGFloat = 6500
	private let brakeForce: CGFloat = 260
	private let speedLimiterBrakeForce: CGFloat = 80
	private let speedLimiterLimit: CGFloat = 60
	private let idleBrakeForce: CGFloat = 8
	private let tractionAssistSpeedLimit: CGFloat = 2
	private let launchMinimumWheelForceScale: CGFloat = 0.35
	private let reverseLaunchMinimumWheelForceScale: CGFloat = 0.7
	private let centerOfMassYOffset: SCNFloat = -0.45
	private let wheelSuspensionRestLength: CGFloat = 0.18
	private let wheelSuspensionTravel: CGFloat = 0.65
	private let wheelSuspensionStiffness: CGFloat = 32
	private let wheelSuspensionCompression: CGFloat = 16
	private let wheelSuspensionDamping: CGFloat = 24
	private let wheelFrictionSlip: CGFloat = 6
	private let wheelRadiusScale: CGFloat = 1.16
	private let steeringResponse: CGFloat = 0.06
	private let wheelSteeringAxis = SCNVector3(x: 0, y: -1, z: 0)
	private let wheelAxle = SCNVector3(x: 1, y: 0, z: 0)
	private let chassisPhysicsWidthScale: SCNFloat = 0.62
	private let chassisPhysicsHeightScale: SCNFloat = 0.28
	private let chassisPhysicsLengthScale: SCNFloat = 0.58
	private let chassisPhysicsCenterHeight: SCNFloat = 0.72
	private let resetHeight: SCNFloat = 1.2
	private var isBraking = false
	private var audio: VehicleAudio?
	var isSpeedLimiterEnabled = false

	var force: CGFloat = 0
	private var targetVehicleSteering: CGFloat = 0
	var speed: CGFloat {
		return CGFloat(abs(physicsVehicle.speedInKilometersPerHour))
	}
	private var chassisSpeed: CGFloat {
		guard let velocity = node.physicsBody?.velocity else { return 0 }
		return CGFloat(sqrt(
			velocity.x * velocity.x +
			velocity.y * velocity.y +
			velocity.z * velocity.z
		))
	}
	var velocity: SCNVector3 {
		return node.physicsBody?.velocity ?? SCNVector3Zero
	}
	var vehicleSteering: CGFloat = 0 {
		didSet {
			if vehicleSteering < -maximumSteering {
				vehicleSteering = -maximumSteering
			}
			if vehicleSteering > maximumSteering {
				vehicleSteering = maximumSteering
			}
		}
	}

	init?(scene: SCNScene, node: SCNNode) {
		guard let taxiNode = node.mafiaChildNode(named: "BODY", recursively: false),
			  let whl0 = node.mafiaChildNode(named: "WHL0", recursively: true),
			  let whr0 = node.mafiaChildNode(named: "WHR0", recursively: true),
			  let whl1 = node.mafiaChildNode(named: "WHL1", recursively: true),
			  let whr1 = node.mafiaChildNode(named: "WHR1", recursively: true),
			  Vehicle.hasUsableBounds(taxiNode),
			  Vehicle.hasUsableBounds(whl0),
			  Vehicle.hasUsableBounds(whr0),
			  Vehicle.hasUsableBounds(whl1),
			  Vehicle.hasUsableBounds(whr1) else {
			return nil
		}

		scriptNode = node
		self.node = taxiNode

		Vehicle.attachChassisVisuals(from: node, to: taxiNode)
		Vehicle.detachChassisForPhysics(
			scene: scene,
			vehicleRoot: node,
			chassisNode: taxiNode,
			wheelNodes: [whl0, whr0, whl1, whr1]
		)

		taxiNode.physicsBody = SCNPhysicsBody(
			type: .dynamic,
			shape: Vehicle.chassisPhysicsShape(
				for: taxiNode,
				widthScale: chassisPhysicsWidthScale,
				heightScale: chassisPhysicsHeightScale,
				lengthScale: chassisPhysicsLengthScale,
				centerHeight: chassisPhysicsCenterHeight
			)
		)
		taxiNode.physicsBody?.allowsResting = false
		taxiNode.physicsBody?.mass = 1000
		taxiNode.physicsBody?.restitution = 0
		taxiNode.physicsBody?.friction = 0.5
		taxiNode.physicsBody?.rollingFriction = 0
		taxiNode.physicsBody?.damping = 0.12
		taxiNode.physicsBody?.angularDamping = 0.8
		taxiNode.physicsBody?.centerOfMassOffset = SCNVector3(x: 0, y: centerOfMassYOffset, z: 0)
		taxiNode.physicsBody?.configureAsVehicleCollider()

		let wheel0 = SCNPhysicsVehicleWheel(node: whl0)
		let wheel1 = SCNPhysicsVehicleWheel(node: whr0)
		let wheel2 = SCNPhysicsVehicleWheel(node: whl1)
		let wheel3 = SCNPhysicsVehicleWheel(node: whr1)

		let wheels = [wheel0, wheel1, wheel2, wheel3]
		let wheelNodes = [whl0, whr0, whl1, whr1]

		for (wheel, wheelNode) in zip(wheels, wheelNodes) {
			wheel.radius = Vehicle.wheelRadius(for: wheelNode) * wheelRadiusScale
		}

		wheel0.connectionPosition = Vehicle.wheelConnectionPosition(for: whl0, wheel: wheel0, restLength: wheelSuspensionRestLength, in: taxiNode)
		wheel1.connectionPosition = Vehicle.wheelConnectionPosition(for: whr0, wheel: wheel1, restLength: wheelSuspensionRestLength, in: taxiNode)
		wheel2.connectionPosition = Vehicle.wheelConnectionPosition(for: whl1, wheel: wheel2, restLength: wheelSuspensionRestLength, in: taxiNode)
		wheel3.connectionPosition = Vehicle.wheelConnectionPosition(for: whr1, wheel: wheel3, restLength: wheelSuspensionRestLength, in: taxiNode)

		physicsVehicle = SCNPhysicsVehicle(chassisBody: taxiNode.physicsBody!, wheels: wheels)
		configure(wheels: wheels)
		scene.physicsWorld.addBehavior(physicsVehicle)

		let soundProfile = VehicleSoundProfile.profile(for: node)
		if soundProfile == nil {
			VehicleSoundLog.log("No sound profile for vehicle node '\(node.name ?? "<unnamed>")'")
		}
		audio = VehicleAudio(profile: soundProfile)
	}

	private static func chassisPhysicsShape(
		for chassisNode: SCNNode,
		widthScale: SCNFloat,
		heightScale: SCNFloat,
		lengthScale: SCNFloat,
		centerHeight: SCNFloat
	) -> SCNPhysicsShape {
		let bounds = chassisNode.boundingBox
		let width = bounds.max.x - bounds.min.x
		let height = bounds.max.y - bounds.min.y
		let length = bounds.max.z - bounds.min.z
		let box = SCNBox(
			width: CGFloat(width * widthScale),
			height: CGFloat(height * heightScale),
			length: CGFloat(length * lengthScale),
			chamferRadius: CGFloat(height * heightScale * 0.18)
		)
		let shapeNode = SCNNode(geometry: box)
		shapeNode.position = SCNVector3(
			x: (bounds.min.x + bounds.max.x) / 2,
			y: bounds.min.y + height * centerHeight,
			z: (bounds.min.z + bounds.max.z) / 2
		)
		return SCNPhysicsShape(node: shapeNode, options: nil)
	}

	private static func hasUsableBounds(_ node: SCNNode) -> Bool {
		let bounds = node.boundingBox
		let width = bounds.max.x - bounds.min.x
		let height = bounds.max.y - bounds.min.y
		let length = bounds.max.z - bounds.min.z
		return width > 0 && height > 0 && length > 0
	}

	private static func wheelRadius(for wheelNode: SCNNode) -> CGFloat {
		let bounds = wheelNode.boundingBox
		let verticalDiameter = bounds.max.y - bounds.min.y
		let longitudinalDiameter = bounds.max.z - bounds.min.z
		let diameter = max(verticalDiameter, longitudinalDiameter)
		return CGFloat(diameter / 2)
	}

	private static func wheelConnectionPosition(for wheelNode: SCNNode, wheel: SCNPhysicsVehicleWheel, restLength: CGFloat, in chassisNode: SCNNode) -> SCNVector3 {
		let rideHeight = SCNFloat(wheel.radius + restLength)
		return wheelNode.convertPosition(SCNVector3(), to: chassisNode) + SCNVector3(x: 0, y: rideHeight, z: 0)
	}

	private func configure(wheels: [SCNPhysicsVehicleWheel]) {
		for wheel in wheels {
			wheel.suspensionRestLength = wheelSuspensionRestLength
			wheel.maximumSuspensionTravel = wheelSuspensionTravel
			wheel.suspensionStiffness = wheelSuspensionStiffness
			wheel.suspensionCompression = wheelSuspensionCompression
			wheel.suspensionDamping = wheelSuspensionDamping
			wheel.frictionSlip = wheelFrictionSlip
			wheel.steeringAxis = wheelSteeringAxis
			wheel.axle = wheelAxle
		}
	}

	private static func attachChassisVisuals(from vehicleRoot: SCNNode, to chassisNode: SCNNode) {
		let detachedWheelNames: Set<String> = ["whl0", "whr0", "whl1", "whr1"]

		for childNode in vehicleRoot.childNodes {
			guard childNode !== chassisNode else { continue }
			guard !detachedWheelNames.contains(childNode.name?.lowercased() ?? "") else { continue }

			let worldTransform = childNode.worldTransform
			chassisNode.addChildNode(childNode)
			childNode.transform = chassisNode.convertTransform(worldTransform, from: nil)
		}
	}

	private static func detachChassisForPhysics(
		scene: SCNScene,
		vehicleRoot: SCNNode,
		chassisNode: SCNNode,
		wheelNodes: [SCNNode]
	) {
		let parentNode = vehicleRoot.parent ?? scene.rootNode
		let chassisWorldTransform = chassisNode.worldTransform
		let wheelWorldTransforms = wheelNodes.map(\.worldTransform)

		parentNode.addChildNode(chassisNode)
		chassisNode.transform = parentNode.convertTransform(chassisWorldTransform, from: nil)

		for (wheelNode, worldTransform) in zip(wheelNodes, wheelWorldTransforms) {
			chassisNode.addChildNode(wheelNode)
			wheelNode.transform = chassisNode.convertTransform(worldTransform, from: nil)
		}
	}

	func applyForces() {
		vehicleSteering += (targetVehicleSteering - vehicleSteering) * steeringResponse
		physicsVehicle.setSteeringAngle(vehicleSteering, forWheelAt: 0)
		physicsVehicle.setSteeringAngle(vehicleSteering, forWheelAt: 1)

		let clampedForce = max(-engineForce, min(engineForce, force))
		let isLimiterHolding = isSpeedLimiterEnabled && speed > speedLimiterLimit && clampedForce < 0
		let brakingForce: CGFloat
		if isBraking {
			brakingForce = brakeForce
		} else if isLimiterHolding {
			brakingForce = speedLimiterBrakeForce
		} else {
			brakingForce = clampedForce == 0 ? idleBrakeForce : 0
		}

		for wheelIndex in 0..<4 {
			physicsVehicle.applyBrakingForce(0, forWheelAt: wheelIndex)
			physicsVehicle.applyEngineForce(0, forWheelAt: wheelIndex)
			physicsVehicle.applyBrakingForce(brakingForce, forWheelAt: wheelIndex)
		}

		let launchProgress = min(1, chassisSpeed / tractionAssistSpeedLimit)
		let minimumWheelForceScale = clampedForce > 0 ? reverseLaunchMinimumWheelForceScale : launchMinimumWheelForceScale
		let launchWheelForceScale = minimumWheelForceScale + (1 - minimumWheelForceScale) * launchProgress
		let wheelForce = isLimiterHolding ? 0 : clampedForce * launchWheelForceScale

		physicsVehicle.applyEngineForce(wheelForce, forWheelAt: 2)
		physicsVehicle.applyEngineForce(wheelForce, forWheelAt: 3)
	}

	func resetUpright() {
		let currentPosition = node.presentation.position
		let forward = node.presentation.worldFront
		let yaw = atan2(-forward.x, -forward.z)

		node.physicsBody?.clearAllForces()
		node.physicsBody?.velocity = SCNVector3Zero
		node.physicsBody?.angularVelocity = SCNVector4Zero
		node.position = SCNVector3(
			x: currentPosition.x,
			y: currentPosition.y + resetHeight,
			z: currentPosition.z
		)
		node.eulerAngles = SCNVector3(x: 0, y: yaw, z: 0)
		updateControls(throttle: 0, brake: false, steering: 0)
		applyForces()
	}

	func updateControls(throttle: CGFloat, brake: Bool, steering: CGFloat) {
		isBraking = brake
		targetVehicleSteering = steering * maximumSteering
		let clampedThrottle = max(-1, min(1, throttle))
		if isSpeedLimiterEnabled && clampedThrottle > 0 && speed >= speedLimiterLimit {
			force = 0
		} else {
			force = brake ? 0 : -clampedThrottle * engineForce
		}
	}

	func updateAudio(isActive: Bool) {
		audio?.update(on: node, speed: speed, throttle: -force / engineForce, isBraking: isBraking, isActive: isActive)
	}

	func playHorn() {
		audio?.playHorn(on: node)
	}

	func setAudioPaused(_ isPaused: Bool) {
		audio?.setPaused(isPaused)
	}

}

private struct VehicleSoundProfile {

	let startSound: String?
	let stopSound: String?
	let npcLoopSound: String?
	let idleLoopSound: String?
	let engineLoopSounds: [String]
	let brakeLoopSound: String?
	let hornSound: String?

	private static let recordStride = 4429
	private static let profiles = loadProfiles()
	private static let genericSoundNames: Set<String> = [
		"engine_on.wav", "engine_off.wav", "engine_on_nf.wav", "ngine_on.wav", "ngine_off.wav",
		"engine1.wav", "interier.wav", "interier_x.wav", "interier_0.wav", "interier_a.wav",
		"gear1.wav", "gear2.wav", "gear3.wav", "gear4.wav",
		"brzdy_loop.wav", "break.wav", "carglass.wav",
		"crasha1.wav", "crasha2.wav", "crashk1.wav", "crashk2.wav",
		"crashb1.wav", "crashb2.wav", "crashc1.wav", "crashc2.wav",
		"crasha1in.wav", "crasha2in.wav", "crashk1in.wav", "crashk2in.wav",
		"crashb1in.wav", "crashb2in.wav", "crashc1in.wav", "crashc2in.wav"
	]

	static func profile(for node: SCNNode) -> VehicleSoundProfile? {
		let candidateNames = vehicleNameCandidates(for: node)
		guard !candidateNames.isEmpty else { return nil }
		VehicleSoundLog.log("Vehicle '\(node.name ?? "<unnamed>")' sound candidates: \(candidateNames.joined(separator: ", "))")
		for name in candidateNames {
			if let profile = profiles[name] {
				VehicleSoundLog.log(
					"Matched vehicle sound profile '\(name)': start=\(profile.startSound ?? "nil"), stop=\(profile.stopSound ?? "nil"), idle=\(profile.idleLoopSound ?? "nil"), brake=\(profile.brakeLoopSound ?? "nil"), horn=\(profile.hornSound ?? "nil"), loops=\(profile.engineLoopSounds.joined(separator: ", "))"
				)
				return profile
			}
		}
		VehicleSoundLog.log("No profile matched candidates: \(candidateNames.joined(separator: ", "))")
		return nil
	}

	private static func vehicleNameCandidates(for node: SCNNode) -> [String] {
		var names: [String] = []
		var currentNode: SCNNode? = node
		while let node = currentNode {
			if let name = node.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
				names.append(contentsOf: name.vehicleSoundCandidateKeys)
			}
			if let modelName = node.vehicleModelName?.trimmingCharacters(in: .whitespacesAndNewlines), !modelName.isEmpty {
				names.append(contentsOf: modelName.vehicleSoundCandidateKeys)
			}
			currentNode = node.parent
		}
		return names.removingDuplicates()
	}

	private static func loadProfiles() -> [String: VehicleSoundProfile] {
		let vehicleURL = mainDirectory.appendingPathComponent("tables/vehicles.bin")
		let carIndexURL = mainDirectory.appendingPathComponent("tables/carindex.def")
		guard let vehicleData = try? Data(contentsOf: vehicleURL),
			  let carIndexData = try? Data(contentsOf: carIndexURL) else {
			VehicleSoundLog.log("Unable to load vehicle sound metadata from tables/vehicles.bin or tables/carindex.def")
			return [:]
		}

		let entries = carIndexData.vehicleEntries()
		let keys = entries.map { $0.key }
		let lowerVehicleData = Data(vehicleData.map { UInt8(asciiLowercase: $0) })
		let locatedRecords = keys.compactMap { key -> (key: String, recordNameOffset: Int)? in
			let needle = Data(Array(key.utf8) + [0])
			guard let range = lowerVehicleData.range(of: needle) else { return nil }
			return (key, range.lowerBound)
		}.sorted { $0.recordNameOffset < $1.recordNameOffset }
		let aliasesByKey = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.aliases) })

		var profiles: [String: VehicleSoundProfile] = [:]
		for (index, record) in locatedRecords.enumerated() {
			let nextOffset = index + 1 < locatedRecords.count ? locatedRecords[index + 1].recordNameOffset : vehicleData.count
			let endOffset = min(nextOffset, record.recordNameOffset + recordStride)
			guard record.recordNameOffset < endOffset else { continue }

			let soundNames = vehicleData.wavNames(in: record.recordNameOffset..<endOffset)
			guard let profile = profile(from: soundNames) else { continue }
			profiles[record.key] = profile
			for alias in aliasesByKey[record.key] ?? [] where profiles[alias] == nil {
				profiles[alias] = profile
			}
		}
		VehicleSoundLog.log("Loaded \(profiles.count) vehicle sound profile keys from \(keys.count) car index entries")
		return profiles
	}

	private static func profile(from soundNames: [String]) -> VehicleSoundProfile? {
		let names = soundNames.map { $0.lowercased() }
		let vehicleNames = names.filter { !genericSoundNames.contains($0) }

		let startSound = vehicleNames.first { $0.hasSuffix("_on.wav") }
		let stopSound = vehicleNames.first { $0.hasSuffix("_off.wav") || $0.hasSuffix("_of.wav") }
		let npcLoopSound = vehicleNames.first { $0.contains("_npc") && $0.hasSuffix(".wav") }
		let idleLoopSound = vehicleNames.first { $0.hasSuffix("_0.wav") }
		let hornSound = existingSoundName(from: names.filter { $0.contains("horn") && $0.hasSuffix(".wav") }.map { Optional($0) })
		let brakeLoopSound = existingSoundName(from: [
			names.first { $0 == "brzdy_loop.wav" },
			names.first { $0 == "break.wav" },
			"09e_brzdy.wav"
		])

		var engineLoopSounds: [String] = []
		for suffix in ["_1.wav", "_2.wav", "_3.wav", "_4.wav", "_x.wav"] {
			if let sound = vehicleNames.first(where: { $0.hasSuffix(suffix) }) {
				engineLoopSounds.append(sound)
			}
		}

		guard startSound != nil || stopSound != nil || idleLoopSound != nil || !engineLoopSounds.isEmpty || hornSound != nil else {
			return nil
		}

		return VehicleSoundProfile(
			startSound: startSound,
			stopSound: stopSound,
			npcLoopSound: npcLoopSound,
			idleLoopSound: idleLoopSound,
			engineLoopSounds: engineLoopSounds,
			brakeLoopSound: brakeLoopSound,
			hornSound: hornSound
		)
	}

	private static func existingSoundName(from soundNames: [String?]) -> String? {
		for soundName in soundNames {
			guard let soundName = soundName else { continue }
			if VehicleSoundFiles.url(named: soundName) != nil {
				return soundName
			}
		}
		return nil
	}

}

private final class VehicleAudio {

	private let profile: VehicleSoundProfile
	private static var audioSourceCache: [String: SCNAudioSource] = [:]
	private static var soundURLCache: [String: URL] = [:]
	private static var missingSoundURLCache = Set<String>()
	private var isRunning = false
	private var currentLoopName: String?
	private var currentLoopPlayer: SCNAudioPlayer?
	private var currentBrakeLoopName: String?
	private var currentBrakeLoopPlayer: SCNAudioPlayer?
	private var oneShotPlayers: [SCNAudioPlayer] = []
	private var lastMissingSoundName: String?
	private var didLogInactiveUpdate = false

	init?(profile: VehicleSoundProfile?) {
		guard let profile = profile else { return nil }
		self.profile = profile
	}

	func setPaused(_ isPaused: Bool) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.setPaused(isPaused)
			}
			return
		}

		let players = ([currentLoopPlayer, currentBrakeLoopPlayer].compactMap { $0 }) + oneShotPlayers
		for player in players {
			guard let audioPlayerNode = player.audioNode as? AVAudioPlayerNode else { continue }
			guard audioPlayerNode.engine != nil else {
				if player === currentLoopPlayer {
					currentLoopPlayer = nil
					currentLoopName = nil
				}
				if player === currentBrakeLoopPlayer {
					currentBrakeLoopPlayer = nil
					currentBrakeLoopName = nil
				}
				oneShotPlayers.removeAll { $0 === player }
				continue
			}
			if isPaused {
				audioPlayerNode.pause()
			} else if !audioPlayerNode.isPlaying {
				audioPlayerNode.play()
			}
		}
	}

	func update(on node: SCNNode, speed: CGFloat, throttle: CGFloat, isBraking: Bool, isActive: Bool) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.update(on: node, speed: speed, throttle: throttle, isBraking: isBraking, isActive: isActive)
			}
			return
		}

		if !isActive {
			if !didLogInactiveUpdate {
				VehicleSoundLog.log("Vehicle audio update inactive")
				didLogInactiveUpdate = true
			}
			stop(on: node)
			return
		}
		didLogInactiveUpdate = false

		if !isRunning {
			isRunning = true
			VehicleSoundLog.log("Starting vehicle audio")
			playOneShot(profile.startSound, on: node)
		}

		playLoop(loopSoundName(for: speed, throttle: throttle), on: node)
		updateBrakeLoop(on: node, speed: speed, isBraking: isBraking)
	}

	func playHorn(on node: SCNNode) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.playHorn(on: node)
			}
			return
		}

		VehicleSoundLog.log("Playing vehicle horn '\(profile.hornSound ?? "nil")' on node '\(node.name ?? "<unnamed>")'")
		playOneShot(profile.hornSound, on: node)
	}

	private func stop(on node: SCNNode) {
		guard isRunning || currentLoopPlayer != nil || currentBrakeLoopPlayer != nil else { return }
		VehicleSoundLog.log("Stopping vehicle audio")
		stopLoop(on: node)
		stopBrakeLoop(on: node)
		if isRunning {
			playOneShot(profile.stopSound, on: node)
		}
		isRunning = false
	}

	private func loopSoundName(for speed: CGFloat, throttle: CGFloat) -> String? {
		if speed < 2, let idleLoopSound = profile.idleLoopSound {
			return idleLoopSound
		}
		guard !profile.engineLoopSounds.isEmpty else {
			return profile.npcLoopSound ?? profile.idleLoopSound
		}

		let accelerationBias: CGFloat = throttle > 0.05 ? 12 : 0
		let indexedSpeed = min(speed + accelerationBias, 100)
		let index = min(profile.engineLoopSounds.count - 1, max(0, Int(indexedSpeed / 25)))
		return profile.engineLoopSounds[index]
	}

	private func playLoop(_ soundName: String?, on node: SCNNode) {
		guard let soundName = soundName, currentLoopName != soundName else { return }
		stopLoop(on: node)
		guard let source = audioSource(named: soundName, loops: true) else { return }
		let player = SCNAudioPlayer(source: source)
		node.addAudioPlayer(player)
		currentLoopName = soundName
		currentLoopPlayer = player
	}

	private func updateBrakeLoop(on node: SCNNode, speed: CGFloat, isBraking: Bool) {
		guard isBraking, speed > 4, let brakeLoopSound = profile.brakeLoopSound else {
			stopBrakeLoop(on: node)
			return
		}
		playBrakeLoop(brakeLoopSound, on: node)
	}

	private func playBrakeLoop(_ soundName: String, on node: SCNNode) {
		guard currentBrakeLoopName != soundName else { return }
		stopBrakeLoop(on: node)
		guard let source = audioSource(named: soundName, loops: true) else { return }
		let player = SCNAudioPlayer(source: source)
		node.addAudioPlayer(player)
		currentBrakeLoopName = soundName
		currentBrakeLoopPlayer = player
		VehicleSoundLog.log("Playing vehicle brake loop '\(soundName)' on node '\(node.name ?? "<unnamed>")'")
	}

	private func stopBrakeLoop(on node: SCNNode) {
		if let currentBrakeLoopPlayer = currentBrakeLoopPlayer {
			node.removeAudioPlayer(currentBrakeLoopPlayer)
		}
		currentBrakeLoopPlayer = nil
		currentBrakeLoopName = nil
	}

	private func stopLoop(on node: SCNNode) {
		if let currentLoopPlayer = currentLoopPlayer {
			node.removeAudioPlayer(currentLoopPlayer)
		}
		currentLoopPlayer = nil
		currentLoopName = nil
	}

	private func playOneShot(_ soundName: String?, on node: SCNNode) {
		guard let source = audioSource(named: soundName, loops: false) else { return }
		let player = SCNAudioPlayer(source: source)
		player.didFinishPlayback = { [weak self, weak node, weak player] in
			guard let player = player else { return }
			DispatchQueue.main.async {
				node?.removeAudioPlayer(player)
				self?.oneShotPlayers.removeAll { $0 === player }
			}
		}
		node.addAudioPlayer(player)
		oneShotPlayers.append(player)
	}

	private func audioSource(named soundName: String?, loops: Bool) -> SCNAudioSource? {
		guard let soundName = soundName else { return nil }
		let cacheKey = "\(loops ? "loop" : "oneShot"):\(soundName.lowercased())"
		if let cachedSource = VehicleAudio.audioSourceCache[cacheKey] {
			return cachedSource
		}

		guard let url = soundURL(named: soundName) else {
			if lastMissingSoundName != soundName {
				VehicleSoundLog.log("Missing vehicle sound file '\(soundName)'")
				lastMissingSoundName = soundName
			}
			return nil
		}
		guard let source = SCNAudioSource(url: url) else {
			VehicleSoundLog.log("Unable to create SCNAudioSource for '\(soundName)' at \(url.path)")
			return nil
		}
		source.loops = loops
		source.isPositional = true
		source.shouldStream = false
		source.volume = loops ? 0.55 : 0.8
		VehicleAudio.audioSourceCache[cacheKey] = source
		return source
	}

	private func soundURL(named soundName: String) -> URL? {
		let cacheKey = soundName.lowercased()
		if let cachedURL = VehicleAudio.soundURLCache[cacheKey] {
			return cachedURL
		}
		if VehicleAudio.missingSoundURLCache.contains(cacheKey) {
			return nil
		}

		if let url = VehicleSoundFiles.url(named: soundName) {
			VehicleAudio.soundURLCache[cacheKey] = url
			return url
		}
		if soundName.lowercased().contains("pahant"),
		   let url = VehicleSoundFiles.url(named: soundName.replacingOccurrences(of: "pahant", with: "phant")) {
			VehicleSoundLog.log("Using corrected vehicle sound filename '\(url.lastPathComponent)' for table entry '\(soundName)'")
			VehicleAudio.soundURLCache[cacheKey] = url
			return url
		}

		VehicleAudio.missingSoundURLCache.insert(cacheKey)
		return nil
	}

}

private enum VehicleSoundFiles {

	private static let urlsByLowercaseName: [String: URL] = {
		let soundsURL = mainDirectory.appendingPathComponent("sounds")
		guard let contents = try? FileManager.default.contentsOfDirectory(
			at: soundsURL,
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		) else {
			VehicleSoundLog.log("Unable to index sounds directory at \(soundsURL.path)")
			return [:]
		}

		var urlsByName: [String: URL] = [:]
		for url in contents where url.pathExtension.lowercased() == "wav" {
			urlsByName[url.lastPathComponent.lowercased()] = url
		}
		VehicleSoundLog.log("Indexed \(urlsByName.count) sound files")
		return urlsByName
	}()

	static func url(named soundName: String) -> URL? {
		return urlsByLowercaseName[soundName.lowercased()]
	}

}

enum VehicleSoundLog {

	static func log(_ message: String) {
		print("[VehicleSound] \(message)")
	}

}

private extension String {

	var normalizedVehicleKey: String {
		return lowercased().replacingOccurrences(of: ".i3d", with: "")
	}

	var vehicleSoundCandidateKeys: [String] {
		let normalized = normalizedVehicleKey
		let strippedDigits = normalized.trimmingTrailingDigits()
		if strippedDigits.isEmpty || strippedDigits == normalized {
			return [normalized]
		}
		return [normalized, strippedDigits]
	}

	func trimmingTrailingDigits() -> String {
		var result = self
		while let last = result.last, last >= "0", last <= "9" {
			result.removeLast()
		}
		return result
	}

}

private extension Sequence where Element: Hashable {

	func removingDuplicates() -> [Element] {
		var seen = Set<Element>()
		return filter { seen.insert($0).inserted }
	}

}

private extension Data {

	func vehicleEntries() -> [(key: String, aliases: [String])] {
		let recordSize = 164
		let firstRecordOffset = 164
		guard count >= firstRecordOffset else { return [] }

		var entries: [(key: String, aliases: [String])] = []
		for offset in stride(from: firstRecordOffset, to: count, by: recordSize) {
			let key = zeroTerminatedString(at: offset, maxLength: 32).normalizedVehicleKey
			if !key.isEmpty {
				let modelName = zeroTerminatedString(at: offset + 32, maxLength: 32).normalizedVehicleKey
				let shadowModelName = zeroTerminatedString(at: offset + 64, maxLength: 32).normalizedVehicleKey
				let aliases = [modelName, shadowModelName].filter { !$0.isEmpty && $0 != key }.removingDuplicates()
				entries.append((key: key, aliases: aliases))
			}
		}
		var seen = Set<String>()
		return entries.filter { seen.insert($0.key).inserted }
	}

	func wavNames(in range: Range<Int>) -> [String] {
		let suffix = Array(".wav".utf8)
		var names: [String] = []
		var offset = range.lowerBound

		while offset + suffix.count <= range.upperBound {
			let matchesSuffix = suffix.indices.allSatisfy { index in
				UInt8(asciiLowercase: self[offset + index]) == suffix[index]
			}
			if matchesSuffix {
				var start = offset - 1
				while start >= range.lowerBound, self[start].isVehicleSoundNameByte {
					start -= 1
				}
				start += 1

				let end = offset + suffix.count
				if start < end,
				   let name = String(bytes: self[start..<end], encoding: .ascii),
				   name.count > 4 {
					names.append(name)
				}
				offset = end
			} else {
				offset += 1
			}
		}
		return names.removingDuplicates()
	}

	func zeroTerminatedString(at offset: Int, maxLength: Int) -> String {
		guard offset < count else { return "" }
		let end = Swift.min(offset + maxLength, count)
		var bytes: [UInt8] = []
		for index in offset..<end {
			let byte = self[index]
			guard byte != 0 else { break }
			bytes.append(byte)
		}
		return String(bytes: bytes, encoding: .ascii) ?? ""
	}

}

private extension UInt8 {

	init(asciiLowercase byte: UInt8) {
		if byte >= 65, byte <= 90 {
			self = byte + 32
		} else {
			self = byte
		}
	}

	var isVehicleSoundNameByte: Bool {
		return (self >= 48 && self <= 57) ||
			(self >= 65 && self <= 90) ||
			(self >= 97 && self <= 122) ||
			self == 95 ||
			self == 46
	}

}
