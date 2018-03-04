//
//  Action.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

enum Action {
	case action(Script, String?)
	case weapon(SCNNode, Weapon)

	var node: SCNNode {
		switch self {
		case .action(let script, _):
			return script.node
		case .weapon(let node, _):
			return node
		}
	}

	var title: String {
		switch self {
		case .action(_, let title):
			return title ?? "Použít"
		case .weapon(_, let weapon):
			return "Sebrat \(weapon.name)"
		}
	}
}
