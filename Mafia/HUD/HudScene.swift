//
//  HudScene.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

final class HudScene: SKScene {

	let game: Game

	var compass: SKSpriteNode!
	var compassNeedle: SKSpriteNode!
	var actionButton: SKSpriteNode!
	var inventoryButton: SKShapeNode!
	var reloadButton: SKShapeNode!
	var dropButton: SKShapeNode!
	var jumpButton: SKShapeNode!
	var objectivesNode: SKNode!
	var consoleLabel: SKLabelNode!
	var speedLabel: SKLabelNode!
	var playerStatusLabel: SKLabelNode!
	private var crosshairNode: SKNode!
	private var vehicleStealProgressBackground: SKShapeNode!
	private var vehicleStealProgressFill: SKShapeNode!
	private var vehicleStealProgressLabel: SKLabelNode!
	private var healthHudPanel: SKSpriteNode!
	private var healthValueShadowLabel: SKLabelNode!
	private var healthValueLabel: SKLabelNode!
	private var ammoHudPanel: SKSpriteNode!
	private var ammoValueShadowLabel: SKLabelNode!
	private var ammoValueLabel: SKLabelNode!
	private var pauseOverlay: SKShapeNode!
	private var pauseTitleLabel: SKLabelNode!
	private var pauseHintLabel: SKLabelNode!
	private var inventoryOverlay: SKShapeNode!
	private var inventoryTitleLabel: SKLabelNode!
	private var inventoryHintLabel: SKLabelNode!
	private var letterboxTopBar: SKShapeNode!
	private var letterboxBottomBar: SKShapeNode!
	private var cutsceneFadeOverlay: SKShapeNode!
	private var loadBlackoutOverlay: SKShapeNode!
	private var inventoryRows: [(node: SKShapeNode, weapon: Weapon?)] = []
	private var inventoryPausedGame = false
	private var isCutsceneOverlayVisible = false
	private var lastSpeedText: String?
	private var lastPlayerStatusText: String?
	private var lastVehicleStealProgress: CGFloat = -1
	private var wasSpeedVisible = false
	private let consoleActionKey = "consoleMessage"
	private let objectivesActionKey = "objectivesMessage"
	private let cutsceneFadeActionKey = "cutsceneFade"
	private let objectiveLineSpacing: CGFloat = 24
	private var showsTouchControls: Bool {
		#if os(iOS)
			return true
		#else
			return false
		#endif
	}
	#if os(iOS)
	private var activeTouchControl: Control?
	#endif
	var isInventoryVisible: Bool {
		return inventoryOverlay?.isHidden == false
	}

	#if os(macOS)

	var ride = false
	var reverse = false
	var vehicleSteering: CGFloat = 0
	private var accelerating = false
	private var reversing = false
	private var braking = false
	private var steeringLeft = false
	private var steeringRight = false
	private var walkingForward = false
	private var walkingBackward = false
	private var walkingLeft = false
	private var walkingRight = false
	private var running = false
	private var crouching = false
	private var lastCrouchSidestepTapDirection = 0
	private var lastCrouchSidestepTapTime: TimeInterval = 0
	private var freeCameraForward = false
	private var freeCameraBackward = false
	private var freeCameraLeft = false
	private var freeCameraRight = false
	private var freeCameraUp = false
	private var freeCameraDown = false

	#endif

	init(size: CGSize, game: Game) {
		self.game = game

		super.init(size: size)

		let compassTexture = HudScene.spriteTexture(
			imageName: "2int.tga",
			rect: CGRect(x: 186, y: 171, width: 70, height: 71),
			masksBlack: true
		)
		compass = SKSpriteNode(texture: compassTexture)
		compass.isHidden = true
		compass.size = CGSize(width: 90, height: 91)
		addChild(compass)

		let compassArrowTexture = HudScene.spriteTexture(
			imageName: "1int.tga",
			rect: CGRect(x: 0, y: 211, width: 64, height: 19),
			masksBlack: true
		)
		compassNeedle = SKSpriteNode(texture: compassArrowTexture)
		compassNeedle.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		compassNeedle.position = .zero
		compassNeedle.size = CGSize(width: 48, height: 14)
		compass.addChild(compassNeedle)

		let actionTexture = HudScene.spriteTexture(
			imageName: "2int.tga",
			rect: CGRect(x: 0, y: 113, width: 35, height: 34),
			masksBlack: true
		)
		actionButton = SKSpriteNode(texture: actionTexture)
		actionButton.isHidden = true
		actionButton.size = CGSize(width: 44, height: 43)
		addChild(actionButton)

		renderButtons()

		objectivesNode = SKNode()
		addChild(objectivesNode)

		consoleLabel = SKLabelNode()
		consoleLabel.fontName = "Arial"
		consoleLabel.fontSize = 17
		consoleLabel.fontColor = SKColor.white
		consoleLabel.horizontalAlignmentMode = .left
		consoleLabel.verticalAlignmentMode = .top
		consoleLabel.numberOfLines = 0
		consoleLabel.preferredMaxLayoutWidth = max(240, size.width - 120)
		consoleLabel.alpha = 0
		addChild(consoleLabel)

		speedLabel = SKLabelNode()
		speedLabel.fontName = "Arial"
		speedLabel.fontSize = 17
		speedLabel.fontColor = SKColor.white
		speedLabel.horizontalAlignmentMode = .left
		speedLabel.verticalAlignmentMode = .center
		speedLabel.isHidden = true
		addChild(speedLabel)

		playerStatusLabel = SKLabelNode()
		playerStatusLabel.fontName = "Arial"
		playerStatusLabel.fontSize = 16
		playerStatusLabel.fontColor = SKColor.white
		playerStatusLabel.horizontalAlignmentMode = .left
		playerStatusLabel.verticalAlignmentMode = .bottom
		playerStatusLabel.numberOfLines = 0
		playerStatusLabel.zPosition = 1100
		playerStatusLabel.isHidden = true
		addChild(playerStatusLabel)

		renderCrosshair()
		renderVehicleStealProgress()
		renderPlayerStatusHud()
		renderPauseScreen()
		renderInventoryOverlay()
		renderCinematicOverlays()

		scaleMode = .resizeFill
		isHidden = false
		isUserInteractionEnabled = true

		layoutHud()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError()
	}

	override func didChangeSize(_ oldSize: CGSize) {
		super.didChangeSize(oldSize)

		layoutHud()
	}

	private func layoutHud() {
		guard compass != nil,
				  actionButton != nil,
				  objectivesNode != nil,
				  consoleLabel != nil,
				  speedLabel != nil,
				  playerStatusLabel != nil,
				  crosshairNode != nil,
				  vehicleStealProgressBackground != nil,
				  vehicleStealProgressFill != nil,
				  vehicleStealProgressLabel != nil,
				  healthHudPanel != nil,
				  ammoHudPanel != nil,
				  pauseOverlay != nil,
				  inventoryOverlay != nil,
				  letterboxTopBar != nil,
				  letterboxBottomBar != nil,
				  cutsceneFadeOverlay != nil,
				  loadBlackoutOverlay != nil else { return }

		compass.position = CGPoint(x: 70, y: size.height-70)
		actionButton.position = CGPoint(x: 45, y: 104)
		objectivesNode.position = CGPoint(x: size.width/2, y: size.height/2)
		consoleLabel.position = CGPoint(x: 24, y: size.height-24)
		consoleLabel.preferredMaxLayoutWidth = max(240, size.width - 120)
		speedLabel.position = CGPoint(x: 24, y: size.height-150)
		playerStatusLabel.position = CGPoint(x: 24, y: 20)
		playerStatusLabel.preferredMaxLayoutWidth = max(220, size.width - 120)
		crosshairNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
		layoutVehicleStealProgress()
		layoutPlayerStatusHud()
		pauseOverlay.position = CGPoint(x: size.width/2, y: size.height/2)
		pauseOverlay.path = CGPath(
			rect: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height),
			transform: nil
		)
		pauseTitleLabel.position = CGPoint(x: 0, y: 20)
		pauseHintLabel.position = CGPoint(x: 0, y: -24)
		layoutInventoryOverlay()
		layoutCinematicOverlays()

		layoutTouchButtons()
	}

	func updateVehicleSpeed(_ speed: CGFloat, vehicleSpeed: CGFloat, force: CGFloat, isVisible: Bool) {
		if wasSpeedVisible != isVisible {
			wasSpeedVisible = isVisible
			speedLabel.isHidden = !isGameplayHudVisible(isVisible)
		}
		guard isVisible else { return }

		let bodySpeed = Int(speed.rounded())
		let wheelSpeed = Int(vehicleSpeed.rounded())
		let engineForce = Int(force.rounded())
		let speedText = "Body \(bodySpeed)  Vehicle \(wheelSpeed)  Force \(engineForce)"
		if lastSpeedText != speedText {
			lastSpeedText = speedText
			speedLabel.text = speedText
		}
	}

	func updatePlayerStatus(health: Int, weapon: Weapon?) {
		updatePlayerStatusHud(health: health, weapon: weapon)
		crosshairNode.isHidden = !isGameplayHudVisible(weapon?.isFirearm == true)

		let weaponText: String
		if let weapon = weapon {
			if weapon.isFirearm {
				let ammoText = weapon.clipAmmo == -1 ? "unlimited" : "\(weapon.clipAmmo)/\(weapon.restAmmo)"
				weaponText = "\(weapon.name)  \(ammoText)"
			} else {
				weaponText = weapon.name
			}
		} else {
			weaponText = "Empty hands"
		}

		let statusText = "Weapon: \(weaponText)\nHealth: \(health)"
		if lastPlayerStatusText != statusText {
			lastPlayerStatusText = statusText
			playerStatusLabel.text = statusText
		}
	}

	func updateVehicleStealProgress(_ progress: CGFloat, isVisible: Bool, label: String = "Stealing car") {
		let isHudVisible = isGameplayHudVisible(isVisible)
		vehicleStealProgressBackground.isHidden = !isHudVisible
		vehicleStealProgressFill.isHidden = !isHudVisible
		vehicleStealProgressLabel.isHidden = !isHudVisible
		vehicleStealProgressLabel.text = label
		guard isVisible else {
			lastVehicleStealProgress = -1
			return
		}

		let clampedProgress = max(0, min(progress, 1))
		guard abs(lastVehicleStealProgress - clampedProgress) > 0.01 else { return }

		lastVehicleStealProgress = clampedProgress
		let width: CGFloat = 180
		vehicleStealProgressFill.path = CGPath(
			roundedRect: CGRect(x: -width / 2, y: -6, width: width * clampedProgress, height: 12),
			cornerWidth: 6,
			cornerHeight: 6,
			transform: nil
		)
	}

	func showConsoleText(_ text: String) {
		consoleLabel.removeAction(forKey: consoleActionKey)
		consoleLabel.text = remappedControlText(text)
		consoleLabel.alpha = isCutsceneOverlayVisible ? 0 : 1
		consoleLabel.run(
			SKAction.sequence([
				SKAction.wait(forDuration: 4),
				SKAction.fadeOut(withDuration: 0.35)
			]),
			withKey: consoleActionKey
		)
	}

	func updateObjectives(_ objectives: [Int]) {
		objectivesNode.removeAction(forKey: objectivesActionKey)
		objectivesNode.removeAllChildren()
		let texts = objectives.compactMap { TextDb.get($0).map(remappedControlText) }
		let hasObjectives = !texts.isEmpty
		objectivesNode.isHidden = !isGameplayHudVisible(hasObjectives)
		objectivesNode.alpha = isGameplayHudVisible(hasObjectives) ? 1 : 0
		guard hasObjectives else { return }

		let startY = CGFloat(texts.count - 1) * objectiveLineSpacing / 2
		for (index, text) in texts.enumerated() {
			let label = SKLabelNode()
			label.fontName = "Arial"
			label.fontSize = 17
			label.fontColor = SKColor.white
			label.horizontalAlignmentMode = .center
			label.verticalAlignmentMode = .center
			label.text = text
			label.position = CGPoint(x: 0, y: startY - CGFloat(index) * objectiveLineSpacing)
			objectivesNode.addChild(label)
		}

		objectivesNode.run(
			SKAction.sequence([
				SKAction.wait(forDuration: 7),
				SKAction.fadeOut(withDuration: 0.35),
				SKAction.hide()
			]),
			withKey: objectivesActionKey
		)
	}

	func showCurrentObjectives(_ objectives: [Int]) {
		let text = objectives.compactMap { TextDb.get($0).map(remappedControlText) }.joined(separator: "\n")
		guard !text.isEmpty else { return }
		showConsoleText(text)
	}

	private func remappedControlText(_ text: String) -> String {
		return text
			.replacingOccurrences(of: "Default: F1 key", with: "Default: O key")
			.replacingOccurrences(of: "Default: F5", with: "Default: V")
	}

	private func isGameplayHudVisible(_ requestedVisibility: Bool) -> Bool {
		return requestedVisibility && !isCutsceneOverlayVisible
	}

	func setActionButtonVisible(_ isVisible: Bool) {
		actionButton.isHidden = !isGameplayHudVisible(isVisible)
	}

	func setCompassVisible(_ isVisible: Bool) {
		compass.isHidden = !isGameplayHudVisible(isVisible)
	}

	func setCutsceneOverlayVisible(_ isVisible: Bool) {
		guard isCutsceneOverlayVisible != isVisible else { return }

		isCutsceneOverlayVisible = isVisible
		letterboxTopBar.isHidden = !isVisible
		letterboxBottomBar.isHidden = !isVisible

		if isVisible {
			compass.isHidden = true
			actionButton.isHidden = true
			speedLabel.isHidden = true
			playerStatusLabel.isHidden = true
			crosshairNode.isHidden = true
			vehicleStealProgressBackground.isHidden = true
			vehicleStealProgressFill.isHidden = true
			vehicleStealProgressLabel.isHidden = true
			healthHudPanel.isHidden = true
			ammoHudPanel.isHidden = true
			objectivesNode.isHidden = true
			consoleLabel.alpha = 0
			inventoryButton?.isHidden = true
			reloadButton?.isHidden = true
			dropButton?.isHidden = true
			jumpButton?.isHidden = true
			playCutsceneFadeIn()
		} else {
			cutsceneFadeOverlay.removeAction(forKey: cutsceneFadeActionKey)
			cutsceneFadeOverlay.isHidden = true
			cutsceneFadeOverlay.alpha = 0
			healthHudPanel.isHidden = false
			speedLabel.isHidden = !wasSpeedVisible
			objectivesNode.isHidden = objectivesNode.children.isEmpty
			consoleLabel.alpha = consoleLabel.hasActions() ? 1 : 0
			layoutTouchButtons()
		}
	}

	func setLoadBlackoutVisible(_ isVisible: Bool) {
		loadBlackoutOverlay.isHidden = !isVisible
	}

}

// MARK: - Cinematic Overlays

extension HudScene {

	private func renderCinematicOverlays() {
		letterboxTopBar = SKShapeNode()
		letterboxTopBar.fillColor = SKColor.black
		letterboxTopBar.strokeColor = SKColor.clear
		letterboxTopBar.zPosition = 950
		letterboxTopBar.isHidden = true
		addChild(letterboxTopBar)

		letterboxBottomBar = SKShapeNode()
		letterboxBottomBar.fillColor = SKColor.black
		letterboxBottomBar.strokeColor = SKColor.clear
		letterboxBottomBar.zPosition = 950
		letterboxBottomBar.isHidden = true
		addChild(letterboxBottomBar)

		cutsceneFadeOverlay = SKShapeNode()
		cutsceneFadeOverlay.fillColor = SKColor.black
		cutsceneFadeOverlay.strokeColor = SKColor.clear
		cutsceneFadeOverlay.zPosition = 975
		cutsceneFadeOverlay.alpha = 0
		cutsceneFadeOverlay.isHidden = true
		addChild(cutsceneFadeOverlay)

		loadBlackoutOverlay = SKShapeNode()
		loadBlackoutOverlay.fillColor = SKColor.black
		loadBlackoutOverlay.strokeColor = SKColor.clear
		loadBlackoutOverlay.zPosition = 2000
		loadBlackoutOverlay.isHidden = true
		addChild(loadBlackoutOverlay)
	}

	private func layoutCinematicOverlays() {
		let barHeight = max(48, size.height * 0.12)
		letterboxBottomBar.path = CGPath(
			rect: CGRect(x: 0, y: 0, width: size.width, height: barHeight),
			transform: nil
		)
		letterboxBottomBar.position = .zero

		letterboxTopBar.path = CGPath(
			rect: CGRect(x: 0, y: 0, width: size.width, height: barHeight),
			transform: nil
		)
		letterboxTopBar.position = CGPoint(x: 0, y: size.height - barHeight)

		cutsceneFadeOverlay.path = CGPath(
			rect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
			transform: nil
		)
		cutsceneFadeOverlay.position = .zero

		loadBlackoutOverlay.path = CGPath(
			rect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
			transform: nil
		)
		loadBlackoutOverlay.position = .zero
	}

	private func playCutsceneFadeIn() {
		cutsceneFadeOverlay.removeAction(forKey: cutsceneFadeActionKey)
		cutsceneFadeOverlay.isHidden = false
		cutsceneFadeOverlay.alpha = 1
		cutsceneFadeOverlay.run(
			SKAction.sequence([
				SKAction.fadeOut(withDuration: 0.55),
				SKAction.hide()
			]),
			withKey: cutsceneFadeActionKey
		)
	}

}

// MARK: - Vehicle Steal Progress

extension HudScene {

	private func renderVehicleStealProgress() {
		vehicleStealProgressBackground = SKShapeNode(
			rect: CGRect(x: -90, y: -6, width: 180, height: 12),
			cornerRadius: 6
		)
		vehicleStealProgressBackground.fillColor = SKColor.black.withAlphaComponent(0.55)
		vehicleStealProgressBackground.strokeColor = SKColor.white.withAlphaComponent(0.7)
		vehicleStealProgressBackground.lineWidth = 1
		vehicleStealProgressBackground.zPosition = 900
		vehicleStealProgressBackground.isHidden = true
		addChild(vehicleStealProgressBackground)

		vehicleStealProgressFill = SKShapeNode(
			rect: CGRect(x: -90, y: -6, width: 0, height: 12),
			cornerRadius: 6
		)
		vehicleStealProgressFill.fillColor = SKColor.white
		vehicleStealProgressFill.strokeColor = SKColor.clear
		vehicleStealProgressFill.zPosition = 901
		vehicleStealProgressFill.isHidden = true
		addChild(vehicleStealProgressFill)

		vehicleStealProgressLabel = SKLabelNode()
		vehicleStealProgressLabel.fontName = "Arial-BoldMT"
		vehicleStealProgressLabel.fontSize = 14
		vehicleStealProgressLabel.fontColor = SKColor.white
		vehicleStealProgressLabel.text = "Stealing car"
		vehicleStealProgressLabel.horizontalAlignmentMode = .center
		vehicleStealProgressLabel.verticalAlignmentMode = .bottom
		vehicleStealProgressLabel.zPosition = 902
		vehicleStealProgressLabel.isHidden = true
		addChild(vehicleStealProgressLabel)
	}

	private func layoutVehicleStealProgress() {
		let position = CGPoint(x: size.width / 2, y: 70)
		vehicleStealProgressBackground.position = position
		vehicleStealProgressFill.position = position
		vehicleStealProgressLabel.position = CGPoint(x: position.x, y: position.y + 14)
	}

}

// MARK: - Player Status HUD

extension HudScene {

	private static let statusTextureSize = CGSize(width: 64, height: 256)

	private static func spriteTexture(imageName: String, rect: CGRect, masksBlack: Bool) -> SKTexture {
		let imageURL = mainDirectory.appendingPathComponent("maps/"+imageName)
		#if os(macOS)
			guard let image = NSImage(contentsOf: imageURL) else {
				return SKTexture(imageUrl: imageURL)
			}
			var proposedRect = CGRect(origin: .zero, size: image.size)
			guard var cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
				return SKTexture(image: image)
			}
		#elseif os(iOS)
			guard let image = UIImage(contentsOfFile: imageURL.path) else {
				return SKTexture(imageUrl: imageURL)
			}
			guard var cgImage = image.cgImage else {
				return SKTexture(image: image)
			}
		#endif

		if let croppedImage = cgImage.cropping(to: rect.integral) {
			cgImage = croppedImage
		}
		if masksBlack, let maskedImage = blackTransparentImage(from: cgImage) {
			cgImage = maskedImage
		}

		#if os(macOS)
			return SKTexture(cgImage: cgImage)
		#elseif os(iOS)
			return SKTexture(cgImage: cgImage)
		#endif
	}

	private static func blackTransparentImage(from image: CGImage) -> CGImage? {
		let width = image.width
		let height = image.height
		let bytesPerPixel = 4
		let bytesPerRow = width * bytesPerPixel
		var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

		let didDraw = pixels.withUnsafeMutableBytes { pixelBuffer -> Bool in
			guard let context = CGContext(
				data: pixelBuffer.baseAddress,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: bytesPerRow,
				space: colorSpace,
				bitmapInfo: bitmapInfo
			) else { return false }

			context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
			return true
		}
		guard didDraw else { return nil }

		for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
			if pixels[offset] <= 2,
			   pixels[offset + 1] <= 2,
			   pixels[offset + 2] <= 2 {
				pixels[offset + 3] = 0
			}
		}

		return pixels.withUnsafeMutableBytes { pixelBuffer -> CGImage? in
			guard let outputContext = CGContext(
				data: pixelBuffer.baseAddress,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: bytesPerRow,
				space: colorSpace,
				bitmapInfo: bitmapInfo
			) else { return nil }

			return outputContext.makeImage()
		}
	}

	private func renderCrosshair() {
		crosshairNode = SKNode()
		crosshairNode.zPosition = 900
		crosshairNode.isHidden = true
		addChild(crosshairNode)

		let materialColor = SKColor.white.withAlphaComponent(0.82)
		let shadowColor = SKColor.black.withAlphaComponent(0.45)
		addCrosshairLine(from: CGPoint(x: -15, y: 0), to: CGPoint(x: -5, y: 0), color: shadowColor, width: 3)
		addCrosshairLine(from: CGPoint(x: 5, y: 0), to: CGPoint(x: 15, y: 0), color: shadowColor, width: 3)
		addCrosshairLine(from: CGPoint(x: 0, y: -15), to: CGPoint(x: 0, y: -5), color: shadowColor, width: 3)
		addCrosshairLine(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 0, y: 15), color: shadowColor, width: 3)
		addCrosshairLine(from: CGPoint(x: -14, y: 0), to: CGPoint(x: -6, y: 0), color: materialColor, width: 1.5)
		addCrosshairLine(from: CGPoint(x: 6, y: 0), to: CGPoint(x: 14, y: 0), color: materialColor, width: 1.5)
		addCrosshairLine(from: CGPoint(x: 0, y: -14), to: CGPoint(x: 0, y: -6), color: materialColor, width: 1.5)
		addCrosshairLine(from: CGPoint(x: 0, y: 6), to: CGPoint(x: 0, y: 14), color: materialColor, width: 1.5)
	}

	private func addCrosshairLine(from start: CGPoint, to end: CGPoint, color: SKColor, width: CGFloat) {
		let path = CGMutablePath()
		path.move(to: start)
		path.addLine(to: end)

		let line = SKShapeNode(path: path)
		line.strokeColor = color
		line.lineWidth = width
		line.lineCap = .round
		crosshairNode.addChild(line)
	}

	private func renderPlayerStatusHud() {
		let statusTexture = SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/1int.tga"))
		let healthTexture = SKTexture(rect: spriteSheetRect(x: 0, y: 73, width: 50, height: 22), in: statusTexture)
		let ammoTexture = SKTexture(rect: spriteSheetRect(x: 0, y: 1, width: 63, height: 22), in: statusTexture)

		healthHudPanel = SKSpriteNode(texture: healthTexture)
		healthHudPanel.size = CGSize(width: 83, height: 35)
		healthHudPanel.anchorPoint = CGPoint(x: 0, y: 0.5)
		healthHudPanel.zPosition = 800
		addChild(healthHudPanel)

		healthValueShadowLabel = statusValueLabel(color: SKColor.black)
		healthValueShadowLabel.position = CGPoint(x: 63, y: -2)
		healthHudPanel.addChild(healthValueShadowLabel)

		healthValueLabel = statusValueLabel(color: SKColor.white)
		healthValueLabel.position = CGPoint(x: 61, y: 0)
		healthHudPanel.addChild(healthValueLabel)

		ammoHudPanel = SKSpriteNode(texture: ammoTexture)
		ammoHudPanel.size = CGSize(width: 93, height: 35)
		ammoHudPanel.anchorPoint = CGPoint(x: 0, y: 0.5)
		ammoHudPanel.zPosition = 800
		addChild(ammoHudPanel)

		ammoValueShadowLabel = statusValueLabel(color: SKColor.black)
		ammoValueShadowLabel.position = CGPoint(x: 62, y: -2)
		ammoHudPanel.addChild(ammoValueShadowLabel)

		ammoValueLabel = statusValueLabel(color: SKColor.white)
		ammoValueLabel.position = CGPoint(x: 60, y: 0)
		ammoHudPanel.addChild(ammoValueLabel)
	}

	private func layoutPlayerStatusHud() {
		let bottomPadding: CGFloat = 43
		let leftPadding: CGFloat = 48
		let panelGap: CGFloat = 13
		let healthWidth = healthHudPanel.size.width
		let ammoWidth = ammoHudPanel.size.width
		let totalWidth = healthWidth + panelGap + ammoWidth

		if size.width >= totalWidth + leftPadding * 2 {
			healthHudPanel.position = CGPoint(x: leftPadding, y: bottomPadding)
			ammoHudPanel.position = CGPoint(x: leftPadding + healthWidth + panelGap, y: bottomPadding)
		} else {
			healthHudPanel.position = CGPoint(x: leftPadding, y: bottomPadding + 42)
			ammoHudPanel.position = CGPoint(x: leftPadding, y: bottomPadding)
		}
	}

	private func updatePlayerStatusHud(health: Int, weapon: Weapon?) {
		healthValueLabel.text = "\(max(0, health))"
		healthValueShadowLabel.text = healthValueLabel.text
		healthHudPanel.isHidden = isCutsceneOverlayVisible

		let ammoText: String
		if let weapon = weapon, weapon.isFirearm, !isCutsceneOverlayVisible {
			ammoText = weapon.clipAmmo == -1 ? "INF" : "\(max(0, weapon.clipAmmo))/\(max(0, weapon.restAmmo))"
			ammoHudPanel.isHidden = false
		} else {
			ammoText = "--/--"
			ammoHudPanel.isHidden = true
		}
		ammoValueLabel.text = ammoText
		ammoValueShadowLabel.text = ammoText
	}

	private func statusValueLabel(color: SKColor) -> SKLabelNode {
		let label = SKLabelNode()
		label.fontName = "Arial-BoldMT"
		label.fontSize = 22
		label.fontColor = color
		label.horizontalAlignmentMode = .center
		label.verticalAlignmentMode = .center
		return label
	}

	private func spriteSheetRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
		return textureRect(x: x, y: y, width: width, height: height, textureSize: HudScene.statusTextureSize)
	}

	private func textureRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, textureSize: CGSize) -> CGRect {
		return CGRect(
			x: x / textureSize.width,
			y: (textureSize.height - y - height) / textureSize.height,
			width: width / textureSize.width,
			height: height / textureSize.height
		)
	}

}

// MARK: - Inventory

extension HudScene {

	private func renderInventoryOverlay() {
		inventoryOverlay = SKShapeNode(rectOf: size)
		inventoryOverlay.fillColor = SKColor.black.withAlphaComponent(0.72)
		inventoryOverlay.strokeColor = SKColor.clear
		inventoryOverlay.zPosition = 900
		inventoryOverlay.isHidden = true
		addChild(inventoryOverlay)

		inventoryTitleLabel = SKLabelNode()
		inventoryTitleLabel.fontName = "Arial-BoldMT"
		inventoryTitleLabel.fontSize = 24
		inventoryTitleLabel.fontColor = SKColor.white
		inventoryTitleLabel.text = "Inventory"
		inventoryTitleLabel.verticalAlignmentMode = .center
		inventoryOverlay.addChild(inventoryTitleLabel)

		inventoryHintLabel = SKLabelNode()
		inventoryHintLabel.fontName = "Arial"
		inventoryHintLabel.fontSize = 14
		inventoryHintLabel.fontColor = SKColor.white.withAlphaComponent(0.72)
		inventoryHintLabel.text = "Select a weapon"
		inventoryHintLabel.verticalAlignmentMode = .center
		inventoryOverlay.addChild(inventoryHintLabel)
	}

	private func layoutInventoryOverlay() {
		inventoryOverlay.position = CGPoint(x: size.width/2, y: size.height/2)
		inventoryOverlay.path = CGPath(
			rect: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height),
			transform: nil
		)
		inventoryTitleLabel.position = CGPoint(x: 0, y: min(190, size.height/2 - 70))
		inventoryHintLabel.position = CGPoint(x: 0, y: inventoryTitleLabel.position.y - 32)
		layoutInventoryRows()
	}

	func setInventoryVisible(_ isVisible: Bool) {
		guard inventoryOverlay.isHidden == isVisible else { return }

		if isVisible {
			guard !game.isGamePaused else { return }

			inventoryOverlay.isHidden = false
			rebuildInventoryRows()
			inventoryPausedGame = true
			game.setPaused(true, showsPauseScreen: false)
		} else {
			inventoryOverlay.isHidden = true
			if inventoryPausedGame {
				inventoryPausedGame = false
				game.setPaused(false)
			}
		}
	}

	func toggleInventory() {
		setInventoryVisible(inventoryOverlay.isHidden)
	}

	func handleInventorySelection(at point: CGPoint) -> Bool {
		guard inventoryOverlay.isHidden == false else { return false }

		let overlayPoint = convert(point, to: inventoryOverlay)
		for row in inventoryRows where row.node.frame.contains(overlayPoint) {
			game.equipPlayerWeapon(row.weapon)
			setInventoryVisible(false)
			return true
		}

		setInventoryVisible(false)
		return true
	}

	private func rebuildInventoryRows() {
		for row in inventoryRows {
			row.node.removeFromParent()
		}
		inventoryRows.removeAll()

		let weapons = game.playerInventoryWeapons()
		if weapons.isEmpty {
			inventoryHintLabel.text = "No weapons"
			return
		}
		inventoryHintLabel.text = "Select a weapon"

		addInventoryRow(title: "Empty hands", subtitle: nil, weapon: nil, isSelected: !weapons.contains(where: { $0.position == .hand }))
		for weapon in weapons {
			let ammoText: String?
			if weapon.isFirearm {
				ammoText = weapon.clipAmmo == -1 ? "unlimited" : "\(weapon.clipAmmo)/\(weapon.restAmmo)"
			} else {
				ammoText = nil
			}
			addInventoryRow(
				title: weapon.name,
				subtitle: ammoText,
				weapon: weapon,
				isSelected: weapon.position == .hand
			)
		}

		layoutInventoryRows()
	}

	private func addInventoryRow(title: String, subtitle: String?, weapon: Weapon?, isSelected: Bool) {
		let row = SKShapeNode(rectOf: CGSize(width: 360, height: 42), cornerRadius: 6)
		row.fillColor = isSelected ? SKColor.white.withAlphaComponent(0.24) : SKColor.white.withAlphaComponent(0.12)
		row.strokeColor = isSelected ? SKColor.white : SKColor.white.withAlphaComponent(0.28)
		row.lineWidth = 1
		inventoryOverlay.addChild(row)

		let titleLabel = SKLabelNode()
		titleLabel.fontName = "Arial"
		titleLabel.fontSize = 16
		titleLabel.fontColor = SKColor.white
		titleLabel.horizontalAlignmentMode = .left
		titleLabel.verticalAlignmentMode = .center
		titleLabel.text = title
		titleLabel.position = CGPoint(x: -166, y: 0)
		row.addChild(titleLabel)

		if let subtitle = subtitle {
			let subtitleLabel = SKLabelNode()
			subtitleLabel.fontName = "Arial"
			subtitleLabel.fontSize = 14
			subtitleLabel.fontColor = SKColor.white.withAlphaComponent(0.72)
			subtitleLabel.horizontalAlignmentMode = .right
			subtitleLabel.verticalAlignmentMode = .center
			subtitleLabel.text = subtitle
			subtitleLabel.position = CGPoint(x: 166, y: 0)
			row.addChild(subtitleLabel)
		}

		inventoryRows.append((node: row, weapon: weapon))
	}

	private func layoutInventoryRows() {
		guard inventoryRows.isEmpty == false else { return }

		let rowWidth = min(360, max(240, size.width - 48))
		let startY = inventoryHintLabel.position.y - 46
		for (index, row) in inventoryRows.enumerated() {
			row.node.path = CGPath(
				roundedRect: CGRect(x: -rowWidth/2, y: -21, width: rowWidth, height: 42),
				cornerWidth: 6,
				cornerHeight: 6,
				transform: nil
			)
			row.node.position = CGPoint(x: 0, y: startY - CGFloat(index) * 50)
			for case let label as SKLabelNode in row.node.children {
				if label.horizontalAlignmentMode == .left {
					label.position.x = -rowWidth/2 + 14
				} else if label.horizontalAlignmentMode == .right {
					label.position.x = rowWidth/2 - 14
				}
			}
		}
	}

}

// MARK: - Pause Screen

extension HudScene {

	private func renderPauseScreen() {
		pauseOverlay = SKShapeNode(rectOf: size)
		pauseOverlay.fillColor = SKColor.black.withAlphaComponent(0.68)
		pauseOverlay.strokeColor = SKColor.clear
		pauseOverlay.zPosition = 1000
		pauseOverlay.isHidden = true
		addChild(pauseOverlay)

		pauseTitleLabel = SKLabelNode()
		pauseTitleLabel.fontName = "Arial-BoldMT"
		pauseTitleLabel.fontSize = 38
		pauseTitleLabel.fontColor = SKColor.white
		pauseTitleLabel.text = "Paused"
		pauseTitleLabel.verticalAlignmentMode = .center
		pauseOverlay.addChild(pauseTitleLabel)

		pauseHintLabel = SKLabelNode()
		pauseHintLabel.fontName = "Arial"
		pauseHintLabel.fontSize = 17
		pauseHintLabel.fontColor = SKColor.white
		pauseHintLabel.text = "Press Esc to resume"
		pauseHintLabel.verticalAlignmentMode = .center
		pauseOverlay.addChild(pauseHintLabel)
	}

	func setPauseScreenVisible(_ isVisible: Bool) {
		pauseOverlay.isHidden = !isVisible
	}

}

// MARK: - Buttons

extension HudScene {

	func renderButtons() {
		let isVisible = showsTouchControls

		inventoryButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		inventoryButton.isHidden = !isVisible
		inventoryButton.position = CGPoint(x: size.width-45, y: size.height-45)
		inventoryButton.fillColor = SKColor.white
		inventoryButton.strokeColor = SKColor.clear
		addChild(inventoryButton)

		let inventoryButtonLabel = SKLabelNode()
		inventoryButtonLabel.fontName = "Arial"
		inventoryButtonLabel.fontSize = 17
		inventoryButtonLabel.fontColor = SKColor.black
		inventoryButtonLabel.text = "Inv"
		inventoryButtonLabel.verticalAlignmentMode = .center
		inventoryButton.addChild(inventoryButtonLabel)

		reloadButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		reloadButton.isHidden = !isVisible
		reloadButton.position = CGPoint(x: size.width-45, y: size.height-45-60)
		reloadButton.fillColor = SKColor.white
		reloadButton.strokeColor = SKColor.clear
		addChild(reloadButton)

		let reloadButtonLabel = SKLabelNode()
		reloadButtonLabel.fontName = "Arial"
		reloadButtonLabel.fontSize = 17
		reloadButtonLabel.fontColor = SKColor.black
		reloadButtonLabel.text = "Rel"
		reloadButtonLabel.verticalAlignmentMode = .center
		reloadButton.addChild(reloadButtonLabel)

		dropButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		dropButton.isHidden = !isVisible
		dropButton.position = CGPoint(x: size.width-45, y: size.height-45-60*2)
		dropButton.fillColor = SKColor.white
		dropButton.strokeColor = SKColor.clear
		addChild(dropButton)

		let dropButtonLabel = SKLabelNode()
		dropButtonLabel.fontName = "Arial"
		dropButtonLabel.fontSize = 17
		dropButtonLabel.fontColor = SKColor.black
		dropButtonLabel.text = "Drp"
		dropButtonLabel.verticalAlignmentMode = .center
		dropButton.addChild(dropButtonLabel)

		jumpButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		jumpButton.isHidden = !isVisible
		jumpButton.position = CGPoint(x: size.width-45, y: size.height-45-60*3)
		jumpButton.fillColor = SKColor.white
		jumpButton.strokeColor = SKColor.clear
		addChild(jumpButton)

		let jumpButtonLabel = SKLabelNode()
		jumpButtonLabel.fontName = "Arial"
		jumpButtonLabel.fontSize = 17
		jumpButtonLabel.fontColor = SKColor.black
		jumpButtonLabel.text = "Jmp"
		jumpButtonLabel.verticalAlignmentMode = .center
		jumpButton.addChild(jumpButtonLabel)

	}

	private func layoutTouchButtons() {
		inventoryButton?.position = CGPoint(x: size.width-45, y: size.height-45)
		reloadButton?.position = CGPoint(x: size.width-45, y: size.height-45-60)
		dropButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*2)
		jumpButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*3)

		guard showsTouchControls else {
			inventoryButton?.isHidden = true
			reloadButton?.isHidden = true
			dropButton?.isHidden = true
			jumpButton?.isHidden = true
			return
		}

		let isVisible = !isCutsceneOverlayVisible
		inventoryButton?.isHidden = !isVisible
		reloadButton?.isHidden = !isVisible
		dropButton?.isHidden = !isVisible
		jumpButton?.isHidden = !isVisible
	}

	func handlesTouchControl(at point: CGPoint) -> Bool {
		guard showsTouchControls else { return false }
		if isInventoryVisible {
			return true
		}
		return touchControlNode(at: point) != nil
	}

	private func touchControlNode(at point: CGPoint) -> SKNode? {
		return nodes(at: point).first { node in
			isTouchControlNode(node)
		}
	}

	private func isTouchControlNode(_ node: SKNode) -> Bool {
		let controls: [SKNode?] = [
			actionButton,
			inventoryButton,
			reloadButton,
			dropButton,
			jumpButton
		]

		return controls.contains { control in
			guard let control = control, !control.isHidden else { return false }
			return node === control || node.parent === control
		}
	}

}

// MARK: - Control

extension HudScene {

	#if os(iOS)

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)

		guard let touch = touches.first else { return }
		let location = touch.location(in: self)
		if handleInventorySelection(at: location) {
			return
		}

		if let node = touchControlNode(at: location) {
			switch node {
			case actionButton:
				activeTouchControl = .ACTION
				game.pressControl(.ACTION)
				game.actionButtonTapped()
			case inventoryButton, inventoryButton.children[0]:
				game.lastControl = .INVENTORY
				game.openInventory()
			case reloadButton, reloadButton.children[0]:
				game.lastControl = .RELOAD
				game.reloadPlayerWeapon()
				if game.mode == .walk {
					if let playerNode = game.scene.playerNode {
						print("pos:", playerNode.presentation.position)
					} else {
						print("pos:", game.cameraContainer.presentation.position)
					}
				} else if let vehicle = game.vehicle {
					print("pos:", vehicle.node.presentation.position)
				}
			case dropButton, dropButton.children[0]:
				game.lastControl = .WEAPONDROP
				game.dropPlayerWeapon()
			case jumpButton, jumpButton.children[0]:
				game.lastControl = .JUMP
				game.playerController?.jump()
				game.scene.pressedJump = true
			default:
				break
			}
		}
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)

		releaseActiveTouchControl()
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesCancelled(touches, with: event)

		releaseActiveTouchControl()
	}

	private func releaseActiveTouchControl() {
		guard let control = activeTouchControl else { return }

		game.releaseControl(control)
		activeTouchControl = nil
	}

	#elseif os(macOS)

	override func mouseDown(with event: NSEvent) {
		if handleInventorySelection(at: event.location(in: self)) {
			return
		}
		super.mouseDown(with: event)
	}

	override func keyDown(with event: NSEvent) {
		guard !event.isARepeat else { return }

		if event.keyCode == 53 { // escape
			if inventoryOverlay.isHidden == false {
				setInventoryVisible(false)
				return
			}
			clearVehicleControls()
			clearWalkingControls()
			clearFreeCameraControls()
			game.setPaused(!game.isGamePaused)
			return
		}

		guard !game.isGamePaused else { return }

		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0.2

		if event.keyCode == 8 { // C
			clearVehicleControls()
			clearWalkingControls()
			clearFreeCameraControls()
			game.toggleFreeCamera()
			SCNTransaction.commit()
			return
		}

		if game.mode == .freeCamera && handleFreeCameraKeyDown(event.keyCode) {
			SCNTransaction.commit()
			return
		}
		if game.mode == .freeCamera {
			SCNTransaction.commit()
			return
		}

		if game.mode == .car && handleVehicleKeyDown(event.keyCode) {
			SCNTransaction.commit()
			return
		}

		switch event.keyCode {
		case 4: // H
			game.playerDidHorn()

		case 7: // X
			game.holsterPlayerWeapons()

		case 51: // backspace
			game.lastControl = .WEAPONDROP
			game.dropPlayerWeapon()

		case 15, 37: // R, L
			game.pressControl(.RELOAD)
			game.reloadPlayerWeapon()

		case 34: // I
			game.pressControl(.INVENTORY)
			game.openInventory()

		case 31: // O
			game.showObjectives()

		case 59, 62: // control
			setCrouching(true)

		case 56, 60: // shift
			setRunning(true)

		case 49: // space
			if game.mode == .walk, game.scene.playerNode != nil {
				game.playerController?.jump()
				game.scene.pressedJump = true
			}

		case 3: // F
			guard let action = game.nearestAction() else { break }
			game.pressControl(.ACTION)
			game.performAction(action)

		case 0, 123: // A, left
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingLeft = true
				registerCrouchSidestepTap(direction: -1)
				updateWalkingControls()
			} else if game.mode == .walk {
				game.cameraNode.eulerAngles.y += 0.25
			}

		case 2, 124: // D, right
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingRight = true
				registerCrouchSidestepTap(direction: 1)
				updateWalkingControls()
			} else if game.mode == .walk {
				game.cameraNode.eulerAngles.y -= 0.25
			}

		case 1, 125: // S, down
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingBackward = true
				updateWalkingControls()
			} else if game.mode == .walk {
				let angle = game.cameraNode.presentation.rotation.y * game.cameraNode.presentation.rotation.w - .pi
				game.cameraNode.position.x += 0.5 * sin(angle)
				game.cameraNode.position.z += 0.5 * cos(angle)
			}

		case 13, 126: // W, up
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingForward = true
				updateWalkingControls()
			} else if game.mode == .walk {
				let angle = game.cameraNode.presentation.rotation.y * game.cameraNode.presentation.rotation.w - .pi
				game.cameraNode.position.x -= 2 * sin(angle)
				game.cameraNode.position.z -= 2 * cos(angle)
			}

		default:
			super.keyDown(with: event)
		}

		SCNTransaction.commit()
	}

	private func handleVehicleKeyDown(_ keyCode: UInt16) -> Bool {
		switch keyCode {
		case 0, 123: // A, left
			steeringLeft = true
		case 2, 124: // D, right
			steeringRight = true
		case 13, 126: // W, up
			accelerating = true
		case 1, 125: // S, down
			reversing = true
		case 49: // space
			braking = true
		case 9: // V
			game.toggleSpeedLimiter()
		case 15: // R
			clearVehicleControls()
			game.vehicle?.resetUpright()
		default:
			return false
		}

		updateVehicleControls()
		return true
	}

	private func handleFreeCameraKeyDown(_ keyCode: UInt16) -> Bool {
		switch keyCode {
		case 0, 123: // A, left
			freeCameraLeft = true
		case 2, 124: // D, right
			freeCameraRight = true
		case 13, 126: // W, up
			freeCameraForward = true
		case 1, 125: // S, down
			freeCameraBackward = true
		case 49: // space
			freeCameraUp = true
		case 56, 60: // shift
			freeCameraDown = true
		default:
			return false
		}

		updateFreeCameraControls()
		return true
	}

	override func keyUp(with event: NSEvent) {
		super.keyUp(with: event)

		guard !game.isGamePaused else { return }

		if game.mode == .freeCamera {
			switch event.keyCode {
			case 0, 123: // A, left
				freeCameraLeft = false
			case 2, 124: // D, right
				freeCameraRight = false
			case 13, 126: // W, up
				freeCameraForward = false
			case 1, 125: // S, down
				freeCameraBackward = false
			case 49: // space
				freeCameraUp = false
			case 56, 60: // shift
				freeCameraDown = false
			default:
				break
			}
			updateFreeCameraControls()
			return
		}

		if game.mode == .walk, game.scene.playerNode != nil {
			switch event.keyCode {
			case 0, 123: // A, left
				walkingLeft = false
				updateWalkingControls()
			case 2, 124: // D, right
				walkingRight = false
				updateWalkingControls()
			case 13, 126: // W, up
				walkingForward = false
				updateWalkingControls()
			case 1, 125: // S, down
				walkingBackward = false
				updateWalkingControls()
			case 59, 62: // control
				setCrouching(false)
			case 56, 60: // shift
				setRunning(false)
			case 15, 37: // R, L
				game.releaseControl(.RELOAD)
			case 34: // I
				game.releaseControl(.INVENTORY)
			case 31: // O
				game.releaseControl(.OBJECTIVES)
			case 3: // F
				game.releaseControl(.ACTION)
			default:
				break
			}
			return
		}

		switch event.keyCode {
		case 0, 123: // A, left
			steeringLeft = false
			updateVehicleControls()

		case 2, 124: // D, right
			steeringRight = false
			updateVehicleControls()

		case 13, 126: // W, up
			accelerating = false
			updateVehicleControls()

		case 1, 125: // S, down
			reversing = false
			updateVehicleControls()

		case 49: // space
			braking = false
			updateVehicleControls()

		case 15: // R
			game.releaseControl(.RELOAD)

		case 34: // I
			game.releaseControl(.INVENTORY)

		case 31: // O
			game.releaseControl(.OBJECTIVES)

		case 9: // V
			game.releaseControl(.SPEEDLIMIT)

		case 3: // F
			game.releaseControl(.ACTION)

		default:
			break
		}
	}

	private func updateVehicleControls() {
		guard let vehicle = game.vehicle else { return }

		let throttle: CGFloat
		if accelerating == reversing {
			throttle = 0
		} else {
			throttle = accelerating ? 1 : -0.55
		}

		let steering: CGFloat
		if steeringLeft == steeringRight {
			steering = 0
		} else {
			steering = steeringLeft ? -1 : 1
		}

		ride = throttle != 0
		reverse = throttle < 0
		vehicleSteering = steering
		vehicle.updateControls(throttle: throttle, brake: braking, steering: steering)
	}

	private func clearVehicleControls() {
		accelerating = false
		reversing = false
		braking = false
		steeringLeft = false
		steeringRight = false
		ride = false
		reverse = false
		vehicleSteering = 0
	}

	private func clearFreeCameraControls() {
		freeCameraForward = false
		freeCameraBackward = false
		freeCameraLeft = false
		freeCameraRight = false
		freeCameraUp = false
		freeCameraDown = false
		game.setFreeCameraMovement(x: 0, y: 0, z: 0, isFast: false)
	}

	private func updateWalkingControls() {
		let forward: SCNFloat
		if walkingForward == walkingBackward {
			forward = 0
		} else {
			forward = walkingForward ? 1 : -1
		}

		let turning: SCNFloat
		turning = 0

		let strafe: SCNFloat
		if walkingLeft == walkingRight {
			strafe = 0
		} else {
			strafe = walkingLeft ? -1 : 1
		}

		game.playerController?.setMovement(x: strafe, z: forward)
		game.playerController?.setTurn(turning)
	}

	private func clearWalkingControls() {
		walkingForward = false
		walkingBackward = false
		walkingLeft = false
		walkingRight = false
		setRunning(false)
		resetCrouchSidestepTap()
		setCrouching(false)
		game.playerController?.stop()
	}

	override func flagsChanged(with event: NSEvent) {
		super.flagsChanged(with: event)

		guard !game.isGamePaused else { return }
		guard game.mode == .walk, game.scene.playerNode != nil else {
			setRunning(false)
			setCrouching(false)
			return
		}

		let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
		setRunning(flags.contains(.shift))
		setCrouching(flags.contains(.control))
	}

	private func setRunning(_ isRunning: Bool) {
		guard !isRunning || (game.mode == .walk && game.scene.playerNode != nil) else { return }
		guard running != isRunning else { return }

		running = isRunning
		game.playerController?.setRunning(isRunning)
	}

	private func setCrouching(_ isCrouching: Bool) {
		guard crouching != isCrouching else { return }

		crouching = isCrouching
		game.setPlayerCrouching(isCrouching)
		resetCrouchSidestepTap()
	}

	private func registerCrouchSidestepTap(direction: Int) {
		guard crouching else {
			resetCrouchSidestepTap()
			return
		}

		let now = Date.timeIntervalSinceReferenceDate
		let isDoubleTap = direction == lastCrouchSidestepTapDirection && now - lastCrouchSidestepTapTime <= 0.32
		lastCrouchSidestepTapDirection = direction
		lastCrouchSidestepTapTime = now

		guard isDoubleTap else { return }

		resetCrouchSidestepTap()
		game.playDodgeAnimation(direction: direction < 0 ? .left : .right)
	}

	private func resetCrouchSidestepTap() {
		lastCrouchSidestepTapDirection = 0
		lastCrouchSidestepTapTime = 0
	}

	private func updateFreeCameraControls() {
		let forward: SCNFloat
		if freeCameraForward == freeCameraBackward {
			forward = 0
		} else {
			forward = freeCameraForward ? -1 : 1
		}

		let strafe: SCNFloat
		if freeCameraLeft == freeCameraRight {
			strafe = 0
		} else {
			strafe = freeCameraLeft ? -1 : 1
		}

		let vertical: SCNFloat
		if freeCameraUp == freeCameraDown {
			vertical = 0
		} else {
			vertical = freeCameraUp ? 1 : -1
		}

		game.setFreeCameraMovement(x: strafe, y: vertical, z: forward, isFast: false)
	}

	#endif

}
