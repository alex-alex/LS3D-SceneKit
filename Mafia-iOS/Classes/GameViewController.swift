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
	
	var gameView: SCNView!
	
	var game: Game!
	
	var lookGesture: UIPanGestureRecognizer!
	var walkGesture: UIPanGestureRecognizer!
	var fireGesture: UITapGestureRecognizer!
	
	let motionManager = CMMotionManager()
	var accelerometer = CMAcceleration()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		gameView = view as! SCNView
		
		try! TextDb.load()
		
		game = Game(vc: self)
		game.setup()
		game.play()
		
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
				guard self.game.mode == .car, let data = data else { return }
				
				self.accelerometer.update(with: data.acceleration)
				
				if self.accelerometer.x > 0 {
					self.game.vehicle.vehicleSteering = CGFloat(self.accelerometer.y*1.3)
				} else {
					self.game.vehicle.vehicleSteering = CGFloat(-self.accelerometer.y*1.3)
				}
			}
		}
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
	
	@objc func lookGestureRecognized(gesture: UIPanGestureRecognizer) {
		let translation = gesture.translation(in: view)
		let vAngle = acos(Float(translation.y) / 200) - (.pi / 2)

		if game.mode == .walk {
			if let playerNode = game.scene.playerNode {
//				let hAngle = acos(Float(translation.x) / 5) - (.pi / 2)
//				scene.playerNode!.eulerAngles.y += hAngle
//				scene.playerNode!.position.y += vAngle
				playerNode.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: Float(translation.x)), asImpulse: true)
			} else {
				let hAngle = acos(Float(translation.x) / 200) - (.pi / 2)
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
	
	@objc func walkGestureRecognized(gesture: UIPanGestureRecognizer) {
		if gesture.state == .ended || gesture.state == .cancelled {
			gesture.setTranslation(.zero, in: view)
		}
		
		let translation = gesture.translation(in: view)
		
		/*if gesture.state == .ended || gesture.state == .cancelled {
//			try! stopAnimation(named: "anims/walk1.5ds", in: scene.playerNode!, animationKey: "__walking__")
		} else if gesture.state == .began {
//			try! playAnimation(named: "anims/walk1.5ds", in: scene.playerNode!, repeat: true, animationKey: "__walking__")
		}*/
		
		if game.mode == .car {
			let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 50)), y: 0, z: max(-1, min(1, Float(-translation.y) / 50)))
			game.vehicle.force = CGFloat(impulse.z) * 3000
		}
	}
	
	@objc func fireGestureRecognized(gesture: UITapGestureRecognizer) {
		print("== fireGestureRecognized ==")
		game.scene.pressedJump = true
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
