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

	var compass: SKShapeNode!
	var compassNeedle: SKShapeNode!
	var actionButton: SKShapeNode!
	var inventoryButton: SKShapeNode!
	var reloadButton: SKShapeNode!
	var dropButton: SKShapeNode!
	var jumpButton: SKShapeNode!
	var carButton: SKShapeNode!
	var objectivesLabel: SKLabelNode!
	var consoleLabel: SKLabelNode!
	var speedLabel: SKLabelNode!
	private var pauseOverlay: SKShapeNode!
	private var pauseTitleLabel: SKLabelNode!
	private var pauseHintLabel: SKLabelNode!
	private var inventoryOverlay: SKShapeNode!
	private var inventoryTitleLabel: SKLabelNode!
	private var inventoryHintLabel: SKLabelNode!
	private var inventoryRows: [(node: SKShapeNode, weapon: Weapon?)] = []
	private var lastSpeedText: String?
	private var wasSpeedVisible = false
	private let consoleActionKey = "consoleMessage"
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
	private var crouching = false
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

		compass = SKShapeNode(ellipseOf: CGSize(width: 100, height: 100))
		compass.isHidden = true
		compass.fillColor = SKColor.white
		compass.strokeColor = SKColor.clear
		addChild(compass)

		compassNeedle = SKShapeNode(rectOf: CGSize(width: 100, height: 2))
		compassNeedle.fillColor = SKColor.red
		compassNeedle.strokeColor = SKColor.clear
		compass.addChild(compassNeedle)

		let compassNeedlePoint = SKShapeNode(ellipseOf: CGSize(width: 10, height: 10))
		compassNeedlePoint.position = CGPoint(x: 40, y: 0)
		compassNeedlePoint.fillColor = SKColor.red
		compassNeedlePoint.strokeColor = SKColor.clear
		compassNeedle.addChild(compassNeedlePoint)

		actionButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		actionButton.isHidden = true
		actionButton.fillColor = SKColor.blue
		actionButton.strokeColor = SKColor.clear
		addChild(actionButton)

		renderButtons()

		objectivesLabel = SKLabelNode()
		objectivesLabel.fontName = "Arial"
		objectivesLabel.fontSize = 17
		objectivesLabel.fontColor = SKColor.white
		objectivesLabel.horizontalAlignmentMode = .center
		objectivesLabel.verticalAlignmentMode = .center
		objectivesLabel.numberOfLines = 0
		objectivesLabel.preferredMaxLayoutWidth = max(300, size.width - 160)
		addChild(objectivesLabel)

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

		renderPauseScreen()
		renderInventoryOverlay()

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
				  objectivesLabel != nil,
				  consoleLabel != nil,
				  speedLabel != nil,
				  pauseOverlay != nil,
				  inventoryOverlay != nil else { return }

		compass.position = CGPoint(x: 70, y: size.height-70)
		actionButton.position = CGPoint(x: 45, y: 45)
		objectivesLabel.position = CGPoint(x: size.width/2, y: size.height/2)
		objectivesLabel.preferredMaxLayoutWidth = max(300, size.width - 160)
		consoleLabel.position = CGPoint(x: 24, y: size.height-24)
		consoleLabel.preferredMaxLayoutWidth = max(240, size.width - 120)
		speedLabel.position = CGPoint(x: 24, y: size.height-150)
		pauseOverlay.position = CGPoint(x: size.width/2, y: size.height/2)
		pauseOverlay.path = CGPath(
			rect: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height),
			transform: nil
		)
		pauseTitleLabel.position = CGPoint(x: 0, y: 20)
		pauseHintLabel.position = CGPoint(x: 0, y: -24)
		layoutInventoryOverlay()

		inventoryButton?.position = CGPoint(x: size.width-45, y: size.height-45)
		reloadButton?.position = CGPoint(x: size.width-45, y: size.height-45-60)
		dropButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*2)
		jumpButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*3)
		carButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*4)
		carButton?.isHidden = game.vehicle == nil
	}

	func updateVehicleSpeed(_ speed: CGFloat, vehicleSpeed: CGFloat, force: CGFloat, isVisible: Bool) {
		if wasSpeedVisible != isVisible {
			wasSpeedVisible = isVisible
			speedLabel.isHidden = !isVisible
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

	func showConsoleText(_ text: String) {
		consoleLabel.removeAction(forKey: consoleActionKey)
		consoleLabel.text = text
		consoleLabel.alpha = 1
		consoleLabel.run(
			SKAction.sequence([
				SKAction.wait(forDuration: 4),
				SKAction.fadeOut(withDuration: 0.35)
			]),
			withKey: consoleActionKey
		)
	}

	func updateObjectives(_ objectives: [Int]) {
		objectivesLabel.text = objectives.compactMap { TextDb.get($0) }.joined(separator: "\n")
		objectivesLabel.isHidden = objectives.isEmpty
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

		inventoryOverlay.isHidden = !isVisible
		if isVisible {
			rebuildInventoryRows()
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
		inventoryButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		inventoryButton.isHidden = false
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
		reloadButton.isHidden = false
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
		dropButton.isHidden = false
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
		jumpButton.isHidden = false
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

		carButton = SKShapeNode(ellipseOf: CGSize(width: 50, height: 50))
		carButton.isHidden = game.vehicle == nil
		carButton.position = CGPoint(x: size.width-45, y: size.height-45-60*4)
		carButton.fillColor = SKColor.white
		carButton.strokeColor = SKColor.clear
		addChild(carButton)

		let carButtonLabel = SKLabelNode()
		carButtonLabel.fontName = "Arial"
		carButtonLabel.fontSize = 17
		carButtonLabel.fontColor = SKColor.black
		carButtonLabel.text = "Car"
		carButtonLabel.verticalAlignmentMode = .center
		carButton.addChild(carButtonLabel)
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

		if let node = nodes(at: location).first {
			switch node {
			case actionButton:
				game.lastControl = .ACTION
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
			case carButton, carButton.children[0]:
				game.lastControl = .ACTION
				guard game.vehicle != nil else { break }
				if game.mode == .walk {
					game.mode = .car
				} else {
					game.mode = .walk
				}
			default:
				break
			}
		}
	}

	#elseif os(macOS)

	override func mouseDown(with event: NSEvent) {
		if handleInventorySelection(at: event.location(in: self)) {
			return
		}
		super.mouseDown(with: event)
	}

	override func keyDown(with event: NSEvent) {
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

		case 59, 62: // control
			setCrouching(true)

		case 49: // space
			if game.mode == .walk, game.scene.playerNode != nil {
				game.playerController?.jump()
				game.scene.pressedJump = true
			}

		case 14: // E
			clearWalkingControls()
			guard game.vehicle != nil else { break }
			if game.mode == .walk {
				game.mode = .car
			} else {
				game.mode = .walk
			}

		case 3: // F
			guard let action = game.nearestAction() else { break }
			game.lastControl = .ACTION
			game.performAction(action)

		case 0, 123: // A, left
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingLeft = true
				if crouching {
					game.playDodgeAnimation(direction: .left)
				}
				updateWalkingControls()
			} else if game.mode == .walk {
				game.cameraNode.eulerAngles.y += 0.25
			}

		case 2, 124: // D, right
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingRight = true
				if crouching {
					game.playDodgeAnimation(direction: .right)
				}
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
			case 15, 37: // R, L
				game.releaseControl(.RELOAD)
			case 34: // I
				game.releaseControl(.INVENTORY)
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
		setCrouching(false)
		game.playerController?.stop()
	}

	override func flagsChanged(with event: NSEvent) {
		super.flagsChanged(with: event)

		guard !game.isGamePaused else { return }
		guard game.mode == .walk, game.scene.playerNode != nil else {
			setCrouching(false)
			return
		}

		setCrouching(event.modifierFlags.contains(.control))
	}

	private func setCrouching(_ isCrouching: Bool) {
		guard crouching != isCrouching else { return }

		crouching = isCrouching
		game.setPlayerCrouching(isCrouching)
		guard isCrouching else { return }

		if walkingLeft {
			game.playDodgeAnimation(direction: .left)
		} else if walkingRight {
			game.playDodgeAnimation(direction: .right)
		}
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
