//
//  GameManager.swift
//  Mafia
//
//  Created by Alex Studnička on 17/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit
import CoreText

#if os(macOS)
    let mainDirectory = URL(fileURLWithPath: "/Users/Alex/Development/Mafia/Mafia")
#elseif os(iOS)
	let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let mainDirectory = documentDirectory.appendingPathComponent("Mafia")
#endif

let mafiaMenuFontName = "AuroraBT-BoldCondensed"
let mafiaMenuTitleFontName = "Freehand-Regular"

class GameManager {

	let view: SCNView

	var mainMenu: MainMenu?
	var animationsGallery: AnimationsGallery?
	var game: Game?
	private var missions: [MissionEntry] = []
	private var saveGames: [SaveGameSlot] = []

	init(view: SCNView) {
		self.view = view

		GameManager.registerBundledFonts()

		// swiftlint:disable:next force_try
		try! TextDb.load()

		view.rendersContinuously = true
		view.backgroundColor = .black
		#if os(iOS)
		view.showsStatistics = false
		#else
		view.showsStatistics = true
		#endif
//		view.debugOptions = [.showPhysicsShapes]
		view.antialiasingMode = .none
		view.allowsCameraControl = false
		view.autoenablesDefaultLighting = false
// 		view.preferredFramesPerSecond = 10
//		loadMission(textId: 4084, imageName: "tutorial.tga", folder: "tutorial")
		loadMenu()
//		loadMission(textId: 4085, imageName: "freeride.tga", folder: "freeitaly")
		view.play(nil)
	}

	private static func registerBundledFonts() {
		for fontName in ["Aurora", "Freehand-Regular"] {
			guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") else { continue }
			_ = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
		}
	}

	func loadMissionSelector() {
		releaseCurrentGame()
		view.isPlaying = true
		view.rendersContinuously = true
		missions = MissionEntry.loadAll()
		view.scene = SCNScene()
		view.delegate = nil
		view.pointOfView = nil
		view.audioListener = nil
		view.overlaySKScene = MissionSelectorScene(size: view.bounds.size, missions: missions, gameManager: self)
	}

	func loadSaveGameSelector() {
		releaseCurrentGame()
		view.isPlaying = true
		view.rendersContinuously = true
		saveGames = SaveGame.loadSlots()
		view.scene = SCNScene()
		view.delegate = nil
		view.pointOfView = nil
		view.audioListener = nil
		view.overlaySKScene = SaveGameSelectorScene(size: view.bounds.size, saveGames: saveGames, gameManager: self)
	}

	func loadAnimationsGallery() {
		releaseCurrentGame()
		view.isPlaying = true
		view.rendersContinuously = true
		view.scene = SCNScene()
		view.overlaySKScene = LoadingScene(textId: 0, imageName: "00menu.tga")
		DispatchQueue.global().async {
			do {
				let gallery = try AnimationsGallery(gameManager: self)
				DispatchQueue.main.async {
					self.animationsGallery = gallery
					gallery.setup(in: self.view)
				}
			} catch {
				print("Failed to load animations gallery:", error)
				DispatchQueue.main.async {
					self.loadMenu()
				}
			}
		}
	}

	func loadMenu() {
		releaseCurrentGame()
		view.isPlaying = true
		view.rendersContinuously = true
		view.scene = SCNScene()
		let loadingScene = LoadingScene(textId: 0, imageName: "00menu.tga")
		view.overlaySKScene = loadingScene
		DispatchQueue.global().async {
			// swiftlint:disable:next force_try
			self.mainMenu = try! MainMenu(gameManager: self)
			DispatchQueue.main.async {
				loadingScene.setProgress(1)
				self.mainMenu?.setup(in: self.view)
			}
		}
	}

	func loadMission(textId: Int, imageName: String, folder: String) {
		let title = TextDb.get(textId) ?? "<none>"
		print("== Loading Mission: folder=\(folder), textId=\(textId), title=\"\(title)\", image=\(imageName)")
		releaseCurrentGame()
		view.isPlaying = true
		view.rendersContinuously = true
		view.scene = SCNScene()
		let loadingScene = LoadingScene(textId: textId, imageName: imageName)
		view.overlaySKScene = loadingScene
		DispatchQueue.global().async {
			do {
				let game = try Game(missionName: folder) { progress in
					DispatchQueue.main.async {
						loadingScene.setProgress(progress)
					}
				}
				game.onMissionEnded = { [weak self] in
					self?.loadMenu()
				}
				game.onMissionRestarted = { [weak self] in
					self?.loadMission(textId: textId, imageName: imageName, folder: folder)
				}
				game.onLoadGameRequested = { [weak self] in
					self?.loadSaveGameSelector()
				}
				DispatchQueue.main.async {
					self.game = game
					game.setup(in: self.view)
				}
			} catch {
				print("Failed to load mission '\(folder)':", error)
				DispatchQueue.main.async {
					self.loadMissionSelector()
				}
			}
		}
	}

	func loadSaveGame(_ saveGame: SaveGameSlot) {
		guard let folder = saveGame.missionFolder else {
			print("Unsupported savegame checkpoint '\(saveGame.fileName)'")
			return
		}

		loadMission(textId: saveGame.textId, imageName: saveGame.imageName, folder: folder)
	}

	private func releaseCurrentGame() {
		game?.tearDown(from: view)
		game = nil
	}

}

private struct MissionEntry {
	let folder: String
	let imageName: String
	let textId: Int

	var title: String {
		return MissionLoadInfo.title(for: folder)
	}

	static func loadAll() -> [MissionEntry] {
		var missions: [MissionEntry] = MissionLoadInfo.loadAll()
			.compactMap { info -> MissionEntry? in
				guard isLoadableMission(folder: info.missionFolder) else { return nil }
				return MissionEntry(
					folder: info.missionFolder,
					imageName: MissionLoadInfo.imageName(for: info.missionFolder, fallbackImageName: info.imageName),
					textId: info.textId
				)
			}
		prependBuiltInMission(folder: "tutorial", imageName: "tutorial.tga", to: &missions)
		return missions.isEmpty ? [
			MissionEntry(
				folder: "freeitaly",
				imageName: MissionLoadInfo.imageName(for: "freeitaly", fallbackImageName: "freeride.tga"),
				textId: MissionLoadInfo.textId(for: "freeitaly")
			)
		] : missions
	}

	private static func prependBuiltInMission(folder: String, imageName: String, to missions: inout [MissionEntry]) {
		guard isLoadableMission(folder: folder),
			  !missions.contains(where: { $0.folder == folder }) else { return }

		missions.insert(
			MissionEntry(
				folder: folder,
				imageName: MissionLoadInfo.imageName(for: folder, fallbackImageName: imageName),
				textId: MissionLoadInfo.textId(for: folder)
			),
			at: 0
		)
	}

	private static func isLoadableMission(folder: String) -> Bool {
		let missionUrl = mainDirectory.appendingPathComponent("missions/" + folder)
		return FileManager.default.fileExists(atPath: missionUrl.appendingPathComponent("scene.4ds").path) &&
			FileManager.default.fileExists(atPath: missionUrl.appendingPathComponent("scene2.bin").path)
	}

}

private final class SaveGameSelectorScene: SKScene {

	private weak var gameManager: GameManager?
	private let saveGames: [SaveGameSlot]
	private var labels: [SKLabelNode] = []
	private var selectedIndex = 0
	private var firstVisibleIndex = 0
	private var rowHeight: CGFloat = 30
	private var firstRowY: CGFloat = 0
	private let maxVisibleSaveGames = 18
	private let titleLabel = SKLabelNode(fontNamed: mafiaMenuFontName)
	private let hintLabel = SKLabelNode(fontNamed: "Arial")
	#if os(iOS)
	private var lastSwipePoint: CGPoint?
	private var didSwipe = false
	#endif

	init(size: CGSize, saveGames: [SaveGameSlot], gameManager: GameManager) {
		self.saveGames = saveGames
		self.gameManager = gameManager

		super.init(size: size)

		scaleMode = .resizeFill
		backgroundColor = .black
		isUserInteractionEnabled = true

		titleLabel.text = "Load Game"
		titleLabel.fontColor = .white
		titleLabel.horizontalAlignmentMode = .center
		addChild(titleLabel)

		#if os(iOS)
		hintLabel.text = saveGames.isEmpty ? "No savegames found" : "Swipe up/down, double-tap to select"
		#else
		hintLabel.text = saveGames.isEmpty ? "No savegames found" : "Use arrows and Return, or click a save"
		#endif
		hintLabel.fontColor = SKColor(white: 0.75, alpha: 1)
		hintLabel.horizontalAlignmentMode = .center
		addChild(hintLabel)

		for _ in 0 ..< min(maxVisibleSaveGames, saveGames.count) {
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

	override func didChangeSize(_ oldSize: CGSize) {
		super.didChangeSize(oldSize)

		titleLabel.fontSize = 34
		titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 64)

		hintLabel.fontSize = 14
		hintLabel.position = CGPoint(x: size.width / 2, y: 24)

		rowHeight = min(30, max(22, (size.height - 150) / CGFloat(max(1, labels.count))))
		let x = max(32, size.width * 0.12)
		firstRowY = size.height - 120

		for (index, label) in labels.enumerated() {
			label.fontSize = min(16, rowHeight * 0.62)
			label.position = CGPoint(x: x, y: firstRowY - CGFloat(index) * rowHeight)
			label.preferredMaxLayoutWidth = size.width - x - 32
		}
	}

	private func refreshLabels() {
		for (labelIndex, label) in labels.enumerated() {
			let saveGameIndex = firstVisibleIndex + labelIndex
			guard saveGames.indices.contains(saveGameIndex) else {
				label.text = nil
				continue
			}

			let saveGame = saveGames[saveGameIndex]
			let prefix = saveGameIndex == selectedIndex ? "> " : "  "
			label.text = prefix + saveGame.title + "  [" + saveGame.fileName + "]"
			if saveGame.missionFolder == nil {
				label.fontColor = SKColor(white: 0.38, alpha: 1)
			} else {
				label.fontColor = saveGameIndex == selectedIndex ? .white : SKColor(white: 0.68, alpha: 1)
			}
		}
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
		gameManager?.loadSaveGame(saveGame)
	}

	#if os(macOS)

	override func keyDown(with event: NSEvent) {
		switch event.keyCode {
		case 125:
			moveSelection(by: 1)
		case 126:
			moveSelection(by: -1)
		case 36, 76:
			loadSelectedSaveGame()
		case 53:
			gameManager?.loadMenu()
		default:
			super.keyDown(with: event)
		}
	}

	override func mouseDown(with event: NSEvent) {
		selectSaveGame(at: event.location(in: self))
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
			loadSelectedSaveGame()
		}
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		lastSwipePoint = nil
		didSwipe = false
	}

	#endif

	private func selectSaveGame(at point: CGPoint) {
		guard let labelIndex = rowIndex(at: point) else { return }

		selectedIndex = firstVisibleIndex + labelIndex
		refreshLabels()
		loadSelectedSaveGame()
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
}

private final class MissionSelectorScene: SKScene {

	private weak var gameManager: GameManager?
	private let missions: [MissionEntry]
	private var labels: [SKLabelNode] = []
	private var selectedIndex = 0
	private var firstVisibleIndex = 0
	private var rowHeight: CGFloat = 30
	private var firstRowY: CGFloat = 0
	private let maxVisibleMissions = 18
	private let titleLabel = SKLabelNode(fontNamed: mafiaMenuFontName)
	private let hintLabel = SKLabelNode(fontNamed: "Arial")
	#if os(iOS)
	private var lastSwipePoint: CGPoint?
	private var didSwipe = false
	#endif

	init(size: CGSize, missions: [MissionEntry], gameManager: GameManager) {
		self.missions = missions
		self.gameManager = gameManager

		super.init(size: size)

		scaleMode = .resizeFill
		backgroundColor = .black
		isUserInteractionEnabled = true

		titleLabel.text = "Select Mission"
		titleLabel.fontColor = .white
		titleLabel.horizontalAlignmentMode = .center
		addChild(titleLabel)

		#if os(iOS)
		hintLabel.text = "Swipe up/down, double-tap to select"
		#else
		hintLabel.text = "Use arrows and Return, or click a mission"
		#endif
		hintLabel.fontColor = SKColor(white: 0.75, alpha: 1)
		hintLabel.horizontalAlignmentMode = .center
		addChild(hintLabel)

		for _ in 0 ..< min(maxVisibleMissions, missions.count) {
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

	override func didChangeSize(_ oldSize: CGSize) {
		super.didChangeSize(oldSize)

		titleLabel.fontSize = 34
		titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 64)

		hintLabel.fontSize = 14
		hintLabel.position = CGPoint(x: size.width / 2, y: 24)

		rowHeight = min(30, max(22, (size.height - 150) / CGFloat(max(1, labels.count))))
		let x = max(32, size.width * 0.2)
		firstRowY = size.height - 120

		for (index, label) in labels.enumerated() {
			label.fontSize = min(18, rowHeight * 0.68)
			label.position = CGPoint(x: x, y: firstRowY - CGFloat(index) * rowHeight)
		}
	}

	private func refreshLabels() {
		for (labelIndex, label) in labels.enumerated() {
			let missionIndex = firstVisibleIndex + labelIndex
			guard missionIndex < missions.count else {
				label.text = nil
				continue
			}

			label.text = (missionIndex == selectedIndex ? "> " : "  ") + missions[missionIndex].title
			label.fontColor = missionIndex == selectedIndex ? .white : SKColor(white: 0.68, alpha: 1)
		}
	}

	private func moveSelection(by offset: Int) {
		guard !missions.isEmpty else { return }

		selectedIndex = max(0, min(missions.count - 1, selectedIndex + offset))
		if selectedIndex < firstVisibleIndex {
			firstVisibleIndex = selectedIndex
		} else if selectedIndex >= firstVisibleIndex + labels.count {
			firstVisibleIndex = selectedIndex - labels.count + 1
		}
		refreshLabels()
	}

	private func loadSelectedMission() {
		guard missions.indices.contains(selectedIndex) else { return }

		let mission = missions[selectedIndex]
		if mission.folder.lowercased() == "00menu" {
			gameManager?.loadMenu()
			return
		}
		gameManager?.loadMission(textId: mission.textId, imageName: mission.imageName, folder: mission.folder)
	}

	#if os(macOS)

	override func keyDown(with event: NSEvent) {
		switch event.keyCode {
		case 125:
			moveSelection(by: 1)
		case 126:
			moveSelection(by: -1)
		case 36, 76:
			loadSelectedMission()
		default:
			super.keyDown(with: event)
		}
	}

	override func mouseDown(with event: NSEvent) {
		selectMission(at: event.location(in: self))
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
			loadSelectedMission()
		}
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		lastSwipePoint = nil
		didSwipe = false
	}

	#endif

	private func selectMission(at point: CGPoint) {
		guard let labelIndex = rowIndex(at: point) else { return }

		selectedIndex = firstVisibleIndex + labelIndex
		refreshLabels()
		loadSelectedMission()
	}

	private func rowIndex(at point: CGPoint) -> Int? {
		guard rowHeight > 0 else { return nil }

		let labelIndex = Int(round((firstRowY - point.y) / rowHeight))
		guard labels.indices.contains(labelIndex) else { return nil }

		let rowCenterY = firstRowY - CGFloat(labelIndex) * rowHeight
		guard abs(point.y - rowCenterY) <= rowHeight / 2 else { return nil }

		let missionIndex = firstVisibleIndex + labelIndex
		return missions.indices.contains(missionIndex) ? labelIndex : nil
	}
}
