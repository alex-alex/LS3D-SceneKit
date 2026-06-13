//
//  TrafficManager.swift
//  Mafia
//
//  Created by Codex on 30/05/2026.
//  Copyright © 2026 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

final class TrafficManager {
	private final class RoamingVehicle {
		let id: Int
		let node: SCNNode
		let definition: TrafficCarDefinition
		var previousWaypointIndex: Int
		var currentWaypointIndex: Int
		var nextWaypointIndex: Int
		var progress: Float
		var travelsForward: Bool
		let speedScale: Float
		let laneOffset: Float
		var isPlaced = false

		init(
			id: Int,
			node: SCNNode,
			definition: TrafficCarDefinition,
			previousWaypointIndex: Int,
			currentWaypointIndex: Int,
			nextWaypointIndex: Int,
			progress: Float,
			travelsForward: Bool,
			speedScale: Float,
			laneOffset: Float
		) {
			self.id = id
			self.node = node
			self.definition = definition
			self.previousWaypointIndex = previousWaypointIndex
			self.currentWaypointIndex = currentWaypointIndex
			self.nextWaypointIndex = nextWaypointIndex
			self.progress = progress
			self.travelsForward = travelsForward
			self.speedScale = speedScale
			self.laneOffset = laneOffset
		}
	}

	private let road: Road
	private let trafficSettings: TrafficSettings
	private let rootNode = SCNNode()
	private var vehicles: [RoamingVehicle] = []
	private let minimumSegmentLength: Float = 0.1
	private let defaultSpeed: Float = 10
	private let defaultLaneOffset: Float = 2.4
	private let minimumCameraTrafficRadius: Float = 420
	private let cameraRebalanceDistance: Float = 80
	private var placementSeed = 0
	private var lastPlacementCenter: SCNVector3?
	var isEnabled = true {
		didSet {
			guard oldValue != isEnabled else { return }
			rootNode.isHidden = !isEnabled
		}
	}
	var placedVehicleNodes: [SCNNode] {
		guard isEnabled else { return [] }
		return vehicles
			.filter { $0.isPlaced && !$0.node.isHidden }
			.map(\.node)
	}

	init?(road: Road?, trafficSettings: TrafficSettings?, scene: SCNScene) {
		guard let road = road,
			  !road.waypoints.isEmpty else {
			return nil
		}

		self.road = road
		self.trafficSettings = TrafficManager.usableTrafficSettings(from: trafficSettings)
		rootNode.name = "__traffic__"
		scene.rootNode.addChildNode(rootNode)
		spawnVehicles()
	}

	func update(deltaTime: TimeInterval, playerPosition: SCNVector3?) {
		guard isEnabled, deltaTime > 0 else { return }

		if let playerPosition = playerPosition {
			rebalanceVehiclesIfNeeded(relativeTo: playerPosition)
		}

		for vehicle in vehicles {
			guard vehicle.isPlaced else { continue }
			update(vehicle: vehicle, deltaTime: Float(deltaTime))
		}

		if let playerPosition = playerPosition {
			updateVisibility(relativeTo: playerPosition)
		}
	}

	private func rebalanceVehiclesIfNeeded(relativeTo cameraPosition: SCNVector3) {
		let shouldRebalance: Bool
		if let lastPlacementCenter = lastPlacementCenter {
			shouldRebalance =
				squaredHorizontalDistance(lastPlacementCenter, cameraPosition) >
				cameraRebalanceDistance * cameraRebalanceDistance
		} else {
			shouldRebalance = true
		}

		if shouldRebalance {
			lastPlacementCenter = cameraPosition
			placementSeed += vehicles.count
		}
		recycleVehiclesIfNeeded(relativeTo: cameraPosition)
	}

	private func spawnVehicles() {
		let count = min(max(trafficSettings.generatedCarCount, 0), road.waypoints.count)
		guard count > 0 else { return }

		for index in 0..<count {
			let waypointIndex = evenlySpacedWaypointIndex(for: index, count: count)
			guard let placement = road.routePlacement(near: road.waypoints[waypointIndex].position, routeSeed: index),
				  let definition = trafficCarDefinitionForGeneratedCar(index: index),
				  let modelPath = resolvedModelPath(for: definition.modelName, variantSeed: index),
				  let node = try? loadModel(named: modelPath) else { continue }

			node.name = "traffic_element"
			node.trafficCarDefinition = definition
			node.position = road.waypoints[waypointIndex].position
			node.isHidden = true
			rootNode.addChildNode(node)

			let vehicle = RoamingVehicle(
				id: index,
				node: node,
				definition: definition,
				previousWaypointIndex: placement.previousWaypointIndex,
				currentWaypointIndex: placement.currentWaypointIndex,
				nextWaypointIndex: placement.nextWaypointIndex,
				progress: placement.progress,
				travelsForward: placement.travelsForward,
				speedScale: 0.9 + Float((index * 37) % 25) / 100,
				laneOffset: defaultLaneOffset + Float(index % 2) * 0.55
			)
			orient(vehicle: vehicle)
			vehicles.append(vehicle)
		}
	}

	private func recycleVehiclesIfNeeded(relativeTo playerPosition: SCNVector3) {
		let hideDistance = max(
			trafficSettings.outerRadiusToHide,
			trafficSettings.outerRadiusForGeneration,
			trafficSettings.innerRadiusForGeneration,
			minimumCameraTrafficRadius
		)
		let hideDistanceSquared = hideDistance * hideDistance

		for vehicle in vehicles {
			if !vehicle.isPlaced || squaredHorizontalDistance(vehicle.node.position, playerPosition) > hideDistanceSquared {
				place(vehicle: vehicle, near: playerPosition)
			}
		}
	}

	private func place(vehicle: RoamingVehicle, near playerPosition: SCNVector3) {
		let routeSeed = vehicle.id + placementSeed
		guard let placement = routePlacement(near: playerPosition, routeSeed: routeSeed) else { return }
		placementSeed += 1
		vehicle.previousWaypointIndex = placement.previousWaypointIndex
		vehicle.currentWaypointIndex = placement.currentWaypointIndex
		vehicle.nextWaypointIndex = placement.nextWaypointIndex
		vehicle.progress = placement.progress
		vehicle.travelsForward = placement.travelsForward
		vehicle.node.position = displayPosition(for: vehicle)
		vehicle.isPlaced = true
		orient(vehicle: vehicle)
	}

	private func routePlacement(near playerPosition: SCNVector3, routeSeed: Int) -> RoadRoutePlacement? {
		if let waypointIndex = waypointIndexNear(playerPosition, offset: routeSeed),
		   let placement = road.routePlacement(near: road.waypoints[waypointIndex].position, routeSeed: routeSeed) {
			return placement
		}

		return road.routePlacement(near: playerPosition, routeSeed: routeSeed)
	}

	private func waypointIndexNear(_ position: SCNVector3, offset: Int) -> Int? {
		let outerRadius = max(
			trafficSettings.outerRadiusForGeneration,
			trafficSettings.innerRadiusForGeneration,
			minimumCameraTrafficRadius
		)
		let innerRadius = min(max(0, trafficSettings.innerRadiusForGeneration), outerRadius)
		let outerRadiusSquared = outerRadius * outerRadius
		let innerRadiusSquared = innerRadius * innerRadius
		var generationCandidates: [Int] = []
		var outerCandidates: [Int] = []
		var nearestIndex: Int?
		var nearestDistance = Float.greatestFiniteMagnitude

		for (index, waypoint) in road.waypoints.enumerated()
			where road.nextWaypointIndex(after: index, routeSeed: offset) != nil {
			let distance = squaredHorizontalDistance(waypoint.position, position)
			if distance < nearestDistance {
				nearestDistance = distance
				nearestIndex = index
			}
			if distance <= outerRadiusSquared {
				outerCandidates.append(index)
				if distance >= innerRadiusSquared {
					generationCandidates.append(index)
				}
			}
		}

		if !generationCandidates.isEmpty {
			return spreadCandidate(from: generationCandidates, around: position, offset: offset)
		}
		if !outerCandidates.isEmpty {
			return spreadCandidate(from: outerCandidates, around: position, offset: offset)
		}
		return nearestIndex
	}

	private func spreadCandidate(from candidates: [Int], around position: SCNVector3, offset: Int) -> Int {
		var candidatesBySector: [Int: [Int]] = [:]

		for candidate in candidates {
			let waypointPosition = road.waypoints[candidate].position
			let dx = Float(waypointPosition.x - position.x)
			let dz = Float(waypointPosition.z - position.z)
			let angle = atan2(dz, dx)
			let sector = Int(floor((angle + Float.pi) / (Float.pi * 2) * 12))
			let distanceBand = min(2, Int(sqrt(dx * dx + dz * dz) / 140))
			let key = distanceBand * 12 + max(0, min(11, sector))
			candidatesBySector[key, default: []].append(candidate)
		}

		let sectorKeys = candidatesBySector.keys.sorted()
		let sectorKey = sectorKeys[offset % sectorKeys.count]
		let sectorCandidates = (candidatesBySector[sectorKey] ?? candidates).sorted()
		return sectorCandidates[(offset / max(1, sectorKeys.count)) % sectorCandidates.count]
	}

	private func update(vehicle: RoamingVehicle, deltaTime: Float) {
		guard road.waypoints.indices.contains(vehicle.previousWaypointIndex),
			  road.waypoints.indices.contains(vehicle.currentWaypointIndex),
			  road.waypoints.indices.contains(vehicle.nextWaypointIndex) else { return }

		let current = road.waypoints[vehicle.currentWaypointIndex]
		let next = road.waypoints[vehicle.nextWaypointIndex]
		let segment = next.position - current.position
		let segmentLength = max(minimumSegmentLength, segment.length)
		let speed = max(defaultSpeed, max(current.speed, next.speed)) * vehicle.speedScale

		vehicle.progress += speed * deltaTime / segmentLength

		while vehicle.progress >= 1 {
			vehicle.progress -= 1
			vehicle.previousWaypointIndex = vehicle.currentWaypointIndex
			vehicle.currentWaypointIndex = vehicle.nextWaypointIndex
			vehicle.nextWaypointIndex = routeWaypointIndex(
				after: vehicle.currentWaypointIndex,
				previousIndex: vehicle.previousWaypointIndex,
				travelsForward: vehicle.travelsForward,
				routeSeed: vehicle.id + placementSeed
			) ?? vehicle.currentWaypointIndex
		}

		vehicle.node.position = displayPosition(for: vehicle)
		orient(vehicle: vehicle)
	}

	private func orient(vehicle: RoamingVehicle) {
		let tangent = routeTangent(for: vehicle)
		let dx = tangent.x
		let dz = tangent.z
		guard abs(dx) > 0.001 || abs(dz) > 0.001 else { return }
		vehicle.node.eulerAngles.y = atan2(dx, dz)
	}

	private func updateVisibility(relativeTo playerPosition: SCNVector3) {
		let hideDistance = max(trafficSettings.outerRadiusToHide, minimumCameraTrafficRadius)
		guard hideDistance > 0 else { return }
		let hideDistanceSquared = hideDistance * hideDistance

		for vehicle in vehicles {
			let isOutsideHideRadius =
				squaredHorizontalDistance(vehicle.node.presentation.worldPosition, playerPosition) > hideDistanceSquared
			vehicle.node.isHidden =
				!vehicle.isPlaced || isOutsideHideRadius
		}
	}

	private func evenlySpacedWaypointIndex(for index: Int, count: Int) -> Int {
		return min(road.waypoints.count - 1, index * road.waypoints.count / count)
	}

	private func trafficCarDefinitionForGeneratedCar(index: Int) -> TrafficCarDefinition? {
		let totalDensity = trafficSettings.cars.reduce(Float(0)) { $0 + max(0, $1.density) }
		if totalDensity <= 0 {
			return trafficSettings.cars[index % trafficSettings.cars.count]
		}

		var pick = deterministicUnitValue(for: index) * totalDensity
		for car in trafficSettings.cars {
			pick -= max(0, car.density)
			if pick <= 0 {
				return car
			}
		}
		return trafficSettings.cars.last
	}

	private func deterministicUnitValue(for index: Int) -> Float {
		let value = UInt32(truncatingIfNeeded: index) &* 1_664_525 &+ 1_013_904_223
		return Float(value % 10_000) / 10_000
	}

	private func resolvedModelPath(for modelName: String, variantSeed: Int) -> String? {
		let normalized = modelName
			.lowercased()
			.replacingOccurrences(of: ".4ds", with: "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: "\0", with: "")

		let basePath = normalized.hasPrefix("models/") ? normalized : "models/" + normalized
		if modelExists(at: basePath) {
			return basePath
		}

		let variantSuffixes = [
			"00", "01", "02", "03", "04",
			"10", "11", "12", "13", "14",
			"20"
		]
		let suffixStart = variantSeed % variantSuffixes.count
		for offset in 0..<variantSuffixes.count {
			let suffix = variantSuffixes[(suffixStart + offset) % variantSuffixes.count]
			let variantPath = basePath + suffix
			if modelExists(at: variantPath) {
				return variantPath
			}
		}

		return nil
	}

	private func modelExists(at modelPath: String) -> Bool {
		let normalizedPath = modelPath.replacingOccurrences(of: ".4ds", with: "") + ".4ds"
		return FileManager.default.fileExists(atPath: mainDirectory.appendingPathComponent(normalizedPath).path)
	}

	private func displayPosition(for vehicle: RoamingVehicle) -> SCNVector3 {
		return displayPosition(
			basePosition: routePosition(for: vehicle),
			tangent: routeTangent(for: vehicle),
			laneOffset: vehicle.laneOffset
		)
	}

	private func displayPosition(
		basePosition: SCNVector3,
		tangent: SCNVector3,
		laneOffset: Float
	) -> SCNVector3 {
		let dx = Float(tangent.x)
		let dz = Float(tangent.z)
		let length = max(minimumSegmentLength, sqrt(dx * dx + dz * dz))
		let rightX = dz / length
		let rightZ = -dx / length

		return SCNVector3(
			x: basePosition.x + SCNFloat(rightX * laneOffset),
			y: basePosition.y,
			z: basePosition.z + SCNFloat(rightZ * laneOffset)
		)
	}

	private func routePosition(for vehicle: RoamingVehicle) -> SCNVector3 {
		let points = routeControlPoints(for: vehicle)
		return Self.linearPosition(
			from: points.current,
			to: points.next,
			progress: vehicle.progress
		)
	}

	private func routeTangent(for vehicle: RoamingVehicle) -> SCNVector3 {
		let points = routeControlPoints(for: vehicle)
		return points.next - points.current
	}

	private func routeControlPoints(for vehicle: RoamingVehicle) -> (
		previous: SCNVector3,
		current: SCNVector3,
		next: SCNVector3,
		future: SCNVector3
	) {
		let routeSeed = vehicle.id + placementSeed
		let futureWaypointIndex =
			routeWaypointIndex(
				after: vehicle.nextWaypointIndex,
				previousIndex: vehicle.currentWaypointIndex,
				travelsForward: vehicle.travelsForward,
				routeSeed: routeSeed
			) ??
			vehicle.nextWaypointIndex
		return (
			road.waypoints[vehicle.previousWaypointIndex].position,
			road.waypoints[vehicle.currentWaypointIndex].position,
			road.waypoints[vehicle.nextWaypointIndex].position,
			road.waypoints[futureWaypointIndex].position
		)
	}

	private func routeWaypointIndex(
		after index: Int,
		previousIndex: Int? = nil,
		travelsForward: Bool,
		routeSeed: Int
	) -> Int? {
		let intersectionSeed = routeSeed + index * 31
		if let previousIndex = previousIndex {
			return road.continuationWaypointIndex(
				from: index,
				previousIndex: previousIndex,
				routeSeed: intersectionSeed
			)
		}
		if travelsForward {
			return road.nextWaypointIndex(after: index, routeSeed: intersectionSeed)
		}
		return road.previousWaypointIndex(before: index)
	}

	private func shouldUseLinearRoute(points: (
		previous: SCNVector3,
		current: SCNVector3,
		next: SCNVector3,
		future: SCNVector3
	)) -> Bool {
		let incoming = Self.horizontalDirection(from: points.previous, to: points.current)
		let outgoing = Self.horizontalDirection(from: points.current, to: points.next)
		let future = Self.horizontalDirection(from: points.next, to: points.future)

		if let incoming = incoming,
		   let outgoing = outgoing,
		   Self.horizontalDot(incoming, outgoing) < 0.25 {
			return true
		}

		if let outgoing = outgoing,
		   let future = future,
		   Self.horizontalDot(outgoing, future) < 0.25 {
			return true
		}

		return false
	}

	private static func horizontalDirection(from start: SCNVector3, to end: SCNVector3) -> SCNVector3? {
		let dx = Float(end.x - start.x)
		let dz = Float(end.z - start.z)
		let length = sqrt(dx * dx + dz * dz)
		guard length > 0.001 else { return nil }
		return SCNVector3(x: SCNFloat(dx / length), y: 0, z: SCNFloat(dz / length))
	}

	private static func horizontalDot(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		return Float(lhs.x * rhs.x + lhs.z * rhs.z)
	}

	private static func linearPosition(from start: SCNVector3, to end: SCNVector3, progress: Float) -> SCNVector3 {
		let t = SCNFloat(max(0, min(1, progress)))
		return SCNVector3(
			x: start.x + (end.x - start.x) * t,
			y: start.y + (end.y - start.y) * t,
			z: start.z + (end.z - start.z) * t
		)
	}

	private static func catmullRom(
		previous: SCNVector3,
		start: SCNVector3,
		end: SCNVector3,
		future: SCNVector3,
		progress: Float
	) -> SCNVector3 {
		let t = SCNFloat(max(0, min(1, progress)))
		let t2 = t * t
		let t3 = t2 * t
		return SCNVector3(
			x: 0.5 * (
				2 * start.x +
				(-previous.x + end.x) * t +
				(2 * previous.x - 5 * start.x + 4 * end.x - future.x) * t2 +
				(-previous.x + 3 * start.x - 3 * end.x + future.x) * t3
			),
			y: 0.5 * (
				2 * start.y +
				(-previous.y + end.y) * t +
				(2 * previous.y - 5 * start.y + 4 * end.y - future.y) * t2 +
				(-previous.y + 3 * start.y - 3 * end.y + future.y) * t3
			),
			z: 0.5 * (
				2 * start.z +
				(-previous.z + end.z) * t +
				(2 * previous.z - 5 * start.z + 4 * end.z - future.z) * t2 +
				(-previous.z + 3 * start.z - 3 * end.z + future.z) * t3
			)
		)
	}

	private static func catmullRomTangent(
		previous: SCNVector3,
		start: SCNVector3,
		end: SCNVector3,
		future: SCNVector3,
		progress: Float
	) -> SCNVector3 {
		let t = SCNFloat(max(0, min(1, progress)))
		let t2 = t * t
		return SCNVector3(
			x: 0.5 * (
				(-previous.x + end.x) +
				2 * (2 * previous.x - 5 * start.x + 4 * end.x - future.x) * t +
				3 * (-previous.x + 3 * start.x - 3 * end.x + future.x) * t2
			),
			y: 0.5 * (
				(-previous.y + end.y) +
				2 * (2 * previous.y - 5 * start.y + 4 * end.y - future.y) * t +
				3 * (-previous.y + 3 * start.y - 3 * end.y + future.y) * t2
			),
			z: 0.5 * (
				(-previous.z + end.z) +
				2 * (2 * previous.z - 5 * start.z + 4 * end.z - future.z) * t +
				3 * (-previous.z + 3 * start.z - 3 * end.z + future.z) * t2
			)
		)
	}

	private func squaredHorizontalDistance(_ lhs: SCNVector3, _ rhs: SCNVector3) -> Float {
		let dx = Float(lhs.x - rhs.x)
		let dz = Float(lhs.z - rhs.z)
		return dx * dx + dz * dz
	}

	private static func usableTrafficSettings(from trafficSettings: TrafficSettings?) -> TrafficSettings {
		if let trafficSettings = trafficSettings, !trafficSettings.cars.isEmpty {
			return trafficSettings
		}

		return TrafficSettings(
			outerRadiusToHide: 180,
			innerRadiusForGeneration: 150,
			outerRadiusForGeneration: 170,
			generatedCarCount: 12,
			cars: [
				TrafficCarDefinition(modelName: "taxi00", density: 1, colors: 0, isPolice: false, gangsterFlags: 0),
				TrafficCarDefinition(modelName: "fordtco00", density: 1, colors: 0, isPolice: false, gangsterFlags: 0),
				TrafficCarDefinition(modelName: "cad_road00", density: 1, colors: 0, isPolice: false, gangsterFlags: 0),
				TrafficCarDefinition(modelName: "polcad00", density: 0.2, colors: 0, isPolice: true, gangsterFlags: 0)
			]
		)
	}
}
