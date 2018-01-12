//
//  GameViewController.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/13/16.
//  Copyright (c) 2016 Alex Studnicka. All rights reserved.
//

import AppKit
import QuartzCore
import SceneKit
import SpriteKit

class GameViewController: NSViewController, SCNSceneRendererDelegate {
    
    @IBOutlet weak var gameView: SCNView!
	
	var game: Game!
	
	var ride = false
	var reverse = false
	var vehicleSteering: CGFloat = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
	
	
    }
	
	override func keyDown(with event: NSEvent) {
		let playerNode = game.scene.playerNode ?? game.cameraNode
		
		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0.2
		
		switch event.keyCode {
		case 0: // A
			playerNode.position.y += 0.25
			
//			let force = SCNVector3(x: 0, y: 2 , z: 0)
//			let position = SCNVector3(x: 0.05, y: 0.05, z: 0.05)
//			playerNode.physicsBody?.applyForce(force, atPosition: position, impulse: true)
			
		case 6: // Z
			playerNode.position.y -= 0.25
			
		case 13: // W
			if game.mode == .walk {
				print("playerNode.position =", playerNode.position)
				print("playerNode.eulerAngles =", playerNode.eulerAngles)
				game.scene.pressedJump = true
			} else {
				let taxiNodeX = game.scene.rootNode.childNode(withName: carNodeName, recursively: true)!
				let taxiNode = taxiNodeX.childNode(withName: "BODY", recursively: false)!
				print("taxiNode.position =", taxiNode.position)
				reverse = !reverse
			}
			
		case 14: // E
			//scene.pressedJump = true
			if game.mode == .walk {
				game.mode = .car
			} else {
				game.mode = .walk
			}
			
		case 123: // left
			if game.mode == .walk {
				playerNode.eulerAngles.y += 0.25
//				playerNode.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: -0.5), asImpulse: true)
			} else if game.mode == .car {
				vehicleSteering -= 0.05
			}

		case 124: // right
			if game.mode == .walk {
				playerNode.eulerAngles.y -= 0.25
//				playerNode.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: 0.5), asImpulse: true)
			} else if game.mode == .car {
				vehicleSteering += 0.05
			}
			
		case 125: // down
			if game.mode == .walk {
				let angle = playerNode.presentation.eulerAngles.y
				playerNode.position.x -= 0.5 * sin(angle)
				playerNode.position.z += 0.5 * cos(angle)
				
//				playerNode.physicsBody?.applyForce(SCNVector3(
//					x: 2 * -sin(angle),
//					y: 0,
//					z: 2 * cos(angle)
//				), asImpulse: true)
			} else if game.mode == .car {
				ride = false
			}
			
		case 126: // up
			if game.mode == .walk {
				let angle = playerNode.presentation.eulerAngles.y
				playerNode.position.x += 2 * sin(angle)
				playerNode.position.z -= 2 * cos(angle)
				
//				playerNode.physicsBody?.applyForce(SCNVector3(
//					x: 2 * sin(angle),
//					y: 0,
//					z: 2 * -cos(angle)
//				), asImpulse: true)
			} else if game.mode == .car {
				ride = true
			}
			
		default:
			super.keyDown(with: event)
		}
		
		SCNTransaction.commit()
	}
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		guard let vehicle = game.vehicle?.physicsVehicle else { return }
		
		vehicle.setSteeringAngle(vehicleSteering, forWheelAt: 0)
		vehicle.setSteeringAngle(vehicleSteering, forWheelAt: 1)
		
		if ride {
			vehicle.applyBrakingForce(0, forWheelAt: 2)
			vehicle.applyBrakingForce(0, forWheelAt: 3)
			if !reverse {
				vehicle.applyEngineForce(1000, forWheelAt: 2)
				vehicle.applyEngineForce(1000, forWheelAt: 3)
			} else {
				vehicle.applyEngineForce(-1000, forWheelAt: 2)
				vehicle.applyEngineForce(-1000, forWheelAt: 3)
			}
		} else {
			vehicle.applyEngineForce(0, forWheelAt: 2)
			vehicle.applyEngineForce(0, forWheelAt: 3)
			vehicle.applyBrakingForce(1000, forWheelAt: 2)
			vehicle.applyBrakingForce(1000, forWheelAt: 3)
		}
	}

}
