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
	optional func matrixViewDidChange()
}

class LEDMatrixView: NSView {
	
	var imageArray: [NSImage] = []

	var columnCount		= 8
	var rowCount		= 8
	
	var curXPos			= 0
	var curYPos			= 0
	
	var currentSize		= 48.0	as CGFloat
	
	var delegate: LEDMatrixViewDelegate! = nil
	
	var creatingImageForMatrixView	= false
	var matrixViewIsChanging		= true
	
	var imageForMatrixView: NSImage {
		let dataOfMatrixView = self.dataWithPDFInsideRect(self.bounds)
		return NSImage(data: dataOfMatrixView)!
	}

	
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

	}
    override func drawRect(dirtyRect: NSRect) {
		
		// draw background
		let backgroundColor = NSColor.darkGrayColor()
		backgroundColor.set()
		NSBezierPath.fillRect(bounds)

		let xStart	= (dirtyRect.origin.x / currentSize)
		let xEnd	= (xStart + (dirtyRect.size.width / currentSize))

		let yStart	= (dirtyRect.origin.y / currentSize)
		let yEnd	= (yStart + (dirtyRect.size.height / currentSize))
		
		let columnStart = Int(ceil(xStart))
		let columnEnd	= Int(floor(xEnd))
		
		let rowStart	= Int(ceil(yStart))
		let rowEnd		= Int(floor(yEnd))

		for x in columnStart..<columnEnd {
			for y in rowStart..<rowEnd {
				let frame = frameForImageAtLogicalX(x, logicalY: y)
				
				if (self.delegate != nil) {
					let imageNumber = delegate.valueForImageAtLogicalX(x, logicalY: y)
					imageArray[imageNumber].drawInRect(frame)
				} else {
					let imageNumber = 0
					imageArray[imageNumber].drawInRect(frame)
				}
			}
		}
		
		if(matrixViewIsChanging == true) {
			matrixViewIsChanging = false
			delegate?.matrixViewDidChange!()
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

		var newFrame			= self.frame
		let maxEdgeLength		= max(frame.height, frame.width)
		newFrame.size.height	= maxEdgeLength
		newFrame.size.width		= maxEdgeLength
		self.frame				= newFrame
		
		let pixelSize = (/*floor*/(maxEdgeLength / CGFloat(columnCount)))
		currentSize = pixelSize

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
		matrixViewIsChanging = true
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
				matrixViewIsChanging = true
				setNeedsDisplayInRect(dirtyRect)

			}
		}
	}

	// MARK: - Drawing
	
	func frameForImageAtLogicalX(logicalX: Int, logicalY: Int) -> CGRect {

		let width	= currentSize
		let height	= currentSize
		
		let x		= width  * CGFloat(logicalX)
		let y		= height * CGFloat(logicalY)

		return CGRect(x: x, y: y, width: width, height: height)
		
	}
	
	//
//	func makeImageForCurrentView()-> NSImage {
//		println("imageForCurrentView()")
//		matrixViewIsChanging = false
//		let dataOfView = self.dataWithPDFInsideRect(self.bounds)
//		let imageOfView = NSImage(data: dataOfView)
//		matrixViewIsChanging = true
//		return imageOfView!
//
//	}
}
