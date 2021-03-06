import Foundation

extension Array where Element == UInt8 {
	enum DataError: Error {
		case incorrectByteCount
	}
	func converted<BitRep: BitConversion>(to type: BitRep.Type) throws -> BitRep {

		let byteSize = MemoryLayout<BitRep>.size
		guard count == byteSize else { throw DataError.incorrectByteCount }

		/*
		// this is what the code used to be, but ended up being 3-4x less efficient
		return reversed()
			.enumerated()
			.map { BitRep($0.element) << (8 * $0.offset) }
			.reduce(0, |)
		*/

		var outVal = UInt64(0)
		for index in 0..<count {
			let bitshift = count - index - 1
			outVal |= UInt64(self[index]) << (bitshift * 8)
		}
		return outVal.convertBitsTo()

		/*
		// this is a slightly faster, yet more complex/ugly alternative
		let alignment = MemoryLayout<BitRep>.alignment
		let unsafeBuffer = UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer.allocate(byteCount: byteSize, alignment: alignment), count: byteSize)

		for index in 0..<count {
			let invertedIndex = count - index - 1
			unsafeBuffer[index] = self[invertedIndex]
		}

		return try unsafeBuffer.bindMemory(to: BitRep.self).first.unwrap()
		*/
	}

	func convertedToU32() throws -> UInt32 {
		try converted(to: UInt32.self)
	}
}

extension FixedWidthInteger {
	func madeEven() -> Self {
		self.isMultiple(of: 2) ? self : self + 1
	}

	mutating func makeEven() {
		self = madeEven()
	}
}
