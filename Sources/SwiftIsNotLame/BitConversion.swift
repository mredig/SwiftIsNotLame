import Foundation

public protocol BitConversion {
	func toBits() -> UInt64
}

public extension BitConversion {
	func convertBitsTo<T>(_ type: T.Type) -> T {
		convertBitsTo()
	}

	func convertBitsTo<T>() -> T {
		let layout = MemoryLayout<T>.self
		let size = layout.size
		let stride = layout.stride
		let alignment = layout.alignment

		let bits = toBits()

		let rawBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: stride, alignment: alignment)
		for i in 0..<Int(size) {
			let shift = i * 8
			rawBuffer[i] = UInt8(0xFF & (bits >> shift))
		}
		let newbuffer = rawBuffer.bindMemory(to: T.self)
		return newbuffer[0]
	}

	func toBin() -> String {
		let byteCount = MemoryLayout<Self>.size

		let bin = toBits()

		let bytes = (0..<byteCount)
			.map { 0xff & (bin >> (8 * $0)) }
			.map { UInt8($0) }
			.reversed()
		let strings = bytes
			.map { String($0, radix: 2) }
			.map { (string: String) -> String in
				let diff = 8 - string.count
				let zeros = String(repeating: "0", count: diff)
				return zeros + string
			}
			.joined(separator: " ")
		return strings
	}
}

extension UInt8: BitConversion {
	public func toBits() -> UInt64 { UInt64(self) }
}

extension UInt16: BitConversion {
	public func toBits() -> UInt64 { UInt64(self) }
}

extension UInt32: BitConversion {
	public func toBits() -> UInt64 { UInt64(self) }
}

extension UInt64: BitConversion {
	public func toBits() -> UInt64 { self }
}

extension UInt: BitConversion {
	public func toBits() -> UInt64 { UInt64(self) }
}

extension Int8: BitConversion {
	public func toBits() -> UInt64 { Int64(self).toBits() }
}

extension Int16: BitConversion {
	public func toBits() -> UInt64 { Int64(self).toBits() }
}

extension Int32: BitConversion {
	public func toBits() -> UInt64 { Int64(self).toBits() }
}

extension Int64: BitConversion {
	public func toBits() -> UInt64 { UInt64(bitPattern: self) }
}

extension Int: BitConversion {
	public func toBits() -> UInt64 { Int64(self).toBits() }
}

extension Float: BitConversion {
	public func toBits() -> UInt64 { bitPattern.toBits() }
}

extension Double: BitConversion {
	public func toBits() -> UInt64 { bitPattern }
}

extension CGFloat: BitConversion {
	public func toBits() -> UInt64 { bitPattern.toBits() }
}
