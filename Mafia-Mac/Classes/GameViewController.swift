//
//  GameViewController.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/13/16.
//  Copyright (c) 2016 Alex Studnicka. All rights reserved.
//

import AppKit
import QuartzCore
import SceneKit
import SpriteKit

class GameViewController: NSViewController {
    
    @IBOutlet weak var gameView: SCNView!
	
	var game: Game!
    
    override func awakeFromNib() {
        super.awakeFromNib()
	
		try! TextDb.load()
		
		game = Game(vc: self)
		game.setup(in: gameView)
		game.play(in: gameView)
    }

}
