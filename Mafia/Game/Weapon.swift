//
//  Weapon.swift
//  Mafia
//
//  Created by Alex Studnička on 07/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

final class Weapon {

	enum Position {
		case hand
		case inventory
	}

	private static var names: [Int: String] = [
		0: "Empty hands",
		1: "Special Action",
		2: "Knuckleduster",
		3: "Knife",
		4: "Baseball Bat",
		5: "Molotov cocktail",
		6: "Colt Detective Special",
		7: "S&W model 27 Magnum",
		8: "S&W model 10 M&P",
		9: "Colt 1911",
		10: "Thompson 1928",
		11: "Pump shotgun",
		12: "Saw off shotgun",
		13: "US Rifle M1903 Springfield",
		14: "Mosin:Nagant 1891/30",
		15: "Grenade",
		16: "Key",
		17: "Bucket",
		18: "Flashlight",
		19: "Documents",
		20: "Bar",
		21: "Papers",
		22: "Bomb",
		23: "Door keys",
		24: "Safe key",
		25: "Crowbar",
		26: "Plane ticket",
		27: "Package",
		28: "Wooden plank",
		29: "Bottle",
		30: "Small Key",
		31: "Sword",
		32: "Dog's Head",
		33: "Thompson 1928 no sound",
		34: "Pump shotgun no sound"
	]

	let uuid = NSUUID()
	let id: Int
	var clipAmmo: Int = 0
	var restAmmo: Int = 0
	var position: Position = .inventory

	var name: String {
		return Weapon.names[id]!
	}

	init(id: Int, clipAmmo: Int = 0, restAmmo: Int = 0) {
		self.id = id
		self.clipAmmo = clipAmmo
		self.restAmmo = restAmmo
	}

}
