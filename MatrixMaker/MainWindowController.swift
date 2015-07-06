//
//  MainWindowController.swift
//  MatrixMaker
//
//  Created by Justin England on 6/29/15.
//  Copyright (c) 2015 Justin England. All rights reserved.
//

import Cocoa
import ORSSerial

class MainWindowController:	NSWindowController,
							NSWindowDelegate,
							NSUserNotificationCenterDelegate,
							NSDrawerDelegate,
							ORSSerialPortDelegate,
							LEDMatrixViewDelegate {
	
	@IBOutlet weak var myMatrixView:		LEDMatrixView!
	@IBOutlet weak var portSettingsDrawer:  NSDrawer!
	@IBOutlet weak var portSelection:		NSPopUpButton!
	@IBOutlet weak var portBaudRate:        NSPopUpButton!
	@IBOutlet weak var portOpenCloseButton:	NSButton!
	@IBOutlet weak var myToolbar:			NSToolbar!
	
	var isPortOpen				= false
	var ledStatusArray			= [[Int]](count: 8, repeatedValue:[Int](count: 8, repeatedValue:0))
	var dataToSend				= NSMutableData()
	var currentConnectionState	= matrixConnectionState.idle
	var	timeoutTimer			= NSTimer()
	var rxSyncBytes				= 0
	
	let rxNumberOfSyncBytes = 3
	let serialPortManager	= ORSSerialPortManager.sharedSerialPortManager()
	let availableBaudRates	= [   300,  1200,  2400,  4800,   9600,  14400,
								19200, 28800, 38400, 57600, 115200, 230400]
	
	enum matrixConnectionState: UInt8 {
		case idle			= 0
		case connecting		= 1
		case connected		= 2
		case disconnecting	= 3
	}
	
	var serialPort: ORSSerialPort? {
		didSet {
			println("Setting serialPort")
			oldValue?.close()
			oldValue?.delegate		= nil
			serialPort?.delegate	= self
		}
	}
		
	override var windowNibName: String {
		return "MainWindowController"
	}
	
//	func windowWillResize(sender: NSWindow, toSize frameSize: NSSize) -> NSSize {
//
//		let oldX = sender.frame.width
//		let oldY = sender.frame.height
//		
//		var newX = frameSize.width
//		var newY = frameSize.height
//		
//		
//		if(newY == oldY) {
//			newY = newX + 80
//		} else if(newX == oldX) {
//			newX = newY - 80
//		}
//		
//		let newSize = NSMakeSize(newX, newY)
//		
//		println("willResize: \(sender.frame.size)")
//		println("toSize: \(frameSize)")
	
//		let resizeIncrement = CGFloat(myMatrixView.currentSize)
//		
//		window?.contentResizeIncrements = NSMakeSize(resizeIncrement,resizeIncrement)

//		return frameSize
//	}
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	
    override func windowDidLoad() {

		super.windowDidLoad()
		
		window!.contentAspectRatio = NSMakeSize(1.0,1.0)
		
		myMatrixView!.imageArray = [(NSImage(named: "led_off.png")!),
									(NSImage(named: "led_red.png")!),
									(NSImage(named: "led_green.png")!),
									(NSImage(named: "led_orange.png")!)]

		myMatrixView!.delegate		= self
		myMatrixView.needsDisplay	= true
		
//		let drawerSize = NSMakeSize(CGFloat(225), CGFloat(500))
//		portSettingsDrawer.minContentSize	= drawerSize
//		portSettingsDrawer.maxContentSize	= drawerSize
//		portSettingsDrawer.contentSize		= drawerSize

		portSettingsDrawer.preferredEdge	= NSMaxXEdge
		
		// create menu for serial port list
		portSelection.removeAllItems()
		for port in serialPortManager.availablePorts {
			portSelection.addItemWithTitle(port.name)
		}
		
		portBaudRate.selectItemWithTitle("115200")
		
//		dataToSend = NSMutableData()
		
		// set up to receive ORSSerialPorts notifications
		let notificationCenter = NSNotificationCenter.defaultCenter()
		
		notificationCenter.addObserver(self,
			selector:   "serialPortsWereConnected:",
			name:       ORSSerialPortsWereConnectedNotification,
			object:     nil)
		
		notificationCenter.addObserver(self,
			selector:   "serialPortsWereDisconnected:",
			name:       ORSSerialPortsWereDisconnectedNotification,
			object:     nil)
		
		NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self

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

/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/

	
	@IBAction func toolbarRotateRight(sender: AnyObject) {
		
		var ledRotateArray	= [[Int]](count: 8, repeatedValue:[Int](count: 8, repeatedValue:0))
		let columnCount		= myMatrixView.columnCount
		let rowCount		= myMatrixView.rowCount
		
		for x in 0..<columnCount {
			for y in 0..<rowCount {
				
				let newX = ((myMatrixView.columnCount - y) - 1)
				let newY = x
				
				ledRotateArray[newX][newY] = ledStatusArray[x][y]
				
			}
		}
		ledStatusArray = ledRotateArray
		myMatrixView.needsDisplay = true

	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	
	@IBAction func toolbarRotateLeft(sender: AnyObject) {
		
		var ledRotateArray	= [[Int]](count: 8, repeatedValue:[Int](count: 8, repeatedValue:0))
		let columnCount		= myMatrixView.columnCount
		let rowCount		= myMatrixView.rowCount
		
		for x in 0..<columnCount {
			for y in 0..<rowCount {
				
				let newX = y
				let newY = ((myMatrixView.rowCount - x) - 1)
				ledRotateArray[newX][newY] = ledStatusArray[x][y]
				
			}
		}
		ledStatusArray = ledRotateArray
		myMatrixView.needsDisplay = true
		
	}


/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/

	
	@IBAction func connectButtonClicked(sender: NSButton) {
		
		var string = ""
		
		if isPortOpen == false {
			for port in serialPortManager.availablePorts {
				if port.name == portSelection.titleOfSelectedItem! {
					serialPort = port as? ORSSerialPort
				}
			}
			
			serialPort?.baudRate = portBaudRate!.titleOfSelectedItem!.toInt()!
			serialPort?.numberOfStopBits = 1
			serialPort?.parity = ORSSerialPortParity.None
			serialPort?.open()
			string = "Opening Port \(serialPort!.path) / \(serialPort!.baudRate)\n"
			
		} else {
			
			serialPort?.close()
			string = "Closing Port \(serialPort!.path)\n"
			
		}
		
		println("\(serialPort)")
		println(string)
		
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
		
		// if connected to µcontroller, update hardware
		if serialPort?.open == true {
			
//			println("serial data for (\(logicalX),\(logicalY)): \(ledStatusArray[logicalX][logicalY])")
//			println("X:" + (NSString(format:"0x%02X", logicalX) as String))
//			println("Y:" + (NSString(format:"0x%02X", logicalY) as String))
//			println("C:" + (NSString(format:"0x%02X", ledStatusArray[logicalX][logicalY]) as String) + "\n")
			
			dataToSend.appendByte(UInt8(logicalX))
			dataToSend.appendByte(UInt8(logicalY))
			dataToSend.appendByte(UInt8(ledStatusArray[logicalX][logicalY]))
			serialPort?.sendData(dataToSend)
			dataToSend.length = 0
		}
		
//		println("valueForImageindex: \(logicalX),\(logicalY)")

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
		
		println("index: \(logicalX),\(logicalY)")
		ledStatusArray[logicalX][logicalY]++
		
		if ledStatusArray[logicalX][logicalY] == myMatrixView.imageArray.count {
			ledStatusArray[logicalX][logicalY] = 0
		}
		
	}
	
	// MARK: - ORSSerialPortDelegate
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func serialPortWasOpened(serialPort: ORSSerialPort) {
		
		portOpenCloseButton.title	= "Disconnect"
		portSelection.enabled		= false
		portBaudRate.enabled		= false
		isPortOpen					= true
		
		// set flag to wait for hardware to initalize and set a timer
		currentConnectionState		= matrixConnectionState.connecting

		//TODO: SET TIMER
//		timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(
//			5,
//			target:self,
//			selector: Selector("matrixFailedToSync"),
//			userInfo: nil,
//			repeats: false)
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func serialPortWasClosed(serialPort: ORSSerialPort) {
		
		self.portOpenCloseButton.title  = "Connect"
		self.portSelection.enabled      = true
		self.portBaudRate.enabled       = true
		self.isPortOpen                 = false
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func serialPort(serialPort: ORSSerialPort, didReceiveData data: NSData) {

		// data has been received from the hardware, send to method to process
		receivedDataFromHardware(data)
//		if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
//			print(string)
//		}
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {

		self.serialPort = nil
		self.portOpenCloseButton.title = "Connect"
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
		
		println("SerialPort \(serialPort) encountered an error: \(error)")
		
	}
	
	// MARK: - Notifications
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func serialPortsWereConnected(notification: NSNotification) {
		if let userInfo = notification.userInfo {
			let connectedPorts = userInfo[ORSConnectedSerialPortsKey] as! [ORSSerialPort]
			println("Ports were connected: \(connectedPorts)")
			
			for port in connectedPorts {
				portSelection.addItemWithTitle(port.name)
			}
		}
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func serialPortsWereDisconnected(notification: NSNotification) {
		if let userInfo = notification.userInfo {
			let disconnectedPorts: [ORSSerialPort] = userInfo[ORSDisconnectedSerialPortsKey] as! [ORSSerialPort]
			println("Ports were disconnected: \(disconnectedPorts)")
			
			let alert = NSAlert()
			alert.messageText = "Port Removed"
			alert.informativeText = "The selected serial port was removed from the system!"
			
			for port in disconnectedPorts {
				portSelection.removeItemWithTitle(port.name)
			}
		}
	}

/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func receivedDataFromHardware(rxData: NSData) {
		
		println(NSString(data: rxData, encoding: NSUTF8StringEncoding)!)

//		switch currentConnectionState {
//			
//		case matrixConnectionState.connecting:
//			
//			var rxDataByteArray = [UInt8](count: rxData.length, repeatedValue: 0)
//			rxData.getBytes(&rxDataByteArray, length: rxData.length)
//			
//			for rxByte in rxDataByteArray {
//				if rxByte == 0x03 {
//					if(rxSyncBytes == rxNumberOfSyncBytes) {
//						
//						currentConnectionState = matrixConnectionState.connected
//						timeoutTimer.invalidate()
//						rxSyncBytes = 0
//						
//					} else {
//						
//						rxSyncBytes++
//					
//					}
//					
//				} else {
//					
//					print(rxByte.char())
//					
//				}
//			}
//
//		default:
//			break
//			
//		}

	}
	
	func matrixFailedToSync() {
		println("Failed to connect to matrix")
		rxSyncBytes = 0
		currentConnectionState = matrixConnectionState.idle
		serialPort!.close()
	}

/*********************** End Window Controller      *************************/

}
