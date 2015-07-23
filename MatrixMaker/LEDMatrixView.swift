//
//  TiledImageView.swift
//  ImageTiling
//
//  Created by Justin England on 6/10/15.
//  Copyright (c) 2015 getoffmyhack.com. All rights reserved.
//

import Cocoa

@objc protocol LEDMatrixViewDelegate {
	func valueForMatrixAtLogicalX(logicalX: Int, logicalY: Int) -> Int
	func nextValueForMatrixAtLogicalX(logicalX: Int, logicalY: Int)
	optional func matrixViewDidChange(rangeForX: NSRange, rangeForY: NSRange)
}

class LEDMatrixView: NSView {
	
	var imageArray: [NSImage] = []

	var columnCount		= 8
	var rowCount		= 8
	
	var curXPos			= 0
	var curYPos			= 0
	
	var currentPixelSize		= 48.0	as CGFloat
	
	var delegate: LEDMatrixViewDelegate! = nil
	
	var matrixViewIsChanging		= false
	
	var imageForMatrixView			= NSImage()

	override var flipped: Bool {
		return true
	}
	
	override func awakeFromNib() {
		
		imageArray = [
			(NSImage(named: "led_off.png")!),
			(NSImage(named: "led_red.png")!),
			(NSImage(named: "led_green.png")!),
			(NSImage(named: "led_orange.png")!)
		]
		
		// initalize image buffer
		imageForMatrixView.size = self.frame.size
	}
	
    override func drawRect(dirtyRect: NSRect) {
		
		// set the NSImage object as the drawing context, flipped
		// to match the hardware cooridnate origin
		imageForMatrixView.lockFocusFlipped(true)

			// draw background
			let backgroundColor = NSColor.darkGrayColor()
			backgroundColor.set()
			NSBezierPath.fillRect(dirtyRect)
	
			// determine the x,y logical cooridinate to start and end;
			// tihis should be either the entire view, or a single LED
			// image that needs to be drawn
			let xStart	= (dirtyRect.origin.x / currentPixelSize)
			let xEnd	= (xStart + (dirtyRect.size.width / currentPixelSize))

			let yStart	= (dirtyRect.origin.y / currentPixelSize)
			let yEnd	= (yStart + (dirtyRect.size.height / currentPixelSize))
			
			let columnStart = Int(ceil(xStart))
			let columnEnd	= Int(floor(xEnd))
			
			let rowStart	= Int(ceil(yStart))
			let rowEnd		= Int(floor(yEnd))
		
			// create NSRange vars for call to delegate
			let xRange = NSMakeRange(columnStart, columnEnd)
			let yRange = NSMakeRange(rowStart, rowEnd)

			for x in columnStart..<columnEnd {
				for y in rowStart..<rowEnd {
					let pixelFrame = frameForPixelAtLogicalX(x, logicalY: y)
					
					if (self.delegate != nil) {
						let imageNumber = delegate.valueForMatrixAtLogicalX(x, logicalY: y)
						imageArray[imageNumber].drawInRect(pixelFrame)
					} else {
						let imageNumber = 0
						imageArray[imageNumber].drawInRect(pixelFrame)
					}
				}
			}
		
		imageForMatrixView.unlockFocus()

		// convert dirtyRect in flipped coordinates to image normal coord's
		let fromImageRect = convertViewRectToImageRect(dirtyRect, viewSize: self.frame.size)
		
		imageForMatrixView.drawInRect(
			dirtyRect,
			fromRect: fromImageRect,
			operation: .CompositeCopy,
			fraction: 1.0,
			respectFlipped: true,
			hints: nil
			)
		
		// only call delegate function if the matrix view is changing
		if(matrixViewIsChanging == true) {
			matrixViewIsChanging = false
			delegate?.matrixViewDidChange!(xRange, rangeForY: yRange)
		}
	}
	
	override func viewDidMoveToSuperview() {

		let notificationCenter = NSNotificationCenter.defaultCenter()
		notificationCenter.addObserver(self,
			selector:   "frameResized",
			name:       NSViewFrameDidChangeNotification,
			object:     self.window)

	}

	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	func frameResized() {
		
		let minEdgeLength		= min(frame.height, frame.width)
		let pixelSize = (minEdgeLength / CGFloat(columnCount))
		currentPixelSize = pixelSize
		imageForMatrixView = NSImage(size: self.frame.size)

	}
	
	func refreshMatrix() {
		matrixViewIsChanging = true
		needsDisplay = true
	}
	
	// MARK: - Mouse Events

	override func mouseDown(theEvent: NSEvent) {
		
		let pointInView	= convertPoint(theEvent.locationInWindow, fromView: nil)
		let ledXPos		= Int(floor(pointInView.x / CGFloat(currentPixelSize)))
		let ledYPos		= Int(floor(pointInView.y / CGFloat(currentPixelSize)))
				
		if ((ledXPos < columnCount) && (ledYPos < rowCount)) &&
			((ledXPos >= 0) && (ledYPos >= 0)){
			
			delegate.nextValueForMatrixAtLogicalX(ledXPos, logicalY: ledYPos)
			curXPos			= ledXPos
			curYPos			= ledYPos

			let dirtyRect	= frameForPixelAtLogicalX(ledXPos, logicalY: ledYPos)
			matrixViewIsChanging = true
			setNeedsDisplayInRect(dirtyRect)
		}
	}
	
	override func mouseDragged(theEvent: NSEvent) {
		
		let pointInView	= convertPoint(theEvent.locationInWindow, fromView: nil)
		let ledXPos		= Int(floor(pointInView.x / CGFloat(currentPixelSize)))
		let ledYPos		= Int(floor(pointInView.y / CGFloat(currentPixelSize)))
		
		if (ledXPos != curXPos) || (ledYPos != curYPos) {
			
			if ((ledXPos < columnCount) && (ledYPos < rowCount)) &&
				((ledXPos >= 0) && (ledYPos >= 0)){
				
				delegate.nextValueForMatrixAtLogicalX(ledXPos, logicalY: ledYPos)
				curXPos	= ledXPos
				curYPos = ledYPos

				let dirtyRect = frameForPixelAtLogicalX(ledXPos, logicalY: ledYPos)
				matrixViewIsChanging = true
				setNeedsDisplayInRect(dirtyRect)

			}
		}
	}

	// MARK: - Drawing
	
	func frameForPixelAtLogicalX(logicalX: Int, logicalY: Int) -> CGRect {

		let width	= currentPixelSize
		let height	= currentPixelSize
		
		let x		= width  * CGFloat(logicalX)
		let y		= height * CGFloat(logicalY)

		return CGRect(x: x, y: y, width: width, height: height)
		
	}
	
	func convertViewRectToImageRect(viewRect: NSRect, viewSize: NSSize) -> NSRect {
		
		var imageRect = viewRect
		imageRect.origin.y = ((viewSize.height - viewRect.origin.y) - viewRect.size.height)
		return imageRect
		
	}
	
}
