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
	
	enum matrixConnectionState: UInt8 {
		case idle			= 0
		case connecting		= 1
		case connected		= 2
		case disconnecting	= 3
	}
	
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
	var sendENQTimer			= NSTimer()
	var rxSyncBytes				= 0
	var counter					= 0
	
	let rxNumberOfSyncBytes = 3
	let serialPortManager	= ORSSerialPortManager.sharedSerialPortManager()
	let availableBaudRates	= [   300,    1200,    2400,  4800,   9600,  14400,
								19200,   28800,   38400, 57600, 115200, 230400,
							   250000, 1000000, 2000000]
	
/*
// characters used for serial comms
#define CHAR_NUL		0x00	// NUL character
#define CHAR_STX		0x02	// STX character (cntl-B)
#define CHAR_ETX		0x03	// ETX character (cntl-C)
#define CHAR_EOT		0x04	// EOT character (cntl-D)
#define CHAR_ENQ		0x05	// ENQ character (cntl-E)
#define CHAR_ACK		0x06	// ACK character (cntl-F)
#define CHAR_BS			0x08	// BS  character (cntl-H)
#define CHAR_CR			0x0d	// CR  character (cntl-M)
#define CHAR_CAN		0x18	// CAN character (cntl-X)
*/
	
	// protocol and control characters
	let controlCharSTX		= 0x02 as UInt8
	let controlCharENQ		= 0x05 as UInt8
	let controlCharACK		= 0x06 as UInt8
	
	// command characters
	let commandCharPlot		= 0xA0 as UInt8
	
	var serialPort: ORSSerialPort? {
		didSet {
			println("Setting serialPort")
			oldValue?.close()
			oldValue?.delegate						= nil
			serialPort?.delegate					= self
			serialPort?.allowsNonStandardBaudRates	= true

		}
	}
		
	override var windowNibName: String {
		return "MainWindowController"
	}
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

    override func windowDidLoad() {

		super.windowDidLoad()
		
		window!.contentAspectRatio			= NSMakeSize(1.0,1.0)
		myMatrixView!.delegate				= self
		portSettingsDrawer.preferredEdge	= NSMaxXEdge
		
		// create menu for serial port list
		portSelection.removeAllItems()
		
		for port in serialPortManager.availablePorts {
			
			let currentPort = port as! ORSSerialPort
			var portSelectionMenuItem = NSMenuItem()
			
			portSelectionMenuItem.title = currentPort.name
			portSelectionMenuItem.representedObject = currentPort
			
			if(currentPort.open == true) {
				portSelectionMenuItem.enabled = false
			}
			portSelection.menu!.addItem(portSelectionMenuItem)
			
		}
		// TODO: de-select disabled menu item
		
		portBaudRate.selectItemWithTitle("1000000")
		
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
	
		NSApplication.sharedApplication().applicationIconImage =
			myMatrixView.imageForMatrixView
	}
	
	// validate the menu items for serial port nspopupbutton
	override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
		
		// check if action method is for portSelect NSPopUpButton
		if(menuItem.action == Selector("portSelectMenuClicked:")) {
			let serialPortItem = menuItem.representedObject as! ORSSerialPort

			// check if port is open, if so, then disable menu item
			if(serialPortItem.open == true) {
				return false
			} else {
				return super.validateMenuItem(menuItem)
			}
		// menuItem not from portSelect: NSPopUpButton, validate as true
		} else {
			return super.validateMenuItem(menuItem)
		}
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
		myMatrixView.refreshMatrix()
	}

/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/

	
	@IBAction func toolbarRotateRight(sender: AnyObject) {
		
		let columnCount		= myMatrixView.columnCount
		let rowCount		= myMatrixView.rowCount
		
		var ledRotateArray	= [[Int]](
				count: columnCount,
				repeatedValue:[Int](
					count: rowCount,
					repeatedValue:0
				)
		)
		
		for x in 0..<columnCount {
			for y in 0..<rowCount {
				
				let newX = ((columnCount - y) - 1)
				let newY = x
				
				ledRotateArray[newX][newY] = ledStatusArray[x][y]
				
			}
		}
		
		ledStatusArray = ledRotateArray
		myMatrixView.refreshMatrix()

	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	@IBAction func toolbarRotateLeft(sender: AnyObject) {
		
		let columnCount		= myMatrixView.columnCount
		let rowCount		= myMatrixView.rowCount
		
		var ledRotateArray	= [[Int]](
			count: columnCount,
			repeatedValue:[Int](
				count: rowCount,
				repeatedValue:0
			)
		)
		
		for x in 0..<columnCount {
			for y in 0..<rowCount {
				
				let newX = y
				let newY = ((rowCount - x) - 1)
				ledRotateArray[newX][newY] = ledStatusArray[x][y]
			}
		}
		
		ledStatusArray = ledRotateArray
		myMatrixView.refreshMatrix()
		
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

			serialPort = portSelection.selectedItem!.representedObject as? ORSSerialPort
			serialPort?.baudRate = portBaudRate!.titleOfSelectedItem!.toInt()!
			serialPort?.numberOfStopBits = 1
			serialPort?.parity = ORSSerialPortParity.None
			serialPort?.open()
			string = "Opening Port \(serialPort!.path) baud: \(serialPort!.baudRate)\n"
			
		} else {
			
			serialPort?.close()
			string = "Closing Port \(serialPort!.path)\n"
			
		}
		
		println(string)
		
	}
	
	
	// Empty method as action to portSelect: NSPopUpMenu so that
	// menu validation will be enabled
	@IBAction func portSelectMenuClicked(sender: AnyObject) {
	}

	
// MARK: - LEDMatrixViewDelegate
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func valueForMatrixAtLogicalX(logicalX: Int, logicalY: Int) -> Int {
		
		return ledStatusArray[logicalX][logicalY]

	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func nextValueForMatrixAtLogicalX(logicalX: Int, logicalY: Int) {

		ledStatusArray[logicalX][logicalY]++
		if ledStatusArray[logicalX][logicalY] == myMatrixView.imageArray.count {
			ledStatusArray[logicalX][logicalY] = 0
		}
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func matrixViewDidChange(rangeForX: NSRange, rangeForY: NSRange) {
		
		if currentConnectionState == matrixConnectionState.connected {
			for x in rangeForX.location..<rangeForX.length {
				for y in rangeForY.location..<rangeForY.length {
					
//					println("serial data for (\(x),\(y)): \(ledStatusArray[x][y])")
//					println("X:" + (NSString(format:"%i", x) as String))
//					println("Y:" + (NSString(format:"%i", y) as String))
//					println("C:" + (NSString(format:"%i", ledStatusArray[x][y]) as String) + "\n")

					dataToSend.appendByte(UInt8(x))
					dataToSend.appendByte(UInt8(y))
					dataToSend.appendByte(UInt8(ledStatusArray[x][y]))
					serialPort?.sendData(dataToSend)
					dataToSend.length = 0
				}
			}
		}
		
		let viewImage = myMatrixView.imageForMatrixView
		NSApplication.sharedApplication().applicationIconImage = viewImage
		
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

		// Set a timer to fire off every 1/2 second sending an ENQ char
		// waiting for hardware to respond
		sendENQTimer = NSTimer.scheduledTimerWithTimeInterval(
			2,
			target:		self,
			selector:	Selector("sendENQToSyncMatrix"),
			userInfo:	nil,
			repeats:	true)
		
		// set timeoutTimer so that if matrix does not respond, it 
		// quits trying and closes serial port
		timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(
			10,
			target:self,
			selector: Selector("matrixFailedToSync"),
			userInfo: nil,
			repeats: false)
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:
 Author:
 
 Description:
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func serialPortWasClosed(serialPort: ORSSerialPort) {
		portOpenCloseButton.title	= "Connect"
		portSelection.enabled		= true
		portBaudRate.enabled		= true
		isPortOpen					= false
		currentConnectionState		= matrixConnectionState.idle
		sendENQTimer.invalidate()
		timeoutTimer.invalidate()
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
		sendENQTimer.invalidate()
		timeoutTimer.invalidate()
		currentConnectionState	= matrixConnectionState.idle
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
	
	// MARK: - NSWindowDelegate
	
	func windowDidBecomeKey(notification: NSNotification) {
		
		NSApplication.sharedApplication().applicationIconImage =
			myMatrixView.imageForMatrixView

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
				
				var serialPortMenuItem					= NSMenuItem()
				serialPortMenuItem.title				= port.name
				serialPortMenuItem.representedObject	= port
				portSelection.menu?.addItem(serialPortMenuItem)
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
		
//		println(NSString(data: rxData, encoding: NSUTF8StringEncoding)!)
		
		var rxDataByteArray = [UInt8](count: rxData.length, repeatedValue: 0)
		rxData.getBytes(&rxDataByteArray, length: rxData.length)

		switch currentConnectionState {
			
			case matrixConnectionState.connecting:
			
				for rxByte in rxDataByteArray {
					if rxByte == controlCharACK {
						timeoutTimer.invalidate()
						sendENQTimer.invalidate()
						currentConnectionState = matrixConnectionState.connected
						rxDataByteArray.removeAll(keepCapacity: false)
						println()
						println("Connected to matrix, rx'd ACK, refreshing display.")
						myMatrixView.refreshMatrix()
					} else {
						print(rxByte.asChar())
					}
				}
				break
			
			case matrixConnectionState.connected:
				for rxByte in rxDataByteArray {
					print(rxByte.asChar())
				}
				break
			
			default:
				break
			
		}

	}
	
	
	// MARK: - Timers
	
	func matrixFailedToSync() {
		println("Failed to connect to matrix")
		currentConnectionState = matrixConnectionState.idle
		sendENQTimer.invalidate()
		serialPort!.close()
	}
	
	func sendENQToSyncMatrix() {
		println("Sending ENQ Char.....")
		dataToSend.appendByte(controlCharENQ)
		serialPort?.sendData(dataToSend)
		dataToSend.length = 0
	}

/*********************** End Window Controller      *************************/

}
