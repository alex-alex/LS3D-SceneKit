//
//  Weapon.swift
//  Mafia
//
//  Created by Alex Studnička on 07/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

final class Weapon {

	enum Position {
		case hand
		case inventory
	}

	struct Profile {
		let clipSize: Int
		let shotInterval: TimeInterval
		let range: SCNFloat
		let impulse: SCNFloat
		let pelletCount: Int
		let spread: SCNFloat
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

	var profile: Profile? {
		return Weapon.profiles[id]
	}

	var isFirearm: Bool {
		return profile != nil
	}

	var hasAmmoLoaded: Bool {
		return clipAmmo == -1 || clipAmmo > 0
	}

	var canReload: Bool {
		guard let profile = profile, clipAmmo >= 0, restAmmo > 0 else { return false }
		return clipAmmo < profile.clipSize
	}

	private static let profiles: [Int: Profile] = [
		6: Profile(clipSize: 6, shotInterval: 0.35, range: 90, impulse: 18, pelletCount: 1, spread: 0.006),
		7: Profile(clipSize: 6, shotInterval: 0.45, range: 100, impulse: 26, pelletCount: 1, spread: 0.005),
		8: Profile(clipSize: 6, shotInterval: 0.38, range: 90, impulse: 20, pelletCount: 1, spread: 0.006),
		9: Profile(clipSize: 7, shotInterval: 0.25, range: 95, impulse: 20, pelletCount: 1, spread: 0.006),
		10: Profile(clipSize: 50, shotInterval: 0.09, range: 85, impulse: 14, pelletCount: 1, spread: 0.012),
		11: Profile(clipSize: 8, shotInterval: 0.85, range: 55, impulse: 10, pelletCount: 8, spread: 0.045),
		12: Profile(clipSize: 2, shotInterval: 0.55, range: 35, impulse: 9, pelletCount: 10, spread: 0.075),
		13: Profile(clipSize: 5, shotInterval: 0.9, range: 140, impulse: 34, pelletCount: 1, spread: 0.003),
		14: Profile(clipSize: 5, shotInterval: 0.9, range: 140, impulse: 34, pelletCount: 1, spread: 0.003),
		33: Profile(clipSize: 50, shotInterval: 0.09, range: 85, impulse: 14, pelletCount: 1, spread: 0.012),
		34: Profile(clipSize: 8, shotInterval: 0.85, range: 55, impulse: 10, pelletCount: 8, spread: 0.045)
	]

	init(id: Int, clipAmmo: Int = 0, restAmmo: Int = 0) {
		self.id = id
		self.clipAmmo = clipAmmo
		self.restAmmo = restAmmo
	}

}
