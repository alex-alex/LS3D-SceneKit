//
//  MainMenu.swift
//  Mafia
//
//  Created by Alex Studnička on 17/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

class MainMenu {
	
	let scnScene = SCNScene()
//	let cameraContainer = SCNNode()
	let cameraNode = SCNNode()
	let scene: Scene
	
	init() {
		scnScene.rootNode.name = "__root__"
		
		let sceneModel = try! loadModel(named: "missions/00menu/scene")
		sceneModel.name = "__model__"
		scnScene.rootNode.addChildNode(sceneModel)
		
		scene = try! loadScene(named: "missions/00menu")
		scene.rootNode.name = "__scene__"
		scnScene.rootNode.addChildNode(scene.rootNode)
		
		// -----
		
		let camera = SCNCamera()
		camera.zNear = 0.01
		camera.zFar = 1000
//		camera.wantsHDR = true
		
		cameraNode.camera = camera
		cameraNode.scale = SCNVector3(x: 1, y: -1, z: 1)
	
		//cameraNode.position = SCNVector3(x: 0, y: 1, z: 0)
//		cameraNode.eulerAngles = SCNVector3(x: .pi/2, y: .pi, z: .pi)
		cameraNode.eulerAngles = SCNVector3(x: .pi, y: 0, z: 0)
		//cameraContainer.position = SCNVector3(x: 0, y: 2, z: 0)
		
		//cameraContainer.eulerAngles.x = -.pi/2.5
		//cameraContainer.addChildNode(cameraNode)
		
		// -----
		
//		camera_start, training_pos, new_game_pos
		let newGamePos = scene.rootNode.childNode(withName: "camera_start", recursively: false)!
		newGamePos.addChildNode(cameraNode)
	}
	
	func setup(in view: SCNView) {		
		view.scene = scnScene
		view.overlaySKScene = nil
		view.delegate = nil
		view.pointOfView = cameraNode
		view.audioListener = nil
	}
	
}
