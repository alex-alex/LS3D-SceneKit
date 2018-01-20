//
//  AnimationPosition.swift
//  Mafia
//
//  Created by Alex Studnička on 17/01/2018.
//  Copyright © 2018 Alex Studnicka. All rights reserved.
//

import Foundation

// /anims/*.tck

/*
-------------------------------------------------- ------------
variable type description
-------------------------------------------------- ------------
fileSgn long file signature, constant = 04 00 00 00
startPosX float initial X coordinate of the position of the object (?)
startPosY float Y
startPosZ float Z
endPosX float final X coordinate of the position of the object (?)
endPosY float Y
endPosZ float Z
time long animation duration in msec
frameTime long duration of one frame in msec
posCount long number of intermediate positions of the object
posDesc - block for describing the coordinates of the positions of the object
endSgn long end signature, constant = 00 00 00 00
-------------------------------------------------- ------------

posDesc - block for describing the coordinates of intermediate positions of the object
The following structure is repeated posCount times
-------------------------------------------------- ------------
variable type description
-------------------------------------------------- ------------
PosX float X coordinate of the position of the object
PosY float Y
PosZ float Z
-------------------------------------------------- ------------
*/
