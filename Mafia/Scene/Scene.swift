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
		eventTime: TimeInterval
	) {
		self.url = url
		self.node = node
		self.fallbackNode = fallbackNode
		self.soundName = soundName
		self.fileName = fileName
		self.eventTime = eventTime
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
	let completion: (Result<Record, Swift.Error>) -> Void
}

private struct PendingDifferenceLoad {
	let completion: (Result<DifferenceFile, Swift.Error>) -> Void
}

private let recordCameraNearPlane: Double = 0.01
private let recordFaceAnimationTimeTolerance: TimeInterval = 0.35

struct TrafficCarDefinition {
	let modelName: String
	let density: Float
	let colors: UInt32
	let isPolice: Bool
	let gangsterFlags: UInt16
}

struct TrafficSettings {
	let outerRadiusToHide: Float
	let innerRadiusForGeneration: Float
	let outerRadiusForGeneration: Float
	let generatedCarCount: Int
	let cars: [TrafficCarDefinition]
}

final class Scene {

	var game: Game!
	let rootNode = SCNNode()
	var playerNode: SCNNode?

	var initScripts: [String: Script] = [:]
	var scripts: [String: Script] = [:]

	var sounds: [SCNNode: Sound] = [:]
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
	private var missingNodeNames = Set<String>()

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
	private var activeAudioPlayers: [ObjectIdentifier: ActiveAudioPlayer] = [:]
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
	private var activeRecordEventSchedules: [ScheduledRecordEvent] = []
	private var activeRecordEventScriptNames = Set<String>()
	private let filmMusicStreamsLock = NSLock()
	private var filmMusicStreams: [Int: ScriptMusicStream] = [:]
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
			DispatchQueue.main.async {
				self.game?.hud?.updateObjectives(self.objectives)
			}
		}
	}
	var pressedJump = false

	init(named name: String) throws {
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
					var type: ObjectType = .object

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
							let _ = try SCNVector3(stream: stream) // min
							let _ = try SCNVector3(stream: stream) // max

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
							stream.currentOffset += partSize - 6

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

					objectNode.recordSourcePosition = objectNode.position
					objectNode.recordSourceOrientationVector = SCNVector3(
						x: -objectNode.orientation.w,
						y: objectNode.orientation.x,
						z: objectNode.orientation.y
					)
					registerNodeName(objectNode)
					self.rootNode.addChildNode(objectNode)

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
								} else if !name.isEmpty {
									pendingHumanEnergyByName[name] = energy
								}
								self.playerNode = node

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
										isPolice: isPolice > 0,
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
			applyObjectDefinitionType(type, to: node)
		}
		pendingObjectTypesByName.removeAll()
		for (name, energy) in pendingHumanEnergyByName {
			guard let node = rootNode.mafiaChildNode(named: name, recursively: true) else { continue }
			node.humanEnergy = energy
		}
		pendingHumanEnergyByName.removeAll()
	}

	private func applyObjectDefinitionType(_ type: ObjectDefinitionType, to node: SCNNode) {
		node.type = type
		if type.hasDefaultHumanEnergy && node.humanEnergy == nil {
			node.humanEnergy = 100
		}
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
		completion: @escaping (Result<DifferenceFile, Swift.Error>) -> Void
	) {
		DispatchQueue.main.async {
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
			self.differenceLoadQueue.async {
				let result = Result { try DifferenceFile(named: name) }
				DispatchQueue.main.async {
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
			differenceFile.rootNode.removeFromParentNode()
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
		completion: @escaping (Result<Record, Swift.Error>) -> Void
	) {
		DispatchQueue.main.async {
			let key = self.recordKey(for: name)
			if let record = self.loadedRecords[key] {
				print("== Record already loaded: \(name)")
				self.waitForPendingDifferenceLoads { result in
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
			self.recordLoadQueue.async {
				let result = Result { () -> Record in
					let record = try Record(name: name)
					Self.preloadRecordAnimations(record)
					return record
				}
				DispatchQueue.main.async {
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
						self.waitForPendingDifferenceLoads { result in
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

	private func waitForPendingDifferenceLoads(completion: @escaping (Result<Void, Swift.Error>) -> Void) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.waitForPendingDifferenceLoads(completion: completion)
			}
			return
		}

		let pendingKeys = Array(pendingDifferenceLoads.keys)
		guard !pendingKeys.isEmpty else {
			completion(.success(()))
			return
		}

		var remainingLoads = pendingKeys.count
		var firstError: Swift.Error?
		let finishOne: (Result<DifferenceFile, Swift.Error>) -> Void = { result in
			if case .failure(let error) = result, firstError == nil {
				firstError = error
			}
			remainingLoads -= 1
			guard remainingLoads == 0 else { return }
			if let firstError = firstError {
				completion(.failure(firstError))
			} else {
				completion(.success(()))
			}
		}

		for key in pendingKeys {
			pendingDifferenceLoads[key]?.append(PendingDifferenceLoad(completion: finishOne))
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
		let recordRoots = differenceRoots + [rootNode, game.scnScene.rootNode]
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
				named: binding.sourceName,
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
		playRecordSpeech(record, animations: resolvedAnimations)
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
		named name: String,
		differenceRoots: [SCNNode]
	) -> SCNNode? {
		if let differenceNode = recordNode(named: name, in: differenceRoots) {
			return differenceNode
		}
		if let renderNode = recordNode(named: name, in: [game.scnScene.rootNode], excluding: rootNode) {
			return renderNode
		}
		return recordNode(named: name, in: [rootNode])
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
		let targetIdentifier = ObjectIdentifier(targetNode)
		let playback = playbacks[targetIdentifier] ?? RecordTransformPlayback(targetNode: targetNode)
		playback.append(events: events, source: source)
		playbacks[targetIdentifier] = playback
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

	private func playRecordSpeech(_ record: Record, animations: [RecordAnimationPlayback]) {
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
				eventTime: event.time
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

		cameraContainer.removeFromParentNode()
		game.scnScene.rootNode.addChildNode(cameraContainer)
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

	func playAudio(_ source: SCNAudioSource, on node: SCNNode, completion: (() -> Void)? = nil) {
		playAudio(source, on: node, fallbackDuration: nil, completion: completion)
	}

	func playAudio(_ source: SCNAudioSource, url: URL, on node: SCNNode, completion: (() -> Void)? = nil) {
		let fallbackDuration = completion == nil ? nil : audioDuration(url: url)
		playAudio(source, on: node, fallbackDuration: fallbackDuration, completion: completion)
	}

	private func playAudio(_ source: SCNAudioSource, on node: SCNNode, fallbackDuration: TimeInterval?, completion: (() -> Void)?) {
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
		let indexedNode = nodesByName[name] ?? nodesByName[lowercasedName]
		let isKnownMissing = missingNodeNames.contains(lowercasedName)
		nodesByNameLock.unlock()
		if let indexedNode = indexedNode {
			return indexedNode
		}
		guard !isKnownMissing else { return nil }
		guard let node = rootNode.mafiaChildNode(named: name, recursively: true) else {
			nodesByNameLock.lock()
			missingNodeNames.insert(lowercasedName)
			nodesByNameLock.unlock()
			return nil
		}
		registerNodeName(node)
		return node
	}

	func registerNodeName(_ node: SCNNode) {
		guard let name = node.name, !name.isEmpty else { return }
		nodesByNameLock.lock()
		defer { nodesByNameLock.unlock() }
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

	var flattenedChildNodes: [SCNNode] {
		return childNodes + childNodes.flatMap { $0.flattenedChildNodes }
	}
}
