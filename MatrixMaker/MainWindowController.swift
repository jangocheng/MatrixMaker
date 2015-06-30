//
//  MainWindowController.swift
//  MatrixMaker
//
//  Created by Justin England on 6/29/15.
//  Copyright (c) 2015 Justin England. All rights reserved.
//

import Cocoa

class MainWindowController:	NSWindowController,
							LEDMatrixViewDelegate {
	
	@IBOutlet weak var myMatrixView: LEDMatrixView!
	
	var ledStatusArray		= [[Int]](count: 8, repeatedValue:[Int](count: 8, repeatedValue:0))
	
	override var windowNibName: String {
		return "MainWindowController"
	}

    override func windowDidLoad() {
		
		super.windowDidLoad()
		
		var localImageArray: [NSImage] = []
		
		localImageArray.append(NSImage(named: "led_off.png")!)
		localImageArray.append(NSImage(named: "led_red.png")!)
		localImageArray.append(NSImage(named: "led_green.png")!)
		localImageArray.append(NSImage(named: "led_orange.png")!)
		
		localImageArray.append(NSImage(named: "led_blue.png")!)
		localImageArray.append(NSImage(named: "led_green2.png")!)
		localImageArray.append(NSImage(named: "led_mauve.png")!)
		localImageArray.append(NSImage(named: "led_yellow.png")!)
		
		myMatrixView!.imageArray	= localImageArray
		myMatrixView!.delegate		= self
		myMatrixView.needsDisplay	= true
		
    }

	// MARK: - Actions
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	
	@IBAction func toolbarNewWindow(sender: AnyObject) {
		
		let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate
		appDelegate!.addWindowController()
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	@IBAction func toolbarResetMatrix(sender: AnyObject) {
		
		for x in 0..<myMatrixView.columnCount {
			for y in 0..<myMatrixView.rowCount {
				ledStatusArray[x][y] = 0
			}
		}
		myMatrixView.needsDisplay = true
	}

	
	// MARK: - LEDMatrixViewDelegate
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func valueForImageAtLogicalX(logicalX: Int, logicalY: Int) -> Int {
		
		return ledStatusArray[logicalX][logicalY]
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func nextValueForImageAtLogicalX(logicalX: Int, logicalY: Int) {
		
		var greenByteForRow:	UInt8
		var redByteForRow:		UInt8
		
		ledStatusArray[logicalX][logicalY]++
		
		if ledStatusArray[logicalX][logicalY] == myMatrixView.imageArray.count {
			ledStatusArray[logicalX][logicalY] = 0
		}
		
	}

/*********************** End Window Controller      *************************/

}
