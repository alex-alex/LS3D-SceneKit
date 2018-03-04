//
//  AnimationFace.swift
//  Mafia
//
//  Created by Alex Studnička on 17/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

// /tables/dat/*.dat

/*
-------------------------------------------------- ----------
variable type description
-------------------------------------------------- ----------
recCount long number of frames describing animation elements
unknown 4 byte constant 01 00 00 00
record1 8 byte first frame
	...
recordN 8 byte and last
-------------------------------------------------- ----------
		
recordX - frame describes the position of the lips, eyebrows, eyes
-------------------------------------------------- ----------
variable type description
-------------------------------------------------- ----------
wideMouth byte pulls his lips into a tube.  From the 00-lip in a line, to the FF-duckface.
openMouth byte mouth opening width.  00-says clenched teeth .. FF-mouth does not close.
lipsConers byte corners of the lips.  00-raised .. FF-lowered
eyelid byte movement of the upper eyelid.  00-raised .. FF-lowered
openEye byte size of eyes.  00-closed .. FF-very large
eyebrow byte raises his eyebrows.  00-very high .. FF-does not raise.
unknown 2 byte Constant 01 01
-------------------------------------------------- ----------
*/
