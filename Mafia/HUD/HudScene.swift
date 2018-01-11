//
//  HudScene.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SpriteKit

final class HudScene: SKScene {
	
	var vc: GameViewController!
	
	var compass: SKShapeNode!
	var compassNeedle: SKShapeNode!
	var actionButton: SKShapeNode!
	var inventoryButton: SKShapeNode!
	var reloadButton: SKShapeNode!
	var dropButton: SKShapeNode!
	var objectivesLabel: SKLabelNode!
	
	override init(size: CGSize) {
		super.init(size: size)
		
		compass = SKShapeNode(ellipseOf: CGSize(width: 100, height: 100))
		compass.isHidden = true
		compass.position = CGPoint(x: 70, y: size.height-70)
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
		actionButton.position = CGPoint(x: 45, y: 45)
		actionButton.fillColor = SKColor.blue
		actionButton.strokeColor = SKColor.clear
		addChild(actionButton)
		
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
		inventoryButtonLabel.text = "I"
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
		reloadButtonLabel.text = "R"
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
		dropButtonLabel.text = "<-"
		dropButtonLabel.verticalAlignmentMode = .center
		dropButton.addChild(dropButtonLabel)
		
		objectivesLabel = SKLabelNode()
		objectivesLabel.fontName = "Arial"
		objectivesLabel.fontSize = 17
		objectivesLabel.horizontalAlignmentMode = .center
		objectivesLabel.verticalAlignmentMode = .center
		objectivesLabel.position = CGPoint(x: size.width/2, y: size.height/2)
		addChild(objectivesLabel)
		
		scaleMode = .resizeFill
		isHidden = false
		isUserInteractionEnabled = true
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError()
	}
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)
		
		if let touch = touches.first, let node = nodes(at: touch.location(in: self)).first {
			#if os(iOS)
			vc.tapped(node: node)
			#endif
		}
	}
	
}
