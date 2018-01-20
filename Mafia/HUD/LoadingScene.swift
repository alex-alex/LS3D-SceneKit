//
//  LoadingScene.swift
//  Mafia
//
//  Created by Alex Studnička on 17/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SpriteKit

extension SKTexture {
	convenience init(imageUrl: URL) {
		#if os(macOS)
			self.init(image: NSImage(contentsOf: imageUrl)!)
		#elseif os(iOS)
			self.init(image: UIImage(contentsOfFile: imageUrl.path)!)
		#endif
	}
}

final class LoadingScene: SKScene {
	
	var loaded = false
	var backgroundNode: SKShapeNode!
	var missionImage: SKSpriteNode!
	var missionName: SKLabelNode!
	var overlayImage: SKSpriteNode!
	var logoImage: SKSpriteNode!
	var loadingImage: SKSpriteNode!
	
	init(textId: Int, imageName: String) {
		super.init(size: CGSize(width: 1024, height: 768))
		
		scaleMode = .resizeFill
		
		let missionImageTexture = SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/"+imageName))
		missionImage = SKSpriteNode(texture: missionImageTexture)
		addChild(missionImage)
		
		missionName = SKLabelNode(fontNamed: "Aurora")
		missionName.fontColor = .black
		missionName.text = textId == 0 ? nil : TextDb.get(textId)
		missionName.horizontalAlignmentMode = .right
		missionName.verticalAlignmentMode = .bottom
		addChild(missionName)
		
		let overlayImageTexture = SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/loadbok.tga"))
		overlayImage = SKSpriteNode(texture: overlayImageTexture)
		addChild(overlayImage)
		
		let loadingImageTexture = SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/kulicky.tga"))
		loadingImage = SKSpriteNode(texture: loadingImageTexture)
		loadingImage.color = SKColor(red: 0.5, green: 0, blue: 0, alpha: 1)
		loadingImage.colorBlendFactor = 1
		addChild(loadingImage)
		
		let logoImageTexture = SKTexture(imageUrl: mainDirectory.appendingPathComponent("maps/mafia.tga"))
		logoImage = SKSpriteNode(texture: logoImageTexture)
		addChild(logoImage)
		
		loaded = true
		didChangeSize(.zero)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func didChangeSize(_ oldSize: CGSize) {
		super.didChangeSize(oldSize)
		
		guard loaded else { return }
		
		let w = size.width
		let h = size.height
		
		backgroundNode?.removeFromParent()
		backgroundNode = SKShapeNode(rectOf: size)
		backgroundNode.fillColor = .white
		backgroundNode.strokeColor = .clear
		backgroundNode.position = CGPoint(x: w/2, y: h/2)
		insertChild(backgroundNode, at: 0)
		
		let missionSize = w*0.75
		missionImage.size = CGSize(width: missionSize, height: h)
		missionImage.position = CGPoint(x: w-missionSize/2, y: h/2)
		
		missionName.fontSize = h * 0.06
		missionName.position = CGPoint(x: w-30, y: 30)
		
		let overlayWidth = w*0.35
		overlayImage.size = CGSize(width: overlayWidth, height: h)
		overlayImage.position = CGPoint(x: overlayWidth/2-1, y: h/2)
		
		let loadingWidth = overlayWidth*0.85
		let loadingContentWidth = loadingWidth*0.85
		let loadingImageHeight = (loadingContentWidth/256)*8
		loadingImage.size = CGSize(width: loadingContentWidth, height: loadingImageHeight)
		loadingImage.position = CGPoint(x: loadingWidth/2, y: 30+(loadingImageHeight/2))
		
		let logoImageHeight = (loadingContentWidth/256)*64
		logoImage.size = CGSize(width: loadingContentWidth, height: logoImageHeight)
		logoImage.position = CGPoint(x: loadingWidth/2, y: 40+loadingImageHeight+(logoImageHeight/2))
	}
	
}
