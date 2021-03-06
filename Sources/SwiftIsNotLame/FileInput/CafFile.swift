import Foundation

public class CafFile: AudioBinaryFile {
	static let caffMagic = try! "caff".toMagicNumber()
	struct ChunkType {
		static let desc = try! "desc".toMagicNumber()
		static let data = try! "data".toMagicNumber()
		static let free = try! "free".toMagicNumber()
	}

	struct AudioFormat {
		static let linearPCM = try! "lpcm".toMagicNumber()
		static let appleIMA4 = try! "ima4".toMagicNumber()
		static let mPEG4AAC = try! "aac ".toMagicNumber()
		static let mACE3 = try! "MAC3".toMagicNumber()
		static let mACE6 = try! "MAC6".toMagicNumber()
		static let uLaw = try! "ulaw".toMagicNumber()
		static let aLaw = try! "alaw".toMagicNumber()
		static let mPEGLayer1 = try! ".mp1".toMagicNumber()
		static let mPEGLayer2 = try! ".mp2".toMagicNumber()
		static let mPEGLayer3 = try! ".mp3".toMagicNumber()
		static let appleLossless = try! "alac".toMagicNumber()

		static let pcmFormatFloatFlag: UInt32 = 1 << 0
		static let pcmFormatLittleEndianFlag: UInt32 = 1 << 1
	}

	private var sampleDataPointerOffsetStart: UInt64 = 0

//	struct CafInfo {
//		let totalSampleSize: Int
////		let format: Audio
//		let channels: SwiftIsNotLame.ChannelCount
//		let sampleRate: SwiftIsNotLame.SampleRate
//		let bitsPerSample: Int
//		var bytesPerSample: Int { bitsPerSample / 8 }
//		var totalSamples: Int {
//			totalSampleSize / (channels.rawValue * bytesPerSample)
//		}
//	}

	public private(set) var _audioInfo: SwiftIsNotLame.AudioInfo?
	public override var audioInfo: SwiftIsNotLame.AudioInfo? { _audioInfo }

	typealias CafInfo = SwiftIsNotLame.AudioInfo

	override init(filePath: URL) throws {
		try super.init(filePath: filePath)
		try processHeader()
	}

	public func processHeader() throws {
		let magic = try read(4).convertedToU32()
		guard magic == Self.caffMagic else { throw CafError.notCafFile }

		let fileVersion = try read(2).converted(to: UInt16.self) // file version
		guard fileVersion == 1 else { throw CafError.corruptCafFile("invalid file version: \(fileVersion)") }
		_ = try read(2) // file flags

		var info: CafInfo?

		let loopSanity = 20
		loop: for _ in 0..<loopSanity {
			let chunkType = try read(4).convertedToU32()
			let chunkSize = try read(8).converted(to: Int64.self)

			switch chunkType {
			case ChunkType.desc:
				info = try readDescChunk(size: chunkSize)
			case ChunkType.data:
				_ = try read(4) // edit count UInt32
				self.sampleDataPointerOffsetStart =	offset
				self._audioInfo = info?.settingTotalSampleSize(Int(chunkSize - 4))
				break loop
			default:
				try skip(Int(chunkSize))
			}
		}
	}

	private func readDescChunk(size: Int64) throws -> CafInfo {
		let readSampleRate = try read(8).converted(to: Double.self)
		let readFormatID = try read(4).converted(to: UInt32.self)
		let readFormatFlags = try read(4).converted(to: UInt32.self)
		let readBytesPerPacket = try read(4).converted(to: UInt32.self)
		let readFramesPerPacket = try read(4).converted(to: UInt32.self)
		let readChannels = try read(4).converted(to: UInt32.self)
		let readBitsPerChannel = try read(4).converted(to: UInt32.self)

		guard
			readFormatID == AudioFormat.linearPCM
		else { throw CafError.unsupportedFileType("Only support linear PCM at this time") }

		let isFloat = (readFormatFlags & AudioFormat.pcmFormatFloatFlag) != 0
		let isLittleEndian = (readFormatFlags & AudioFormat.pcmFormatLittleEndianFlag) != 0

		let format: SwiftIsNotLame.AudioInfo.AudioFormat = isFloat ? .float : .pcm

		guard
			readFramesPerPacket == 1
		else { throw CafError.unsupportedCafFile("Compressed Caf files not supported.") }

		guard
			readBytesPerPacket == (readBitsPerChannel / 8)
		else {
			throw CafError.unsupportedCafFile(
				"""
				FIX THIS SOON - mismatch between bytes and bitcount per sample. This SHOULD be \
				supported. (ex. 24bit samples taking 32bits of padded space)
				""")
		}
		guard
			isLittleEndian == true
		else {
			throw CafError.unsupportedCafFile(
				"""
				FIX THIS SOON - big endian data not currently supported
				""")
		}

		let channels: SwiftIsNotLame.ChannelCount
		switch readChannels {
		case 1:
			channels = .one
		case 2:
			channels = .two
		default:
			throw CafError.unsupportedNumberOfChannels("Only support 1 or 2 channels. \(readChannels) provided")
		}

		let sampleRate: SwiftIsNotLame.SampleRate
		switch readSampleRate {
		case 44100:
			sampleRate = .hz44100
		case 48000:
			sampleRate = .hz48000
		default:
			throw CafError.unsupportedSampleRate("\(readSampleRate) is unsupported.")
		}

		return CafInfo(
			totalSampleSize: 0,
			format: format,
			channels: channels,
			sampleRate: sampleRate,
			bitsPerSample: Int(readBitsPerChannel))
	}

	enum CafError: Error {
		case notCafFile
		case corruptCafFile(_ description: String?)
		case unsupportedFileType(_ description: String?)
		case unsupportedCafFile(_ description: String?)
		case unsupportedNumberOfChannels(_ description: String?)
		case unsupportedSampleRate(_ description: String?)
	}
}

extension CafFile: AudioBinaryFileDelegate {
	func offsetForSample(_ sampleIndex: Int, channel: Int, audioInfo: SwiftIsNotLame.AudioInfo) -> (sampleOffset: Int, byteOrder: BinaryFile.ByteOrder) {
		fatalError("not implemented!")
	}
}
