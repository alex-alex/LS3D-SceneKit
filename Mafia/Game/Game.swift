//
//  Game.swift
//  Mafia
//
//  Created by Alex Studnička on 11/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

#if os(macOS)
let mainDirectory = URL(fileURLWithPath: "/Users/alex/Development/Mafia DEV/Mafia")
#elseif os(iOS)
let mainDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Mafia")
#endif

final class Game {
	
	enum Mode {
		case walk, car
	}
	
}
