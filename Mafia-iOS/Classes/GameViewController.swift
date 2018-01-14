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

class GameViewController: UIViewController {
	
	var game: Game!
	var hud: HudScene!
	
	var lookGesture: UIPanGestureRecognizer!
	var walkGesture: UIPanGestureRecognizer!
	var fireGesture: UITapGestureRecognizer!
	
	let motionManager = CMMotionManager()
	var accelerometer = CMAcceleration()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		try! TextDb.load()
		
		// ------
		
		let gameView = view as! SCNView
		gameView.delegate = self
		
		// ------
		
		game = Game(vc: self)
		game.setup(in: gameView)
		
		hud = HudScene(size: gameView.bounds.size, game: game)
		hud.setup(in: gameView)
		
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
//		fireGesture = UITapGestureRecognizer(target: self, action: #selector(fireGestureRecognized))
//		fireGesture.delegate = self
//		view.addGestureRecognizer(fireGesture)
		
		// ------
		
		if motionManager.isAccelerometerAvailable {
			//gameView.preferredFramesPerSecond
			motionManager.accelerometerUpdateInterval = 1/60
			motionManager.startAccelerometerUpdates(to: .main) { data, error in
				guard let data = data else { return }
				
				self.accelerometer.update(with: data.acceleration)
				
				if self.accelerometer.x > 0 {
					self.game.vehicle.vehicleSteering = CGFloat(self.accelerometer.y*1.3)
				} else {
					self.game.vehicle.vehicleSteering = CGFloat(-self.accelerometer.y*1.3)
				}
			}
		}
		
		// ------
		
		game.play(in: gameView)
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

		if game.mode == .walk {
			if let playerNode = game.scene.playerNode {
//				let hAngle = acos(Float(translation.x) / 5) - (.pi / 2)
//				scene.playerNode!.eulerAngles.y += hAngle
//				scene.playerNode!.position.y += vAngle
				playerNode.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: Float(translation.x)), asImpulse: true)
			} else {
				let hAngle = acos(Float(translation.x) / 500 * 80) - (.pi / 2)
				game.elevation = max((-.pi/2.5), min(0, game.elevation - vAngle))
				game.cameraContainer.eulerAngles.x = game.elevation
				game.cameraContainer.eulerAngles.y += hAngle
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
		game.vehicle.force = CGFloat(impulse.z) * 3000
	}
	
	func fireGestureRecognized(gesture: UITapGestureRecognizer) {
		print("== fireGestureRecognized ==")
		game.scene.pressedJump = true
	}
	
}

extension GameViewController: SCNSceneRendererDelegate {
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		let translation = walkGesture.translation(in: view)
		
		if game.mode == .walk {
			if let playerNode = game.scene.playerNode {
				let angle = playerNode.presentation.rotation.y * playerNode.presentation.rotation.w - .pi
//				let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 5000)), y: 0, z: max(-1, min(1, Float(-translation.y) / 5000)))
//				scene.playerNode!.position.x -= impulse.x * cos(angle) - impulse.z * sin(angle)
//				scene.playerNode!.position.z += impulse.x * -sin(angle) - impulse.z * cos(angle)
				var impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 50)), y: 0, z: max(-1, min(1, Float(-translation.y) / 50)))
				impulse = SCNVector3(
					x: (impulse.x * cos(angle) - impulse.z * sin(angle))*80,
					y: 0,
					z: (impulse.x * -sin(angle) - impulse.z * cos(angle))*80
				)
				playerNode.physicsBody?.applyForce(impulse, asImpulse: true)
			} else {
				let angle = game.cameraContainer.presentation.eulerAngles.y
				let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 500)), y: 0, z: max(-1, min(1, Float(-translation.y) / 500)))
				game.cameraContainer.position.x -= impulse.x * cos(angle) - impulse.z * sin(angle)
				game.cameraContainer.position.z += impulse.x * -sin(angle) - impulse.z * cos(angle)
			}
		} else {
			game.vehicle.applyForces()
		}
		
		if let node = game.scene.compassNode {
			let p1 = node.presentation.worldPosition
			let p2 = game.scene.playerNode!.presentation.worldPosition
			hud.compass.isHidden = false
			let playerAngle: SCNFloat
			if game.mode == .walk {
				playerAngle = game.scene.playerNode!.presentation.rotation.y * game.scene.playerNode!.presentation.rotation.w - .pi
			} else {
				playerAngle = game.vehicle.node.presentation.rotation.y * game.vehicle.node.presentation.rotation.w - .pi/2
			}
			hud.compassNeedle.zRotation = CGFloat(atan2(p2.z - p1.z, p2.x - p1.x) + playerAngle)
		} else {
			hud.compass.isHidden = true
		}

		hud.actionButton.isHidden = game.scene.actions.filter({ $0.node.distance(to: game.scene.playerNode!) < 2 }).isEmpty
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
		//hud.objectivesLabel.text = game.scene.objectives.map({ TextDb.get($0)! }).joined(separator: "\n")
	}
	
}
