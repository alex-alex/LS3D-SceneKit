//
//  CollisionVolume.swift
//  Mafia
//
//  Created by Alex Studnicka on 04/03/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit

enum VolumeType: UInt8 {
	case face			= 0
	case face1			= 1
	case face2			= 2
	case face3			= 3
	case face4			= 4
	case face5			= 5
	case face6			= 6
	case face7			= 7

	case XTOBB			= 0x80
	case AABB			= 0x81
	case sphere			= 0x82
	case OBB			= 0x83
	case cylinder		= 0x84
}

struct Volume {
	var type: VolumeType
	var sortInfo: UInt8
	// 0b0000_0010 - destroyable
	// 0b0100_0000 - bullet penetrable
	var flags: UInt8
	var mtlId: UInt8
	var linkId: UInt32?

	init(stream: InputStream, hasLink: Bool) throws {
		type = try VolumeType(forcedRawValue: stream.read())
		sortInfo = try stream.read()
		flags = try stream.read()
		mtlId = try stream.read()

		if hasLink {
			let _linkId: UInt32 = try stream.read()
			linkId = _linkId
		} else {
			linkId = nil
		}
	}
}
