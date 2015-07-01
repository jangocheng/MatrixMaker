//
//  AppDelegate.swift
//  MatrixMaker
//
//  Created by Justin England on 6/29/15.
//  Copyright (c) 2015 Justin England. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	var windowControllers: [MainWindowController] = []
	
	// MARK: -  NSApplicationDelegate
	
	func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication)-> Bool {
		return true
	}
	
	func applicationDidFinishLaunching(aNotification: NSNotification) {
		addWindowController()
	}
	
	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}
	
	// MARK: - Helpers
	
	func addWindowController() {
		
		let windowController = MainWindowController()
		windowController.showWindow(self)
		windowControllers.append(windowController)
		
	}
	
	// MARK - Actions
	
	@IBAction func displayNewWindow(send: NSMenuItem) {
		addWindowController()
	}
	
	
	
	
	
}

