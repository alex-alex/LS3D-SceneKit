//
//  GameViewController.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/13/16.
//  Copyright (c) 2016 Alex Studnicka. All rights reserved.
//

import AppKit
import SceneKit

@MainActor
class GameViewController: NSViewController {

    @IBOutlet weak var gameView: GameSceneView!

	var gameManager: GameManager?
	private var cursorCaptureTimer: Timer?
	private var mouseEventMonitor: Any?
	private var isCursorHidden = false
	private var isCursorCaptureActive = false
	private var shouldDropNextMouseDelta = false

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()

		Task { @MainActor [weak self] in
			guard let self = self else { return }
			self.gameManager = GameManager(view: self.gameView)
		}
    }

	override func viewDidAppear() {
		super.viewDidAppear()

		view.window?.acceptsMouseMovedEvents = true
		view.window?.makeFirstResponder(gameView)
		gameView.mouseMovedHandler = { [weak self] event in
			self?.handleMouseEvent(event, source: .view)
		}
		gameView.mouseDownHandler = { [weak self] event in
			guard let self = self else { return }
				if let hud = self.gameManager?.game?.hud {
				let point = self.gameView.convert(event.locationInWindow, from: nil)
				if hud.handleInventorySelection(at: point) {
					return
				}
			}
				self.gameManager?.game?.playerDidFire()
			}
			gameView.mouseUpHandler = { [weak self] _ in
				self?.gameManager?.game?.releaseControl(.FIRE)
			}
		startMouseEventMonitor()
		startCursorCaptureTimer()
		updateCursorCapture()
	}

	override func viewWillDisappear() {
		super.viewWillDisappear()

		setCursorCaptureActive(false)
	}

	@MainActor deinit {
		cursorCaptureTimer?.invalidate()
		if let mouseEventMonitor = mouseEventMonitor {
			NSEvent.removeMonitor(mouseEventMonitor)
		}
		setCursorCaptureActive(false)
	}

	override func viewDidLayout() {
		super.viewDidLayout()

		gameView.overlaySKScene?.size = gameView.bounds.size
	}

	private enum MouseSource {
		case view
		case monitor
	}

	private func startMouseEventMonitor() {
		guard mouseEventMonitor == nil else { return }

		mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
			.mouseMoved,
			.leftMouseDragged,
			.rightMouseDragged,
			.otherMouseDragged
		]) { [weak self] event in
			self?.handleMouseEvent(event, source: .monitor)
			return event
		}
	}

	private func startCursorCaptureTimer() {
		guard cursorCaptureTimer == nil else { return }

		cursorCaptureTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
			Task { @MainActor in
				self?.updateCursorCapture()
			}
		}
	}

	private func handleMouseEvent(_ event: NSEvent, source: MouseSource) {
		updateCursorCapture()
		if source == .monitor && (abs(event.deltaX) > 0 || abs(event.deltaY) > 0) {
			if shouldDropNextMouseDelta {
				shouldDropNextMouseDelta = false
				return
			}
			queueMouseDelta(x: SCNFloat(event.deltaX), y: SCNFloat(event.deltaY))
		}
	}

	private func queueMouseDelta(x deltaX: SCNFloat, y deltaY: SCNFloat) {
		guard let game = gameManager?.game,
			  !game.isGamePaused else {
			return
		}

		game.look(
			deltaX: -deltaX * 0.006,
			deltaY: deltaY * 0.004
		)
	}

	private func updateCursorCapture() {
		view.window?.acceptsMouseMovedEvents = true

		guard let game = gameManager?.game,
			  view.window?.isKeyWindow == true,
			  !game.isGamePaused,
			  game.hud?.isInventoryVisible != true,
			  isMouseLookMode(for: game) else {
			setCursorCaptureActive(false)
			return
		}

		setCursorCaptureActive(true)
	}

	private func setCursorCaptureActive(_ isActive: Bool) {
		guard isCursorCaptureActive != isActive else { return }

		isCursorCaptureActive = isActive

		if isActive {
			shouldDropNextMouseDelta = true
			gameManager?.game?.clearPendingLook()
			setCursorHidden(true)
			centerCursorInGameView()
			_ = CGAssociateMouseAndMouseCursorPosition(0)
		} else {
			shouldDropNextMouseDelta = false
			gameManager?.game?.clearPendingLook()
			_ = CGAssociateMouseAndMouseCursorPosition(1)
			setCursorHidden(false)
		}
	}

	private func setCursorHidden(_ isHidden: Bool) {
		guard isCursorHidden != isHidden else { return }

		if isHidden {
			NSCursor.hide()
		} else {
			NSCursor.unhide()
		}
		isCursorHidden = isHidden
	}

	private func centerCursorInGameView() {
		guard let window = gameView.window,
			  let screen = window.screen else { return }

		let viewCenter = CGPoint(x: gameView.bounds.midX, y: gameView.bounds.midY)
		let windowPoint = gameView.convert(viewCenter, to: nil)
		let screenPoint = window.convertPoint(toScreen: windowPoint)
		let quartzPoint = CGPoint(
			x: screenPoint.x,
			y: screen.frame.maxY - screenPoint.y
		)
		CGWarpMouseCursorPosition(quartzPoint)
	}

	private func isMouseLookMode(for game: Game) -> Bool {
		switch game.mode {
		case .walk:
			return game.scene.playerNode != nil
		case .car:
			return true
		case .freeCamera:
			return true
		}
	}

}
