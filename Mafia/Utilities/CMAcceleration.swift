//
//  CMAcceleration.swift
//  Mafia
//
//  Created by Alex Studnička on 12/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

#if os(iOS)
	
import Foundation
import CoreMotion
	
extension CMAcceleration {
	
	mutating func update(with new: CMAcceleration, filteringFactor: Double = 0.5) {
		x = new.x * filteringFactor + x * (1.0 - filteringFactor)
		y = new.y * filteringFactor + y * (1.0 - filteringFactor)
		z = new.z * filteringFactor + z * (1.0 - filteringFactor)
	}
	
}

#endif
