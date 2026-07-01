//
//  Scene.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/14/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import Foundation
import AVFoundation
import SceneKit
import SpriteKit

struct SceneError: Error { }

private func isNumberedSceneNodeName(_ candidateName: String, forBaseName baseName: String) -> Bool {
	let lowercasedCandidateName = candidateName.lowercased()
	guard lowercasedCandidateName.hasPrefix(baseName),
		  lowercasedCandidateName.count > baseName.count else {
		return false
	}
	let suffix = lowercasedCandidateName.dropFirst(baseName.count)
	return suffix.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
}

struct EnemyGroupMember {
	let actorId: Int
	weak var actor: SCNNode?
	var role: String?
}

struct EnemyGroup {
	var members: [EnemyGroupMember] = []
	weak var car: SCNNode?
	var carId: Int?
	var carParameter: Float?
}

final class DetectorHitWait {
	weak var script: Script?
	weak var node: SCNNode?

	init(script: Script, node: SCNNode) {
		self.script = script
		self.node = node
	}
}

enum SceneSection: UInt16 {
	case objects		= 0x4000
	case objDefs		= 0xae20
	case xyzs			= 0xae02
	case weather		= 0xaef0
	case noRainSectors	= 0xaef1
	case initScripts	= 0xae50
}

enum SceneSectionItem: UInt16 {
	case object			= 0x4010
	case objDef			= 0xae21
	case initDef		= 0xae03
	case initScript		= 0xae51
}

enum SceneObjectPart: UInt16 {
	case padding			= 0x0000
	case name			= 0x0010
	case position		= 0x0020
	case rotation		= 0x0022
	case globalPosition	= 0x002c
	case scale			= 0x002d
	case model			= 0x2012
	case type			= 0x4011
	case inSector		= 0x4020

	case unknown3		= 0x4033

	case light			= 0x4040
	case music			= 0x4050

	case sound			= 0x4060
	case occluder		= 0x4083

	case lightType		= 0x4090	// LMAP, LENS
	case lightMap		= 0x40a0
	case lens			= 0xb110

	case unknown4		= 0xb151

	case sector			= 0xb401
}

enum ObjectType: UInt32 {
	case none			= 0
	case light			= 2
	case camera			= 3
	case sound			= 4
	case object			= 6
	case model			= 9
	case occluder		= 12
	case music			= 14
}

enum ObjectDefinitionType: UInt32 {
	case none			= 0
	case ghost			= 1
	case player			= 2
	case car			= 4
	case script			= 5
	case door			= 6
	case trolley		= 8
	case unknown3		= 9		// object (villa)
	case traffic		= 12
	case pedestrians	= 18
	case empty			= 20
	case dog			= 21
	case plane			= 22
	case railRoute		= 24
	case pumpar			= 25
	case unknown26		= 26
	case enemy			= 27
	case unknown2		= 28
	case wagons			= 30
	case clock			= 34
	case physical		= 35
	case truck			= 36
}

extension ObjectDefinitionType {
	var hasDefaultHumanEnergy: Bool {
		switch self {
		case .player, .enemy, .pumpar:
			return true
		default:
			return false
		}
	}
}

enum LightType: UInt32 {
	/// bodové: světlo v prostoru svítí do všech stran
	case point = 1
	/// kuželové: simuluje se zastínění světla stínítkem
	case cone
	/// směrové: simuluje svit vzdálelého zdroje (např. slunce), světlo tedy svítí v celé scéně stále stejným směrem
	case directional
	/// ambientní: určuje celkové osvícení scény
	case ambient
	/// mlha: vzdálené objekty plynule přechází do určené barvy
	case fog
	case pointAmbient = 6
	case layeredFog = 8
}

enum EnvironmentLightKind {
	case ambient
	case fog
}

struct EnvironmentLight {
	let kind: EnvironmentLightKind
	let node: SCNNode
	let color: SKColor
	let power: CGFloat
	let near: CGFloat
	let far: CGFloat
	let sectorName: String?
}

struct PhysicalData {
	let weight: CGFloat
	let friction: CGFloat
}

struct ScriptEventBinding {
	let script: Script
	let eventId: String
}

struct CityMusicRegion {
	let node: SCNNode
	let musicId: String
}

struct Mission6RaceSettings {
	let lapCount: Int
	let participantCount: Int
	let circuitIndex: Int
	let participantSourceId: Int
	let playerParticipantVehicleRecordId: Int?
	let participantVehicleRecordIds: [Int]
	let participants: [Mission6RaceParticipant]
	let checkpoints: Mission6Checkpoints?
	let circuit: Mission6RaceCircuit?
	let nativeDifferenceName: String
	let nativeDifferenceFileName: String
	let nativeDifferenceExists: Bool
	let nativeRecordName: String
	let nativeRecordRelativePath: String
	let nativeRecordExists: Bool
	let participantSourceRecord: Mission6CarcyclopediaRecord?
	let participantSourceCarIndexRecord: Mission6CarIndexRecord?
	let participantSourceCollectionMask: UInt32?
	let participantSourceSelectedCollectionMask: UInt32?
	let participantProfiles: [Mission6RaceParticipantProfile]
}

struct Mission6RaceParticipant {
	let slotIndex: Int
	let vehicleRecordId: Int
	let isPlayer: Bool
	let nativeRequestedProfileIndex: Int
	let nativeProfileIndex: Int?
	let profileName: String?
	let vehicleClass: UInt32?
	let skillMultiplier: Float?
	let initialEnergy: Int
	let isActive: Bool
	let isFinished: Bool
	let finishTimeMilliseconds: Int?
	let finishOrder: Int?
}

struct Mission6RaceHudStats: Sendable {
	let elapsedMilliseconds: Int
	let lapElapsedMilliseconds: Int
	let bestLapMilliseconds: Int?
	let position: Int
	let participantCount: Int
	let currentLap: Int
	let lapCount: Int
	let countdownText: String?
}

private struct Mission6RaceAICar {
	weak var node: SCNNode?
	let slotIndex: Int
	var route: [SCNVector3]
	var segmentIndex: Int
	var segmentProgress: Float
	let speed: Float
	var completedLaps: Int
	var isFinished: Bool
}

final class Mission6RaceState: @unchecked Sendable {
	private static let countdownDurationMilliseconds = 3000
	private static let goMessageDurationMilliseconds = 1000
	private static let movedBoxRaceId = 0x1d97c
	private static let nativePlayerParticipantVehicleRecordId = 0x2b
	private static let nativeCollectionRecordType: UInt32 = 0x02000000
	private static let routeSearchLimit = 4096
	private static let routeNearestWindow = 12

	private struct RaceFrameRecord {
		weak var node: SCNNode?
		var raceId: Int
	}

	private struct RaceStatusBinding {
		weak var script: Script?
		var varId: Int
		var completion: (() -> Void)?
	}

	private struct RaceProgressState {
		let route: [Int]?
		let startPosition: SCNVector3
		let startForward: SCNVector3
		var lastRouteIndex: Int?
		var lastStartPlaneDistance: Float
		var maxDistanceFromStart: Float
		var completedLaps: Int
		var hasFinished: Bool
		var elapsedMilliseconds: Int
		var lapElapsedMilliseconds: Int
		var bestLapMilliseconds: Int?
	}

	private let lock = NSLock()
	private var settings: Mission6RaceSettings?
	private var statusValue: Int?
	private var hasStarted = false
	private var isRaceClockActive = false
	private var countdownRemainingMilliseconds: Int?
	private var goMessageRemainingMilliseconds = 0
	private var progressState: RaceProgressState?
	private var boxRecords: [ObjectIdentifier: RaceFrameRecord] = [:]
	private var destinationRecords: [ObjectIdentifier: RaceFrameRecord] = [:]
	private var boxOrder: [ObjectIdentifier] = []
	private var destinationOrder: [ObjectIdentifier] = []
	private var statusBindings: [RaceStatusBinding] = []

	func configure(
		lapCount: Int,
		participantCount: Int,
		circuitIndex: Int,
		participantSourceId: Int,
		sceneName: String,
		checkpoints: Mission6Checkpoints?,
		circuit: Mission6RaceCircuit?,
		participantSourceRecord: Mission6CarcyclopediaRecord?,
		participantSourceCarIndexRecord: Mission6CarIndexRecord?,
		participantProfiles: [Mission6RaceParticipantProfile]
	) {
		lock.lock()
		defer { lock.unlock() }
		let participantVehicleRecordIds = Self.participantVehicleRecordIds(
			participantCount: participantCount,
			participantSourceId: participantSourceId,
			participantSourceRecord: participantSourceRecord
		)
		let nativeDifferenceName = Self.nativeDifferenceName(sceneName: sceneName)
		let nativeDifferenceFileName = Self.nativeDifferenceFileName(name: nativeDifferenceName)
		let participantSourceCollectionMask = participantSourceCarIndexRecord?.nativeCollectionMask
		settings = Mission6RaceSettings(
			lapCount: lapCount,
			participantCount: participantCount,
			circuitIndex: circuitIndex,
			participantSourceId: participantSourceId,
			playerParticipantVehicleRecordId: participantCount > 0 ? Self.nativePlayerParticipantVehicleRecordId : nil,
			participantVehicleRecordIds: participantVehicleRecordIds,
			participants: Self.participants(
				vehicleRecordIds: participantVehicleRecordIds,
				participantProfiles: participantProfiles
			),
			checkpoints: checkpoints,
			circuit: circuit,
			nativeDifferenceName: nativeDifferenceName,
			nativeDifferenceFileName: nativeDifferenceFileName,
			nativeDifferenceExists: Self.nativeDifferenceExists(fileName: nativeDifferenceFileName),
			nativeRecordName: Self.nativeRecordName,
			nativeRecordRelativePath: Self.nativeRecordRelativePath,
			nativeRecordExists: Self.nativeRecordExists(relativePath: Self.nativeRecordRelativePath),
			participantSourceRecord: participantSourceRecord,
			participantSourceCarIndexRecord: participantSourceCarIndexRecord,
			participantSourceCollectionMask: participantSourceCollectionMask,
			participantSourceSelectedCollectionMask: participantSourceCollectionMask.map(Self.lowestSetBitMask),
			participantProfiles: participantProfiles
		)
		statusValue = nil
		hasStarted = false
		isRaceClockActive = false
		countdownRemainingMilliseconds = nil
		goMessageRemainingMilliseconds = 0
		progressState = nil
	}

	func start(script: Script, varId: Int, completion: @escaping () -> Void) {
		let value: Int?
		let shouldCompleteImmediately: Bool
		lock.lock()
		statusBindings = statusBindings.filter { $0.script != nil }
		value = settings == nil ? 3 : statusValue
		if settings != nil {
			hasStarted = true
			isRaceClockActive = false
			countdownRemainingMilliseconds = Self.countdownDurationMilliseconds
			goMessageRemainingMilliseconds = 0
		}
		shouldCompleteImmediately = value.map(Self.isTerminalStatusValue) == true
		if !shouldCompleteImmediately,
		   !statusBindings.contains(where: { $0.script === script && $0.varId == varId }) {
			statusBindings.append(RaceStatusBinding(script: script, varId: varId, completion: completion))
		}
		lock.unlock()
		if let value, shouldCompleteImmediately {
			script.setVariable(varId, to: Float(value), completion: shouldCompleteImmediately ? completion : nil)
		} else if shouldCompleteImmediately {
			completion()
		}
	}

	func setStatusValue(_ value: Int) {
		let bindings: [RaceStatusBinding]
		let isTerminalStatusValue: Bool
		lock.lock()
		statusValue = value
		statusBindings = statusBindings.filter { $0.script != nil }
		bindings = statusBindings
		isTerminalStatusValue = Self.isTerminalStatusValue(value)
		if isTerminalStatusValue {
			statusBindings.removeAll()
		}
		lock.unlock()
		for binding in bindings {
			binding.script?.setVariable(
				binding.varId,
				to: Float(value),
				completion: isTerminalStatusValue ? binding.completion : nil
			)
		}
	}

	func settingsSnapshot() -> Mission6RaceSettings? {
		lock.lock()
		defer { lock.unlock() }
		return settings
	}

	func isStartedSnapshot() -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return isRaceClockActive && statusValue == nil
	}

	func failIfRaceStarted() {
		lock.lock()
		let shouldFail = hasStarted && statusValue == nil
		lock.unlock()
		if shouldFail {
			setStatusValue(0)
		}
	}

	func prepareProgress(startPosition: SCNVector3, startForward: SCNVector3) {
		lock.lock()
		defer { lock.unlock() }
		let route = settings?.checkpoints.flatMap {
			Self.buildRoute(checkpoints: $0, startPosition: startPosition, startForward: startForward)
		}
		progressState = RaceProgressState(
			route: route,
			startPosition: startPosition,
			startForward: Self.horizontalNormalized(startForward),
			lastRouteIndex: route == nil ? nil : 0,
			lastStartPlaneDistance: Self.startPlaneDistance(position: startPosition, progressState: nil, startPosition: startPosition, startForward: startForward),
			maxDistanceFromStart: 0,
			completedLaps: 0,
			hasFinished: false,
			elapsedMilliseconds: 0,
			lapElapsedMilliseconds: 0,
			bestLapMilliseconds: nil
		)
	}

	func advanceCountdown(deltaTime: TimeInterval) {
		lock.lock()
		defer { lock.unlock() }
		guard hasStarted, statusValue == nil else { return }
		let elapsedDeltaMilliseconds = Self.elapsedMilliseconds(deltaTime: deltaTime)
		if let remainingMilliseconds = countdownRemainingMilliseconds {
			let nextRemainingMilliseconds = remainingMilliseconds - elapsedDeltaMilliseconds
			if nextRemainingMilliseconds <= 0 {
				countdownRemainingMilliseconds = nil
				isRaceClockActive = true
				goMessageRemainingMilliseconds = Self.goMessageDurationMilliseconds
			} else {
				countdownRemainingMilliseconds = nextRemainingMilliseconds
			}
			return
		}
		if goMessageRemainingMilliseconds > 0 {
			goMessageRemainingMilliseconds = max(0, goMessageRemainingMilliseconds - elapsedDeltaMilliseconds)
		}
	}

	func updatePlayerProgress(position: SCNVector3, deltaTime: TimeInterval) {
		lock.lock()
		guard isRaceClockActive,
			  statusValue == nil,
			  let settings,
			  var progressState,
			  !progressState.hasFinished,
			  settings.lapCount > 0 else {
			lock.unlock()
			return
		}
		let elapsedDeltaMilliseconds = Self.elapsedMilliseconds(deltaTime: deltaTime)
		progressState.elapsedMilliseconds += elapsedDeltaMilliseconds
		progressState.lapElapsedMilliseconds += elapsedDeltaMilliseconds
		let previousCompletedLaps = progressState.completedLaps
		if let route = progressState.route,
		   let lastRouteIndex = progressState.lastRouteIndex,
		   let checkpoints = settings.checkpoints,
		   let routeIndex = Self.nearestRouteIndex(
			to: position,
			checkpoints: checkpoints,
			route: route,
			lastRouteIndex: lastRouteIndex
		   ) {
			let routeCount = route.count
			let rawDelta = routeIndex - lastRouteIndex
			let forwardDelta = rawDelta < -(routeCount / 2) ? rawDelta + routeCount : rawDelta
			let delta = forwardDelta > routeCount / 2 ? forwardDelta - routeCount : forwardDelta
			if delta > 0, routeIndex < lastRouteIndex {
				progressState.completedLaps += 1
			} else if delta < 0, routeIndex > lastRouteIndex, progressState.completedLaps > 0 {
				progressState.completedLaps -= 1
			}
			progressState.lastRouteIndex = routeIndex
		} else if Self.updateStartGateProgress(position: position, progressState: &progressState) {
			progressState.completedLaps += 1
		}
		if progressState.completedLaps > previousCompletedLaps {
			let completedLapMilliseconds = progressState.lapElapsedMilliseconds
			if completedLapMilliseconds > 0 {
				if let bestLapMilliseconds = progressState.bestLapMilliseconds {
					progressState.bestLapMilliseconds = min(bestLapMilliseconds, completedLapMilliseconds)
				} else {
					progressState.bestLapMilliseconds = completedLapMilliseconds
				}
			}
			progressState.lapElapsedMilliseconds = 0
		}

		let didFinish = progressState.completedLaps >= settings.lapCount
		if didFinish {
			progressState.hasFinished = true
		}
		self.progressState = progressState
		lock.unlock()

		if didFinish {
			complete(nativePlayerFinishOrder: 1)
		}
	}

	func complete(nativePlayerFinishOrder: Int) {
		setStatusValue(Self.scriptStatusValue(forNativePlayerFinishOrder: nativePlayerFinishOrder))
	}

	func hudStats(opponentCompletedLaps: [Int]) -> Mission6RaceHudStats? {
		lock.lock()
		defer { lock.unlock() }
		guard hasStarted,
			  statusValue == nil,
			  let settings,
			  let progressState else {
			return nil
		}
		let completedLaps = min(progressState.completedLaps, max(0, settings.lapCount))
		let currentLap = settings.lapCount > 0 ? min(completedLaps + 1, settings.lapCount) : 0
		let position = 1 + opponentCompletedLaps.filter { $0 > progressState.completedLaps }.count
		return Mission6RaceHudStats(
			elapsedMilliseconds: progressState.elapsedMilliseconds,
			lapElapsedMilliseconds: progressState.lapElapsedMilliseconds,
			bestLapMilliseconds: progressState.bestLapMilliseconds,
			position: max(1, min(position, max(1, settings.participants.count))),
			participantCount: max(1, settings.participants.count),
			currentLap: currentLap,
			lapCount: max(0, settings.lapCount),
			countdownText: countdownText()
		)
	}

	func registerBox(_ node: SCNNode, raceId: Int) {
		lock.lock()
		defer { lock.unlock() }
		let key = ObjectIdentifier(node)
		if let record = boxRecords[key] {
			if record.raceId == Self.movedBoxRaceId {
				boxRecords[key]?.raceId = raceId
			}
			return
		}
		boxRecords[key] = RaceFrameRecord(node: node, raceId: raceId)
		boxOrder.append(key)
	}

	func registerDestination(_ node: SCNNode, raceId: Int) {
		lock.lock()
		defer { lock.unlock() }
		let key = ObjectIdentifier(node)
		if destinationRecords[key] != nil {
			return
		}
		destinationRecords[key] = RaceFrameRecord(node: node, raceId: raceId)
		destinationOrder.append(key)
	}

	func countBoxes(raceId: Int) -> Int {
		lock.lock()
		defer { lock.unlock() }
		return countRecords(&boxRecords, raceId: raceId)
	}

	func countDestinations(raceId: Int) -> Int {
		lock.lock()
		defer { lock.unlock() }
		return countRecords(&destinationRecords, raceId: raceId)
	}

	func moveBoxToDestination(raceId: Int) -> (box: SCNNode, destination: SCNNode)? {
		lock.lock()
		defer { lock.unlock() }
		pruneDeadRecords()
		guard let boxKey = boxOrder.last(where: { boxRecords[$0]?.raceId == raceId }),
			  let boxNode = boxRecords[boxKey]?.node,
			  let destinationKey = destinationOrder.last(where: { destinationRecords[$0]?.raceId == raceId }),
			  let destinationNode = destinationRecords[destinationKey]?.node else {
			return nil
		}
		boxRecords.removeValue(forKey: boxKey)
		boxOrder.removeAll { $0 == boxKey }
		return (boxNode, destinationNode)
	}

	func clear() {
		let bindings: [RaceStatusBinding]
		lock.lock()
		settings = nil
		statusValue = nil
		hasStarted = false
		isRaceClockActive = false
		countdownRemainingMilliseconds = nil
		goMessageRemainingMilliseconds = 0
		progressState = nil
		statusBindings = statusBindings.filter { $0.script != nil }
		bindings = statusBindings
		boxRecords.removeAll()
		destinationRecords.removeAll()
		boxOrder.removeAll()
		destinationOrder.removeAll()
		statusBindings.removeAll()
		lock.unlock()
		for binding in bindings {
			binding.script?.setVariable(binding.varId, to: 3, completion: binding.completion)
		}
	}

	private func countRecords(_ records: inout [ObjectIdentifier: RaceFrameRecord], raceId: Int) -> Int {
		records = records.filter { _, record in record.node != nil }
		return records.values.filter { $0.raceId == raceId }.count
	}

	private func pruneDeadRecords() {
		boxRecords = boxRecords.filter { _, record in record.node != nil }
		destinationRecords = destinationRecords.filter { _, record in record.node != nil }
		boxOrder = boxOrder.filter { boxRecords[$0] != nil }
		destinationOrder = destinationOrder.filter { destinationRecords[$0] != nil }
	}

	private func countdownText() -> String? {
		if let remainingMilliseconds = countdownRemainingMilliseconds {
			let second = max(1, min(3, Int(ceil(Double(remainingMilliseconds) / 1000))))
			return "\(second)"
		}
		if goMessageRemainingMilliseconds > 0 {
			return "GO"
		}
		return nil
	}

	private static func elapsedMilliseconds(deltaTime: TimeInterval) -> Int {
		return max(0, Int((deltaTime * 1000).rounded()))
	}

	private static func isTerminalStatusValue(_ value: Int) -> Bool {
		value == 0 || value == 1 || value == 2 || value == 3
	}

	private static func scriptStatusValue(forNativePlayerFinishOrder value: Int) -> Int {
		if value == 1 {
			return 1
		}
		return value == 0 ? 2 : 0
	}

	static let nativeRecordName = "recordrace"
	private static let nativeRecordRelativePath = "records/recordrace.rep"

	static func nativeDifferenceName(sceneName _: String) -> String {
		return "difrace"
	}

	static func nativeDifferenceFileName(name: String) -> String {
		let fileName = name.lowercased().hasSuffix(".chg") ? name : name + ".chg"
		return fileName
	}

	private static func nativeDifferenceExists(fileName: String) -> Bool {
		return FileManager.default.fileExists(
			atPath: mainDirectory.appendingPathComponent("diff/" + fileName).path
		)
	}

	private static func nativeRecordExists(relativePath: String) -> Bool {
		return FileManager.default.fileExists(
			atPath: mainDirectory.appendingPathComponent(relativePath).path
		)
	}

	private static func participantVehicleRecordIds(
		participantCount: Int,
		participantSourceId: Int,
		participantSourceRecord: Mission6CarcyclopediaRecord?
	) -> [Int] {
		guard participantCount > 0,
			  participantSourceId != -1,
			  participantSourceId != 0,
			  let participantSourceRecord,
			  participantSourceRecord.rawType != nativeCollectionRecordType else {
			return []
		}
		return (0..<participantCount).map { index in
			index == 0 ? nativePlayerParticipantVehicleRecordId : participantSourceId
		}
	}

	private static func lowestSetBitMask(in mask: UInt32) -> UInt32 {
		guard mask != 0 else { return 0 }
		return mask & (~mask &+ 1)
	}

	private static func participants(
		vehicleRecordIds: [Int],
		participantProfiles: [Mission6RaceParticipantProfile]
	) -> [Mission6RaceParticipant] {
		vehicleRecordIds.enumerated().map { slotIndex, vehicleRecordId in
			let profileIndex = slotIndex == 0 ? 0 : nil
			let profile = profileIndex.flatMap { index in
				participantProfiles.indices.contains(index) ? participantProfiles[index] : nil
			}
			return Mission6RaceParticipant(
				slotIndex: slotIndex,
				vehicleRecordId: vehicleRecordId,
				isPlayer: slotIndex == 0,
				nativeRequestedProfileIndex: slotIndex == 0 ? 0 : -1,
				nativeProfileIndex: profileIndex,
				profileName: profile?.name,
				vehicleClass: profile?.vehicleClass,
				skillMultiplier: profile?.skillMultiplier,
				initialEnergy: 200,
				isActive: true,
				isFinished: false,
				finishTimeMilliseconds: nil,
				finishOrder: nil
			)
		}
	}

	private static func buildRoute(
		checkpoints: Mission6Checkpoints,
		startPosition: SCNVector3,
		startForward: SCNVector3
	) -> [Int]? {
		guard let startIndex = nearestCheckpointIndex(to: startPosition, checkpoints: checkpoints) else { return nil }
		let normalizedStartForward = horizontalNormalized(startForward)
		let startCheckpoint = checkpoints.checkpoints[startIndex]
		guard let firstLink = startCheckpoint.links.max(by: { lhs, rhs in
			let lhsVector = checkpoints.checkpoints[Int(lhs.checkpointIndex)].position - startCheckpoint.position
			let rhsVector = checkpoints.checkpoints[Int(rhs.checkpointIndex)].position - startCheckpoint.position
			return dot(horizontalNormalized(lhsVector), normalizedStartForward) <
				dot(horizontalNormalized(rhsVector), normalizedStartForward)
		}) else {
			return nil
		}

		var route = [startIndex]
		var previousIndex = startIndex
		var currentIndex = Int(firstLink.checkpointIndex)
		var visited = Set([startIndex])
		for _ in 0..<routeSearchLimit {
			route.append(currentIndex)
			if currentIndex == startIndex {
				route.removeLast()
				return route.count > 3 ? route : nil
			}
			guard visited.insert(currentIndex).inserted else { return nil }
			let current = checkpoints.checkpoints[currentIndex]
			let incoming = current.position - checkpoints.checkpoints[previousIndex].position
			let candidates = current.links
				.map { Int($0.checkpointIndex) }
				.filter { $0 != previousIndex }
			guard let nextIndex = candidates.max(by: { lhs, rhs in
				let lhsVector = checkpoints.checkpoints[lhs].position - current.position
				let rhsVector = checkpoints.checkpoints[rhs].position - current.position
				return dot(horizontalNormalized(lhsVector), horizontalNormalized(incoming)) <
					dot(horizontalNormalized(rhsVector), horizontalNormalized(incoming))
			}) else {
				return nil
			}
			previousIndex = currentIndex
			currentIndex = nextIndex
		}
		return nil
	}

	private static func nearestRouteIndex(
		to position: SCNVector3,
		checkpoints: Mission6Checkpoints,
		route: [Int],
		lastRouteIndex: Int
	) -> Int? {
		let routeCount = route.count
		guard routeCount > 0 else { return nil }
		var bestRouteIndex = lastRouteIndex
		var bestDistance = Float.greatestFiniteMagnitude
		for offset in -routeNearestWindow...routeNearestWindow {
			let routeIndex = (lastRouteIndex + offset + routeCount) % routeCount
			let checkpointIndex = route[routeIndex]
			let distance = horizontalSquaredDistance(position, checkpoints.checkpoints[checkpointIndex].position)
			if distance < bestDistance {
				bestDistance = distance
				bestRouteIndex = routeIndex
			}
		}
		return bestRouteIndex
	}

	private static func nearestCheckpointIndex(to position: SCNVector3, checkpoints: Mission6Checkpoints) -> Int? {
		var bestIndex: Int?
		var bestDistance = Float.greatestFiniteMagnitude
		for checkpoint in checkpoints.checkpoints {
			let distance = horizontalSquaredDistance(position, checkpoint.position)
			if distance < bestDistance {
				bestDistance = distance
				bestIndex = checkpoint.index
			}
		}
		return bestIndex
	}

	private static func updateStartGateProgress(position: SCNVector3, progressState: inout RaceProgressState) -> Bool {
		let distanceFromStart = sqrt(horizontalSquaredDistance(position, progressState.startPosition))
		progressState.maxDistanceFromStart = max(progressState.maxDistanceFromStart, distanceFromStart)
		let currentPlaneDistance = startPlaneDistance(
			position: position,
			progressState: progressState,
			startPosition: progressState.startPosition,
			startForward: progressState.startForward
		)
		let didCrossPlane =
			(progressState.lastStartPlaneDistance < 0 && currentPlaneDistance >= 0) ||
			(progressState.lastStartPlaneDistance > 0 && currentPlaneDistance <= 0)
		progressState.lastStartPlaneDistance = currentPlaneDistance
		guard didCrossPlane, progressState.maxDistanceFromStart > 300 else { return false }
		progressState.maxDistanceFromStart = 0
		return true
	}

	private static func startPlaneDistance(
		position: SCNVector3,
		progressState: RaceProgressState?,
		startPosition: SCNVector3,
		startForward: SCNVector3
	) -> Float {
		let forward = progressState?.startForward ?? horizontalNormalized(startForward)
		return dot(position - startPosition, forward)
	}

	private static func horizontalNormalized(_ vector: SCNVector3) -> SCNVector3 {
		let x = Float(vector.x)
		let z = Float(vector.z)
		let length = sqrt(x * x + z * z)
		guard length > 0.0001 else { return SCNVector3(x: 0, y: 0, z: 1) }
		return SCNVector3(x: SCNFloat(x / length), y: 0, z: SCNFloat(z / length))
	}

	private static func dot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		Float(lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z)
	}

	private static func horizontalSquaredDistance(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		let dx = Float(lhs.x - rhs.x)
		let dz = Float(lhs.z - rhs.z)
		return dx * dx + dz * dz
	}
}

private final class ActiveAudioPlayer {
	let node: SCNNode
	let player: SCNAudioPlayer
	let completion: (() -> Void)?
	var fallbackWorkItem: DispatchWorkItem?
	var fallbackDeadline: TimeInterval?
	var fallbackRemaining: TimeInterval?

	init(node: SCNNode, player: SCNAudioPlayer, completion: (() -> Void)?) {
		self.node = node
		self.player = player
		self.completion = completion
	}
}

private final class ScheduledRecordSound {
	let url: URL
	weak var node: SCNNode?
	let fallbackNode: SCNNode
	let soundName: String
	let fileName: String
	let eventTime: TimeInterval
	let subtitleText: String?
	var workItem: DispatchWorkItem?
	var deadline: TimeInterval?
	var remaining: TimeInterval
	var didPlay = false

	init(
		url: URL,
		node: SCNNode?,
		fallbackNode: SCNNode,
		soundName: String,
		fileName: String,
		eventTime: TimeInterval,
		subtitleText: String? = nil
	) {
		self.url = url
		self.node = node
		self.fallbackNode = fallbackNode
		self.soundName = soundName
		self.fileName = fileName
		self.eventTime = eventTime
		self.subtitleText = subtitleText
		self.remaining = eventTime
	}
}

private final class ScheduledRecordEvent {
	let recordName: String
	let event: RecordTimedEvent
	var workItem: DispatchWorkItem?
	var deadline: TimeInterval?
	var remaining: TimeInterval
	var didDispatch = false

	init(recordName: String, event: RecordTimedEvent) {
		self.recordName = recordName
		self.event = event
		self.remaining = event.time
	}
}

private struct RecordSoundBinding {
	let fileName: String
	let url: URL
	let node: SCNNode
}

private final class ActiveRecordPlayback {
	let name: String
	let duration: TimeInterval
	var workItem: DispatchWorkItem?
	var deadline: TimeInterval?
	var remaining: TimeInterval

	init(name: String, duration: TimeInterval) {
		self.name = name
		self.duration = duration
		self.remaining = duration
	}
}

private struct RecordAnimationPlayback {
	let animation: RecordAnimation
	let animationPath: String
	let targetNode: SCNNode
	let binding: RecordModelBinding?
	let matchEvent: RecordAnimationEvent
	let source: String
	let trackId: Int
	let startTime: TimeInterval
	let duration: TimeInterval
	let positionDistance: SCNFloat
	let orientationDistance: SCNFloat
	let matches: Int
}

private final class RecordTransformPlayback {
	let targetNode: SCNNode
	var eventByKey: [String: RecordAnimationEvent] = [:]
	var sources = Set<String>()

	init(targetNode: SCNNode) {
		self.targetNode = targetNode
	}

	func append(events: [RecordAnimationEvent], source: String) {
		for event in events {
			let key = [
				String(event.animationId),
				String(event.trackId),
				String(format: "%.3f", event.time),
				String(event.packedTrackId)
			].joined(separator: ":")
			eventByKey[key] = event
		}
		sources.insert(source)
	}

	var sortedEvents: [RecordAnimationEvent] {
		return eventByKey.values.sorted {
			if $0.time == $1.time {
				return $0.animationId < $1.animationId
			}
			return $0.time < $1.time
		}
	}
}

private struct RecordAnimationTargetMatch {
	let node: SCNNode
	let binding: RecordModelBinding?
	let event: RecordAnimationEvent
	let timingEvents: [RecordAnimationEvent]
	let source: String
	let trackId: Int
	let positionDistance: SCNFloat
	let orientationDistance: SCNFloat
}

private final class RecordAnimationLookup {
	struct BindingNode {
		let index: Int
		let binding: RecordModelBinding
		let node: SCNNode
	}

	let record: Record
	let bindingNodes: [BindingNode]
	let targetLinksByGroup: [Int: [RecordTargetLink]]
	let animationEventsByAnimationId: [Int: [RecordAnimationEvent]]
	let animationEventsByTrackId: [Int: [RecordAnimationEvent]]
	private let candidates: [SCNNode]
	private var nodesByName: [String: SCNNode] = [:]
	private var missingNodeNames = Set<String>()
	private var bindingsByNodeName: [String: RecordModelBinding] = [:]
	private var skeletonMatchCache: [String: [ObjectIdentifier: Int]] = [:]

	init(record: Record, recordRoots: [SCNNode]) {
		self.record = record
		let candidates = recordRoots.flatMap { [$0] + $0.flattenedChildNodes }
		self.candidates = candidates
		self.targetLinksByGroup = Dictionary(grouping: record.targetLinks, by: \.groupId)
		self.animationEventsByAnimationId = Dictionary(grouping: record.animationEvents, by: \.animationId)
		self.animationEventsByTrackId = Dictionary(grouping: record.animationEvents, by: \.trackId)

		var resolvedBindingNodes: [BindingNode] = []
		resolvedBindingNodes.reserveCapacity(record.modelBindings.count)
		for (index, binding) in record.modelBindings.enumerated() {
			guard let node = Self.node(named: binding.sourceName, in: candidates) else { continue }
			resolvedBindingNodes.append(BindingNode(index: index, binding: binding, node: node))
		}
		self.bindingNodes = resolvedBindingNodes

		for bindingNode in resolvedBindingNodes {
			guard let nodeName = bindingNode.node.name?.lowercased() else { continue }
			bindingsByNodeName[nodeName] = bindingNode.binding
		}
	}

	func node(named recordName: String) -> SCNNode? {
		let key = recordName.lowercased()
		if let node = nodesByName[key] {
			return node
		}
		if missingNodeNames.contains(key) {
			return nil
		}
		guard let node = Self.node(named: recordName, in: candidates) else {
			missingNodeNames.insert(key)
			return nil
		}
		nodesByName[key] = node
		return node
	}

	func binding(for node: SCNNode) -> RecordModelBinding? {
		guard let nodeName = node.name?.lowercased() else { return nil }
		if let binding = bindingsByNodeName[nodeName] {
			return binding
		}
		let binding = record.modelBindings.first { binding in
			let sourceName = binding.sourceName.lowercased()
			return sourceName == nodeName ||
				(nodeName.count >= 16 && nodeName.hasPrefix(sourceName)) ||
				(sourceName.count >= 16 && sourceName.hasPrefix(nodeName))
		}
		bindingsByNodeName[nodeName] = binding
		return binding
	}

	func skeletonMatchCount(
		for animationPath: String,
		in node: SCNNode,
		resolver: (String, SCNNode) throws -> (node: SCNNode, matches: Int)
	) -> Int {
		let nodeIdentifier = ObjectIdentifier(node)
		if let cachedMatches = skeletonMatchCache[animationPath]?[nodeIdentifier] {
			return cachedMatches
		}
		let matches = (try? resolver(animationPath, node).matches) ?? 0
		var matchesByNode = skeletonMatchCache[animationPath] ?? [:]
		matchesByNode[nodeIdentifier] = matches
		skeletonMatchCache[animationPath] = matchesByNode
		return matches
	}

	private static func node(named name: String, in candidates: [SCNNode]) -> SCNNode? {
		if let dottedNode = dottedNode(named: name, in: candidates) {
			return dottedNode
		}
		if let exactNode = candidates.first(where: { $0.name == name }) {
			return exactNode
		}

		let lowercasedName = name.lowercased()
		if let caseInsensitiveNode = candidates.first(where: { $0.name?.lowercased() == lowercasedName }) {
			return caseInsensitiveNode
		}

		let numberedMatches = candidates.filter { node in
			guard let nodeName = node.name else { return false }
			return isNumberedSceneNodeName(nodeName, forBaseName: lowercasedName)
		}
		if numberedMatches.count == 1 {
			return numberedMatches[0]
		}

		guard name.count >= 16 else { return nil }
		return candidates.first { node in
			node.name?.lowercased().hasPrefix(lowercasedName) == true
		}
	}

	private static func dottedNode(named name: String, in candidates: [SCNNode]) -> SCNNode? {
		let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
		guard parts.count == 2 else { return nil }

		let parentName = parts[0]
		let childName = parts[1]
		for parentNode in candidates where recordNodeName(parentNode.name, matches: parentName) {
			if let childNode = parentNode.mafiaChildNode(named: childName, recursively: true) {
				return childNode
			}
		}
		return nil
	}

	private static func recordNodeName(_ candidate: String?, matches name: String) -> Bool {
		guard let candidate = candidate?.lowercased(),
			  !candidate.isEmpty else {
			return false
		}
		let name = name.lowercased()
		return candidate == name ||
			(candidate.count >= 16 && candidate.hasPrefix(name)) ||
			(name.count >= 16 && name.hasPrefix(candidate))
	}
}

private struct PendingRecordLoad {
	let full: Bool
	let completion: @Sendable (Result<Record, Swift.Error>) -> Void
}

private struct PendingDifferenceLoad {
	let completion: @Sendable (Result<DifferenceFile, Swift.Error>) -> Void
}

private final class PendingDifferenceWaitState: @unchecked Sendable {
	private let lock = NSLock()
	private var remainingLoads: Int
	private var firstError: Swift.Error?
	private let completion: @Sendable (Result<Void, Swift.Error>) -> Void

	init(remainingLoads: Int, completion: @escaping @Sendable (Result<Void, Swift.Error>) -> Void) {
		self.remainingLoads = remainingLoads
		self.completion = completion
	}

	func finishOne(_ result: Result<DifferenceFile, Swift.Error>) {
		lock.lock()
		if case .failure(let error) = result, firstError == nil {
			firstError = error
		}
		remainingLoads -= 1
		let shouldFinish = remainingLoads == 0
		let error = firstError
		lock.unlock()

		guard shouldFinish else { return }
		if let error = error {
			completion(.failure(error))
		} else {
			completion(.success(()))
		}
	}
}

private let recordCameraNearPlane: Double = 0.01
private let recordFaceAnimationTimeTolerance: TimeInterval = 0.35

struct TrafficCarDefinition {
	let modelName: String
	let density: Float
	let colors: UInt32
	let policeFlags: UInt16
	let gangsterFlags: UInt16

	var isPolice: Bool {
		return policeFlags != 0
	}

	var originalPoliceTrafficByte: UInt8 {
		return UInt8(truncatingIfNeeded: policeFlags)
	}

	var originalAuxiliaryTrafficByte: UInt8 {
		return UInt8(truncatingIfNeeded: policeFlags >> 8)
	}

	var originalAlternateTrafficByte: UInt8 {
		guard originalPoliceTrafficByte == 0 else { return 0 }
		return UInt8(truncatingIfNeeded: gangsterFlags)
	}

	var originalTrafficColorARGB: UInt32 {
		if originalPoliceTrafficByte != 0 {
			return 0xff009fff
		}
		if originalAlternateTrafficByte != 0 {
			return 0xffff9f00
		}
		return 0xffb0e0b0
	}

	init(modelName: String, density: Float, colors: UInt32, policeFlags: UInt16, gangsterFlags: UInt16) {
		self.modelName = modelName
		self.density = density
		self.colors = colors
		self.policeFlags = policeFlags
		self.gangsterFlags = gangsterFlags
	}

	init(modelName: String, density: Float, colors: UInt32, isPolice: Bool, gangsterFlags: UInt16) {
		self.init(
			modelName: modelName,
			density: density,
			colors: colors,
			policeFlags: isPolice ? 1 : 0,
			gangsterFlags: gangsterFlags
		)
	}
}

struct TrafficSettings {
	let outerRadiusToHide: Float
	let innerRadiusForGeneration: Float
	let outerRadiusForGeneration: Float
	let generatedCarCount: Int
	let cars: [TrafficCarDefinition]
}

final class Scene: @unchecked Sendable {

	weak var game: Game!
	let name: String
	let rootNode = SCNNode()
	var playerNode: SCNNode?

	var initScripts: [String: Script] = [:]
	var scripts: [String: Script] = [:]

	var sounds: [SCNNode: Sound] = [:]
	var enemyGroups: [Int: EnemyGroup] = [:]
	var detectorHitWaits: [DetectorHitWait] = []
	let mission6RaceState = Mission6RaceState()
	var humanVehicleOwners: [ObjectIdentifier: SCNNode] = [:]
	var unusableCarIds = Set<ObjectIdentifier>()
	var actions: [Action] = []
	var environmentLights: [EnvironmentLight] = []
	var trafficSettings: TrafficSettings?
	var compassNode: SCNNode?
	var playerFireEvent: ScriptEventBinding?
	var playerHornEvent: ScriptEventBinding?
	private var didStartScripts = false
	private var lastActionAnimationId = 0
	private var lastActionAnimationEndTime: TimeInterval = 0
	private let nodesByNameLock = NSLock()
	private let weaponsLock = NSLock()
	private var weaponsByOwner: [ObjectIdentifier: [Weapon]] = [:]
	private var nodesByName: [String: SCNNode] = [:]
	private var nodesByNativeSceneObjectIndex: [Int: SCNNode] = [:]
	private var missingNodeNames = Set<String>()
	private var mission6RaceSpawnedCars: [SCNNode] = []
	private var mission6RaceAICars: [Mission6RaceAICar] = []
	private var mission6RaceCircuitDebugNode: SCNNode?

	func weapons(for owner: SCNNode) -> [Weapon] {
		weaponsLock.lock()
		defer { weaponsLock.unlock() }
		return weaponsByOwner[ObjectIdentifier(owner)] ?? []
	}

	func appendWeapon(_ weapon: Weapon, for owner: SCNNode) {
		weaponsLock.lock()
		defer { weaponsLock.unlock() }
		weaponsByOwner[ObjectIdentifier(owner), default: []].append(weapon)
	}

	func setWeapons(_ weapons: [Weapon], for owner: SCNNode) {
		weaponsLock.lock()
		defer { weaponsLock.unlock() }
		weaponsByOwner[ObjectIdentifier(owner)] = weapons
	}

	func updateWeapons(for owner: SCNNode, _ update: (inout [Weapon]) -> Void) {
		weaponsLock.lock()
		defer { weaponsLock.unlock() }
		update(&weaponsByOwner[ObjectIdentifier(owner), default: []])
	}

	@discardableResult
	func updateWeaponsIfPresent(for owner: SCNNode, _ update: (inout [Weapon]) -> Void) -> Bool {
		weaponsLock.lock()
		defer { weaponsLock.unlock() }
		let ownerKey = ObjectIdentifier(owner)
		guard weaponsByOwner[ownerKey] != nil else { return false }
		update(&weaponsByOwner[ownerKey]!)
		return true
	}
	private var pendingDoorDataByName: [String: DoorData] = [:]
	private var pendingPhysicalDataByName: [String: PhysicalData] = [:]
	private var pendingScriptStringsByName: [String: String] = [:]
	private var pendingObjectTypesByName: [String: ObjectDefinitionType] = [:]
	private var pendingHumanEnergyByName: [String: Float] = [:]
	private var pendingPlayerNodeName: String?
	private var activeAudioPlayers: [ObjectIdentifier: ActiveAudioPlayer] = [:]
	private(set) var cityMusicRegions: [CityMusicRegion] = []
	private var loadedDifferenceFiles: [String: DifferenceFile] = [:]
	private let differenceLoadQueue = DispatchQueue(label: "difference.load", qos: .userInitiated)
	private var pendingDifferenceLoads: [String: [PendingDifferenceLoad]] = [:]
	private var loadedDifferenceScriptNames = Set<String>()
	private var replacedScriptsByDifferenceName: [String: Script] = [:]
	private var loadedRecords: [String: Record] = [:]
	private let recordLoadQueue = DispatchQueue(label: "record.load", qos: .userInitiated)
	private var pendingRecordLoads: [String: [PendingRecordLoad]] = [:]
	private var activeRecordNames = Set<String>()
	private var activeRecordPlaybacks: [String: ActiveRecordPlayback] = [:]
	private var activeRecordPropNodes: [SCNNode] = []
	private var activeRecordTransformRestores: [ObjectIdentifier: (node: SCNNode, transform: SCNMatrix4)] = [:]
	private var activeRecordEventSchedules: [ScheduledRecordEvent] = []
	private var activeRecordEventScriptNames = Set<String>()
	private let filmMusicStreamsLock = NSLock()
	private var filmMusicStreams: [Int: ScriptMusicStream] = [:]
	private var nativeSceneObjectCount = 0
	private var nextFilmMusicSlot = 0
	private var recordCameraRestore: (
		parent: SCNNode?,
		transform: SCNMatrix4,
		cameraPosition: SCNVector3,
		cameraEulerAngles: SCNVector3,
		cameraFieldOfView: CGFloat?,
		cameraNearPlane: Double?
	)?
	private var cutscenePausedScriptIds = Set<ObjectIdentifier>()
	private var isCutsceneSkipRequested = false
	private var activeRecordSoundSchedules: [ScheduledRecordSound] = []
	private var isAudioPaused = false

	var objectives: [Int] = [] {
		didSet {
			let objectives = objectives
			DispatchQueue.main.async {
				self.game?.hud?.updateObjectives(objectives)
			}
		}
	}
	var pressedJump = false

	init(named name: String) throws {
		self.name = name
		let url = mainDirectory.appendingPathComponent(name + "/scene2.bin")

		guard let stream = InputStream(url: url) else { throw SceneError() }
		stream.open()

		let header: Int16 = try stream.read()
		guard header == 0x4c53 else { throw SceneError() }

		let _fileSize: Int32 = try stream.read()
		let fileSize = Int(_fileSize)

		let _: UInt16 = try stream.read() // version
		let commentLength: UInt32 = try stream.read()
		let sceneDataOffset = 72 + Int(commentLength)
		guard sceneDataOffset <= fileSize else { throw SceneError() }
		stream.currentOffset = sceneDataOffset

		while stream.currentOffset < fileSize {
			try readSection(stream: stream)
		}

		stream.close()
	}

	// swiftlint:disable:next function_body_length
	private func readSection(stream: InputStream) throws {
//		let scene = self

		let startOffset = stream.currentOffset

		let secSgn = try SceneSection(forcedRawValue: stream.read())
	//	guard secSgn == 44576 else { throw SceneError.file }

		let _secSize: UInt32 = try stream.read()
		let secSize = Int(_secSize)
		let sectionEndOffset = startOffset + secSize

		switch secSgn {
		case .weather, .noRainSectors:
			stream.currentOffset = sectionEndOffset
			return

		case .objects, .objDefs, .xyzs, .initScripts:
			break
		}

		while stream.currentOffset < sectionEndOffset {
			try autoreleasepool {

				let objectStartOffset = stream.currentOffset

				let objSgn = try SceneSectionItem(forcedRawValue: stream.read())

		//		print("--- \(objSgn)")

				let _objSize: UInt32 = try stream.read()
				let objSize = Int(_objSize)

				switch objSgn {
				case .object:

					let objectNode = SCNNode()
					objectNode.nativeSceneObjectIndex = nativeSceneObjectCount
					nativeSceneObjectCount += 1
					var type: ObjectType = .object
					var pendingMusicAreaBounds: AreaBounds?

					while stream.currentOffset < (objectStartOffset + objSize) {
						let partSgn = try SceneObjectPart(forcedRawValue: stream.read())

		//				print("------ \(partSgn)")

						let _partSize: UInt32 = try stream.read()
						let partSize = Int(_partSize)
						let partEndOffset = stream.currentOffset + partSize - 6

						switch partSgn {
						case .padding:
							stream.currentOffset += partSize - 6

						case .name:
							let str: String = try stream.read(maxLength: partSize - 6)
							objectNode.name = str

						case .position:
							let _ = try SCNVector3(stream: stream)
		//					objectNode.position = position

						case .rotation:
							let rotation = try SCNQuaternion(stream: stream)
							objectNode.orientation = rotation

						case .globalPosition:
							let globalPosition = try SCNVector3(stream: stream)
							objectNode.position = globalPosition

						case .scale:
							let scale = try SCNVector3(stream: stream)
							objectNode.scale = scale

						case .model:
							var str: String = try stream.read(maxLength: partSize - 6)
							str = str.lowercased().replacingOccurrences(of: ".i3d", with: "")
							objectNode.vehicleModelName = str
							try loadModel(named: "models/" + str, node: objectNode)

						case .type:
							let rawType: UInt32 = try stream.read()
							type = ObjectType(rawValue: rawType) ?? .object

						case .inSector:
							stream.currentOffset += 6
							let _: String = try stream.read(maxLength: partSize - 12)
		//					print("--------- \(str)")

						case .unknown3:
							stream.currentOffset += partSize - 6

						case .light:
							try readLight(stream: stream, partSize: partSize, objectNode: objectNode)

						case .music:
							let min = try SCNVector3(stream: stream)
							let max = try SCNVector3(stream: stream)
							objectNode.areaBounds = AreaBounds(min: min, max: max)

						case .sound:
							self.sounds[objectNode] = try Sound(scene: self, node: objectNode, stream: stream, partSize: partSize)

						case .occluder:
							stream.currentOffset += partSize - 6

						case .lightType:
							let _: String = try stream.read(maxLength: partSize - 6)
		//					print("lightType: (\(str))")

						case .lightMap:
							stream.currentOffset += partSize - 6
	//						let lightData = try stream.read(maxLength: partSize - 6)
	//						print("lightMap:", lightData.map({ String(format: "%02x", $0) }).joined())

						case .lens:
							stream.currentOffset += partSize - 6

						case .unknown4:
							if type == .music, let areaBounds = try readAreaBounds(stream: stream, endOffset: partEndOffset) {
								pendingMusicAreaBounds = areaBounds
							}

						case .sector:
							stream.currentOffset += partSize - 6
						}

						stream.currentOffset = partEndOffset
					}

					if type != .none && type != .model && type != .object && type != .camera && type != .light {
		//				print("OBJECT TYPE: \(type) \(objectNode.name)")

						if objectNode.name == "target" {
							let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
							box.firstMaterial = SCNMaterial()
							box.firstMaterial?.diffuse.contents = SKColor.red
							box.firstMaterial?.cullMode = .front
							objectNode.geometry = box
						} else {
							let box = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)
							box.firstMaterial = SCNMaterial()

							switch type {
							case .none:
								box.firstMaterial?.diffuse.contents = SKColor.red
							case .light:
								box.firstMaterial?.diffuse.contents = SKColor.yellow
							case .sound:
								box.firstMaterial?.diffuse.contents = SKColor.magenta
							case .music:
								box.firstMaterial?.diffuse.contents = SKColor.cyan
							case .occluder:
								box.firstMaterial?.diffuse.contents = SKColor.brown
							case .camera:
								box.firstMaterial?.diffuse.contents = SKColor.orange
							case .object:
								box.firstMaterial?.diffuse.contents = SKColor.red
							default:
								print("type:", type.rawValue)
								box.firstMaterial?.diffuse.contents = SKColor.green
							}

							box.firstMaterial?.cullMode = .front
							box.firstMaterial?.transparency = 0.2
							objectNode.geometry = box
						}
					}

					if let pendingMusicAreaBounds {
						objectNode.areaBounds = pendingMusicAreaBounds
					}
					if type == .music,
					   let musicId = Self.cityMusicId(from: objectNode.name),
					   objectNode.areaBounds != nil {
						cityMusicRegions.append(CityMusicRegion(node: objectNode, musicId: musicId))
					}

					objectNode.recordSourcePosition = objectNode.position
					objectNode.recordSourceOrientationVector = SCNVector3(
						x: -objectNode.orientation.w,
						y: objectNode.orientation.x,
						z: objectNode.orientation.y
					)
					self.rootNode.addChildNode(objectNode)
					registerNodeTree(objectNode)

				case .objDef:
					var name: String = ""
					var node: SCNNode?
					var type: ObjectDefinitionType = .empty

					while stream.currentOffset < (objectStartOffset + objSize) {
						let partSgn: UInt16 = try stream.read()

						let _partSize: UInt32 = try stream.read()
						let partSize = Int(_partSize)
						let partEndOffset = stream.currentOffset + partSize - 6

						switch partSgn {
							case 0xae23: // name
								name = try stream.read(maxLength: partSize - 6)
								node = self.node(named: name)
								if let node = node {
									applyObjectDefinitionType(type, to: node)
								} else if type != .empty {
									pendingObjectTypesByName[name] = type
								}

							case 0xae22: // type
								type = try ObjectDefinitionType(forcedRawValue: stream.read())
								if let node = node {
									applyObjectDefinitionType(type, to: node)
								} else if !name.isEmpty {
									pendingObjectTypesByName[name] = type
								}

						case 0xae24: // props

							switch type {
							case .ghost:
								stream.currentOffset += partSize - 6

							case .player:
								stream.currentOffset += 1

								let _: UInt32 = try stream.read()						// 1		behavior
								let _: UInt32 = try stream.read()						// 3		voice
								let _: Float = try stream.read()						// 0.7		strength
								let energy: Float = try stream.read()					// 200		energy
								let _: Float = try stream.read()						// 40		energy hand r
								let _: Float = try stream.read()						// 40		energy hand l
								let _: Float = try stream.read()						// 40		energy leg l
								let _: Float = try stream.read()						// 40		energy leg r
								let _: Float = try stream.read()						// 0.7		reactions
								let _: Float = try stream.read()						// 1		speed
								let _: Float = try stream.read()						// 0.6		aggresivity
								let _: Float = try stream.read()						// 0.8		intelligence
								let _: Float = try stream.read()						// 1		shooting
								let _: Float = try stream.read()						// 1		signt
								let _: Float = try stream.read()						// 1		hearing
								let _: Float = try stream.read()						// 0.8		driving
								let _: Float = try stream.read()						// 80		mass
								let _: Float = try stream.read()						// 0.5		behavior 2

								print("Player \(name) energy: \(energy)")
								if let node = node {
									node.humanEnergy = energy
									self.playerNode = node
									playDefaultHumanIdleAnimation(in: node)
									print("== Player Node from object definition: \(name), node=\(node.name ?? "<unnamed>"), energy=\(energy), position=\(node.worldPosition)")
								} else if !name.isEmpty {
									pendingHumanEnergyByName[name] = energy
									pendingPlayerNodeName = name
									print("== Pending Player Node: \(name), energy=\(energy)")
								} else {
									print("== Player Node missing name in object definition, energy=\(energy)")
								}

							case .car:
								stream.currentOffset += partSize - 6

							case .script:
								stream.currentOffset += 10

								let scriptLength: UInt32 = try stream.read()
								let scriptStr: String = try stream.read(maxLength: Int(scriptLength))
								//print("[SCRIPT \(name)]:", scriptStr)
								if let node = node {
									attachScript(scriptStr, named: name, to: node)
								} else {
									pendingScriptStringsByName[name] = scriptStr
								}

							case .door:
								let doorData = try readDoorData(stream: stream)
								if let node = node {
									attachDoor(doorData, to: node)
								} else {
									pendingDoorDataByName[name] = doorData
								}

							case .trolley:
								stream.currentOffset += 1

								let _: UInt32 = try stream.read()						// numOfLinkedWagons / 0
								let _: Float = try stream.read()						// distanceBetweenWagons / 17
								let _: Float = try stream.read()						// 8 (const)
								let _: Float = try stream.read()						// maxSpeed / 9.7222
								let _: Float = try stream.read()						// 1 (const)
								let _: Float = try stream.read()						// 10000 (const)

							case .unknown3:
								stream.currentOffset += partSize - 6

							case .traffic:

								let _: UInt32 = try stream.read()						// 5 (const)
								let outerRadiusToHide: Float = try stream.read()
								let innerRadiusForGeneration: Float = try stream.read()
								let outerRadiusForGeneration: Float = try stream.read()
								let numOfGeneratedCars: UInt32 = try stream.read()
								let numOfCarsInDatabase: UInt32 = try stream.read()
								var cars: [TrafficCarDefinition] = []

								for _ in 0 ..< numOfCarsInDatabase {
									let modelName: String = try stream.read(maxLength: 20)

									let modelDensity: Float = try stream.read()

									let colors: UInt32 = try stream.read()

									let isPolice: UInt16 = try stream.read()

									let gangsterFlags: UInt16 = try stream.read()
									cars.append(TrafficCarDefinition(
										modelName: modelName,
										density: modelDensity,
										colors: colors,
										policeFlags: isPolice,
										gangsterFlags: gangsterFlags
									))
								}

								trafficSettings = TrafficSettings(
									outerRadiusToHide: outerRadiusToHide,
									innerRadiusForGeneration: innerRadiusForGeneration,
									outerRadiusForGeneration: outerRadiusForGeneration,
									generatedCarCount: Int(numOfGeneratedCars),
									cars: cars
								)

							case .pedestrians:
								stream.currentOffset += 5

								let _: Float = try stream.read()						// genRadiusFromPoint / 100
								let _: Float = try stream.read()						// outerRadiusToHide / 100
								let _: Float = try stream.read()						// innerRadiusForGen / 50
								let _: Float = try stream.read()						// outerRadiusForGener / 90
								let _: Float = try stream.read()						// innerRadiusForGener / 50
								let _: UInt32 = try stream.read()						// numOfGeneratedPeds / 100
								let numOfPedsInDatabase: UInt32 = try stream.read()

								for _ in 0 ..< numOfPedsInDatabase {
									let _: String = try stream.read(maxLength: 17) // modelName
		//							print("PED modelName:", modelName)
								}

								for _ in 0 ..< numOfPedsInDatabase {
									let _: UInt32 = try stream.read() // modelDensity
		//							print("PED density:", modelDensity)
								}

							case .none, .empty:
								break

							case .dog:
								stream.currentOffset += partSize - 6

							case .plane:
								stream.currentOffset += partSize - 6

							case .railRoute:
								stream.currentOffset += partSize - 6

							case .pumpar:
								stream.currentOffset += partSize - 6

							case .enemy:
								stream.currentOffset += 79

								let scriptLength: UInt32 = try stream.read()
								let scriptStr: String = try stream.read(maxLength: Int(scriptLength))
								//print("ENEMY SCRIPT \(name):\n\(scriptStr)")

								if let node = node {
									attachScript(scriptStr, named: name, to: node)
								} else {
									pendingScriptStringsByName[name] = scriptStr
								}

								case .unknown2:
									stream.currentOffset += partSize - 6

								case .unknown26:
									stream.currentOffset += partSize - 6

								case .wagons:
									stream.currentOffset += partSize - 6

							case .clock:
								stream.currentOffset += partSize - 6

							case .physical:
								let physicalData = try readPhysicalData(stream: stream)
								if let node = node {
									attachPhysical(physicalData, to: node)
								} else {
									pendingPhysicalDataByName[name] = physicalData
								}

							case .truck:
								stream.currentOffset += partSize - 6

							}

						default:
							assert(true)
						}

						stream.currentOffset = partEndOffset
					}

				case .initDef:
					stream.currentOffset += objSize - 6
					print("[INIT DEF]")

				case .initScript:
					stream.currentOffset += 1

					let nameLength: UInt32 = try stream.read()
					let name: String = try stream.read(maxLength: Int(nameLength))

					let scriptLength: UInt32 = try stream.read()
					let scriptStr: String = try stream.read(maxLength: Int(scriptLength))
					let script = Script(script: scriptStr, scene: self, node: self.rootNode, name: name)
					self.initScripts[name] = script
				}
			}
		}

	}

	private func readLight(stream: InputStream, partSize: Int, objectNode: SCNNode) throws {
		let endOffset = stream.currentOffset + partSize - 6
		var lightType: LightType = .point
		var color = SKColor.white
		var power: CGFloat = 1
		var coneAngle: CGFloat = 0
		var near: CGFloat = 0
		var far: CGFloat = 0
		var sectorName: String?

		while stream.currentOffset < endOffset {
			let property = try stream.readLightPropertyHeader()
			let propertyEndOffset = stream.currentOffset + property.payloadSize
			guard propertyEndOffset <= endOffset else {
				stream.currentOffset = endOffset
				break
			}

			switch property.signature {
			case 0x4041:
				guard property.payloadSize >= 4 else { break }
				let rawValue: UInt32 = try stream.read()
				lightType = LightType(rawValue: rawValue) ?? .point

			case 0x0026:
				guard property.payloadSize >= 12 else { break }
				let r: Float = try stream.read()
				let g: Float = try stream.read()
				let b: Float = try stream.read()
				color = SKColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)

			case 0x4042:
				guard property.payloadSize >= 4 else { break }
				let value: Float = try stream.read()
				power = CGFloat(value)

			case 0x4043:
				guard property.payloadSize >= 8 else { break }
				let _: Float = try stream.read()
				let value: Float = try stream.read()
				coneAngle = CGFloat(value)

			case 0x4044:
				guard property.payloadSize >= 8 else { break }
				let nearValue: Float = try stream.read()
				let farValue: Float = try stream.read()
				near = CGFloat(nearValue)
				far = CGFloat(farValue)

			case 0x4045:
				guard property.payloadSize >= 4 else { break }
				let _: UInt32 = try stream.read()

			case 0x4046:
				sectorName = try stream.read(maxLength: property.payloadSize).nilIfEmpty

			default:
				break
			}

			stream.currentOffset = propertyEndOffset
		}

		configureLightNode(
			objectNode,
			type: lightType,
			color: color,
			power: power,
			coneAngle: coneAngle,
			near: near,
			far: far,
			sectorName: sectorName
		)
	}

	private func readAreaBounds(stream: InputStream, endOffset: Int) throws -> AreaBounds? {
		guard endOffset - stream.currentOffset >= 4 else { return nil }
		let vertexCount: UInt32 = try stream.read()
		guard vertexCount > 0 else { return nil }
		let vertexBytes = Int(vertexCount) * 12
		guard endOffset - stream.currentOffset >= vertexBytes else { return nil }

		var vertices: [SCNVector3] = []
		vertices.reserveCapacity(Int(vertexCount))
		for _ in 0..<vertexCount {
			vertices.append(try SCNVector3(stream: stream))
		}

		var triangles: [(Int, Int, Int)] = []
		if endOffset - stream.currentOffset >= 4 {
			let triangleCount: UInt32 = try stream.read()
			let triangleBytes = Int(triangleCount) * 6
			if triangleCount > 0, endOffset - stream.currentOffset >= triangleBytes {
				triangles.reserveCapacity(Int(triangleCount))
				for _ in 0..<triangleCount {
					let first: UInt16 = try stream.read()
					let second: UInt16 = try stream.read()
					let third: UInt16 = try stream.read()
					triangles.append((Int(first), Int(second), Int(third)))
				}
			}
		}

		let minPoint = SCNVector3(
			x: vertices.map(\.x).min() ?? 0,
			y: vertices.map(\.y).min() ?? 0,
			z: vertices.map(\.z).min() ?? 0
		)
		let maxPoint = SCNVector3(
			x: vertices.map(\.x).max() ?? 0,
			y: vertices.map(\.y).max() ?? 0,
			z: vertices.map(\.z).max() ?? 0
		)
		return AreaBounds(min: minPoint, max: maxPoint, vertices: vertices, triangles: triangles)
	}

	private static func cityMusicId(from name: String?) -> String? {
		guard let name else { return nil }
		let prefix = "city_music_"
		guard name.lowercased().hasPrefix(prefix) else { return nil }
		let suffix = String(name.dropFirst(prefix.count).prefix(2))
		return suffix.isEmpty ? nil : suffix
	}

	func resolvePendingDoors(in rootNode: SCNNode) {
		for (name, doorData) in pendingDoorDataByName {
			guard let node = rootNode.mafiaChildNode(named: name, recursively: true) else { continue }
			attachDoor(doorData, to: node)
		}
		pendingDoorDataByName.removeAll()
	}

	private func attachDoor(_ doorData: DoorData, to node: SCNNode) {
		node.doorData = doorData
		if doorData.isOpen {
			node.eulerAngles.y += doorData.initialOpenAngle(forUserSide: 0)
			doorData.openDirection = 0
		}
		attachDoorPhysics(to: node)
		guard !actions.contains(where: { action in
			if case .door(let doorNode) = action {
				return doorNode === node
			}
			return false
		}) else { return }
		actions.append(.door(node))
	}

	private func attachDoorPhysics(to node: SCNNode) {
		guard let shape = node.convexHullPhysicsShapeFromGeometryHierarchy() else { return }

		node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: shape)
		node.physicsBody?.configureAsDynamicObjectCollider()
	}

	func resolvePendingPhysicalObjects(in rootNode: SCNNode) {
		for (name, physicalData) in pendingPhysicalDataByName {
			guard let node = rootNode.mafiaChildNode(named: name, recursively: true) else { continue }
			attachPhysical(physicalData, to: node)
		}
		pendingPhysicalDataByName.removeAll()
	}

	func resolvePendingScripts(in rootNode: SCNNode) {
		for (name, scriptString) in pendingScriptStringsByName {
			guard let node = rootNode.mafiaChildNode(named: name, recursively: true) else { continue }
			attachScript(scriptString, named: name, to: node)
		}
		pendingScriptStringsByName.removeAll()
	}

	func resolvePendingObjectTypes(in rootNode: SCNNode) {
		for (name, type) in pendingObjectTypesByName {
			guard let node = rootNode.mafiaChildNode(named: name, recursively: true) else { continue }
			registerNodeTree(node)
			applyObjectDefinitionType(type, to: node)
		}
		pendingObjectTypesByName.removeAll()
		for (name, energy) in pendingHumanEnergyByName {
			guard let node = rootNode.mafiaChildNode(named: name, recursively: true) else { continue }
			registerNodeTree(node)
			node.humanEnergy = energy
			playDefaultHumanIdleAnimation(in: node)
			if name == pendingPlayerNodeName {
				playerNode = node
				print("== Resolved Player Node: \(name), energy=\(energy)")
			}
		}
		pendingHumanEnergyByName.removeAll()
		pendingPlayerNodeName = nil
	}

	private func applyObjectDefinitionType(_ type: ObjectDefinitionType, to node: SCNNode) {
		node.type = type
		if type.hasDefaultHumanEnergy && node.humanEnergy == nil {
			node.humanEnergy = 100
		}
		if type.hasDefaultHumanEnergy {
			playDefaultHumanIdleAnimation(in: node)
		}
	}

	func spawnMission6RaceCars(raceTables: Mission6RaceTables) {
		clearMission6RaceSpawnedCars()
		guard let settings = mission6RaceState.settingsSnapshot() else { return }

		for participant in settings.participants {
			guard let startNode = rootNode.mafiaChildNode(named: "start\(participant.slotIndex)", recursively: true),
				  let carRecord = raceTables.carIndexRecord(at: participant.vehicleRecordId),
				  let modelPath = mission6RaceCarModelPath(for: carRecord) else {
				continue
			}

			let carNode = SCNNode()
			do {
				try loadModel(named: modelPath, node: carNode)
			} catch {
				print("== Mission6 race car failed: slot=\(participant.slotIndex) model=\(modelPath) \(error)")
				continue
			}
			guard carNode.hasModelContent else { continue }

			carNode.name = "racing_car\(participant.slotIndex)"
			carNode.vehicleModelName = ((modelPath as NSString).lastPathComponent as NSString).deletingPathExtension.lowercased()
			carNode.type = .car
			addSyntheticMission6RaceWheelsIfNeeded(to: carNode)
			carNode.transform = rootNode.convertTransform(startNode.presentation.worldTransform, from: nil)
			rootNode.addChildNode(carNode)
			registerNodeTree(carNode)
			mission6RaceSpawnedCars.append(carNode)
			print("== Mission6 race car spawned: slot=\(participant.slotIndex) record=\(participant.vehicleRecordId) model=\(modelPath)")
		}
		if let startNode = rootNode.mafiaChildNode(named: "start0", recursively: true) {
			mission6RaceState.prepareProgress(
				startPosition: startNode.presentation.worldPosition,
				startForward: startNode.presentation.worldFront
			)
		}
		configureMission6RaceAI(settings: settings)
	}

	private func addSyntheticMission6RaceWheelsIfNeeded(to carNode: SCNNode) {
		let wheelNames = ["WHL0", "WHR0", "WHL1", "WHR1"]
		guard wheelNames.contains(where: { carNode.mafiaChildNode(named: $0, recursively: true) == nil }),
			  let bodyNode = carNode.mafiaChildNode(named: "BODY", recursively: false) else {
			return
		}

		let bounds = bodyNode.boundingBox
		let width = bounds.max.x - bounds.min.x
		let height = bounds.max.y - bounds.min.y
		let length = bounds.max.z - bounds.min.z
		guard width > 0, height > 0, length > 0 else { return }

		let radius = max(SCNFloat(0.18), min(width, length) * 0.07)
		let halfWidth = width * 0.42
		let halfLength = length * 0.34
		let centerX = (bounds.min.x + bounds.max.x) / 2
		let centerZ = (bounds.min.z + bounds.max.z) / 2
		let wheelY = bounds.min.y + radius
		let localPositions: [(name: String, position: SCNVector3)] = [
			("WHL0", SCNVector3(x: centerX - halfWidth, y: wheelY, z: centerZ + halfLength)),
			("WHR0", SCNVector3(x: centerX + halfWidth, y: wheelY, z: centerZ + halfLength)),
			("WHL1", SCNVector3(x: centerX - halfWidth, y: wheelY, z: centerZ - halfLength)),
			("WHR1", SCNVector3(x: centerX + halfWidth, y: wheelY, z: centerZ - halfLength))
		]

		for wheel in localPositions where carNode.mafiaChildNode(named: wheel.name, recursively: true) == nil {
			let wheelBox = SCNBox(
				width: CGFloat(radius * 0.55),
				height: CGFloat(radius * 2),
				length: CGFloat(radius * 2),
				chamferRadius: 0
			)
			let material = SCNMaterial()
			material.diffuse.contents = SKColor.clear
			material.transparency = 0
			wheelBox.firstMaterial = material

			let wheelNode = SCNNode(geometry: wheelBox)
			wheelNode.name = wheel.name
			wheelNode.position = bodyNode.convertPosition(wheel.position, to: carNode)
			carNode.addChildNode(wheelNode)
		}
	}

	func updateMission6RaceProgress(deltaTime: TimeInterval) {
		mission6RaceState.advanceCountdown(deltaTime: deltaTime)
		if let position = mission6RacePlayerPosition() {
			mission6RaceState.updatePlayerProgress(position: position, deltaTime: deltaTime)
		}
		updateMission6RaceAI(deltaTime: deltaTime)
		let stats = mission6RaceState.hudStats(
			opponentCompletedLaps: mission6RaceAICars.map(\.completedLaps)
		)
		game?.updateHud { hud in
			hud.updateMission6RaceStats(stats)
		}
	}

	private func clearMission6RaceSpawnedCars() {
		mission6RaceAICars.removeAll()
		mission6RaceCircuitDebugNode?.removeFromParentNode()
		mission6RaceCircuitDebugNode = nil
		for carNode in mission6RaceSpawnedCars {
			unregisterNodeTree(carNode)
			carNode.removeFromParentNode()
		}
		mission6RaceSpawnedCars.removeAll()
	}

	private func mission6RaceCarModelPath(for carRecord: Mission6CarIndexRecord) -> String? {
		for modelName in [carRecord.key, carRecord.modelName] {
			guard let modelPath = mission6RaceCarModelPath(for: modelName),
				  mission6RaceCarModelExists(at: modelPath) else {
				continue
			}
			return modelPath
		}
		return nil
	}

	private func mission6RaceCarModelPath(for modelName: String) -> String? {
		let normalizedName = modelName
			.replacingOccurrences(of: "\\", with: "/")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let withoutExtension = (normalizedName as NSString).deletingPathExtension
		guard !withoutExtension.isEmpty else { return nil }
		return withoutExtension.contains("/") ? withoutExtension : "models/" + withoutExtension
	}

	private func mission6RaceCarModelExists(at modelPath: String) -> Bool {
		let url = mainDirectory.appendingPathComponent(modelPath.lowercased() + ".4ds")
		return FileManager.default.fileExists(atPath: url.path)
	}

	private func mission6RacePlayerPosition() -> SCNVector3? {
		if let vehicleNode = game?.vehicle?.node {
			return vehicleNode.presentation.worldPosition
		}
		return mission6RaceSpawnedCars.first { $0.name == "racing_car0" }?.presentation.worldPosition
	}

	private func configureMission6RaceAI(settings: Mission6RaceSettings) {
		mission6RaceAICars.removeAll()
		guard let checkpoints = settings.checkpoints,
			  let startNode = rootNode.mafiaChildNode(named: "start0", recursively: true),
			  let route = mission6RaceAIRoute(checkpoints: checkpoints, startNode: startNode),
			  route.count > 2 else {
			clearMission6RaceCircuitDebug()
			return
		}
		configureMission6RaceCircuitDebug(route: route, checkpoints: checkpoints)
		let routeLength = mission6RaceRouteLength(route)
		let bestLapTime = settings.circuit?.bestTimes.first.flatMap { value -> Float? in
			value > 0 ? Float(value) / 1000 : nil
		}
		let baseSpeed = bestLapTime.map { routeLength / $0 } ?? 18

		for participant in settings.participants where !participant.isPlayer {
			guard let node = mission6RaceSpawnedCars.first(where: { $0.name == "racing_car\(participant.slotIndex)" }) else {
				continue
			}
			let multiplier = participant.skillMultiplier ?? 1
			let slotScale = 0.96 + Float(participant.slotIndex % 5) * 0.015
			mission6RaceAICars.append(Mission6RaceAICar(
				node: node,
				slotIndex: participant.slotIndex,
				route: route,
				segmentIndex: 0,
				segmentProgress: Float(participant.slotIndex) * 0.015,
				speed: max(8, baseSpeed * multiplier * slotScale),
				completedLaps: 0,
				isFinished: false
			))
		}
	}

	private func updateMission6RaceAI(deltaTime: TimeInterval) {
		guard deltaTime > 0,
			  mission6RaceState.isStartedSnapshot(),
			  let settings = mission6RaceState.settingsSnapshot(),
			  !mission6RaceAICars.isEmpty else {
			return
		}
		for index in mission6RaceAICars.indices {
			guard !mission6RaceAICars[index].isFinished,
				  let node = mission6RaceAICars[index].node else {
				continue
			}
			updateMission6RaceAICar(&mission6RaceAICars[index], node: node, deltaTime: Float(deltaTime))
			if mission6RaceAICars[index].completedLaps >= settings.lapCount {
				mission6RaceAICars[index].isFinished = true
				mission6RaceState.failIfRaceStarted()
			}
		}
	}

	private func updateMission6RaceAICar(_ aiCar: inout Mission6RaceAICar, node: SCNNode, deltaTime: Float) {
		guard aiCar.route.count > 1 else { return }
		var remainingDistance = aiCar.speed * deltaTime
		while remainingDistance > 0 {
			let current = aiCar.route[aiCar.segmentIndex]
			let nextIndex = (aiCar.segmentIndex + 1) % aiCar.route.count
			let next = aiCar.route[nextIndex]
			let segmentLength = max(0.001, mission6RaceHorizontalDistance(current, next))
			let availableDistance = (1 - aiCar.segmentProgress) * segmentLength
			if remainingDistance < availableDistance {
				aiCar.segmentProgress += remainingDistance / segmentLength
				remainingDistance = 0
			} else {
				remainingDistance -= availableDistance
				aiCar.segmentIndex = nextIndex
				aiCar.segmentProgress = 0
				if aiCar.segmentIndex == 0 {
					aiCar.completedLaps += 1
				}
			}
		}

		let current = aiCar.route[aiCar.segmentIndex]
		let next = aiCar.route[(aiCar.segmentIndex + 1) % aiCar.route.count]
		let progress = SCNFloat(aiCar.segmentProgress)
		node.position = SCNVector3(
			x: current.x + (next.x - current.x) * progress,
			y: current.y + (next.y - current.y) * progress,
			z: current.z + (next.z - current.z) * progress
		)
		let tangent = next - current
		if abs(tangent.x) > 0.001 || abs(tangent.z) > 0.001 {
			node.eulerAngles.y = atan2(tangent.x, tangent.z)
		}
	}

	func setMission6RaceDebugVisible(_ isVisible: Bool) {
		mission6RaceCircuitDebugNode?.isHidden = !isVisible
	}

	private func clearMission6RaceCircuitDebug() {
		mission6RaceCircuitDebugNode?.removeFromParentNode()
		mission6RaceCircuitDebugNode = nil
	}

	private func configureMission6RaceCircuitDebug(route: [SCNVector3], checkpoints: Mission6Checkpoints) {
		clearMission6RaceCircuitDebug()

		var vertices: [SCNVector3] = []
		var indices: [Int32] = []
		for index in route.indices {
			let nextIndex = (index + 1) % route.count
			let vertexIndex = Int32(vertices.count)
			vertices.append(mission6RaceDebugPosition(route[index]))
			vertices.append(mission6RaceDebugPosition(route[nextIndex]))
			indices.append(vertexIndex)
			indices.append(vertexIndex + 1)
		}

		guard !vertices.isEmpty else { return }

		let source = SCNGeometrySource(vertices: vertices)
		let element = SCNGeometryElement(indices: indices, primitiveType: .line)
		let geometry = SCNGeometry(sources: [source], elements: [element])
		geometry.firstMaterial = Game.debugMaterial(color: .yellow)

		let node = SCNNode(geometry: geometry)
		node.name = "__mission6_race_circuit_debug__"
		node.isHidden = !(game?.areCollisionWireframesVisible ?? false)

		let markerMaterial = Game.debugMaterial(color: .orange, fillMode: .fill)
		for checkpoint in checkpoints.checkpoints where checkpoint.type == 8 {
			let marker = SCNSphere(radius: 0.55)
			marker.firstMaterial = markerMaterial
			let markerNode = SCNNode(geometry: marker)
			markerNode.name = "__mission6_race_control_\(checkpoint.index)__"
			markerNode.position = mission6RaceDebugPosition(checkpoint.position)
			node.addChildNode(markerNode)
		}

		rootNode.addChildNode(node)
		mission6RaceCircuitDebugNode = node
	}

	private func mission6RaceDebugPosition(_ position: SCNVector3) -> SCNVector3 {
		SCNVector3(x: position.x, y: position.y + 1.25, z: position.z)
	}

	private func mission6RaceAIRoute(checkpoints: Mission6Checkpoints, startNode: SCNNode) -> [SCNVector3]? {
		let controlNodes = checkpoints.checkpoints.filter { $0.type == 8 }
		guard controlNodes.count > 2 else { return nil }

		let neighbors = mission6RaceCheckpointNeighbors(checkpoints: checkpoints)
		guard let startControlIndex = mission6RaceStartControlIndex(
			controlNodes: controlNodes,
			startNode: startNode
		) else {
			return nil
		}

		let orderedControls = mission6RaceOrderedControlRoute(
			checkpoints: checkpoints,
			neighbors: neighbors,
			controlNodes: controlNodes,
			startIndex: startControlIndex
		)
		guard orderedControls.count == controlNodes.count else { return nil }
		guard var route = mission6RaceExpandedControlRoute(
			checkpoints: checkpoints,
			neighbors: neighbors,
			orderedControls: orderedControls
		) else { return nil }
		route.insert(startNode.presentation.worldPosition, at: 0)
		return route
	}

	private func mission6RaceCheckpointNeighbors(checkpoints: Mission6Checkpoints) -> [[(index: Int, distance: Float)]] {
		var neighbors = Array(repeating: [(index: Int, distance: Float)](), count: checkpoints.checkpoints.count)
		for checkpoint in checkpoints.checkpoints {
			for link in checkpoint.links {
				let linkedIndex = Int(link.checkpointIndex)
				guard checkpoints.checkpoints.indices.contains(linkedIndex) else { continue }
				neighbors[checkpoint.index].append((index: linkedIndex, distance: link.distance))
				neighbors[linkedIndex].append((index: checkpoint.index, distance: link.distance))
			}
		}
		return neighbors
	}

	private func mission6RaceStartControlIndex(
		controlNodes: [Mission6Checkpoint],
		startNode: SCNNode
	) -> Int? {
		let startPosition = startNode.presentation.worldPosition
		let startNodeFront = startNode.presentation.worldFront
		let startForward = horizontalMission6RaceVector(SCNVector3(
			x: -startNodeFront.x,
			y: -startNodeFront.y,
			z: -startNodeFront.z
		))
		let forwardControls = controlNodes.filter {
			mission6RaceDot(horizontalMission6RaceVector($0.position - startPosition), startForward) > 0
		}
		let candidates = forwardControls.isEmpty ? controlNodes : forwardControls
		return candidates.min {
			mission6RaceHorizontalDistanceSquared($0.position, startPosition) <
				mission6RaceHorizontalDistanceSquared($1.position, startPosition)
		}?.index
	}

	private func mission6RaceOrderedControlRoute(
		checkpoints: Mission6Checkpoints,
		neighbors: [[(index: Int, distance: Float)]],
		controlNodes: [Mission6Checkpoint],
		startIndex: Int
	) -> [Int] {
		var ordered = [startIndex]
		var remaining = Set(controlNodes.map(\.index))
		remaining.remove(startIndex)
		var currentIndex = startIndex

		while !remaining.isEmpty {
			let candidate = remaining.compactMap { controlIndex -> (index: Int, distance: Float)? in
				guard let result = mission6RaceShortestCheckpointPath(
					checkpoints: checkpoints,
					neighbors: neighbors,
					from: currentIndex,
					to: controlIndex
				) else {
					return nil
				}
				return (index: controlIndex, distance: result.distance)
			}.min { lhs, rhs in
				lhs.distance < rhs.distance
			}
			guard let candidate else { break }
			ordered.append(candidate.index)
			remaining.remove(candidate.index)
			currentIndex = candidate.index
		}

		return ordered
	}

	private func mission6RaceExpandedControlRoute(
		checkpoints: Mission6Checkpoints,
		neighbors: [[(index: Int, distance: Float)]],
		orderedControls: [Int]
	) -> [SCNVector3]? {
		var routeIndices: [Int] = []
		for index in 0..<(orderedControls.count - 1) {
			guard let result = mission6RaceShortestCheckpointPath(
				checkpoints: checkpoints,
				neighbors: neighbors,
				from: orderedControls[index],
				to: orderedControls[index + 1]
			) else {
				return nil
			}
			if routeIndices.isEmpty {
				routeIndices.append(contentsOf: result.path)
			} else {
				routeIndices.append(contentsOf: result.path.dropFirst())
			}
		}

		return routeIndices.map { checkpoints.checkpoints[$0].position }
	}

	private func mission6RaceShortestCheckpointPath(
		checkpoints: Mission6Checkpoints,
		neighbors: [[(index: Int, distance: Float)]],
		from startIndex: Int,
		to endIndex: Int
	) -> (distance: Float, path: [Int])? {
		let count = checkpoints.checkpoints.count
		guard checkpoints.checkpoints.indices.contains(startIndex),
			  checkpoints.checkpoints.indices.contains(endIndex),
			  neighbors.count == count else {
			return nil
		}

		var distances = Array(repeating: Float.greatestFiniteMagnitude, count: count)
		var previous = Array(repeating: -1, count: count)
		var visited = Array(repeating: false, count: count)
		distances[startIndex] = 0

		for _ in 0..<count {
			var currentIndex: Int?
			var currentDistance = Float.greatestFiniteMagnitude
			for index in 0..<count where !visited[index] && distances[index] < currentDistance {
				currentIndex = index
				currentDistance = distances[index]
			}
			guard let currentIndex else { break }
			if currentIndex == endIndex { break }
			visited[currentIndex] = true

			for neighbor in neighbors[currentIndex] {
				let nextDistance = currentDistance + neighbor.distance
				if nextDistance < distances[neighbor.index] {
					distances[neighbor.index] = nextDistance
					previous[neighbor.index] = currentIndex
				}
			}
		}

		guard distances[endIndex] < Float.greatestFiniteMagnitude else { return nil }
		var path = [endIndex]
		var currentIndex = endIndex
		while currentIndex != startIndex {
			currentIndex = previous[currentIndex]
			guard currentIndex >= 0 else { return nil }
			path.append(currentIndex)
		}
		return (distance: distances[endIndex], path: Array(path.reversed()))
	}

	private func mission6RaceRouteLength(_ route: [SCNVector3]) -> Float {
		guard route.count > 1 else { return 0 }
		var length: Float = 0
		for index in route.indices {
			length += mission6RaceHorizontalDistance(route[index], route[(index + 1) % route.count])
		}
		return length
	}

	private func mission6RaceHorizontalDistance(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		sqrt(mission6RaceHorizontalDistanceSquared(lhs, rhs))
	}

	private func mission6RaceHorizontalDistanceSquared(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		let dx = Float(lhs.x - rhs.x)
		let dz = Float(lhs.z - rhs.z)
		return dx * dx + dz * dz
	}

	private func horizontalMission6RaceVector(_ vector: SCNVector3) -> SCNVector3 {
		let x = Float(vector.x)
		let z = Float(vector.z)
		let length = sqrt(x * x + z * z)
		guard length > 0.0001 else { return SCNVector3(x: 0, y: 0, z: 1) }
		return SCNVector3(x: SCNFloat(x / length), y: 0, z: SCNFloat(z / length))
	}

	private func mission6RaceDot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		Float(lhs.x * rhs.x + lhs.z * rhs.z)
	}

	func startScripts() {
		guard !didStartScripts else { return }
		didStartScripts = true
		for script in initScripts.values {
			script.start()
		}
		for script in scripts.values {
			script.start()
		}
	}

	func restoreSaveGameScriptStates(from checkpoint: SaveGameCheckpoint) {
		for entity in checkpoint.entities {
			guard let state = entity.scriptActorState,
				  let script = scripts[entity.name] else { continue }
			script.node.actorState = state
		}
	}

	func tearDown() {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.tearDown()
			}
			return
		}

		let tearDownStartTime = CFAbsoluteTimeGetCurrent()
		var lastStepTime = tearDownStartTime
		func logTearDownStep(_ name: String) {
			let now = CFAbsoluteTimeGetCurrent()
			print(String(format: "== Scene tearDown %@ %.3fs total %.3fs", name, now - lastStepTime, now - tearDownStartTime))
			lastStepTime = now
		}

		setScriptsPaused(true)
		let allScripts = Array(initScripts.values) + Array(scripts.values)
		for script in allScripts {
			script.stop()
		}
		logTearDownStep("scripts")
		destroyScriptMusicStreams()
		logTearDownStep("music streams")
		unloadRecords()
		logTearDownStep("records")
		clearDifferenceFiles()
		logTearDownStep("differences")
		stopActiveAudioPlayers()
		logTearDownStep("audio players")
		playerNode = nil
		compassNode = nil
		playerFireEvent = nil
		playerHornEvent = nil
		initScripts.removeAll()
		scripts.removeAll()
		sounds.removeAll()
		enemyGroups.removeAll()
		detectorHitWaits.removeAll()
		clearMission6RaceSpawnedCars()
		mission6RaceState.clear()
		humanVehicleOwners.removeAll()
		actions.removeAll()
		environmentLights.removeAll()
		pendingDoorDataByName.removeAll()
		pendingPhysicalDataByName.removeAll()
		pendingScriptStringsByName.removeAll()
		pendingObjectTypesByName.removeAll()
		pendingHumanEnergyByName.removeAll()
		pendingPlayerNodeName = nil
		unusableCarIds.removeAll()
		trafficSettings = nil
		cutscenePausedScriptIds.removeAll()
		isCutsceneSkipRequested = false
		nodesByNameLock.lock()
		nodesByName.removeAll()
		nodesByNativeSceneObjectIndex.removeAll()
		missingNodeNames.removeAll()
		nodesByNameLock.unlock()
		nativeSceneObjectCount = 0
		weaponsLock.lock()
		weaponsByOwner.removeAll()
		weaponsLock.unlock()
		logTearDownStep("state")
	}

	@discardableResult
	func loadDifferenceFile(named name: String) throws -> DifferenceFile {
		let key = differenceKey(for: name)
		if let differenceFile = loadedDifferenceFiles[key] {
			print("== Difference already loaded: \(name)")
			return differenceFile
		}

		print("== Loading Difference: \(name)")
		let differenceFile: DifferenceFile
		do {
			differenceFile = try DifferenceFile(named: name)
		} catch {
			throw error
		}
		attachDifferenceFile(differenceFile, key: key)
		printLoadedDifference(differenceFile)
		return differenceFile
	}

	func loadDifferenceFileAsync(
		named name: String,
		completion: @escaping @Sendable (Result<DifferenceFile, Swift.Error>) -> Void
	) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			let key = self.differenceKey(for: name)
			if let differenceFile = self.loadedDifferenceFiles[key] {
				print("== Difference already loaded: \(name)")
				completion(.success(differenceFile))
				return
			}

			let pendingLoad = PendingDifferenceLoad(completion: completion)
			if self.pendingDifferenceLoads[key] != nil {
				self.pendingDifferenceLoads[key]?.append(pendingLoad)
				return
			}
			self.pendingDifferenceLoads[key] = [pendingLoad]

			print("== Loading Difference async: \(name)")
			self.differenceLoadQueue.async { [weak self] in
				let result = Result { try DifferenceFile(named: name) }
				DispatchQueue.main.async { [weak self] in
					guard let self = self else { return }
					let pendingLoads = self.pendingDifferenceLoads.removeValue(forKey: key) ?? []
					guard !pendingLoads.isEmpty else { return }
					switch result {
					case .success(let differenceFile):
						self.attachDifferenceFile(differenceFile, key: key)
						self.printLoadedDifference(differenceFile)
						for pendingLoad in pendingLoads {
							pendingLoad.completion(.success(differenceFile))
						}

					case .failure(let error):
						for pendingLoad in pendingLoads {
							pendingLoad.completion(.failure(error))
						}
					}
				}
			}
		}
	}

	private func attachDifferenceFile(_ differenceFile: DifferenceFile, key: String) {
		rootNode.addChildNode(differenceFile.rootNode)
		registerNodeTree(differenceFile.rootNode)
		loadedDifferenceFiles[key] = differenceFile
		for (name, isEnabled) in differenceFile.animationStates {
			guard let node = game.scnScene.rootNode.mafiaChildNode(named: name, recursively: true) else {
				continue
			}
			node.actionsEnabled = isEnabled
		}
		for script in differenceFile.scripts.values {
			if replacedScriptsByDifferenceName[script.name] == nil, let existingScript = scripts[script.name] {
				replacedScriptsByDifferenceName[script.name] = existingScript
			}
			let loadedScript = Script(script: script.source, scene: self, node: differenceFile.rootNode, name: script.name)
			loadedScript.node.actorState = .active
			loadedScript.applyDeclaredInitialActorState()
			scripts[script.name] = loadedScript
			if didStartScripts && script.name == "GameInitStart" {
				loadedScript.start()
			}
			loadedDifferenceScriptNames.insert(script.name)
		}
	}

	private func printLoadedDifference(_ differenceFile: DifferenceFile) {
		print(
			"== Loaded Difference: \(differenceFile.name) " +
			"nodes=\(differenceFile.rootNode.childNodes.count) scripts=\(differenceFile.scripts.count)"
		)
	}

	private func differenceKey(for name: String) -> String {
		let lowercasedName = name.lowercased()
		return lowercasedName.hasSuffix(".chg") ? String(lowercasedName.dropLast(4)) : lowercasedName
	}

	func clearDifferenceFiles() {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.clearDifferenceFiles()
			}
			return
		}

		print("== Clearing Differences: \(loadedDifferenceFiles.count)")
		let cancelledLoads = pendingDifferenceLoads.values.flatMap { $0 }
		pendingDifferenceLoads.removeAll()
		for pendingLoad in cancelledLoads {
			pendingLoad.completion(.failure(SceneError()))
		}
		for differenceFile in loadedDifferenceFiles.values {
			unregisterNodeTree(differenceFile.rootNode)
			if differenceFile.rootNode.parent != nil {
				differenceFile.rootNode.removeFromParentNode()
			}
		}
		loadedDifferenceFiles.removeAll()

		for scriptName in loadedDifferenceScriptNames {
			if let replacedScript = replacedScriptsByDifferenceName[scriptName] {
				scripts[scriptName] = replacedScript
			} else {
				scripts.removeValue(forKey: scriptName)
			}
		}
		loadedDifferenceScriptNames.removeAll()
		replacedScriptsByDifferenceName.removeAll()
	}

	@discardableResult
	func loadRecord(named name: String, full: Bool = false) throws -> Record {
		let key = recordKey(for: name)
		if let record = loadedRecords[key] {
			print("== Record already loaded: \(name)")
			playRecord(record, full: full)
			return record
		}

		print("== Loading Record: \(name)")
		let record = try Record(name: name)
		loadedRecords[key] = record
		print(
			"== Loaded Record: \(record.name) header=\(record.headerKey) " +
			"animations=\(record.animations.count) models=\(record.modelBindings.count) " +
			"cameraKeys=\(record.cameraKeyframes.count) events=\(record.timedEvents.count) " +
			"speech=\(record.speechEvents.count) animationEvents=\(record.animationEvents.count) " +
			"targetLinks=\(record.targetLinks.count)"
		)
		playRecord(record, full: full)
		return record
	}

	func loadRecordAsync(
		named name: String,
		full: Bool = false,
		completion: @escaping @Sendable (Result<Record, Swift.Error>) -> Void
	) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			let key = self.recordKey(for: name)
			if let record = self.loadedRecords[key] {
				print("== Record already loaded: \(name)")
				self.waitForPendingDifferenceLoads { [weak self] result in
					guard let self = self else { return }
					switch result {
					case .success:
						self.playRecord(record, full: full)
						completion(.success(record))

					case .failure(let error):
						completion(.failure(error))
					}
				}
				return
			}

			let pendingLoad = PendingRecordLoad(full: full, completion: completion)
			if self.pendingRecordLoads[key] != nil {
				self.pendingRecordLoads[key]?.append(pendingLoad)
				return
			}
			self.pendingRecordLoads[key] = [pendingLoad]

			print("== Loading Record async: \(name)")
			self.recordLoadQueue.async { [weak self] in
				let result = Result { () -> Record in
					let record = try Record(name: name)
					Self.preloadRecordAnimations(record)
					return record
				}
				DispatchQueue.main.async { [weak self] in
					guard let self = self else { return }
					let pendingLoads = self.pendingRecordLoads.removeValue(forKey: key) ?? []
					guard !pendingLoads.isEmpty else { return }
					switch result {
					case .success(let record):
						self.loadedRecords[key] = record
						print(
							"== Loaded Record: \(record.name) header=\(record.headerKey) " +
							"animations=\(record.animations.count) models=\(record.modelBindings.count) " +
							"cameraKeys=\(record.cameraKeyframes.count) events=\(record.timedEvents.count) " +
							"speech=\(record.speechEvents.count) animationEvents=\(record.animationEvents.count) " +
							"targetLinks=\(record.targetLinks.count)"
						)
						self.waitForPendingDifferenceLoads { [weak self] result in
							guard let self = self else { return }
							switch result {
							case .success:
								for pendingLoad in pendingLoads {
									self.playRecord(record, full: pendingLoad.full)
									pendingLoad.completion(.success(record))
								}

							case .failure(let error):
								for pendingLoad in pendingLoads {
									pendingLoad.completion(.failure(error))
								}
							}
						}

					case .failure(let error):
						for pendingLoad in pendingLoads {
							pendingLoad.completion(.failure(error))
						}
					}
				}
			}
		}
	}

	private func waitForPendingDifferenceLoads(completion: @escaping @Sendable (Result<Void, Swift.Error>) -> Void) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async { [weak self] in
				self?.waitForPendingDifferenceLoads(completion: completion)
			}
			return
		}

		let pendingKeys = Array(pendingDifferenceLoads.keys)
		guard !pendingKeys.isEmpty else {
			completion(.success(()))
			return
		}

		let waitState = PendingDifferenceWaitState(remainingLoads: pendingKeys.count, completion: completion)

		for key in pendingKeys {
			pendingDifferenceLoads[key]?.append(PendingDifferenceLoad(completion: waitState.finishOne))
		}
	}

	private func recordKey(for name: String) -> String {
		let lowercasedName = name.lowercased()
		return lowercasedName.hasSuffix(".rep") ? String(lowercasedName.dropLast(4)) : lowercasedName
	}

	private static func preloadRecordAnimations(_ record: Record) {
		var animationPaths = Set<String>()
		var positionAnimationPaths = Set<String>()
		for animation in record.animations {
			let animationPath = recordAnimationPath(for: animation.name)
			animationPaths.insert(animationPath)
			positionAnimationPaths.insert(recordPreloadPositionAnimationPath(for: animationPath))
		}

		var loadedAnimations = 0
		for animationPath in animationPaths where (try? loadAnimation(named: animationPath)) != nil {
			loadedAnimations += 1
		}

		var loadedPositionAnimations = 0
		for positionAnimationPath in positionAnimationPaths where positionAnimationExists(named: positionAnimationPath) {
			if (try? loadPositionAnimation(named: positionAnimationPath)) != nil {
				loadedPositionAnimations += 1
			}
		}

		print(
			"== Preloaded Record Animations: \(record.name) " +
			"animations=\(loadedAnimations)/\(animationPaths.count) " +
			"position=\(loadedPositionAnimations)/\(positionAnimationPaths.count)"
		)
	}

	private static func recordAnimationPath(for animationName: String) -> String {
		return "anims/" + animationName.replacingOccurrences(
			of: ".i3d",
			with: ".5ds",
			options: [.caseInsensitive]
		)
	}

	private static func recordPreloadPositionAnimationPath(for animationPath: String) -> String {
		let lowercasedPath = animationPath.lowercased()
		if lowercasedPath.hasSuffix(".5ds") {
			return String(animationPath.dropLast(4)) + ".tck"
		}
		return animationPath + ".tck"
	}

	func unloadRecords() {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.unloadRecords()
			}
			return
		}

		print("== Unloading Records: \(loadedRecords.count)")
		stopRecordPlayback()
		let cancelledLoads = pendingRecordLoads.values.flatMap { $0 }
		loadedRecords.removeAll()
		pendingRecordLoads.removeAll()
		for pendingLoad in cancelledLoads {
			pendingLoad.completion(.failure(SceneError()))
		}
	}

	private func playRecord(_ record: Record, full: Bool) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.playRecord(record, full: full)
			}
			return
		}

		let differenceRoots = loadedDifferenceFiles.values.map { $0.rootNode }
		let existingRecordRoots = differenceRoots + [rootNode, game.scnScene.rootNode]
		let recordPropNodes = createRecordPropNodes(for: record, existingRoots: existingRecordRoots)
		let recordRoots = differenceRoots + recordPropNodes + [rootNode, game.scnScene.rootNode]
		let animationLookup = RecordAnimationLookup(record: record, recordRoots: recordRoots)

		print("== Playing Record: \(record.name) full=\(full)")
		activeRecordNames.insert(record.name)

		print("== Record Bindings resolved: \(animationLookup.bindingNodes.count)/\(record.modelBindings.count)")

		var startedAnimations = 0
		var startedPositionAnimations = 0
		var skippedAnimations = 0
		var resolvedAnimations: [RecordAnimationPlayback] = []
		var resolvedTransformPlaybacks: [ObjectIdentifier: RecordTransformPlayback] = [:]
		var positionAnimationNodeIds = Set<ObjectIdentifier>()
		for animation in record.animations {
			let animationName = animation.name.replacingOccurrences(
				of: ".i3d",
				with: ".5ds",
				options: [.caseInsensitive]
			)
			let animationPath = "anims/" + animationName
			guard let target = recordAnimationTarget(
				animation: animation,
				animationPath: animationPath,
				record: record,
				lookup: animationLookup
			) else {
				skippedAnimations += 1
				print("== Record Animation skipped: no decoded REC target \(animation.id) \(animation.name)")
				continue
			}
			let transformEvents = recordTransformEvents(for: target, record: record)
			let positionAnimationPath = recordPositionAnimationPath(for: animationPath)
			let positionDuration = try? positionAnimationDuration(named: positionAnimationPath)
			if positionDuration == nil, isRecordVehicleTarget(target) {
				appendRecordTransformPlayback(
					targetNode: target.node,
					events: transformEvents,
					source: target.source,
					to: &resolvedTransformPlaybacks
				)
			}

			do {
				let duration = try animationDuration(named: animationPath)
				let playbackDuration = max(duration, positionDuration ?? 0)
				let animationRoot = try recordAnimationRoot(
					for: animationPath,
					in: target.node
				)
				guard animationRoot.matches > 0 else {
					if positionDuration != nil {
						let startTime = recordAnimationStartTime(
							events: target.timingEvents,
							matching: target.event,
							duration: playbackDuration
						) ?? target.event.time
						playRecordPositionAnimation(
							named: positionAnimationPath,
							in: target.node,
							recordName: record.name,
							animationKey: "record:\(record.name):position:\(animation.id)",
							after: max(0, startTime)
						)
						positionAnimationNodeIds.insert(ObjectIdentifier(target.node))
						startedPositionAnimations += 1
					} else {
						appendRecordTransformPlayback(
							targetNode: target.node,
							events: transformEvents,
							source: target.source,
							to: &resolvedTransformPlaybacks
						)
					}
					skippedAnimations += 1
					print("== Record Animation skipped: no skeleton target \(animation.id) \(animation.name)")
					continue
				}
				let startTime = recordAnimationStartTime(
					events: target.timingEvents,
					matching: target.event,
					duration: playbackDuration
				) ?? target.event.time
				resolvedAnimations.append(RecordAnimationPlayback(
					animation: animation,
					animationPath: animationPath,
					targetNode: animationRoot.node,
					binding: target.binding,
					matchEvent: target.event,
					source: target.source,
					trackId: target.trackId,
					startTime: startTime,
					duration: duration,
					positionDistance: target.positionDistance,
					orientationDistance: target.orientationDistance,
					matches: animationRoot.matches
				))
				} catch {
					if let positionDuration = positionDuration {
						let startTime = recordAnimationStartTime(
							events: target.timingEvents,
							matching: target.event,
							duration: positionDuration
						) ?? target.event.time
						playRecordPositionAnimation(
							named: positionAnimationPath,
							in: target.node,
							recordName: record.name,
							animationKey: "record:\(record.name):position:\(animation.id)",
							after: max(0, startTime)
						)
						positionAnimationNodeIds.insert(ObjectIdentifier(target.node))
						startedPositionAnimations += 1
					} else {
					appendRecordTransformPlayback(
						targetNode: target.node,
						events: transformEvents,
						source: target.source,
						to: &resolvedTransformPlaybacks
					)
				}
				skippedAnimations += 1
				print("== Record Animation failed: \(animation.name) \(error)")
			}
		}

		var initialPoseByTarget: [ObjectIdentifier: RecordAnimationPlayback] = [:]
		for playback in resolvedAnimations where playback.startTime > 0 {
			let targetIdentifier = ObjectIdentifier(playback.targetNode)
			if initialPoseByTarget[targetIdentifier] == nil ||
				playback.startTime < initialPoseByTarget[targetIdentifier]!.startTime {
				initialPoseByTarget[targetIdentifier] = playback
			}
		}
		for playback in initialPoseByTarget.values {
			do {
				try applyAnimationInitialPose(named: playback.animationPath, in: playback.targetNode)
			} catch {
				print("== Record Animation initial pose failed: \(playback.animation.name) \(error)")
			}
		}

			for playback in resolvedAnimations {
				let animationDelay = max(0, playback.startTime)
				let animationKey = "record:\(record.name):\(playback.animation.id)"
				do {
					try playRecordAnimation(
						named: playback.animationPath,
						in: playback.targetNode,
						recordName: record.name,
						animationKey: animationKey,
						after: animationDelay
					)
					startedAnimations += 1
					let positionAnimationPath = recordPositionAnimationPath(for: playback.animationPath)
					if positionAnimationExists(named: positionAnimationPath) {
						playRecordPositionAnimation(
							named: positionAnimationPath,
							in: playback.targetNode,
							recordName: record.name,
							animationKey: animationKey + ":position",
							after: animationDelay
						)
						positionAnimationNodeIds.insert(ObjectIdentifier(playback.targetNode))
						startedPositionAnimations += 1
					}
					print(
						"== Record Animation target: \(playback.animation.name) -> \(playback.targetNode.name ?? "unnamed") " +
						"binding=\(playback.binding.map { "\($0.sourceName)/\($0.targetName)" } ?? "exact-node") " +
						"matches=\(playback.matches) " +
						"source=\(playback.source) " +
						"track=\(playback.trackId) " +
						"event=\(String(format: "0x%04x", playback.matchEvent.packedTrackId)) " +
						"eventTime=\(String(format: "%.2fs", playback.matchEvent.time)) " +
						"startTime=\(String(format: "%.2fs", playback.startTime)) " +
						"posD=\(String(format: "%.3f", playback.positionDistance)) " +
						"rotD=\(String(format: "%.3f", playback.orientationDistance)) " +
						"delay=\(String(format: "%.2f", animationDelay))s"
					)
				} catch {
					skippedAnimations += 1
					print("== Record Animation failed: \(playback.animation.name) \(error)")
				}
			}
		print(
			"== Record Animations started: \(startedAnimations) " +
			"position=\(startedPositionAnimations) skipped=\(skippedAnimations)"
		)
		for binding in record.modelBindings where !binding.transformEvents.isEmpty {
			guard let node = recordBindingTransformTargetNode(
				for: binding,
				differenceRoots: differenceRoots
			) else {
				continue
			}
			guard !node.isHiddenInRecordHierarchy else { continue }
			guard !positionAnimationNodeIds.contains(ObjectIdentifier(node)) else { continue }
			appendRecordTransformPlayback(
				targetNode: node,
				events: binding.transformEvents,
				source: "binding-transform:\(binding.sourceName)/\(binding.targetName)",
				to: &resolvedTransformPlaybacks
			)
		}
		var startedTransforms = 0
		let recordDuration = estimatedRecordDuration(record)
		for transformPlayback in resolvedTransformPlaybacks.values {
			let events = transformPlayback.sortedEvents
			guard !events.isEmpty else { continue }
			playRecordTransform(
				transformPlayback,
				recordName: record.name,
				duration: recordDuration
			)
			startedTransforms += 1
			print(
				"== Record Transform target: \(transformPlayback.targetNode.name ?? "unnamed") " +
				"keys=\(events.count) " +
				"sources=\(transformPlayback.sources.sorted().joined(separator: ",")) " +
				"first=\(String(format: "%.2fs", events.first?.time ?? 0)) " +
				"last=\(String(format: "%.2fs", events.last?.time ?? 0))"
			)
		}
		print("== Record Transforms started: \(startedTransforms)")
		playRecordCamera(record)
		playRecordEvents(record)
		playRecordSpeech(record, animations: resolvedAnimations, showsSubtitles: full)
		playRecordSounds(record)
		startActiveRecordPlayback(record, duration: recordDuration)
	}

	private func recordAnimationStartTime(
		events animationEvents: [RecordAnimationEvent],
		matching event: RecordAnimationEvent,
		duration: TimeInterval
	) -> TimeInterval? {
		let matchedEvents: [RecordAnimationEvent]
		if event.trackId >= 0 {
			matchedEvents = animationEvents.filter { $0.trackId == event.trackId }
		} else {
			matchedEvents = animationEvents
		}
		let events = matchedEvents.isEmpty ? animationEvents : matchedEvents
		return events
			.map { max(0, $0.time - $0.animationStartOffset) }
			.min()
	}

	private func playRecordAnimation(
		named name: String,
		in node: SCNNode,
		recordName: String,
		animationKey: String,
		after delay: TimeInterval
	) throws {
		guard delay > 0 else {
			stopRecordAnimationActions(in: node, recordName: recordName, keeping: animationKey)
			try playAnimation(named: name, in: node, animationKey: animationKey, includePositionAnimation: false)
			return
		}

		node.runAction(SCNAction.sequence([
			.wait(duration: delay),
			.run { [weak self] node in
				do {
					self?.stopRecordAnimationActions(in: node, recordName: recordName, keeping: animationKey)
					try playAnimation(named: name, in: node, animationKey: animationKey, includePositionAnimation: false)
				} catch {
					print("== Record Animation failed delayed: \(name) \(error)")
				}
			}
		]), forKey: animationKey + ":schedule")
	}

	private func playRecordPositionAnimation(
		named name: String,
		in node: SCNNode,
		recordName: String,
		animationKey: String,
		after delay: TimeInterval
	) {
		rememberRecordTransform(for: node)
		guard delay > 0 else {
			node.removeAction(forKey: animationKey)
			do {
				try playPositionAnimation(named: name, in: node, animationKey: animationKey)
			} catch {
				print("== Record Position Animation failed: \(name) \(error)")
			}
			return
		}

		node.runAction(SCNAction.sequence([
			.wait(duration: delay),
			.run { node in
				node.removeAction(forKey: animationKey)
				do {
					try playPositionAnimation(named: name, in: node, animationKey: animationKey)
				} catch {
					print("== Record Position Animation failed delayed: \(name) \(error)")
				}
			}
		]), forKey: animationKey + ":schedule")
	}

	private func recordPositionAnimationPath(for animationPath: String) -> String {
		let lowercasedPath = animationPath.lowercased()
		if lowercasedPath.hasSuffix(".5ds") {
			return String(animationPath.dropLast(4)) + ".tck"
		}
		return animationPath + ".tck"
	}

	private func stopRecordAnimationActions(in node: SCNNode, recordName: String, keeping animationKey: String) {
		let recordKeyPrefix = "record:\(recordName):"
		for actionKey in node.actionKeys {
			guard actionKey.hasPrefix(recordKeyPrefix),
				  !actionKey.contains(":transform:"),
				  actionKey != animationKey,
				  actionKey != animationKey + ":schedule",
				  !actionKey.hasSuffix(":schedule") else {
				continue
			}
			node.removeAction(forKey: actionKey)
		}
		for childNode in node.childNodes {
			stopRecordAnimationActions(in: childNode, recordName: recordName, keeping: animationKey)
		}
	}

	private func recordTransformEvents(
		for target: RecordAnimationTargetMatch,
		record: Record
	) -> [RecordAnimationEvent] {
		if target.trackId >= 0 {
			let trackEvents = record.animationEvents.filter { $0.trackId == target.trackId }
			if !trackEvents.isEmpty {
				return trackEvents
			}
		}
		return target.timingEvents
	}

	private func isRecordVehicleTarget(_ target: RecordAnimationTargetMatch) -> Bool {
		return target.binding?.targetName.lowercased().hasPrefix("car") == true
	}

	private func recordBindingTransformTargetNode(
		for binding: RecordModelBinding,
		differenceRoots: [SCNNode]
	) -> SCNNode? {
		let name = binding.sourceName
		if let differenceNode = recordNode(named: name, in: differenceRoots) {
			return differenceNode
		}
		if let renderNode = recordNode(named: name, in: [game.scnScene.rootNode], excluding: rootNode) {
			return renderNode
		}
		if let sceneNode = recordNode(named: name, in: [rootNode]) {
			return sceneNode
		}
		if binding.targetName.lowercased().hasPrefix("car"),
		   let vehicle = game.vehicle {
			return vehicle.scriptNode.liveTransformNode ?? vehicle.node
		}
		return nil
	}

	private func createRecordPropNodes(for record: Record, existingRoots: [SCNNode]) -> [SCNNode] {
		var createdNodes: [SCNNode] = []
		var createdNames = Set<String>()
		for binding in record.modelBindings {
			let sourceName = binding.sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !sourceName.isEmpty else { continue }
			let lowercasedName = sourceName.lowercased()
			guard createdNames.insert(lowercasedName).inserted else { continue }
			guard recordNode(named: sourceName, in: existingRoots + createdNodes) == nil else { continue }
			guard let modelPath = recordPropModelPath(for: sourceName) else { continue }

			let propNode = SCNNode()
			propNode.name = sourceName
			do {
				try loadModel(named: modelPath, node: propNode)
				guard propNode.hasModelContent else { continue }
				propNode.disablePhysicsInHierarchy()
				rootNode.addChildNode(propNode)
				registerNodeTree(propNode)
				activeRecordPropNodes.append(propNode)
				createdNodes.append(propNode)
				print("== Record Prop created: \(sourceName) model=\(modelPath)")
			} catch {
				print("== Record Prop failed: \(sourceName) model=\(modelPath) \(error)")
			}
		}
		return createdNodes
	}

	private func recordPropModelPath(for name: String) -> String? {
		let normalizedName = name
			.replacingOccurrences(of: "\\", with: "/")
			.replacingOccurrences(of: ".i3d", with: "", options: [.caseInsensitive])
			.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalizedName.isEmpty else { return nil }

		let modelPath = normalizedName.contains("/") ? normalizedName : "models/" + normalizedName
		let url = mainDirectory.appendingPathComponent(modelPath.lowercased() + ".4ds")
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		return modelPath
	}

	private func recordNode(
		named name: String,
		in roots: [SCNNode],
		excluding excludedRoot: SCNNode? = nil
	) -> SCNNode? {
		let candidates = roots.flatMap { [$0] + $0.flattenedChildNodes }
			.filter { node in
				guard let excludedRoot = excludedRoot else { return true }
				return !node.isInHierarchy(of: excludedRoot)
			}
		if let dottedNode = recordDottedNode(named: name, in: candidates) {
			return dottedNode
		}
		if let exactNode = candidates.first(where: { $0.name == name }) {
			return exactNode
		}

		let lowercasedName = name.lowercased()
		if let caseInsensitiveNode = candidates.first(where: { $0.name?.lowercased() == lowercasedName }) {
			return caseInsensitiveNode
		}

		guard name.count >= 16 else { return nil }
		return candidates.first { node in
			node.name?.lowercased().hasPrefix(lowercasedName) == true
		}
	}

	private func recordDottedNode(named name: String, in candidates: [SCNNode]) -> SCNNode? {
		let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
		guard parts.count == 2 else { return nil }

		let parentName = parts[0]
		let childName = parts[1]
		for parentNode in candidates where recordNodeName(parentNode.name, matches: parentName) {
			if let childNode = parentNode.mafiaChildNode(named: childName, recursively: true) {
				return childNode
			}
		}
		return nil
	}

	private func recordNodeName(_ candidate: String?, matches name: String) -> Bool {
		guard let candidate = candidate?.lowercased(),
			  !candidate.isEmpty else {
			return false
		}
		let name = name.lowercased()
		return candidate == name ||
			(candidate.count >= 16 && candidate.hasPrefix(name)) ||
			(name.count >= 16 && name.hasPrefix(candidate))
	}

	private func appendRecordTransformPlayback(
		targetNode: SCNNode,
		events: [RecordAnimationEvent],
		source: String,
		to playbacks: inout [ObjectIdentifier: RecordTransformPlayback]
	) {
		guard !events.isEmpty else { return }
		rememberRecordTransform(for: targetNode)
		let targetIdentifier = ObjectIdentifier(targetNode)
		let playback = playbacks[targetIdentifier] ?? RecordTransformPlayback(targetNode: targetNode)
		playback.append(events: events, source: source)
		playbacks[targetIdentifier] = playback
	}

	private func rememberRecordTransform(for node: SCNNode) {
		let identifier = ObjectIdentifier(node)
		guard activeRecordTransformRestores[identifier] == nil else { return }
		activeRecordTransformRestores[identifier] = (node, node.transform)
	}

	private func playRecordTransform(
		_ playback: RecordTransformPlayback,
		recordName: String,
		duration: TimeInterval
	) {
		let events = playback.sortedEvents
		guard !events.isEmpty else { return }

		let actionKey = "record:\(recordName):transform:\(ObjectIdentifier(playback.targetNode).hashValue)"
		playback.targetNode.removeAction(forKey: actionKey)
		Self.applyRecordTransform(events: events, at: 0, to: playback.targetNode)
		let actionDuration = max(duration, events.last?.time ?? 0)
		guard actionDuration > 0 else { return }
		playback.targetNode.runAction(
			SCNAction.customAction(duration: actionDuration) { node, elapsedTime in
				Self.applyRecordTransform(events: events, at: TimeInterval(elapsedTime), to: node)
			},
			forKey: actionKey
		)
	}

	private static func applyRecordTransform(
		events: [RecordAnimationEvent],
		at time: TimeInterval,
		to node: SCNNode
	) {
		guard let firstEvent = events.first else { return }
		guard time > firstEvent.time else {
			applyRecordTransform(event: firstEvent, to: node)
			return
		}

		guard let lastEvent = events.last,
			  time <= lastEvent.time else {
			applyRecordTransform(event: events[events.count - 1], to: node)
			return
		}

		var lowerBound = 0
		var upperBound = events.count - 1
		while lowerBound < upperBound {
			let middle = (lowerBound + upperBound) / 2
			if time > events[middle].time {
				lowerBound = middle + 1
			} else {
				upperBound = middle
			}
		}

		let nextIndex = lowerBound
		guard nextIndex > 0 else {
			applyRecordTransform(event: firstEvent, to: node)
			return
		}

		let previousEvent = events[nextIndex - 1]
		let nextEvent = events[nextIndex]
		let span = nextEvent.time - previousEvent.time
		let progress = span <= 0 ? 1 : CGFloat((time - previousEvent.time) / span)
		applyRecordTransform(
			previous: events[max(0, nextIndex - 2)],
			current: previousEvent,
			next: nextEvent,
			following: events[min(events.count - 1, nextIndex + 1)],
			progress: progress,
			node: node
		)
	}

	private static func applyRecordTransform(event: RecordAnimationEvent, to node: SCNNode) {
		node.position = event.position
		node.orientation = recordOrientation(from: event.orientationVector, fallback: node.orientation)
	}

	private static func applyRecordTransform(
		previous previousEvent: RecordAnimationEvent,
		current currentEvent: RecordAnimationEvent,
		next nextEvent: RecordAnimationEvent,
		following followingEvent: RecordAnimationEvent,
		progress: CGFloat,
		node: SCNNode
	) {
		let amount = max(0, min(1, SCNFloat(progress)))
		node.position = recordCatmullRom(
			previousEvent.position,
			currentEvent.position,
			nextEvent.position,
			followingEvent.position,
			amount
		)
		let orientationVector = SCNVector3(
			x: currentEvent.orientationVector.x + (nextEvent.orientationVector.x - currentEvent.orientationVector.x) * amount,
			y: currentEvent.orientationVector.y + (nextEvent.orientationVector.y - currentEvent.orientationVector.y) * amount,
			z: currentEvent.orientationVector.z + (nextEvent.orientationVector.z - currentEvent.orientationVector.z) * amount
		)
		node.orientation = recordOrientation(from: orientationVector, fallback: node.orientation)
	}

	private static func recordCatmullRom(
		_ previous: SCNVector3,
		_ current: SCNVector3,
		_ next: SCNVector3,
		_ following: SCNVector3,
		_ progress: SCNFloat
	) -> SCNVector3 {
		let progress2 = progress * progress
		let progress3 = progress2 * progress
		return SCNVector3(
			x: 0.5 * (
				2 * current.x +
				(-previous.x + next.x) * progress +
				(2 * previous.x - 5 * current.x + 4 * next.x - following.x) * progress2 +
				(-previous.x + 3 * current.x - 3 * next.x + following.x) * progress3
			),
			y: 0.5 * (
				2 * current.y +
				(-previous.y + next.y) * progress +
				(2 * previous.y - 5 * current.y + 4 * next.y - following.y) * progress2 +
				(-previous.y + 3 * current.y - 3 * next.y + following.y) * progress3
			),
			z: 0.5 * (
				2 * current.z +
				(-previous.z + next.z) * progress +
				(2 * previous.z - 5 * current.z + 4 * next.z - following.z) * progress2 +
				(-previous.z + 3 * current.z - 3 * next.z + following.z) * progress3
			)
		)
	}

	private static func recordOrientation(
		from vector: SCNVector3,
		fallback: SCNQuaternion
	) -> SCNQuaternion {
		return SCNQuaternion(
			x: vector.y,
			y: vector.z,
			z: fallback.z,
			w: -vector.x
		)
	}

	private func recordAnimationRoot(
		for animationPath: String,
		in targetNode: SCNNode
	) throws -> (node: SCNNode, matches: Int) {
		let (animations, _) = try loadAnimation(named: animationPath)
		let animationNameCounts = Dictionary(
			grouping: animations.map { $0.name.lowercased() },
			by: { $0 }
		).mapValues { $0.count }
		var best = (node: targetNode, matches: 0, order: 0)
		var order = 0
		_ = recordAnimationSubtreeMatchCount(
			in: targetNode,
			animationNameCounts: animationNameCounts,
			best: &best,
			order: &order
		)
		return (node: best.node, matches: best.matches)
	}

	private func recordAnimationSubtreeMatchCount(
		in node: SCNNode,
		animationNameCounts: [String: Int],
		best: inout (node: SCNNode, matches: Int, order: Int),
		order: inout Int
	) -> (names: Set<String>, matches: Int) {
		let nodeOrder = order
		order += 1
		var subtreeNames = Set<String>()
		for childNode in node.childNodes {
			let childMatches = recordAnimationSubtreeMatchCount(
				in: childNode,
				animationNameCounts: animationNameCounts,
				best: &best,
				order: &order
			)
			subtreeNames.formUnion(childMatches.names)
		}
		if let name = node.name?.lowercased(),
		   animationNameCounts[name] != nil {
			subtreeNames.insert(name)
		}

		let matches = subtreeNames.reduce(0) { count, name in
			count + (animationNameCounts[name] ?? 0)
		}
		if matches > best.matches || (matches == best.matches && nodeOrder < best.order) {
			best = (node, matches, nodeOrder)
		}
		return (subtreeNames, matches)
	}

	private func recordAnimationTarget(
		animation: RecordAnimation,
		animationPath: String,
		record: Record,
		lookup: RecordAnimationLookup
	) -> RecordAnimationTargetMatch? {
		func vectorDistance(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNFloat {
			let x = lhs.x - rhs.x
			let y = lhs.y - rhs.y
			let z = lhs.z - rhs.z
			return sqrt(x * x + y * y + z * z)
		}

		func sourcePosition(of node: SCNNode) -> SCNVector3 {
			return node.recordSourcePosition ?? node.position
		}

		func sourceOrientation(of node: SCNNode) -> SCNVector3 {
			return SCNVector3(
				x: node.recordSourceOrientationVector?.x ?? node.orientation.x,
				y: node.recordSourceOrientationVector?.y ?? node.orientation.y,
				z: node.recordSourceOrientationVector?.z ?? node.orientation.z
			)
		}

		func positionTolerance(for binding: RecordModelBinding?) -> SCNFloat {
			guard let targetName = binding?.targetName.lowercased() else { return 1.0 }
			return targetName.hasPrefix("car") ? 80.0 : 1.0
		}

		func skeletonMatchCount(in node: SCNNode) -> Int {
			return lookup.skeletonMatchCount(for: animationPath, in: node) { animationPath, node in
				try recordAnimationRoot(for: animationPath, in: node)
			}
		}

		var cachedSkeletonCompatibleNodeIds: Set<ObjectIdentifier>?
		func skeletonCompatibleNodeIds() -> Set<ObjectIdentifier> {
			if let cachedSkeletonCompatibleNodeIds = cachedSkeletonCompatibleNodeIds {
				return cachedSkeletonCompatibleNodeIds
			}
			let compatibleNodeIds = Set(
				lookup.bindingNodes
					.filter { skeletonMatchCount(in: $0.node) > 0 }
					.map { ObjectIdentifier($0.node) }
			)
			cachedSkeletonCompatibleNodeIds = compatibleNodeIds
			return compatibleNodeIds
		}

		let directAnimationEvents = recordAnimationEvents(for: animation, lookup: lookup)
		let animationEvents: [RecordAnimationEvent]
		let sourcePrefix: String
		if directAnimationEvents.isEmpty {
			guard let sequenceEvents = recordSequenceAnimationEvents(
				animation: animation,
				record: record,
				lookup: lookup
			) else {
				return nil
			}
			animationEvents = sequenceEvents.events
			sourcePrefix = "sequence-table:\(sequenceEvents.animation.id)/"
		} else {
			animationEvents = directAnimationEvents
			sourcePrefix = ""
		}
		let eventTrackIds = Set(animationEvents.map(\.trackId).filter { $0 >= 0 })
		let targetEvents: [RecordAnimationEvent]
		if eventTrackIds.count == 1, let trackId = eventTrackIds.first {
			targetEvents = lookup.animationEventsByTrackId[trackId] ?? []
		} else {
			targetEvents = animationEvents
		}
		let targetResolutionEvents = recordAnimationTargetResolutionEvents(from: targetEvents)
		guard !targetResolutionEvents.isEmpty else { return nil }

		struct LinkedTargetCandidate {
			let targetNode: SCNNode
			let binding: RecordModelBinding?
			let anchorName: String
			let event: RecordAnimationEvent
			let positionDistance: SCNFloat
			let orientationDistance: SCNFloat
			let score: SCNFloat
		}

		var linkedCandidates: [LinkedTargetCandidate] = []
		for (_, links) in lookup.targetLinksByGroup {
			guard let targetLink = links.first(where: { $0.role == 1 }),
				  let targetNode = lookup.node(named: targetLink.name) else {
				continue
			}
			let targetBinding = lookup.binding(for: targetNode)
			let tolerance = positionTolerance(for: targetBinding)

			for anchorLink in links {
				guard let anchorNode = lookup.node(named: anchorLink.name) else { continue }
				let anchorPosition = sourcePosition(of: anchorNode)
				let anchorOrientation = sourceOrientation(of: anchorNode)
				for event in targetResolutionEvents {
					let positionDistance = vectorDistance(event.position, anchorPosition)
					let orientationDistance = vectorDistance(event.orientationVector, anchorOrientation)
					guard positionDistance <= tolerance,
						  orientationDistance <= 0.15 else {
						continue
					}
					let score = positionDistance + orientationDistance * 8
					linkedCandidates.append(LinkedTargetCandidate(
						targetNode: targetNode,
						binding: targetBinding,
						anchorName: anchorLink.name,
						event: event,
						positionDistance: positionDistance,
						orientationDistance: orientationDistance,
						score: score
					))
				}
			}
		}

		if !linkedCandidates.isEmpty {
			let compatibleNodeIds = skeletonCompatibleNodeIds()
			let candidates = compatibleNodeIds.isEmpty ?
				linkedCandidates :
				linkedCandidates.filter { compatibleNodeIds.contains(ObjectIdentifier($0.targetNode)) }
			let bestLinkedCandidate = candidates.min {
				if $0.score == $1.score {
					return $0.event.time > $1.event.time
				}
				return $0.score < $1.score
			}
			guard let bestLinkedCandidate = bestLinkedCandidate else { return nil }
			return RecordAnimationTargetMatch(
				node: bestLinkedCandidate.targetNode,
				binding: bestLinkedCandidate.binding,
				event: bestLinkedCandidate.event,
				timingEvents: animationEvents,
				source: sourcePrefix + "target-link:\(bestLinkedCandidate.anchorName)",
				trackId: bestLinkedCandidate.event.trackId,
				positionDistance: bestLinkedCandidate.positionDistance,
				orientationDistance: bestLinkedCandidate.orientationDistance
			)
		}

		struct TransformCandidate {
			let node: SCNNode
			let binding: RecordModelBinding
			let event: RecordAnimationEvent
			let positionDistance: SCNFloat
			let orientationDistance: SCNFloat
			let score: SCNFloat
		}
		var transformCandidates: [TransformCandidate] = []
		for event in targetResolutionEvents {
			for bindingNode in lookup.bindingNodes {
				let positionDistance = vectorDistance(event.position, sourcePosition(of: bindingNode.node))
				let orientationDistance = vectorDistance(event.orientationVector, sourceOrientation(of: bindingNode.node))
				guard positionDistance <= positionTolerance(for: bindingNode.binding),
					  orientationDistance <= 0.15 else {
					continue
				}
				transformCandidates.append(TransformCandidate(
					node: bindingNode.node,
					binding: bindingNode.binding,
					event: event,
					positionDistance: positionDistance,
					orientationDistance: orientationDistance,
					score: positionDistance + orientationDistance * 8
				))
			}
		}

		guard !transformCandidates.isEmpty else { return nil }
		let compatibleNodeIds = skeletonCompatibleNodeIds()
		let candidates = compatibleNodeIds.isEmpty ?
			transformCandidates :
			transformCandidates.filter { compatibleNodeIds.contains(ObjectIdentifier($0.node)) }
		guard let bestCandidate = candidates.min(by: {
			if $0.score == $1.score {
				return $0.event.time > $1.event.time
			}
			return $0.score < $1.score
		}) else {
			return nil
		}

		return RecordAnimationTargetMatch(
			node: bestCandidate.node,
			binding: bestCandidate.binding,
			event: bestCandidate.event,
			timingEvents: animationEvents,
			source: sourcePrefix + "transform-table",
			trackId: bestCandidate.event.trackId,
			positionDistance: bestCandidate.positionDistance,
			orientationDistance: bestCandidate.orientationDistance
		)
	}

	private func recordAnimationTargetResolutionEvents(
		from events: [RecordAnimationEvent]
	) -> [RecordAnimationEvent] {
		let groupedEvents = Dictionary(grouping: events.filter { $0.trackId >= 0 }, by: \.trackId)
		guard !groupedEvents.isEmpty else { return events }

		return groupedEvents.values.flatMap { trackEvents in
			trackEvents
		}.sorted {
			if $0.trackId == $1.trackId {
				return $0.time < $1.time
			}
			return $0.trackId < $1.trackId
		}
	}

	private func recordAnimationEvents(
		for animation: RecordAnimation,
		lookup: RecordAnimationLookup
	) -> [RecordAnimationEvent] {
		var events = lookup.animationEventsByAnimationId[animation.id] ?? []
		if animation.index != animation.id {
			events += lookup.animationEventsByAnimationId[animation.index] ?? []
		}
		return events
	}

	private func recordHasAnimationEvents(
		for animation: RecordAnimation,
		lookup: RecordAnimationLookup
	) -> Bool {
		return !(lookup.animationEventsByAnimationId[animation.id]?.isEmpty ?? true) ||
			(animation.index != animation.id && !(lookup.animationEventsByAnimationId[animation.index]?.isEmpty ?? true))
	}

	private func recordSequenceAnimationEvents(
		animation: RecordAnimation,
		record: Record,
		lookup: RecordAnimationLookup
	) -> (animation: RecordAnimation, events: [RecordAnimationEvent])? {
		guard let animationIndex = record.animations.firstIndex(where: { $0.id == animation.id }),
			  !recordHasAnimationEvents(for: animation, lookup: lookup) else {
			return nil
		}

		var missingStartIndex = animationIndex
		while missingStartIndex > 0 {
			let previousAnimation = record.animations[missingStartIndex - 1]
			guard !recordHasAnimationEvents(for: previousAnimation, lookup: lookup) else { break }
			missingStartIndex -= 1
		}

		var missingEndIndex = animationIndex
		while missingEndIndex + 1 < record.animations.count {
			let nextAnimation = record.animations[missingEndIndex + 1]
			guard !recordHasAnimationEvents(for: nextAnimation, lookup: lookup) else { break }
			missingEndIndex += 1
		}

		let relativeIndex = animationIndex - missingStartIndex
		let donorIndex = missingEndIndex + 1 + relativeIndex
		guard donorIndex < record.animations.count else { return nil }

		let donorAnimation = record.animations[donorIndex]
		let donorEvents = recordAnimationEvents(for: donorAnimation, lookup: lookup)
		guard !donorEvents.isEmpty else { return nil }
		return (donorAnimation, donorEvents)
	}

	private func playRecordSounds(_ record: Record) {
		var soundsByName: [String: RecordSoundBinding] = [:]
		for (node, sound) in sounds {
			guard let name = node.name, !name.isEmpty else { continue }
			soundsByName[name.lowercased()] = RecordSoundBinding(
				fileName: sound.url.lastPathComponent,
				url: sound.url,
				node: node
			)
		}
		for sound in loadedDifferenceFiles.values.flatMap({ $0.sounds }) {
			guard let url = mafiaResourceURL(directory: "sounds", name: sound.fileName) else {
				continue
			}
			soundsByName[sound.name.lowercased()] = RecordSoundBinding(
				fileName: sound.fileName,
				url: url,
				node: sound.node
			)
		}

		guard !soundsByName.isEmpty else {
			print("== Record Sounds skipped: no scene or difference sounds")
			return
		}

		let soundEvents = record.timedEvents
			.filter { !$0.isStop }
			.compactMap { event -> (event: RecordTimedEvent, sound: RecordSoundBinding)? in
				guard let sound = soundsByName[event.name.lowercased()] else { return nil }
				return (event, sound)
			}

		guard !soundEvents.isEmpty else {
			print("== Record Sounds skipped: no timed sound events")
			return
		}

		let lastSoundTime = soundEvents.map { $0.event.time }.max() ?? 0
		print(
			"== Record Sounds scheduling: \(soundEvents.count)/\(record.timedEvents.count) " +
			"last=\(String(format: "%.2f", lastSoundTime))s"
		)
		var scheduledCount = 0
		for (event, sound) in soundEvents {
			let scheduledSound = ScheduledRecordSound(
				url: sound.url,
				node: sound.node,
				fallbackNode: rootNode,
				soundName: event.name,
				fileName: sound.fileName,
				eventTime: event.time
			)
			activeRecordSoundSchedules.append(scheduledSound)
			scheduleRecordSound(scheduledSound, after: event.time)
			scheduledCount += 1
		}
		print("== Record Sounds scheduled: \(scheduledCount)")
	}

	private func playRecordSpeech(
		_ record: Record,
		animations: [RecordAnimationPlayback],
		showsSubtitles: Bool
	) {
		guard !record.speechEvents.isEmpty else {
			return
		}

		let lastSpeechTime = record.speechEvents.map { $0.time }.max() ?? 0
		print(
			"== Record Speech scheduling: \(record.speechEvents.count) " +
			"last=\(String(format: "%.2f", lastSpeechTime))s"
		)
		var scheduledCount = 0
		for event in record.speechEvents {
			let fileName = event.fileName
			guard let url = mafiaResourceURL(directory: "sounds", name: fileName) else {
				print("== Record Speech missing: \(fileName)")
				continue
			}

			let scheduledSound = ScheduledRecordSound(
				url: url,
				node: game?.cameraNode,
				fallbackNode: rootNode,
				soundName: "speech \(event.soundId)",
				fileName: fileName,
				eventTime: event.time,
				subtitleText: showsSubtitles ? TextDb.get(event.soundId) : nil
			)
			activeRecordSoundSchedules.append(scheduledSound)
			scheduleRecordSound(scheduledSound, after: event.time)
			if let speechTarget = recordSpeechTarget(for: event, animations: animations) {
				scheduleRecordFaceAnimation(
					soundId: event.soundId,
					in: speechTarget,
					after: event.time
				)
			} else {
				logRecordFaceAnimationTargetFailure(for: event, animations: animations)
			}
			scheduledCount += 1
		}

		print("== Record Speech scheduled: \(scheduledCount)")
	}

	private func playRecordEvents(_ record: Record) {
		let events = record.timedEvents.filter { !$0.isStop }
		guard !events.isEmpty else { return }

		activeRecordEventScriptNames.formUnion(events.map(\.name))
		print("== Record Events scheduling: \(events.count)")
		for event in events {
			let scheduledEvent = ScheduledRecordEvent(recordName: record.name, event: event)
			activeRecordEventSchedules.append(scheduledEvent)
			scheduleRecordEvent(scheduledEvent, after: event.time)
		}
	}

	private func scheduleRecordEvent(_ scheduledEvent: ScheduledRecordEvent, after delay: TimeInterval) {
		scheduledEvent.workItem?.cancel()
		scheduledEvent.workItem = nil
		scheduledEvent.deadline = nil
		scheduledEvent.remaining = delay
		guard !game.isGamePaused else { return }

		let workItem = DispatchWorkItem { [weak self, weak scheduledEvent] in
			guard let self = self,
				  let scheduledEvent = scheduledEvent,
				  !scheduledEvent.didDispatch,
				  self.activeRecordNames.contains(scheduledEvent.recordName) else { return }
			scheduledEvent.didDispatch = true
			scheduledEvent.workItem = nil
			scheduledEvent.deadline = nil
			self.dispatchRecordEvent(scheduledEvent.event)
		}
		scheduledEvent.workItem = workItem
		scheduledEvent.deadline = Date.timeIntervalSinceReferenceDate + delay
		DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
	}

	private func dispatchRecordEvent(_ event: RecordTimedEvent) {
		var didDispatch = false
		if let script = scripts[event.name] ?? initScripts[event.name] {
			print("== Record Event script: \(String(format: "%.2f", event.time))s \(event.name)")
			script.restart()
			didDispatch = true
		}

		let allScripts = Array(initScripts.values) + Array(scripts.values)
		for script in allScripts where script.events[event.name] != nil {
			print("== Record Event enqueue: \(String(format: "%.2f", event.time))s \(event.name)")
			script.enqueueEvent(event.name)
			didDispatch = true
		}

		if !didDispatch && event.name.hasPrefix("Music") {
			print("== Record Event missing music handler: \(event.name)")
		}
	}

	private func logRecordFaceAnimationTargetFailure(
		for event: RecordSpeechEvent,
		animations: [RecordAnimationPlayback]
	) {
		let faceFileName = String(format: "%08d.dat", event.soundId)
		guard hasFaceAnimation(soundId: event.soundId) else {
			print(
				"== Record Face Animation failed: missing \(faceFileName) " +
				"speech=\(event.soundId) channel=\(event.channelId) " +
				"speaker=\(event.speakerFrameName ?? "none") " +
				"time=\(String(format: "%.2f", event.time))s"
			)
			return
		}

		guard let speakerFrameName = event.speakerFrameName,
			  !speakerFrameName.isEmpty else {
			print(
				"== Record Face Animation failed: no speaker binding \(faceFileName) " +
				"speech=\(event.soundId) channel=\(event.channelId) " +
				"time=\(String(format: "%.2f", event.time))s"
			)
			return
		}

		let morpherAnimations = animations.filter { hasFaceAnimationTarget(in: $0.targetNode) }
		let activeAnimations = animations.filter {
			recordFaceAnimationContains(event.time, in: $0, tolerance: 0)
		}
		let activeMorpherAnimations = morpherAnimations.filter {
			recordFaceAnimationContains(event.time, in: $0, tolerance: recordFaceAnimationTimeTolerance)
		}
		let activeAnimationDescriptions = activeAnimations
			.prefix(3)
			.map { playback in
				recordFaceAnimationTargetDescription(playback, at: event.time)
			}
			.joined(separator: "; ")
		let nearestMorpherAnimations = morpherAnimations
			.sorted {
				recordFaceAnimationDistance(from: event.time, to: $0) <
					recordFaceAnimationDistance(from: event.time, to: $1)
			}
			.prefix(3)
			.map { playback in
				recordFaceAnimationTargetDescription(playback, at: event.time)
			}
			.joined(separator: "; ")
		print(
			"== Record Face Animation failed: no target \(faceFileName) " +
			"speech=\(event.soundId) channel=\(event.channelId) speaker=\(speakerFrameName) " +
			"time=\(String(format: "%.2f", event.time))s " +
			"activeAnimations=\(activeAnimations.count) active=[\(activeAnimationDescriptions)] " +
			"morphTargets=\(morpherAnimations.count) activeMorphTargets=\(activeMorpherAnimations.count) " +
			"nearest=[\(nearestMorpherAnimations)]"
		)
	}

	private func recordFaceAnimationDistance(
		from time: TimeInterval,
		to playback: RecordAnimationPlayback
	) -> TimeInterval {
		let endTime = playback.startTime + playback.duration
		if time < playback.startTime {
			return playback.startTime - time
		}
		if time > endTime {
			return time - endTime
		}
		return 0
	}

	private func recordFaceAnimationContains(
		_ time: TimeInterval,
		in playback: RecordAnimationPlayback,
		tolerance: TimeInterval
	) -> Bool {
		return time >= playback.startTime - tolerance &&
			time <= playback.startTime + playback.duration + tolerance
	}

	private func recordFaceAnimationTargetDescription(
		_ playback: RecordAnimationPlayback,
		at time: TimeInterval
	) -> String {
		let endTime = playback.startTime + playback.duration
		return "\(playback.animation.name)->\(playback.targetNode.name ?? "unnamed") " +
			"start=\(String(format: "%.2f", playback.startTime))s " +
			"end=\(String(format: "%.2f", endTime))s " +
			"delta=\(String(format: "%.2f", recordFaceAnimationDistance(from: time, to: playback)))s " +
			"track=\(playback.trackId)"
	}

	private func recordSpeechTarget(
		for event: RecordSpeechEvent,
		animations: [RecordAnimationPlayback]
	) -> SCNNode? {
		guard hasFaceAnimation(soundId: event.soundId) else { return nil }
		guard let speakerFrameName = event.speakerFrameName,
			  !speakerFrameName.isEmpty else {
			return nil
		}

		return animations
			.filter { hasFaceAnimationTarget(in: $0.targetNode) }
			.first { recordSpeechTarget($0, matches: speakerFrameName) }?
			.targetNode
	}

	private func recordSpeechTarget(
		_ playback: RecordAnimationPlayback,
		matches speakerFrameName: String
	) -> Bool {
		if recordName(playback.targetNode.name, matches: speakerFrameName) {
			return true
		}
		if let binding = playback.binding,
		   recordName(binding.sourceName, matches: speakerFrameName) ||
			recordName(binding.targetName, matches: speakerFrameName) ||
			recordName(binding.extraName, matches: speakerFrameName) {
			return true
		}
		return playback.targetNode.flattenedChildNodes.contains { childNode in
			recordName(childNode.name, matches: speakerFrameName)
		}
	}

	private func recordName(_ candidate: String?, matches recordName: String) -> Bool {
		guard let candidate = candidate?.lowercased(),
			  !candidate.isEmpty else {
			return false
		}
		let recordName = recordName.lowercased()
		return candidate == recordName ||
			(candidate.count >= 16 && candidate.hasPrefix(recordName)) ||
			(recordName.count >= 16 && recordName.hasPrefix(candidate))
	}

	private func scheduleRecordFaceAnimation(
		soundId: Int,
		in node: SCNNode,
		after delay: TimeInterval
	) {
		let actionKey = "record:face:\(soundId):\(delay)"
		node.runAction(SCNAction.sequence([
			.wait(duration: max(0, delay)),
			.run { node in
				do {
					try playFaceAnimation(
						soundId: soundId,
						in: node,
						animationKey: actionKey
					)
				} catch {
					print("== Record Face Animation failed: \(soundId) \(error)")
				}
			}
		]), forKey: actionKey + ":schedule")
	}

	private func scheduleRecordSound(_ scheduledSound: ScheduledRecordSound, after delay: TimeInterval) {
		scheduledSound.workItem?.cancel()
		scheduledSound.workItem = nil
		scheduledSound.deadline = nil
		scheduledSound.remaining = delay
		guard !isAudioPaused else { return }

		let workItem = DispatchWorkItem { [weak self, weak scheduledSound] in
			guard let self = self,
				  let scheduledSound = scheduledSound,
				  !scheduledSound.didPlay else { return }
			scheduledSound.didPlay = true
			scheduledSound.workItem = nil
			scheduledSound.deadline = nil
			print(
				"== Record Sound play: " +
				"\(String(format: "%.2f", scheduledSound.eventTime))s " +
				"\(scheduledSound.soundName) \(scheduledSound.fileName)"
			)
			guard let source = SCNAudioSource(url: scheduledSound.url) else {
				print("== Record Sound failed: \(scheduledSound.fileName)")
				return
			}
			source.isPositional = false
			source.load()
			if let subtitleText = scheduledSound.subtitleText {
				self.game.showCutsceneSubtitleText(
					subtitleText,
					duration: self.audioDuration(url: scheduledSound.url) ?? 4
				)
			}
			self.playAudio(
				source,
				url: scheduledSound.url,
				on: scheduledSound.node ?? scheduledSound.fallbackNode
			)
		}
		scheduledSound.workItem = workItem
		scheduledSound.deadline = Date.timeIntervalSinceReferenceDate + delay
		DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
	}

	func estimatedRecordDuration(_ record: Record) -> TimeInterval {
		let durations = record.animations.compactMap { animation -> TimeInterval? in
			let animationName = animation.name.replacingOccurrences(
				of: ".i3d",
				with: ".5ds",
				options: [.caseInsensitive]
			)
			return try? loadAnimation(named: "anims/" + animationName).1
		}
		let lastEventTime = record.timedEvents.map(\.time).max() ?? 0
		let lastSpeechTime = record.speechEvents.map(\.time).max() ?? 0
		let lastCameraTime = record.cameraKeyframes.map(\.time).max() ?? 0
		let lastAnimationEventTime = record.animationEvents.map(\.time).max() ?? 0
		return [
			lastCameraTime,
			durations.max() ?? 0,
			lastAnimationEventTime,
			lastEventTime,
			lastSpeechTime
		].max() ?? 0
	}

	func activeRecordPlaybackDuration() -> TimeInterval {
		guard Thread.isMainThread else {
			return DispatchQueue.main.sync {
				self.activeRecordPlaybackDuration()
			}
		}

		refreshActiveRecordPlaybacks()
		return activeRecordPlaybacks.values.map(\.remaining).max() ?? 0
	}

	func requestCutsceneSkip() -> Bool {
		guard Thread.isMainThread else {
			return DispatchQueue.main.sync {
				self.requestCutsceneSkip()
			}
		}

		refreshActiveRecordPlaybacks()
		guard !activeRecordPlaybacks.isEmpty else {
			return false
		}

		isCutsceneSkipRequested = true
		stopRecordPlayback()
		return true
	}

	func clearActiveRecordPlayback() {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.clearActiveRecordPlayback()
			}
			return
		}

		stopRecordPlayback()
	}

	func consumeCutsceneSkipRequest() -> Bool {
		guard Thread.isMainThread else {
			return DispatchQueue.main.sync {
				self.consumeCutsceneSkipRequest()
			}
		}

		guard isCutsceneSkipRequested else { return false }
		isCutsceneSkipRequested = false
		return true
	}

	private func startActiveRecordPlayback(_ record: Record, duration: TimeInterval) {
		let key = recordKey(for: record.name)
		activeRecordPlaybacks[key]?.workItem?.cancel()
		activeRecordNames.insert(record.name)

		guard duration > 0 else {
			activeRecordNames.remove(record.name)
			activeRecordPlaybacks.removeValue(forKey: key)
			return
		}

		let playback = ActiveRecordPlayback(name: record.name, duration: duration)
		activeRecordPlaybacks[key] = playback
		scheduleActiveRecordPlayback(playback, after: duration)
	}

	private func scheduleActiveRecordPlayback(_ playback: ActiveRecordPlayback, after delay: TimeInterval) {
		playback.workItem?.cancel()
		playback.workItem = nil
		playback.deadline = nil
		playback.remaining = delay
		guard !game.isGamePaused else { return }

		let workItem = DispatchWorkItem { [weak self, weak playback] in
			guard let self = self,
				  let playback = playback else { return }
			self.activeRecordNames.remove(playback.name)
			self.activeRecordPlaybacks.removeValue(forKey: self.recordKey(for: playback.name))
			if self.activeRecordPlaybacks.isEmpty {
				self.stopRecordPlayback()
			}
		}
		playback.workItem = workItem
		playback.deadline = Date.timeIntervalSinceReferenceDate + delay
		DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
	}

	private func refreshActiveRecordPlaybacks() {
		for playback in activeRecordPlaybacks.values {
			if let deadline = playback.deadline {
				playback.remaining = max(0, deadline - Date.timeIntervalSinceReferenceDate)
			}
		}
		let expiredKeys = activeRecordPlaybacks.compactMap { key, playback in
			playback.remaining <= 0 ? key : nil
		}
		for key in expiredKeys {
			if let playback = activeRecordPlaybacks[key] {
				activeRecordNames.remove(playback.name)
			}
			activeRecordPlaybacks.removeValue(forKey: key)
		}
		if !expiredKeys.isEmpty, activeRecordPlaybacks.isEmpty {
			stopRecordPlayback()
		}
	}

	private func playRecordCamera(_ record: Record) {
		guard let game = game,
			  record.cameraKeyframes.count > 1 else {
			print("== Record Camera skipped: keys=\(record.cameraKeyframes.count)")
			return
		}

		let cameraContainer = game.cameraContainer
		if recordCameraRestore == nil {
			recordCameraRestore = (
				parent: cameraContainer.parent,
				transform: cameraContainer.presentation.worldTransform,
				cameraPosition: game.cameraNode.position,
				cameraEulerAngles: game.cameraNode.eulerAngles,
				cameraFieldOfView: game.cameraNode.camera?.fieldOfView,
				cameraNearPlane: game.cameraNode.camera?.zNear
			)
		}

		if cameraContainer.parent !== game.scnScene.rootNode {
			cameraContainer.removeFromParentNode()
			game.scnScene.rootNode.addChildNode(cameraContainer)
		}
		cameraContainer.transform = recordCameraRestore?.transform ?? cameraContainer.transform
		game.cameraNode.position = SCNVector3Zero
		game.cameraNode.eulerAngles = SCNVector3(x: 0, y: 0, z: .pi)
		game.cameraNode.camera?.zNear = recordCameraNearPlane

		let keyframes = record.cameraKeyframes
		let duration = estimatedRecordDuration(record)
		let lastKeyTime = keyframes.last?.time ?? 0
		let controlledKeyframes = keyframes.filter {
			$0.outgoingControlPoint != nil || $0.incomingControlPoint != nil
		}.count
		let cutMarkerKeyframes = keyframes.filter(\.hasCutMarker).count
		let hardCutKeyframes = keyframes.filter(cameraKeyframeIsHardCut).count
		print(
			"== Record Camera playing: keys=\(keyframes.count) " +
			"controlled=\(controlledKeyframes) " +
			"cutMarkers=\(cutMarkerKeyframes) " +
			"hardCuts=\(hardCutKeyframes) " +
			"lastKey=\(String(format: "%.2f", lastKeyTime))s " +
			"duration=\(String(format: "%.2f", duration))s"
		)

		let firstKeyframe = keyframes[0]
		cameraContainer.position = firstKeyframe.position
		cameraContainer.eulerAngles = cameraEulerAngles(
			position: firstKeyframe.position,
			focusPosition: firstKeyframe.focusPosition,
			roll: firstKeyframe.roll
		)
		if let fieldOfView = firstKeyframe.fieldOfView {
			game.cameraNode.camera?.fieldOfView = fieldOfView
		}
		game.isCutsceneCameraActive = true

		cameraContainer.runAction(SCNAction.customAction(duration: duration) { node, elapsedTime in
			let time = TimeInterval(elapsedTime)
			let bounds = cameraKeyframeBounds(in: keyframes, at: time)
			let from = bounds.from
			let to = bounds.to
			let localProgress = SCNFloat(bounds.progress)
			node.position = cameraPosition(from: from, to: to, progress: localProgress)
			node.eulerAngles = cameraEulerAngles(from: from, to: to, progress: localProgress)
			if let fromFieldOfView = from.fieldOfView,
			   let toFieldOfView = to.fieldOfView {
				game.cameraNode.camera?.fieldOfView = cameraFieldOfView(
					from: from,
					to: to,
					defaultFrom: fromFieldOfView,
					defaultTo: toFieldOfView,
					progress: localProgress
				)
			}
		}, forKey: "record:camera:\(record.name)")
	}

	private func stopRecordPlayback() {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.stopRecordPlayback()
			}
			return
		}

		for differenceFile in loadedDifferenceFiles.values {
			differenceFile.rootNode.removeAllActionsRecursively()
		}
		rootNode.removeRecordActionsRecursively()
		game?.scnScene.rootNode.removeRecordActionsRecursively()
		for scheduledSound in activeRecordSoundSchedules {
			scheduledSound.workItem?.cancel()
		}
		activeRecordSoundSchedules.removeAll()
		for scheduledEvent in activeRecordEventSchedules {
			scheduledEvent.workItem?.cancel()
		}
		activeRecordEventSchedules.removeAll()
		activeRecordEventScriptNames.removeAll()
		filmMusicStreamsLock.lock()
		let filmMusicStreams = Array(self.filmMusicStreams.values)
		self.filmMusicStreams.removeAll()
		nextFilmMusicSlot = 0
		filmMusicStreamsLock.unlock()
		for stream in filmMusicStreams {
			stream.destroy()
		}
		for playback in activeRecordPlaybacks.values {
			playback.workItem?.cancel()
		}
		activeRecordPlaybacks.removeAll()
		for propNode in activeRecordPropNodes {
			unregisterNodeTree(propNode)
			if propNode.parent != nil {
				propNode.removeFromParentNode()
			}
		}
		activeRecordPropNodes.removeAll()
		for restore in activeRecordTransformRestores.values {
			restore.node.transform = restore.transform
		}
		activeRecordTransformRestores.removeAll()
		game?.cameraContainer.removeAllActions()
		game?.isCutsceneCameraActive = false
		if let restore = recordCameraRestore,
		   let game = game {
			game.cameraNode.position = restore.cameraPosition
			game.cameraNode.eulerAngles = restore.cameraEulerAngles
			if let fieldOfView = restore.cameraFieldOfView {
				game.cameraNode.camera?.fieldOfView = fieldOfView
			}
			if let nearPlane = restore.cameraNearPlane {
				game.cameraNode.camera?.zNear = nearPlane
			}
			game.restoreGameplayCamera()
		}
		recordCameraRestore = nil
		activeRecordNames.removeAll()
	}

	func setCutsceneScriptsPaused(_ isPaused: Bool, except excludedScripts: [Script] = []) {
		let excludedScriptIds = Set(excludedScripts.map { ObjectIdentifier($0) })
		let allScripts = Array(initScripts.values) + Array(scripts.values)
		if isPaused {
			for script in allScripts {
				let scriptId = ObjectIdentifier(script)
				guard !excludedScriptIds.contains(scriptId),
					  !activeRecordEventScriptNames.contains(script.name) else { continue }
				cutscenePausedScriptIds.insert(scriptId)
				script.setPaused(true)
			}
		} else {
			let pausedScriptIds = cutscenePausedScriptIds
			cutscenePausedScriptIds.removeAll()
			for script in allScripts where pausedScriptIds.contains(ObjectIdentifier(script)) {
				script.setPaused(false)
			}
		}
	}

	func setScriptsPaused(_ isPaused: Bool, except excludedScripts: [Script] = []) {
		let excludedScriptIds = Set(excludedScripts.map { ObjectIdentifier($0) })
		var pausedScriptIds = Set<ObjectIdentifier>()
		let allScripts = Array(initScripts.values) + Array(scripts.values)
		for script in allScripts {
			let scriptId = ObjectIdentifier(script)
			guard !excludedScriptIds.contains(scriptId),
				  !pausedScriptIds.contains(scriptId) else { continue }
			if !isPaused, cutscenePausedScriptIds.contains(scriptId) {
				continue
			}
			pausedScriptIds.insert(scriptId)
			script.setPaused(isPaused)
		}
	}

	func playAudio(_ source: SCNAudioSource, on node: SCNNode, completion: (@Sendable () -> Void)? = nil) {
		playAudio(source, on: node, fallbackDuration: nil, completion: completion)
	}

	func playAudio(_ source: SCNAudioSource, url: URL, on node: SCNNode, completion: (@Sendable () -> Void)? = nil) {
		let fallbackDuration = completion == nil ? nil : audioDuration(url: url)
		playAudio(source, on: node, fallbackDuration: fallbackDuration, completion: completion)
	}

	private func playAudio(_ source: SCNAudioSource, on node: SCNNode, fallbackDuration: TimeInterval?, completion: (@Sendable () -> Void)?) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.playAudio(source, on: node, fallbackDuration: fallbackDuration, completion: completion)
			}
			return
		}

		let player = SCNAudioPlayer(source: source)
		let playerId = ObjectIdentifier(player)
		player.didFinishPlayback = { [weak self] in
			DispatchQueue.main.async {
				self?.finishAudioPlayer(playerId)
			}
		}
		let activePlayer = ActiveAudioPlayer(node: node, player: player, completion: completion)
		activeAudioPlayers[playerId] = activePlayer
		node.addAudioPlayer(player)
		if isAudioPaused, let audioPlayerNode = player.audioNode as? AVAudioPlayerNode {
			audioPlayerNode.pause()
		}
		if let fallbackDuration = fallbackDuration {
			scheduleAudioCompletionFallback(for: playerId, after: fallbackDuration + 0.1)
		}
	}

	func setAudioPaused(_ isPaused: Bool) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.setAudioPaused(isPaused)
			}
			return
		}

		isAudioPaused = isPaused
		setActiveRecordPlaybacksPaused(isPaused)
		setRecordSoundSchedulesPaused(isPaused)
		setRecordEventSchedulesPaused(isPaused)
		setScriptMusicStreamsPaused(isPaused)
		var detachedPlayerIds: [ObjectIdentifier] = []
		for (playerId, activePlayer) in activeAudioPlayers {
			guard let audioPlayerNode = activePlayer.player.audioNode as? AVAudioPlayerNode else { continue }
			guard audioPlayerNode.engine != nil else {
				detachedPlayerIds.append(playerId)
				continue
			}
			if isPaused {
				audioPlayerNode.pause()
				pauseAudioCompletionFallback(for: activePlayer)
			} else if !audioPlayerNode.isPlaying {
				audioPlayerNode.play()
				rescheduleAudioCompletionFallback(for: activePlayer)
			}
		}
		for playerId in detachedPlayerIds {
			finishAudioPlayer(playerId)
		}
	}

	private func setScriptMusicStreamsPaused(_ isPaused: Bool) {
		let allScripts = Array(initScripts.values) + Array(scripts.values)
		for script in allScripts {
			script.setAudioPaused(isPaused)
		}
	}

	func destroyScriptMusicStreams() {
		let allScripts = Array(initScripts.values) + Array(scripts.values)
		for script in allScripts {
			script.destroyMusicStreams()
		}
	}

	func addFilmMusicStream(_ stream: ScriptMusicStream) {
		filmMusicStreamsLock.lock()
		filmMusicStreams[nextFilmMusicSlot] = stream
		nextFilmMusicSlot += 1
		filmMusicStreamsLock.unlock()
	}

	func filmMusicStream(at slot: Int) -> ScriptMusicStream? {
		filmMusicStreamsLock.lock()
		let stream = filmMusicStreams[slot]
		filmMusicStreamsLock.unlock()
		return stream
	}

	private func setRecordSoundSchedulesPaused(_ isPaused: Bool) {
		for scheduledSound in activeRecordSoundSchedules where !scheduledSound.didPlay {
			if isPaused {
				if let deadline = scheduledSound.deadline {
					scheduledSound.remaining = max(0, deadline - Date.timeIntervalSinceReferenceDate)
				}
				scheduledSound.workItem?.cancel()
				scheduledSound.workItem = nil
				scheduledSound.deadline = nil
			} else {
				scheduleRecordSound(scheduledSound, after: scheduledSound.remaining)
			}
		}
	}

	private func setRecordEventSchedulesPaused(_ isPaused: Bool) {
		for scheduledEvent in activeRecordEventSchedules where !scheduledEvent.didDispatch {
			if isPaused {
				if let deadline = scheduledEvent.deadline {
					scheduledEvent.remaining = max(0, deadline - Date.timeIntervalSinceReferenceDate)
				}
				scheduledEvent.workItem?.cancel()
				scheduledEvent.workItem = nil
				scheduledEvent.deadline = nil
			} else {
				scheduleRecordEvent(scheduledEvent, after: scheduledEvent.remaining)
			}
		}
	}

	private func setActiveRecordPlaybacksPaused(_ isPaused: Bool) {
		for playback in activeRecordPlaybacks.values {
			if isPaused {
				if let deadline = playback.deadline {
					playback.remaining = max(0, deadline - Date.timeIntervalSinceReferenceDate)
				}
				playback.workItem?.cancel()
				playback.workItem = nil
				playback.deadline = nil
			} else {
				scheduleActiveRecordPlayback(playback, after: playback.remaining)
			}
		}
	}

	private func audioDuration(url: URL) -> TimeInterval? {
		guard let file = try? AVAudioFile(forReading: url) else { return nil }
		return TimeInterval(file.length) / file.processingFormat.sampleRate
	}

	private func finishAudioPlayer(_ playerId: ObjectIdentifier) {
		guard let activePlayer = activeAudioPlayers.removeValue(forKey: playerId) else { return }
		activePlayer.fallbackWorkItem?.cancel()
		activePlayer.fallbackWorkItem = nil
		activePlayer.player.didFinishPlayback = nil
		activePlayer.node.removeAudioPlayer(activePlayer.player)
		activePlayer.completion?()
	}

	private func stopActiveAudioPlayers() {
		for activePlayer in activeAudioPlayers.values {
			activePlayer.fallbackWorkItem?.cancel()
			activePlayer.player.didFinishPlayback = nil
			activePlayer.node.removeAudioPlayer(activePlayer.player)
		}
		activeAudioPlayers.removeAll()
	}

	private func scheduleAudioCompletionFallback(for playerId: ObjectIdentifier, after delay: TimeInterval) {
		guard let activePlayer = activeAudioPlayers[playerId] else { return }
		activePlayer.fallbackWorkItem?.cancel()
		activePlayer.fallbackRemaining = nil
		guard !isAudioPaused else {
			activePlayer.fallbackDeadline = nil
			activePlayer.fallbackRemaining = delay
			return
		}
		let workItem = DispatchWorkItem { [weak self] in
			DispatchQueue.main.async {
				self?.finishAudioPlayer(playerId)
			}
		}
		activePlayer.fallbackWorkItem = workItem
		activePlayer.fallbackDeadline = Date.timeIntervalSinceReferenceDate + delay
		DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
	}

	private func pauseAudioCompletionFallback(for activePlayer: ActiveAudioPlayer) {
		guard let fallbackDeadline = activePlayer.fallbackDeadline else { return }
		activePlayer.fallbackWorkItem?.cancel()
		activePlayer.fallbackWorkItem = nil
		activePlayer.fallbackDeadline = nil
		activePlayer.fallbackRemaining = max(0, fallbackDeadline - Date.timeIntervalSinceReferenceDate)
	}

	private func rescheduleAudioCompletionFallback(for activePlayer: ActiveAudioPlayer) {
		guard let fallbackRemaining = activePlayer.fallbackRemaining else { return }
		scheduleAudioCompletionFallback(for: ObjectIdentifier(activePlayer.player), after: fallbackRemaining)
	}

	func triggerPlayerFireEvent() {
		guard let event = playerFireEvent else { return }
		event.script.enqueueEvent(event.eventId)
	}

	func triggerPlayerHornEvent() {
		guard let event = playerHornEvent else { return }
		event.script.enqueueEvent(event.eventId)
	}

	func noteActionAnimation(id: Int, duration: TimeInterval = 0.8) {
		lastActionAnimationId = id
		lastActionAnimationEndTime = Date.timeIntervalSinceReferenceDate + duration
	}

	func currentActionAnimationId() -> Int {
		guard Date.timeIntervalSinceReferenceDate < lastActionAnimationEndTime else { return 0 }
		return lastActionAnimationId
	}

	private func attachScript(
		_ scriptString: String,
		named name: String,
		to node: SCNNode,
		initialState: ActorState = .active
	) {
		node.actorState = initialState
		let script = Script(script: scriptString, scene: self, node: node, name: name)
		script.applyDeclaredInitialActorState()
		self.scripts[name] = script
	}

	private func readPhysicalData(stream: InputStream) throws -> PhysicalData {
		stream.currentOffset += 2
		let _: Float = try stream.read()	// center of mass?
		let _: Float = try stream.read()
		let weight: Float = try stream.read()
		let friction: Float = try stream.read()
		let _: Float = try stream.read()
		// 0-crate,1-crate1,2-barrel,3-barrel1,4-label,5-box,6-wood,7-plate,8-no_sound
		let _: UInt32 = try stream.read()	// sound
		stream.currentOffset += 5

		return PhysicalData(
			weight: CGFloat(max(5, min(80, weight))),
			friction: CGFloat(max(0.2, min(1.0, friction)))
		)
	}

	private func attachPhysical(_ physicalData: PhysicalData, to node: SCNNode) {
		guard let shape = node.convexHullPhysicsShapeFromGeometryHierarchy() else { return }

		node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
		node.physicsBody?.mass = physicalData.weight
		node.physicsBody?.friction = physicalData.friction
		node.physicsBody?.rollingFriction = 0.1
		node.physicsBody?.restitution = 0.15
		node.physicsBody?.damping = 0.05
		node.physicsBody?.angularDamping = 0.15
		node.physicsBody?.allowsResting = true
		node.physicsBody?.configureAsDynamicObjectCollider()
	}

	private func readDoorData(stream: InputStream) throws -> DoorData {
		stream.currentOffset += 5
		let open1: UInt8 = try stream.read()
		let open2: UInt8 = try stream.read()
		let moveAngle: Float = try stream.read()
		let open: UInt8 = try stream.read()
		let locked: UInt8 = try stream.read()
		let closeSpeed: Float = try stream.read()
		let openSpeed: Float = try stream.read()
		let openSound: String = try stream.read(maxLength: 16)
		let closeSound: String = try stream.read(maxLength: 16)
		let lockedSound: String = try stream.read(maxLength: 16)
		let _: UInt8 = try stream.read()

		return DoorData(
			open1: open1,
			open2: open2,
			moveAngle: SCNFloat(moveAngle),
			isOpen: open > 0,
			isLocked: locked > 0,
			closeSpeed: TimeInterval(max(0.1, Double(closeSpeed))),
			openSpeed: TimeInterval(max(0.1, Double(openSpeed))),
			openSound: openSound,
			closeSound: closeSound,
			lockedSound: lockedSound
		)
	}

	private func configureLightNode(
		_ objectNode: SCNNode,
		type: LightType,
		color: SKColor,
		power: CGFloat,
		coneAngle: CGFloat,
		near: CGFloat,
		far: CGFloat,
		sectorName: String?
	) {
		let pointLightIntensityScale: CGFloat = 650

		switch type {
		case .point:
			objectNode.light = SCNLight()
			objectNode.light?.type = .omni
			objectNode.light?.color = color
			objectNode.light?.intensity = power * pointLightIntensityScale
			objectNode.light?.attenuationStartDistance = near
			objectNode.light?.attenuationEndDistance = far

		case .cone:
			objectNode.light = SCNLight()
			objectNode.light?.type = .spot
			objectNode.light?.color = color
			objectNode.light?.intensity = power * 1000
			objectNode.light?.spotOuterAngle = coneAngle > 0 ? coneAngle * 180 / .pi : 45
			objectNode.light?.attenuationStartDistance = near
			objectNode.light?.attenuationEndDistance = far

		case .directional:
			objectNode.light = SCNLight()
			objectNode.light?.type = .directional
			objectNode.light?.color = color
			objectNode.light?.intensity = power * 100

		case .ambient, .pointAmbient:
			environmentLights.append(EnvironmentLight(
				kind: .ambient,
				node: objectNode,
				color: color,
				power: power,
				near: near,
				far: far,
				sectorName: sectorName
			))

		case .fog, .layeredFog:
			environmentLights.append(EnvironmentLight(
				kind: .fog,
				node: objectNode,
				color: color,
				power: power,
				near: near,
				far: far,
				sectorName: sectorName
			))
		}
	}

	func node(named name: String) -> SCNNode? {
		let lowercasedName = name.lowercased()
		nodesByNameLock.lock()
		let indexedNode = lockedNode(named: name, lowercasedName: lowercasedName)
		let isKnownMissing = missingNodeNames.contains(lowercasedName)
		if let indexedNode = indexedNode {
			nodesByNameLock.unlock()
			return indexedNode
		}
		if isKnownMissing {
			nodesByNameLock.unlock()
			return nil
		}
		missingNodeNames.insert(lowercasedName)
		nodesByNameLock.unlock()
		return nil
	}

	func node(nativeSceneObjectIndex index: Int) -> SCNNode? {
		nodesByNameLock.lock()
		defer { nodesByNameLock.unlock() }
		return nodesByNativeSceneObjectIndex[index]
	}

	private func lockedNode(named name: String, lowercasedName: String) -> SCNNode? {
		if let indexedNode = nodesByName[name] ?? nodesByName[lowercasedName] {
			return indexedNode
		}
		if let numberedNode = lockedNumberedNode(forBaseName: lowercasedName) {
			return numberedNode
		}
		guard name.count >= 16 else { return nil }

		var visitedNodeIds = Set<ObjectIdentifier>()
		for node in nodesByName.values {
			let nodeId = ObjectIdentifier(node)
			guard visitedNodeIds.insert(nodeId).inserted else { continue }
			guard let nodeName = node.name?.lowercased() else { continue }
			if nodeName.hasPrefix(lowercasedName) {
				return node
			}
		}
		return nil
	}

	private func lockedNumberedNode(forBaseName baseName: String) -> SCNNode? {
		var match: SCNNode?
		var visitedNodeIds = Set<ObjectIdentifier>()
		for node in nodesByName.values {
			let nodeId = ObjectIdentifier(node)
			guard visitedNodeIds.insert(nodeId).inserted,
				  let nodeName = node.name,
				  isNumberedSceneNodeName(nodeName, forBaseName: baseName) else {
				continue
			}
			guard match == nil else { return nil }
			match = node
		}
		return match
	}

	func registerNodeName(_ node: SCNNode) {
		nodesByNameLock.lock()
		defer { nodesByNameLock.unlock() }
		if let nativeIndex = node.nativeSceneObjectIndex,
		   nodesByNativeSceneObjectIndex[nativeIndex] == nil {
			nodesByNativeSceneObjectIndex[nativeIndex] = node
		}
		guard let name = node.name, !name.isEmpty else { return }
		let lowercasedName = name.lowercased()
		missingNodeNames.remove(lowercasedName)
		if nodesByName[name] == nil {
			nodesByName[name] = node
		}
		if nodesByName[lowercasedName] == nil {
			nodesByName[lowercasedName] = node
		}
	}

	func registerNodeTree(_ node: SCNNode) {
		registerNodeName(node)
		for child in node.childNodes {
			registerNodeTree(child)
		}
	}

	private func unregisterNodeTree(_ node: SCNNode) {
		if let nativeIndex = node.nativeSceneObjectIndex {
			nodesByNameLock.lock()
			if nodesByNativeSceneObjectIndex[nativeIndex] === node {
				nodesByNativeSceneObjectIndex.removeValue(forKey: nativeIndex)
			}
			nodesByNameLock.unlock()
		}
		if let name = node.name, !name.isEmpty {
			let lowercasedName = name.lowercased()
			nodesByNameLock.lock()
			if nodesByName[name] === node {
				nodesByName.removeValue(forKey: name)
			}
			if nodesByName[lowercasedName] === node {
				nodesByName.removeValue(forKey: lowercasedName)
			}
			nodesByNameLock.unlock()
		}
		for child in node.childNodes {
			unregisterNodeTree(child)
		}
	}

}

private func lerpVector(_ start: SCNVector3, _ end: SCNVector3, _ amount: SCNFloat) -> SCNVector3 {
	let clampedAmount = max(0, min(1, amount))
	return SCNVector3(
		x: start.x + (end.x - start.x) * clampedAmount,
		y: start.y + (end.y - start.y) * clampedAmount,
		z: start.z + (end.z - start.z) * clampedAmount
	)
}

private func lerpAngle(_ start: SCNFloat, _ end: SCNFloat, _ amount: SCNFloat) -> SCNFloat {
	let clampedAmount = max(0, min(1, amount))
	let fullTurn = SCNFloat.pi * 2
	var delta = end - start
	while delta > .pi {
		delta -= fullTurn
	}
	while delta < -.pi {
		delta += fullTurn
	}
	return start + delta * clampedAmount
}

private func vectorLength(_ vector: SCNVector3) -> SCNFloat {
	return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

private func cameraPosition(
	from: RecordCameraKeyframe,
	to: RecordCameraKeyframe,
	progress: SCNFloat
) -> SCNVector3 {
	if cameraKeyframeIsHardCut(to) {
		return progress < 1 ? from.position : to.position
	}

	guard let controlPoint1 = from.outgoingControlPoint,
		  let controlPoint2 = to.incomingControlPoint else {
		return lerpVector(from.position, to.position, progress)
	}

	return cubicBezier(
		from.position,
		controlPoint1.position,
		controlPoint2.position,
		to.position,
		progress
	)
}

private func cameraEulerAngles(
	from: RecordCameraKeyframe,
	to: RecordCameraKeyframe,
	progress: SCNFloat
) -> SCNVector3 {
	return cameraEulerAngles(
		position: cameraPosition(from: from, to: to, progress: progress),
		focusPosition: cameraFocusPosition(from: from, to: to, progress: progress),
		roll: cameraRoll(from: from, to: to, progress: progress)
	)
}

private func cameraFocusPosition(
	from: RecordCameraKeyframe,
	to: RecordCameraKeyframe,
	progress: SCNFloat
) -> SCNVector3 {
	if cameraKeyframeIsHardCut(to) {
		return progress < 1 ? from.focusPosition : to.focusPosition
	}

	guard let controlPoint1 = from.outgoingControlPoint,
		  let controlPoint2 = to.incomingControlPoint else {
		return lerpVector(from.focusPosition, to.focusPosition, progress)
	}

	return cubicBezier(
		from.focusPosition,
		controlPoint1.focusPosition,
		controlPoint2.focusPosition,
		to.focusPosition,
		progress
	)
}

private func cameraRoll(
	from: RecordCameraKeyframe,
	to: RecordCameraKeyframe,
	progress: SCNFloat
) -> SCNFloat {
	if cameraKeyframeIsHardCut(to) {
		return progress < 1 ? from.roll : to.roll
	}

	guard let controlPoint1 = from.outgoingControlPoint,
		  let controlPoint2 = to.incomingControlPoint else {
		return lerpAngle(from.roll, to.roll, progress)
	}

	let controlRoll1 = unwrapAngle(controlPoint1.roll, relativeTo: from.roll)
	let controlRoll2 = unwrapAngle(controlPoint2.roll, relativeTo: controlRoll1)
	let targetRoll = unwrapAngle(to.roll, relativeTo: controlRoll2)
	return cubicBezier(from.roll, controlRoll1, controlRoll2, targetRoll, progress)
}

private func cameraEulerAngles(
	position: SCNVector3,
	focusPosition: SCNVector3,
	roll: SCNFloat
) -> SCNVector3 {
	let direction = SCNVector3(
		x: focusPosition.x - position.x,
		y: focusPosition.y - position.y,
		z: focusPosition.z - position.z
	)
	let length = max(SCNFloat(0.0001), vectorLength(direction))
	let clampedVertical = max(SCNFloat(-1), min(SCNFloat(1), direction.y / length))
	return SCNVector3(
		x: asin(clampedVertical),
		y: atan2(-direction.x, -direction.z),
		z: roll
	)
}

private func cameraFieldOfView(
	from: RecordCameraKeyframe,
	to: RecordCameraKeyframe,
	defaultFrom: CGFloat,
	defaultTo: CGFloat,
	progress: SCNFloat
) -> CGFloat {
	if cameraKeyframeIsHardCut(to) {
		return progress < 1 ? defaultFrom : defaultTo
	}

	guard let controlPoint1 = from.outgoingControlPoint,
		  let controlPoint2 = to.incomingControlPoint,
		  let controlFieldOfView1 = controlPoint1.fieldOfView,
		  let controlFieldOfView2 = controlPoint2.fieldOfView else {
		return defaultFrom + (defaultTo - defaultFrom) * CGFloat(progress)
	}

	return CGFloat(cubicBezier(
		SCNFloat(defaultFrom),
		SCNFloat(controlFieldOfView1),
		SCNFloat(controlFieldOfView2),
		SCNFloat(defaultTo),
		progress
	))
}

private func cameraKeyframeIsHardCut(_ keyframe: RecordCameraKeyframe) -> Bool {
	return keyframe.hasCutMarker
}

private func cubicBezier(
	_ p0: SCNVector3,
	_ p1: SCNVector3,
	_ p2: SCNVector3,
	_ p3: SCNVector3,
	_ amount: SCNFloat
) -> SCNVector3 {
	return SCNVector3(
		x: cubicBezier(p0.x, p1.x, p2.x, p3.x, amount),
		y: cubicBezier(p0.y, p1.y, p2.y, p3.y, amount),
		z: cubicBezier(p0.z, p1.z, p2.z, p3.z, amount)
	)
}

private func cubicBezier(
	_ p0: SCNFloat,
	_ p1: SCNFloat,
	_ p2: SCNFloat,
	_ p3: SCNFloat,
	_ amount: SCNFloat
) -> SCNFloat {
	let t = max(0, min(1, amount))
	let oneMinusT = 1 - t
	return oneMinusT * oneMinusT * oneMinusT * p0 +
		3 * oneMinusT * oneMinusT * t * p1 +
		3 * oneMinusT * t * t * p2 +
		t * t * t * p3
}

private func unwrapAngles(_ angles: SCNVector3, relativeTo reference: SCNVector3) -> SCNVector3 {
	return SCNVector3(
		x: unwrapAngle(angles.x, relativeTo: reference.x),
		y: unwrapAngle(angles.y, relativeTo: reference.y),
		z: unwrapAngle(angles.z, relativeTo: reference.z)
	)
}

private func unwrapAngle(_ angle: SCNFloat, relativeTo reference: SCNFloat) -> SCNFloat {
	let fullTurn = SCNFloat.pi * 2
	var unwrapped = angle
	while unwrapped - reference > .pi {
		unwrapped -= fullTurn
	}
	while unwrapped - reference < -.pi {
		unwrapped += fullTurn
	}
	return unwrapped
}

private func cameraKeyframeBounds(
	in keyframes: [RecordCameraKeyframe],
	at time: TimeInterval
) -> (from: RecordCameraKeyframe, to: RecordCameraKeyframe, progress: CGFloat) {
	guard let first = keyframes.first else {
		fatalError("cameraKeyframeBounds requires at least one keyframe")
	}
	guard time > first.time else { return (first, first, 0) }

	guard let last = keyframes.last else {
		return (first, first, 0)
	}
	guard time <= last.time else {
		return (last, last, 0)
	}

	var lowerBound = 0
	var upperBound = keyframes.count - 1
	while lowerBound < upperBound {
		let middle = (lowerBound + upperBound) / 2
		if time > keyframes[middle].time {
			lowerBound = middle + 1
		} else {
			upperBound = middle
		}
	}

	let nextIndex = lowerBound
	guard nextIndex > 0 else { return (first, first, 0) }

	let previous = keyframes[nextIndex - 1]
	let next = keyframes[nextIndex]
	let duration = next.time - previous.time
	let progress = duration > 0 ? CGFloat((time - previous.time) / duration) : 1
	return (previous, next, max(0, min(1, progress)))
}

private extension InputStream {
	func readLightPropertyHeader() throws -> (signature: UInt16, payloadSize: Int) {
		let signature: UInt16 = try read()
		let size: UInt32 = try read()
		return (signature, max(0, Int(size) - 6))
	}
}

private extension String {
	var nilIfEmpty: String? {
		return isEmpty ? nil : self
	}
}

private extension SCNNode {
	var isHiddenInRecordHierarchy: Bool {
		var node: SCNNode? = self
		while let currentNode = node {
			if currentNode.isHidden {
				return true
			}
			node = currentNode.parent
		}
		return false
	}

	func isInHierarchy(of rootNode: SCNNode) -> Bool {
		var node: SCNNode? = self
		while let currentNode = node {
			if currentNode === rootNode {
				return true
			}
			node = currentNode.parent
		}
		return false
	}

	var hasGeometryContent: Bool {
		if geometry != nil {
			return true
		}
		return childNodes.contains { $0.hasGeometryContent }
	}

	func removeAllActionsRecursively() {
		removeAllActions()
		for childNode in childNodes {
			childNode.removeAllActionsRecursively()
		}
	}

	func removeRecordActionsRecursively() {
		for key in actionKeys where key.hasPrefix("record:") {
			removeAction(forKey: key)
		}
		for childNode in childNodes {
			childNode.removeRecordActionsRecursively()
		}
	}

	var flattenedChildNodes: [SCNNode] {
		var nodes: [SCNNode] = []
		enumerateChildNodes { node, _ in
			nodes.append(node)
		}
		return nodes
	}
}
