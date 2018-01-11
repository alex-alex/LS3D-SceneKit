//
//  Game.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

#if os(macOS)
let mainDirectory = URL(fileURLWithPath: "/Users/alex/Development/Mafia DEV/Mafia")
#elseif os(iOS)
let mainDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Mafia")
#endif

final class Game {
	
	enum Mode {
		case walk, car
	}
	
	let gameScene: Scene
	let scnScene: SCNScene
	
	var vc: UIViewController!
	
	var lastControl: Control? = nil
	
	init(gameScene: Scene, scnScene: SCNScene) {
		self.gameScene = gameScene
		self.scnScene = scnScene
	}
	
}

// MARK: - Actions

extension Game {
	
	func performAction(_ action: Action) {
		switch action {
		case .action(let script, _):
			let index = gameScene.actions.index(where: { action in
				if case .action(let _script, _) = action {
					return script.uuid == _script.uuid
				} else {
					return false
				}
			})!
			gameScene.actions.remove(at: index)
			
			script.next()
			
		case .weapon(let node, let weapon):
			node.isHidden = true
			
			let index = gameScene.actions.index(where: { action in
				if case .weapon(_, let _weapon) = action {
					return weapon.uuid == _weapon.uuid
				} else {
					return false
				}
			})!
			gameScene.actions.remove(at: index)
			
			if gameScene.weapons[gameScene.playerNode!] == nil {
				gameScene.weapons[gameScene.playerNode!] = []
			}
			
			for weapon in gameScene.weapons[gameScene.playerNode!]! {
				weapon.position = .inventory
			}
			
			gameScene.weapons[gameScene.playerNode!]!.append(weapon)
			weapon.position = .hand
			
			break
		}
	}
	
	func actionButtonTapped() {
		let actions = gameScene.actions.filter({ $0.node.distance(to: gameScene.playerNode!) < 2 })
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
	}
	
	func openInventory() {
		let alert = UIAlertController(title: "Inventář", message: nil, preferredStyle: .alert)
		for weapon in gameScene.weapons[gameScene.playerNode!] ?? [] {
			alert.addAction(UIAlertAction(title: weapon.name + (weapon.position == .hand ? " (v ruce)" : ""), style: .default, handler: { _ in
				for weapon in self.gameScene.weapons[self.gameScene.playerNode!] ?? [] {
					weapon.position = .inventory
				}
				weapon.position = .hand
			}))
		}
		alert.addAction(UIAlertAction(title: "Prázdné ruce", style: .cancel, handler: { _ in
			for weapon in self.gameScene.weapons[self.gameScene.playerNode!] ?? [] {
				weapon.position = .inventory
			}
		}))
		vc.present(alert, animated: true)
	}
	
}
