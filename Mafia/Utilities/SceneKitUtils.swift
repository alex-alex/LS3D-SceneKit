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

private var nodeTypeKey: UInt8 = 0

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

	func distance(to node: SCNNode) -> Float {
		return (presentation.worldPosition - node.presentation.worldPosition).length
	}
}
