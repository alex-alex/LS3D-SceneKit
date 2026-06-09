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

	weak var game: Game!

	var compass: SKSpriteNode!
	var compassNeedle: SKSpriteNode!
	var actionButton: SKSpriteNode!
	var speedometer: SKSpriteNode!
	var speedometerNeedle: SKShapeNode!
	var speedLimitIndicator: SKSpriteNode!
	var revCounter: SKSpriteNode!
	var revCounterNeedle: SKShapeNode!
	var mapNode: SKSpriteNode!
	var mapBorderNode: SKShapeNode!
	var mapMarkerNode: SKShapeNode!
	var pauseButton: SKShapeNode!
	var inventoryButton: SKShapeNode!
	var reloadButton: SKShapeNode!
	var sprintButton: SKShapeNode!
	var crouchButton: SKShapeNode!
	var jumpButton: SKShapeNode!
	var objectivesNode: SKNode!
	var consoleLabel: SKLabelNode!
	var subtitleLabel: SKLabelNode!
	private var scriptTimerLabel: SKLabelNode!
	private var cutsceneSubtitleLabel: SKLabelNode!
	var speedLabel: SKLabelNode!
	var playerStatusLabel: SKLabelNode!
	private var diagnosticsLabel: SKLabelNode!
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
	private var pauseDialogControls: [MenuDefControl] = []
	private var pauseDialogNode: SKNode!
	private var pauseDialogPaperNode: SKSpriteNode!
	private var pauseDialogHeaderNode: SKSpriteNode!
	private var pauseDialogTitleLabel: SKLabelNode!
	private var pauseSelectionLine: SKShapeNode!
	private var pauseOptionLabels: [SKLabelNode] = []
	private var pauseOptionControls: [MenuDefControl] = []
	private var pauseOptionFrames: [CGRect] = []
	private var selectedPauseOptionIndex = 0
	private var pauseHiddenStates: [(node: SKNode, isHidden: Bool)] = []
	private var inventoryOverlay: SKShapeNode!
	private var inventoryTitleLabel: SKLabelNode!
	private var inventoryHintLabel: SKLabelNode!
	private var letterboxTopBar: SKShapeNode!
	private var letterboxBottomBar: SKShapeNode!
	private var cutsceneFadeOverlay: SKShapeNode!
	private var loadBlackoutOverlay: SKShapeNode!
	private var missionEndContainer: SKNode!
	private var missionEndPaperNode: SKSpriteNode!
	private var missionEndHeaderNode: SKSpriteNode!
	private var missionEndTitleLabel: SKLabelNode!
	private var missionEndLabel: SKLabelNode!
	private var missionEndOptionLabels: [SKLabelNode] = []
	private var missionEndOptionFrames: [CGRect] = []
	private var missionEndControls: [MenuDefControl] = []
	private var selectedMissionEndOptionIndex = 0
	private var inventoryRows: [(node: SKShapeNode, dropButton: SKShapeNode?, weapon: Weapon?)] = []
	private var selectedInventoryRowIndex = 0
	private var inventoryRowScrollOffset: CGFloat = 0
	private var inventoryPausedGame = false
	private var isCutsceneOverlayVisible = false
	private var lastSpeedText: String?
	private var lastPlayerStatusText: String?
	private var lastDiagnosticsText: String?
	private var lastScriptTimerText: String?
	private var lastVehicleStealProgress: CGFloat = -1
	private var wasSpeedVisible = false
	private var activeScriptTimerId: NSUUID?
	private var scriptTimerEndTime: TimeInterval?
	private var scriptTimerRemainingMilliseconds: Float = 0
	private var isScriptTimerRequestedVisible = false
	private let consoleActionKey = "consoleMessage"
	private let subtitleActionKey = "subtitleMessage"
	private let cutsceneSubtitleActionKey = "cutsceneSubtitleMessage"
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
	private var activeTouchButton: SKNode?
	private var lastMissionEndSwipePoint: CGPoint?
	private var didSwipeMissionEndOption = false
	private var lastInventorySwipePoint: CGPoint?
	private var didSwipeInventory = false
	#endif
	private var running = false
	private var crouching = false
	private var lastCrouchSiderollTapDirection = 0
	private var lastCrouchSiderollTapTime: TimeInterval = 0
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
	private var freeCameraForward = false
	private var freeCameraBackward = false
	private var freeCameraLeft = false
	private var freeCameraRight = false
	private var freeCameraUp = false
	private var freeCameraDown = false
	private var freeCameraFast = false

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

		let speedometerTexture = HudScene.spriteTexture(
			imageName: "2int.tga",
			rect: CGRect(x: 94, y: 0, width: 162, height: 163),
			masksBlack: true
		)
		speedometer = SKSpriteNode(texture: speedometerTexture)
		speedometer.anchorPoint = CGPoint(x: 0, y: 0)
		speedometer.isHidden = true
		speedometer.size = CGSize(width: 220, height: 221)
		speedometer.zPosition = 800
		addChild(speedometer)
		speedometerNeedle = HudScene.instrumentNeedle(length: 93, width: 5)
		speedometerNeedle.position = CGPoint(x: speedometer.size.width * 0.5, y: speedometer.size.height * 0.5)
		speedometer.addChild(speedometerNeedle)

		let speedLimitIndicatorTexture = HudScene.spriteTexture(
			imageName: "2int.tga",
			rect: CGRect(x: 36, y: 116, width: 27, height: 27),
			masksBlack: true
		)
		speedLimitIndicator = SKSpriteNode(texture: speedLimitIndicatorTexture)
		speedLimitIndicator.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		speedLimitIndicator.isHidden = true
		speedLimitIndicator.size = CGSize(width: 27, height: 27)
		speedLimitIndicator.zRotation = CGFloat.pi / 4
		speedLimitIndicator.zPosition = 802
		addChild(speedLimitIndicator)

		let revCounterTexture = HudScene.spriteTexture(
			imageName: "2int.tga",
			rect: CGRect(x: 109, y: 165, width: 76, height: 76),
			masksBlack: true
		)
		revCounter = SKSpriteNode(texture: revCounterTexture)
		revCounter.anchorPoint = CGPoint(x: 0, y: 0)
		revCounter.isHidden = true
		revCounter.size = CGSize(width: 108, height: 108)
		revCounter.zPosition = 801
		addChild(revCounter)
		revCounterNeedle = HudScene.instrumentNeedle(length: 43, width: 4)
		revCounterNeedle.position = CGPoint(x: revCounter.size.width * 0.5, y: revCounter.size.height * 0.5)
		revCounter.addChild(revCounterNeedle)

		renderButtons()
		renderMapOverlay()

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
		consoleLabel.zPosition = 2100
		addChild(consoleLabel)

		subtitleLabel = SKLabelNode()
		subtitleLabel.fontName = "Arial"
		subtitleLabel.fontSize = 22
		subtitleLabel.fontColor = SKColor.white
		subtitleLabel.horizontalAlignmentMode = .center
		subtitleLabel.verticalAlignmentMode = .center
		subtitleLabel.numberOfLines = 0
		subtitleLabel.preferredMaxLayoutWidth = max(260, size.width - 160)
		subtitleLabel.alpha = 0
		subtitleLabel.zPosition = 2100
		addChild(subtitleLabel)

		scriptTimerLabel = SKLabelNode()
		scriptTimerLabel.fontName = "Menlo-Bold"
		scriptTimerLabel.fontSize = 24
		scriptTimerLabel.fontColor = SKColor.white
		scriptTimerLabel.horizontalAlignmentMode = .right
		scriptTimerLabel.verticalAlignmentMode = .top
		scriptTimerLabel.zPosition = 1200
		scriptTimerLabel.isHidden = true
		addChild(scriptTimerLabel)

		cutsceneSubtitleLabel = SKLabelNode()
		cutsceneSubtitleLabel.fontName = "Arial"
		cutsceneSubtitleLabel.fontSize = 22
		cutsceneSubtitleLabel.fontColor = SKColor.white
		cutsceneSubtitleLabel.horizontalAlignmentMode = .center
		cutsceneSubtitleLabel.verticalAlignmentMode = .center
		cutsceneSubtitleLabel.numberOfLines = 0
		cutsceneSubtitleLabel.preferredMaxLayoutWidth = max(260, size.width - 160)
		cutsceneSubtitleLabel.alpha = 0
		cutsceneSubtitleLabel.zPosition = 2100
		addChild(cutsceneSubtitleLabel)

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

		diagnosticsLabel = SKLabelNode()
		diagnosticsLabel.fontName = "Menlo"
		diagnosticsLabel.fontSize = 13
		diagnosticsLabel.fontColor = SKColor.white
		diagnosticsLabel.horizontalAlignmentMode = .left
		diagnosticsLabel.verticalAlignmentMode = .top
		diagnosticsLabel.numberOfLines = 0
		diagnosticsLabel.zPosition = 2600
		addChild(diagnosticsLabel)

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

	nonisolated override func didChangeSize(_ oldSize: CGSize) {
		Task { @MainActor [weak self] in
			self?.layoutHud()
		}
	}

	private func layoutHud() {
		guard compass != nil,
				  actionButton != nil,
				  speedometer != nil,
				  speedometerNeedle != nil,
				  speedLimitIndicator != nil,
				  revCounter != nil,
				  revCounterNeedle != nil,
				  mapNode != nil,
				  mapBorderNode != nil,
				  mapMarkerNode != nil,
				  objectivesNode != nil,
				  consoleLabel != nil,
				  subtitleLabel != nil,
				  scriptTimerLabel != nil,
				  cutsceneSubtitleLabel != nil,
				  speedLabel != nil,
				  playerStatusLabel != nil,
				  diagnosticsLabel != nil,
				  crosshairNode != nil,
				  vehicleStealProgressBackground != nil,
				  vehicleStealProgressFill != nil,
				  vehicleStealProgressLabel != nil,
				  healthHudPanel != nil,
				  ammoHudPanel != nil,
				  pauseOverlay != nil,
				  pauseDialogNode != nil,
				  pauseDialogPaperNode != nil,
				  pauseDialogHeaderNode != nil,
				  pauseDialogTitleLabel != nil,
				  pauseSelectionLine != nil,
				  inventoryOverlay != nil,
				  letterboxTopBar != nil,
				  letterboxBottomBar != nil,
				  cutsceneFadeOverlay != nil,
				  loadBlackoutOverlay != nil,
				  missionEndContainer != nil,
				  missionEndPaperNode != nil,
				  missionEndHeaderNode != nil,
				  missionEndTitleLabel != nil,
				  missionEndLabel != nil else { return }

		compass.position = CGPoint(x: 70, y: size.height-70)
		actionButton.position = CGPoint(x: 45, y: 104)
		layoutVehicleInstruments()
		layoutMapOverlay()
		objectivesNode.position = CGPoint(x: size.width/2, y: size.height * 2 / 3)
		consoleLabel.position = CGPoint(x: 24, y: actionButton.position.y + actionButton.size.height / 2 + 36)
		consoleLabel.preferredMaxLayoutWidth = max(240, size.width - 120)
		let letterboxBarHeight = max(48, size.height * 0.12)
		subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
		subtitleLabel.preferredMaxLayoutWidth = max(260, size.width - 160)
		scriptTimerLabel.position = CGPoint(x: size.width - 24, y: size.height - 24)
		cutsceneSubtitleLabel.position = CGPoint(x: size.width / 2, y: letterboxBarHeight / 2)
		cutsceneSubtitleLabel.preferredMaxLayoutWidth = max(260, size.width - 160)
		speedLabel.position = CGPoint(x: 24, y: size.height-150)
		playerStatusLabel.position = CGPoint(x: 24, y: 20)
		playerStatusLabel.preferredMaxLayoutWidth = max(220, size.width - 120)
		let diagnosticsX = compass.position.x + compass.size.width / 2 + 16
		diagnosticsLabel.position = CGPoint(x: diagnosticsX, y: size.height - 12)
		diagnosticsLabel.preferredMaxLayoutWidth = max(180, min(360, size.width - diagnosticsX - 12))
		crosshairNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
		layoutVehicleStealProgress()
		layoutPlayerStatusHud()
		pauseOverlay.position = CGPoint(x: size.width/2, y: size.height/2)
		pauseOverlay.path = CGPath(
			rect: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height),
			transform: nil
		)
		layoutPauseDialog()
		layoutInventoryOverlay()
		layoutCinematicOverlays()
		layoutMissionEndMenu()

		layoutTouchButtons()
	}

	func updateVehicleSpeed(
		_ speed: CGFloat,
		vehicleSpeed: CGFloat,
		force: CGFloat,
		isVisible: Bool,
		isSpeedLimiterEnabled: Bool
	) {
		if wasSpeedVisible != isVisible {
			wasSpeedVisible = isVisible
			speedometer.isHidden = !isGameplayHudVisible(isVisible)
			speedLimitIndicator.isHidden = !isGameplayHudVisible(isVisible && isSpeedLimiterEnabled)
			revCounter.isHidden = !isGameplayHudVisible(isVisible)
			speedLabel.isHidden = true
		}
		speedometer.isHidden = !isGameplayHudVisible(isVisible)
		speedLimitIndicator.isHidden = !isGameplayHudVisible(isVisible && isSpeedLimiterEnabled)
		revCounter.isHidden = !isGameplayHudVisible(isVisible)
		speedLabel.isHidden = true
		guard isVisible else { return }

		let bodySpeed = Int(speed.rounded())
		let wheelSpeed = Int(vehicleSpeed.rounded())
		let engineForce = Int(force.rounded())
		updateInstrumentNeedles(speed: vehicleSpeed, force: force)
		let speedText = "Body \(bodySpeed)  Vehicle \(wheelSpeed)  Force \(engineForce)"
		if lastSpeedText != speedText {
			lastSpeedText = speedText
			speedLabel.text = speedText
		}
	}

	private func layoutVehicleInstruments() {
		let shortSide = min(size.width, size.height)
		let scale: CGFloat = shortSide <= 430 ? 0.72 : 1
		let rightPadding: CGFloat = shortSide <= 430 ? 10 : 18
		let bottomPadding: CGFloat = shortSide <= 430 ? 10 : 18
		let gaugeGap: CGFloat = shortSide <= 430 ? 7 : 10

		speedometer.setScale(scale)
		revCounter.setScale(scale)
		speedLimitIndicator.setScale(scale)

		let speedometerWidth = speedometer.size.width * scale
		let speedometerHeight = speedometer.size.height * scale
		let revCounterWidth = revCounter.size.width * scale
		let indicatorWidth = speedLimitIndicator.size.width * scale

		speedometer.position = CGPoint(x: size.width - speedometerWidth - rightPadding, y: bottomPadding)
		speedLimitIndicator.position = CGPoint(
			x: speedometer.position.x + speedometerWidth - indicatorWidth / 2,
			y: speedometer.position.y + speedometerHeight + indicatorWidth / 2
		)
		revCounter.position = CGPoint(
			x: speedometer.position.x - revCounterWidth - gaugeGap,
			y: bottomPadding
		)
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

	func updateDiagnostics(framesPerSecond: CGFloat, position: SCNVector3, details: String? = nil) {
		let detailsText = details.map { "\n" + $0 } ?? ""
		let diagnosticsText = String(
			format: "FPS %.0f\nX %.2f  Y %.2f  Z %.2f%@",
			Double(framesPerSecond),
			Double(position.x),
			Double(position.y),
			Double(position.z),
			detailsText
		)

		if lastDiagnosticsText != diagnosticsText {
			lastDiagnosticsText = diagnosticsText
			diagnosticsLabel.text = diagnosticsText
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

	func showSubtitleText(_ text: String, duration: TimeInterval = 4) {
		subtitleLabel.removeAction(forKey: subtitleActionKey)
		subtitleLabel.text = remappedControlText(text)
		subtitleLabel.alpha = 1
		subtitleLabel.run(
			SKAction.sequence([
				SKAction.wait(forDuration: duration),
				SKAction.fadeOut(withDuration: 0.35)
			]),
			withKey: subtitleActionKey
		)
	}

	func showCutsceneSubtitleText(_ text: String, duration: TimeInterval = 4) {
		guard isCutsceneOverlayVisible else { return }

		cutsceneSubtitleLabel.removeAction(forKey: cutsceneSubtitleActionKey)
		cutsceneSubtitleLabel.text = remappedControlText(text)
		cutsceneSubtitleLabel.alpha = 1
		cutsceneSubtitleLabel.run(
			SKAction.sequence([
				SKAction.wait(forDuration: duration),
				SKAction.fadeOut(withDuration: 0.35)
			]),
			withKey: cutsceneSubtitleActionKey
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

	func showScriptTimer(scriptId: NSUUID, remainingMilliseconds: Float) {
		activeScriptTimerId = scriptId
		isScriptTimerRequestedVisible = true
		setScriptTimerRemainingMilliseconds(remainingMilliseconds)
		refreshScriptTimerVisibility()
	}

	func updateScriptTimer(scriptId: NSUUID, remainingMilliseconds: Float) {
		guard activeScriptTimerId == scriptId else { return }
		setScriptTimerRemainingMilliseconds(remainingMilliseconds)
		refreshScriptTimerVisibility()
	}

	func hideScriptTimer(scriptId: NSUUID) {
		guard activeScriptTimerId == scriptId else { return }
		activeScriptTimerId = nil
		scriptTimerEndTime = nil
		scriptTimerRemainingMilliseconds = 0
		isScriptTimerRequestedVisible = false
		lastScriptTimerText = nil
		scriptTimerLabel.text = nil
		refreshScriptTimerVisibility()
	}

	private func setScriptTimerRemainingMilliseconds(_ remainingMilliseconds: Float) {
		scriptTimerRemainingMilliseconds = max(0, remainingMilliseconds)
		if scriptTimerRemainingMilliseconds > 0 {
			scriptTimerEndTime = Date.timeIntervalSinceReferenceDate + TimeInterval(scriptTimerRemainingMilliseconds) / 1000
		} else {
			scriptTimerEndTime = nil
		}
		updateScriptTimerLabel()
	}

	private func refreshScriptTimerVisibility() {
		scriptTimerLabel.isHidden = !isGameplayHudVisible(isScriptTimerRequestedVisible)
	}

	func refreshScriptTimer() {
		updateScriptTimerLabel()
	}

	private func updateScriptTimerLabel() {
		guard isScriptTimerRequestedVisible else { return }
		let remainingMilliseconds: Float
		if let scriptTimerEndTime = scriptTimerEndTime {
			remainingMilliseconds = Float(max(0, scriptTimerEndTime - Date.timeIntervalSinceReferenceDate) * 1000)
		} else {
			remainingMilliseconds = scriptTimerRemainingMilliseconds
		}
		let text = HudScene.scriptTimerText(remainingMilliseconds: remainingMilliseconds)
		if lastScriptTimerText != text {
			lastScriptTimerText = text
			scriptTimerLabel.text = text
		}
	}

	private func isGameplayHudVisible(_ requestedVisibility: Bool) -> Bool {
		return requestedVisibility && !isCutsceneOverlayVisible && !isPauseScreenVisible
	}

	private static func scriptTimerText(remainingMilliseconds: Float) -> String {
		let totalSeconds = Int(ceil(Double(max(0, remainingMilliseconds)) / 1000))
		let hours = totalSeconds / 3600
		let minutes = (totalSeconds / 60) % 60
		let seconds = totalSeconds % 60
		if hours > 0 {
			return String(format: "%d:%02d:%02d", hours, minutes, seconds)
		}
		return String(format: "%02d:%02d", minutes, seconds)
	}

	private func updateInstrumentNeedles(speed: CGFloat, force: CGFloat) {
		speedometerNeedle.zRotation = HudScene.gaugeNeedleAngle(
			progress: max(0, min(1, speed / 240))
		)
		revCounterNeedle.zRotation = HudScene.gaugeNeedleAngle(
			progress: max(0, min(1, abs(force) / 6500))
		)
	}

	private static func gaugeNeedleAngle(progress: CGFloat) -> CGFloat {
		let startAngle = CGFloat.pi * 1.25
		let sweep = CGFloat.pi * 1.5
		return startAngle - sweep * progress
	}

	private static func instrumentNeedle(length: CGFloat, width: CGFloat) -> SKShapeNode {
		let path = CGMutablePath()
		path.move(to: CGPoint(x: -length * 0.12, y: 0))
		path.addLine(to: CGPoint(x: length, y: 0))

		let needle = SKShapeNode(path: path)
		needle.strokeColor = SKColor(red: 0.58, green: 0.02, blue: 0.02, alpha: 1)
		needle.lineWidth = width
		needle.lineCap = .round
		needle.zPosition = 5

		let hub = SKShapeNode(circleOfRadius: width * 1.35)
		hub.fillColor = SKColor(red: 0.35, green: 0.01, blue: 0.01, alpha: 1)
		hub.strokeColor = SKColor.clear
		hub.zPosition = 6
		needle.addChild(hub)

		return needle
	}

	func setActionButtonVisible(_ isVisible: Bool) {
		actionButton.isHidden = !isGameplayHudVisible(isVisible)
		layoutTouchButtons()
	}

	func setCompassVisible(_ isVisible: Bool) {
		compass.isHidden = !isGameplayHudVisible(isVisible)
	}

	func setCutsceneOverlayVisible(_ isVisible: Bool) {
		guard isCutsceneOverlayVisible != isVisible else { return }

		isCutsceneOverlayVisible = isVisible
		if isVisible {
			setMapOverlayVisible(false)
		}
		letterboxTopBar.isHidden = !isVisible
		letterboxBottomBar.isHidden = !isVisible

		if isVisible {
			compass.isHidden = true
			actionButton.isHidden = true
			speedometer.isHidden = true
			speedLimitIndicator.isHidden = true
			revCounter.isHidden = true
			speedLabel.isHidden = true
			playerStatusLabel.isHidden = true
			scriptTimerLabel.isHidden = true
			crosshairNode.isHidden = true
			vehicleStealProgressBackground.isHidden = true
			vehicleStealProgressFill.isHidden = true
			vehicleStealProgressLabel.isHidden = true
			healthHudPanel.isHidden = true
			ammoHudPanel.isHidden = true
			objectivesNode.isHidden = true
			consoleLabel.alpha = 0
			pauseButton?.isHidden = true
			inventoryButton?.isHidden = true
			reloadButton?.isHidden = true
			sprintButton?.isHidden = true
			crouchButton?.isHidden = true
			jumpButton?.isHidden = true
			playCutsceneFadeIn()
		} else {
			cutsceneFadeOverlay.removeAction(forKey: cutsceneFadeActionKey)
			cutsceneFadeOverlay.isHidden = true
			cutsceneFadeOverlay.alpha = 0
			healthHudPanel.isHidden = false
			speedometer.isHidden = !wasSpeedVisible
			speedLimitIndicator.isHidden = true
			revCounter.isHidden = !wasSpeedVisible
			speedLabel.isHidden = true
			refreshScriptTimerVisibility()
			objectivesNode.isHidden = objectivesNode.children.isEmpty
			consoleLabel.alpha = consoleLabel.hasActions() ? 1 : 0
			cutsceneSubtitleLabel.removeAction(forKey: cutsceneSubtitleActionKey)
			cutsceneSubtitleLabel.alpha = 0
			layoutTouchButtons()
		}
	}

	func setLoadBlackoutVisible(_ isVisible: Bool) {
		loadBlackoutOverlay.isHidden = !isVisible
		loadBlackoutOverlay.alpha = isVisible ? 1 : 0
	}

	func setScriptBlackoutVisible(_ isVisible: Bool, immediate: Bool) {
		loadBlackoutOverlay.removeAllActions()
		let wasHidden = loadBlackoutOverlay.isHidden
		loadBlackoutOverlay.isHidden = false
		if immediate {
			loadBlackoutOverlay.alpha = isVisible ? 1 : 0
			loadBlackoutOverlay.isHidden = !isVisible
			return
		}

		if isVisible && wasHidden {
			loadBlackoutOverlay.alpha = 0
		}
		let fade = isVisible ? SKAction.fadeIn(withDuration: 0.5) : SKAction.fadeOut(withDuration: 0.5)
		let actions = isVisible ? [fade] : [fade, SKAction.hide()]
		loadBlackoutOverlay.run(SKAction.sequence(actions))
	}

	func showMissionEndText(_ text: String?) {
		setMapOverlayVisible(false)
		missionEndLabel.text = text
		missionEndLabel.alpha = text == nil ? 0 : 1
		missionEndContainer.isHidden = false
		selectedMissionEndOptionIndex = 0
		layoutMissionEndMenu()
	}

}

// MARK: - Map Overlay

extension HudScene {

	private func renderMapOverlay() {
		let texture = SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/0mapar.bmp"))

		mapNode = SKSpriteNode(texture: texture)
		mapNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		mapNode.alpha = 0.62
		mapNode.zPosition = 700
		mapNode.isHidden = true
		addChild(mapNode)

		mapBorderNode = SKShapeNode()
		mapBorderNode.fillColor = SKColor.clear
		mapBorderNode.strokeColor = SKColor.black.withAlphaComponent(0.75)
		mapBorderNode.lineWidth = 1.5
		mapBorderNode.zPosition = mapNode.zPosition + 1
		mapBorderNode.isHidden = true
		addChild(mapBorderNode)

		let markerPath = CGMutablePath()
		markerPath.move(to: CGPoint(x: 0, y: 12))
		markerPath.addLine(to: CGPoint(x: -9, y: -8))
		markerPath.addLine(to: CGPoint(x: 9, y: -8))
		markerPath.closeSubpath()

		mapMarkerNode = SKShapeNode(path: markerPath)
		mapMarkerNode.fillColor = SKColor(red: 1, green: 0.93, blue: 0.12, alpha: 0.96)
		mapMarkerNode.strokeColor = SKColor.black.withAlphaComponent(0.65)
		mapMarkerNode.lineWidth = 1
		mapMarkerNode.zPosition = 2
		mapMarkerNode.isHidden = true
		mapNode.addChild(mapMarkerNode)
	}

	private func layoutMapOverlay() {
		let targetAspect: CGFloat = 2
		let maximumWidth = size.width * 0.86
		let maximumHeight = size.height * 0.74
		let width = min(maximumWidth, maximumHeight * targetAspect)
		let height = width / targetAspect
		let mapSize = CGSize(width: max(1, width), height: max(1, height))

		mapNode.size = mapSize
		mapNode.position = CGPoint(x: size.width / 2, y: size.height * 0.52)

		mapBorderNode.path = CGPath(
			rect: CGRect(x: -mapSize.width / 2, y: -mapSize.height / 2, width: mapSize.width, height: mapSize.height),
			transform: nil
		)
		mapBorderNode.position = mapNode.position
	}

	private func setMapOverlayVisible(_ isVisible: Bool) {
		if !isVisible {
			game.releaseControl(.MAP)
		}

		guard !isCutsceneOverlayVisible,
			  !isPauseScreenVisible,
			  !isInventoryVisible,
			  !isMissionEndVisible else {
			mapNode?.isHidden = true
			mapBorderNode?.isHidden = true
			return
		}

		mapNode.isHidden = !isVisible
		mapBorderNode.isHidden = !isVisible
		if !isVisible {
			mapMarkerNode.isHidden = true
		}
	}

	func updateMapMarker(normalizedPosition: CGPoint?, heading: CGFloat?) {
		guard let normalizedPosition = normalizedPosition else {
			mapMarkerNode.isHidden = true
			return
		}

		let localX = (normalizedPosition.x - 0.5) * mapNode.size.width
		let localY = (normalizedPosition.y - 0.5) * mapNode.size.height
		mapMarkerNode.position = CGPoint(x: localX, y: localY)
		mapMarkerNode.zRotation = heading ?? 0
		mapMarkerNode.isHidden = mapNode.isHidden
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
		loadBlackoutOverlay.alpha = 0
		loadBlackoutOverlay.isHidden = true
		addChild(loadBlackoutOverlay)

		missionEndControls = (try? MenuDef().controls(for: .gameOver)) ?? []
		missionEndContainer = SKNode()
		missionEndContainer.zPosition = 2101
		missionEndContainer.isHidden = true
		addChild(missionEndContainer)

		missionEndPaperNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir3.tga")))
		missionEndPaperNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		missionEndPaperNode.alpha = 0.92
		missionEndPaperNode.zPosition = 0
		missionEndContainer.addChild(missionEndPaperNode)

		missionEndHeaderNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir5a.tga")))
		missionEndHeaderNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		missionEndHeaderNode.zPosition = 1
		missionEndContainer.addChild(missionEndHeaderNode)

		missionEndTitleLabel = SKLabelNode(fontNamed: mafiaMenuTitleFontName)
		missionEndTitleLabel.fontColor = .white
		missionEndTitleLabel.horizontalAlignmentMode = .center
		missionEndTitleLabel.verticalAlignmentMode = .center
		missionEndTitleLabel.zPosition = 2
		missionEndContainer.addChild(missionEndTitleLabel)

		missionEndLabel = SKLabelNode()
		missionEndLabel.fontName = mafiaMenuFontName
		missionEndLabel.fontColor = .black
		missionEndLabel.horizontalAlignmentMode = .center
		missionEndLabel.verticalAlignmentMode = .center
		missionEndLabel.numberOfLines = 0
		missionEndLabel.zPosition = 2
		missionEndLabel.alpha = 0
		missionEndContainer.addChild(missionEndLabel)

		let optionControls = missionEndControls.filter { $0.type == "meti" }.sorted { $0.position.y < $1.position.y }
		for control in optionControls {
			let label = SKLabelNode(fontNamed: mafiaMenuFontName)
			label.text = TextDb.get(Int(control.textId))
			label.fontColor = .black
			label.horizontalAlignmentMode = .center
			label.verticalAlignmentMode = .center
			label.zPosition = 2
			missionEndContainer.addChild(label)
			missionEndOptionLabels.append(label)
		}
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

	private func layoutMissionEndMenu() {
		let windowControl = missionEndControls.first { $0.type == "tniw" }
		let scale = missionEndScale()
		let windowFrame = missionEndFrame(for: windowControl)
		let headerHeight = 50 * scale
		let bodyFrame = CGRect(
			x: windowFrame.minX,
			y: windowFrame.minY,
			width: windowFrame.width,
			height: windowFrame.height - headerHeight
		)

		missionEndHeaderNode.position = CGPoint(x: windowFrame.midX, y: windowFrame.maxY - headerHeight / 2)
		missionEndHeaderNode.size = CGSize(width: windowFrame.width, height: headerHeight)

		missionEndPaperNode.position = CGPoint(x: bodyFrame.midX, y: bodyFrame.midY)
		missionEndPaperNode.size = bodyFrame.size

		missionEndTitleLabel.text = windowControl.flatMap { TextDb.get(Int($0.textId)) }
		missionEndTitleLabel.fontSize = min(34, headerHeight * 0.68)
		missionEndTitleLabel.position = missionEndHeaderNode.position

		let optionControls = missionEndControls.filter { $0.type == "meti" }.sorted { $0.position.y < $1.position.y }
		let optionFrames = optionControls.map { missionEndChildFrame(for: $0, in: bodyFrame, scale: scale) }

		if let textSlot = missionEndControls.first(where: { $0.type == "tsil" }) {
			var frame = missionEndChildFrame(for: textSlot, in: bodyFrame, scale: scale)
				.insetBy(dx: 12 * scale, dy: 4 * scale)
			if let firstOptionFrame = optionFrames.first {
				let minimumMessageY = firstOptionFrame.maxY + 16 * scale
				let maximumMessageY = bodyFrame.maxY - frame.height / 2 - 8 * scale
				if frame.midY < minimumMessageY {
					let adjustedMidY = min(minimumMessageY, maximumMessageY)
					frame.origin.y = adjustedMidY - frame.height / 2
				}
			}
			missionEndLabel.fontSize = missionEndFontSize(for: frame, maximum: 24)
			missionEndLabel.position = CGPoint(x: frame.midX, y: frame.midY)
			missionEndLabel.preferredMaxLayoutWidth = frame.width
		}

		missionEndOptionFrames = []
		for (index, control) in optionControls.enumerated() where missionEndOptionLabels.indices.contains(index) {
			let frame = missionEndChildFrame(for: control, in: bodyFrame, scale: scale)
				.insetBy(dx: 12 * scale, dy: 3 * scale)
			let label = missionEndOptionLabels[index]
			label.fontSize = missionEndFontSize(for: frame, maximum: 26)
			label.position = CGPoint(x: frame.midX, y: frame.midY)
			label.preferredMaxLayoutWidth = frame.width
			missionEndOptionFrames.append(frame)
		}
		refreshMissionEndSelection()
	}

	private func moveMissionEndSelection(by offset: Int) {
		guard !missionEndOptionLabels.isEmpty else { return }

		selectedMissionEndOptionIndex = max(
			0,
			min(missionEndOptionLabels.count - 1, selectedMissionEndOptionIndex + offset)
		)
		refreshMissionEndSelection()
	}

	private func refreshMissionEndSelection() {
		for (index, label) in missionEndOptionLabels.enumerated() {
			let selected = index == selectedMissionEndOptionIndex
			label.fontColor = selected ? SKColor(red: 0.42, green: 0.04, blue: 0.03, alpha: 1) : .black
			label.setScale(selected ? 1.07 : 1)
		}
	}

	private func activateSelectedMissionEndOption() {
		guard missionEndOptionLabels.indices.contains(selectedMissionEndOptionIndex) else { return }

		game.activateMissionEndOption(at: selectedMissionEndOptionIndex)
	}

	private func missionEndFontSize(for frame: CGRect, maximum: CGFloat) -> CGFloat {
		return min(maximum, max(16, frame.height * 0.6))
	}

	private func missionEndScale() -> CGFloat {
		return min(size.width / 800, size.height / 600, 1.6)
	}

	private func missionEndFrame(for control: MenuDefControl?) -> CGRect {
		let scale = missionEndScale()
		let xOffset = (size.width - 800 * scale) / 2
		let yOffset = (size.height - 600 * scale) / 2
		let x = xOffset + (control?.position.x ?? 200) * scale
		let yTop = yOffset + (control?.position.y ?? 200) * scale
		let width = CGFloat(control?.scaleX ?? 400) * scale
		let height = CGFloat(control?.scaleY ?? 150) * scale
		return CGRect(x: x, y: size.height - yTop - height, width: width, height: height)
	}

	private func missionEndChildFrame(for control: MenuDefControl, in bodyFrame: CGRect, scale: CGFloat) -> CGRect {
		let x = bodyFrame.minX + control.position.x * scale
		let y = bodyFrame.maxY - control.position.y * scale - CGFloat(control.scaleY) * scale
		return CGRect(x: x, y: y, width: CGFloat(control.scaleX) * scale, height: CGFloat(control.scaleY) * scale)
	}

	private func playCutsceneFadeIn() {
		let startAlpha: CGFloat
		if !loadBlackoutOverlay.isHidden, loadBlackoutOverlay.alpha > 0 {
			startAlpha = loadBlackoutOverlay.alpha
			loadBlackoutOverlay.removeAllActions()
			loadBlackoutOverlay.alpha = 0
			loadBlackoutOverlay.isHidden = true
		} else {
			startAlpha = 1
		}

		cutsceneFadeOverlay.removeAction(forKey: cutsceneFadeActionKey)
		cutsceneFadeOverlay.isHidden = false
		cutsceneFadeOverlay.alpha = startAlpha
		cutsceneFadeOverlay.run(
			SKAction.sequence([
				SKAction.fadeOut(withDuration: 2.0),
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
		healthHudPanel.isHidden = isCutsceneOverlayVisible || isPauseScreenVisible

		let ammoText: String
		if let weapon = weapon, weapon.isFirearm, !isCutsceneOverlayVisible, !isPauseScreenVisible {
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

			setMapOverlayVisible(false)
			inventoryOverlay.isHidden = false
			rebuildInventoryRows()
			inventoryPausedGame = true
			game.setPaused(true, showsPauseScreen: false)
			game.requestRender()
		} else {
			inventoryOverlay.isHidden = true
			game.requestRender()
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
			if let weapon = row.weapon,
			   let dropButton = row.dropButton {
				let rowPoint = row.node.convert(overlayPoint, from: inventoryOverlay)
				if dropButton.frame.contains(rowPoint) {
					game.dropPlayerWeapon(weapon)
					rebuildInventoryRows()
					return true
				}
			}

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
		selectedInventoryRowIndex = 0
		inventoryRowScrollOffset = 0

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

		if let selectedIndex = inventoryRows.firstIndex(where: { row in
			if let weapon = row.weapon {
				return weapon.position == .hand
			}
			return !weapons.contains(where: { $0.position == .hand })
		}) {
			selectedInventoryRowIndex = selectedIndex
		}
		scrollSelectedInventoryRowIntoView()
		refreshInventorySelection()
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

		let dropButton: SKShapeNode?
		if weapon != nil {
			let button = SKShapeNode(rectOf: CGSize(width: 58, height: 28), cornerRadius: 5)
			button.fillColor = SKColor.white.withAlphaComponent(0.18)
			button.strokeColor = SKColor.white.withAlphaComponent(0.34)
			button.lineWidth = 1
			row.addChild(button)

			let dropLabel = SKLabelNode()
			dropLabel.fontName = "Arial-BoldMT"
			dropLabel.fontSize = 12
			dropLabel.fontColor = SKColor.white
			dropLabel.text = "Drop"
			dropLabel.verticalAlignmentMode = .center
			button.addChild(dropLabel)
			dropButton = button
		} else {
			dropButton = nil
		}

		inventoryRows.append((node: row, dropButton: dropButton, weapon: weapon))
	}

	private func layoutInventoryRows() {
		guard inventoryRows.isEmpty == false else { return }

		scrollSelectedInventoryRowIntoView()
		let rowWidth = min(360, max(240, size.width - 48))
		let startY = inventoryHintLabel.position.y - 46
		for (index, row) in inventoryRows.enumerated() {
			row.node.path = CGPath(
				roundedRect: CGRect(x: -rowWidth/2, y: -21, width: rowWidth, height: 42),
				cornerWidth: 6,
				cornerHeight: 6,
				transform: nil
			)
			row.node.position = CGPoint(x: 0, y: startY - CGFloat(index) * 50 + inventoryRowScrollOffset)
			for case let label as SKLabelNode in row.node.children {
				if label.horizontalAlignmentMode == .left {
					label.position.x = -rowWidth/2 + 14
				} else if label.horizontalAlignmentMode == .right {
					label.position.x = row.dropButton == nil ? rowWidth/2 - 14 : rowWidth/2 - 84
				}
			}
			row.dropButton?.position = CGPoint(x: rowWidth/2 - 42, y: 0)
		}
	}

	private func moveInventorySelection(by offset: Int) {
		guard !inventoryRows.isEmpty else { return }

		selectedInventoryRowIndex = max(0, min(inventoryRows.count - 1, selectedInventoryRowIndex + offset))
		scrollSelectedInventoryRowIntoView()
		refreshInventorySelection()
		layoutInventoryRows()
	}

	private func scrollSelectedInventoryRowIntoView() {
		guard !inventoryRows.isEmpty else { return }

		let rowSpacing: CGFloat = 50
		let rowHeight: CGFloat = 42
		let startY = inventoryHintLabel.position.y - 46
		let topVisibleY = startY
		let bottomVisibleY = -size.height / 2 + 64
		let visibleHeight = max(rowHeight, topVisibleY - bottomVisibleY)
		let maxScrollOffset = max(0, CGFloat(inventoryRows.count - 1) * rowSpacing - (visibleHeight - rowHeight))

		let selectedRowY = startY - CGFloat(selectedInventoryRowIndex) * rowSpacing + inventoryRowScrollOffset
		if selectedRowY - rowHeight / 2 < bottomVisibleY {
			inventoryRowScrollOffset += bottomVisibleY - (selectedRowY - rowHeight / 2)
		} else if selectedRowY + rowHeight / 2 > topVisibleY + rowHeight / 2 {
			inventoryRowScrollOffset -= (selectedRowY + rowHeight / 2) - (topVisibleY + rowHeight / 2)
		}
		inventoryRowScrollOffset = max(0, min(maxScrollOffset, inventoryRowScrollOffset))
	}

	private func refreshInventorySelection() {
		for (index, row) in inventoryRows.enumerated() {
			let selected = index == selectedInventoryRowIndex
			row.node.fillColor = selected ? SKColor.white.withAlphaComponent(0.24) : SKColor.white.withAlphaComponent(0.12)
			row.node.strokeColor = selected ? SKColor.white : SKColor.white.withAlphaComponent(0.28)
		}
	}

	private func equipSelectedInventoryRow() {
		guard inventoryRows.indices.contains(selectedInventoryRowIndex) else { return }

		game.equipPlayerWeapon(inventoryRows[selectedInventoryRowIndex].weapon)
		setInventoryVisible(false)
	}

	private func handleInventoryDropButton(at point: CGPoint) -> Bool {
		guard inventoryOverlay.isHidden == false else { return false }

		let overlayPoint = convert(point, to: inventoryOverlay)
		for row in inventoryRows {
			guard let weapon = row.weapon,
				  let dropButton = row.dropButton,
				  row.node.frame.contains(overlayPoint) else { continue }

			let rowPoint = row.node.convert(overlayPoint, from: inventoryOverlay)
			guard dropButton.frame.contains(rowPoint) else { continue }

			game.dropPlayerWeapon(weapon)
			rebuildInventoryRows()
			return true
		}
		return false
	}

}

// MARK: - Pause Screen

extension HudScene {

	private func renderPauseScreen() {
		pauseDialogControls = (try? MenuDef().controls(for: .gameMenu)) ?? []

		pauseOverlay = SKShapeNode(rectOf: size)
		pauseOverlay.fillColor = SKColor.black.withAlphaComponent(0.45)
		pauseOverlay.strokeColor = SKColor.clear
		pauseOverlay.zPosition = 2200
		pauseOverlay.isHidden = true
		addChild(pauseOverlay)

		pauseDialogNode = SKNode()
		pauseDialogNode.zPosition = 1
		pauseOverlay.addChild(pauseDialogNode)

		pauseDialogPaperNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir3.tga")))
		pauseDialogPaperNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		pauseDialogPaperNode.alpha = 0.94
		pauseDialogPaperNode.zPosition = 0
		pauseDialogNode.addChild(pauseDialogPaperNode)

		pauseDialogHeaderNode = SKSpriteNode(texture: SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/papir5a.tga")))
		pauseDialogHeaderNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		pauseDialogHeaderNode.zPosition = 1
		pauseDialogNode.addChild(pauseDialogHeaderNode)

		pauseDialogTitleLabel = SKLabelNode(fontNamed: mafiaMenuTitleFontName)
		pauseDialogTitleLabel.fontColor = .white
		pauseDialogTitleLabel.horizontalAlignmentMode = .center
		pauseDialogTitleLabel.verticalAlignmentMode = .center
		pauseDialogTitleLabel.zPosition = 2
		pauseDialogNode.addChild(pauseDialogTitleLabel)

		pauseSelectionLine = SKShapeNode()
		pauseSelectionLine.strokeColor = SKColor(red: 0.88, green: 0.05, blue: 0.06, alpha: 1)
		pauseSelectionLine.lineWidth = 2
		pauseSelectionLine.zPosition = 3
		pauseDialogNode.addChild(pauseSelectionLine)

		pauseOptionControls = pauseDialogControls
			.filter { $0.type == "meti" }
			.sorted { $0.position.y < $1.position.y }

		for control in pauseOptionControls {
			let label = SKLabelNode(fontNamed: mafiaMenuFontName)
			label.text = TextDb.get(Int(control.textId))
			label.fontColor = .black
			label.horizontalAlignmentMode = .center
			label.verticalAlignmentMode = .center
			label.zPosition = 1
			pauseDialogNode.addChild(label)
			pauseOptionLabels.append(label)
		}
	}

	func setPauseScreenVisible(_ isVisible: Bool) {
		if isVisible {
			setMapOverlayVisible(false)
			setGameplayHudHiddenForPause(true)
			pauseOverlay.isHidden = false
			selectedPauseOptionIndex = pauseOptionControls.firstIndex(where: { $0.id == 102 }) ?? 0
			refreshPauseSelection()
		} else {
			pauseOverlay.isHidden = true
			setGameplayHudHiddenForPause(false)
		}
	}

	private var isPauseScreenVisible: Bool {
		return pauseOverlay?.isHidden == false
	}

	private func layoutPauseDialog() {
		let scale = pauseDialogScale()
		let dialogControl = pauseDialogControls.first { $0.type == "tniw" }
		let dialogFrame = pauseDialogFrame(for: dialogControl)
		let titleHeight = min(50 * scale, dialogFrame.height * 0.28)
		let bodyFrame = CGRect(
			x: dialogFrame.minX,
			y: dialogFrame.minY,
			width: dialogFrame.width,
			height: dialogFrame.height - titleHeight
		)

		pauseDialogHeaderNode.position = CGPoint(x: dialogFrame.midX - size.width / 2, y: dialogFrame.maxY - titleHeight / 2 - size.height / 2)
		pauseDialogHeaderNode.size = CGSize(width: dialogFrame.width, height: titleHeight)

		pauseDialogPaperNode.position = CGPoint(x: bodyFrame.midX - size.width / 2, y: bodyFrame.midY - size.height / 2)
		pauseDialogPaperNode.size = bodyFrame.size

		pauseDialogTitleLabel.text = dialogControl.flatMap { TextDb.get(Int($0.textId)) }
		pauseDialogTitleLabel.fontSize = min(34 * scale, titleHeight * 0.68)
		pauseDialogTitleLabel.position = pauseDialogHeaderNode.position

		pauseOptionFrames = []
		for (index, control) in pauseOptionControls.enumerated() where pauseOptionLabels.indices.contains(index) {
			let frame = pauseDialogChildFrame(for: control, in: bodyFrame, scale: scale)
				.insetBy(dx: 12 * scale, dy: 3 * scale)
			let label = pauseOptionLabels[index]
			label.fontSize = min(36 * scale, max(16 * scale, frame.height * 0.82))
			label.position = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
			label.preferredMaxLayoutWidth = frame.width
			pauseOptionFrames.append(frame)
		}
		refreshPauseSelection()
	}

	private func handlePauseSelection(at point: CGPoint) -> Bool {
		guard game.isGamePaused, pauseOverlay.isHidden == false else { return false }

		for (index, frame) in pauseOptionFrames.enumerated() where frame.contains(point) {
			selectedPauseOptionIndex = index
			refreshPauseSelection()
			activateSelectedPauseOption()
			return true
		}

		return pauseDialogPaperNode.calculateAccumulatedFrame().contains(point)
	}

	private func movePauseSelection(by offset: Int) {
		guard !pauseOptionLabels.isEmpty else { return }

		selectedPauseOptionIndex = max(
			0,
			min(pauseOptionLabels.count - 1, selectedPauseOptionIndex + offset)
		)
		refreshPauseSelection()
	}

	private func refreshPauseSelection() {
		for (index, label) in pauseOptionLabels.enumerated() {
			let selected = index == selectedPauseOptionIndex
			label.fontColor = .black
			label.setScale(selected ? 1.07 : 1)
		}
		updatePauseSelectionLine()
	}

	private func updatePauseSelectionLine() {
		guard pauseOptionFrames.indices.contains(selectedPauseOptionIndex),
			  pauseOptionLabels.indices.contains(selectedPauseOptionIndex) else {
			pauseSelectionLine.path = nil
			return
		}

		let frame = pauseOptionFrames[selectedPauseOptionIndex]
		let label = pauseOptionLabels[selectedPauseOptionIndex]
		let lineWidth = min(frame.width - 16, max(24, label.frame.width * 0.98))
		let lineY = label.position.y - frame.height * 0.28
		let path = CGMutablePath()
		path.move(to: CGPoint(x: label.position.x - lineWidth / 2, y: lineY))
		path.addLine(to: CGPoint(x: label.position.x + lineWidth / 2, y: lineY))
		pauseSelectionLine.path = path
	}

	private func activateSelectedPauseOption() {
		guard pauseOptionControls.indices.contains(selectedPauseOptionIndex) else { return }

		switch pauseOptionControls[selectedPauseOptionIndex].id {
		case 102:
			game.exitPausedGameToMainMenu()
		case 103:
			game.loadGameFromPauseMenu()
		case 111:
			game.setPaused(false)
		default:
			break
		}
	}

	private func pauseDialogScale() -> CGFloat {
		return min(size.width / 800, size.height / 600)
	}

	private func pauseDialogFrame(for control: MenuDefControl?) -> CGRect {
		let scale = pauseDialogScale()
		let xOffset = (size.width - 800 * scale) / 2
		let yOffset = (size.height - 600 * scale) / 2
		let x = xOffset + (control?.position.x ?? 200) * scale
		let yTop = yOffset + (control?.position.y ?? 60) * scale
		let width = CGFloat(control?.scaleX ?? 217) * scale
		let height = CGFloat(control?.scaleY ?? 190) * scale
		return CGRect(x: x, y: size.height - yTop - height, width: width, height: height)
	}

	private func pauseDialogChildFrame(for control: MenuDefControl, in dialogFrame: CGRect, scale: CGFloat) -> CGRect {
		let x = dialogFrame.minX + control.position.x * scale
		let y = dialogFrame.maxY - control.position.y * scale - CGFloat(control.scaleY) * scale
		return CGRect(x: x, y: y, width: CGFloat(control.scaleX) * scale, height: CGFloat(control.scaleY) * scale)
	}

	private func setGameplayHudHiddenForPause(_ isHidden: Bool) {
		if isHidden {
			guard pauseHiddenStates.isEmpty else { return }
			let nodes: [SKNode?] = [
				compass,
				actionButton,
				speedometer,
				speedLimitIndicator,
				revCounter,
				speedLabel,
				playerStatusLabel,
				diagnosticsLabel,
				consoleLabel,
				subtitleLabel,
				scriptTimerLabel,
				cutsceneSubtitleLabel,
				crosshairNode,
				vehicleStealProgressBackground,
				vehicleStealProgressFill,
				vehicleStealProgressLabel,
				healthHudPanel,
				ammoHudPanel,
				objectivesNode,
				pauseButton,
				inventoryButton,
				reloadButton,
				sprintButton,
				crouchButton,
				jumpButton
			]
			pauseHiddenStates = nodes.compactMap { node in
				guard let node = node else { return nil }
				return (node: node, isHidden: node.isHidden)
			}
			pauseHiddenStates.forEach { $0.node.isHidden = true }
		} else {
			pauseHiddenStates.forEach { $0.node.isHidden = $0.isHidden }
			pauseHiddenStates.removeAll()
			refreshScriptTimerVisibility()
			layoutTouchButtons()
		}
	}

}

// MARK: - Buttons

extension HudScene {

	func renderButtons() {
		let isVisible = showsTouchControls

		pauseButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		pauseButton.isHidden = !isVisible
		pauseButton.position = CGPoint(x: 45, y: size.height-45)
		pauseButton.fillColor = SKColor.white
		pauseButton.strokeColor = SKColor.clear
		addChild(pauseButton)

		let pauseButtonLabel = SKLabelNode()
		pauseButtonLabel.fontName = "Arial"
		pauseButtonLabel.fontSize = 17
		pauseButtonLabel.fontColor = SKColor.black
		pauseButtonLabel.text = "Pau"
		pauseButtonLabel.verticalAlignmentMode = .center
		pauseButton.addChild(pauseButtonLabel)

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
		reloadButtonLabel.text = "Rld"
		reloadButtonLabel.verticalAlignmentMode = .center
		reloadButton.addChild(reloadButtonLabel)

		sprintButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		sprintButton.isHidden = !isVisible
		sprintButton.position = CGPoint(x: size.width-45, y: size.height-45-60*2)
		sprintButton.strokeColor = SKColor.clear
		addChild(sprintButton)

		let sprintButtonLabel = SKLabelNode()
		sprintButtonLabel.fontName = "Arial"
		sprintButtonLabel.fontSize = 17
		sprintButtonLabel.fontColor = SKColor.black
		sprintButtonLabel.text = "Spr"
		sprintButtonLabel.verticalAlignmentMode = .center
		sprintButton.addChild(sprintButtonLabel)
		updateSprintButtonAppearance()

		crouchButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		crouchButton.isHidden = !isVisible
		crouchButton.position = CGPoint(x: size.width-45, y: size.height-45-60*3)
		crouchButton.strokeColor = SKColor.clear
		addChild(crouchButton)

		let crouchButtonLabel = SKLabelNode()
		crouchButtonLabel.fontName = "Arial"
		crouchButtonLabel.fontSize = 17
		crouchButtonLabel.fontColor = SKColor.black
		crouchButtonLabel.text = "Crh"
		crouchButtonLabel.verticalAlignmentMode = .center
		crouchButton.addChild(crouchButtonLabel)
		updateCrouchButtonAppearance()

		jumpButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		jumpButton.isHidden = !isVisible
		jumpButton.position = CGPoint(x: size.width-45, y: size.height-45-60*4)
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
		pauseButton?.position = CGPoint(x: 45, y: size.height-45)
		inventoryButton?.position = CGPoint(x: size.width-45, y: size.height-45)
		reloadButton?.position = CGPoint(x: size.width-45, y: size.height-45-60)
		sprintButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*2)
		crouchButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*3)
		jumpButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*4)

		guard showsTouchControls else {
			pauseButton?.isHidden = true
			inventoryButton?.isHidden = true
			reloadButton?.isHidden = true
			sprintButton?.isHidden = true
			crouchButton?.isHidden = true
			jumpButton?.isHidden = true
			return
		}

		let isVisible = !isCutsceneOverlayVisible
		guard !isPauseScreenVisible else {
			pauseButton?.isHidden = true
			inventoryButton?.isHidden = true
			reloadButton?.isHidden = true
			sprintButton?.isHidden = true
			crouchButton?.isHidden = true
			jumpButton?.isHidden = true
			return
		}
		let showsWalkingControls = isVisible && game.mode == .walk && game.scene.playerNode != nil
		pauseButton?.isHidden = !isVisible
		inventoryButton?.isHidden = !isVisible
		reloadButton?.isHidden = !isVisible
		sprintButton?.isHidden = !showsWalkingControls
		crouchButton?.isHidden = !showsWalkingControls
		jumpButton?.isHidden = !showsWalkingControls
	}

	func handlesTouchControl(at point: CGPoint) -> Bool {
		guard showsTouchControls else { return false }
		if isMissionEndVisible {
			return true
		}
		if isInventoryVisible {
			return true
		}
		if game.isGamePaused {
			return true
		}
		return touchControlNode(at: point) != nil
	}

	private var isMissionEndVisible: Bool {
		return missionEndContainer?.isHidden == false
	}

	private func handleMissionEndSelection(at point: CGPoint) -> Bool {
		guard isMissionEndVisible else { return false }

		for (index, frame) in missionEndOptionFrames.enumerated() where frame.contains(point) {
			game.activateMissionEndOption(at: index)
			return true
		}

		return false
	}

	private func touchControlNode(at point: CGPoint) -> SKNode? {
		return nodes(at: point).first { node in
			isTouchControlNode(node)
		}
	}

	private func isTouchControlNode(_ node: SKNode) -> Bool {
		let controls: [SKNode?] = [
			actionButton,
			speedometer,
			speedLimitIndicator,
			pauseButton,
			inventoryButton,
			reloadButton,
			sprintButton,
			crouchButton,
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
		if isMissionEndVisible {
			lastMissionEndSwipePoint = location
			didSwipeMissionEndOption = false
			return
		}
		if isInventoryVisible {
			if handleInventoryDropButton(at: location) {
				return
			}
			lastInventorySwipePoint = location
			didSwipeInventory = false
			return
		}
		if handleInventorySelection(at: location) {
			return
		}
		if handlePauseSelection(at: location) {
			return
		}
		if game.isGamePaused,
		   let node = touchControlNode(at: location),
		   !(node === pauseButton || node.parent === pauseButton) {
			return
		}

		if let node = touchControlNode(at: location) {
			switch node {
			case actionButton:
				activeTouchControl = .ACTION
				game.pressControl(.ACTION)
				game.actionButtonTapped()
			case pauseButton, pauseButton.children[0]:
				activeTouchButton = nil
				setRunning(false)
				setCrouching(false)
				game.setPaused(!game.isGamePaused)
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
			case speedometer, speedometerNeedle, speedLimitIndicator:
				game.toggleSpeedLimiter()
			case sprintButton, sprintButton.children[0]:
				guard game.mode == .walk, game.scene.playerNode != nil else { break }
				activeTouchButton = sprintButton
				setRunning(true)
			case crouchButton, crouchButton.children[0]:
				guard game.mode == .walk, game.scene.playerNode != nil else { break }
				activeTouchButton = crouchButton
				setCrouching(true)
			case jumpButton, jumpButton.children[0]:
				game.lastControl = .JUMP
				game.playerController?.jump()
				game.scene.pressedJump = true
			default:
				break
			}
		}
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesMoved(touches, with: event)

		guard isMissionEndVisible,
			  let point = touches.first?.location(in: self) else {
			handleInventoryTouchMoved(touches)
			return
		}

		handleMissionEndTouchMoved(to: point)
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)

		if isMissionEndVisible {
			defer {
				lastMissionEndSwipePoint = nil
				didSwipeMissionEndOption = false
			}
			guard didSwipeMissionEndOption == false,
				  (touches.first?.tapCount ?? 0) >= 2 else { return }

			activateSelectedMissionEndOption()
			return
		}

		if isInventoryVisible {
			defer {
				lastInventorySwipePoint = nil
				didSwipeInventory = false
			}
			guard didSwipeInventory == false,
				  (touches.first?.tapCount ?? 0) >= 2 else { return }

			equipSelectedInventoryRow()
			return
		}

		releaseActiveTouchControl()
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesCancelled(touches, with: event)

		if isMissionEndVisible {
			lastMissionEndSwipePoint = nil
			didSwipeMissionEndOption = false
			return
		}
		if isInventoryVisible {
			lastInventorySwipePoint = nil
			didSwipeInventory = false
			return
		}

		releaseActiveTouchControl()
	}

	private func handleMissionEndTouchMoved(to point: CGPoint) {
		guard let lastPoint = lastMissionEndSwipePoint else { return }

		let deltaY = point.y - lastPoint.y
		let rowHeight = missionEndOptionFrames.first?.height ?? 32
		let threshold = max(18, rowHeight * 0.75)
		if abs(deltaY) >= threshold {
			moveMissionEndSelection(by: deltaY > 0 ? -1 : 1)
			lastMissionEndSwipePoint = point
			didSwipeMissionEndOption = true
		}
	}

	private func handleInventoryTouchMoved(_ touches: Set<UITouch>) {
		guard isInventoryVisible,
			  let point = touches.first?.location(in: self),
			  let lastPoint = lastInventorySwipePoint else { return }

		let deltaY = point.y - lastPoint.y
		let rowHeight = inventoryRows.first?.node.frame.height ?? 42
		let threshold = max(18, rowHeight * 0.75)
		if abs(deltaY) >= threshold {
			moveInventorySelection(by: deltaY > 0 ? -1 : 1)
			lastInventorySwipePoint = point
			didSwipeInventory = true
		}
	}

	private func releaseActiveTouchControl() {
		if activeTouchButton === sprintButton {
			setRunning(false)
		} else if activeTouchButton === crouchButton {
			setCrouching(false)
		}
		activeTouchButton = nil

		if let control = activeTouchControl {
			game.releaseControl(control)
			activeTouchControl = nil
		}
	}

	#elseif os(macOS)

	override func mouseDown(with event: NSEvent) {
		let location = event.location(in: self)
		if handleMissionEndSelection(at: location) {
			return
		}
		if handleInventorySelection(at: location) {
			return
		}
		if handlePauseSelection(at: location) {
			return
		}
		super.mouseDown(with: event)
	}

	override func keyDown(with event: NSEvent) {
		if event.isARepeat {
			if isMissionEndVisible {
				switch event.keyCode {
				case 125: // down
					moveMissionEndSelection(by: 1)
				case 126: // up
					moveMissionEndSelection(by: -1)
				default:
					break
				}
			} else if inventoryOverlay.isHidden == false {
				switch event.keyCode {
				case 125: // down
					moveInventorySelection(by: 1)
				case 126: // up
					moveInventorySelection(by: -1)
				default:
					break
				}
			} else if game.isGamePaused {
				switch event.keyCode {
				case 125: // down
					movePauseSelection(by: 1)
				case 126: // up
					movePauseSelection(by: -1)
				default:
					break
				}
			}
			return
		}

		if isMissionEndVisible {
			switch event.keyCode {
			case 125: // down
				moveMissionEndSelection(by: 1)
			case 126: // up
				moveMissionEndSelection(by: -1)
			case 36, 76: // return, keypad enter
				activateSelectedMissionEndOption()
			case 53: // escape
				game.activateMissionEndOption(at: 1)
			default:
				break
			}
			return
		}

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

		if event.keyCode == 34 { // I
			game.pressControl(.INVENTORY)
			toggleInventory()
			return
		}

		if event.keyCode == 48 { // tab
			guard !game.isGamePaused,
				  inventoryOverlay.isHidden,
				  !isCutsceneOverlayVisible,
				  !isMissionEndVisible else { return }
			game.pressControl(.MAP)
			setMapOverlayVisible(true)
			return
		}

		if inventoryOverlay.isHidden == false {
			switch event.keyCode {
			case 125: // down
				moveInventorySelection(by: 1)
			case 126: // up
				moveInventorySelection(by: -1)
			case 36, 76: // return, keypad enter
				equipSelectedInventoryRow()
			default:
				break
			}
			return
		}

		if game.isGamePaused {
			switch event.keyCode {
			case 125: // down
				movePauseSelection(by: 1)
			case 126: // up
				movePauseSelection(by: -1)
			case 36, 76: // return, keypad enter
				activateSelectedPauseOption()
			default:
				break
			}
			return
		}

		guard !game.isGamePaused else { return }

		if event.keyCode == 36 || event.keyCode == 76 { // return, keypad enter
			if game.scene.requestCutsceneSkip() {
				return
			}
		}

		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0.2

		if event.keyCode == 35 { // P
			let isEnabled = Script.toggleCommandLogging()
			showConsoleText("Script logging \(isEnabled ? "enabled" : "disabled")")
			SCNTransaction.commit()
			return
		}

		if event.keyCode == 40 { // K
			game.toggleCollisionWireframes()
			SCNTransaction.commit()
			return
		}

		if event.keyCode == 8 { // C
			clearVehicleControls()
			clearWalkingControls()
			clearFreeCameraControls()
			game.toggleFreeCamera()
			SCNTransaction.commit()
			return
		}

		if event.keyCode == 11 { // B
			game.addAllPossiblePlayerInventoryItems()
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
			if game.mode == .car {
				game.playerDidHorn()
			} else {
				game.holsterPlayerWeapons()
			}

		case 7: // X
			game.holsterPlayerWeapons()

		case 51: // backspace
			game.lastControl = .WEAPONDROP
			game.dropPlayerWeapon()

		case 15, 37: // R, L
			game.pressControl(.RELOAD)
			game.reloadPlayerWeapon()

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
				registerCrouchSiderollTap(direction: -1)
				updateWalkingControls()
			} else if game.mode == .walk {
				game.cameraNode.eulerAngles.y += 0.25
			}

		case 2, 124: // D, right
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingRight = true
				registerCrouchSiderollTap(direction: 1)
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
		case 37: // L
			game.vehicle?.liftForCollisionDebug()
			showConsoleText("Vehicle lifted for collision debug")
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
			freeCameraFast = true
		default:
			return false
		}

		updateFreeCameraControls()
		return true
	}

	override func keyUp(with event: NSEvent) {
		super.keyUp(with: event)

		if event.keyCode == 48 { // tab
			setMapOverlayVisible(false)
			return
		}

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
				freeCameraFast = false
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
		freeCameraFast = false
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
		resetCrouchSiderollTap()
		setCrouching(false)
		game.playerController?.stop()
	}

	override func flagsChanged(with event: NSEvent) {
		super.flagsChanged(with: event)

		guard !game.isGamePaused else { return }
		if game.mode == .freeCamera {
			let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
			freeCameraFast = flags.contains(.shift)
			updateFreeCameraControls()
			return
		}

		guard game.mode == .walk, game.scene.playerNode != nil else {
			setRunning(false)
			setCrouching(false)
			return
		}

		let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
		setRunning(flags.contains(.shift))
		setCrouching(flags.contains(.control))
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

		game.setFreeCameraMovement(x: strafe, y: vertical, z: forward, isFast: freeCameraFast)
	}

	#endif

	private func setRunning(_ isRunning: Bool) {
		guard !isRunning || (game.mode == .walk && game.scene.playerNode != nil) else { return }
		guard running != isRunning else { return }

		running = isRunning
		game.playerController?.setRunning(isRunning)
		updateSprintButtonAppearance()
	}

	private func setCrouching(_ isCrouching: Bool) {
		guard crouching != isCrouching else { return }

		crouching = isCrouching
		game.setPlayerCrouching(isCrouching)
		resetCrouchSiderollTap()
		updateCrouchButtonAppearance()
	}

	func registerCrouchSiderollSwipe(direction: Int) {
		guard crouching else {
			resetCrouchSiderollTap()
			return
		}

		resetCrouchSiderollTap()
		game.playSiderollAnimation(direction: direction < 0 ? .left : .right)
	}

	private func registerCrouchSiderollTap(direction: Int) {
		guard crouching else {
			resetCrouchSiderollTap()
			return
		}

		let now = Date.timeIntervalSinceReferenceDate
		let isDoubleTap = direction == lastCrouchSiderollTapDirection && now - lastCrouchSiderollTapTime <= 0.32
		lastCrouchSiderollTapDirection = direction
		lastCrouchSiderollTapTime = now

		guard isDoubleTap else { return }

		resetCrouchSiderollTap()
		game.playSiderollAnimation(direction: direction < 0 ? .left : .right)
	}

	private func resetCrouchSiderollTap() {
		lastCrouchSiderollTapDirection = 0
		lastCrouchSiderollTapTime = 0
	}

	private func updateCrouchButtonAppearance() {
		guard let crouchButton = crouchButton else { return }

		crouchButton.fillColor = crouching ? SKColor(red: 0.78, green: 0.88, blue: 1, alpha: 1) : SKColor.white
	}

	private func updateSprintButtonAppearance() {
		guard let sprintButton = sprintButton else { return }

		sprintButton.fillColor = running ? SKColor(red: 0.82, green: 1, blue: 0.76, alpha: 1) : SKColor.white
	}

}
