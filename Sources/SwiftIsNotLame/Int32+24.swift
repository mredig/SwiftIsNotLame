import Foundation

extension Int32 {
	func convert24bitTo32() throws -> Int32 {
		var bit24 = UInt32(bitPattern: self) & 0xFF_FF_FF

		let int24Sign: UInt32 = 0x80_00_00
		let signed = (int24Sign & bit24) == int24Sign

		if signed {
			bit24 = bit24 | 0xFF_00_00_00
		}

		var double = Double(Int32(bitPattern: bit24))
		double *= Double(Int32.max) / Double(0x7FFFFF)

		return Self(double)
	}
}
