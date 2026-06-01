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
		var currentWaypointIndex: Int
		var nextWaypointIndex: Int
		var progress: Float
		let speedScale: Float
		let laneOffset: Float
		var isPlaced = false

		init(
			id: Int,
			node: SCNNode,
			currentWaypointIndex: Int,
			nextWaypointIndex: Int,
			progress: Float,
			speedScale: Float,
			laneOffset: Float
		) {
			self.id = id
			self.node = node
			self.currentWaypointIndex = currentWaypointIndex
			self.nextWaypointIndex = nextWaypointIndex
			self.progress = progress
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
	private let maxGeneratedCars = 16
	private var placementSeed = 0
	private var lastPlacementCenter: SCNVector3?

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
		guard deltaTime > 0 else { return }

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
			for vehicle in vehicles {
				place(vehicle: vehicle, near: cameraPosition)
			}
		} else {
			recycleVehiclesIfNeeded(relativeTo: cameraPosition)
		}
	}

	private func spawnVehicles() {
		let count = min(max(trafficSettings.generatedCarCount, 0), maxGeneratedCars, road.waypoints.count)
		guard count > 0 else { return }

		for index in 0..<count {
			let waypointIndex = evenlySpacedWaypointIndex(for: index, count: count)
			guard let nextIndex = road.nextWaypointIndex(after: waypointIndex, routeSeed: index),
				  nextIndex != waypointIndex,
				  let modelName = modelNameForGeneratedCar(index: index),
				  let modelPath = resolvedModelPath(for: modelName, variantSeed: index),
				  let node = try? loadModel(named: modelPath) else { continue }

			node.name = "__traffic_\(modelName)_\(index)__"
			node.position = road.waypoints[waypointIndex].position
			node.isHidden = true
			rootNode.addChildNode(node)

			let vehicle = RoamingVehicle(
				id: index,
				node: node,
				currentWaypointIndex: waypointIndex,
				nextWaypointIndex: nextIndex,
				progress: Float(index % 4) * 0.2,
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
		guard let waypointIndex = waypointIndexNear(playerPosition, offset: vehicle.id + placementSeed),
			  let nextIndex = road.nextWaypointIndex(after: waypointIndex, routeSeed: vehicle.id + placementSeed),
			  nextIndex != waypointIndex else { return }

		placementSeed += 1
		vehicle.currentWaypointIndex = waypointIndex
		vehicle.nextWaypointIndex = nextIndex
		vehicle.progress = 0
		vehicle.node.position = displayPosition(for: vehicle)
		vehicle.isPlaced = true
		orient(vehicle: vehicle)
	}

	private func waypointIndexNear(_ position: SCNVector3, offset: Int) -> Int? {
		let radius = max(
			trafficSettings.outerRadiusForGeneration,
			trafficSettings.innerRadiusForGeneration,
			trafficSettings.outerRadiusToHide,
			minimumCameraTrafficRadius
		)
		let radiusSquared = radius * radius
		var candidates: [Int] = []
		var nearestIndex: Int?
		var nearestDistance = Float.greatestFiniteMagnitude

		for (index, waypoint) in road.waypoints.enumerated()
			where road.nextWaypointIndex(after: index, routeSeed: offset) != nil {
			let distance = squaredHorizontalDistance(waypoint.position, position)
			if distance < nearestDistance {
				nearestDistance = distance
				nearestIndex = index
			}
			if distance <= radiusSquared {
				candidates.append(index)
			}
		}

		if !candidates.isEmpty {
			return spreadCandidate(from: candidates, around: position, offset: offset)
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
		guard road.waypoints.indices.contains(vehicle.currentWaypointIndex),
			  road.waypoints.indices.contains(vehicle.nextWaypointIndex) else { return }

		let current = road.waypoints[vehicle.currentWaypointIndex]
		let next = road.waypoints[vehicle.nextWaypointIndex]
		let segment = next.position - current.position
		let segmentLength = max(minimumSegmentLength, segment.length)
		let speed = max(defaultSpeed, max(current.speed, next.speed)) * vehicle.speedScale

		vehicle.progress += speed * deltaTime / segmentLength

		while vehicle.progress >= 1 {
			vehicle.progress -= 1
			vehicle.currentWaypointIndex = vehicle.nextWaypointIndex
			vehicle.nextWaypointIndex =
				road.nextWaypointIndex(
					after: vehicle.currentWaypointIndex,
					routeSeed: vehicle.id + placementSeed
				) ?? vehicle.currentWaypointIndex
		}

		let start = road.waypoints[vehicle.currentWaypointIndex].position
		let end = road.waypoints[vehicle.nextWaypointIndex].position
		vehicle.node.position = displayPosition(
			basePosition: interpolate(start: start, end: end, progress: vehicle.progress),
			start: start,
			end: end,
			laneOffset: vehicle.laneOffset
		)
		orient(vehicle: vehicle)
	}

	private func orient(vehicle: RoamingVehicle) {
		let start = road.waypoints[vehicle.currentWaypointIndex].position
		let end = road.waypoints[vehicle.nextWaypointIndex].position
		let dx = end.x - start.x
		let dz = end.z - start.z
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

	private func modelNameForGeneratedCar(index: Int) -> String? {
		let totalDensity = trafficSettings.cars.reduce(Float(0)) { $0 + max(0, $1.density) }
		if totalDensity <= 0 {
			return trafficSettings.cars[index % trafficSettings.cars.count].modelName
		}

		var pick = Float(index % 1000) / 1000 * totalDensity
		for car in trafficSettings.cars {
			pick -= max(0, car.density)
			if pick <= 0 {
				return car.modelName
			}
		}
		return trafficSettings.cars.last?.modelName
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

	private func interpolate(start: SCNVector3, end: SCNVector3, progress: Float) -> SCNVector3 {
		let t = SCNFloat(progress)
		return SCNVector3(
			x: start.x + (end.x - start.x) * t,
			y: start.y + (end.y - start.y) * t,
			z: start.z + (end.z - start.z) * t
		)
	}

	private func displayPosition(for vehicle: RoamingVehicle) -> SCNVector3 {
		let start = road.waypoints[vehicle.currentWaypointIndex].position
		let end = road.waypoints[vehicle.nextWaypointIndex].position
		return displayPosition(basePosition: start, start: start, end: end, laneOffset: vehicle.laneOffset)
	}

	private func displayPosition(
		basePosition: SCNVector3,
		start: SCNVector3,
		end: SCNVector3,
		laneOffset: Float
	) -> SCNVector3 {
		let dx = Float(end.x - start.x)
		let dz = Float(end.z - start.z)
		let length = max(minimumSegmentLength, sqrt(dx * dx + dz * dz))
		let rightX = dz / length
		let rightZ = -dx / length

		return SCNVector3(
			x: basePosition.x + SCNFloat(rightX * laneOffset),
			y: basePosition.y,
			z: basePosition.z + SCNFloat(rightZ * laneOffset)
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
