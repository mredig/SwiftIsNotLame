import Foundation

struct MyRNG: RandomNumberGenerator {
	let seed: UInt64
	var value: UInt64

	init(seed: UInt64 = UInt64(CFAbsoluteTimeGetCurrent() * 10000)) {
		self.seed = seed
		self.value = Self.randomNumber(seed: seed)
	}

	static func randomNumber(seed: UInt64, max: UInt64 = UInt64.max) -> UInt64 {
		let a: UInt64 = 16807
		let c: UInt64 = 12345
//		seed = (a * seed + c) % 2147483647
		let value = (a * seed + c) % 2147483647
		return value % max
	}

	mutating func next<T: FixedWidthInteger & UnsignedInteger>() -> T {
		let result = T(Self.randomNumber(seed: value, max: UInt64(T.max)))
		value = UInt64(result)
		return result
	}

	mutating func next<T>(upperBound: T) -> T where T : FixedWidthInteger, T : UnsignedInteger {
		let result = T(Self.randomNumber(seed: value, max: UInt64(upperBound)))
		value = UInt64(result)
		return result
	}
}
