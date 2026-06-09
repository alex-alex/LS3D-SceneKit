//
//  AppDelegate.swift
//  Mafia
//
//  Created by Alex Studnicka on 8/13/16.
//  Copyright (c) 2016 Alex Studnicka. All rights reserved.
//

import Cocoa

@main
class AppDelegate: NSObject {

    @IBOutlet weak var window: NSWindow!
	private var didEnterFullScreenOnLaunch = false

}

// MARK: - NSApplicationDelegate

extension AppDelegate: NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
		window.collectionBehavior = window.collectionBehavior.union(.fullScreenPrimary)
		window.makeKeyAndOrderFront(nil)

		DispatchQueue.main.async { [weak self] in
			guard let self = self,
				  !self.didEnterFullScreenOnLaunch,
				  !self.window.styleMask.contains(.fullScreen) else {
				return
			}

			self.didEnterFullScreenOnLaunch = true
			self.window.toggleFullScreen(nil)
		}
    }

}
