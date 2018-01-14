//
//  Scene.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/14/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

struct SceneError: Error { }

enum SceneSection: UInt16 {
	case objects		= 0x4000
	case objDefs		= 0xae20
	case xyzs			= 0xae02
	case initScripts	= 0xae50
}

enum SceneSectionItem: UInt16 {
	case object			= 0x4010
	case objDef			= 0xae21
	case initDef		= 0xae03
	case initScript		= 0xae51
}

enum SceneObjectPart: UInt16 {
	case name			= 0x0010
	case position		= 0x0020
	case rotation		= 0x0022
	case globalPosition	= 0x002c
	case scale			= 0x002d
	case model			= 0x2012
	case type			= 0x4011
	case inSector		= 0x4020
	
	case unknown3		= 0x4033
	
	case light			= 0x4040
	case music			= 0x4050
	
	case sound			= 0x4060
	case occluder		= 0x4083
	
	case lightType		= 0x4090	// LMAP, LENS
	case lightMap		= 0x40a0
	case lens			= 0xb110
	
	case unknown4		= 0xb151
	
	case sector			= 0xb401
}

enum ObjectType: UInt32 {
	case light			= 2
	case camera			= 3
	case sound			= 4
	case object			= 6
	case model			= 9
	case occluder		= 12
	case music			= 14
}

enum ObjectDefinitionType: UInt32 {
	case ghost			= 1
	case player			= 2
	case car			= 4
	case script			= 5
	case door			= 6
	case trolley		= 8
	case unknown3		= 9		// object (villa)
	case traffic		= 12
	case pedestrians	= 18
	case empty			= 20
	case dog			= 21
	case plane			= 22
	case railRoute		= 24
	case pumpar			= 25
	case enemy			= 27
	case unknown2		= 28
	case wagons			= 30
	case clock			= 34
	case physical		= 35
	case truck			= 36
}

final class Scene {
	
	var game: Game!
	let rootNode = SCNNode()
	var playerNode: SCNNode? = nil
	
	var initScripts: [String: Script] = [:]
	var scripts: [String: Script] = [:]
	
	var sounds: [SCNNode: Sound] = [:]
	var weapons: [SCNNode: [Weapon]] = [:]
	var actions: [Action] = []
	var compassNode: SCNNode? = nil
	
	var objectives: [Int] = [] {
		didSet {
//			game.objectivesChanged()
		}
	}
	var pressedJump = false
	
	init() {}
	
}

private func readSection(stream: InputStream, scene: inout Scene) throws {
	
	let startOffset = stream.currentOffset
	
	let secSgn = try SceneSection(forcedRawValue: stream.read())
//	guard secSgn == 44576 else { throw SceneError.file }
	
	let _secSize: UInt32 = try stream.read()
	let secSize = Int(_secSize)
	
	while stream.currentOffset < (startOffset + secSize) {
		try autoreleasepool {
			
			let objectStartOffset = stream.currentOffset
			
			let objSgn = try SceneSectionItem(forcedRawValue: stream.read())
			
	//		print("--- \(objSgn)")
			
			let _objSize: UInt32 = try stream.read()
			let objSize = Int(_objSize)
			
			switch objSgn {
			case .object:
				
				let objectNode = SCNNode()
				var type: ObjectType = .object
				
				while stream.currentOffset < (objectStartOffset + objSize) {
					let partSgn = try SceneObjectPart(forcedRawValue: stream.read())
					
	//				print("------ \(partSgn)")
					
					let _partSize: UInt32 = try stream.read()
					let partSize = Int(_partSize)
					
					switch partSgn {
					case .name:
						let str: String = try stream.read(maxLength: partSize - 6)
						objectNode.name = str
						
					case .position:
						let _ = try SCNVector3(stream: stream)
	//					objectNode.position = position

					case .rotation:
						let rotation = try SCNQuaternion(stream: stream)
						objectNode.orientation = rotation
					
					case .globalPosition:
						let globalPosition = try SCNVector3(stream: stream)
						objectNode.position = globalPosition
						
					case .scale:
						let scale = try SCNVector3(stream: stream)
						objectNode.scale = scale
						
					case .model:
						var str: String = try stream.read(maxLength: partSize - 6)
						str = str.lowercased().replacingOccurrences(of: ".i3d", with: "")
						try loadModel(named: "models/" + str, node: objectNode)
						
					case .type:
						type = try ObjectType(forcedRawValue: stream.read())
						
					case .inSector:
						stream.currentOffset += 6
						let _: String = try stream.read(maxLength: partSize - 12)
	//					print("--------- \(str)")
						
					case .unknown3:
						stream.currentOffset += partSize - 6
						
					case .light:
						stream.currentOffset += partSize - 6
						
					case .music:
						let min = try SCNVector3(stream: stream)
						let max = try SCNVector3(stream: stream)
						
					case .sound:
						scene.sounds[objectNode] = try Sound(scene: scene, node: objectNode, stream: stream, partSize: partSize)
						
					case .occluder:
						stream.currentOffset += partSize - 6
						
					case .lightType:
						let _: String = try stream.read(maxLength: partSize - 6)
	//					print("lightType: (\(str))")
						
					case .lightMap:
						stream.currentOffset += partSize - 6
						
					case .lens:
						stream.currentOffset += partSize - 6
						
					case .unknown4:
						stream.currentOffset += partSize - 6
						
					case .sector:
						stream.currentOffset += partSize - 6
					}
				}
				
				if type != .model {
	//				print("OBJECT TYPE: \(type) \(objectNode.name)")
					
					if objectNode.name == "target" {
						let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
						box.firstMaterial = SCNMaterial()
						box.firstMaterial?.diffuse.contents = SKColor.red
						box.firstMaterial?.cullMode = .front
						objectNode.geometry = box
					} else {
						let box = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0)
						box.firstMaterial = SCNMaterial()
						
						switch type {
						case .light:
							box.firstMaterial?.diffuse.contents = SKColor.yellow
						case .sound:
							box.firstMaterial?.diffuse.contents = SKColor.magenta
						case .music:
							box.firstMaterial?.diffuse.contents = SKColor.cyan
						case .occluder:
							box.firstMaterial?.diffuse.contents = SKColor.brown
						case .camera:
							box.firstMaterial?.diffuse.contents = SKColor.orange
						default:
							box.firstMaterial?.diffuse.contents = SKColor.green
						}
						
						box.firstMaterial?.cullMode = .front
						box.firstMaterial?.transparency = 0.2
						objectNode.geometry = box
					}
				}
				
				scene.rootNode.addChildNode(objectNode)
				
			case .objDef:
				var name: String = ""
				var node: SCNNode? = nil
				var type: ObjectDefinitionType = .empty
				
				while stream.currentOffset < (objectStartOffset + objSize) {
					let partSgn: UInt16 = try stream.read()
					
					let _partSize: UInt32 = try stream.read()
					let partSize = Int(_partSize)
					
					switch partSgn {
					case 0xae23: // name
						name = try stream.read(maxLength: partSize - 6)
						node = scene.rootNode.childNode(withName: name, recursively: true)
						node?.type = type
						
					case 0xae22: // type
						type = try ObjectDefinitionType(forcedRawValue: stream.read())
						node?.type = type
						
					case 0xae24: // props

						switch type {
						case .ghost:
							stream.currentOffset += partSize - 6
							
						case .player:
							stream.currentOffset += 1
							
							let _: UInt32 = try stream.read()						// 1		behavior
							let _: UInt32 = try stream.read()						// 3		voice
							let _: Float = try stream.read()						// 0.7		strength
							let _: Float = try stream.read()						// 200		energy
							let _: Float = try stream.read()						// 40		energy hand r
							let _: Float = try stream.read()						// 40		energy hand l
							let _: Float = try stream.read()						// 40		energy leg l
							let _: Float = try stream.read()						// 40		energy leg r
							let _: Float = try stream.read()						// 0.7		reactions
							let _: Float = try stream.read()						// 1		speed
							let _: Float = try stream.read()						// 0.6		aggresivity
							let _: Float = try stream.read()						// 0.8		intelligence
							let _: Float = try stream.read()						// 1		shooting
							let _: Float = try stream.read()						// 1		signt
							let _: Float = try stream.read()						// 1		hearing
							let _: Float = try stream.read()						// 0.8		driving
							let _: Float = try stream.read()						// 80		mass
							let _: Float = try stream.read()						// 0.5		behavior 2
							
							scene.playerNode = node
							
						case .car:
							stream.currentOffset += partSize - 6
							
						case .script:
							stream.currentOffset += 10
							
							let scriptLength: UInt32 = try stream.read()
							let scriptStr: String = try stream.read(maxLength: Int(scriptLength))
							//print("[SCRIPT \(name)]:", scriptStr)
							guard node != nil else { print("SCRIPT HAS EMPTY NODE!!!"); break }
							let script = Script(script: scriptStr, scene: scene, node: node!)
							scene.scripts[name] = script
							script.start()
						
						case .door:
							stream.currentOffset += 21
							
	//						DWORD TYPE (?)
	//						BYTE OPEN_UP
	//						BYTE OPEN_DOWN
	//						FLOAT MOVE_ANGLE (1,5 = 90�)
	//						BYTE START_OPEN
	//						BYTE LOCKED
	//						FLOAT OPEN_SPEED
	//						FLOAT CLOSE_SPEED
							
							let open: String = try stream.read(maxLength: 16)
	//						print("door open:", open)
							let close: String = try stream.read(maxLength: 16)
	//						print("door close:", close)
							let locked: String = try stream.read(maxLength: 16)
	//						print("door locked:", locked)
							
							stream.currentOffset += 1
							
						case .trolley:
							stream.currentOffset += 1
							
							let numOfLinkedWagons: UInt32 = try stream.read()		// 0
							let distanceBetweenWagons: Float = try stream.read()	// 17
							let _: Float = try stream.read()						// 8 (const)
							let maxSpeed: Float = try stream.read()					// 9.7222
							let _: Float = try stream.read()						// 1 (const)
							let _: Float = try stream.read()						// 10000 (const)
							
						case .unknown3:
							stream.currentOffset += partSize - 6
							
						case .traffic:
							
							let _: UInt32 = try stream.read()						// 5 (const)
							let outerRadiusToHide: Float = try stream.read()		// 180
							let innerRadiusForGener: Float = try stream.read()		// 150
							let outerRadiusForGener: Float = try stream.read()		// 170
							let numOfGeneratedCars: UInt32 = try stream.read()		// 13
							let numOfCarsInDatabase: UInt32 = try stream.read()
							
							for _ in 0 ..< numOfCarsInDatabase {
								let modelName: String = try stream.read(maxLength: 20)
	//							print("CAR modelName:", modelName)
								
								let modelDensity: Float = try stream.read()
	//							print("CAR density:", modelDensity)
								
								let colors: UInt32 = try stream.read()
	//							print("CAR colors:", colors)
								
								let isPolice: UInt16 = try stream.read()
	//							print("CAR isPolice:", isPolice)
								
								let gangsterFlags: UInt16 = try stream.read()
	//							print("CAR gangsterFlags:", gangsterFlags)
							}
							
						case .pedestrians:
							stream.currentOffset += 5
							
							let genRadiusFromPoint: Float = try stream.read()		// 100
							let outerRadiusToHide: Float = try stream.read()		// 100
							let innerRadiusForGen: Float = try stream.read()		// 50
							let outerRadiusForGener: Float = try stream.read()		// 90
							let innerRadiusForGener: Float = try stream.read()		// 50
							let numOfGeneratedPeds: UInt32 = try stream.read()		// 100
							let numOfPedsInDatabase: UInt32 = try stream.read()
							
							for _ in 0 ..< numOfPedsInDatabase {
								let modelName: String = try stream.read(maxLength: 17)
	//							print("PED modelName:", modelName)
							}
							
							for _ in 0 ..< numOfPedsInDatabase {
								let modelDensity: UInt32 = try stream.read()
	//							print("PED density:", modelDensity)
							}
							
						case .empty:
							break
							
						case .dog:
							stream.currentOffset += partSize - 6
							
						case .plane:
							stream.currentOffset += partSize - 6
							
						case .railRoute:
							stream.currentOffset += partSize - 6
							
						case .pumpar:
							stream.currentOffset += partSize - 6
							
						case .enemy:
							stream.currentOffset += 79
							
							let scriptLength: UInt32 = try stream.read()
							let scriptStr: String = try stream.read(maxLength: Int(scriptLength))
							//print("ENEMY SCRIPT \(name):\n\(scriptStr)")
							
							let script = Script(script: scriptStr, scene: scene, node: node!)
							scene.scripts[name] = script
							script.start()
							
						case .unknown2:
							stream.currentOffset += partSize - 6
							
						case .wagons:
							stream.currentOffset += partSize - 6
							
						case .clock:
							stream.currentOffset += partSize - 6
							
						case .physical:
							stream.currentOffset += 2
							let _: Float = try stream.read()	// center of mass?
							let _: Float = try stream.read()
							let weight: Float = try stream.read()
							let friction: Float = try stream.read()
							let _: Float = try stream.read()
							// 0-crate,1-crate1,2-barrel,3-barrel1,4-label,5-box,6-wood,7-plate,8-no_sound
							let sound: UInt32 = try stream.read()
							stream.currentOffset += 5
							
							node?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
							
						case .truck:
							stream.currentOffset += partSize - 6
							
						}
						
					default:
						assert(true)
					}
				}
				
			case .initDef:
				stream.currentOffset += objSize - 6
				print("[INIT DEF]")
				
			case .initScript:
				stream.currentOffset += 1
				
				let nameLength: UInt32 = try stream.read()
				let name: String = try stream.read(maxLength: Int(nameLength))
				
				let scriptLength: UInt32 = try stream.read()
				let scriptStr: String = try stream.read(maxLength: Int(scriptLength))
				print("INIT_SCRIPT \(name):\n\(scriptStr)")
				let script = Script(script: scriptStr, scene: scene, node: scene.rootNode)
				scene.initScripts[name] = script
				script.start()
			}
		}
	}
	
}

func loadScene(named name: String) throws -> Scene {
	let url = mainDirectory.appendingPathComponent(name + "/scene2.bin")
	
//	let mainNode = SCNNode()
	var scene = Scene()
	
	guard let stream = InputStream(url: url) else { throw SceneError() }
	stream.open()
	
	let header: Int16 = try stream.read()
	guard header == 0x4c53 else { throw SceneError() }
	
	let _fileSize: Int32 = try stream.read()
	let fileSize = Int(_fileSize)
	
	stream.currentOffset = 160
	
	while stream.currentOffset < fileSize {
		try readSection(stream: stream, scene: &scene)
//		mainNode.addChildNode(node)
	}
	
	stream.close()
	
	return scene
}
