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

#if os(macOS)
    let mainDirectory = URL(fileURLWithPath: "/Users/Alex/Development/Mafia/Mafia")
#elseif os(iOS)
	let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let mainDirectory = documentDirectory.appendingPathComponent("Mafia")
#endif

class GameManager {

	let view: SCNView

	var mainMenu: MainMenu?
	var game: Game!
	private var missions: [MissionEntry] = []

	init(view: SCNView) {
		self.view = view

		// swiftlint:disable:next force_try
		try! TextDb.load()

		view.rendersContinuously = true
		view.backgroundColor = .black
		view.showsStatistics = true
//		view.debugOptions = [.showPhysicsShapes]
		view.antialiasingMode = .none
		view.allowsCameraControl = false
		view.autoenablesDefaultLighting = false
// 		view.preferredFramesPerSecond = 10
//		loadMission(textId: 4084, imageName: "tutorial.tga", folder: "tutorial")
		loadMissionSelector()
//		loadMission(textId: 4085, imageName: "freeride.tga", folder: "freeitaly")
//		loadMenu()
		view.play(nil)
	}

	func loadMissionSelector() {
		missions = MissionEntry.loadAll()
		view.scene = SCNScene()
		view.delegate = nil
		view.pointOfView = nil
		view.audioListener = nil
		view.overlaySKScene = MissionSelectorScene(size: view.bounds.size, missions: missions, gameManager: self)
	}

	func loadMenu() {
		view.scene = SCNScene()
		let loadingScene = LoadingScene(textId: 0, imageName: "00menu.tga")
		view.overlaySKScene = loadingScene
		DispatchQueue.global().async {
			// swiftlint:disable:next force_try
			self.mainMenu = try! MainMenu()
			DispatchQueue.main.async {
				loadingScene.setProgress(1)
				self.mainMenu?.setup(in: self.view)
			}
		}
	}

	func loadMission(textId: Int, imageName: String, folder: String) {
		view.scene = SCNScene()
		let loadingScene = LoadingScene(textId: textId, imageName: imageName)
		view.overlaySKScene = loadingScene
		DispatchQueue.global().async {
			// swiftlint:disable:next force_try
			self.game = try! Game(missionName: folder) { progress in
				DispatchQueue.main.async {
					loadingScene.setProgress(progress)
				}
			}
			DispatchQueue.main.async {
				self.game.setup(in: self.view)
			}
		}
	}

}

private struct MissionEntry {
	let folder: String
	let imageName: String

	var title: String {
		return folder
	}

	static func loadAll() -> [MissionEntry] {
		let url = mainDirectory.appendingPathComponent("missions/a.txt")
		guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
			return [MissionEntry(folder: "freeitaly", imageName: "freeride.tga")]
		}

		var missions: [MissionEntry] = contents
			.components(separatedBy: .newlines)
			.compactMap { (line: String) -> MissionEntry? in
				let parts = line
					.components(separatedBy: .whitespacesAndNewlines)
					.filter { !$0.isEmpty }
				guard let folder = parts.first else { return nil }
				guard isLoadableMission(folder: folder) else { return nil }
				let imageName = parts.count > 1 ? normalizedImageName(parts[1], fallbackFolder: folder) : fallbackImageName(for: folder)
				return MissionEntry(folder: folder, imageName: imageName)
			}
		prependBuiltInMission(folder: "tutorial", imageName: "tutorial.tga", to: &missions)
		return missions.isEmpty ? [MissionEntry(folder: "freeitaly", imageName: "freeride.tga")] : missions
	}

	private static func prependBuiltInMission(folder: String, imageName: String, to missions: inout [MissionEntry]) {
		guard isLoadableMission(folder: folder),
			  !missions.contains(where: { $0.folder == folder }) else { return }

		missions.insert(
			MissionEntry(folder: folder, imageName: normalizedImageName(imageName, fallbackFolder: folder)),
			at: 0
		)
	}

	private static func isLoadableMission(folder: String) -> Bool {
		let missionUrl = mainDirectory.appendingPathComponent("missions/" + folder)
		return FileManager.default.fileExists(atPath: missionUrl.appendingPathComponent("scene.4ds").path) &&
			FileManager.default.fileExists(atPath: missionUrl.appendingPathComponent("scene2.bin").path)
	}

	private static func normalizedImageName(_ imageName: String, fallbackFolder: String) -> String {
		let normalizedName = imageName.contains(".") ? imageName : imageName + ".tga"
		let url = mainDirectory.appendingPathComponent("maps/" + normalizedName)
		return FileManager.default.fileExists(atPath: url.path) ? normalizedName : fallbackImageName(for: fallbackFolder)
	}

	private static func fallbackImageName(for folder: String) -> String {
		let folderImageName = folder + ".tga"
		let folderImageUrl = mainDirectory.appendingPathComponent("maps/" + folderImageName)
		if FileManager.default.fileExists(atPath: folderImageUrl.path) {
			return folderImageName
		}
		return "00menu.tga"
	}
}

private final class MissionSelectorScene: SKScene {

	private weak var gameManager: GameManager?
	private let missions: [MissionEntry]
	private var labels: [SKLabelNode] = []
	private var selectedIndex = 0
	private var firstVisibleIndex = 0
	private let maxVisibleMissions = 18
	private let titleLabel = SKLabelNode(fontNamed: "Aurora")
	private let hintLabel = SKLabelNode(fontNamed: "Arial")

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

		hintLabel.text = "Use arrows and Return, or click a mission"
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

		let rowHeight = min(30, max(22, (size.height - 150) / CGFloat(max(1, labels.count))))
		let x = max(32, size.width * 0.2)
		let top = size.height - 120

		for (index, label) in labels.enumerated() {
			label.fontSize = min(18, rowHeight * 0.68)
			label.position = CGPoint(x: x, y: top - CGFloat(index) * rowHeight)
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
		gameManager?.loadMission(textId: 0, imageName: mission.imageName, folder: mission.folder)
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

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let point = touches.first?.location(in: self) else { return }
		selectMission(at: point)
	}

	#endif

	private func selectMission(at point: CGPoint) {
		for (labelIndex, label) in labels.enumerated() where label.contains(point) {
			selectedIndex = firstVisibleIndex + labelIndex
			refreshLabels()
			loadSelectedMission()
			return
		}
	}
}
