import XCTest
@testable import SwiftIsNotLame

final class BitConversionTests: XCTestCase {
	func testBits() {
		let binary = "01110101_00101101_01000101_01101010".replacingOccurrences(of: "_", with: "")
		let uint64 = UInt(binary, radix: 2)!
		let uint32 = uint64.convertBitsTo(UInt32.self)
		let float: Float = uint32.convertBitsTo()
		let double: Double = uint32.convertBitsTo()
		let uin32ret: UInt32 = double.convertBitsTo()

		let sixteen = uin32ret.convertBitsTo(Int16.self)

		let final32 = sixteen.convertBitsTo(type(of: uint32).self)

		func printer<T: BitConversion>(_ value: T) {
			print(value.toBin(), " - ", value)
		}

		printer(uint32)
		printer(float)
		printer(double)
		printer(uin32ret)
		printer(sixteen)
		printer(final32)
	}

}
