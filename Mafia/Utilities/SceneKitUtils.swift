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
		collisionBitMask = PhysicsCategory.all
		contactTestBitMask = PhysicsCategory.player
	}
}

extension SCNNode {
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

func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
	return SCNVector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
	return SCNVector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
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

func mafiaResourceURL(directory: String, name: String) -> URL? {
	let directoryURL = mainDirectory.appendingPathComponent(directory)
	let directURL = directoryURL.appendingPathComponent(name)
	if FileManager.default.fileExists(atPath: directURL.path) {
		return directURL
	}

	let normalizedName = name.lowercased()
	guard let enumerator = FileManager.default.enumerator(
		at: directoryURL,
		includingPropertiesForKeys: nil,
		options: [.skipsHiddenFiles]
	) else {
		return nil
	}

	for case let url as URL in enumerator where url.lastPathComponent.lowercased() == normalizedName {
		return url
	}
	return nil
}

func mafiaMapURL(named name: String) -> URL? {
	return mafiaResourceURL(directory: "maps", name: name)
}

private var nodeTypeKey: UInt8 = 0
private var followsCameraKey: UInt8 = 0
private var doorDataKey: UInt8 = 0
private var actionsEnabledKey: UInt8 = 0
private var humanEnergyKey: UInt8 = 0

final class DoorData {
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

extension SCNNode {
	var type: ObjectDefinitionType {
		get {
			let rawValue: NSNumber = associatedObject(self, key: &nodeTypeKey) {
				return NSNumber(value: ObjectDefinitionType.empty.rawValue)
			}
			return ObjectDefinitionType(rawValue: rawValue.uint32Value) ?? .empty
		}
		set {
			associateObject(self, key: &nodeTypeKey, value: NSNumber(value: newValue.rawValue))
		}
	}

	var followsCamera: Bool {
		get {
			let value: NSNumber = associatedObject(self, key: &followsCameraKey) {
				return NSNumber(value: false)
			}
			return value.boolValue
		}
		set {
			associateObject(self, key: &followsCameraKey, value: NSNumber(value: newValue))
		}
	}

	var doorData: DoorData? {
		get {
			return objc_getAssociatedObject(self, &doorDataKey) as? DoorData
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(self, &doorDataKey, newValue, .OBJC_ASSOCIATION_RETAIN)
			} else {
				objc_setAssociatedObject(self, &doorDataKey, nil, .OBJC_ASSOCIATION_RETAIN)
			}
		}
	}

	var actionsEnabled: Bool {
		get {
			let value: NSNumber = associatedObject(self, key: &actionsEnabledKey) {
				return NSNumber(value: true)
			}
			return value.boolValue
		}
		set {
			associateObject(self, key: &actionsEnabledKey, value: NSNumber(value: newValue))
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

	var humanEnergy: Float? {
		get {
			return (objc_getAssociatedObject(self, &humanEnergyKey) as? NSNumber)?.floatValue
		}
		set {
			if let newValue = newValue {
				objc_setAssociatedObject(self, &humanEnergyKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN)
			} else {
				objc_setAssociatedObject(self, &humanEnergyKey, nil, .OBJC_ASSOCIATION_RETAIN)
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
	return normalized.hasPrefix("mrak") ||
		normalized.hasPrefix("0mrak") ||
		normalized.hasPrefix("4mrak") ||
		normalized.hasPrefix("9mrak") ||
		normalized.contains("|mrak")
}

func isSkyboxBackdropResourceName(_ name: String?) -> Bool {
	guard let name = name?.lowercased() else { return false }
	let normalized = name.replacingOccurrences(of: ".4ds", with: "")
	return normalized == "sky" ||
		normalized.hasPrefix("sky ") ||
		normalized.hasPrefix("sky_") ||
		normalized.hasPrefix("sky.") ||
		normalized.hasPrefix("sky") ||
		normalized.hasPrefix("denjasno") ||
		normalized.hasPrefix("denzatazeno") ||
		normalized.hasPrefix("den2") ||
		normalized.hasPrefix("noczatazeno") ||
		normalized.contains("|sky ")
}
