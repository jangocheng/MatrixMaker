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
							NSUserNotificationCenterDelegate,
							NSDrawerDelegate,
							ORSSerialPortDelegate,
							LEDMatrixViewDelegate {
	
	@IBOutlet weak var myMatrixView:		LEDMatrixView!
	@IBOutlet weak var portSettingsDrawer:  NSDrawer!
	@IBOutlet weak var portSettingsView:    NSView!
	@IBOutlet weak var portSelection:		NSPopUpButton!
	@IBOutlet weak var portBaudRate:        NSPopUpButton!
	@IBOutlet weak var portParity:			NSMatrix!
	@IBOutlet weak var portStopBits:		NSMatrix!
	@IBOutlet weak var portOpenCloseButton:	NSButton!
	
	var isPortOpen: Bool	= false
	var ledStatusArray		= [[Int]](count: 8, repeatedValue:[Int](count: 8, repeatedValue:0))
	var dataToSend:			NSMutableData!
	
	let serialPortManager	= ORSSerialPortManager.sharedSerialPortManager()
	let availableBaudRates	= [   300,  1200,  2400,  4800,   9600,  14400,
								19200, 28800, 38400, 57600, 115200, 230400]
	
	var serialPort: ORSSerialPort? {
		didSet {
			println("Setting serialPort")
			oldValue?.close()
			oldValue?.delegate = nil
			serialPort?.delegate = self
		}
	}
	
	
	override var windowNibName: String {
		return "MainWindowController"
	}

    override func windowDidLoad() {

		super.windowDidLoad()

		myMatrixView!.imageArray = [(NSImage(named: "led_off.png")!),
									(NSImage(named: "led_red.png")!),
									(NSImage(named: "led_green.png")!),
									(NSImage(named: "led_orange.png")!)]

		myMatrixView!.delegate				= self
		myMatrixView.needsDisplay			= true
		
		let drawerSize = NSMakeSize(CGFloat(225), CGFloat(500))
		
		portSettingsDrawer.minContentSize	= drawerSize
		portSettingsDrawer.maxContentSize	= drawerSize
		portSettingsDrawer.contentSize		= drawerSize
		portSettingsDrawer.preferredEdge	= NSMaxXEdge
		
		// create menu for serial port list
		portSelection.removeAllItems()
		for port in serialPortManager.availablePorts {
			portSelection.addItemWithTitle(port.name)
		}
		
		portBaudRate.selectItemWithTitle("115200")
		
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
			
			println("Parity: \(portParity.cellWithTag(portParity.selectedTag())?.titleOfSelectedItem)")
			
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
		portParity.enabled			= false
		portStopBits.enabled		= false
		isPortOpen					= true
		
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
		self.portParity.enabled			= true
		self.portStopBits.enabled		= true
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

		if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
			println(string)
		}
		
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
		
		let alert = NSAlert()
		//		alert.messageText = "Port Removed"
		//		alert.informativeText = "The selected serial port was removed from the system!"
		//      alert.runModal()
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


/*********************** End Window Controller      *************************/

}
