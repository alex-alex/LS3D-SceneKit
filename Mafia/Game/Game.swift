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

#if os(macOS)
let mainDirectory = URL(fileURLWithPath: "/Users/alex/Development/Mafia DEV/Mafia")
#elseif os(iOS)
let mainDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Mafia")
#endif

let carNodeName = "taxi2" // cad_road

final class Game: NSObject {
	
	enum Mode {
		case walk, car
	}
	
	var vc: GameViewController!
	
	let scnScene = SCNScene()
	let cameraContainer = SCNNode()
	let cameraNode = SCNNode()
	
	var mode: Mode = .car {
		didSet {
			/*cameraContainer.removeFromParentNode()
			if mode == .walk {
				scene.playerNode!.addChildNode(cameraContainer)
			} else {
				let taxiNodeX = scene.rootNode.childNode(withName: carNodeName, recursively: true)!
				let taxiNode = taxiNodeX.childNode(withName: "BODY", recursively: false)!
				taxiNode.addChildNode(cameraContainer)
			}*/
		}
	}
	
	let scene: Scene
	
	var vehicle: Vehicle!
	var elevation: SCNFloat = 0
	var lastControl: Control? = nil
	
	init(vc: GameViewController) {
		self.vc = vc
		
		let sceneModel = try! loadModel(named: "missions/tutorial/scene")
		scnScene.rootNode.addChildNode(sceneModel)
		
		scene = try! loadScene(named: "missions/tutorial")
		
		super.init()
		
		scene.delegate = vc
		scene.game = self
		scnScene.rootNode.addChildNode(scene.rootNode)
		
//		let sceneCache = try! SceneCache(name: "missions/freeitaly")
//		scnScene.rootNode.addChildNode(sceneCache.node)
		
		let collisions = try! Collisions(name: "missions/tutorial", scene: scnScene)
		scnScene.rootNode.addChildNode(collisions.node)
		
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
			playerNode.physicsBody?.angularDamping = 0.999
			playerNode.physicsBody?.damping = 0.999
			playerNode.physicsBody?.rollingFriction = 0
			playerNode.physicsBody?.friction = 0
			playerNode.physicsBody?.restitution = 0
			
			playerNode.position.y += 0.5
		}
		
		// -----
		
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
			let bodyNode = vehicle.node.childNode(withName: "BODY", recursively: false)!
			bodyNode.addChildNode(cameraContainer)
		}
	}
	
	func setup(in view: SCNView) {
		//view.delegate = self
		view.rendersContinuously = true
		view.scene = scnScene
		view.antialiasingMode = .none
		view.allowsCameraControl = false
		view.autoenablesDefaultLighting = false
		view.showsStatistics = true
		//view.debugOptions = [.showPhysicsShapes]
		view.backgroundColor = .darkGray
		view.pointOfView = cameraNode
		if let playerNode = scene.playerNode {
			view.audioListener = playerNode
		} else {
			view.audioListener = cameraContainer
		}
	}
	
	func play(in view: SCNView) {
		view.play(nil)
	}
	
}

// MARK: - SCNSceneRendererDelegate

extension Game: SCNSceneRendererDelegate {
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		
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
		#if os(iOS)
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
		#endif
	}
	
	func openInventory() {
		#if os(iOS)
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
		#endif
	}
	
}
