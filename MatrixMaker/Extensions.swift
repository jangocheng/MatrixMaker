//
//  Extensions.swift
//  MatrixMaker
//
//  Created by Justin England on 7/1/15.
//  Copyright (c) 2015 Justin England. All rights reserved.
//

import Foundation

extension NSMutableData {
	func appendByte(var b: UInt8) {
		self.appendBytes(&b, length: 1)
	}
}

extension UInt8 {
	func asChar() -> Character {
		return Character(UnicodeScalar(Int(self)))
	}
}