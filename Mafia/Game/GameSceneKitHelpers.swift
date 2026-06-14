//
//  GameSceneKitHelpers.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

extension SCNNode {
	func setHiddenInHierarchy(_ hidden: Bool) {
		isHidden = hidden
		for child in childNodes {
			child.setHiddenInHierarchy(hidden)
		}
	}
}

extension SCNNode {
	var hasModelContent: Bool {
		if geometry != nil {
			return true
		}
		return childNodes.contains { $0.hasModelContent }
	}

	func firstNode(where matches: (SCNNode) -> Bool) -> SCNNode? {
		if matches(self) {
			return self
		}
		for child in childNodes {
			if let node = child.firstNode(where: matches) {
				return node
			}
		}
		return nil
	}

	func firstResult<Result>(where transform: (SCNNode) -> Result?) -> Result? {
		if let result = transform(self) {
			return result
		}
		for child in childNodes {
			if let result = child.firstResult(where: transform) {
				return result
			}
		}
		return nil
	}

	func hideSkyboxBackdropGeometry() {
		if isSkyboxBackdropNode {
			isHidden = true
			return
		}
		for child in childNodes {
			child.hideSkyboxBackdropGeometry()
		}
	}

	func disablePhysicsInHierarchy() {
		physicsBody = nil
		for child in childNodes {
			child.disablePhysicsInHierarchy()
		}
	}

	var isSkyboxBackdropNode: Bool {
		if isSkyboxBackdropResourceName(name) {
			return true
		}
		return geometry?.materials.contains { material in
			isSkyboxBackdropResourceName(material.name)
		} ?? false
	}

	func skyboxTextureSet() -> String? {
		if let textureSet = skyboxTextureSetName(from: name) {
			return textureSet
		}
		if let materialTextureSet = geometry?.materials.compactMap({ skyboxTextureSetName(from: $0.name) }).first {
			return materialTextureSet
		}
		for child in childNodes {
			if let textureSet = child.skyboxTextureSet() {
				return textureSet
			}
		}
		return nil
	}

	func skyboxNodes(relativeTo cameraPosition: SCNVector3) -> [(node: SCNNode, offset: SCNVector3)] {
		var nodes: [(node: SCNNode, offset: SCNVector3)] = []
		guard !isHidden else { return nodes }
		if isSkyboxNode {
			nodes.append((self, presentation.worldPosition - cameraPosition))
			return nodes
		}
		for child in childNodes {
			nodes.append(contentsOf: child.skyboxNodes(relativeTo: cameraPosition))
		}
		return nodes
	}

	var isSkyboxNode: Bool {
		return followsCamera && parent?.parent?.name == "__cache__"
	}

	func containsWorldPosition(_ position: SCNVector3) -> Bool {
		let bounds = boundingBox
		guard bounds.max.x > bounds.min.x || bounds.max.y > bounds.min.y || bounds.max.z > bounds.min.z else {
			return false
		}

		let localPosition = presentation.convertPosition(position, from: nil)
		return localPosition.x >= bounds.min.x && localPosition.x <= bounds.max.x &&
			localPosition.y >= bounds.min.y && localPosition.y <= bounds.max.y &&
			localPosition.z >= bounds.min.z && localPosition.z <= bounds.max.z
	}

	var hierarchyLevel: Int {
		var level = 0
		var current = parent
		while current != nil {
			level += 1
			current = current?.parent
		}
		return level
	}

	func actionSquaredDistance(to position: SCNVector3) -> Float {
		let bounds = boundingBox
		guard bounds.max.x > bounds.min.x || bounds.max.y > bounds.min.y || bounds.max.z > bounds.min.z else {
			return squaredDistance(to: position)
		}

		let localPosition = presentation.convertPosition(position, from: nil)
		let closest = SCNVector3(
			x: max(bounds.min.x, min(bounds.max.x, localPosition.x)),
			y: max(bounds.min.y, min(bounds.max.y, localPosition.y)),
			z: max(bounds.min.z, min(bounds.max.z, localPosition.z))
		)
		let worldClosest = presentation.convertPosition(closest, to: nil)
		let dx = Float(worldClosest.x - position.x)
		let dy = Float(worldClosest.y - position.y)
		let dz = Float(worldClosest.z - position.z)
		return dx * dx + dy * dy + dz * dz
	}
}

extension Array where Element == EnvironmentLight {
	func bestMatch(
		kind: EnvironmentLightKind,
		cameraPosition: SCNVector3,
		rootNode: SCNNode,
		sectorNodes: inout [String: SCNNode],
		missingSectorNames: inout Set<String>
	) -> EnvironmentLight? {
		var bestLight: EnvironmentLight?
		var bestLevel = Int.min

		for light in self where light.kind == kind {
			let level: Int
			if let sectorName = light.sectorName,
			   let sectorNode = environmentSectorNode(
				named: sectorName,
				rootNode: rootNode,
				sectorNodes: &sectorNodes,
				missingSectorNames: &missingSectorNames
			   ) {
				guard sectorNode.containsWorldPosition(cameraPosition) else { continue }
				level = sectorName == "Primary Sector" ? 0 : sectorNode.hierarchyLevel
			} else {
				level = light.node.hierarchyLevel
			}

			if level >= bestLevel {
				bestLight = light
				bestLevel = level
			}
		}

		return bestLight
	}

	func environmentSectorNode(
		named name: String,
		rootNode: SCNNode,
		sectorNodes: inout [String: SCNNode],
		missingSectorNames: inout Set<String>
	) -> SCNNode? {
		if let sectorNode = sectorNodes[name] {
			return sectorNode
		}
		guard !missingSectorNames.contains(name) else { return nil }
		guard let sectorNode = rootNode.mafiaChildNode(named: name, recursively: true) else {
			missingSectorNames.insert(name)
			return nil
		}
		sectorNodes[name] = sectorNode
		return sectorNode
	}
}

extension EnvironmentLight {
	var isOutdoorLight: Bool {
		guard let sectorName else { return true }
		return sectorName.caseInsensitiveCompare("Primary Sector") == .orderedSame
	}
}

extension SKColor {
	func multiplied(by value: CGFloat) -> SKColor {
		let components = rgbaComponents
		return SKColor(
			red: min(1, components.red * value),
			green: min(1, components.green * value),
			blue: min(1, components.blue * value),
			alpha: components.alpha
		)
	}

	func lerped(to target: SKColor, amount: CGFloat) -> SKColor {
		let start = rgbaComponents
		let end = target.rgbaComponents
		return SKColor(
			red: start.red + (end.red - start.red) * amount,
			green: start.green + (end.green - start.green) * amount,
			blue: start.blue + (end.blue - start.blue) * amount,
			alpha: start.alpha + (end.alpha - start.alpha) * amount
		)
	}

	var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
		#if os(macOS)
			let color = usingColorSpace(.deviceRGB) ?? self
			return (color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent)
		#elseif os(iOS)
			var red: CGFloat = 0
			var green: CGFloat = 0
			var blue: CGFloat = 0
			var alpha: CGFloat = 0
			getRed(&red, green: &green, blue: &blue, alpha: &alpha)
			return (red, green, blue, alpha)
		#endif
	}
}

func skyboxTextureSetName(from name: String?) -> String? {
	guard let name = name?.lowercased() else { return nil }
	for component in name.components(separatedBy: "|") where component.hasPrefix("sky ") && component.hasSuffix(".bmp") {
		let parts = component.components(separatedBy: " ")
		guard parts.count >= 3 else { continue }
		return parts.dropLast().joined(separator: " ")
	}
	return nil
}

func loadMapImage(named name: String) -> Any? {
	guard let url = mafiaMapURL(named: name) else { return nil }
	#if os(macOS)
		return NSImage(contentsOf: url)
	#elseif os(iOS)
		return UIImage(contentsOfFile: url.path)
	#endif
}
