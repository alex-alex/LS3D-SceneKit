//
//  InputStreamUtils.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

enum InputStreamReadError: Error {
	case unexpectedEndOfFile
}

public extension InputStream {

	var currentOffset: Int {
		get {
			return (property(forKey: .fileCurrentOffsetKey) as? NSNumber ?? 0).intValue
		}
		set {
			setProperty(NSNumber(value: newValue), forKey: .fileCurrentOffsetKey)
		}
	}

	func read(maxLength: Int) throws -> [UInt8] {
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

	func read<T: BinaryInteger>() throws -> T {
		var buffer: T = 0

		let n = withUnsafeMutablePointer(to: &buffer) { ptr in
			ptr.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { ptr in
				self.readFully(into: ptr, maxLength: MemoryLayout<T>.size)
			})
		}

		if n == MemoryLayout<T>.size {
			return buffer
		} else if n < 0 {
			throw streamError ?? NSError()
		} else {
			throw InputStreamReadError.unexpectedEndOfFile
		}
	}

	func read<T: FloatingPoint>() throws -> T {
		var buffer: T = 0

		let n = withUnsafeMutablePointer(to: &buffer) { ptr in
			ptr.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { ptr in
				self.readFully(into: ptr, maxLength: MemoryLayout<T>.size)
			})
		}

		if n == MemoryLayout<T>.size {
			return buffer
		} else if n < 0 {
			throw streamError ?? NSError()
		} else {
			throw InputStreamReadError.unexpectedEndOfFile
		}
	}

	func read(maxLength: Int, encoding: String.Encoding = .utf8) throws -> String {
		var bytes: [UInt8] = try read(maxLength: maxLength)
		if let terminatorIndex = bytes.firstIndex(of: 0) {
			bytes.removeSubrange(terminatorIndex...)
		}
		if bytes.isEmpty { return "" }
		if encoding == .utf8 {
			bytes.append(0)
			return String(cString: bytes.map({ Int8(bitPattern: $0) }))
		} else {
			let data = Data(bytes: bytes)
			return String(data: data, encoding: encoding) ?? ""
		}
	}

	private func readFully(into buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
		var offset = 0
		while offset < maxLength {
			let ret = read(buffer.advanced(by: offset), maxLength: maxLength - offset)
			if ret <= 0 {
				return offset == 0 ? ret : offset
			}
			offset += ret
		}
		return offset
	}
}

extension CGPoint {
	init(stream: InputStream) throws {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		self.init(x: CGFloat(x), y: CGFloat(y))
	}
}

extension SCNVector3 {
	init(stream: InputStream) throws {
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		self.init(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
	}
}

extension SCNQuaternion {
	init(stream: InputStream) throws {
		let w: Float = try stream.read()
		let x: Float = try stream.read()
		let y: Float = try stream.read()
		let z: Float = try stream.read()
		self.init(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z), w: -SCNFloat(w))
	}
}

extension SCNMatrix4 {
	init(stream: InputStream) throws {
		var transformationMatrix: [SCNFloat] = []
		for _ in 0 ..< 16 {
			let value: Float = try stream.read()
			transformationMatrix.append(SCNFloat(value))
		}
		self.init(values: transformationMatrix)
	}
}
