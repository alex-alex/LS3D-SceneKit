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
	case door(SCNNode)
	case vehicleSteal(Vehicle)
	case vehicleEnter(Vehicle)

	var node: SCNNode {
		switch self {
		case .action(let script, _):
			return script.node
		case .weapon(let node, _):
			return node
		case .door(let node):
			return node
		case .vehicleSteal(let vehicle):
			return vehicle.node
		case .vehicleEnter(let vehicle):
			return vehicle.node
		}
	}

	var title: String {
		switch self {
		case .action(_, let title):
			return title ?? "Použít"
		case .weapon(_, let weapon):
			return "Sebrat \(weapon.name)"
		case .door(let node):
			return node.doorData?.isOpen == true ? "Zavřít" : "Otevřít"
		case .vehicleSteal:
			return "Steal car"
		case .vehicleEnter:
			return "Enter car"
		}
	}
}
