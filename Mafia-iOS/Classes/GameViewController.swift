//
//  GameViewController.swift
//  Mafia-iOS
//
//  Created by Alex Studnicka on 8/19/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import SpriteKit
import CoreMotion

let carNodeName = "taxi2" // cad_road

class GameViewController: UIViewController {
	
	let motionManager = CMMotionManager()
	var accelerometer: [UIAccelerationValue] = [0, 0, 0]
	
	let mainScene = SCNScene()
	let cameraContainer = SCNNode()
	let cameraNode = SCNNode()
	
	var hud: HudScene!
	
	var vehicle: Vehicle!
	
	var lookGesture: UIPanGestureRecognizer!
	var walkGesture: UIPanGestureRecognizer!
	var fireGesture: FireGestureRecognizer!
	
	var lastControl: Control? = nil
	
	var mode: Game.Mode = .walk {
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
	
	var game: Game!
	var scene: Scene!
	
	var elevation: Float = 0
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		try! TextDb.load()
		
		let node1 = try! loadModel(named: "missions/tutorial/scene")
		mainScene.rootNode.addChildNode(node1)
		
		scene = try! loadScene(named: "missions/tutorial")
		scene.delegate = self
		mainScene.rootNode.addChildNode(scene.rootNode)
		
//		let node3 = try! loadCacheBin(named: "missions/freeitaly")
//		scene.rootNode.addChildNode(node3)
		
		let collisions = try! Collisions(name: "missions/tutorial", scene: mainScene)
		mainScene.rootNode.addChildNode(collisions.node)
		
		game = Game(gameScene: scene, scnScene: mainScene)
		game.vc = self
		
		let camera = SCNCamera()
		camera.zFar = 1000
		
		cameraNode.camera = camera
		cameraNode.scale = SCNVector3(x: 1, y: -1, z: 1)
		
		if true {
			cameraNode.position = SCNVector3(x: 0, y: 2.2*2, z: -1.5*4)
			cameraNode.eulerAngles = SCNVector3(x: 0.15, y: .pi, z: .pi)
			elevation = 0
		} else {
			cameraNode.position = SCNVector3(x: 0, y: 1, z: 0)
			cameraNode.eulerAngles = SCNVector3(x: .pi/2, y: .pi, z: .pi)
			cameraContainer.position = SCNVector3(x: 0, y: 2, z: 0)
			elevation = -.pi/2.5
		}
		
		cameraContainer.eulerAngles.x = elevation
		cameraContainer.addChildNode(cameraNode)
		
		if let playerNode = scene.playerNode {
			scene.playerNode!.addChildNode(cameraContainer)
		} else {
			scene.rootNode.addChildNode(cameraContainer)
		}
		
		let gameView = view as! SCNView
		gameView.delegate = self
		gameView.rendersContinuously = true
		gameView.scene = mainScene
		gameView.antialiasingMode = .none
		gameView.allowsCameraControl = false
		gameView.autoenablesDefaultLighting = false
		gameView.showsStatistics = true
		//gameView.debugOptions = [.showPhysicsShapes]
		gameView.backgroundColor = .darkGray
		gameView.pointOfView = cameraNode
		if let playerNode = scene.playerNode {
			gameView.audioListener = playerNode
		} else {
			gameView.audioListener = cameraContainer
		}
		
		// -----------
		
		let carNode = scene.rootNode.childNode(withName: carNodeName, recursively: true)!
		vehicle = Vehicle(scene: mainScene, node: carNode)
		
		mode = .car
		
		// -----------
		
		if let playerNode = scene?.playerNode {
			let cylinderNode = SCNNode()
			cylinderNode.geometry = SCNCylinder(radius: 0.25, height: 1.5)
			cylinderNode.geometry?.firstMaterial = SCNMaterial()
			cylinderNode.geometry?.firstMaterial?.cullMode = .front
			cylinderNode.geometry?.firstMaterial?.diffuse.contents = SKColor.red
			cylinderNode.position = SCNVector3(0, 1, 0)
			playerNode.addChildNode(cylinderNode)
			
			let cylinderShape = SCNPhysicsShape(geometry: SCNCylinder(radius: 0.25, height: 1.5), options: nil)
			let playerPhysicsShape = SCNPhysicsShape(shapes: [cylinderShape], transforms: [NSValue(scnMatrix4: SCNMatrix4MakeTranslation(0, 1, 0))])
			playerNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: playerPhysicsShape)
			playerNode.physicsBody?.allowsResting = false
			playerNode.physicsBody?.mass = 80
			playerNode.physicsBody?.angularDamping = 0.999
			playerNode.physicsBody?.damping = 0.999
			playerNode.physicsBody?.rollingFriction = 0
			playerNode.physicsBody?.friction = 0
			playerNode.physicsBody?.restitution = 0
			
			playerNode.position.y += 0.5
		}
		
		// ------
		
		hud = HudScene(size: gameView.bounds.size, game: game)
		gameView.overlaySKScene = hud
		
		// ------
		
		// look gesture
		lookGesture = UIPanGestureRecognizer(target: self, action: #selector(lookGestureRecognized))
		lookGesture.delegate = self
		gameView.addGestureRecognizer(lookGesture)

		// walk gesture
		walkGesture = UIPanGestureRecognizer(target: self, action: #selector(walkGestureRecognized))
		walkGesture.delegate = self
		gameView.addGestureRecognizer(walkGesture)

		// fire gesture
		fireGesture = FireGestureRecognizer(target: self, action: #selector(fireGestureRecognized))
		fireGesture.delegate = self
		view.addGestureRecognizer(fireGesture)
		
		// ------
		
		if motionManager.isAccelerometerAvailable {
			motionManager.accelerometerUpdateInterval = 1/60
			motionManager.startAccelerometerUpdates(to: .main) { data, error in
				guard let data = data else { return }
				
				let kFilteringFactor = 0.5
				
				self.accelerometer[0] = data.acceleration.x * kFilteringFactor + self.accelerometer[0] * (1.0 - kFilteringFactor)
				self.accelerometer[1] = data.acceleration.y * kFilteringFactor + self.accelerometer[1] * (1.0 - kFilteringFactor)
				self.accelerometer[2] = data.acceleration.z * kFilteringFactor + self.accelerometer[2] * (1.0 - kFilteringFactor)
				
				if self.accelerometer[0] > 0 {
					self.vehicle.vehicleSteering = CGFloat(self.accelerometer[1]*1.3)
				} else {
					self.vehicle.vehicleSteering = CGFloat(-self.accelerometer[1]*1.3)
				}
			}
		}
		
		// ------
		
		gameView.play(nil)
	}
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

}

extension GameViewController {
	
	func lookGestureRecognized(gesture: UIPanGestureRecognizer) {
		let translation = gesture.translation(in: view)
		let vAngle = acos(Float(translation.y) / 200) - (.pi / 2)

		if mode == .walk {
			let hAngle = acos(Float(translation.x) / 500 * 80) - (.pi / 2)
			if let playerNode = scene.playerNode {
//				scene.playerNode!.eulerAngles.y += hAngle
//				scene.playerNode!.position.y += vAngle
				//scene.playerNode!.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: hAngle), asImpulse: true)
			} else {
				elevation = max((-.pi/2.5), min(0, elevation - vAngle))
				cameraContainer.eulerAngles.x = elevation
				cameraContainer.eulerAngles.y += hAngle
			}
		} else {
			/*let hAngle = acos(Float(translation.x) / 200) - (.pi / 2)
			
			vehicleSteering -= CGFloat(hAngle)
			if vehicleSteering < -0.6 {
				vehicleSteering = -0.6
			}
			if vehicleSteering > 0.6 {
				vehicleSteering = 0.6
			}*/
		}

		gesture.setTranslation(.zero, in: view)
	}
	
	func walkGestureRecognized(gesture: UIPanGestureRecognizer) {
		if gesture.state == .ended || gesture.state == .cancelled {
			gesture.setTranslation(.zero, in: view)
		}
		
		let translation = gesture.translation(in: view)
		
		/*if gesture.state == .ended || gesture.state == .cancelled {
//			try! stopAnimation(named: "anims/walk1.5ds", in: scene.playerNode!, animationKey: "__walking__")
		} else if gesture.state == .began {
//			try! playAnimation(named: "anims/walk1.5ds", in: scene.playerNode!, repeat: true, animationKey: "__walking__")
		}*/
		
		let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 50)), y: 0, z: max(-1, min(1, Float(-translation.y) / 50)))
		vehicle.force = CGFloat(impulse.z) * 3000
	}
	
	func fireGestureRecognized(gesture: FireGestureRecognizer) {
		print("== fireGestureRecognized ==")
		scene.pressedJump = true
		
		/*let taxiNodeX = scene.rootNode.childNode(withName: carNodeName, recursively: true)!
		let taxiNode = taxiNodeX.childNode(withName: "BODY", recursively: false)!
		print("taxiNode.position =", taxiNode.presentation.position)*/
	}
	
}

extension GameViewController: SCNSceneRendererDelegate {
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		let translation = walkGesture.translation(in: view)
		
		if mode == .walk {
			if let playerNode = scene.playerNode {
				let angle = playerNode.presentation.eulerAngles.y
//				let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 5000)), y: 0, z: max(-1, min(1, Float(-translation.y) / 5000)))
//				scene.playerNode!.position.x -= impulse.x * cos(angle) - impulse.z * sin(angle)
//				scene.playerNode!.position.z += impulse.x * -sin(angle) - impulse.z * cos(angle)
				var impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 500)), y: 0, z: max(-1, min(1, Float(-translation.y) / 500)))
				impulse = SCNVector3(
					x: (impulse.x * cos(angle) - impulse.z * sin(angle))*80,
					y: 0,
					z: (impulse.x * -sin(angle) - impulse.z * cos(angle))*80
				)
				playerNode.physicsBody?.applyForce(impulse, asImpulse: true)
			} else {
				let angle = cameraContainer.presentation.eulerAngles.y
				let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 500)), y: 0, z: max(-1, min(1, Float(-translation.y) / 500)))
				cameraContainer.position.x -= impulse.x * cos(angle) - impulse.z * sin(angle)
				cameraContainer.position.z += impulse.x * -sin(angle) - impulse.z * cos(angle)
			}
		} else {
			vehicle.applyForces()
		}
		
		if let node = scene.compassNode {
			let p1 = node.presentation.worldPosition
			let p2 = scene.playerNode!.presentation.worldPosition
			hud.compass.isHidden = false
			hud.compassNeedle.zRotation = CGFloat(atan2(p2.z - p1.z, p2.x - p1.x) - scene.playerNode!.eulerAngles.y)
		} else {
			hud.compass.isHidden = true
		}

		hud.actionButton.isHidden = scene.actions.filter({ $0.node.distance(to: scene.playerNode!) < 2 }).isEmpty
	}
	
}

extension GameViewController: UIGestureRecognizerDelegate {
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		if gestureRecognizer == lookGesture {
			return touch.location(in: view).x > view.frame.size.width / 2
		} else if gestureRecognizer == walkGesture {
			return touch.location(in: view).x < view.frame.size.width / 2
		}
		return true
	}
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
	
}

extension GameViewController {
	
	func objectivesChanged() {
		hud.objectivesLabel.text = scene.objectives.map({ TextDb.get($0)! }).joined(separator: "\n")
	}
	
}
