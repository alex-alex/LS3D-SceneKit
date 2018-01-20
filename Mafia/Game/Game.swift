//
//  Game.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

final class Game: NSObject {
	
	enum Mode {
		case walk, car
	}
	
	var hud: HudScene!
	
	let scnScene = SCNScene()
	let cameraContainer = SCNNode()
	let cameraNode = SCNNode()
	
	var mode: Mode = .car {
		didSet {
			cameraContainer.removeFromParentNode()
			if mode == .walk {
				scene.playerNode!.addChildNode(cameraContainer)
			} else {
				vehicle.node.addChildNode(cameraContainer)
			}
		}
	}
	
	let scene: Scene
	
	var vehicle: Vehicle!
	var elevation: SCNFloat = 0
	var lastControl: Control? = nil
	
	init(missionName: String) {
		scnScene.rootNode.name = "__root__"
		
		let sceneModel = try! loadModel(named: "missions/\(missionName)/scene")
		sceneModel.name = "__model__"
		scnScene.rootNode.addChildNode(sceneModel)
		print("== Loaded Scene Model")
		
		scene = try! loadScene(named: "missions/"+missionName)
		
		super.init()
		
		scene.game = self
		scene.rootNode.name = "__scene__"
		scnScene.rootNode.addChildNode(scene.rootNode)
		print("== Loaded Scene")
		
		if let sceneCache = try! SceneCache(name: "missions/"+missionName) {
			scnScene.rootNode.addChildNode(sceneCache.node)
			sceneCache.node.name = "__cache__"
			print("== Loaded Scene Cache")
		}
		
		let collisions = try! Collisions(name: "missions/"+missionName, scene: scnScene)
		collisions.node.name = "__colliions__"
		scnScene.rootNode.addChildNode(collisions.node)
		print("== Loaded Scene Collisions")

//		let floorNode = SCNNode()
//		floorNode.opacity = 0
//		let floor = SCNFloor()
//		floor.reflectivity = 0
//		floorNode.geometry = floor
//		floorNode.physicsBody = SCNPhysicsBody.static()
//		scnScene.rootNode.addChildNode(floorNode)
		
		// -----
		
//		if scene.playerNode == nil {
//			//load z mise08-mesto
//			let spawnPoint = scnScene.rootNode.childNode(withName: "emeth_1", recursively: true)!
//			scene.playerNode = try! loadModel(named: "models/tommy")
//			scene.playerNode!.transform = spawnPoint.worldTransform
//			scnScene.rootNode.addChildNode(scene.playerNode!)
//		}
		
		// -----
		
		if let playerNode = scene.playerNode {
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
			playerNode.physicsBody?.angularDamping = 0.9999999
			playerNode.physicsBody?.damping = 0.9999999
			playerNode.physicsBody?.rollingFriction = 0
			playerNode.physicsBody?.friction = 0
			playerNode.physicsBody?.restitution = 0
			
			playerNode.position.y += 0.5
		}
		
		// -----
		
		let carNodeName = "taxi2"
//		let carNodeName = "cad_road"
		let carNode = scene.rootNode.childNode(withName: carNodeName, recursively: true)!
		vehicle = Vehicle(scene: scnScene, node: carNode)
		
		// -----
		
		let camera = SCNCamera()
		camera.zFar = 1000
		
		cameraNode.camera = camera
		cameraNode.scale = SCNVector3(x: 1, y: -1, z: 1)
		
		if mode == .car {
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
		
		if mode == .walk {
			if let playerNode = scene.playerNode {
				playerNode.addChildNode(cameraContainer)
			} else {
				scene.rootNode.addChildNode(cameraContainer)
			}
		} else {
			vehicle.node.addChildNode(cameraContainer)
		}
	}
	
	func setup(in view: SCNView) {
		hud = HudScene(size: view.bounds.size, game: self)
		view.scene = scnScene
		view.overlaySKScene = hud
		view.delegate = self
		view.pointOfView = cameraNode
		if let playerNode = scene.playerNode {
			view.audioListener = playerNode
		} else {
			view.audioListener = cameraContainer
		}
	}
	
}

// MARK: - SCNSceneRendererDelegate

extension Game: SCNSceneRendererDelegate {
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		#if os(macOS)
		
		guard let vehicle = vehicle?.physicsVehicle else { return }
		
		vehicle.setSteeringAngle(hud.vehicleSteering, forWheelAt: 0)
		vehicle.setSteeringAngle(hud.vehicleSteering, forWheelAt: 1)
		
		if hud.ride {
			vehicle.applyBrakingForce(0, forWheelAt: 2)
			vehicle.applyBrakingForce(0, forWheelAt: 3)
			if !hud.reverse {
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
		
		#elseif os(iOS)
		
		if mode == .walk {
			/*let translation = vc.walkGesture.translation(in: vc.view)
			if let playerNode = scene.playerNode {
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
				let angle = cameraContainer.presentation.rotation.y * cameraContainer.presentation.rotation.w - .pi
				let impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 500)), y: 0, z: max(-1, min(1, Float(-translation.y) / 500)))
				cameraContainer.position.x -= impulse.x * cos(angle) - impulse.z * sin(angle)
				cameraContainer.position.z += impulse.x * -sin(angle) - impulse.z * cos(angle)
			}*/
		} else {
			vehicle.applyForces()
		}
			
		#endif
		
		if let node = scene.compassNode {
			let p1 = node.presentation.worldPosition
			let p2 = scene.playerNode!.presentation.worldPosition
			hud.compass.isHidden = false
			let playerAngle: SCNFloat
			if mode == .walk {
				playerAngle = scene.playerNode!.presentation.rotation.y * scene.playerNode!.presentation.rotation.w - .pi
			} else {
				playerAngle = self.vehicle.node.presentation.rotation.y * self.vehicle.node.presentation.rotation.w - .pi/2
			}
			hud.compassNeedle.zRotation = CGFloat(atan2(p2.z - p1.z, p2.x - p1.x) + playerAngle)
		} else {
			hud.compass.isHidden = true
		}
		
		hud.actionButton.isHidden = scene.actions.filter({ $0.node.distance(to: scene.playerNode!) < 2 }).isEmpty
	}
	
}

// MARK: - Actions

extension Game {
	
	func performAction(_ action: Action) {
		switch action {
		case .action(let script, _):
			let index = scene.actions.index(where: { action in
				if case .action(let _script, _) = action {
					return script.uuid == _script.uuid
				} else {
					return false
				}
			})!
			scene.actions.remove(at: index)
			
			script.next()
			
		case .weapon(let node, let weapon):
			node.isHidden = true
			
			let index = scene.actions.index(where: { action in
				if case .weapon(_, let _weapon) = action {
					return weapon.uuid == _weapon.uuid
				} else {
					return false
				}
			})!
			scene.actions.remove(at: index)
			
			if scene.weapons[scene.playerNode!] == nil {
				scene.weapons[scene.playerNode!] = []
			}
			
			for weapon in scene.weapons[scene.playerNode!]! {
				weapon.position = .inventory
			}
			
			scene.weapons[scene.playerNode!]!.append(weapon)
			weapon.position = .hand
			
			break
		}
	}
	
	func actionButtonTapped() {
		/*#if os(iOS)
		let actions = scene.actions.filter({ $0.node.distance(to: scene.playerNode!) < 2 })
		if actions.count == 1 {
			performAction(actions[0])
		} else if actions.count > 1 {
			let alert = UIAlertController(title: "Sebrat / Použít", message: nil, preferredStyle: .alert)
			for action in actions {
				alert.addAction(UIAlertAction(title: action.title, style: .default, handler: { _ in
					self.performAction(action)
				}))
			}
			alert.addAction(UIAlertAction(title: "Zrušit", style: .cancel, handler: nil))
			vc.present(alert, animated: true)
		}
		#endif*/
	}
	
	func openInventory() {
		/*#if os(iOS)
		let alert = UIAlertController(title: "Inventář", message: nil, preferredStyle: .alert)
		for weapon in scene.weapons[scene.playerNode!] ?? [] {
			alert.addAction(UIAlertAction(title: weapon.name + (weapon.position == .hand ? " (v ruce)" : ""), style: .default, handler: { _ in
				for weapon in self.scene.weapons[self.scene.playerNode!] ?? [] {
					weapon.position = .inventory
				}
				weapon.position = .hand
			}))
		}
		alert.addAction(UIAlertAction(title: "Prázdné ruce", style: .cancel, handler: { _ in
			for weapon in self.scene.weapons[self.scene.playerNode!] ?? [] {
				weapon.position = .inventory
			}
		}))
		vc.present(alert, animated: true)
		#endif*/
	}
	
}
