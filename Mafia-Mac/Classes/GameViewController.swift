//
//  GameViewController.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/13/16.
//  Copyright (c) 2016 Alex Studnicka. All rights reserved.
//

import AppKit
import SceneKit

class GameViewController: NSViewController {

    @IBOutlet weak var gameView: SCNView!

	var gameManager: GameManager!

    override func awakeFromNib() {
        super.awakeFromNib()

		gameManager = GameManager(view: gameView)
    }

}
