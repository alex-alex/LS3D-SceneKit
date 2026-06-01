//
//  MissionEffects.swift
//  Mafia
//
//  Created by Codex on 6/1/26.
//  Copyright © 2026 Alex Studnicka. All rights reserved.
//

import Foundation
import CoreGraphics
import SceneKit
import SpriteKit

struct MissionEffect {
	let id: UInt32
	let position: SCNVector3
	let scale: Float
}

final class MissionEffects {
	let node = SCNNode()
	let effects: [MissionEffect]

	init?(name: String) throws {
		let url = mainDirectory.appendingPathComponent(name + "/effects.bin")
		guard FileManager.default.fileExists(atPath: url.path),
			  let stream = InputStream(url: url) else { return nil }

		stream.open()
		defer { stream.close() }

		let header: UInt16 = try stream.read()
		guard header == 100 else { throw SceneError() }

		let declaredFileSize: UInt32 = try stream.read()
		let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
		let actualFileSize = (attributes?[.size] as? NSNumber)?.intValue ?? Int(declaredFileSize)
		let fileSize = min(Int(declaredFileSize), actualFileSize)

		var loadedEffects: [MissionEffect] = []

		while stream.currentOffset + 74 <= fileSize {
			let recordStartOffset = stream.currentOffset
			let signature: UInt16 = try stream.read()
			let recordSizeValue: UInt32 = try stream.read()
			let recordSize = Int(recordSizeValue)
			let recordEndOffset = recordStartOffset + recordSize

			guard signature == 1000, recordSize >= 74, recordEndOffset <= fileSize else {
				stream.currentOffset = min(recordEndOffset, fileSize)
				continue
			}

			stream.currentOffset += 48

			let position = try SCNVector3(stream: stream)
			let scale: Float = try stream.read()
			let id: UInt32 = try stream.read()

			let effect = MissionEffect(id: id, position: position, scale: scale)
			loadedEffects.append(effect)
			node.addChildNode(MissionEffects.makeNode(for: effect))

			stream.currentOffset = recordEndOffset
		}

		effects = loadedEffects
	}

	private static func makeNode(for effect: MissionEffect) -> SCNNode {
		let effectNode = SCNNode()
		effectNode.name = "__mission_effect_\(effect.id)_\(effectName(for: effect.id))__"
		effectNode.position = effect.position
		effectNode.addParticleSystem(particleSystem(for: effect))
		return effectNode
	}

	private static func particleSystem(for effect: MissionEffect) -> SCNParticleSystem {
		let profile = profile(for: effect.id)
		let system = SCNParticleSystem()
		let scale = CGFloat(max(Float(0.25), min(effect.scale, Float(4))))

		system.birthRate = profile.birthRate * scale
		system.birthLocation = .volume
		system.birthDirection = .constant
		system.emitterShape = SCNSphere(radius: profile.emitterRadius * scale)
		system.loops = true
		system.isLocal = false
		system.particleLifeSpan = profile.lifeSpan
		system.particleLifeSpanVariation = profile.lifeSpanVariation
		system.particleSize = profile.size * scale
		system.particleSizeVariation = profile.sizeVariation * scale
		system.particleVelocity = profile.velocity
		system.particleVelocityVariation = profile.velocityVariation
		system.acceleration = profile.acceleration
		system.spreadingAngle = profile.spreadingAngle
		system.particleColor = profile.color
		system.particleColorVariation = profile.colorVariation
		system.blendMode = profile.blendMode
		system.particleImage = softParticleImage()
		system.warmupDuration = min(3, profile.lifeSpan)
		system.stretchFactor = profile.stretchFactor

		return system
	}

	private static func softParticleImage() -> CGImage? {
		let size = 64
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(
			data: nil,
			width: size,
			height: size,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: colorSpace,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			return nil
		}

		let center = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
		let colors = [
			CGColor(red: 1, green: 1, blue: 1, alpha: 0.42),
			CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
			CGColor(red: 1, green: 1, blue: 1, alpha: 0)
		] as CFArray
		let locations: [CGFloat] = [0, 0.42, 1]
		guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
			return nil
		}

		context.drawRadialGradient(
			gradient,
			startCenter: center,
			startRadius: 0,
			endCenter: center,
			endRadius: CGFloat(size) / 2,
			options: [.drawsAfterEndLocation]
		)
		return context.makeImage()
	}

	private static func profile(for id: UInt32) -> ParticleProfile {
		switch id {
		case 5, 28, 38, 44, 45, 50, 53, 55, 58, 71, 78:
			return .smoke
		case 24, 25, 34, 47, 62, 63, 64, 65, 66, 70, 74, 75, 90:
			return .thinSmoke
		case 6, 9, 11, 21, 22, 39, 49, 57, 59, 60, 68, 77, 86:
			return .fire
		case 7, 8, 10, 20, 48, 51, 52, 67, 69:
			return .explosion
		case 19, 23, 26, 27, 30, 31, 36, 37, 41, 42, 43, 54, 76, 83, 84, 85, 87, 89:
			return .water
		case 12, 13, 14, 15, 16, 17, 18, 32, 56, 79, 80, 81, 82:
			return .spark
		case 33, 72, 73:
			return .dust
		case 35:
			return .paper
		default:
			return .impact
		}
	}

	private static func effectName(for id: UInt32) -> String {
		switch id {
		case 0: return "blood"
		case 1: return "hit_stonewall"
		case 2: return "hit_ground"
		case 3: return "hit_metal"
		case 4: return "hit_wood"
		case 5: return "night_chimney_smoke"
		case 6: return "Fire"
		case 7: return "Explosion"
		case 8: return "molotov_explosion"
		case 9: return "fire_small"
		case 10: return "explosion_big"
		case 11: return "molotov_fire"
		case 12: return "Thompson_muzzle_flash_day"
		case 13: return "Thompson_muzzle_flash_night"
		case 14: return "pistol_muzzle_flash_day"
		case 15: return "pistol_muzzle_flash_night"
		case 16: return "shotgun_muzzle_flash_day"
		case 17: return "shotgun_muzzle_flash_night"
		case 18: return "fireworks"
		case 19: return "pena"
		case 20: return "explosion_car"
		case 21: return "fire_fading"
		case 22: return "fire_small_fading"
		case 23: return "pena_ve_vane"
		case 24: return "smoke_cigarette"
		case 25: return "smoke_cigarette_breath"
		case 26: return "chcani"
		case 27: return "bliti"
		case 28: return "smoke_parnik"
		case 29: return "hit_grass"
		case 30: return "voda_prehrada"
		case 31: return "voda_prehrada_dole"
		case 32: return "listi_ze_stromu"
		case 33: return "prach_motorest"
		case 34: return "kour_restaurace"
		case 35: return "dollars"
		case 36: return "fontanka1"
		case 37: return "zblunk"
		case 38: return "smoke_saliery"
		case 39: return "lighter"
		case 40: return "krev_vrtule"
		case 41: return "voda_vezeni_1"
		case 42: return "voda_vezeni_2"
		case 43: return "hit_water"
		case 44: return "smoke_loco1"
		case 47: return "steam2_loco"
		case 48: return "explosion_hotel"
		case 49: return "gasoline"
		case 50: return "smoke_coffee"
		case 51: return "Explosion_hotel1"
		case 52: return "Explosion_Morello"
		case 53: return "Dust_Morello"
		case 54: return "kola_na_vode"
		case 55: return "slow_smoke"
		case 56: return "spark_cig"
		case 57: return "Fire_no_smoke"
		case 58: return "smoke_cigarette_breath1"
		case 59: return "horici_benzin"
		case 60: return "FMVlighter"
		case 61: return "bloodSamFMV"
		case 62: return "FMV_Loko-2sec"
		case 63: return "FMV_Loko-1sec"
		case 64: return "FMV_Loko-03"
		case 65: return "FMV_Loko-low"
		case 66: return "FMV_chladic"
		case 67: return "FMV_Expl-cisterna"
		case 68: return "FMV_lighter"
		case 69: return "FMV_gasoline2"
		case 70: return "doutnik"
		case 71: return "kour_na_lokomotivu_NESAHA"
		case 72: return "vol_dust"
		case 73: return "hovna"
		case 74: return "FMV_cigarette"
		case 75: return "dust_fall"
		case 76: return "kaluz_chuze"
		case 77: return "fire_cig"
		case 78: return "kour_lod_doprava"
		case 79: return "fireworks1"
		case 80: return "fireworks2"
		case 81: return "fireworks3"
		case 82: return "fireworks4"
		case 83: return "vlny"
		case 84: return "vlny_big"
		case 85: return "vlny_small"
		case 86: return "FMV_sirka"
		case 87: return "hydrant"
		case 88: return "kytka_listy"
		case 89: return "hadice"
		case 90: return "dymovnice"
		case 91: return "FMV"
		default: return "unknown"
		}
	}
}

private struct ParticleProfile {
	let birthRate: CGFloat
	let lifeSpan: CGFloat
	let lifeSpanVariation: CGFloat
	let size: CGFloat
	let sizeVariation: CGFloat
	let velocity: CGFloat
	let velocityVariation: CGFloat
	let acceleration: SCNVector3
	let spreadingAngle: CGFloat
	let emitterRadius: CGFloat
	let color: SKColor
	let colorVariation: SCNVector4
	let blendMode: SCNParticleBlendMode
	let stretchFactor: CGFloat

	static let smoke = ParticleProfile(
		birthRate: 10,
		lifeSpan: 4.2,
		lifeSpanVariation: 1,
		size: 0.34,
		sizeVariation: 0.14,
		velocity: 0.22,
		velocityVariation: 0.12,
		acceleration: SCNVector3(x: 0, y: 0.14, z: 0),
		spreadingAngle: 28,
		emitterRadius: 0.12,
		color: SKColor(white: 0.42, alpha: 0.24),
		colorVariation: SCNVector4(x: 0.12, y: 0.12, z: 0.12, w: 0.1),
		blendMode: .alpha,
		stretchFactor: 0.05
	)

	static let thinSmoke = ParticleProfile(
		birthRate: 7,
		lifeSpan: 3.2,
		lifeSpanVariation: 0.8,
		size: 0.18,
		sizeVariation: 0.08,
		velocity: 0.16,
		velocityVariation: 0.08,
		acceleration: SCNVector3(x: 0, y: 0.11, z: 0),
		spreadingAngle: 20,
		emitterRadius: 0.06,
		color: SKColor(white: 0.62, alpha: 0.2),
		colorVariation: SCNVector4(x: 0.1, y: 0.1, z: 0.1, w: 0.08),
		blendMode: .alpha,
		stretchFactor: 0.08
	)

	static let fire = ParticleProfile(
		birthRate: 18,
		lifeSpan: 0.55,
		lifeSpanVariation: 0.18,
		size: 0.12,
		sizeVariation: 0.06,
		velocity: 0.28,
		velocityVariation: 0.15,
		acceleration: SCNVector3(x: 0, y: 0.28, z: 0),
		spreadingAngle: 24,
		emitterRadius: 0.07,
		color: SKColor(red: 1, green: 0.46, blue: 0.08, alpha: 0.45),
		colorVariation: SCNVector4(x: 0.1, y: 0.18, z: 0.05, w: 0.12),
		blendMode: .additive,
		stretchFactor: 0.2
	)

	static let explosion = ParticleProfile(
		birthRate: 24,
		lifeSpan: 0.7,
		lifeSpanVariation: 0.25,
		size: 0.18,
		sizeVariation: 0.08,
		velocity: 0.45,
		velocityVariation: 0.25,
		acceleration: SCNVector3(x: 0, y: 0.05, z: 0),
		spreadingAngle: 180,
		emitterRadius: 0.18,
		color: SKColor(red: 1, green: 0.55, blue: 0.13, alpha: 0.32),
		colorVariation: SCNVector4(x: 0.14, y: 0.16, z: 0.08, w: 0.12),
		blendMode: .additive,
		stretchFactor: 0.08
	)

	static let water = ParticleProfile(
		birthRate: 16,
		lifeSpan: 0.85,
		lifeSpanVariation: 0.25,
		size: 0.045,
		sizeVariation: 0.025,
		velocity: 0.42,
		velocityVariation: 0.18,
		acceleration: SCNVector3(x: 0, y: -0.55, z: 0),
		spreadingAngle: 45,
		emitterRadius: 0.06,
		color: SKColor(red: 0.78, green: 0.9, blue: 1, alpha: 0.28),
		colorVariation: SCNVector4(x: 0.06, y: 0.06, z: 0.08, w: 0.1),
		blendMode: .alpha,
		stretchFactor: 0.45
	)

	static let spark = ParticleProfile(
		birthRate: 10,
		lifeSpan: 0.45,
		lifeSpanVariation: 0.18,
		size: 0.025,
		sizeVariation: 0.012,
		velocity: 0.55,
		velocityVariation: 0.22,
		acceleration: SCNVector3(x: 0, y: -0.28, z: 0),
		spreadingAngle: 75,
		emitterRadius: 0.035,
		color: SKColor(red: 1, green: 0.82, blue: 0.25, alpha: 0.7),
		colorVariation: SCNVector4(x: 0.06, y: 0.1, z: 0.04, w: 0.08),
		blendMode: .additive,
		stretchFactor: 1.4
	)

	static let dust = ParticleProfile(
		birthRate: 8,
		lifeSpan: 2,
		lifeSpanVariation: 0.55,
		size: 0.2,
		sizeVariation: 0.08,
		velocity: 0.2,
		velocityVariation: 0.12,
		acceleration: SCNVector3(x: 0, y: 0.04, z: 0),
		spreadingAngle: 80,
		emitterRadius: 0.16,
		color: SKColor(red: 0.5, green: 0.45, blue: 0.38, alpha: 0.2),
		colorVariation: SCNVector4(x: 0.1, y: 0.08, z: 0.07, w: 0.08),
		blendMode: .alpha,
		stretchFactor: 0.03
	)

	static let paper = ParticleProfile(
		birthRate: 3,
		lifeSpan: 2.4,
		lifeSpanVariation: 0.6,
		size: 0.07,
		sizeVariation: 0.025,
		velocity: 0.2,
		velocityVariation: 0.1,
		acceleration: SCNVector3(x: 0, y: -0.12, z: 0),
		spreadingAngle: 45,
		emitterRadius: 0.08,
		color: SKColor(white: 0.9, alpha: 0.35),
		colorVariation: SCNVector4(x: 0.06, y: 0.06, z: 0.04, w: 0.08),
		blendMode: .alpha,
		stretchFactor: 0.6
	)

	static let impact = ParticleProfile(
		birthRate: 3,
		lifeSpan: 0.55,
		lifeSpanVariation: 0.16,
		size: 0.045,
		sizeVariation: 0.02,
		velocity: 0.22,
		velocityVariation: 0.12,
		acceleration: SCNVector3(x: 0, y: -0.18, z: 0),
		spreadingAngle: 90,
		emitterRadius: 0.04,
		color: SKColor(red: 0.72, green: 0.62, blue: 0.48, alpha: 0.25),
		colorVariation: SCNVector4(x: 0.12, y: 0.1, z: 0.08, w: 0.1),
		blendMode: .alpha,
		stretchFactor: 0.2
	)
}
