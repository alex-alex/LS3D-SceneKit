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
	private let entries: [MainMenuEntry]

	init(gameManager: GameManager) throws {
		self.gameManager = gameManager
		let loadedMenuDef = try MenuDef()
		let loadedMenuControls = MainMenu.visibleControls(in: loadedMenuDef.controls(for: .mainMenu))
		menuDef = loadedMenuDef
		menuControls = loadedMenuControls
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
		case 990104:
			return .missionSelector
		case 990109:
			return .mission(folder: "autosalon", imageName: "carcyklopedia.tga")
		default:
			return .none
		}
	}

	func setup(in view: SCNView) {
		view.scene = scnScene
		let menuScene = MainMenuScene(size: view.bounds.size, controls: menuControls, entries: entries)
		menuScene.onSelectionChanged = { [weak self] index in
			self?.selectEntry(at: index)
		}
		menuScene.onEntryActivated = { [weak self] index in
			self?.activateEntry(at: index)
		}
		view.overlaySKScene = menuScene
		view.delegate = nil
		view.pointOfView = cameraNode
		view.audioListener = cameraRig
		selectEntry(at: 0, animated: false)
	}

	private func selectEntry(at index: Int, animated: Bool = true) {
		guard entries.indices.contains(index),
			  let anchor = menuAnchor(named: entries[index].anchorName) else { return }

		moveCamera(to: anchor, animated: animated)
	}

	private func activateEntry(at index: Int) {
		guard entries.indices.contains(index) else { return }

		switch entries[index].action {
		case .mission(let folder, let imageName):
			gameManager?.loadMission(textId: 0, imageName: imageName, folder: folder)
		case .missionSelector:
			gameManager?.loadMissionSelector()
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
	case missionSelector
	case none
}

private final class MainMenuScene: SKScene {

	var onSelectionChanged: ((Int) -> Void)?
	var onEntryActivated: ((Int) -> Void)?

	private let controls: [MenuDefControl]
	private let entries: [MainMenuEntry]
	private let paperNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir3.tga")))
	private let headerNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir5a.tga")))
	private let selectionLine = SKShapeNode()
	private let titleLabel = SKLabelNode(fontNamed: mafiaMenuTitleFontName)
	private var labels: [SKLabelNode] = []
	private var selectedIndex = 0
	private var rowHeight: CGFloat = 31
	private var firstRowY: CGFloat = 0
	private var menuFrame = CGRect.zero

	init(size: CGSize, controls: [MenuDefControl], entries: [MainMenuEntry]) {
		self.controls = controls
		self.entries = entries

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

		let scale = menuScale()
		let titleWindow = controls.first { $0.type == "tniw" }
		let titleHeight = 50 * scale
		menuFrame = frame(for: titleWindow)

		headerNode.position = CGPoint(x: menuFrame.midX, y: menuFrame.maxY - titleHeight / 2)
		headerNode.size = CGSize(width: menuFrame.width, height: titleHeight)
		titleLabel.fontSize = min(36, titleHeight * 0.68)
		titleLabel.position = CGPoint(x: menuFrame.midX, y: menuFrame.maxY - titleHeight / 2)
		titleLabel.text = titleWindow.flatMap { TextDb.get(Int($0.textId)) }

		let paperFrame = CGRect(
			x: menuFrame.minX,
			y: menuFrame.minY,
			width: menuFrame.width,
			height: menuFrame.height - titleHeight
		)
		paperNode.position = CGPoint(x: paperFrame.midX, y: paperFrame.midY)
		paperNode.size = paperFrame.size

		for (index, label) in labels.enumerated() {
			let control = entries[index].control
			let controlFrame = childFrame(for: control, in: paperFrame, scale: scale)
			rowHeight = controlFrame.height
			label.fontSize = min(36, controlFrame.height * 0.94)
			label.position = CGPoint(x: controlFrame.midX, y: controlFrame.midY)
			label.preferredMaxLayoutWidth = controlFrame.width
		}

		refreshSelection()
	}

	private func menuScale() -> CGFloat {
		return min(size.width / 640, size.height / 480, 1.6)
	}

	private func frame(for control: MenuDefControl?) -> CGRect {
		let scale = menuScale()
		let xOffset = 10 * scale
		let yOffset = 10 * scale
		let x = xOffset + (control?.position.x ?? 55) * scale
		let yTop = yOffset + (control?.position.y ?? 60) * scale
		let width = CGFloat(control?.scaleX ?? 217) * scale
		let height = CGFloat(control?.scaleY ?? 353) * scale
		return CGRect(x: x, y: size.height - yTop - height, width: width, height: height)
	}

	private func childFrame(for control: MenuDefControl, in paperFrame: CGRect, scale: CGFloat) -> CGRect {
		let x = paperFrame.minX + control.position.x * scale
		let y = paperFrame.maxY - control.position.y * scale - CGFloat(control.scaleY) * scale
		return CGRect(x: x, y: y, width: CGFloat(control.scaleX) * scale, height: CGFloat(control.scaleY) * scale)
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
		select(at: event.location(in: self))
	}

	#elseif os(iOS)

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let point = touches.first?.location(in: self) else { return }
		select(at: point)
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
