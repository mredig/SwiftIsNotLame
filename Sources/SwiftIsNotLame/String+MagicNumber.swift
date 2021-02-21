import Foundation

extension String {
	/// Don't use on strings longer than 4 utf8 characters long.
	/// 
	/// uses a common methodology to convert strings to numerical values for magic numbers
	func toMagicNumber() throws -> UInt32 {
		try Array(utf8)
			.convertedToU32()
	}
}
