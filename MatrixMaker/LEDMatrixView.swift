//
//  TiledImageView.swift
//  ImageTiling
//
//  Created by Justin England on 6/10/15.
//  Copyright (c) 2015 getoffmyhack.com. All rights reserved.
//

import Cocoa

/*--------------------------------------------------------------------------*\
 
 Protocol:		LEDMatrixViewDelegate

 Required:

 valueForMatrixAtLogicalX(logicalX: Int, logicalY: Int) -> Int
	returns value from model for pixel at (logicalX, logicalY)

 nextValueForMatrixAtLogicalX(logicalX: Int, logicalY: Int)
	inform delegate to update model for pixel at (logicalX, logicalY)

 Optional:

 matrixViewDidChange(rangeForX: NSRange, rangeForY: NSRange)
	inform delgate that the matrix view is changing

\*--------------------------------------------------------------------------*/


@objc protocol LEDMatrixViewDelegate {

    func valueForMatrixAtLogicalX(logicalX: Int, logicalY: Int) -> Int
	func nextValueForMatrixAtLogicalX(logicalX: Int, logicalY: Int)
	optional func matrixViewDidChange(rangeForX: NSRange, rangeForY: NSRange)
    
}

/*--------------------------------------------------------------------------*\
 
 Class:			LEDMatrixView: NSView

 Description:	creates an LED matrix view that responds to mouse events in
				order to change the individual LED pixels
 
\*--------------------------------------------------------------------------*/


class LEDMatrixView: NSView {
	
	var imageArray: [NSImage] = []

	var columnCount			= 8
	var rowCount			= 8
	
	var currentXPosition	= 0
	var currentYPosition	= 0
	
	var currentPixelSize	= 48.0	as CGFloat
	
	var matrixViewIsChanging	= false
	
	var imageForMatrixView		= NSImage()
	
	var delegate: LEDMatrixViewDelegate! = nil
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

/***********************  Overrides Methods         *************************/
//
// MARK: - Overrides
//

	// use flipped coordinates to match hardware
	override var flipped: Bool {
		return true
	}

/*--------------------------------------------------------------------------*\
 
 Function:		override awakeFromNib()
 
 Description:	initalizes pixel image array and image buffer
 
\*--------------------------------------------------------------------------*/
	
	override func awakeFromNib() {
		
		imageArray = [
		
			(NSImage(named: "led_off.png")!),
			(NSImage(named: "led_red.png")!),
			(NSImage(named: "led_green.png")!),
			(NSImage(named: "led_orange.png")!)
//			(NSImage(named: NSImageNameStatusNone)!),
//			(NSImage(named: NSImageNameStatusUnavailable)!),
//			(NSImage(named: NSImageNameStatusAvailable)!),
//			(NSImage(named: NSImageNameStatusPartiallyAvailable)!),

		]
		
		// initalize image buffer
		imageForMatrixView.size = self.frame.size

	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		override drawRect(NSRect)
 
 Description:	draws matrix view to image buffer then draws to view;
				calls delegate if needed
 
\*--------------------------------------------------------------------------*/
	
    override func drawRect(dirtyRect: NSRect) {
	
		// set the NSImage object as the drawing context, flipped
		// to match the hardware cooridnate origin
		imageForMatrixView.lockFocusFlipped(true)
		
			// draw background
			let backgroundColor = NSColor.darkGrayColor()
			backgroundColor.set()
			NSBezierPath.fillRect(dirtyRect)
	
			// determine the x,y logical cooridinate to start and end;
			// this should be either the entire view, or a single LED
			// pixel that needs to be drawn
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
					
					// the delegate should always be available except once during
					// initalization
					if (self.delegate != nil) {
						let imageNumber = delegate.valueForMatrixAtLogicalX(x, logicalY: y)
						imageArray[imageNumber].drawInRect(pixelFrame)
						
					} else {
						let imageNumber = 0
						imageArray[imageNumber].drawInRect(pixelFrame)
					}
				}
			}
		
		// done drawing matrix in image buffer
		imageForMatrixView.unlockFocus()
		
		// convert dirtyRect in flipped coordinates to image normal coord's
		let fromImageRect = convertViewRectToImageRect(dirtyRect)
		
		// tell image buffer to draw itself in view
		imageForMatrixView.drawInRect(
							dirtyRect,
			fromRect:		fromImageRect,
			operation:		.CompositeCopy,
			fraction:		1.0,
			respectFlipped:	true,
			hints:			nil
			)
		
		// only call delegate function if the matrix view is changing
		if(matrixViewIsChanging == true) {
			matrixViewIsChanging = false
			delegate?.matrixViewDidChange!(xRange, rangeForY: yRange)
		}
	}

/*--------------------------------------------------------------------------*\
 
 Function:		override viewDidMoveToSuperview()
 
 Description:	init observer to NSViewFrameDidChange notifcations

\*--------------------------------------------------------------------------*/

	override func viewDidMoveToSuperview() {

		let notificationCenter = NSNotificationCenter.defaultCenter()
		notificationCenter.addObserver(self,
			selector:   #selector(LEDMatrixView.frameResized),
			name:       NSViewFrameDidChangeNotification,
			object:     self.window)

	}

/*********************** Events                    *************************/
//
// MARK: - Events
//
	
/*--------------------------------------------------------------------------*\
 
 Function:		mouseDown(NSEvent)
 
 Description:	handle mouse down event: update pixel at mouse point
	
\*--------------------------------------------------------------------------*/

	override func mouseDown(theEvent: NSEvent) {
		
		let pointInView	= convertPoint(theEvent.locationInWindow, fromView: nil)
		let ledXPos		= Int(floor(pointInView.x / CGFloat(currentPixelSize)))
		let ledYPos		= Int(floor(pointInView.y / CGFloat(currentPixelSize)))
		
		// check that logical pixel # is within range of matrix
		if ((ledXPos < columnCount) && (ledYPos < rowCount)) &&
			((ledXPos >= 0) && (ledYPos >= 0)){
			
			// tell delegate to update model data
			delegate.nextValueForMatrixAtLogicalX(ledXPos, logicalY: ledYPos)
			
			// update current logical pixel position
			currentXPosition			= ledXPos
			currentYPosition			= ledYPos

			// redraw view rect for logical pixel
			let dirtyRect	= frameForPixelAtLogicalX(ledXPos, logicalY: ledYPos)
			matrixViewIsChanging = true
			setNeedsDisplayInRect(dirtyRect)
		}
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		mouseDragged(NSEvent)
 
 Description:	handle mouse down event: update pixels at mouse points
	
\*--------------------------------------------------------------------------*/
	
	override func mouseDragged(theEvent: NSEvent) {
		
		let pointInView	= convertPoint(theEvent.locationInWindow, fromView: nil)
		let ledXPos		= Int(floor(pointInView.x / CGFloat(currentPixelSize)))
		let ledYPos		= Int(floor(pointInView.y / CGFloat(currentPixelSize)))
		
		// check if in new logical pixel frame
		if (ledXPos != currentXPosition) || (ledYPos != currentYPosition) {
			
			// check that logical pixel # is within the range of the matrix
			if ((ledXPos < columnCount) && (ledYPos < rowCount)) &&
				((ledXPos >= 0) && (ledYPos >= 0)){
				
				// tell delegate to update model data
				delegate.nextValueForMatrixAtLogicalX(ledXPos, logicalY: ledYPos)
				
				// update current logical pixel position
				currentXPosition	= ledXPos
				currentYPosition	= ledYPos

				// redraw view rect for logical pixel
				let dirtyRect = frameForPixelAtLogicalX(ledXPos, logicalY: ledYPos)
				matrixViewIsChanging = true
				setNeedsDisplayInRect(dirtyRect)

			}
		}
	}
	
/*********************** Notifications              *************************/
//
// MARK: - Notifications
//

/*--------------------------------------------------------------------------*\
 
 Function:		frameResized()
	
 Description:	called when NSViewFrameDidChangeNotification received;
				resets pixel size based on new view frame size;
				resizes matrix image
 
\*--------------------------------------------------------------------------*/
	
	func frameResized() {
		
		// calculate new pixel size
		let minEdgeLength		= min(frame.height, frame.width)
		let pixelSize = (minEdgeLength / CGFloat(columnCount))
		currentPixelSize = pixelSize
		
		// update image buffer size
		imageForMatrixView.size = self.frame.size
	}

/*********************** Helpers                    *************************/
//
// MARK: - Helpers
//

/*--------------------------------------------------------------------------*\
 
 Function:		refreshMatrix()
 
 Description:	tells matrix to redraw it self after model data has changed
 
\*--------------------------------------------------------------------------*/
	
	func refreshMatrix() {
		
		// matrix has changed, set flag
		matrixViewIsChanging = true
		
		// tell self to re-draw view
		needsDisplay = true
	}

/*--------------------------------------------------------------------------*\
 
 Function:		frameForPixelAtLogicalX(logicalX: Int, logicalY: Int) -> CGRect

 Description:	returns Rect for location to draw a single pixel image
 
\*--------------------------------------------------------------------------*/
	
	func frameForPixelAtLogicalX(logicalX: Int, logicalY: Int) -> NSRect {

		let width	= currentPixelSize
		let height	= currentPixelSize
		
		let x		= width  * CGFloat(logicalX)
		let y		= height * CGFloat(logicalY)

		return NSRect(x: x, y: y, width: width, height: height)
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		convertViewRectToImageRect(viewRect: NSRect, viewSize: NSSize) -> NSRect
 
 Description:	convert the view's rect.origin from normal to 
				flipped coordinates
 
\*--------------------------------------------------------------------------*/

	func convertViewRectToImageRect(viewRect: NSRect) -> NSRect {
		
		let viewSize = self.frame.size
		var imageRect = viewRect
		imageRect.origin.y = ((viewSize.height - viewRect.origin.y) - viewRect.size.height)
		return imageRect
		
	}
	

/*********************** End LEDMatrixView          *************************/

}
