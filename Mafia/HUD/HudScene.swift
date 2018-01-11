//
//  HudScene.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SpriteKit

class HudScene: SKScene {
	
	var vc: GameViewController!
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)
		
		if let touch = touches.first, let node = nodes(at: touch.location(in: self)).first {
			#if os(iOS)
			vc.tapped(node: node)
			#endif
		}
	}
	
}
