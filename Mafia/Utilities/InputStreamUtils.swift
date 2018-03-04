//
//  InputStreamUtils.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import CoreGraphics

public extension InputStream {

	var currentOffset: Int {
		get {
			return (property(forKey: .fileCurrentOffsetKey) as? NSNumber ?? 0).intValue
		}
		set {
			setProperty(NSNumber(value: newValue), forKey: .fileCurrentOffsetKey)
		}
	}

	public func read(maxLength: Int) throws -> [UInt8] {
		var buffer: [UInt8] = []
		while buffer.count < maxLength {
			let size = maxLength - buffer.count
			var tmpBuffer = [UInt8](repeating: 0, count: size)
			let ret = read(&tmpBuffer, maxLength: size)
			if ret < 0 {
				throw streamError ?? NSError()
			} else if ret == 0 {
				break
			}
			buffer += tmpBuffer
		}
		return buffer
	}

	public func read<T: BinaryInteger>() throws -> T {
		var buffer: T = 0

		let n = withUnsafePointer(to: &buffer) { ptr in
			ptr.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { ptr in
				self.read(UnsafeMutablePointer<UInt8>(mutating: ptr), maxLength: MemoryLayout<T>.size)
			})
		}

		if n > 0 {
			assert(n == MemoryLayout<T>.size, "read length must be sizeof(T)")
			return buffer
		} else {
			fatalError()
		}
	}

	public func read<T: FloatingPoint>() throws -> T {
		var buffer: T = 0

		let n = withUnsafePointer(to: &buffer) { ptr in
			ptr.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { ptr in
				self.read(UnsafeMutablePointer<UInt8>(mutating: ptr), maxLength: MemoryLayout<T>.size)
			})
		}

		if n > 0 {
			assert(n == MemoryLayout<T>.size, "read length must be sizeof(T)")
			return buffer
		} else {
			fatalError()
		}
	}

	public func read(maxLength: Int, encoding: String.Encoding = .utf8) throws -> String {
		var bytes: [UInt8] = try read(maxLength: maxLength)
		if bytes.last != 0 {
			bytes.append(0)
		}
		if encoding == .utf8 {
			return String(cString: bytes.map({ Int8(bitPattern: $0) }))
		} else {
			let data = Data(bytes: bytes)
			return String(data: data, encoding: encoding) ?? ""
		}
	}
}

extension CGPoint {
	init(stream: InputStream) throws {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		self.init(x: CGFloat(x), y: CGFloat(y))
	}
}
