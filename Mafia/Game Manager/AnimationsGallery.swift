//
//  AnimationsGallery.swift
//  Mafia
//
//  Created by Codex on 07/06/2026.
//  Copyright (c) 2026 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

final class AnimationsGallery: @unchecked Sendable {

	private let scnScene = SCNScene()
	private let cameraNode = SCNNode()
	private let modelNode: SCNNode
	private let originalTransforms: [ObjectIdentifier: SCNMatrix4]
	private let animations: [AnimationGalleryEntry]
	private weak var gameManager: GameManager?

	init(gameManager: GameManager) throws {
		self.gameManager = gameManager
		modelNode = try loadModel(named: "models/tommyhighhat")
		modelNode.name = "__animation_gallery_model__"
		modelNode.eulerAngles.y = .pi
		originalTransforms = AnimationsGallery.captureTransforms(in: modelNode)
		animations = AnimationsGallery.loadAnimationEntries()

		scnScene.rootNode.name = "__animation_gallery_root__"
		scnScene.rootNode.addChildNode(modelNode)
		setupCamera()
		setupLights()
	}

	@MainActor func setup(in view: SCNView) {
		view.scene = scnScene
		view.delegate = nil
		view.pointOfView = cameraNode
		view.audioListener = cameraNode
		view.overlaySKScene = AnimationsGalleryScene(
			size: view.bounds.size,
			animations: animations,
			gameManager: gameManager
		) { [weak self] entry in
			Task { @MainActor in
				self?.playGalleryAnimation(entry)
			}
		}

		if let firstAnimation = animations.first {
			playGalleryAnimation(firstAnimation)
		}
	}

	private func playGalleryAnimation(_ entry: AnimationGalleryEntry) {
		modelNode.removeAllActionsRecursively()
		restoreOriginalTransforms()
		clearAnimationTargetCache(for: modelNode)

		do {
			try playAnimation(
				named: entry.path,
				in: modelNode,
				repeat: true,
				animationKey: "__gallery_animation__",
				transitionDuration: 0.12
			)
		} catch {
			print("Animation gallery failed to play \(entry.path):", error)
		}
	}

	private func restoreOriginalTransforms() {
		modelNode.enumerateHierarchy { node, _ in
			guard let transform = self.originalTransforms[ObjectIdentifier(node)] else { return }
			node.transform = transform
		}
	}

	private func setupCamera() {
		let camera = SCNCamera()
		camera.zNear = 0.01
		camera.zFar = 1000
		cameraNode.camera = camera
		cameraNode.scale = SCNVector3(x: 1, y: -1, z: 1)
		scnScene.rootNode.addChildNode(cameraNode)

		let bounds = modelBounds()
		let center = bounds.center
		let radius = max(bounds.radius, 1)
		cameraNode.position = SCNVector3(center.x, center.y + radius * 0.45, center.z - radius * 3.2)
		cameraNode.eulerAngles = SCNVector3(x: .pi, y: 0, z: 0)
	}

	private func setupLights() {
		let ambient = SCNNode()
		ambient.light = SCNLight()
		ambient.light?.type = .ambient
		ambient.light?.intensity = 420
		scnScene.rootNode.addChildNode(ambient)

		let key = SCNNode()
		key.light = SCNLight()
		key.light?.type = .omni
		key.light?.intensity = 900
		key.position = SCNVector3(0, 4, 8)
		scnScene.rootNode.addChildNode(key)
	}

	private func modelBounds() -> (center: SCNVector3, radius: SCNFloat) {
		let bounds = AnimationsGallery.hierarchyBounds(in: modelNode)
		let minPoint = bounds.min
		let maxPoint = bounds.max
		let center = SCNVector3(
			x: (minPoint.x + maxPoint.x) / 2,
			y: (minPoint.y + maxPoint.y) / 2,
			z: (minPoint.z + maxPoint.z) / 2
		)
		let size = SCNVector3(
			x: maxPoint.x - minPoint.x,
			y: maxPoint.y - minPoint.y,
			z: maxPoint.z - minPoint.z
		)
		let radius = max(size.x, max(size.y, size.z)) / 2
		return (center, radius)
	}

	private static func hierarchyBounds(in rootNode: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
		var minPoint = SCNVector3(
			x: SCNFloat.greatestFiniteMagnitude,
			y: SCNFloat.greatestFiniteMagnitude,
			z: SCNFloat.greatestFiniteMagnitude
		)
		var maxPoint = SCNVector3(
			x: -SCNFloat.greatestFiniteMagnitude,
			y: -SCNFloat.greatestFiniteMagnitude,
			z: -SCNFloat.greatestFiniteMagnitude
		)
		var didFindBounds = false

		rootNode.enumerateHierarchy { node, _ in
			guard node.geometry != nil else { return }
			let bounds = node.boundingBox
			for point in AnimationsGallery.corners(min: bounds.min, max: bounds.max) {
				let convertedPoint = rootNode.convertPosition(point, from: node)
				minPoint.x = min(minPoint.x, convertedPoint.x)
				minPoint.y = min(minPoint.y, convertedPoint.y)
				minPoint.z = min(minPoint.z, convertedPoint.z)
				maxPoint.x = max(maxPoint.x, convertedPoint.x)
				maxPoint.y = max(maxPoint.y, convertedPoint.y)
				maxPoint.z = max(maxPoint.z, convertedPoint.z)
				didFindBounds = true
			}
		}

		if didFindBounds {
			return (minPoint, maxPoint)
		}

		return rootNode.boundingBox
	}

	private static func corners(min: SCNVector3, max: SCNVector3) -> [SCNVector3] {
		return [
			SCNVector3(min.x, min.y, min.z),
			SCNVector3(min.x, min.y, max.z),
			SCNVector3(min.x, max.y, min.z),
			SCNVector3(min.x, max.y, max.z),
			SCNVector3(max.x, min.y, min.z),
			SCNVector3(max.x, min.y, max.z),
			SCNVector3(max.x, max.y, min.z),
			SCNVector3(max.x, max.y, max.z)
		]
	}

	private static func captureTransforms(in rootNode: SCNNode) -> [ObjectIdentifier: SCNMatrix4] {
		var transforms: [ObjectIdentifier: SCNMatrix4] = [:]
		rootNode.enumerateHierarchy { node, _ in
			transforms[ObjectIdentifier(node)] = node.transform
		}
		return transforms
	}

	private static func loadAnimationEntries() -> [AnimationGalleryEntry] {
		let animationsDirectory = mainDirectory.appendingPathComponent("anims")
		guard let enumerator = FileManager.default.enumerator(
			at: animationsDirectory,
			includingPropertiesForKeys: [.isRegularFileKey],
			options: [.skipsHiddenFiles]
		) else {
			return []
		}

		var entries: [AnimationGalleryEntry] = []
		for case let url as URL in enumerator {
			guard url.pathExtension.lowercased() == "5ds" else { continue }
			let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
			guard resourceValues?.isRegularFile == true else { continue }

			let relativePath = url.path
				.dropFirst(animationsDirectory.path.count)
				.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
				.replacingOccurrences(of: "\\", with: "/")
			guard !relativePath.isEmpty else { continue }

			let path = "anims/" + relativePath
			entries.append(AnimationGalleryEntry(
				title: relativePath.replacingOccurrences(of: ".5ds", with: "", options: [.caseInsensitive]),
				path: path
			))
		}

		return entries.sorted {
			$0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
		}
	}
}

struct AnimationGalleryEntry {
	let title: String
	let path: String
}

private final class AnimationsGalleryScene: SKScene {

	private weak var gameManager: GameManager?
	private let animations: [AnimationGalleryEntry]
	private let onAnimationSelected: @Sendable (AnimationGalleryEntry) -> Void
	private var filteredAnimations: [AnimationGalleryEntry]
	private var labels: [SKLabelNode] = []
	private var selectedIndex = 0
	private var firstVisibleIndex = 0
	private var searchText = ""
	private var rowHeight: CGFloat = 30
	private var firstRowY: CGFloat = 0
	private let maxVisibleAnimations = 20
	private let titleLabel = SKLabelNode(fontNamed: mafiaMenuFontName)
	private let searchLabel = SKLabelNode(fontNamed: "Arial")
	private let selectedLabel = SKLabelNode(fontNamed: "Arial")
	private let hintLabel = SKLabelNode(fontNamed: "Arial")
	#if os(iOS)
	private var lastSwipePoint: CGPoint?
	private var didSwipe = false
	#endif

	init(
		size: CGSize,
		animations: [AnimationGalleryEntry],
		gameManager: GameManager?,
		onAnimationSelected: @escaping @Sendable (AnimationGalleryEntry) -> Void
	) {
		self.animations = animations
		filteredAnimations = animations
		self.gameManager = gameManager
		self.onAnimationSelected = onAnimationSelected

		super.init(size: size)

		scaleMode = .resizeFill
		backgroundColor = .clear
		isUserInteractionEnabled = true

		titleLabel.text = "Animations"
		titleLabel.fontColor = .white
		titleLabel.horizontalAlignmentMode = .left
		addChild(titleLabel)

		searchLabel.fontColor = .white
		searchLabel.horizontalAlignmentMode = .left
		addChild(searchLabel)

		selectedLabel.fontColor = SKColor(white: 0.82, alpha: 1)
		selectedLabel.horizontalAlignmentMode = .left
		addChild(selectedLabel)

		#if os(iOS)
		hintLabel.text = animations.isEmpty ? "No animations found" : "Swipe up/down, double-tap to replay"
		#else
		hintLabel.text = animations.isEmpty ? "No animations found" : "Type to search, arrows select, Return replays, Esc returns"
		#endif
		hintLabel.fontColor = SKColor(white: 0.75, alpha: 1)
		hintLabel.horizontalAlignmentMode = .left
		addChild(hintLabel)

		for _ in 0 ..< min(maxVisibleAnimations, animations.count) {
			let label = SKLabelNode(fontNamed: "Arial")
			label.horizontalAlignmentMode = .left
			label.verticalAlignmentMode = .center
			addChild(label)
			labels.append(label)
		}

		didChangeSize(.zero)
		refreshLabels()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	nonisolated override func didChangeSize(_ oldSize: CGSize) {
		Task { @MainActor [weak self] in
			self?.layoutScene()
		}
	}

	private func layoutScene() {
		let panelWidth = min(max(280, size.width * 0.34), 420)
		let x = max(24, size.width - panelWidth - 24)
		titleLabel.fontSize = 34
		titleLabel.position = CGPoint(x: x, y: size.height - 56)

		searchLabel.fontSize = 15
		searchLabel.position = CGPoint(x: x, y: size.height - 84)
		searchLabel.preferredMaxLayoutWidth = panelWidth

		selectedLabel.fontSize = 14
		selectedLabel.position = CGPoint(x: x, y: size.height - 108)
		selectedLabel.preferredMaxLayoutWidth = panelWidth

		hintLabel.fontSize = 13
		hintLabel.position = CGPoint(x: x, y: 24)
		hintLabel.preferredMaxLayoutWidth = panelWidth

		rowHeight = min(30, max(20, (size.height - 170) / CGFloat(max(1, labels.count))))
		firstRowY = size.height - 150

		for (index, label) in labels.enumerated() {
			label.fontSize = min(16, rowHeight * 0.64)
			label.position = CGPoint(x: x, y: firstRowY - CGFloat(index) * rowHeight)
			label.preferredMaxLayoutWidth = panelWidth
		}
	}

	private func refreshLabels() {
		searchLabel.text = searchText.isEmpty ? "Search: " : "Search: " + searchText
		selectedLabel.text = filteredAnimations.indices.contains(selectedIndex) ? filteredAnimations[selectedIndex].path : nil

		for (labelIndex, label) in labels.enumerated() {
			let animationIndex = firstVisibleIndex + labelIndex
			guard filteredAnimations.indices.contains(animationIndex) else {
				label.text = nil
				continue
			}

			label.text = (animationIndex == selectedIndex ? "> " : "  ") + filteredAnimations[animationIndex].title
			label.fontColor = animationIndex == selectedIndex ? .white : SKColor(white: 0.68, alpha: 1)
		}
	}

	private func moveSelection(by offset: Int) {
		guard !filteredAnimations.isEmpty else { return }

		selectedIndex = max(0, min(filteredAnimations.count - 1, selectedIndex + offset))
		if selectedIndex < firstVisibleIndex {
			firstVisibleIndex = selectedIndex
		} else if selectedIndex >= firstVisibleIndex + labels.count {
			firstVisibleIndex = selectedIndex - labels.count + 1
		}
		refreshLabels()
		playSelectedAnimation()
	}

	private func playSelectedAnimation() {
		guard filteredAnimations.indices.contains(selectedIndex) else { return }
		onAnimationSelected(filteredAnimations[selectedIndex])
	}

	private func updateSearchText(_ newSearchText: String) {
		searchText = newSearchText
		if searchText.isEmpty {
			filteredAnimations = animations
		} else {
			filteredAnimations = animations.filter {
				$0.title.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil ||
					$0.path.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
			}
		}

		selectedIndex = 0
		firstVisibleIndex = 0
		refreshLabels()
		playSelectedAnimation()
	}

	#if os(macOS)

	private func appendSearchText(from event: NSEvent) -> Bool {
		guard let characters = event.charactersIgnoringModifiers,
			  !characters.isEmpty else { return false }

		let filteredCharacters = characters.filter { character in
			guard let scalar = String(character).unicodeScalars.first else { return false }
			return !CharacterSet.controlCharacters.contains(scalar)
		}
		guard !filteredCharacters.isEmpty else { return false }

		updateSearchText(searchText + String(filteredCharacters))
		return true
	}

	override func keyDown(with event: NSEvent) {
		switch event.keyCode {
		case 125:
			moveSelection(by: 1)
		case 126:
			moveSelection(by: -1)
		case 36, 76:
			playSelectedAnimation()
		case 53:
			gameManager?.loadMenu()
		case 51, 117:
			guard !searchText.isEmpty else { return }
			updateSearchText(String(searchText.dropLast()))
		default:
			if !appendSearchText(from: event) {
				super.keyDown(with: event)
			}
		}
	}

	override func mouseDown(with event: NSEvent) {
		selectAnimation(at: event.location(in: self))
	}

	#elseif os(iOS)

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let point = touches.first?.location(in: self) else { return }
		lastSwipePoint = point
		didSwipe = false
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let point = touches.first?.location(in: self),
			  let lastPoint = lastSwipePoint else { return }

		let deltaY = point.y - lastPoint.y
		let threshold = max(18, rowHeight * 0.75)
		if abs(deltaY) >= threshold {
			moveSelection(by: deltaY > 0 ? -1 : 1)
			lastSwipePoint = point
			didSwipe = true
		}
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else { return }
		defer {
			lastSwipePoint = nil
			didSwipe = false
		}

		if didSwipe {
			return
		}

		if touch.tapCount >= 2 {
			playSelectedAnimation()
		}
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		lastSwipePoint = nil
		didSwipe = false
	}

	#endif

	private func selectAnimation(at point: CGPoint) {
		guard let labelIndex = rowIndex(at: point) else { return }

		selectedIndex = firstVisibleIndex + labelIndex
		refreshLabels()
		playSelectedAnimation()
	}

	private func rowIndex(at point: CGPoint) -> Int? {
		guard rowHeight > 0 else { return nil }

		let labelIndex = Int(round((firstRowY - point.y) / rowHeight))
		guard labels.indices.contains(labelIndex) else { return nil }

		let rowCenterY = firstRowY - CGFloat(labelIndex) * rowHeight
		guard abs(point.y - rowCenterY) <= rowHeight / 2 else { return nil }

		let animationIndex = firstVisibleIndex + labelIndex
		return filteredAnimations.indices.contains(animationIndex) ? labelIndex : nil
	}
}

private extension SCNNode {
	func removeAllActionsRecursively() {
		removeAllActions()
		for child in childNodes {
			child.removeAllActionsRecursively()
		}
	}
}
