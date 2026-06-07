//
//  MainMenu.swift
//  Mafia
//
//  Created by Alex Studnička on 17/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

class MainMenu {

	let scnScene = SCNScene()
	let cameraRig = SCNNode()
	let cameraNode = SCNNode()
	let scene: Scene
	private weak var gameManager: GameManager?
	private let menuDef: MenuDef
	private let menuControls: [MenuDefControl]
	private let loadGameControls: [MenuDefControl]
	private let entries: [MainMenuEntry]
	private weak var menuScene: MainMenuScene?
	private var menuChangeSoundSource: SCNAudioSource?

	init(gameManager: GameManager) throws {
		self.gameManager = gameManager
		let loadedMenuDef = try MenuDef()
		let loadedMenuControls = MainMenu.visibleControls(in: loadedMenuDef.controls(for: .mainMenu))
		menuDef = loadedMenuDef
		menuControls = loadedMenuControls
		loadGameControls = loadedMenuDef.controls(for: .loadGame)
		entries = MainMenu.makeEntries(from: loadedMenuControls)

		scnScene.rootNode.name = "__root__"
		cameraRig.name = "__main_menu_camera__"

		let sceneModel = try loadModel(named: "missions/00menu/scene")
		sceneModel.name = "__model__"
		scnScene.rootNode.addChildNode(sceneModel)

		scene = try Scene(named: "missions/00menu")
		scene.rootNode.name = "__scene__"
		scnScene.rootNode.addChildNode(scene.rootNode)
		scene.playerNode?.removeFromParentNode()
		scene.playerNode = nil

		if let loadedMissionEffects = try? MissionEffects(name: "missions/00menu"),
		   let missionEffects = loadedMissionEffects {
			missionEffects.node.name = "__effects__"
			scnScene.rootNode.addChildNode(missionEffects.node)
		}

		// -----

		let camera = SCNCamera()
		camera.zNear = 0.01
		camera.zFar = 1000
//		camera.wantsHDR = true

		cameraNode.camera = camera
		cameraNode.scale = SCNVector3(x: 1, y: -1, z: 1)

		cameraNode.eulerAngles = SCNVector3(x: .pi, y: 0, z: 0)
		cameraRig.addChildNode(cameraNode)
		scnScene.rootNode.addChildNode(cameraRig)

		if let startAnchor = menuAnchor(named: "camera_start") ?? entries.first.flatMap({ menuAnchor(named: $0.anchorName) }) {
			cameraRig.transform = startAnchor.presentation.worldTransform
		}
	}

	private static func visibleControls(in controls: [MenuDefControl]) -> [MenuDefControl] {
		guard let lastTagIndex = controls.lastIndex(where: { $0.type == "etag" }) else { return controls }
		return Array(controls[(lastTagIndex + 1)...])
	}

	private static func makeEntries(from controls: [MenuDefControl]) -> [MainMenuEntry] {
		return controls
			.filter { $0.type == "meti" }
			.sorted { $0.position.y < $1.position.y }
			.map { control in
				MainMenuEntry(
					control: control,
					title: TextDb.get(Int(control.textId)) ?? "",
					anchorName: anchorName(for: control.id),
					action: action(for: control.id)
				)
			}
	}

	private static func anchorName(for controlId: UInt32) -> String {
		switch controlId {
		case 990101:
			return "intro_pos"
		case 990102:
			return "training_pos"
		case 990103:
			return "new_game_pos"
		case 990104:
			return "load_game_pos"
		case 990105:
			return "free_ride_pos"
		case 990106:
			return "champion_pos"
		case 990109:
			return "carcyclopedia_pos"
		case 990110:
			return "options_pos"
		case 990111:
			return "credits_pos"
		case 990112:
			return "single_pos"
		case 990113:
			return "exit_pos"
		default:
			return "camera_start"
		}
	}

	private static func action(for controlId: UInt32) -> MainMenuAction {
		switch controlId {
		case 990101:
			return .mission(folder: "intro", imageName: "00menu.tga")
		case 990102:
			return .mission(folder: "tutorial", imageName: "tutorial.tga")
		case 990103:
			return .missionSelector
		case 990104:
			return .saveGameSelector
		case 990109:
			return .mission(folder: "autosalon", imageName: "carcyklopedia.tga")
		case 990110:
			return .animationsGallery
		default:
			return .none
		}
	}

	func setup(in view: SCNView) {
		view.scene = scnScene
		let menuScene = MainMenuScene(size: view.bounds.size, controls: menuControls, entries: entries, loadGameControls: loadGameControls)
		self.menuScene = menuScene
		menuScene.onSelectionChanged = { [weak self] index in
			self?.playMenuChangeSound()
			self?.selectEntry(at: index)
		}
		menuScene.onEntryActivated = { [weak self] index in
			self?.activateEntry(at: index)
		}
		menuScene.onSaveGameActivated = { [weak self] saveGame in
			self?.stopMenuScripts()
			self?.gameManager?.loadSaveGame(saveGame)
		}
		view.overlaySKScene = menuScene
		view.delegate = nil
		view.pointOfView = cameraNode
		view.audioListener = cameraRig
		scene.startScripts()
		selectEntry(at: 0, animated: false)
	}

	private func selectEntry(at index: Int, animated: Bool = true) {
		guard entries.indices.contains(index),
			  let anchor = menuAnchor(named: entries[index].anchorName) else { return }

		moveCamera(to: anchor, animated: animated)
	}

	private func playMenuChangeSound() {
		if menuChangeSoundSource == nil {
			let url = mainDirectory.appendingPathComponent("sounds/menuchange.wav")
			guard let source = SCNAudioSource(url: url) else { return }
			source.isPositional = false
			source.load()
			menuChangeSoundSource = source
		}

		guard let source = menuChangeSoundSource else { return }
		scene.playAudio(source, on: scene.rootNode)
	}

	private func stopMenuScripts() {
		scene.destroyScriptMusicStreams()
	}

	private func activateEntry(at index: Int) {
		guard entries.indices.contains(index) else { return }

		switch entries[index].action {
		case .mission(let folder, let imageName):
			stopMenuScripts()
			gameManager?.loadMission(textId: MissionLoadInfo.textId(for: folder), imageName: imageName, folder: folder)
		case .saveGameSelector:
			menuScene?.showSaveGameSelector(saveGames: SaveGame.loadSlots())
		case .missionSelector:
			stopMenuScripts()
			gameManager?.loadMissionSelector()
		case .animationsGallery:
			stopMenuScripts()
			gameManager?.loadAnimationsGallery()
		case .none:
			break
		}
	}

	private func menuAnchor(named name: String) -> SCNNode? {
		return scnScene.rootNode.mafiaChildNode(named: name, recursively: true)
	}

	private func moveCamera(to anchor: SCNNode, animated: Bool) {
		let targetTransform = anchor.presentation.worldTransform
		guard animated else {
			cameraRig.removeAllActions()
			cameraRig.transform = targetTransform
			return
		}

		let startPosition = cameraRig.presentation.position
		let startEulerAngles = cameraRig.presentation.eulerAngles
		let targetPosition = SCNVector3(targetTransform.m41, targetTransform.m42, targetTransform.m43)
		let targetEulerAngles = MainMenu.eulerAngles(from: targetTransform)
		cameraRig.removeAllActions()
		cameraRig.runAction(SCNAction.customAction(duration: 0.45) { node, elapsedTime in
			let progress = MainMenu.smoothStep(SCNFloat(elapsedTime / 0.45))
			node.position = MainMenu.interpolate(from: startPosition, to: targetPosition, progress: progress)
			node.eulerAngles = MainMenu.interpolate(from: startEulerAngles, to: targetEulerAngles, progress: progress)
		})
	}

	private static func interpolate(from: SCNVector3, to: SCNVector3, progress: SCNFloat) -> SCNVector3 {
		return SCNVector3(
			x: from.x + (to.x - from.x) * progress,
			y: from.y + (to.y - from.y) * progress,
			z: from.z + (to.z - from.z) * progress
		)
	}

	private static func smoothStep(_ value: SCNFloat) -> SCNFloat {
		let progress = max(0, min(1, value))
		return progress * progress * (3 - 2 * progress)
	}

	private static func eulerAngles(from transform: SCNMatrix4) -> SCNVector3 {
		let node = SCNNode()
		node.transform = transform
		return node.eulerAngles
	}

}

private struct MainMenuEntry {
	let control: MenuDefControl
	let title: String
	let anchorName: String
	let action: MainMenuAction
}

private enum MainMenuAction {
	case mission(folder: String, imageName: String)
	case saveGameSelector
	case missionSelector
	case animationsGallery
	case none
}

private final class MainMenuScene: SKScene {

	var onSelectionChanged: ((Int) -> Void)?
	var onEntryActivated: ((Int) -> Void)?
	var onSaveGameActivated: ((SaveGameSlot) -> Void)?

	private let controls: [MenuDefControl]
	private let entries: [MainMenuEntry]
	private let loadGameControls: [MenuDefControl]
	private let paperNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir3.tga")))
	private let headerNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir5a.tga")))
	private let selectionLine = SKShapeNode()
	private let titleLabel = SKLabelNode(fontNamed: mafiaMenuTitleFontName)
	private var labels: [SKLabelNode] = []
	private var selectedIndex = 0
	private var rowHeight: CGFloat = 31
	private var firstRowY: CGFloat = 0
	private var menuFrame = CGRect.zero
	private var saveGameDialog: SaveGameDialogNode?
	#if os(iOS)
	private var lastSwipePoint: CGPoint?
	private var didSwipe = false
	#endif

	init(size: CGSize, controls: [MenuDefControl], entries: [MainMenuEntry], loadGameControls: [MenuDefControl]) {
		self.controls = controls
		self.entries = entries
		self.loadGameControls = loadGameControls

		super.init(size: size)

		scaleMode = .resizeFill
		backgroundColor = .clear
		isUserInteractionEnabled = true

		paperNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		paperNode.alpha = 0.92
		paperNode.zPosition = 10
		addChild(paperNode)

		headerNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		headerNode.zPosition = 11
		addChild(headerNode)

		selectionLine.strokeColor = SKColor(red: 0.42, green: 0.04, blue: 0.03, alpha: 1)
		selectionLine.lineWidth = 2
		selectionLine.zPosition = 21
		addChild(selectionLine)

		titleLabel.fontColor = .white
		titleLabel.horizontalAlignmentMode = .center
		titleLabel.verticalAlignmentMode = .center
		titleLabel.zPosition = 20
		addChild(titleLabel)

		for entry in entries {
			let label = SKLabelNode(fontNamed: mafiaMenuFontName)
			label.text = entry.title
			label.horizontalAlignmentMode = .center
			label.verticalAlignmentMode = .center
			label.zPosition = 20
			addChild(label)
			labels.append(label)
		}

		didChangeSize(.zero)
		refreshSelection()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func didChangeSize(_ oldSize: CGSize) {
		super.didChangeSize(oldSize)

		layoutReferenceMainMenu()
		saveGameDialog?.layout(size: size)
	}

	func showSaveGameSelector(saveGames: [SaveGameSlot]) {
		saveGameDialog?.removeFromParent()
		let dialog = SaveGameDialogNode(saveGames: saveGames, controls: loadGameControls)
		dialog.onDismiss = { [weak self] in
			self?.saveGameDialog?.removeFromParent()
			self?.saveGameDialog = nil
			self?.didChangeSize(.zero)
		}
		dialog.onSaveGameActivated = { [weak self] saveGame in
			self?.onSaveGameActivated?(saveGame)
		}
		dialog.zPosition = 40
		addChild(dialog)
		saveGameDialog = dialog
		layoutReferenceMainMenu()
		dialog.layout(size: size)
	}

	private func layoutReferenceMainMenu() -> CGRect {
		let scale = menuDefScale()
		let titleWindow = controls.first { $0.type == "tniw" }
		let frame = frame(for: titleWindow, scale: scale)
		let titleHeight = min(50 * scale, frame.height * 0.16)
		headerNode.position = CGPoint(x: frame.midX, y: frame.maxY - titleHeight / 2)
		headerNode.size = CGSize(width: frame.width, height: titleHeight)
		titleLabel.fontSize = min(36 * scale, titleHeight * 0.68)
		titleLabel.position = headerNode.position
		titleLabel.text = titleWindow.flatMap { TextDb.get(Int($0.textId)) }

		let paperFrame = CGRect(
			x: frame.minX,
			y: frame.minY,
			width: frame.width,
			height: frame.height - titleHeight
		)
		paperNode.position = CGPoint(x: paperFrame.midX, y: paperFrame.midY)
		paperNode.size = paperFrame.size

		for (index, label) in labels.enumerated() {
			let control = entries[index].control
			let controlFrame = childFrame(for: control, in: paperFrame, scale: scale)
			rowHeight = controlFrame.height
			label.fontSize = min(36 * scale, controlFrame.height * 0.94)
			label.position = CGPoint(x: controlFrame.midX, y: controlFrame.midY)
			label.preferredMaxLayoutWidth = controlFrame.width
		}

		menuFrame = frame
		refreshSelection()
		return frame
	}

	private func menuDefScale() -> CGFloat {
		return min(size.width / 800, size.height / 600, 1.6)
	}

	private func frame(for control: MenuDefControl?, scale: CGFloat) -> CGRect {
		return referenceFrame(
			x: CGFloat(control?.position.x ?? 55),
			y: CGFloat(control?.position.y ?? 60),
			width: CGFloat(control?.scaleX ?? 217),
			height: CGFloat(control?.scaleY ?? 353),
			scale: scale
		)
	}

	private func childFrame(for control: MenuDefControl, in parentFrame: CGRect, scale: CGFloat) -> CGRect {
		let width = CGFloat(control.scaleX) * scale
		let height = CGFloat(control.scaleY) * scale
		return CGRect(
			x: parentFrame.minX + control.position.x * scale,
			y: parentFrame.maxY - control.position.y * scale - height,
			width: width,
			height: height
		)
	}

	private func referenceFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, scale: CGFloat) -> CGRect {
		let referenceOrigin = CGPoint(
			x: (size.width - 800 * scale) / 2,
			y: (size.height - 600 * scale) / 2
		)
		return CGRect(
			x: referenceOrigin.x + x * scale,
			y: referenceOrigin.y + 600 * scale - (y + height) * scale,
			width: width * scale,
			height: height * scale
		)
	}

	private func refreshSelection() {
		for (index, label) in labels.enumerated() {
			let selected = index == selectedIndex
			label.fontColor = .black
			label.setScale(selected ? 1.07 : 1)
		}
		updateSelectionLine()
	}

	private func updateSelectionLine() {
		guard labels.indices.contains(selectedIndex) else { return }

		let label = labels[selectedIndex]
		let lineWidth = min(menuFrame.width - 80, max(24, label.frame.width * 0.72))
		let y = label.position.y - rowHeight * 0.34 - 2
		let path = CGMutablePath()
		path.move(to: CGPoint(x: label.position.x - lineWidth / 2, y: y))
		path.addLine(to: CGPoint(x: label.position.x + lineWidth / 2, y: y))
		selectionLine.path = path
	}

	private func moveSelection(by offset: Int) {
		guard !entries.isEmpty else { return }

		let newIndex = max(0, min(entries.count - 1, selectedIndex + offset))
		select(index: newIndex)
	}

	private func select(index: Int) {
		guard entries.indices.contains(index), index != selectedIndex else { return }

		selectedIndex = index
		refreshSelection()
		onSelectionChanged?(selectedIndex)
	}

	#if os(macOS)

	override func keyDown(with event: NSEvent) {
		if saveGameDialog?.keyDown(with: event) == true {
			return
		}

		switch event.keyCode {
		case 125:
			moveSelection(by: 1)
		case 126:
			moveSelection(by: -1)
		case 36, 76:
			onEntryActivated?(selectedIndex)
		default:
			super.keyDown(with: event)
		}
	}

	override func mouseDown(with event: NSEvent) {
		if saveGameDialog?.mouseDown(at: event.location(in: self)) == true {
			return
		}

		select(at: event.location(in: self))
	}

	#elseif os(iOS)

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let point = touches.first?.location(in: self) else { return }
		if saveGameDialog != nil {
			saveGameDialog?.touchesBegan(at: point)
			return
		}

		lastSwipePoint = point
		didSwipe = false
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		if saveGameDialog != nil {
			guard let point = touches.first?.location(in: self) else { return }
			saveGameDialog?.touchesMoved(to: point)
			return
		}

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
		if saveGameDialog != nil {
			saveGameDialog?.touchesEnded(tapCount: touch.tapCount)
			return
		}

		defer {
			lastSwipePoint = nil
			didSwipe = false
		}

		if didSwipe {
			return
		}

		if touch.tapCount >= 2 {
			onEntryActivated?(selectedIndex)
		}
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		if saveGameDialog != nil {
			saveGameDialog?.touchesCancelled()
			return
		}

		lastSwipePoint = nil
		didSwipe = false
	}

	#endif

	private func select(at point: CGPoint) {
		guard let labelIndex = rowIndex(at: point) else { return }
		if labelIndex == selectedIndex {
			onEntryActivated?(selectedIndex)
			return
		}
		select(index: labelIndex)
	}

	private func rowIndex(at point: CGPoint) -> Int? {
		guard menuFrame.contains(point), rowHeight > 0 else { return nil }

		return labels.firstIndex { $0.frame.insetBy(dx: -8, dy: -4).contains(point) }
	}

}

private final class SaveGameDialogNode: SKNode {

	var onDismiss: (() -> Void)?
	var onSaveGameActivated: ((SaveGameSlot) -> Void)?

	private let saveGames: [SaveGameSlot]
	private let controls: [MenuDefControl]
	private let paperNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir3.tga")))
	private let headerNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir5a.tga")))
	private let previewNode = SKSpriteNode()
	private let selectionLine = SKShapeNode()
	private let scrollbarTrackNode = SKShapeNode()
	private let scrollbarThumbNode = SKShapeNode()
	private let upArrowLabel = SKLabelNode(fontNamed: "Arial")
	private let downArrowLabel = SKLabelNode(fontNamed: "Arial")
	private let titleLabel = SKLabelNode(fontNamed: mafiaMenuTitleFontName)
	private let countLabel = SKLabelNode(fontNamed: "Arial")
	private let hintLabel = SKLabelNode(fontNamed: "Arial")
	private let detailLabel = SKLabelNode(fontNamed: "Arial")
	private var labels: [SKLabelNode] = []
	private var selectedIndex = 0
	private var firstVisibleIndex = 0
	private var rowHeight: CGFloat = 24
	private var firstRowY: CGFloat = 0
	private var listFrame = CGRect.zero
	private var scrollbarParentFrame = CGRect.zero
	private var sceneSize = CGSize.zero
	#if os(iOS)
	private var lastSwipePoint: CGPoint?
	private var didSwipe = false
	#endif

	init(saveGames: [SaveGameSlot], controls: [MenuDefControl]) {
		self.saveGames = saveGames
		self.controls = controls

		super.init()

		paperNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		paperNode.alpha = 0.94
		paperNode.zPosition = 0
		addChild(paperNode)

		headerNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		headerNode.zPosition = 1
		addChild(headerNode)

		previewNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		previewNode.zPosition = -31
		addChild(previewNode)

		selectionLine.strokeColor = SKColor(red: 0.88, green: 0.05, blue: 0.06, alpha: 1)
		selectionLine.lineWidth = 3
		selectionLine.zPosition = 13
		addChild(selectionLine)

		scrollbarTrackNode.strokeColor = SKColor(white: 0.32, alpha: 1)
		scrollbarTrackNode.lineWidth = 1
		scrollbarTrackNode.fillColor = SKColor(white: 0.83, alpha: 0.35)
		scrollbarTrackNode.zPosition = 10
		addChild(scrollbarTrackNode)

		scrollbarThumbNode.strokeColor = SKColor(white: 0.28, alpha: 1)
		scrollbarThumbNode.lineWidth = 1
		scrollbarThumbNode.fillColor = SKColor(white: 0.93, alpha: 0.6)
		scrollbarThumbNode.zPosition = 11
		addChild(scrollbarThumbNode)

		for arrowLabel in [upArrowLabel, downArrowLabel] {
			arrowLabel.fontColor = SKColor(white: 0.46, alpha: 1)
			arrowLabel.fontSize = 22
			arrowLabel.horizontalAlignmentMode = .center
			arrowLabel.verticalAlignmentMode = .center
			arrowLabel.zPosition = 12
			addChild(arrowLabel)
		}
		upArrowLabel.text = "▲"
		downArrowLabel.text = "▼"

		titleLabel.text = text(for: 171)
		titleLabel.fontColor = .white
		titleLabel.horizontalAlignmentMode = .left
		titleLabel.verticalAlignmentMode = .center
		titleLabel.zPosition = 12
		addChild(titleLabel)

		countLabel.text = String(format: text(for: 172), saveGames.count)
		countLabel.fontColor = .white
		countLabel.horizontalAlignmentMode = .right
		countLabel.verticalAlignmentMode = .center
		countLabel.zPosition = 12
		addChild(countLabel)

		hintLabel.text = text(for: 177)
		hintLabel.fontColor = .white
		hintLabel.horizontalAlignmentMode = .center
		hintLabel.verticalAlignmentMode = .center
		hintLabel.zPosition = 12
		addChild(hintLabel)

		detailLabel.fontColor = .black
		detailLabel.horizontalAlignmentMode = .left
		detailLabel.verticalAlignmentMode = .center
		detailLabel.zPosition = 12
		addChild(detailLabel)

		refreshLabels()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func layout(size: CGSize) {
		sceneSize = size
		let scale = menuScale()
		let titleWindow = control(type: "tniw", id: 2)
		let panelFrame = frame(for: titleWindow, scale: scale)
		let titleHeight = min(50 * scale, panelFrame.height * 0.16)

		headerNode.position = CGPoint(x: panelFrame.midX, y: panelFrame.maxY - titleHeight / 2)
		headerNode.size = CGSize(width: panelFrame.width, height: titleHeight)

		let paperFrame = CGRect(
			x: panelFrame.minX,
			y: panelFrame.minY,
			width: panelFrame.width,
			height: panelFrame.height - titleHeight
		)
		paperNode.position = CGPoint(x: paperFrame.midX, y: paperFrame.midY)
		paperNode.size = paperFrame.size
		scrollbarParentFrame = paperFrame

		titleLabel.fontSize = min(34 * scale, titleHeight * 0.68)
		titleLabel.position = CGPoint(x: panelFrame.minX + 28 * scale, y: panelFrame.maxY - titleHeight / 2 + 4 * scale)

		if let totalControl = control(type: "txtr", id: 10) {
			let totalFrame = childFrame(for: totalControl, in: paperFrame, scale: scale)
			countLabel.fontSize = min(18 * scale, max(12 * scale, totalFrame.height * 0.95))
			countLabel.position = CGPoint(x: totalFrame.maxX, y: totalFrame.midY)
		}

		layoutPreview(in: panelFrame, scale: scale)

		if let hintControl = control(id: 1401) {
			let hintFrame = childFrame(for: hintControl, in: panelFrame, scale: scale)
			hintLabel.fontSize = max(11 * scale, hintFrame.height * 0.95)
			hintLabel.position = CGPoint(x: hintFrame.midX, y: hintFrame.midY)
		}

		if let listControl = control(type: "dnws", id: 4) {
			listFrame = childFrame(for: listControl, in: paperFrame, scale: scale)
		} else {
			listFrame = paperFrame.insetBy(dx: 10 * scale, dy: 17 * scale)
		}

		let visibleCount = max(1, labels.count)
		let rowControl = control(type: "iles", id: 100)
		rowHeight = rowControl.map { CGFloat($0.scaleY) * scale } ?? min(20 * scale, listFrame.height / CGFloat(visibleCount))
		let visibleSaveGameCount = max(0, min(saveGames.count, Int(floor(listFrame.height / max(1, rowHeight)))))
		ensureLabelCount(visibleSaveGameCount)
		firstRowY = listFrame.maxY - rowHeight / 2 - 5 * scale
		let textX = listFrame.minX + (rowControl?.position.x ?? 10) * scale

		for (index, label) in labels.enumerated() {
			label.fontSize = min(18 * scale, rowHeight * 0.74)
			label.position = CGPoint(x: textX, y: firstRowY - CGFloat(index) * rowHeight)
			label.preferredMaxLayoutWidth = listFrame.width - 20 * scale
		}

		if let detailControl = control(id: 1010) {
			let detailSize = CGSize(width: CGFloat(detailControl.scaleX) * scale, height: CGFloat(detailControl.scaleY) * scale)
			let detailFrame = CGRect(
				x: listFrame.minX,
				y: paperFrame.minY + 10 * scale,
				width: min(detailSize.width, paperFrame.maxX - listFrame.minX - 16 * scale),
				height: detailSize.height
			)
			detailLabel.fontSize = min(14 * scale, max(10 * scale, detailFrame.height * 0.95))
			detailLabel.position = CGPoint(x: detailFrame.minX, y: detailFrame.midY)
			detailLabel.preferredMaxLayoutWidth = detailFrame.width
		} else {
			detailLabel.fontSize = min(18 * scale, 18 * scale)
			detailLabel.position = CGPoint(x: listFrame.minX, y: paperFrame.minY + 17 * scale)
			detailLabel.preferredMaxLayoutWidth = listFrame.width + 54 * scale
		}

		layoutScrollbar(scale: scale)
		refreshLabels()
	}

	private func ensureLabelCount(_ count: Int) {
		while labels.count < count {
			let label = SKLabelNode(fontNamed: "Arial")
			label.fontColor = .black
			label.horizontalAlignmentMode = .left
			label.verticalAlignmentMode = .center
			label.zPosition = 12
			addChild(label)
			labels.append(label)
		}

		while labels.count > count {
			labels.removeLast().removeFromParent()
		}
	}

	private func layoutPreview(in panelFrame: CGRect, scale: CGFloat) {
		guard let imageWindow = control(id: 1001),
			  let previewControl = control(type: "tcer", id: 1003) ?? control(type: "ftcr", id: 1002) else {
			previewNode.isHidden = true
			return
		}

		let imageWindowFrame = childFrame(for: imageWindow, in: panelFrame, scale: scale)
		let previewFrame = childFrame(for: previewControl, in: imageWindowFrame, scale: scale)
		previewNode.isHidden = previewFrame.minY < 0 || previewFrame.height <= 1
		guard !previewNode.isHidden else { return }

		previewNode.position = CGPoint(x: previewFrame.midX, y: previewFrame.midY)
		previewNode.size = previewFrame.size
	}

	#if os(macOS)
	func keyDown(with event: NSEvent) -> Bool {
		switch event.keyCode {
		case 125:
			moveSelection(by: 1)
		case 126:
			moveSelection(by: -1)
		case 36, 76:
			loadSelectedSaveGame()
		case 53:
			onDismiss?()
		default:
			return false
		}
		return true
	}
	#endif

	func mouseDown(at point: CGPoint) -> Bool {
		if let row = rowIndex(at: point) {
			selectedIndex = firstVisibleIndex + row
			refreshLabels()
			loadSelectedSaveGame()
			return true
		}

		return containsDialog(point)
	}

	#if os(iOS)
	func touchesBegan(at point: CGPoint) {
		lastSwipePoint = point
		didSwipe = false
	}

	func touchesMoved(to point: CGPoint) {
		guard let lastPoint = lastSwipePoint else { return }
		let deltaY = point.y - lastPoint.y
		let threshold = max(18, rowHeight * 0.75)
		if abs(deltaY) >= threshold {
			moveSelection(by: deltaY > 0 ? -1 : 1)
			lastSwipePoint = point
			didSwipe = true
		}
	}

	func touchesEnded(tapCount: Int) {
		defer {
			lastSwipePoint = nil
			didSwipe = false
		}

		if !didSwipe, tapCount >= 2 {
			loadSelectedSaveGame()
		}
	}

	func touchesCancelled() {
		lastSwipePoint = nil
		didSwipe = false
	}
	#endif

	private func refreshLabels() {
		for (labelIndex, label) in labels.enumerated() {
			let saveGameIndex = firstVisibleIndex + labelIndex
			guard saveGames.indices.contains(saveGameIndex) else {
				label.text = nil
				continue
			}

			let saveGame = saveGames[saveGameIndex]
			label.text = saveGame.title
			label.fontColor = saveGame.missionFolder == nil ? SKColor(white: 0.38, alpha: 1) : .black
		}

		detailLabel.text = saveGames.indices.contains(selectedIndex) ? saveGames[selectedIndex].detailText : ""
		updatePreview()
		updateSelectionLine()
		layoutScrollbar(scale: menuScale())
	}

	private func updatePreview() {
		guard saveGames.indices.contains(selectedIndex),
			  let screenshotURL = saveGames[selectedIndex].screenshotURL else {
			previewNode.texture = nil
			return
		}

		previewNode.texture = SKTexture(imageUrl: screenshotURL)
	}

	private func updateSelectionLine() {
		let labelIndex = selectedIndex - firstVisibleIndex
		guard labels.indices.contains(labelIndex),
			  saveGames.indices.contains(selectedIndex) else {
			selectionLine.path = nil
			return
		}

		let label = labels[labelIndex]
		let lineWidth = min(listFrame.width - 20, max(24, label.frame.width * 0.98))
		let y = label.position.y - rowHeight * 0.36
		let path = CGMutablePath()
		path.move(to: CGPoint(x: label.position.x, y: y))
		path.addLine(to: CGPoint(x: label.position.x + lineWidth, y: y))
		selectionLine.path = path
	}

	private func moveSelection(by offset: Int) {
		guard !saveGames.isEmpty else { return }

		selectedIndex = max(0, min(saveGames.count - 1, selectedIndex + offset))
		if selectedIndex < firstVisibleIndex {
			firstVisibleIndex = selectedIndex
		} else if selectedIndex >= firstVisibleIndex + labels.count {
			firstVisibleIndex = selectedIndex - labels.count + 1
		}
		refreshLabels()
	}

	private func loadSelectedSaveGame() {
		guard saveGames.indices.contains(selectedIndex) else { return }

		let saveGame = saveGames[selectedIndex]
		guard saveGame.missionFolder != nil else { return }
		onSaveGameActivated?(saveGame)
	}

	private func rowIndex(at point: CGPoint) -> Int? {
		guard rowHeight > 0 else { return nil }

		let labelIndex = Int(round((firstRowY - point.y) / rowHeight))
		guard labels.indices.contains(labelIndex) else { return nil }

		let rowCenterY = firstRowY - CGFloat(labelIndex) * rowHeight
		guard abs(point.y - rowCenterY) <= rowHeight / 2 else { return nil }

		let saveGameIndex = firstVisibleIndex + labelIndex
		return saveGames.indices.contains(saveGameIndex) ? labelIndex : nil
	}

	private func containsDialog(_ point: CGPoint) -> Bool {
		return headerNode.calculateAccumulatedFrame().contains(point) ||
			paperNode.calculateAccumulatedFrame().contains(point)
	}

	private func menuScale() -> CGFloat {
		guard sceneSize != .zero else { return 1 }
		return min(sceneSize.width / 800, sceneSize.height / 600, 1.6)
	}

	private func control(type: String? = nil, id: UInt32? = nil) -> MenuDefControl? {
		return controls.first { control in
			if let type = type, control.type != type {
				return false
			}
			if let id = id, control.id != id {
				return false
			}
			return true
		}
	}

	private func frame(for control: MenuDefControl?, scale: CGFloat) -> CGRect {
		return referenceFrame(
			x: CGFloat(control?.position.x ?? 295),
			y: CGFloat(control?.position.y ?? 60),
			width: CGFloat(control?.scaleX ?? 450),
			height: CGFloat(control?.scaleY ?? 491),
			scale: scale
		)
	}

	private func childFrame(for control: MenuDefControl, in parentFrame: CGRect, scale: CGFloat) -> CGRect {
		let width = CGFloat(control.scaleX) * scale
		let height = CGFloat(control.scaleY) * scale
		return CGRect(
			x: parentFrame.minX + control.position.x * scale,
			y: parentFrame.maxY - control.position.y * scale - height,
			width: width,
			height: height
		)
	}

	private func referenceFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, scale: CGFloat) -> CGRect {
		let referenceOrigin = CGPoint(
			x: (sceneSize.width - 800 * scale) / 2,
			y: (sceneSize.height - 600 * scale) / 2
		)
		return CGRect(
			x: referenceOrigin.x + x * scale,
			y: referenceOrigin.y + 600 * scale - (y + height) * scale,
			width: width * scale,
			height: height * scale
		)
	}

	private func text(for textId: Int) -> String {
		return TextDb.get(textId) ?? ""
	}

	private func layoutScrollbar(scale: CGFloat) {
		guard !listFrame.isEmpty else { return }

		let upControl = control(type: "birt", id: 11)
		let downControl = control(type: "birt", id: 12)
		let upFrame = upControl.map { childFrame(for: $0, in: scrollbarParentFrame, scale: scale) } ?? CGRect(
			x: listFrame.maxX + 10 * scale,
			y: listFrame.maxY - 27 * scale,
			width: 18 * scale,
			height: 10 * scale
		)
		let downFrame = downControl.map { childFrame(for: $0, in: scrollbarParentFrame, scale: scale) } ?? CGRect(
			x: listFrame.maxX + 10 * scale,
			y: listFrame.minY,
			width: 18 * scale,
			height: 10 * scale
		)
		let trackFrame = CGRect(
			x: min(upFrame.minX, downFrame.minX),
			y: downFrame.maxY,
			width: max(upFrame.width, downFrame.width),
			height: max(1, upFrame.minY - downFrame.maxY)
		)
		scrollbarTrackNode.path = CGPath(rect: trackFrame, transform: nil)
		upArrowLabel.fontSize = max(12 * scale, upFrame.height * 1.8)
		upArrowLabel.position = CGPoint(x: upFrame.midX, y: upFrame.midY)
		downArrowLabel.fontSize = max(12 * scale, downFrame.height * 1.8)
		downArrowLabel.position = CGPoint(x: downFrame.midX, y: downFrame.midY)

		let scrollableHeight = max(1, trackFrame.height)
		let thumbHeight = saveGames.isEmpty ? scrollableHeight : max(36 * scale, scrollableHeight * CGFloat(labels.count) / CGFloat(saveGames.count))
		let maxFirstVisibleIndex = max(0, saveGames.count - labels.count)
		let scrollProgress = maxFirstVisibleIndex == 0 ? 0 : CGFloat(firstVisibleIndex) / CGFloat(maxFirstVisibleIndex)
		let thumbTop = trackFrame.maxY - scrollProgress * (scrollableHeight - thumbHeight)
		let thumbFrame = CGRect(
			x: trackFrame.minX,
			y: thumbTop - thumbHeight,
			width: trackFrame.width,
			height: thumbHeight
		)
		scrollbarThumbNode.path = CGPath(rect: thumbFrame, transform: nil)
	}
}
