import Foundation

public class WavFile {
	static let wavMagic = "RIFF".toMagicNumber()
	static let wavIDFmt = "fmt ".toMagicNumber()
	static let wavIDWave = "WAVE".toMagicNumber()
	static let wavIDData = "data".toMagicNumber()
	static let wavExtesible: UInt16 = 0xFFFE
	static let wavFormatPCM: UInt16 = 0x01
	static let wavFormatIEEEFloat: UInt16 = 0x03

	let sourceData: Data

	private var pointerOffset: Int = 0

	public var format: UInt16?
	public var channels: Int?
	public var samplesPerSecond: Int?
	public var bitsPerSample: Int?

	public init(sourceData: Data) {
		self.sourceData = sourceData
	}

	public func decode() throws {
		// header
		let magic = try read(4).convertedToU32()
		guard magic == Self.wavMagic else { throw WavError.notWavFile }

		_ = read(4) // file length
		let wavId = try read(4).convertedToU32()
		guard wavId == Self.wavIDWave else { throw WavError.corruptWavFile("No WAVE id chunk") }

		let loopSanity = 20
		for _ in 0..<loopSanity {
			let chunkType = try read(4).convertedToU32()

			switch chunkType {
			case Self.wavIDFmt:
				try readFMTChunk()
			case Self.wavIDData:
				break
			default:
				let size = try read(4, byteOrder: .littleEndian)
					.convertedToU32()
					.madeEven()
				pointerOffset += Int(size)
			}
		}
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

		let channels = try read(2, byteOrder: .littleEndian).converted(to: UInt16.self)
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

	enum WavError: Error {
		case notWavFile
		case corruptWavFile(_ description: String?)
		case notSupported(_ description: String?)
	}
}


extension Array where Element == UInt8 {
	enum DataError: Error {
		case incorrectByteCount
	}
	func converted<BitRep: FixedWidthInteger>(to type: BitRep.Type) throws -> BitRep {

		let byteSize = MemoryLayout<BitRep>.size
		guard count == byteSize else { throw DataError.incorrectByteCount }

		return reversed()
			.enumerated()
			.map { BitRep($0.element) << (8 * $0.offset) }
			.reduce(0, |)
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
