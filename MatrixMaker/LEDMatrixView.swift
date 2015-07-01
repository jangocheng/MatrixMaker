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
	
//	let path = "/Library/Application Support/Apple/iChat Icons/Flags/"
//	let image1 = NSImage(byReferencingFile: path + "Brazil.png")
//	let image2 = NSImage(byReferencingFile: path + "Chile.png")
	
	var imageArray: [NSImage] = []

	let columnCount		= 8
	let rowCount		= 8
	
	var curXPos			= 0
	var curYPos			= 0
	
	var currentSize		= 48
	var prevoiousSize	= 48
	
	var delegate: LEDMatrixViewDelegate! = nil
	
    override func drawRect(dirtyRect: NSRect) {
		
		// draw background
		let backgroundColor = NSColor.darkGrayColor()
		backgroundColor.set()
		NSBezierPath.fillRect(bounds)

		for x in 0..<columnCount {
			for y in 0..<rowCount {
				let frame = frameForImageAtLogicalX(x, logicalY: y)
				if !imageArray.isEmpty{
					let imageNumber = delegate.valueForImageAtLogicalX(x, logicalY: y)
					imageArray[imageNumber].drawInRect(frame)
				}
			}
		}
	}
	
	override var intrinsicContentSize: NSSize {
		
		let furthestFrame =
			frameForImageAtLogicalX(columnCount - 1, logicalY: rowCount - 1)
		return NSSize(width: furthestFrame.maxX, height: furthestFrame.maxY)
		
	}
	
	// MARK: - Mouse Events

	override func mouseDown(theEvent: NSEvent) {
		
		let pointInView	= convertPoint(theEvent.locationInWindow, fromView: nil)
		let ledXPos		= Int(floor(pointInView.x / CGFloat(currentSize)))
		let ledYPos		= Int(floor(pointInView.y / CGFloat(currentSize)))
		
		delegate.nextValueForImageAtLogicalX(ledXPos, logicalY: ledYPos)
		curXPos			= ledXPos; curYPos = ledYPos
		needsDisplay	= true
	}
	
	override func mouseDragged(theEvent: NSEvent) {
		
		let pointInView	= convertPoint(theEvent.locationInWindow, fromView: nil)
		let ledXPos		= Int(floor(pointInView.x / CGFloat(currentSize)))
		let ledYPos		= Int(floor(pointInView.y / CGFloat(currentSize)))
		
		if (ledXPos != curXPos) || (ledYPos != curYPos) {
			
			if ((ledXPos < columnCount) && (ledYPos < rowCount)) &&
				((ledXPos >= 0) && (ledYPos >= 0)){
				
				delegate.nextValueForImageAtLogicalX(ledXPos, logicalY: ledYPos)
				curXPos			= ledXPos; curYPos = ledYPos
				needsDisplay	= true
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
