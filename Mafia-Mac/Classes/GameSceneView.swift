//
//  GameSceneView.swift
//  Mafia
//
//  Created by Codex on 29/05/2026.
//  Copyright © 2026 Alex Studnicka. All rights reserved.
//

import AppKit
import SceneKit

final class GameSceneView: SCNView {

	var mouseMovedHandler: ((NSEvent) -> Void)?
	var mouseDownHandler: ((NSEvent) -> Void)?
	var mouseUpHandler: ((NSEvent) -> Void)?

	private var mouseTrackingArea: NSTrackingArea?

	override var acceptsFirstResponder: Bool {
		return true
	}

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		window?.acceptsMouseMovedEvents = true
		window?.makeFirstResponder(self)
	}

	override func updateTrackingAreas() {
		super.updateTrackingAreas()

		if let mouseTrackingArea = mouseTrackingArea {
			removeTrackingArea(mouseTrackingArea)
		}

		let options: NSTrackingArea.Options = [
			.activeAlways,
			.enabledDuringMouseDrag,
			.inVisibleRect,
			.mouseMoved
		]
		let trackingArea = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
		addTrackingArea(trackingArea)
		mouseTrackingArea = trackingArea
	}

	override func mouseMoved(with event: NSEvent) {
		mouseMovedHandler?(event)
	}

	override func mouseDragged(with event: NSEvent) {
		mouseMovedHandler?(event)
	}

	override func rightMouseDragged(with event: NSEvent) {
		mouseMovedHandler?(event)
	}

	override func otherMouseDragged(with event: NSEvent) {
		mouseMovedHandler?(event)
	}

	override func mouseDown(with event: NSEvent) {
		mouseDownHandler?(event)
	}

	override func rightMouseDown(with event: NSEvent) {
		mouseDownHandler?(event)
	}

	override func mouseUp(with event: NSEvent) {
		mouseUpHandler?(event)
	}

	override func rightMouseUp(with event: NSEvent) {
		mouseUpHandler?(event)
	}

	override func flagsChanged(with event: NSEvent) {
		overlaySKScene?.flagsChanged(with: event)
		super.flagsChanged(with: event)
	}

}
