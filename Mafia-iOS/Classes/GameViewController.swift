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

@MainActor
class GameViewController: UIViewController {

	var gameView: SCNView!

	var gameManager: GameManager?

	var lookGesture: UIPanGestureRecognizer!
	var walkGesture: UIPanGestureRecognizer!
	var fireGesture: UITapGestureRecognizer!
	var siderollLeftSwipeGesture: UISwipeGestureRecognizer!
	var siderollRightSwipeGesture: UISwipeGestureRecognizer!
	private var isTouchDriving = false

	let motionManager = CMMotionManager()
	var accelerometer = CMAcceleration()

    override func viewDidLoad() {
        super.viewDidLoad()

		guard let scnView = view as? SCNView else {
			assertionFailure("GameViewController root view must be an SCNView")
			return
		}
		gameView = scnView
		gameManager = GameManager(view: scnView)

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
		fireGesture = UITapGestureRecognizer(target: self, action: #selector(fireGestureRecognized))
		fireGesture.delegate = self
		fireGesture.cancelsTouchesInView = false
		view.addGestureRecognizer(fireGesture)

		// crouch sideroll gestures
		siderollLeftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(siderollSwipeRecognized))
		siderollLeftSwipeGesture.direction = .left
		siderollLeftSwipeGesture.delegate = self
		siderollLeftSwipeGesture.cancelsTouchesInView = false
		view.addGestureRecognizer(siderollLeftSwipeGesture)

		siderollRightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(siderollSwipeRecognized))
		siderollRightSwipeGesture.direction = .right
		siderollRightSwipeGesture.delegate = self
		siderollRightSwipeGesture.cancelsTouchesInView = false
		view.addGestureRecognizer(siderollRightSwipeGesture)

		// ------

		if motionManager.isAccelerometerAvailable {
			//gameView.preferredFramesPerSecond
			motionManager.accelerometerUpdateInterval = 1/60
				motionManager.startAccelerometerUpdates(to: .main) { data, _ in
					guard self.gameManager?.game?.mode == .car,
						  let vehicle = self.gameManager?.game?.vehicle,
					  let data = data,
					  !self.isTouchDriving else { return }

				self.accelerometer.update(with: data.acceleration)

				if self.accelerometer.x > 0 {
					vehicle.vehicleSteering = CGFloat(self.accelerometer.y*1.3)
				} else {
					vehicle.vehicleSteering = CGFloat(-self.accelerometer.y*1.3)
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

		if let game = gameManager?.game, game.mode == .walk {
			if game.scene.playerNode != nil {
				game.look(
					deltaX: -Float(translation.x) * 0.008,
					deltaY: Float(translation.y) * 0.004
				)
			} else {
				let hAngle = acos(Float(translation.x) / 200) - (.pi / 2)
				game.elevation = max((-.pi/2.5), min(0, game.elevation - vAngle))
				game.cameraContainer.eulerAngles.x = game.elevation
				game.cameraContainer.eulerAngles.y += hAngle
			}
		}

		gesture.setTranslation(.zero, in: view)
	}

	@objc func walkGestureRecognized(gesture: UIPanGestureRecognizer) {
		if gesture.state == .ended || gesture.state == .cancelled {
			gesture.setTranslation(.zero, in: view)
			gameManager?.game?.playerController?.setMovement(x: 0, z: 0)
			if let vehicle = gameManager?.game?.vehicle, gameManager?.game?.mode == .car {
				vehicle.updateControls(throttle: 0, brake: false, steering: 0)
			}
			isTouchDriving = false
			return
		}

		let translation = gesture.translation(in: view)

		/*if gesture.state == .ended || gesture.state == .cancelled {
//			try! stopAnimation(named: "anims/walk1.5ds", in: scene.playerNode!, animationKey: "__walking__")
		} else if gesture.state == .began {
//			try! playAnimation(named: "anims/walk1.5ds", in: scene.playerNode!, repeat: true, animationKey: "__walking__")
		}*/

		if gameManager?.game?.mode == .walk {
			let inputX = max(-1, min(1, Float(translation.x) / 50))
			let inputZ = max(-1, min(1, Float(-translation.y) / 50))
			gameManager?.game?.playerController?.setMovement(x: inputX, z: inputZ)
		} else if gameManager?.game?.mode == .car, let vehicle = gameManager?.game?.vehicle {
			isTouchDriving = true
			let steering = max(-1, min(1, CGFloat(translation.x) / 50))
			let throttleInput = max(-1, min(1, CGFloat(-translation.y) / 50))
			let throttle = throttleInput >= 0 ? throttleInput : throttleInput * 0.55
			vehicle.updateControls(throttle: throttle, brake: false, steering: steering)
		}
	}

	@objc func fireGestureRecognized(gesture: UITapGestureRecognizer) {
		gameManager?.game?.playerDidFire()
		gameManager?.game?.releaseControl(.FIRE)
	}

	@objc func siderollSwipeRecognized(gesture: UISwipeGestureRecognizer) {
		let direction = gesture.direction == .left ? -1 : 1
		gameManager?.game?.hud?.registerCrouchSiderollSwipe(direction: direction)
	}

}

extension GameViewController: UIGestureRecognizerDelegate {

	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldReceive touch: UITouch) -> Bool {
		guard gameManager?.game != nil else { return false }

		if let hud = gameManager?.game?.hud,
		   hud.handlesTouchControl(at: touch.location(in: hud)) {
			return false
		}

		if gestureRecognizer == lookGesture {
			return touch.location(in: view).x > view.frame.size.width / 2
		} else if gestureRecognizer == walkGesture {
			return touch.location(in: view).x < view.frame.size.width / 2
		} else if gestureRecognizer == siderollLeftSwipeGesture || gestureRecognizer == siderollRightSwipeGesture {
			return touch.location(in: view).x < view.frame.size.width / 2
		}
		return true
	}

	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}

}
