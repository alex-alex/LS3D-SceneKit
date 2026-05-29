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

	#if os(macOS)

	var ride = false
	var reverse = false
	var vehicleSteering: CGFloat = 0
	private var accelerating = false
	private var reversing = false
	private var braking = false
	private var steeringLeft = false
	private var steeringRight = false

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
		guard compass != nil, actionButton != nil, objectivesLabel != nil, speedLabel != nil else { return }

		compass.position = CGPoint(x: 70, y: size.height-70)
		actionButton.position = CGPoint(x: 45, y: 45)
		objectivesLabel.position = CGPoint(x: size.width/2, y: size.height/2)
		speedLabel.position = CGPoint(x: 24, y: size.height-150)

		inventoryButton?.position = CGPoint(x: size.width-45, y: size.height-45)
		reloadButton?.position = CGPoint(x: size.width-45, y: size.height-45-60)
		dropButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*2)
		jumpButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*3)
		carButton?.position = CGPoint(x: size.width-45, y: size.height-45-60*4)
	}

	func updateVehicleSpeed(_ speed: CGFloat, vehicleSpeed: CGFloat, force: CGFloat, isVisible: Bool) {
		speedLabel.isHidden = !isVisible
		let bodySpeed = Int(speed.rounded())
		let wheelSpeed = Int(vehicleSpeed.rounded())
		let engineForce = Int(force.rounded())
		speedLabel.text = "Body \(bodySpeed)  Vehicle \(wheelSpeed)  Force \(engineForce)"
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
				game.scene.playerNode?.physicsBody?.applyForce(SCNVector3(
					x: 0,
					y: 1000,
					z: 0
				), asImpulse: true)
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
		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0.2

		if game.mode == .car && handleVehicleKeyDown(event.keyCode) {
			SCNTransaction.commit()
			return
		}

		switch event.keyCode {
		case 0: // A
			if let playerNode = game.scene.playerNode {
				playerNode.physicsBody?.applyForce(SCNVector3(
					x: 0,
					y: 4*80,
					z: 0
				), asImpulse: true)
			} else {
				game.cameraNode.position.y += 0.25
			}

		case 6: // Z
			if game.scene.playerNode == nil {
				game.cameraNode.position.y -= 0.25
			}

		case 13: // W
			if game.scene.playerNode != nil {
				game.scene.pressedJump = true
			}

		case 14: // E
			if game.mode == .walk {
				game.mode = .car
			} else {
				game.mode = .walk
			}

		case 123: // left
			if game.mode == .walk {
				if let playerNode = game.scene.playerNode {
					playerNode.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: -10), asImpulse: true)
				} else {
					game.cameraNode.eulerAngles.y += 0.25
				}
			}

		case 124: // right
			if game.mode == .walk {
				if let playerNode = game.scene.playerNode {
					playerNode.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: 10), asImpulse: true)
				} else {
					game.cameraNode.eulerAngles.y -= 0.25
				}
			}

		case 125: // down
			if game.mode == .walk {
				if let playerNode = game.scene.playerNode {
					let angle = playerNode.presentation.rotation.y * playerNode.presentation.rotation.w - .pi
					playerNode.physicsBody?.applyForce(SCNVector3(
						x: 4*80 * sin(angle),
						y: 0,
						z: 4*80 * cos(angle)
					), asImpulse: true)
				} else {
					let angle = game.cameraNode.presentation.rotation.y * game.cameraNode.presentation.rotation.w - .pi
					game.cameraNode.position.x += 0.5 * sin(angle)
					game.cameraNode.position.z += 0.5 * cos(angle)
				}
			}

		case 126: // up
			if game.mode == .walk {
				if let playerNode = game.scene.playerNode {
					let angle = playerNode.presentation.rotation.y * playerNode.presentation.rotation.w - .pi
					playerNode.physicsBody?.applyForce(SCNVector3(
						x: 4*80 * -sin(angle),
						y: 0,
						z: 4*80 * -cos(angle)
					), asImpulse: true)
				} else {
					let angle = game.cameraNode.presentation.rotation.y * game.cameraNode.presentation.rotation.w - .pi
					game.cameraNode.position.x -= 2 * sin(angle)
					game.cameraNode.position.z -= 2 * cos(angle)
				}
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

	override func keyUp(with event: NSEvent) {
		super.keyUp(with: event)

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

	#endif

}
