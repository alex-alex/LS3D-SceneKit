//
//  GameViewController.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/13/16.
//  Copyright (c) 2016 Alex Studnicka. All rights reserved.
//

import SceneKit
import SpriteKit
import QuartzCore

enum GameMode {
	case walk, car
}

let carNodeName = "taxi2" // cad_road

class GameViewController: NSViewController, SCNSceneRendererDelegate {
    
    @IBOutlet weak var gameView: SCNView!
	
	let mainScene = SCNScene()
	let cameraNode = SCNNode()
	
	var mode: GameMode = .walk {
		didSet {
			cameraNode.removeFromParentNode()
			if mode == .walk {
				scene.playerNode!.addChildNode(cameraNode)
			} else {
				let taxiNodeX = scene.rootNode.childNode(withName: carNodeName, recursively: true)!
				let taxiNode = taxiNodeX.childNode(withName: "BODY", recursively: false)!
				taxiNode.addChildNode(cameraNode)
			}
		}
	}
	var scene: Scene!
	
	var vehicle: Vehicle!
    
    override func awakeFromNib() {
        super.awakeFromNib()
		
		try! TextDb.load()
		
		let node1 = try! loadModel(named: "missions/tutorial/scene")
		//node1.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
//		node1.opacity = 0
		mainScene.rootNode.addChildNode(node1)
		
		scene = try! loadScene(named: "missions/tutorial")
//		scene.rootNode.opacity = 0
		mainScene.rootNode.addChildNode(scene.rootNode)
		
		//let sceneCache = try! SceneCache(name: "missions/freeride")
		//scene.rootNode.addChildNode(sceneCache.node)
		
		let node4 = try! loadTreeKlz(named: "missions/tutorial", rootNode: mainScene.rootNode)
		mainScene.rootNode.addChildNode(node4)
		
//		let floorNode = SCNNode()
//		floorNode.opacity = 0
//		floorNode.geometry = SCNFloor()
//		floorNode.physicsBody = SCNPhysicsBody.static()
//		mainScene.rootNode.addChildNode(floorNode)
		
//		let playerBase = playerNode.childNode(withName: "base", recursively: true)
//		print("playerBase.morpher:", playerBase?.morpher?.targets.count)
//		playerBase?.geometry = playerBase?.morpher?.targets[2]
//		playerBase?.morpher?.setWeight(1, forTargetAt: 1)
		
//		scene!.playerNode = scene!.playerNode!.childNode(withName: "base", recursively: false)!
		
//		try! playAnimation(named: "anims/walk1.5ds", in: scene.playerNode!, repeat: true)
//		scene.playerNode?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
		
		let camera = SCNCamera()
		camera.zFar = 1000
		
		cameraNode.camera = camera
		//cameraNode.position = SCNVector3(x: 0, y: 2.2*2, z: -1.5*4)
		cameraNode.position = SCNVector3(x: 0, y: 2.2, z: -1.5)
		cameraNode.scale = SCNVector3(x: 1, y: -1, z: 1)
		cameraNode.eulerAngles = SCNVector3(x: 0.15, y: .pi, z: .pi)
		if let playerNode = scene?.playerNode {
			playerNode.addChildNode(cameraNode)
			//playerNode.position = SCNVector3(x: 24.9499206542969, y: 0.174427032470703, z: -23.9080371856689)
			//playerNode.eulerAngles = SCNVector3(x: 3.14159250259399, y: 0.162268161773682, z: 3.14159250259399)
		} else {
			mainScene.rootNode.addChildNode(cameraNode)
		}
		
		gameView.delegate = self
        gameView.scene = mainScene
		gameView.rendersContinuously = true
//		gameView.preferredFramesPerSecond = 30
		gameView.antialiasingMode = .none
		gameView.allowsCameraControl = false
//		gameView.autoenablesDefaultLighting = true
        gameView.showsStatistics = true
        gameView.backgroundColor = .darkGray
		gameView.pointOfView = cameraNode
		if let playerNode = scene?.playerNode {
			gameView.audioListener = playerNode
		}
		
		// --------------------
		
		let carNode = scene.rootNode.childNode(withName: carNodeName, recursively: true)!
		vehicle = Vehicle(scene: mainScene, node: carNode)
		
		// --------------------
		
//		let playerShape = SCNPhysicsShape(node: scene!.playerNode!, options: [
//			SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.boundingBox,
//			SCNPhysicsShape.Option.keepAsCompound: false
//		])
//		scene!.playerNode!.physicsBody = SCNPhysicsBody(type: .dynamic, shape: playerShape)
//		//scene!.playerNode!.physicsBody?.isAffectedByGravity = false
//		scene!.playerNode!.physicsBody?.angularDamping = 0.9
//		scene!.playerNode!.physicsBody?.damping = 0.9
//		scene!.playerNode!.physicsBody?.rollingFriction = 0
//		scene!.playerNode!.physicsBody?.friction = 0
//		scene!.playerNode!.physicsBody?.restitution = 0
//		//scene!.playerNode!.physicsBody?.velocityFactor = SCNVector3(x: 1, y: 0, z: 1)
		
		/*let overlayScene = SKScene(size: gameView.bounds.size)
		let compass = SKShapeNode(ellipseOf: CGSize(width: 100, height: 100))
		compass.fillColor = SKColor.white
		compass.strokeColor = SKColor.clear
		overlayScene.addChild(compass)
		overlayScene.scaleMode = .resizeFill
		overlayScene.isHidden = false
		overlayScene.isUserInteractionEnabled = false
		gameView.overlaySKScene = overlayScene*/
		
		gameView.play(nil)
    }
	
	var ride = false
	var reverse = false
	var vehicleSteering: CGFloat = 0
	
	override func keyDown(with event: NSEvent) {
		let playerNode = scene?.playerNode ?? cameraNode
		
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
			if mode == .walk {
				print("playerNode.position =", playerNode.position)
				print("playerNode.eulerAngles =", playerNode.eulerAngles)
				scene.pressedJump = true
			} else {
				let taxiNodeX = scene.rootNode.childNode(withName: carNodeName, recursively: true)!
				let taxiNode = taxiNodeX.childNode(withName: "BODY", recursively: false)!
				print("taxiNode.position =", taxiNode.position)
				reverse = !reverse
			}
			
		case 14: // E
			//scene.pressedJump = true
			if mode == .walk {
				mode = .car
			} else {
				mode = .walk
			}
			
		case 123: // left
			if mode == .walk {
				playerNode.eulerAngles.y += 0.25
//				playerNode.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: -0.5), asImpulse: true)
			} else if mode == .car {
				vehicleSteering -= 0.05
			}

		case 124: // right
			if mode == .walk {
				playerNode.eulerAngles.y -= 0.25
//				playerNode.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: 0.5), asImpulse: true)
			} else if mode == .car {
				vehicleSteering += 0.05
			}
			
		case 125: // down
			if mode == .walk {
				let angle = playerNode.presentation.eulerAngles.y
				playerNode.position.x -= 0.5 * sin(angle)
				playerNode.position.z += 0.5 * cos(angle)
				
//				playerNode.physicsBody?.applyForce(SCNVector3(
//					x: 2 * -sin(angle),
//					y: 0,
//					z: 2 * cos(angle)
//				), asImpulse: true)
			} else if mode == .car {
				ride = false
			}
			
		case 126: // up
			if mode == .walk {
				let angle = playerNode.presentation.eulerAngles.y
				playerNode.position.x += 2 * sin(angle)
				playerNode.position.z -= 2 * cos(angle)
				
//				playerNode.physicsBody?.applyForce(SCNVector3(
//					x: 2 * sin(angle),
//					y: 0,
//					z: 2 * -cos(angle)
//				), asImpulse: true)
			} else if mode == .car {
				ride = true
			}
			
		default:
			super.keyDown(with: event)
		}
		
		SCNTransaction.commit()
	}
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		guard let vehicle = vehicle?.physicsVehicle else { return }
		
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
