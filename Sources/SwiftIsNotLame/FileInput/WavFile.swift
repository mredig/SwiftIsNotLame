import Foundation

public class WavFile: BinaryFile {
	static let wavMagic = try! "RIFF".toMagicNumber()
	static let wavIDFmt = try! "fmt ".toMagicNumber()
	static let wavIDWave = try! "WAVE".toMagicNumber()
	static let wavIDData = try! "data".toMagicNumber()
	static let wavExtesible: UInt16 = 0xFFFE
	static let wavFormatPCM: UInt16 = 0x01
	static let wavFormatIEEEFloat: UInt16 = 0x03

	private var sampleDataPointerOffsetStart = 0

	public private(set) var wavInfo: WavInfo?

	public struct WavInfo {
		public enum WavFormat {
			case pcm
			case float

			init(from value: UInt16) throws {
				switch value {
				case WavFile.wavFormatPCM:
					self = .pcm
				case WavFile.wavFormatIEEEFloat:
					self = .float
				default:
					throw WavError.notSupported("Non PCM and float wavs are unsupported")
				}
			}
		}
		public let totalSampleSize: Int
		public let format: WavFormat
		public let channels: SwiftIsNotLame.ChannelCount
		public let sampleRate: SwiftIsNotLame.SampleRate
		public let bitsPerSample: Int
		public var bytesPerSample: Int { bitsPerSample / 8 }
		public var totalSamples: Int {
			totalSampleSize / (channels.rawValue * (bitsPerSample / 8)) - (bitsPerSample == 24 ? 1 : 0)
		}

		func settingTotalSampleSize(_ value: Int) -> Self {
			return WavInfo(
				totalSampleSize: value,
				format: format,
				channels: channels,
				sampleRate: sampleRate,
				bitsPerSample: bitsPerSample)
		}
	}

	override public init(filePath: URL) throws {
		try super.init(filePath: filePath)
		try processHeader()
	}

	// MARK: - Wav channel conveniences
	/// Channel value is 0 indexed - if there are two channels, channel 0 and channel 1 are valid values.
	public func sample<BitRep: FixedWidthInteger>(at offset: Int, channel: Int) throws -> BitRep {
		guard
			let info = wavInfo,
			channel < info.channels.rawValue
		else { throw WavError.genericError("Requested sample for channel that doesnt exist") }

		let totalOffsetFromDataPointer = sampleDataPointerOffsetStart + (offset * info.channels.rawValue * info.bytesPerSample) + (info.bytesPerSample * channel)

		return try read(single: BitRep.self, byteOrder: .littleEndian, startingAt: UInt64(totalOffsetFromDataPointer))
	}

	/// Channel value is 0 indexed - if there are two channels, channel 0 and channel 1 are valid values.
	public func channelBuffer<BitRep: FixedWidthInteger>(channel: Int) throws -> ContiguousArray<BitRep> {
		guard let info = wavInfo else { return [] }
		let totalSamples = info.totalSamples
		let is24Bit = info.bitsPerSample == 24

		var channelBuffer = ContiguousArray<BitRep>(unsafeUninitializedCapacity: totalSamples) { _, _ in }
		for sampleIndex in (0..<totalSamples) {
			var thisSample: BitRep = try sample(at: sampleIndex, channel: channel)
			if is24Bit {
				thisSample = try (thisSample as? Int32)?.convert24bitTo32() as! BitRep
			}
			channelBuffer.append(thisSample)
		}

		return channelBuffer
	}

	// MARK: - Wav byte reading
	public func processHeader() throws {
		// header
		let magic = try read(4).convertedToU32()
		guard magic == Self.wavMagic else { throw WavError.notWavFile }

		_ = try read(4) // file length
		let wavId = try read(4).convertedToU32()
		guard wavId == Self.wavIDWave else { throw WavError.corruptWavFile("No WAVE id chunk") }

		var info: WavInfo?

		let loopSanity = 20
		loop: for _ in 0..<loopSanity {
			let chunkType = try read(4).convertedToU32()

			switch chunkType {
			case Self.wavIDFmt:
				info = try readFMTChunk()
			case Self.wavIDData:
				let size = try read(4, byteOrder: .littleEndian).convertedToU32()
				self.sampleDataPointerOffsetStart = Int(offset)
				self.wavInfo = info?.settingTotalSampleSize(Int(size))
				break loop
			default:
				let size = try read(4, byteOrder: .littleEndian)
					.convertedToU32()
					.madeEven()
				let offset = try handle.handleOffset()
				try handle.handleSeek(toOffset: offset + UInt64(size))
			}
		}
	}

	/// returns a WavInfo, but incomplete without the totalSampleSize
	private func readFMTChunk() throws -> WavInfo {
		var sizeRemaining = try read(4, byteOrder: .littleEndian)
			.convertedToU32()
			.madeEven()

		guard sizeRemaining >= 16 else { throw WavError.corruptWavFile("fmt chunk too small")}

		let formatTag = try read(2, byteOrder: .littleEndian).converted(to: UInt16.self)
		sizeRemaining -= 2
		guard
			[Self.wavFormatPCM].contains(formatTag)
		else { throw WavError.notSupported("Only support PCM Wave format") }

		let channels = try read(single: UInt16.self, byteOrder: .littleEndian)
		sizeRemaining -= 2

		let samplesPerSecond = try read(4, byteOrder: .littleEndian).convertedToU32()
		sizeRemaining -= 4

		_ = try read(4) // avg bytes/sec
		_ = try read(2) // block align
		sizeRemaining -= 6

		let bitsPerSample = try read(2, byteOrder: .littleEndian).converted(to: UInt16.self)
		sizeRemaining -= 2
		guard
			bitsPerSample.isMultiple(of: 8)
		else { throw WavError.corruptWavFile("Bits per sample is not divisible by 8") }

		return WavInfo(
			totalSampleSize: -1,
			format: try WavInfo.WavFormat(from: formatTag),
			channels: try SwiftIsNotLame.ChannelCount(from: Int(channels)),
			sampleRate: try SwiftIsNotLame.SampleRate(from: Int(samplesPerSecond)),
			bitsPerSample: Int(bitsPerSample))
	}

	enum WavError: Error {
		case notWavFile
		case corruptWavFile(_ description: String?)
		case notSupported(_ description: String?)
		case genericError(_ description: String?)
		case unknown
	}
}

enum ConversionError: Error {
	case not32bit
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
