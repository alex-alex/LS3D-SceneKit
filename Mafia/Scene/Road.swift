//
//  Road.swift
//  Mafia
//
//  Created by Codex on 30/05/2026.
//  Copyright © 2026 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

struct RoadError: Error { }

struct RoadLane {
	let unknown1: UInt16
	let type: UInt8
	let unknown2: UInt8
	let distance: Float
}

struct RoadDirectionLink {
	let farActiveCrossPoint: UInt16
	let unknown1: UInt16
	let farCrosspointDistance: Float
	let angle: Float
	let unknown3: [UInt8]
	let priority: UInt32
	let unknown5: [UInt8]
	let lanes: [RoadLane]
}

struct RoadWaypointLink {
	let directionLink: UInt8
	let unknown1: UInt8
}

struct RoadCrossroad {
	let position: SCNVector3
	let semaphore: UInt8
	let unknown1: [UInt8]
	let speed: Float
	let waypointLinks: [RoadWaypointLink]
	let directionLinks: [RoadDirectionLink]
}

struct RoadWaypoint {
	let position: SCNVector3
	let speed: Float
	let previousPoint: UInt8
	let previousPointType: UInt8
	let nextPoint: UInt8
	let nextPointType: UInt8
	let farPreviousCrosspoint: UInt8
	let unknown1: UInt8
	let farNextCrosspoint: UInt8
	let unknown2: UInt8
}

final class Road {
	let version: UInt32
	let crossroads: [RoadCrossroad]
	let waypoints: [RoadWaypoint]

	init?(name: String) throws {
		let url = mainDirectory.appendingPathComponent(name + "/road.bin")
		guard FileManager.default.fileExists(atPath: url.path),
			  let stream = InputStream(url: url) else {
			return nil
		}

		stream.open()
		defer { stream.close() }

		let version: UInt32 = try stream.read()
		guard version == 2 else { return nil }

		let crossroadCount: UInt32 = try stream.read()
		var crossroads: [RoadCrossroad] = []
		crossroads.reserveCapacity(Int(crossroadCount))
		for _ in 0..<crossroadCount {
			try crossroads.append(Road.readCrossroad(stream: stream))
		}

		let waypointCount: UInt32 = try stream.read()
		var waypoints: [RoadWaypoint] = []
		waypoints.reserveCapacity(Int(waypointCount))
		for _ in 0..<waypointCount {
			try waypoints.append(Road.readWaypoint(stream: stream))
		}

		self.version = version
		self.crossroads = crossroads
		self.waypoints = waypoints
	}

	func nextWaypointIndex(after index: Int, routeSeed: Int = 0) -> Int? {
		guard waypoints.indices.contains(index) else { return nil }

		let waypoint = waypoints[index]
		if let nextIndex = waypointIndex(point: waypoint.nextPoint, type: waypoint.nextPointType) {
			return nextIndex
		}

		let outgoing = outgoingWaypointIndices(fromPoint: waypoint.nextPoint, type: waypoint.nextPointType)
		guard !outgoing.isEmpty else { return nil }
		return bestOutgoingWaypointIndex(from: index, candidates: outgoing, routeSeed: routeSeed)
	}

	private func waypointIndex(point: UInt8, type: UInt8) -> Int? {
		guard type >= 128 else { return nil }
		let index = Int(point) + Int(type - 128) * 256
		return waypoints.indices.contains(index) ? index : nil
	}

	private func outgoingWaypointIndices(fromPoint point: UInt8, type: UInt8) -> [Int] {
		return waypoints.enumerated().compactMap { index, waypoint in
			if waypoint.previousPoint == point, waypoint.previousPointType == type {
				return index
			}
			return nil
		}
	}

	private func bestOutgoingWaypointIndex(from index: Int, candidates: [Int], routeSeed: Int) -> Int {
		guard let incomingDirection = incomingDirectionVector(for: index) else {
			return candidates[routeSeed % candidates.count]
		}

		let currentPosition = waypoints[index].position
		let rankedCandidates = candidates
			.map { candidate -> (index: Int, score: Float) in
				let candidateDirection = normalizedHorizontalVector(
					from: currentPosition,
					to: waypoints[candidate].position
				)
				return (candidate, dot(incomingDirection, candidateDirection))
			}
			.filter { $0.score > -0.25 }
			.sorted { lhs, rhs in
				if abs(lhs.score - rhs.score) > 0.05 {
					return lhs.score > rhs.score
				}
				return lhs.index < rhs.index
			}

		guard !rankedCandidates.isEmpty else {
			return candidates[routeSeed % candidates.count]
		}

		let choiceCount = min(rankedCandidates.count, routeSeed % 4 == 0 ? 2 : 1)
		let choiceIndex = choiceCount > 1 ? (routeSeed / 4) % choiceCount : 0
		return rankedCandidates[choiceIndex].index
	}

	private func incomingDirectionVector(for index: Int) -> SCNVector3? {
		let waypoint = waypoints[index]
		guard let previousIndex = waypointIndex(point: waypoint.previousPoint, type: waypoint.previousPointType) else {
			return nil
		}
		return normalizedHorizontalVector(from: waypoints[previousIndex].position, to: waypoint.position)
	}

	private func normalizedHorizontalVector(from start: SCNVector3, to end: SCNVector3) -> SCNVector3 {
		let dx = Float(end.x - start.x)
		let dz = Float(end.z - start.z)
		let length = max(0.001, sqrt(dx * dx + dz * dz))
		return SCNVector3(x: SCNFloat(dx / length), y: 0, z: SCNFloat(dz / length))
	}

	private func dot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		return Float(lhs.x * rhs.x + lhs.z * rhs.z)
	}

	private static func readCrossroad(stream: InputStream) throws -> RoadCrossroad {
		let position = try SCNVector3(stream: stream)
		let semaphore: UInt8 = try stream.read()
		let unknown1 = try stream.read(maxLength: 3)
		let speed: Float = try stream.read()

		var waypointLinks: [RoadWaypointLink] = []
		for _ in 0..<4 {
			let directionLink: UInt8 = try stream.read()
			let unknown1: UInt8 = try stream.read()
			waypointLinks.append(RoadWaypointLink(directionLink: directionLink, unknown1: unknown1))
		}

		var directionLinks: [RoadDirectionLink] = []
		for _ in 0..<4 {
			directionLinks.append(try readDirectionLink(stream: stream))
		}

		return RoadCrossroad(
			position: position,
			semaphore: semaphore,
			unknown1: unknown1,
			speed: speed,
			waypointLinks: waypointLinks,
			directionLinks: directionLinks
		)
	}

	private static func readDirectionLink(stream: InputStream) throws -> RoadDirectionLink {
		let farActiveCrossPoint: UInt16 = try stream.read()
		let unknown1: UInt16 = try stream.read()
		let farCrosspointDistance: Float = try stream.read()
		let angle: Float = try stream.read()
		let unknown3 = try stream.read(maxLength: 2)
		let priority: UInt32 = try stream.read()
		let unknown5 = try stream.read(maxLength: 2)

		var lanes: [RoadLane] = []
		for _ in 0..<4 {
			let unknown1: UInt16 = try stream.read()
			let type: UInt8 = try stream.read()
			let unknown2: UInt8 = try stream.read()
			let distance: Float = try stream.read()
			lanes.append(RoadLane(unknown1: unknown1, type: type, unknown2: unknown2, distance: distance))
		}

		return RoadDirectionLink(
			farActiveCrossPoint: farActiveCrossPoint,
			unknown1: unknown1,
			farCrosspointDistance: farCrosspointDistance,
			angle: angle,
			unknown3: unknown3,
			priority: priority,
			unknown5: unknown5,
			lanes: lanes
		)
	}

	private static func readWaypoint(stream: InputStream) throws -> RoadWaypoint {
		return RoadWaypoint(
			position: try SCNVector3(stream: stream),
			speed: try stream.read(),
			previousPoint: try stream.read(),
			previousPointType: try stream.read(),
			nextPoint: try stream.read(),
			nextPointType: try stream.read(),
			farPreviousCrosspoint: try stream.read(),
			unknown1: try stream.read(),
			farNextCrosspoint: try stream.read(),
			unknown2: try stream.read()
		)
	}
}
