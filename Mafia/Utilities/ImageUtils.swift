//
//  ImageUtils.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

extension CGImage {
	func removeColor(_ color: CGColor) -> CGImage? {
		guard let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: width * 4,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
		), let data = context.data else {
			return nil
		}

		context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

		let components = color.components ?? [0, 0, 0]
		let keyRed = componentByte(components, at: 0)
		let keyGreen = componentByte(components, at: 1)
		let keyBlue = componentByte(components, at: 2)
		let tolerance = 4
		let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

		for offset in stride(from: 0, to: width * height * 4, by: 4) {
			if abs(Int(pixels[offset]) - Int(keyRed)) <= tolerance &&
				abs(Int(pixels[offset + 1]) - Int(keyGreen)) <= tolerance &&
				abs(Int(pixels[offset + 2]) - Int(keyBlue)) <= tolerance {
				pixels[offset + 3] = 0
			}
		}

		return context.makeImage()
	}

	private func componentByte(_ components: [CGFloat], at index: Int) -> UInt8 {
		let value = components.indices.contains(index) ? components[index] : 0
		return UInt8(max(0, min(255, value * 255)))
	}
}

#if os(macOS)

	extension NSImage {
		func applyingAlphaMask(_ maskImage: NSImage) -> NSImage? {
			var baseRect = CGRect(origin: .zero, size: size)
			var maskRect = CGRect(origin: .zero, size: maskImage.size)
			guard let baseImage = cgImage(forProposedRect: &baseRect, context: nil, hints: nil),
				  let maskImage = maskImage.cgImage(forProposedRect: &maskRect, context: nil, hints: nil),
				  let context = CGContext(
					data: nil,
					width: baseImage.width,
					height: baseImage.height,
					bitsPerComponent: 8,
					bytesPerRow: baseImage.width * 4,
					space: CGColorSpaceCreateDeviceRGB(),
					bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
				  ),
				  let maskContext = CGContext(
					data: nil,
					width: baseImage.width,
					height: baseImage.height,
					bitsPerComponent: 8,
					bytesPerRow: baseImage.width * 4,
					space: CGColorSpaceCreateDeviceRGB(),
					bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
				  ),
				  let data = context.data,
				  let maskData = maskContext.data else {
				return nil
			}

			let bounds = CGRect(x: 0, y: 0, width: baseImage.width, height: baseImage.height)
			context.draw(baseImage, in: bounds)
			maskContext.interpolationQuality = .high
			maskContext.draw(maskImage, in: bounds)

			let pixels = data.bindMemory(to: UInt8.self, capacity: baseImage.width * baseImage.height * 4)
			let maskPixels = maskData.bindMemory(to: UInt8.self, capacity: baseImage.width * baseImage.height * 4)
			for offset in stride(from: 0, to: baseImage.width * baseImage.height * 4, by: 4) {
				let alpha = Swift.max(maskPixels[offset], Swift.max(maskPixels[offset + 1], maskPixels[offset + 2]))
				pixels[offset] = UInt8((UInt16(pixels[offset]) * UInt16(alpha)) / 255)
				pixels[offset + 1] = UInt8((UInt16(pixels[offset + 1]) * UInt16(alpha)) / 255)
				pixels[offset + 2] = UInt8((UInt16(pixels[offset + 2]) * UInt16(alpha)) / 255)
				pixels[offset + 3] = alpha
			}

			guard let cgImage = context.makeImage() else { return nil }
			return NSImage(cgImage: cgImage, size: size)
		}

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

#elseif os(iOS)

	extension UIImage {
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

		func removeColor(_ color: UIColor) -> UIImage? {
			guard let cgImage = cgImage?.removeColor(color.cgColor) else { return nil }
			return UIImage(cgImage: cgImage)
		}
	}

#endif
