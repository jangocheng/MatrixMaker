//
//  TiledImageView.swift
//  ImageTiling
//
//  Created by Justin England on 6/10/15.
//  Copyright (c) 2015 getoffmyhack.com. All rights reserved.
//

import Cocoa

@objc protocol LEDMatrixViewDelegate {
	func valueForImageAtLogicalX(logicalX: Int, logicalY: Int) -> Int
	func nextValueForImageAtLogicalX(logicalX: Int, logicalY: Int)
}

class LEDMatrixView: NSView {
	
	var imageArray: [NSImage] = []

	var columnCount		= 8
	var rowCount		= 8
	
	var curXPos			= 0
	var curYPos			= 0
	
	var currentSize		= 48
	var prevoiousSize	= 48
	
	var delegate: LEDMatrixViewDelegate! = nil
	
	override var flipped: Bool {
		return true
	}
	
    override func drawRect(dirtyRect: NSRect) {
		
		// draw background
		
		let backgroundColor = NSColor.darkGrayColor()
		backgroundColor.set()
		NSBezierPath.fillRect(bounds)

//		println("Rect: \(dirtyRect)")

		let xStart	= Int(dirtyRect.origin.x / CGFloat(currentSize))
		let xEnd	= Int(CGFloat(xStart) + (dirtyRect.size.width / CGFloat(currentSize)))

		let yStart	= Int(dirtyRect.origin.y / CGFloat(currentSize))
		let yEnd	= Int(CGFloat(yStart) + (dirtyRect.size.height / CGFloat(currentSize)))

		for x in xStart..<xEnd {
			for y in yStart..<yEnd {
				let frame = frameForImageAtLogicalX(x, logicalY: y)
				if !imageArray.isEmpty{
					let imageNumber = delegate.valueForImageAtLogicalX(x, logicalY: y)
					imageArray[imageNumber].drawInRect(frame)
				}
			}
		}
	}

//	override var intrinsicContentSize: NSSize {
//		
//		let furthestFrame =
//			frameForImageAtLogicalX(columnCount - 1, logicalY: rowCount - 1)
//		return NSSize(width: furthestFrame.maxX, height: furthestFrame.maxY)
//		
//	}
	
	override func viewDidMoveToWindow() {

		let notificationCenter = NSNotificationCenter.defaultCenter()
		notificationCenter.addObserver(self,
									selector:   "windowResized",
									name:       NSWindowDidResizeNotification,
									object:     self.window)
	
	}
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	func windowResized() {

		var newFrame = self.frame
//		println("newsize: \(self.frame)")
		
		// autosizing
		
		// get largest size (width or height)
		let maxEdgeLength = max(frame.height, frame.width)
//		println("maxEdgeLength: \(maxEdgeLength)")
		
		newFrame.size.height = maxEdgeLength
		newFrame.size.width  = maxEdgeLength
		self.frame = newFrame
		
		let pixelSize = (floor(maxEdgeLength / CGFloat(columnCount)))
//		println("pixelSize: \(pixelSize)")
//		println("newsize2: \(self.frame)")
		
		currentSize = Int(pixelSize)

	}
	
	// MARK: - Mouse Events

	override func mouseDown(theEvent: NSEvent) {
		
		let pointInView	= convertPoint(theEvent.locationInWindow, fromView: nil)
		let ledXPos		= Int(floor(pointInView.x / CGFloat(currentSize)))
		let ledYPos		= Int(floor(pointInView.y / CGFloat(currentSize)))
		
		delegate.nextValueForImageAtLogicalX(ledXPos, logicalY: ledYPos)
		curXPos			= ledXPos
		curYPos			= ledYPos

		let dirtyRect	= frameForImageAtLogicalX(ledXPos, logicalY: ledYPos)
		setNeedsDisplayInRect(dirtyRect)
		
	}
	
	override func mouseDragged(theEvent: NSEvent) {
		
		let pointInView	= convertPoint(theEvent.locationInWindow, fromView: nil)
		let ledXPos		= Int(floor(pointInView.x / CGFloat(currentSize)))
		let ledYPos		= Int(floor(pointInView.y / CGFloat(currentSize)))
		
		if (ledXPos != curXPos) || (ledYPos != curYPos) {
			
			if ((ledXPos < columnCount) && (ledYPos < rowCount)) &&
				((ledXPos >= 0) && (ledYPos >= 0)){
				
				delegate.nextValueForImageAtLogicalX(ledXPos, logicalY: ledYPos)
				curXPos	= ledXPos
				curYPos = ledYPos

				let dirtyRect = frameForImageAtLogicalX(ledXPos, logicalY: ledYPos)
				setNeedsDisplayInRect(dirtyRect)

			}
		}
	}

	// MARK: - Drawing
	
	func frameForImageAtLogicalX(logicalX: Int, logicalY: Int) -> CGRect {
		let spacing	= 0
		let width	= currentSize
		let height	= currentSize
		
		let x		= (spacing + width)  * logicalX
		let y		= (spacing + height) * logicalY
		return CGRect(x: x, y: y, width: width, height: height)
	}
}
