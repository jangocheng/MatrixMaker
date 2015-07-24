/****************************************************************************\

File:			MainWindowController.swift

Date:			1 July 2015

Description:	Window controller for app

Known bugs/missing features:

Modifications:
Date                Comment
----    ------------------------------------------------

\****************************************************************************/

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
							NSTabViewDelegate,
							ORSSerialPortDelegate,
							LEDMatrixViewDelegate {
	
	enum matrixConnectionState: UInt8 {
		case idle			= 0
		case connecting		= 1
		case connected		= 2
		case disconnecting	= 3
	}
	
	enum pixelColor: UInt8 {
		case Red	= 1
		case Green	= 2
		case Orange	= 3
	}
	
	@IBOutlet weak var myMatrixView:		LEDMatrixView!
	@IBOutlet weak var portSettingsDrawer:  NSDrawer!
	@IBOutlet weak var portSelection:		NSPopUpButton!
	@IBOutlet weak var portBaudRate:        NSPopUpButton!
	@IBOutlet weak var portOpenCloseButton:	NSButton!
	@IBOutlet weak var myToolbar:			NSToolbar!
	@IBOutlet weak var imageCodeTabView:	NSTabView!
	@IBOutlet	   var codeTextView:		NSTextView!
		
	var isPortOpen				= false
	var ledStatusArray			= [[Int]](count: 8, repeatedValue:[Int](count: 8, repeatedValue:0))
	var dataToSend				= NSMutableData()
	var currentConnectionState	= .idle as matrixConnectionState
	var	timeoutTimer			= NSTimer()
	var sendENQTimer			= NSTimer()
	
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
			println("Setting serialPort: old: \(oldValue) new: \(serialPort)")
			oldValue?.close()
			oldValue?.delegate						= nil
			serialPort?.delegate					= self
			serialPort?.allowsNonStandardBaudRates	= true

		}
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
/***********************  Overrides Methods         *************************/
//
// MARK: - Overrides
//
	
	// override NIB name to be loaded
	override var windowNibName: String {
		return "MainWindowController"
	}

/*--------------------------------------------------------------------------*\
 
 Function:		override windowDidLoad()
 
 Description:	initalizes everything needed to display window and views
 
\*--------------------------------------------------------------------------*/
	
    override func windowDidLoad() {

		super.windowDidLoad()
		
		myMatrixView!.delegate				= self
		imageCodeTabView!.delegate			= self
		
		let myFont = NSFont.userFixedPitchFontOfSize(CGFloat(12))
		codeTextView.font = myFont!

		portSettingsDrawer.preferredEdge	= (NSMaxXEdge)
		
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
	
		setDockIconAsMatrixView()

	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		override validateMenuItem(menuItem: NSMenuItem) -> Bool
 
 Description:	validate menu items dynamically; checks if port is open, and
				disables / enables as needed
	
\*--------------------------------------------------------------------------*/

	override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
		
		// check if action method is for portSelect NSPopUpButton
		if(menuItem.action == Selector("portSelectMenuClicked:")) {
			let serialPortItem = menuItem.representedObject as! ORSSerialPort
			// check if port is open, if so, then disable menu item
			if(serialPortItem.open == true) {
				return false
			} else {
				return true
			}
		// menuItem not from portSelect: NSPopUpButton, validate as true
		} else {
			return super.validateMenuItem(menuItem)
		}
	}

/***********************  Action Methods            *************************/
//
// MARK: - Actions
//
	
/*--------------------------------------------------------------------------*\
 
 Function:		toolbarNewWindow(sender: AnyObject)
 
 Description:	Action method for "New" toolbar button;
				called AppDelegate to add new windowcontroller to app
 
\*--------------------------------------------------------------------------*/
	
	
	@IBAction func toolbarNewWindow(sender: AnyObject) {
		
		let appDelegate = NSApplication.sharedApplication().delegate as? AppDelegate
		appDelegate!.addWindowController()
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		toolbarResetMatrix(sender: AnyObject)
 
 Description:	Action method for "Reset" toolbar button;
				clears model array and resets matrix view
 
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
 
 Function:		toolbarRotateRight(sender: AnyObject)
 
 Description:	Action method for rotate "Right" toolbar button
				transforms matrix model array to right
 
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
 
 Function:		toolbarRotateRight(sender: AnyObject)
 
 Description:	Action method for rotate "Left" toolbar button
				transforms matrix model array to left
 
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
	
 Function:		connectButtonClicked(sender: NSButton)
 
 Description:	Action method called when "Connect" button called from drawer;
				attempts to open selected serial port
 
\*--------------------------------------------------------------------------*/
	
	@IBAction func connectButtonClicked(sender: NSButton) {
		
		var string = ""
		
		// check if portOpen flag is set
		if isPortOpen == false {

			// check if selected port is not opened in another instance (window)
			let localPort = portSelection.selectedItem!.representedObject as? ORSSerialPort
			
			// check if port is open in another window
			if(localPort!.open == false) {
				serialPort = localPort
				serialPort?.baudRate = portBaudRate!.titleOfSelectedItem!.toInt()!
				serialPort?.numberOfStopBits = 1
				serialPort?.parity = ORSSerialPortParity.None
				serialPort?.open()
				string = "Opening Port \(serialPort!.path) baud: \(serialPort!.baudRate)\n"
			} else {
				let alert = NSAlert()
				alert.icon				= NSImage(named: NSImageNameCaution)
				alert.messageText		= "Port Already In Use!"
				alert.informativeText	= "\"\(localPort!.path)\"\nis currently in use, please select another port!"
				alert.addButtonWithTitle("OK")
				alert.beginSheetModalForWindow(window!, completionHandler: nil )
			}
			
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

/*********************** LEDMatrixViewDelegate     **************************/
//
// MARK: - LEDMatrixViewDelegate
//
	
/*--------------------------------------------------------------------------*\
 
 Function:		valueForMatrixAtLogicalX(logicalX: Int, logicalY: Int) -> Int
 
 Description:	called when model data value is needed for matrix display
 
 
\*--------------------------------------------------------------------------*/
	
	func valueForMatrixAtLogicalX(logicalX: Int, logicalY: Int) -> Int {
		
		// return value for pixel at (logicalX, logicalY)
		return ledStatusArray[logicalX][logicalY]

	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		nextValueForMatrixAtLogicalX(logicalX: Int, logicalY: Int)
 
 Description:	called when model data needs to be updated
 
\*--------------------------------------------------------------------------*/
	
	func nextValueForMatrixAtLogicalX(logicalX: Int, logicalY: Int) {

		// update model data for pixel location (logicalX, logicalY)
		ledStatusArray[logicalX][logicalY]++
		if ledStatusArray[logicalX][logicalY] == myMatrixView.imageArray.count {
			ledStatusArray[logicalX][logicalY] = 0
		}
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		matrixViewDidChange(rangeForX: NSRange, rangeForY: NSRange)
 
 Description:	called when matrix view has changed
 
\*--------------------------------------------------------------------------*/
	
	func matrixViewDidChange(rangeForX: NSRange, rangeForY: NSRange) {
		
		// if currently connected to hardware, send update to serial port
		if currentConnectionState == .connected {
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

		// update dock icon
		setDockIconAsMatrixView()
	}
	
/*********************** ORSSerialPortDelegate      *************************/
//
// MARK: - ORSSerialPortDelegate
//
	
/*--------------------------------------------------------------------------*\
 
 Function:		serialPortWasOpened(serialPort: ORSSerialPort)
 
 Description:	called when requested port is opened;
				set environment for active open port
 
\*--------------------------------------------------------------------------*/
	
	func serialPortWasOpened(serialPort: ORSSerialPort) {
		
		// update UI elements
		portOpenCloseButton.title	= "Disconnect"
		portSelection.enabled		= false
		portBaudRate.enabled		= false
		isPortOpen					= true
		
		// set flag to wait for hardware to initalize and set a timer
		currentConnectionState		= .connecting

		// Set a timer to fire off every 2 seconds sending an ENQ char
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
 
 Function:		serialPortWasClosed(serialPort: ORSSerialPort)

 Description:	called when request port is closed
 
\*--------------------------------------------------------------------------*/
	
	func serialPortWasClosed(serialPort: ORSSerialPort) {
		
		// update UI elements and flages
		portOpenCloseButton.title	= "Connect"
		portSelection.enabled		= true
		portBaudRate.enabled		= true
		isPortOpen					= false
		currentConnectionState		= .idle
		
		// cancel timers
		sendENQTimer.invalidate()
		timeoutTimer.invalidate()
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		serialPort(serialPort: ORSSerialPort, didReceiveData data: NSData)
 
 Description:	received data from serial port
 
\*--------------------------------------------------------------------------*/
	
	func serialPort(serialPort: ORSSerialPort, didReceiveData data: NSData) {

		// data has been received from the hardware, send to method to process
		receivedDataFromHardware(data)
//		if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
//			print(string)
//		}
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
 
 Description:	called when current selected serial port is removed;
				handle as an error condition

 
\*--------------------------------------------------------------------------*/
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {

		// TODO: NSAlert for port removed
		self.serialPort = nil
		sendENQTimer.invalidate()
		timeoutTimer.invalidate()
		currentConnectionState	= .idle
		self.portOpenCloseButton.title = "Connect"
		
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError)
 
 Description:	handle serial port errors
 
\*--------------------------------------------------------------------------*/
	
	func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
		
		// TODO: NSAlert for serialPort error
		println("SerialPort \(serialPort) encountered an error: \(error)")
		
	}

/*********************** NSWindowDelegate           *************************/
//
// MARK: - NSWindowDelegate
//
	
/*--------------------------------------------------------------------------*\
 
 Function:		windowDidBecomeKey(notification: NSNotification)
 
 Description:	sets app dock icon to match key window
 
\*--------------------------------------------------------------------------*/

	
	func windowDidBecomeKey(notification: NSNotification) {
		setDockIconAsMatrixView()
	}

/*********************** NSTabViewDelegate          *************************/
//
// MARK: - NSTabViewDelegate
//

/*--------------------------------------------------------------------------*\
 
 Function:		tabview(tabView: NSTabView, 
						willSelectTabViewItem: NSTabViewItem?)
 
 Description:	delegate called when new tab view selected;
				processes new tab as needed
 
 Returns:		void
 
\*--------------------------------------------------------------------------*/

	
	func tabView(tabView: NSTabView, willSelectTabViewItem: NSTabViewItem?) {
		switch(willSelectTabViewItem!.label) {
//			case "Image":
//				println("contentview: \(tabView.contentRect) tabViewItem: \(willSelectTabViewItem)")
//			break
			
			case "Code":
				createCodeFromMatrix()
			break
			
			default:
			break
			
		}
	}
	
/*********************** ORSSerialPortNotifications *************************/
//
// MARK: - ORSSerialPort Notifications
//
	
/*--------------------------------------------------------------------------*\
 
 Function:		serialPortsWereConnected(notification: NSNotification)
 
 Description:	called when ports added to system; adds ports to menu
 
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
 
 Function:		serialPortsWereDisconnected(notification: NSNotification)
 
 Description:	called when ports removed from system; remove ports from menu
	
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
	
/*********************** Timers                    *************************/
//
// MARK: - Timers
//
	
/*--------------------------------------------------------------------------*\
 
 Function:		matrixFailedToSync()
 
 Description:	called from timer - if ACK not received from matrix,
				gracefully fail to connect
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/

	
	func matrixFailedToSync() {
		println("Failed to connect to matrix")
		currentConnectionState = .idle
		sendENQTimer.invalidate()
		serialPort!.close()
	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		sendENQToSyncMatrix()
 
 Description:	called from timer - sends ENQ char to open serial port
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/

	
	func sendENQToSyncMatrix() {
		println("Sending ENQ Char.....")
		dataToSend.appendByte(controlCharENQ)
		serialPort?.sendData(dataToSend)
		dataToSend.length = 0
	}

/*********************** Helpers                    *************************/
//
// MARK: - Helpers
//
	
/*--------------------------------------------------------------------------*\
 
 Function:		setDockIconAsMatrixView()
 
 Description:	retreives image buffer from matrix view and sets as dock icon
 
 Parameters:	void
 Returns:		void
 
\*--------------------------------------------------------------------------*/

	
	func setDockIconAsMatrixView() {

		NSApplication.sharedApplication().applicationIconImage =
			myMatrixView.imageForMatrixView

	}
	
/*--------------------------------------------------------------------------*\
 
 Function:		receivedDataFromHardware(rxData: NSData)
 
 Description:	processes incoming data from serial port
 
 Parameters:	rxData - data received
 Returns:		void
 
\*--------------------------------------------------------------------------*/
	
	func receivedDataFromHardware(rxData: NSData) {
		
		var rxDataByteArray = [UInt8](count: rxData.length, repeatedValue: 0)
		rxData.getBytes(&rxDataByteArray, length: rxData.length)
		
		switch currentConnectionState {
			
		case .connecting:
			
			for rxByte in rxDataByteArray {
				if rxByte == controlCharACK {
					timeoutTimer.invalidate()
					sendENQTimer.invalidate()
					currentConnectionState = .connected
					rxDataByteArray.removeAll(keepCapacity: false)
					println()
					println("Connected to matrix, rx'd ACK, refreshing display.")
					myMatrixView.refreshMatrix()
				} else {
					print(rxByte.asChar())
				}
			}
			break
			
		case .connected:
			for rxByte in rxDataByteArray {
				print(rxByte.asChar())
			}
			break
			
		default:
			break
			
		}
		
	}

/*--------------------------------------------------------------------------*\
 
 Function:		createCodeFromMatrix()
 
 Description:	creates the 'C' code array that describes the matrix view

\*--------------------------------------------------------------------------*/

	func createCodeFromMatrix() {
		
		var redByte:		UInt8 = 0
		var greenByte:		UInt8 = 0
		
		var currentByte:	UInt8 = 0
		
		let msbSetByte:		UInt8 = 0b10000000
		
		var redString:		String	= ""
		var greenString:	String	= ""
		
		var redStringForComment:	String = ""
		var greenStringForComment:	String = ""
		
		codeTextView.textStorage!.mutableString.setString("")
		codeTextView.editable = true

		codeTextView.insertText("const uint8_t matrix_image[][8] =\n{\n")
		
		for y in 0..<myMatrixView.rowCount {
			
			// for each row, get values for each coluumn
			for x in 0..<myMatrixView.columnCount {
				currentByte = msbSetByte >> UInt8(x)
				let color = ledStatusArray[x][y]
				switch(UInt8(color)) {
					case pixelColor.Red.rawValue:
						redByte		|= currentByte
						greenByte	&= ~currentByte
						redStringForComment		+= "+"
						greenStringForComment	+= " "
					break
					
					case pixelColor.Green.rawValue:
						redByte		&= ~currentByte
						greenByte	|= currentByte
						redStringForComment		+= " "
						greenStringForComment	+= "+"
					break
					
					case pixelColor.Orange.rawValue:
						redByte		|= currentByte
						greenByte	|= currentByte
						redStringForComment		+= "+"
						greenStringForComment	+= "+"
					break
					
					default:
						redStringForComment		+= " "
						greenStringForComment	+= " "
					break
				}
			}
			redString	+= String(format: "\t\t0x%02X", redByte)
			greenString	+= String(format: "\t\t0x%02X", greenByte)

			// FIXME: DONT USE (-1)
			if(y < (myMatrixView.rowCount - 1)) {
				redString	+= ","
				greenString += ","
			}
			redString	+= "\t// |" + redStringForComment	+ "|\n"
			greenString	+= "\t// |" + greenStringForComment + "|\n"

			redByte = 0;				greenByte = 0
			redStringForComment = "";	greenStringForComment = ""
			
		}
		
		codeTextView.insertText("\t{\t\t\t// RED\n")
		codeTextView.insertText(redString)
		codeTextView.insertText("\t},\n")
		codeTextView.insertText("\t{\t\t\t// GREEN\n")
		codeTextView.insertText(greenString)
		codeTextView.insertText("\t}\n")
		codeTextView.insertText("}\n")
		codeTextView.editable = false

	}

/*********************** End Window Controller      *************************/

}
