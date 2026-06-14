//
//  RoadMapBounds.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

struct RoadMapBounds {
	static let artworkCalibrationOffset = CGPoint(x: -0.06, y: 0.14)

	let minX: SCNFloat
	let maxX: SCNFloat
	let minZ: SCNFloat
	let maxZ: SCNFloat

	init?(road: Road) {
		let positions = road.waypoints.map(\.position) + road.crossroads.map(\.position)
		guard let first = positions.first else { return nil }

		var minX = first.x
		var maxX = first.x
		var minZ = first.z
		var maxZ = first.z
		for position in positions.dropFirst() {
			minX = min(minX, position.x)
			maxX = max(maxX, position.x)
			minZ = min(minZ, position.z)
			maxZ = max(maxZ, position.z)
		}

		guard maxX > minX, maxZ > minZ else { return nil }

		self.minX = minX
		self.maxX = maxX
		self.minZ = minZ
		self.maxZ = maxZ
	}

	func normalizedPoint(for position: SCNVector3) -> CGPoint {
		let x = CGFloat((position.x - minX) / (maxX - minX))
		let y = CGFloat((position.z - minZ) / (maxZ - minZ))
		return CGPoint(
			x: max(0, min(1, x + Self.artworkCalibrationOffset.x)),
			y: max(0, min(1, y + Self.artworkCalibrationOffset.y))
		)
	}
}
