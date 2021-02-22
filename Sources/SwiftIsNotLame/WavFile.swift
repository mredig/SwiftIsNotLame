import Foundation

public class WavFile {
	static let wavMagic = try! "RIFF".toMagicNumber()
	static let wavIDFmt = try! "fmt ".toMagicNumber()
	static let wavIDWave = try! "WAVE".toMagicNumber()
	static let wavIDData = try! "data".toMagicNumber()
	static let wavExtesible: UInt16 = 0xFFFE
	static let wavFormatPCM: UInt16 = 0x01
	static let wavFormatIEEEFloat: UInt16 = 0x03

	let sourceData: Data

	private var pointerOffset = 0

	private var totalSampleSize = 0
	private var sampleDataPointerOffsetStart = 0

	public private(set) var format: UInt16?
	public private(set) var channels: Int?
	public private(set) var samplesPerSecond: Int?
	public private(set) var bitsPerSample: Int?
	public var bytesPerSample: Int? { bitsPerSample.map { $0 / 8} }
	public private(set) var totalSamples: Int?

	public init(sourceData: Data) {
		self.sourceData = sourceData
	}

	/// Channel value is 0 indexed - if there are two channels, channel 0 and channel 1 are valid values.
	public func sample<BitRep: FixedWidthInteger>(at offset: Int, channel: Int) throws -> BitRep {
		let startOffset = pointerOffset
		defer { pointerOffset = startOffset }

		guard
			let channels = channels,
			channel < channels
		else { throw WavError.genericError("Requested sample for channel that doesnt exist") }

		let totalOffsetFromDataPointer = sampleDataPointerOffsetStart + (offset * channels * bytesPerSample!) + (bytesPerSample! * channel)

		return try read(single: BitRep.self, byteOrder: .littleEndian, startingAt: totalOffsetFromDataPointer)
	}

	/// Channel value is 0 indexed - if there are two channels, channel 0 and channel 1 are valid values.
	public func channelBuffer<BitRep: FixedWidthInteger>(channel: Int) throws -> ContiguousArray<BitRep> {
		guard let totalSamples = totalSamples else { return [] }
//		let is24Bit = bitsPerSample == 24

		var channelBuffer = ContiguousArray<BitRep>(unsafeUninitializedCapacity: totalSamples) { _, _ in }
		for sampleIndex in (0..<totalSamples) {
			let thisSample: BitRep = try sample(at: sampleIndex, channel: channel)
			channelBuffer.append(thisSample)
		}

		return channelBuffer
	}

	public func decode() throws {
		// header
		let magic = try read(4).convertedToU32()
		guard magic == Self.wavMagic else { throw WavError.notWavFile }

		_ = read(4) // file length
		let wavId = try read(4).convertedToU32()
		guard wavId == Self.wavIDWave else { throw WavError.corruptWavFile("No WAVE id chunk") }

		let loopSanity = 20
		loop: for _ in 0..<loopSanity {
			let chunkType = try read(4).convertedToU32()

			switch chunkType {
			case Self.wavIDFmt:
				try readFMTChunk()
			case Self.wavIDData:
				let size = try read(4, byteOrder: .littleEndian).convertedToU32()
				self.totalSampleSize = Int(size)
				self.sampleDataPointerOffsetStart = pointerOffset
				break loop
			default:
				let size = try read(4, byteOrder: .littleEndian)
					.convertedToU32()
					.madeEven()
				pointerOffset += Int(size)
			}
		}

		guard
			let channels = channels,
			let bitsPerSample = bitsPerSample
		else { throw WavError.unknown }

		totalSamples = totalSampleSize / (channels * (bitsPerSample / 8))
		print("here")
	}

	private func readFMTChunk() throws {
		var sizeRemaining = try read(4, byteOrder: .littleEndian)
			.convertedToU32()
			.madeEven()

		defer { pointerOffset += Int(sizeRemaining) }

		guard sizeRemaining >= 16 else { throw WavError.corruptWavFile("fmt chunk too small")}

		let formatTag = try read(2, byteOrder: .littleEndian).converted(to: UInt16.self)
		self.format = formatTag
		sizeRemaining -= 2
		guard
			[Self.wavFormatPCM].contains(formatTag)
		else { throw WavError.notSupported("Only support PCM Wave format") }

//		let channels = try read(2, byteOrder: .littleEndian).converted(to: UInt16.self)
		let channels = try read(single: UInt16.self, byteOrder: .littleEndian)
		self.channels = Int(channels)
		sizeRemaining -= 2

		let samplesPerSecond = try read(4, byteOrder: .littleEndian).convertedToU32()
		self.samplesPerSecond = Int(samplesPerSecond)
		sizeRemaining -= 4

		_ = read(4) // avg bytes/sec
		_ = read(2) // block align
		sizeRemaining -= 6

		let bitsPerSample = try read(2, byteOrder: .littleEndian).converted(to: UInt16.self)
		self.bitsPerSample = Int(bitsPerSample)
		sizeRemaining -= 2
		guard
			bitsPerSample.isMultiple(of: 8)
		else { throw WavError.corruptWavFile("Bits per sample is not divisible by 8") }
	}

	// MARK: - Generic byte reading
	enum ByteOrder {
		case bigEndian
		case littleEndian
	}

	private func read(_ byteCount: Int, byteOrder: ByteOrder = .bigEndian, startingAt offset: Int? = nil) -> [UInt8] {
		let startOffset = offset ?? pointerOffset
		let endOffset = startOffset + byteCount

		let bytes = sourceData[startOffset..<endOffset]

		pointerOffset = endOffset
		switch byteOrder {
		case .bigEndian:
			return Array(bytes)
		case .littleEndian:
			return bytes.reversed()
		}
	}

	private func read<BitRep: FixedWidthInteger>(single type: BitRep.Type, byteOrder: ByteOrder = .bigEndian, startingAt offset: Int? = nil) throws -> BitRep {
		let size = MemoryLayout<BitRep>.size
		return try read(size, byteOrder: byteOrder, startingAt: offset)
			.converted(to: BitRep.self)
	}

	enum WavError: Error {
		case notWavFile
		case corruptWavFile(_ description: String?)
		case notSupported(_ description: String?)
		case genericError(_ description: String?)
		case unknown
	}
}


extension Array where Element == UInt8 {
	enum DataError: Error {
		case incorrectByteCount
	}
	func converted<BitRep: FixedWidthInteger>(to type: BitRep.Type) throws -> BitRep {

		let byteSize = MemoryLayout<BitRep>.size
		guard count == byteSize else { throw DataError.incorrectByteCount }

		/*
		// this is what the code used to be, but ended up being 3-4x less efficient
		return reversed()
			.enumerated()
			.map { BitRep($0.element) << (8 * $0.offset) }
			.reduce(0, |)
		*/

		var outVal = BitRep(0)
		for index in 0..<count {
			let bitshift = count - index - 1
			outVal |= BitRep(self[index]) << (bitshift * 8)
		}
		return outVal

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
