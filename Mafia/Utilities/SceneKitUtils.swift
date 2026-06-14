//
//  SceneKitUtils.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

extension SCNNode: @retroactive @unchecked Sendable {}
extension SCNAudioPlayer: @retroactive @unchecked Sendable {}
extension SCNAudioSource: @retroactive @unchecked Sendable {}

#if os(macOS)
	typealias SCNFloat = CGFloat
#elseif os(iOS)
	typealias SCNFloat = Float
#endif

enum PhysicsCategory {
	static let world = 1 << 0
	static let player = 1 << 1
	static let dynamicObject = 1 << 2
	static let vehicle = 1 << 3
	static let vehicleRaycastGround = 1 << 4
	static let all = world | player | dynamicObject | vehicle
	static let playerBlocking = world | dynamicObject | vehicle
}

extension SCNPhysicsBody {
	func configureAsWorldCollider() {
		categoryBitMask = PhysicsCategory.world
		collisionBitMask = PhysicsCategory.all
		contactTestBitMask = PhysicsCategory.player
	}

	func configureAsDynamicObjectCollider() {
		categoryBitMask = PhysicsCategory.dynamicObject
		collisionBitMask = PhysicsCategory.all
		contactTestBitMask = PhysicsCategory.player
	}

	func configureAsVehicleCollider() {
		categoryBitMask = PhysicsCategory.vehicle
		collisionBitMask = PhysicsCategory.all | PhysicsCategory.vehicleRaycastGround
		contactTestBitMask = PhysicsCategory.player
	}

	func configureAsVehicleRaycastGroundCollider() {
		categoryBitMask = PhysicsCategory.vehicleRaycastGround
		collisionBitMask = PhysicsCategory.vehicle
		contactTestBitMask = 0
	}
}

extension SCNNode {
	func configureAsCollisionWireframe() {
		guard let geometry = geometry else { return }
		geometry.firstMaterial = SCNMaterial.collisionWireframeMaterial
	}

	func setCollisionWireframesVisible(_ isVisible: Bool) {
		if let geometry = geometry {
			geometry.firstMaterial?.transparency = isVisible ? 1 : 0
		}

		for child in childNodes {
			child.setCollisionWireframesVisible(isVisible)
		}
	}

	func isDescendantNode(of ancestor: SCNNode) -> Bool {
		var node = parent
		while let currentNode = node {
			if currentNode === ancestor {
				return true
			}
			node = currentNode.parent
		}
		return false
	}

	var debugNodePath: String {
		var components: [String] = []
		var currentNode: SCNNode? = self
		while let node = currentNode {
			if let name = node.name, !name.isEmpty {
				components.append(name)
			}
			currentNode = node.parent
		}

		return components.isEmpty ? "<unnamed>" : components.reversed().joined(separator: "/")
	}

	func collisionLinkRoot(for linkType: Int) -> SCNNode? {
		switch linkType {
		case 1:
			return mafiaChildNode(named: "__model__", recursively: false)
		case 2:
			return mafiaChildNode(named: "__scene__", recursively: false)
		default:
			return nil
		}
	}

	var physicsBodyCount: Int {
		let ownCount = physicsBody == nil ? 0 : 1
		return childNodes.reduce(ownCount) { $0 + $1.physicsBodyCount }
	}

	func nearestPhysicsBodyDistance(to position: SCNVector3) -> SCNFloat? {
		var nearestDistanceSquared: SCNFloat?
		collectNearestPhysicsBodyDistanceSquared(to: position, nearestDistanceSquared: &nearestDistanceSquared)
		return nearestDistanceSquared.map(sqrt)
	}

	func nearestGeometryBoundsDistance(to position: SCNVector3) -> SCNFloat? {
		return nearestGeometryBounds(to: position)?.horizontalDistance
	}

	func nearestGeometryBounds(to position: SCNVector3) -> (horizontalDistance: SCNFloat, minY: SCNFloat, maxY: SCNFloat)? {
		var nearestDistanceSquared: SCNFloat?
		var nearestYBounds: (min: SCNFloat, max: SCNFloat)?
		collectNearestGeometryBounds(
			to: position,
			nearestDistanceSquared: &nearestDistanceSquared,
			nearestYBounds: &nearestYBounds
		)
		guard let nearestDistanceSquared = nearestDistanceSquared,
			  let nearestYBounds = nearestYBounds else { return nil }
		return (sqrt(nearestDistanceSquared), nearestYBounds.min, nearestYBounds.max)
	}

	private func collectNearestGeometryBounds(
		to position: SCNVector3,
		nearestDistanceSquared: inout SCNFloat?,
		nearestYBounds: inout (min: SCNFloat, max: SCNFloat)?
	) {
		if geometry != nil {
			let bounds = worldBoundingBox
			let dx: SCNFloat
			if position.x < bounds.min.x {
				dx = bounds.min.x - position.x
			} else if position.x > bounds.max.x {
				dx = position.x - bounds.max.x
			} else {
				dx = 0
			}
			let dz: SCNFloat
			if position.z < bounds.min.z {
				dz = bounds.min.z - position.z
			} else if position.z > bounds.max.z {
				dz = position.z - bounds.max.z
			} else {
				dz = 0
			}
			let distanceSquared = dx * dx + dz * dz
			if nearestDistanceSquared == nil || distanceSquared < nearestDistanceSquared! {
				nearestDistanceSquared = distanceSquared
				nearestYBounds = (bounds.min.y, bounds.max.y)
			}
		}

		for child in childNodes {
			child.collectNearestGeometryBounds(
				to: position,
				nearestDistanceSquared: &nearestDistanceSquared,
				nearestYBounds: &nearestYBounds
			)
		}
	}

	private var worldBoundingBox: (min: SCNVector3, max: SCNVector3) {
		let bounds = boundingBox
		let xs = [bounds.min.x, bounds.max.x]
		let ys = [bounds.min.y, bounds.max.y]
		let zs = [bounds.min.z, bounds.max.z]
		var worldMin = SCNVector3(x: SCNFloat.greatestFiniteMagnitude, y: SCNFloat.greatestFiniteMagnitude, z: SCNFloat.greatestFiniteMagnitude)
		var worldMax = SCNVector3(x: -SCNFloat.greatestFiniteMagnitude, y: -SCNFloat.greatestFiniteMagnitude, z: -SCNFloat.greatestFiniteMagnitude)

		for x in xs {
			for y in ys {
				for z in zs {
					let point = presentation.convertPosition(SCNVector3(x: x, y: y, z: z), to: nil)
					worldMin.x = min(worldMin.x, point.x)
					worldMin.y = min(worldMin.y, point.y)
					worldMin.z = min(worldMin.z, point.z)
					worldMax.x = max(worldMax.x, point.x)
					worldMax.y = max(worldMax.y, point.y)
					worldMax.z = max(worldMax.z, point.z)
				}
			}
		}

		return (worldMin, worldMax)
	}

	private func collectNearestPhysicsBodyDistanceSquared(
		to position: SCNVector3,
		nearestDistanceSquared: inout SCNFloat?
	) {
		if physicsBody != nil {
			let nodePosition = presentation.worldPosition
			let dx = nodePosition.x - position.x
			let dz = nodePosition.z - position.z
			let distanceSquared = dx * dx + dz * dz
			if nearestDistanceSquared == nil || distanceSquared < nearestDistanceSquared! {
				nearestDistanceSquared = distanceSquared
			}
		}

		for child in childNodes {
			child.collectNearestPhysicsBodyDistanceSquared(
				to: position,
				nearestDistanceSquared: &nearestDistanceSquared
			)
		}
	}

	func convexHullPhysicsShapeFromGeometryHierarchy() -> SCNPhysicsShape? {
		var shapes: [SCNPhysicsShape] = []
		var transforms: [NSValue] = []

		collectConvexHullPhysicsShapes(relativeTo: self, shapes: &shapes, transforms: &transforms)
		guard !shapes.isEmpty else { return nil }
		return SCNPhysicsShape(shapes: shapes, transforms: transforms)
	}

	private func collectConvexHullPhysicsShapes(relativeTo rootNode: SCNNode, shapes: inout [SCNPhysicsShape], transforms: inout [NSValue]) {
		if let geometry = geometry {
			shapes.append(SCNPhysicsShape(geometry: geometry, options: [
				.type: SCNPhysicsShape.ShapeType.convexHull.rawValue
			]))
			transforms.append(NSValue(scnMatrix4: convertTransform(SCNMatrix4Identity, to: rootNode)))
		}

		for child in mafiaChildNodes {
			child.collectConvexHullPhysicsShapes(relativeTo: rootNode, shapes: &shapes, transforms: &transforms)
		}
	}
}

private extension SCNMaterial {
	static var collisionWireframeMaterial: SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = SKColor.green
		material.emission.contents = SKColor.green
		material.lightingModel = .constant
		material.isDoubleSided = true
		material.fillMode = .lines
		material.transparency = 0
		return material
	}
}

func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
	return SCNVector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
	return SCNVector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

func * (lhs: SCNVector3, rhs: SCNFloat) -> SCNVector3 {
	return SCNVector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
}

func * (lhs: SCNFloat, rhs: SCNVector3) -> SCNVector3 {
	return rhs * lhs
}

func += (lhs: inout SCNVector3, rhs: SCNVector3) {
	lhs = lhs + rhs // swiftlint:disable:this shorthand_operator
}

func + (lhs: SCNVector4, rhs: SCNVector4) -> SCNVector4 {
	return SCNVector4(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z, w: lhs.w + rhs.w)
}

func += (lhs: inout SCNVector4, rhs: SCNVector4) {
	lhs = lhs + rhs // swiftlint:disable:this shorthand_operator
}

extension SCNVector3 {
	var length: Float {
		return sqrtf(Float(x * x + y * y + z * z))
	}

	var normalized: SCNVector3 {
		let vectorLength = SCNFloat(length)
		guard vectorLength > 0.0001 else { return SCNVector3Zero }
		return SCNVector3(x: x / vectorLength, y: y / vectorLength, z: z / vectorLength)
	}

	func cross(_ vector: SCNVector3) -> SCNVector3 {
		return SCNVector3(
			x: y * vector.z - z * vector.y,
			y: z * vector.x - x * vector.z,
			z: x * vector.y - y * vector.x
		)
	}
}

extension SCNQuaternion {
	var eulerAngles: SCNVector3 {
		let ysqr = y * y

		let t0 = 2.0 * (w * x + y * z)
		let t1 = 1.0 - 2.0 * (x * x + ysqr)
		let nx = atan2(t0, t1)

		var t2 = 2.0 * (w * y - z * x)
		t2 = t2 > 1 ? 1 : t2
		t2 = t2 < -1 ? -1 : t2
		let ny = asin(t2)

		let t3 = +2.0 * (w * z + x * y)
		let t4 = +1.0 - 2.0 * (ysqr + z * z)
		let nz = atan2(t3, t4)

		return SCNVector3(nx, ny, nz)
	}
}

extension SCNMatrix4 {
	init(values: [SCNFloat]) {
		self.init(
			m11: values[0], m12: values[1], m13: values[2], m14: values[3],
			m21: values[4], m22: values[5], m23: values[6], m24: values[7],
			m31: values[8], m32: values[9], m33: values[10], m34: values[11],
			m41: values[12], m42: values[13], m43: values[14], m44: values[15]
		)
	}
}

extension SKTexture {
	convenience init(imageUrl: URL) {
		#if os(macOS)
			self.init(image: NSImage(contentsOf: imageUrl)!)
		#elseif os(iOS)
			self.init(image: UIImage(contentsOfFile: imageUrl.path)!)
		#endif
	}
}

private final class MafiaResourceURLCache: @unchecked Sendable {
	private let lock = NSLock()
	private var urlsByKey: [String: URL] = [:]
	private var missingKeys: Set<String> = []

	func cachedURL(for key: String) -> URL?? {
		lock.lock()
		defer { lock.unlock() }
		if let url = urlsByKey[key] {
			return .some(url)
		}
		if missingKeys.contains(key) {
			return .some(nil)
		}
		return nil
	}

	func cacheURL(_ url: URL, for key: String) {
		lock.lock()
		defer { lock.unlock() }
		urlsByKey[key] = url
		missingKeys.remove(key)
	}

	func cacheMissingURL(for key: String) {
		lock.lock()
		defer { lock.unlock() }
		missingKeys.insert(key)
	}
}

private let mafiaResourceURLs = MafiaResourceURLCache()

func mafiaResourceURL(directory: String, name: String) -> URL? {
	let cacheKey = directory.lowercased() + "/" + name.replacingOccurrences(of: "\\", with: "/").lowercased()
	if let cachedURL = mafiaResourceURLs.cachedURL(for: cacheKey) {
		return cachedURL
	}

	let directoryURL = mainDirectory.appendingPathComponent(directory)
	let directURL = directoryURL.appendingPathComponent(name)
	if FileManager.default.fileExists(atPath: directURL.path) {
		cacheMafiaResourceURL(directURL, for: cacheKey)
		return directURL
	}

	let normalizedName = name.replacingOccurrences(of: "\\", with: "/").lowercased()
	let isNestedName = normalizedName.contains("/")
	guard let enumerator = FileManager.default.enumerator(
		at: directoryURL,
		includingPropertiesForKeys: nil,
		options: [.skipsHiddenFiles]
	) else {
		cacheMissingMafiaResourceURL(for: cacheKey)
		return nil
	}

	for case let url as URL in enumerator {
		if isNestedName {
			let relativePath = url.path
				.dropFirst(directoryURL.path.count)
				.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
				.lowercased()
			if relativePath == normalizedName {
				cacheMafiaResourceURL(url, for: cacheKey)
				return url
			}
		} else if url.lastPathComponent.lowercased() == normalizedName {
			cacheMafiaResourceURL(url, for: cacheKey)
			return url
		}
	}
	cacheMissingMafiaResourceURL(for: cacheKey)
	return nil
}

private func cacheMafiaResourceURL(_ url: URL, for key: String) {
	mafiaResourceURLs.cacheURL(url, for: key)
}

private func cacheMissingMafiaResourceURL(for key: String) {
	mafiaResourceURLs.cacheMissingURL(for: key)
}

func mafiaMapURL(named name: String) -> URL? {
	return mafiaResourceURL(directory: "maps", name: name)
}

private final class SCNNodeAssociatedObjectKeys: @unchecked Sendable {
	let nodeType = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let followsCamera = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let doorData = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let actorState = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let actionsEnabled = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let enemyAIState = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let enemyHostileAttackDistance = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let enemyHostileTargetNode = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let enemyPodvadimJakTretera = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let humanEnergy = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let vehicleModelName = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let trafficCarDefinition = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let liveTransformNode = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let recordSourcePosition = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let recordSourceOrientationVector = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	let areaBounds = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)

	init() {
		nodeType.initialize(to: 0)
		followsCamera.initialize(to: 0)
		doorData.initialize(to: 0)
		actorState.initialize(to: 0)
		actionsEnabled.initialize(to: 0)
		enemyAIState.initialize(to: 0)
		enemyHostileAttackDistance.initialize(to: 0)
		enemyHostileTargetNode.initialize(to: 0)
		enemyPodvadimJakTretera.initialize(to: 0)
		humanEnergy.initialize(to: 0)
		vehicleModelName.initialize(to: 0)
		trafficCarDefinition.initialize(to: 0)
		liveTransformNode.initialize(to: 0)
		recordSourcePosition.initialize(to: 0)
		recordSourceOrientationVector.initialize(to: 0)
		areaBounds.initialize(to: 0)
	}
}

private let scnNodeAssociatedObjectKeys = SCNNodeAssociatedObjectKeys()

enum ActorState: String {
	case active
	case inactive
	case off

	var canRunScript: Bool {
		return self == .active
	}
}

final class AreaBounds: @unchecked Sendable {
	let min: SCNVector3
	let max: SCNVector3
	let vertices: [SCNVector3]
	let triangles: [(Int, Int, Int)]

	init(min: SCNVector3, max: SCNVector3, vertices: [SCNVector3] = [], triangles: [(Int, Int, Int)] = []) {
		self.min = min
		self.max = max
		self.vertices = vertices
		self.triangles = triangles
	}
}

final class DoorData: @unchecked Sendable {
	let open1: UInt8
	let open2: UInt8
	let moveAngle: SCNFloat
	var isOpen: Bool
	var isLocked: Bool
	let closeSpeed: TimeInterval
	let openSpeed: TimeInterval
	let openSound: String
	let closeSound: String
	let lockedSound: String

	var closedEulerAngles: SCNVector3?
	var openDirection = 0

	init(
		open1: UInt8,
		open2: UInt8,
		moveAngle: SCNFloat,
		isOpen: Bool,
		isLocked: Bool,
		closeSpeed: TimeInterval,
		openSpeed: TimeInterval,
		openSound: String,
		closeSound: String,
		lockedSound: String
	) {
		self.open1 = open1
		self.open2 = open2
		self.moveAngle = moveAngle
		self.isOpen = isOpen
		self.isLocked = isLocked
		self.closeSpeed = closeSpeed
		self.openSpeed = openSpeed
		self.openSound = openSound
		self.closeSound = closeSound
		self.lockedSound = lockedSound
	}

	func initialOpenAngle(forUserSide userSide: Int) -> SCNFloat {
		if open1 > 0 {
			return moveAngle
		}
		if open2 > 0 {
			return -moveAngle
		}
		return userSide == 0 ? moveAngle : -moveAngle
	}
}

final class TrafficCarDefinitionBox: @unchecked Sendable {
	let definition: TrafficCarDefinition

	init(_ definition: TrafficCarDefinition) {
		self.definition = definition
	}
}

extension SCNNode {
	var vehicleModelName: String? {
		get {
			let value: NSString = associatedObject(self, key: scnNodeAssociatedObjectKeys.vehicleModelName) {
				return NSString(string: "")
			}
			return value.length > 0 ? value as String : nil
		}
		set {
			associateObject(self, key: scnNodeAssociatedObjectKeys.vehicleModelName, value: NSString(string: newValue ?? ""))
		}
	}

	var trafficCarDefinition: TrafficCarDefinition? {
		get {
			return (objc_getAssociatedObject(
				self,
				scnNodeAssociatedObjectKeys.trafficCarDefinition
			) as? TrafficCarDefinitionBox)?.definition
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(
					self,
					scnNodeAssociatedObjectKeys.trafficCarDefinition,
					TrafficCarDefinitionBox(newValue),
					.OBJC_ASSOCIATION_RETAIN
				)
			} else {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.trafficCarDefinition, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	var liveTransformNode: SCNNode? {
		get {
			return objc_getAssociatedObject(self, scnNodeAssociatedObjectKeys.liveTransformNode) as? SCNNode
		}
		set {
			objc_setAssociatedObject(
				self,
				scnNodeAssociatedObjectKeys.liveTransformNode,
				newValue,
				.OBJC_ASSOCIATION_RETAIN
			)
		}
	}

	var recordSourcePosition: SCNVector3? {
		get {
			return (objc_getAssociatedObject(self, scnNodeAssociatedObjectKeys.recordSourcePosition) as? NSValue)?.scnVector3Value
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(
					self,
					scnNodeAssociatedObjectKeys.recordSourcePosition,
					NSValue(scnVector3: newValue),
					.OBJC_ASSOCIATION_RETAIN
				)
			} else {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.recordSourcePosition, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	var recordSourceOrientationVector: SCNVector3? {
		get {
			return (objc_getAssociatedObject(self, scnNodeAssociatedObjectKeys.recordSourceOrientationVector) as? NSValue)?.scnVector3Value
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(
					self,
					scnNodeAssociatedObjectKeys.recordSourceOrientationVector,
					NSValue(scnVector3: newValue),
					.OBJC_ASSOCIATION_RETAIN
				)
			} else {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.recordSourceOrientationVector, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	var areaBounds: AreaBounds? {
		get {
			return objc_getAssociatedObject(self, scnNodeAssociatedObjectKeys.areaBounds) as? AreaBounds
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.areaBounds, newValue, .OBJC_ASSOCIATION_RETAIN)
			} else {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.areaBounds, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	var type: ObjectDefinitionType {
		get {
			let rawValue: NSNumber = associatedObject(self, key: scnNodeAssociatedObjectKeys.nodeType) {
				return NSNumber(value: ObjectDefinitionType.empty.rawValue)
			}
			return ObjectDefinitionType(rawValue: rawValue.uint32Value) ?? .empty
		}
		set {
			associateObject(self, key: scnNodeAssociatedObjectKeys.nodeType, value: NSNumber(value: newValue.rawValue))
		}
	}

	var followsCamera: Bool {
		get {
			let value: NSNumber = associatedObject(self, key: scnNodeAssociatedObjectKeys.followsCamera) {
				return NSNumber(value: false)
			}
			return value.boolValue
		}
		set {
			associateObject(self, key: scnNodeAssociatedObjectKeys.followsCamera, value: NSNumber(value: newValue))
		}
	}

	var doorData: DoorData? {
		get {
			return objc_getAssociatedObject(self, scnNodeAssociatedObjectKeys.doorData) as? DoorData
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.doorData, newValue, .OBJC_ASSOCIATION_RETAIN)
			} else {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.doorData, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	var actionsEnabled: Bool {
		get {
			let value: NSNumber = associatedObject(self, key: scnNodeAssociatedObjectKeys.actionsEnabled) {
				return NSNumber(value: true)
			}
			return value.boolValue
		}
		set {
			associateObject(self, key: scnNodeAssociatedObjectKeys.actionsEnabled, value: NSNumber(value: newValue))
		}
	}

	var actionsEnabledInHierarchy: Bool {
		var current: SCNNode? = self
		while let node = current {
			if !node.actionsEnabled {
				return false
			}
			current = node.parent
		}
		return true
	}

	var enemyAIState: String? {
		get {
			return objc_getAssociatedObject(self, scnNodeAssociatedObjectKeys.enemyAIState) as? String
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.enemyAIState, newValue, .OBJC_ASSOCIATION_RETAIN)
			} else {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.enemyAIState, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	var enemyHostileAttackDistance: Float {
		get {
			let value: NSNumber = associatedObject(self, key: scnNodeAssociatedObjectKeys.enemyHostileAttackDistance) {
				return NSNumber(value: 0)
			}
			return value.floatValue
		}
		set {
			associateObject(self, key: scnNodeAssociatedObjectKeys.enemyHostileAttackDistance, value: NSNumber(value: newValue))
		}
	}

	var enemyHostileTargetNode: SCNNode? {
		get {
			return objc_getAssociatedObject(self, scnNodeAssociatedObjectKeys.enemyHostileTargetNode) as? SCNNode
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.enemyHostileTargetNode, newValue, .OBJC_ASSOCIATION_RETAIN)
			} else {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.enemyHostileTargetNode, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	var enemyPodvadimJakTretera: Bool {
		get {
			let value: NSNumber = associatedObject(self, key: scnNodeAssociatedObjectKeys.enemyPodvadimJakTretera) {
				return NSNumber(value: false)
			}
			return value.boolValue
		}
		set {
			associateObject(self, key: scnNodeAssociatedObjectKeys.enemyPodvadimJakTretera, value: NSNumber(value: newValue))
		}
	}

	var actorState: ActorState {
		get {
			let rawValue: NSString = associatedObject(self, key: scnNodeAssociatedObjectKeys.actorState) {
				return ActorState.active.rawValue as NSString
			}
			return ActorState(rawValue: rawValue as String) ?? .active
		}
		set {
			associateObject(self, key: scnNodeAssociatedObjectKeys.actorState, value: newValue.rawValue as NSString)
			actionsEnabled = newValue.canRunScript
		}
	}

	var humanEnergy: Float? {
		get {
			return (objc_getAssociatedObject(self, scnNodeAssociatedObjectKeys.humanEnergy) as? NSNumber)?.floatValue
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.humanEnergy, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN)
			} else {
				objc_setAssociatedObject(self, scnNodeAssociatedObjectKeys.humanEnergy, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	func distance(to node: SCNNode) -> Float {
		return (presentation.worldPosition - node.presentation.worldPosition).length
	}

	func squaredDistance(to position: SCNVector3) -> Float {
		let nodePosition = presentation.worldPosition
		let dx = Float(nodePosition.x - position.x)
		let dy = Float(nodePosition.y - position.y)
		let dz = Float(nodePosition.z - position.z)
		return dx * dx + dy * dy + dz * dz
	}

	func mafiaChildNode(named name: String, recursively: Bool) -> SCNNode? {
		if let exactMatch = mafiaChildNode(recursively: recursively, matches: { $0 == name }) {
			return exactMatch
		}
		let normalizedName = name.lowercased()
		return mafiaChildNode(recursively: recursively, matches: { $0.lowercased() == normalizedName })
	}

	private func mafiaChildNode(recursively: Bool, matches: (String) -> Bool) -> SCNNode? {
		if let nodeName = self.name, matches(nodeName) {
			return self
		}
		for child in mafiaChildNodes {
			if let childName = child.name, matches(childName) {
				return child
			}
			if recursively, let match = child.mafiaChildNode(recursively: true, matches: matches) {
				return match
			}
		}
		return nil
	}

	private var mafiaChildNodes: [SCNNode] {
		guard let childObjects = value(forKey: "childNodes") as? [Any] else {
			return childNodes
		}
		return childObjects.compactMap { $0 as? SCNNode }
	}
}

func isSkyboxResourceName(_ name: String?) -> Bool {
	if isSkyboxBackdropResourceName(name) {
		return true
	}
	guard let name = name?.lowercased() else { return false }
	let normalized = name.replacingOccurrences(of: ".4ds", with: "")
	return normalized.components(separatedBy: "|").contains(where: isSkyboxCloudResourceName)
}

func isSkyboxBackdropResourceName(_ name: String?) -> Bool {
	guard let name = name?.lowercased() else { return false }
	let normalized = name.replacingOccurrences(of: ".4ds", with: "")
	return normalized == "sky" ||
		normalized.hasPrefix("sky ") ||
		normalized.hasPrefix("sky_") ||
		normalized.hasPrefix("sky.") ||
		normalized.hasPrefix("denjasno") ||
		normalized.hasPrefix("denzatazeno") ||
		normalized.hasPrefix("den2") ||
		normalized.hasPrefix("noczatazeno") ||
		normalized.contains("|sky ")
}

private func isSkyboxCloudResourceName(_ name: String) -> Bool {
	let normalized = name.replacingOccurrences(of: ".bmp", with: "")
	for prefix in ["mrak", "0mrak", "4mrak", "9mrak"] where normalized.hasPrefix(prefix) {
		return !normalized.hasPrefix(prefix + "odrap")
	}
	return false
}
