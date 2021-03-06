import Foundation

public class CafFile: BinaryFile {
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

		static let pcmFormatFloatFlag = 1 << 0
		static let pcmFormatLittleEndianFlag = 1 << 1
	}

	private var sampleDataPointerOffsetStart = 0

	struct CafInfo {
		let totalSampleSize: Int
//		let format: Audio
		let channels: SwiftIsNotLame.ChannelCount
		let sampleRate: SwiftIsNotLame.SampleRate
		let bitsPerSample: Int
		var bytesPerSample: Int { bitsPerSample / 8 }
		var totalSamples: Int {
			totalSampleSize / (channels.rawValue * bytesPerSample)
		}
	}

	public func processHeader() throws {
		let magic = try read(4).convertedToU32()
		guard magic == Self.caffMagic else { throw CafError.notCafFile }

		let fileVersion = try read(2).converted(to: UInt16.self) // file version
		guard fileVersion == 1 else { throw CafError.corruptCafFile("invalid file version: \(fileVersion)") }
		_ = try read(2) // file flags

//		var info: CafInfo?
//
//		let loopSanity = 20
//		loop: for _ in 0..<loopSanity {
//			let chunkType = try read(4).convertedToU32()
//			let chunkSize = try read(8).converted(to: Int64.self)
//
//			switch chunkType {
//			case ChunkType.desc:
//				let sampleRate = try read(8).converted(to: Double.self)
//			default:
//				<#code#>
//			}
//		}
	}

	enum CafError: Error {
		case notCafFile
		case corruptCafFile(_ description: String?)
	}
}
