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
	var speedLabel: SKLabelNode!
	private var pauseOverlay: SKShapeNode!
	private var pauseTitleLabel: SKLabelNode!
	private var pauseHintLabel: SKLabelNode!
	private var lastSpeedText: String?
	private var wasSpeedVisible = false

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
		objectivesLabel.horizontalAlignmentMode = .center
		objectivesLabel.verticalAlignmentMode = .center
		addChild(objectivesLabel)

		speedLabel = SKLabelNode()
		speedLabel.fontName = "Arial"
		speedLabel.fontSize = 17
		speedLabel.fontColor = SKColor.white
		speedLabel.horizontalAlignmentMode = .left
		speedLabel.verticalAlignmentMode = .center
		speedLabel.isHidden = true
		addChild(speedLabel)

		renderPauseScreen()

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
				  speedLabel != nil,
				  pauseOverlay != nil else { return }

		compass.position = CGPoint(x: 70, y: size.height-70)
		actionButton.position = CGPoint(x: 45, y: 45)
		objectivesLabel.position = CGPoint(x: size.width/2, y: size.height/2)
		speedLabel.position = CGPoint(x: 24, y: size.height-150)
		pauseOverlay.position = CGPoint(x: size.width/2, y: size.height/2)
		pauseOverlay.path = CGPath(
			rect: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height),
			transform: nil
		)
		pauseTitleLabel.position = CGPoint(x: 0, y: 20)
		pauseHintLabel.position = CGPoint(x: 0, y: -24)

		inventoryButton?.position = CGPoint(x: size.width-45, y: size.height-45)
		reloadButton?.position = CGPoint(x: size.width-45, y: size.height-45-60)
		dropButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*2)
		jumpButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*3)
		carButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*4)
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
		carButton.isHidden = false
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

		if let touch = touches.first, let node = nodes(at: touch.location(in: self)).first {
			switch node {
			case actionButton:
				game.lastControl = .ACTION
				game.actionButtonTapped()
			case inventoryButton, inventoryButton.children[0]:
				game.lastControl = .INVENTORY
				game.openInventory()
			case reloadButton, reloadButton.children[0]:
				game.lastControl = .RELOAD
				if game.mode == .walk {
					if let playerNode = game.scene.playerNode {
						print("pos:", playerNode.presentation.position)
					} else {
						print("pos:", game.cameraContainer.presentation.position)
					}
				} else {
					print("pos:", game.vehicle.node.presentation.position)
				}
			case dropButton, dropButton.children[0]:
				game.lastControl = .WEAPONDROP
				for (i, weapon) in (game.scene.weapons[game.scene.playerNode!] ?? []).enumerated() where weapon.position == .hand {
					print("dropping", weapon.name)
					game.scene.weapons[game.scene.playerNode!]!.remove(at: i)

					let batNode = game.scene.rootNode.childNode(withName: "2bbat", recursively: true)!
					batNode.isHidden = false
//					let weapon = Weapon(id: 4, clipAmmo: -1, restAmmo: -1)
					game.scene.actions.append(.weapon(batNode, weapon))

					break
				}
			case jumpButton, jumpButton.children[0]:
				game.lastControl = .JUMP
				game.playerController?.jump()
				game.scene.pressedJump = true
			case carButton, carButton.children[0]:
				game.lastControl = .ACTION
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

	override func keyDown(with event: NSEvent) {
		if event.keyCode == 53 { // escape
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
		case 49: // space
			if game.mode == .walk, game.scene.playerNode != nil {
				game.playerController?.jump()
				game.scene.pressedJump = true
			}

		case 14: // E
			clearWalkingControls()
			if game.mode == .walk {
				game.mode = .car
			} else {
				game.mode = .walk
			}

		case 0, 123: // A, left
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingLeft = true
				updateWalkingControls()
			} else if game.mode == .walk {
				game.cameraNode.eulerAngles.y += 0.25
			}

		case 2, 124: // D, right
			if game.mode == .walk, game.scene.playerNode != nil {
				walkingRight = true
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
			game.vehicle.resetUpright()
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

		default:
			break
		}
	}

	private func updateVehicleControls() {
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
		game.vehicle.updateControls(throttle: throttle, brake: braking, steering: steering)
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
		game.playerController?.stop()
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
