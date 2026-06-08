//
//  SwiftUtils.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

struct RawRepresentableError: Error, CustomStringConvertible {
	let typeName: String
	let rawValue: String

	var description: String {
		return "Invalid \(typeName) raw value: \(rawValue)"
	}
}

public extension RawRepresentable {
	init(forcedRawValue rawValue: RawValue) throws {
		guard let x = Self(rawValue: rawValue) else {
			let error = RawRepresentableError(typeName: String(describing: Self.self), rawValue: String(describing: rawValue))
			print(error)
			throw error
		}
		self = x
	}
}

func associatedObject<ValueType: AnyObject>(
	_ base: AnyObject,
	key: UnsafePointer<UInt8>,
	initialiser: () -> ValueType)
	-> ValueType {
		if let associated = objc_getAssociatedObject(base, key) as? ValueType { return associated }
		let associated = initialiser()
		objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
		return associated
}

func associateObject<ValueType: AnyObject>(
	_ base: AnyObject,
	key: UnsafePointer<UInt8>,
	value: ValueType) {
		objc_setAssociatedObject(base, key, value, .OBJC_ASSOCIATION_RETAIN)
}
