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

enum LightType: UInt32 {
	/// bodové: světlo v prostoru svítí do všech stran
	case point = 1
	/// kuželové: simuluje se zastínění světla stínítkem
	case cone
	/// ambientní: určuje celkové osvícení scény
	case ambient
	/// směrové: simuluje svit vzdálelého zdroje (např. slunce), světlo tedy svítí v celé scéně stále stejným směrem
	case directional
	/// mlha: vzdálené objekty plynule přechází do určené barvy
	case fog
	case layeredFog
}

final class Scene {

	var game: Game!
	let rootNode = SCNNode()
	var playerNode: SCNNode?

	var initScripts: [String: Script] = [:]
	var scripts: [String: Script] = [:]

	var sounds: [SCNNode: Sound] = [:]
	var weapons: [SCNNode: [Weapon]] = [:]
	var actions: [Action] = []
	var compassNode: SCNNode?

	var objectives: [Int] = [] {
		didSet {
//			game.objectivesChanged()
		}
	}
	var pressedJump = false

	init(named name: String) throws {
		let url = mainDirectory.appendingPathComponent(name + "/scene2.bin")

		guard let stream = InputStream(url: url) else { throw SceneError() }
		stream.open()

		let header: Int16 = try stream.read()
		guard header == 0x4c53 else { throw SceneError() }

		let _fileSize: Int32 = try stream.read()
		let fileSize = Int(_fileSize)

		stream.currentOffset = 160

		while stream.currentOffset < fileSize {
			try readSection(stream: stream)
		}

		stream.close()
	}

	// swiftlint:disable:next function_body_length
	private func readSection(stream: InputStream) throws {
//		let scene = self

		let startOffset = stream.currentOffset

		let _ = try SceneSection(forcedRawValue: stream.read()) // secSgn
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
							objectNode.light = SCNLight()

							stream.currentOffset += 6
							let lightTypeRaw: UInt32 = try stream.read()
							let lightType = try LightType(forcedRawValue: lightTypeRaw)

							switch lightType {
							case .point:
								objectNode.light?.type = .omni
	//							objectNode.light?.mod
							case .cone:
								objectNode.light?.type = .spot
							case .ambient:
								objectNode.light?.type = .ambient
							case .directional:
								objectNode.light?.type = .directional
							case .fog, .layeredFog:
								objectNode.light?.type = .ambient
								objectNode.light?.intensity = 0
							}

							stream.currentOffset += 6
							let r: Float = try stream.read()
							let g: Float = try stream.read()
							let b: Float = try stream.read()
							objectNode.light?.color = SKColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)

							stream.currentOffset += 6
							let power: Float = try stream.read()
							if objectNode.light?.type == .spot {
								objectNode.light?.intensity = CGFloat(power * 1000)
							} else {
								objectNode.light?.intensity = CGFloat(power * 100)
							}

							stream.currentOffset += 6
							let _: Float = try stream.read()	// cone 1 / 0.3490658402
							let _: Float = try stream.read()	// cone 2 / 0.6981316805

							stream.currentOffset += 6
							let _: Float = try stream.read()	// range near
							let _: Float = try stream.read()	// range far

							stream.currentOffset += partSize - 72

						case .music:
							let _ = try SCNVector3(stream: stream) // min
							let _ = try SCNVector3(stream: stream) // max

						case .sound:
							self.sounds[objectNode] = try Sound(scene: self, node: objectNode, stream: stream, partSize: partSize)

						case .occluder:
							stream.currentOffset += partSize - 6

						case .lightType:
							let _: String = try stream.read(maxLength: partSize - 6)
		//					print("lightType: (\(str))")

						case .lightMap:
							stream.currentOffset += partSize - 6
	//						let lightData = try stream.read(maxLength: partSize - 6)
	//						print("lightMap:", lightData.map({ String(format: "%02x", $0) }).joined())

						case .lens:
							stream.currentOffset += partSize - 6

						case .unknown4:
							stream.currentOffset += partSize - 6

						case .sector:
							stream.currentOffset += partSize - 6
						}
					}

					if type != .model && type != .object && type != .camera && type != .light {
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
							case .object:
								box.firstMaterial?.diffuse.contents = SKColor.red
							default:
								print("type:", type.rawValue)
								box.firstMaterial?.diffuse.contents = SKColor.green
							}

							box.firstMaterial?.cullMode = .front
							box.firstMaterial?.transparency = 0.2
							objectNode.geometry = box
						}
					}

					self.rootNode.addChildNode(objectNode)

				case .objDef:
					var name: String = ""
					var node: SCNNode?
					var type: ObjectDefinitionType = .empty

					while stream.currentOffset < (objectStartOffset + objSize) {
						let partSgn: UInt16 = try stream.read()

						let _partSize: UInt32 = try stream.read()
						let partSize = Int(_partSize)

						switch partSgn {
						case 0xae23: // name
							name = try stream.read(maxLength: partSize - 6)
							node = self.rootNode.childNode(withName: name, recursively: true)
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

								self.playerNode = node

							case .car:
								stream.currentOffset += partSize - 6

							case .script:
								stream.currentOffset += 10

								let scriptLength: UInt32 = try stream.read()
								let scriptStr: String = try stream.read(maxLength: Int(scriptLength))
								//print("[SCRIPT \(name)]:", scriptStr)
								guard node != nil else { print("SCRIPT HAS EMPTY NODE!!!"); break }
								let script = Script(script: scriptStr, scene: self, node: node!)
								self.scripts[name] = script

							case .door:
								stream.currentOffset += 21

		//						DWORD TYPE (?)
		//						BYTE OPEN_UP
		//						BYTE OPEN_DOWN
		//						FLOAT MOVE_ANGLE (90°)
		//						BYTE START_OPEN
		//						BYTE LOCKED
		//						FLOAT OPEN_SPEED
		//						FLOAT CLOSE_SPEED

								let _: String = try stream.read(maxLength: 16) // open
		//						print("door open:", open)
								let _: String = try stream.read(maxLength: 16) // close
		//						print("door close:", close)
								let _: String = try stream.read(maxLength: 16) // locked
		//						print("door locked:", locked)

								stream.currentOffset += 1

							case .trolley:
								stream.currentOffset += 1

								let _: UInt32 = try stream.read()						// numOfLinkedWagons / 0
								let _: Float = try stream.read()						// distanceBetweenWagons / 17
								let _: Float = try stream.read()						// 8 (const)
								let _: Float = try stream.read()						// maxSpeed / 9.7222
								let _: Float = try stream.read()						// 1 (const)
								let _: Float = try stream.read()						// 10000 (const)

							case .unknown3:
								stream.currentOffset += partSize - 6

							case .traffic:

								let _: UInt32 = try stream.read()						// 5 (const)
								let _: Float = try stream.read()						// outerRadiusToHide / 180
								let _: Float = try stream.read()						// innerRadiusForGener / 150
								let _: Float = try stream.read()						// outerRadiusForGener / 170
								let _: UInt32 = try stream.read()						// numOfGeneratedCars /	13
								let numOfCarsInDatabase: UInt32 = try stream.read()

								for _ in 0 ..< numOfCarsInDatabase {
									let _: String = try stream.read(maxLength: 20) // modelName
		//							print("CAR modelName:", modelName)

									let _: Float = try stream.read() // modelDensity
		//							print("CAR density:", modelDensity)

									let _: UInt32 = try stream.read() // colors
		//							print("CAR colors:", colors)

									let _: UInt16 = try stream.read() // isPolice
		//							print("CAR isPolice:", isPolice)

									let _: UInt16 = try stream.read() // gangsterFlags
		//							print("CAR gangsterFlags:", gangsterFlags)
								}

							case .pedestrians:
								stream.currentOffset += 5

								let _: Float = try stream.read()						// genRadiusFromPoint / 100
								let _: Float = try stream.read()						// outerRadiusToHide / 100
								let _: Float = try stream.read()						// innerRadiusForGen / 50
								let _: Float = try stream.read()						// outerRadiusForGener / 90
								let _: Float = try stream.read()						// innerRadiusForGener / 50
								let _: UInt32 = try stream.read()						// numOfGeneratedPeds / 100
								let numOfPedsInDatabase: UInt32 = try stream.read()

								for _ in 0 ..< numOfPedsInDatabase {
									let _: String = try stream.read(maxLength: 17) // modelName
		//							print("PED modelName:", modelName)
								}

								for _ in 0 ..< numOfPedsInDatabase {
									let _: UInt32 = try stream.read() // modelDensity
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

								let script = Script(script: scriptStr, scene: self, node: node!)
								self.scripts[name] = script

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
								let _: Float = try stream.read()	// weight
								let _: Float = try stream.read()	// friction
								let _: Float = try stream.read()
								// 0-crate,1-crate1,2-barrel,3-barrel1,4-label,5-box,6-wood,7-plate,8-no_sound
								let _: UInt32 = try stream.read()	// sound
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
					let script = Script(script: scriptStr, scene: self, node: self.rootNode)
					self.initScripts[name] = script
				}
			}
		}

	}

}
