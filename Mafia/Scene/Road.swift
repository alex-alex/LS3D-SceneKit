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

struct RoadRoutePlacement {
	let previousWaypointIndex: Int
	let currentWaypointIndex: Int
	let nextWaypointIndex: Int
	let progress: Float
	let travelsForward: Bool
}

final class Road {
	let version: UInt32
	let crossroads: [RoadCrossroad]
	let waypoints: [RoadWaypoint]
	private let outgoingWaypointIndicesByPoint: [Int: [Int]]
	private let incomingWaypointIndicesByPoint: [Int: [Int]]
	private let waypointIndicesByX: [Int]

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
		self.outgoingWaypointIndicesByPoint = Road.makeOutgoingWaypointIndicesByPoint(waypoints)
		self.incomingWaypointIndicesByPoint = Road.makeIncomingWaypointIndicesByPoint(waypoints)
		self.waypointIndicesByX = Road.makeWaypointIndicesByX(waypoints)
	}

	func nextWaypointIndex(after index: Int, routeSeed: Int = 0) -> Int? {
		return nextWaypointIndex(after: index, previousIndex: nil, routeSeed: routeSeed)
	}

	func nextWaypointIndex(after index: Int, previousIndex: Int?, routeSeed: Int = 0) -> Int? {
		guard waypoints.indices.contains(index) else { return nil }

		let waypoint = waypoints[index]
		if let nextIndex = waypointIndex(point: waypoint.nextPoint, type: waypoint.nextPointType) {
			return nextIndex
		}

		let outgoing = outgoingWaypointIndices(fromPoint: waypoint.nextPoint, type: waypoint.nextPointType)
		guard !outgoing.isEmpty else { return nil }
		let candidates = outgoing.filter { $0 != previousIndex }
		return bestOutgoingWaypointIndex(
			from: index,
			previousIndex: previousIndex,
			candidates: candidates.isEmpty ? outgoing : candidates,
			routeSeed: routeSeed
		)
	}

	func continuationWaypointIndex(from index: Int, previousIndex: Int?, routeSeed: Int = 0) -> Int? {
		guard waypoints.indices.contains(index) else { return nil }

		let directCandidates = directWaypointCandidates(for: index).filter { $0 != previousIndex }
		if !directCandidates.isEmpty {
			return bestOutgoingWaypointIndex(
				from: index,
				previousIndex: previousIndex,
				candidates: directCandidates,
				routeSeed: routeSeed,
				usesRouteSeed: false
			)
		}

		let localCandidates = continuationWaypointCandidates(for: index, includesCrossroadLinks: false)
		let forwardLocalCandidates = localCandidates.filter { $0 != previousIndex }
		if !forwardLocalCandidates.isEmpty {
			return bestOutgoingWaypointIndex(
				from: index,
				previousIndex: previousIndex,
				candidates: forwardLocalCandidates,
				routeSeed: routeSeed,
				usesRouteSeed: false
			)
		}

		let allCandidates = continuationWaypointCandidates(for: index, includesCrossroadLinks: true)
		guard !allCandidates.isEmpty else { return nil }

		let candidates = allCandidates.filter { $0 != previousIndex }
		return bestOutgoingWaypointIndex(
			from: index,
			previousIndex: previousIndex,
			candidates: candidates.isEmpty ? allCandidates : candidates,
			routeSeed: routeSeed
		)
	}

	func continuationWaypointIndices(from index: Int) -> [Int] {
		guard waypoints.indices.contains(index) else { return [] }
		let directCandidates = directWaypointCandidates(for: index)
		if !directCandidates.isEmpty {
			return directCandidates
		}
		return continuationWaypointCandidates(for: index, includesCrossroadLinks: false)
	}

	func previousWaypointIndex(before index: Int) -> Int? {
		guard waypoints.indices.contains(index) else { return nil }

		let waypoint = waypoints[index]
		if let previousIndex = waypointIndex(point: waypoint.previousPoint, type: waypoint.previousPointType) {
			return previousIndex
		}

		let incoming = incomingWaypointIndices(toPoint: waypoint.previousPoint, type: waypoint.previousPointType)
		return incoming.first
	}

	func nearestWaypointIndex(to position: SCNVector3) -> Int? {
		guard !waypointIndicesByX.isEmpty else { return nil }

		var nearestIndex: Int?
		var nearestDistance = Float.greatestFiniteMagnitude

		let positionX = Float(position.x)
		let startIndex = nearestWaypointXOrderIndex(to: positionX)

		var lowerIndex = startIndex
		while lowerIndex >= waypointIndicesByX.startIndex {
			let index = waypointIndicesByX[lowerIndex]
			let waypoint = waypoints[index]
			let xDistance = positionX - Float(waypoint.position.x)
			if xDistance * xDistance > nearestDistance {
				break
			}
			let distance = squaredDistance(waypoint.position, position)
			if distance < nearestDistance {
				nearestDistance = distance
				nearestIndex = index
			}
			lowerIndex -= 1
		}

		var upperIndex = startIndex + 1
		while upperIndex < waypointIndicesByX.endIndex {
			let index = waypointIndicesByX[upperIndex]
			let waypoint = waypoints[index]
			let xDistance = Float(waypoint.position.x) - positionX
			if xDistance * xDistance > nearestDistance {
				break
			}
			let distance = squaredDistance(waypoint.position, position)
			if distance < nearestDistance {
				nearestDistance = distance
				nearestIndex = index
			}
			upperIndex += 1
		}

		return nearestIndex
	}

	func routePlacement(near position: SCNVector3, routeSeed: Int = 0) -> RoadRoutePlacement? {
		return routePlacement(near: position, direction: nil, routeSeed: routeSeed)
	}

	func routePlacement(near position: SCNVector3, direction: SCNVector3?, routeSeed: Int = 0) -> RoadRoutePlacement? {
		if let direction = direction,
		   let nearestIndex = nearestWaypointIndex(to: position),
		   let placement = directedRoutePlacement(
			near: position,
			from: nearestIndex,
			direction: direction,
			routeSeed: routeSeed
		   ) {
			return placement
		}

		var bestPlacement: RoadRoutePlacement?
		var bestDistance = Float.greatestFiniteMagnitude

		for (index, waypoint) in waypoints.enumerated() {
			let candidates = routeNeighborCandidates(for: index, direction: direction, routeSeed: routeSeed)
			for candidate in candidates where candidate.index != index {
				let projectedProgress = projectedHorizontalProgress(
					position,
					from: waypoint.position,
					to: waypoints[candidate.index].position
				)
				let projectedPosition = interpolatedPosition(
					from: waypoint.position,
					to: waypoints[candidate.index].position,
					progress: projectedProgress
				)
				let distance = squaredHorizontalDistance(position, projectedPosition)
				if distance < bestDistance {
					bestDistance = distance
					bestPlacement = RoadRoutePlacement(
						previousWaypointIndex: candidate.previousIndex,
						currentWaypointIndex: index,
						nextWaypointIndex: candidate.index,
						progress: projectedProgress,
						travelsForward: candidate.travelsForward
					)
				}
			}
		}

		return bestPlacement
	}

	private func directedRoutePlacement(
		near position: SCNVector3,
		from index: Int,
		direction: SCNVector3,
		routeSeed: Int
	) -> RoadRoutePlacement? {
		guard let candidate = directedNeighborCandidate(for: index, direction: direction, routeSeed: routeSeed) else {
			return nil
		}
		let projectedProgress = projectedHorizontalProgress(
			position,
			from: waypoints[index].position,
			to: waypoints[candidate.index].position
		)
		return RoadRoutePlacement(
			previousWaypointIndex: candidate.previousIndex,
			currentWaypointIndex: index,
			nextWaypointIndex: candidate.index,
			progress: projectedProgress,
			travelsForward: candidate.travelsForward
		)
	}

	private func waypointIndex(point: UInt8, type: UInt8) -> Int? {
		guard type >= 128 else { return nil }
		let index = Int(point) + Int(type - 128) * 256
		return waypoints.indices.contains(index) ? index : nil
	}

	private func nearestWaypointXOrderIndex(to positionX: Float) -> Int {
		guard !waypointIndicesByX.isEmpty else { return 0 }

		var lowerBound = waypointIndicesByX.startIndex
		var upperBound = waypointIndicesByX.endIndex
		while lowerBound < upperBound {
			let midIndex = (lowerBound + upperBound) / 2
			let waypointX = Float(waypoints[waypointIndicesByX[midIndex]].position.x)
			if waypointX < positionX {
				lowerBound = midIndex + 1
			} else {
				upperBound = midIndex
			}
		}

		if lowerBound == waypointIndicesByX.startIndex {
			return lowerBound
		}
		if lowerBound == waypointIndicesByX.endIndex {
			return waypointIndicesByX.index(before: lowerBound)
		}

		let previousIndex = waypointIndicesByX.index(before: lowerBound)
		let previousDistance = abs(Float(waypoints[waypointIndicesByX[previousIndex]].position.x) - positionX)
		let lowerDistance = abs(Float(waypoints[waypointIndicesByX[lowerBound]].position.x) - positionX)
		return previousDistance <= lowerDistance ? previousIndex : lowerBound
	}

	private func routeNeighborCandidates(
		for index: Int,
		direction: SCNVector3?,
		routeSeed: Int
	) -> [(index: Int, previousIndex: Int, travelsForward: Bool)] {
		var candidates: [(index: Int, previousIndex: Int, travelsForward: Bool)] = []
		if let direction = direction,
		   let directedCandidate = directedNeighborCandidate(for: index, direction: direction, routeSeed: routeSeed) {
			return [directedCandidate]
		}
		if let nextIndex = nextWaypointIndex(after: index, routeSeed: routeSeed), nextIndex != index {
			candidates.append((nextIndex, previousWaypointIndex(before: index) ?? index, true))
		}
		return candidates
	}

	private func directedNeighborCandidate(
		for index: Int,
		direction: SCNVector3,
		routeSeed: Int
	) -> (index: Int, previousIndex: Int, travelsForward: Bool)? {
		guard waypoints.indices.contains(index) else { return nil }

		guard let forward = normalizedHorizontalVector(direction) else { return nil }

		let nextIndex = nextWaypointIndex(after: index, routeSeed: routeSeed)
		let previousIndex = previousWaypointIndex(before: index)
		let candidates = [
			nextIndex.map { (index: $0, previousIndex: previousIndex ?? index, travelsForward: true) },
			previousIndex.map { (index: $0, previousIndex: nextIndex ?? index, travelsForward: false) }
		].compactMap { $0 }

		return candidates
			.filter { $0.index != index }
			.max { lhs, rhs in
				directionScore(from: index, to: lhs.index, direction: forward) <
					directionScore(from: index, to: rhs.index, direction: forward)
		}
	}

	private func directWaypointCandidates(for index: Int) -> [Int] {
		let waypoint = waypoints[index]
		var candidates: [Int] = []
		if let previousIndex = waypointIndex(point: waypoint.previousPoint, type: waypoint.previousPointType) {
			appendUnique(previousIndex, to: &candidates)
		}
		if let nextIndex = waypointIndex(point: waypoint.nextPoint, type: waypoint.nextPointType) {
			appendUnique(nextIndex, to: &candidates)
		}
		return candidates.filter { $0 != index }
	}

	private func continuationWaypointCandidates(for index: Int, includesCrossroadLinks: Bool) -> [Int] {
		let waypoint = waypoints[index]
		var candidates: [Int] = []

		appendContinuationCandidates(
			to: &candidates,
			point: waypoint.previousPoint,
			type: waypoint.previousPointType,
			includesCrossroadLinks: includesCrossroadLinks
		)
		appendContinuationCandidates(
			to: &candidates,
			point: waypoint.nextPoint,
			type: waypoint.nextPointType,
			includesCrossroadLinks: includesCrossroadLinks
		)

		return candidates.filter { $0 != index }
	}

	private func appendContinuationCandidates(
		to candidates: inout [Int],
		point: UInt8,
		type: UInt8,
		includesCrossroadLinks: Bool
	) {
		if let directIndex = waypointIndex(point: point, type: type) {
			appendUnique(directIndex, to: &candidates)
			return
		}

		appendWaypointCandidates(to: &candidates, point: point, type: type)
		if includesCrossroadLinks {
			appendCrossroadLinkCandidates(to: &candidates, point: point, type: type)
		}
	}

	private func appendWaypointCandidates(to candidates: inout [Int], point: UInt8, type: UInt8) {
		for outgoingIndex in outgoingWaypointIndices(fromPoint: point, type: type) {
			appendUnique(outgoingIndex, to: &candidates)
		}
		for incomingIndex in incomingWaypointIndices(toPoint: point, type: type) {
			appendUnique(incomingIndex, to: &candidates)
		}
	}

	private func appendCrossroadLinkCandidates(to candidates: inout [Int], point: UInt8, type: UInt8) {
		guard type < 128 else { return }
		let crossroadIndex = Int(point) + Int(type) * 256
		guard crossroads.indices.contains(crossroadIndex) else { return }

		for link in crossroads[crossroadIndex].directionLinks where link.farActiveCrossPoint != 0xffff {
			let farPoint = UInt8(link.farActiveCrossPoint & 0xff)
			let farType = UInt8((link.farActiveCrossPoint >> 8) & 0xff)
			appendWaypointCandidates(to: &candidates, point: farPoint, type: farType)
		}
	}

	private func appendUnique(_ index: Int, to candidates: inout [Int]) {
		if !candidates.contains(index) {
			candidates.append(index)
		}
	}

	private func outgoingWaypointIndices(fromPoint point: UInt8, type: UInt8) -> [Int] {
		return outgoingWaypointIndicesByPoint[Road.pointKey(point: point, type: type)] ?? []
	}

	private func incomingWaypointIndices(toPoint point: UInt8, type: UInt8) -> [Int] {
		return incomingWaypointIndicesByPoint[Road.pointKey(point: point, type: type)] ?? []
	}

	private func bestOutgoingWaypointIndex(
		from index: Int,
		previousIndex: Int?,
		candidates: [Int],
		routeSeed: Int,
		usesRouteSeed: Bool = true
	) -> Int {
		guard let incomingDirection = incomingDirectionVector(for: index, previousIndex: previousIndex) else {
			return candidates[usesRouteSeed ? routeSeed % candidates.count : 0]
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
			return candidates[usesRouteSeed ? routeSeed % candidates.count : 0]
		}

		return rankedCandidates[usesRouteSeed ? routeSeed % rankedCandidates.count : 0].index
	}

	private func incomingDirectionVector(for index: Int) -> SCNVector3? {
		return incomingDirectionVector(for: index, previousIndex: nil)
	}

	private func incomingDirectionVector(for index: Int, previousIndex: Int?) -> SCNVector3? {
		if let previousIndex = previousIndex,
		   waypoints.indices.contains(previousIndex),
		   previousIndex != index {
			return normalizedHorizontalVector(from: waypoints[previousIndex].position, to: waypoints[index].position)
		}

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

	private func normalizedHorizontalVector(_ vector: SCNVector3) -> SCNVector3? {
		let dx = Float(vector.x)
		let dz = Float(vector.z)
		let length = sqrt(dx * dx + dz * dz)
		guard length > 0.001 else { return nil }
		return SCNVector3(x: SCNFloat(dx / length), y: 0, z: SCNFloat(dz / length))
	}

	private func dot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		return Float(lhs.x * rhs.x + lhs.z * rhs.z)
	}

	private func directionScore(from index: Int, to candidateIndex: Int, direction: SCNVector3) -> Float {
		let candidateDirection = normalizedHorizontalVector(
			from: waypoints[index].position,
			to: waypoints[candidateIndex].position
		)
		return dot(direction, candidateDirection)
	}

	private func projectedHorizontalProgress(_ position: SCNVector3, from start: SCNVector3, to end: SCNVector3) -> Float {
		let segmentX = Float(end.x - start.x)
		let segmentZ = Float(end.z - start.z)
		let lengthSquared = segmentX * segmentX + segmentZ * segmentZ
		guard lengthSquared > 0.0001 else { return 0 }

		let pointX = Float(position.x - start.x)
		let pointZ = Float(position.z - start.z)
		let progress = (pointX * segmentX + pointZ * segmentZ) / lengthSquared
		return max(0, min(1, progress))
	}

	private func interpolatedPosition(from start: SCNVector3, to end: SCNVector3, progress: Float) -> SCNVector3 {
		let t = SCNFloat(progress)
		return SCNVector3(
			x: start.x + (end.x - start.x) * t,
			y: start.y + (end.y - start.y) * t,
			z: start.z + (end.z - start.z) * t
		)
	}

	private func squaredHorizontalDistance(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		let dx = Float(lhs.x - rhs.x)
		let dz = Float(lhs.z - rhs.z)
		return dx * dx + dz * dz
	}

	private func squaredDistance(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		let dx = Float(lhs.x - rhs.x)
		let dy = Float(lhs.y - rhs.y)
		let dz = Float(lhs.z - rhs.z)
		return dx * dx + dy * dy + dz * dz
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
			directionLinks.append(cleanedDirectionLink(try readDirectionLink(stream: stream)))
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

	private static func cleanedDirectionLink(_ link: RoadDirectionLink) -> RoadDirectionLink {
		guard link.farActiveCrossPoint != 0xffff,
			  link.lanes.allSatisfy({ $0.type == 0 }) else {
			return link
		}

		return RoadDirectionLink(
			farActiveCrossPoint: 0xffff,
			unknown1: link.unknown1,
			farCrosspointDistance: link.farCrosspointDistance,
			angle: link.angle,
			unknown3: link.unknown3,
			priority: link.priority,
			unknown5: link.unknown5,
			lanes: link.lanes
		)
	}

	private static func makeOutgoingWaypointIndicesByPoint(_ waypoints: [RoadWaypoint]) -> [Int: [Int]] {
		var indicesByPoint: [Int: [Int]] = [:]
		for (index, waypoint) in waypoints.enumerated() {
			indicesByPoint[pointKey(point: waypoint.previousPoint, type: waypoint.previousPointType), default: []].append(index)
		}
		return indicesByPoint
	}

	private static func makeIncomingWaypointIndicesByPoint(_ waypoints: [RoadWaypoint]) -> [Int: [Int]] {
		var indicesByPoint: [Int: [Int]] = [:]
		for (index, waypoint) in waypoints.enumerated() {
			indicesByPoint[pointKey(point: waypoint.nextPoint, type: waypoint.nextPointType), default: []].append(index)
		}
		return indicesByPoint
	}

	private static func makeWaypointIndicesByX(_ waypoints: [RoadWaypoint]) -> [Int] {
		return waypoints.indices.sorted {
			let lhsPosition = waypoints[$0].position
			let rhsPosition = waypoints[$1].position
			if lhsPosition.x != rhsPosition.x {
				return lhsPosition.x < rhsPosition.x
			}
			return $0 < $1
		}
	}

	private static func pointKey(point: UInt8, type: UInt8) -> Int {
		return Int(point) | (Int(type) << 8)
	}
}
