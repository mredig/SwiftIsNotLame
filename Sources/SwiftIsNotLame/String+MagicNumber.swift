import Foundation

extension String {
	/// Don't use on strings longer than 4 utf8 characters long
	/// uses a common methodology to convert strings to numerical values for magic numbers
	func toMagicNumber() -> UInt32 {
		utf8
		.reversed()
		.enumerated()
		.map { (index, byte) in
			UInt32(byte) << (index * 8)
		}
		.reduce(0, |)
	}
}
