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
		let comps = color.components ?? [0, 0, 0]
		return copy(maskingColorComponents: [comps[0], comps[0], comps[1], comps[1], comps[2], comps[2]])
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
			let hue: CGFloat = CGFloat(arc4random() % 256) / 256 // use 256 to get full range from 0.0 to 1.0
			let saturation: CGFloat = CGFloat(arc4random() % 128) / 256 + 0.5 // from 0.5 to 1.0 to stay away from white
			let brightness: CGFloat = CGFloat(arc4random() % 128) / 256 + 0.5 // from 0.5 to 1.0 to stay away from black
			return NSColor(calibratedHue: hue, saturation: saturation, brightness: brightness, alpha: 1)
		}
	}

#elseif os(iOS)

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
		func removeColor(_ color: UIColor) -> UIImage? {
			guard let cgImage = cgImage?.removeColor(color.cgColor) else { return nil }
			return UIImage(cgImage: cgImage)
		}
	}

	extension UIColor {
		static func random() -> UIColor {
			let hue: CGFloat = CGFloat(arc4random() % 256) / 256 // use 256 to get full range from 0.0 to 1.0
			let saturation: CGFloat = CGFloat(arc4random() % 128) / 256 + 0.5 // from 0.5 to 1.0 to stay away from white
			let brightness: CGFloat = CGFloat(arc4random() % 128) / 256 + 0.5 // from 0.5 to 1.0 to stay away from black
			return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
		}
	}

#endif
