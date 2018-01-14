//
//  Extensions.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/13/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

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
	
	public func read<T : BinaryInteger>() throws -> T {
		var buffer : T = 0 as! T
		
		let n = withUnsafePointer(to: &buffer) { p in
			p.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { p in
				self.read(UnsafeMutablePointer<UInt8>(mutating: p), maxLength: MemoryLayout<T>.size) // UnsafeMutablePointer<UInt8>(p)
			})
		}
		
		if n > 0 {
			assert(n == MemoryLayout<T>.size, "read length must be sizeof(T)")
			return buffer
		} else {
			fatalError()
		}
	}
	
	public func read<T : FloatingPoint>() throws -> T {
		var buffer : T = 0
		
		let n = withUnsafePointer(to: &buffer) { p in
			p.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size, { p in
				self.read(UnsafeMutablePointer<UInt8>(mutating: p), maxLength: MemoryLayout<T>.size) // UnsafeMutablePointer<UInt8>(p)
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

struct RawRepresentableError: Error {}

public extension RawRepresentable {
	public init(forcedRawValue rawValue: RawValue) throws {
		guard let x = Self(rawValue: rawValue) else {
			print("rawValue:", rawValue)
			throw RawRepresentableError()
		}
		self = x
	}
}

func +(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
	return SCNVector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

func -(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
	return SCNVector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

func += (lhs: inout SCNVector3, rhs: SCNVector3) {
	lhs = lhs + rhs
}

func +(lhs: SCNVector4, rhs: SCNVector4) -> SCNVector4 {
	return SCNVector4(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z, w: lhs.w + rhs.w)
}

func += (lhs: inout SCNVector4, rhs: SCNVector4) {
	lhs = lhs + rhs
}

extension CGImage {
	func removeColor(_ color: (CGFloat, CGFloat, CGFloat)) -> CGImage? {
		return copy(maskingColorComponents: [color.0, color.0, color.1, color.1, color.2, color.2])
	}
	
	func caLayer() -> CALayer {
		let layer = CALayer()
		#if os(macOS)
		layer.frame = NSRect(x: 0, y: 0, width: width, height: height)
		#elseif os(iOS)
		layer.frame = CGRect(x: 0, y: 0, width: width, height: height)
		#endif
		layer.contents = self
		return layer
	}
}

#if os(macOS)

	typealias SCNFloat = CGFloat
	
	extension NSImage {
		var inversed: NSImage? {
			guard let representation = representations.first as? NSBitmapImageRep,
				  let startingCIImage = CIImage(bitmapImageRep: representation),
				  let invertColorFilter = CIFilter(name: "CIColorInvert") else { return nil }
			
			invertColorFilter.setValue(startingCIImage, forKey: kCIInputImageKey)
			
			guard let outputImage = invertColorFilter.outputImage else { return nil }
			
			let finalImageRep = NSCIImageRep(ciImage: outputImage)
			let finalImage: NSImage = NSImage(size: finalImageRep.size)
			finalImage.addRepresentation(finalImageRep)
			return finalImage
		}
	}
	
	extension NSColor {
		static func random() -> NSColor {
			let hue : CGFloat = CGFloat(arc4random() % 256) / 256 // use 256 to get full range from 0.0 to 1.0
			let saturation : CGFloat = CGFloat(arc4random() % 128) / 256 + 0.5 // from 0.5 to 1.0 to stay away from white
			let brightness : CGFloat = CGFloat(arc4random() % 128) / 256 + 0.5 // from 0.5 to 1.0 to stay away from black
			return NSColor(calibratedHue: hue, saturation: saturation, brightness: brightness, alpha: 1)
		}
	}
	
#elseif os(iOS)
	
	typealias SCNFloat = Float
	
//	extension UIImage {
//		func inverseImage(cgResult: Bool) -> UIImage? {
//			let coreImage = UIKit.CIImage(image: self)
//			guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
//			filter.setValue(coreImage, forKey: kCIInputImageKey)
//			guard let result = filter.valueForKey(kCIOutputImageKey) as? UIKit.CIImage else { return nil }
//			if cgResult { // I've found that UIImage's that are based on CIImages don't work with a lot of calls properly
//				return UIImage(CGImage: CIContext(options: nil).createCGImage(result, fromRect: result.extent))
//			}
//			return UIImage(CIImage: result)
//		}
//	}
	
	extension UIImage {
		func removeColor(_ color: (CGFloat, CGFloat, CGFloat)) -> UIImage? {
			guard let cgImage = cgImage?.removeColor(color) else { return nil }
			return UIImage(cgImage: cgImage)
		}
	}
	
	extension UIColor {
		static func random() -> UIColor {
			let hue : CGFloat = CGFloat(arc4random() % 256) / 256 // use 256 to get full range from 0.0 to 1.0
			let saturation : CGFloat = CGFloat(arc4random() % 128) / 256 + 0.5 // from 0.5 to 1.0 to stay away from white
			let brightness : CGFloat = CGFloat(arc4random() % 128) / 256 + 0.5 // from 0.5 to 1.0 to stay away from black
			return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
		}
	}
	
#endif

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
	
	var length: Float {
		return sqrtf(Float(x * x + y * y + z * z))
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
	init(values: [SCNFloat]) {
		self.init(m11: values[0], m12: values[1], m13: values[2], m14: values[3], m21: values[4], m22: values[5], m23: values[6], m24: values[7], m31: values[8], m32: values[9], m33: values[10], m34: values[11], m41: values[12], m42: values[13], m43: values[14], m44: values[15])
	}

	init(stream: InputStream) throws {
		var transformationMatrix: [SCNFloat] = []
		for _ in 0 ..< 16 {
			let value: Float = try stream.read()
			transformationMatrix.append(SCNFloat(value))
		}
		self.init(values: transformationMatrix)
	}
}

func associatedObject<ValueType: AnyObject>(
	_ base: AnyObject,
	key: UnsafePointer<UInt8>,
	initialiser: () -> ValueType)
	-> ValueType {
		if let associated = objc_getAssociatedObject(base, key)
			as? ValueType { return associated }
		let associated = initialiser()
		objc_setAssociatedObject(base, key, associated,
								 .OBJC_ASSOCIATION_RETAIN)
		return associated
}

func associateObject<ValueType: AnyObject>(
	_ base: AnyObject,
	key: UnsafePointer<UInt8>,
	value: ValueType) {
	objc_setAssociatedObject(base, key, value,
							 .OBJC_ASSOCIATION_RETAIN)
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
