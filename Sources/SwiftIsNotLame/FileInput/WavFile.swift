import Foundation

public class WavFile: AudioBinaryFile {
	static let wavMagic = try! "RIFF".toMagicNumber()
	static let wavIDFmt = try! "fmt ".toMagicNumber()
	static let wavIDWave = try! "WAVE".toMagicNumber()
	static let wavIDData = try! "data".toMagicNumber()
	static let wavExtesible: UInt16 = 0xFFFE
	static let wavFormatPCM: UInt16 = 0x01
	static let wavFormatIEEEFloat: UInt16 = 0x03

	private var sampleDataPointerOffsetStart = 0

	public private(set) var _audioInfo: SwiftIsNotLame.AudioInfo?
	public override var audioInfo: SwiftIsNotLame.AudioInfo? { _audioInfo }

	typealias WavInfo = SwiftIsNotLame.AudioInfo

	override public init(filePath: URL) throws {
		try super.init(filePath: filePath)
		try processHeader()
		delegate = self
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
				self._audioInfo = info?.settingTotalSampleSize(Int(size))
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
			[Self.wavFormatPCM, Self.wavFormatIEEEFloat].contains(formatTag)
		else { throw WavError.notSupported("Only support PCM Wave format") }
		let format: WavInfo.AudioFormat
		switch formatTag {
		case 3:
			format = .float
		default:
			format = .pcm
		}

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
			format: format,
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

extension WavFile: AudioBinaryFileDelegate {
	func offsetForSample(_ sampleIndex: Int, channel: Int, audioInfo: SwiftIsNotLame.AudioInfo, byteOrder: inout BinaryFile.ByteOrder) -> Int {
		sampleDataPointerOffsetStart + (sampleIndex * audioInfo.channels.rawValue * audioInfo.bytesPerSample) + (audioInfo.bytesPerSample * channel)
	}
}
