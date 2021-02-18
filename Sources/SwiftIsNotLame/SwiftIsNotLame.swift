import lame
import Foundation

class SwiftIsNotLame {

	private let lameGlobal = lame_init()

	enum ChannelCount: Int32 {
		case one = 1
		case two
	}

	var channels = ChannelCount.two

	enum SampleRate: Int32 {
		case hz44100 = 44100
		case hz48000 = 48000
	}
	var sampleRate = SampleRate.hz44100

	enum Mode {
		case stereo
		case jointStereo
		case mono

		var rawValue: MPEG_mode_e {
			switch self {
			case .stereo:
				return STEREO
			case .jointStereo:
				return JOINT_STEREO
			case .mono:
				return MONO
			}
		}
	}
	var mode = Mode.jointStereo

	enum Bitrate {
		case CBR(rate: Int32)
		case VBR(rate: Int32)
	}
	var bitRate = Bitrate.CBR(rate: 256) {
		didSet { validateBitrate() }
	}

	var quality = UInt8(2) {
		didSet { validateQuality() }
	}

	private var _mp3Buffer: UnsafeMutableBufferPointer<UInt8> = {
		let mp3BufferSize = Int(1.25 * 1152 + 7200) + 1
		let pointer = UnsafeMutableRawPointer.allocate(
			byteCount: mp3BufferSize,
			alignment: MemoryLayout<UInt8>.alignment)
			.bindMemory(to: UInt8.self, capacity: mp3BufferSize)

		return UnsafeMutableBufferPointer(start: pointer, count: mp3BufferSize)
	}()

	init() {
		lame_set_errorf(lameGlobal) { format, args in
			SwiftIsNotLame.logFromLame(format, args, source: "Error")
		}

		lame_set_debugf(lameGlobal) { format, args in
			SwiftIsNotLame.logFromLame(format, args, source: "Debug")
		}

		lame_set_msgf(lameGlobal) { format, args in
			SwiftIsNotLame.logFromLame(format, args, source: "Message")
		}
	}

	func prepareForEncoding() {
		lame_set_num_channels(lameGlobal, channels.rawValue)
		lame_set_in_samplerate(lameGlobal, sampleRate.rawValue)
		lame_set_mode(lameGlobal, mode.rawValue)
		lame_set_quality(lameGlobal, Int32(quality))

		let rate: Int32
		switch bitRate {
		case .VBR(let bRate):
			lame_set_bWriteVbrTag(lameGlobal, 1)
			rate = bRate
		case .CBR(let bRate):
			lame_set_bWriteVbrTag(lameGlobal, 0)
			rate = bRate
		}
		lame_set_brate(lameGlobal, rate)


		lame_init_params(lameGlobal)
	}

	func finishEncoding() throws -> Data {
		let bytesWritten = lame_encode_flush(lameGlobal, _mp3Buffer.baseAddress, Int32(_mp3Buffer.count))
		try validateBytesWritten(bytesWritten)

		return Data(bytes: _mp3Buffer.baseAddress!, count: Int(bytesWritten))
	}

	func encodeChunk<BitRep: PCMBitRepresentation>(channelOne: UnsafePointer<BitRep>, channelTwo: UnsafePointer<BitRep>? = nil, sampleSize: Int, mp3Buffer: UnsafeMutableBufferPointer<UInt8>? = nil) throws -> Data {
		let mp3Buffer = mp3Buffer ?? _mp3Buffer

		guard let mp3Pointer = mp3Buffer.baseAddress else {
			throw LameError.improperlyFormattedMp3Buffer
		}

		let channel2 = channelTwo ?? channelOne

		let bytesWritten = BitRep.lameEncode(lameGlobal, channelOneBuffer: channelOne, channelTwoBuffer: channel2, sampleSize: sampleSize, mp3Buffer: mp3Pointer, mp3BufferCount: mp3Buffer.count)

		try validateBytesWritten(bytesWritten)

		return Data(bytes: mp3Pointer, count: Int(bytesWritten))
	}

	// MARK: - Property Validation
	private func validateBitrate() {
		switch bitRate {
		case .CBR(rate: let rate), .VBR(rate: let rate):
			if (8...320).contains(rate) == false {
				print("Warning: bitrate must be between 8 and 320: \(bitRate)")
				bitRate = .CBR(rate: 256)
			}
		}
	}

	private func validateQuality() {
		if (0...9).contains(quality) == false {
			print("Warning: quality must be between 0 and 9: \(quality)")
			quality = 2
		}
	}

	private func validateBytesWritten(_ value: Int32) throws {
		guard value >= 0 else {
			if value == -1 {
				throw LameError.mp3BufferTooSmall
			} else {
				throw LameError.mp3InternalError(code: value)
			}
		}
	}

	static func logFromLame(_ unsafeFormat: UnsafePointer<Int8>?, _ args: CVaListPointer?, source: String) {
		guard
			let raw = UnsafeRawPointer(unsafeFormat)?.assumingMemoryBound(to: UInt8.self),
			let args = args
		else {
			print("\(source) output ocurred, but was not translatable.")
			return
		}
		let formatCStr = String(cString: raw)
		let formatted = NSString(format: formatCStr, arguments: args)
		print(formatted)
	}

	enum LameError: Error {
		case improperlyFormattedMp3Buffer
		case mp3BufferTooSmall
		case mp3InternalError(code: Int32)
	}
}

protocol PCMBitRepresentation {
	static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Self>, channelTwoBuffer: UnsafePointer<Self>, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>, mp3BufferCount: Int) -> Int32
}

extension Int16: PCMBitRepresentation {
	static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Int16>, channelTwoBuffer: UnsafePointer<Int16>, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

extension Int32: PCMBitRepresentation {
	static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Int32>, channelTwoBuffer: UnsafePointer<Int32>, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer_int(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

extension Int: PCMBitRepresentation {
	static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Int>, channelTwoBuffer: UnsafePointer<Int>, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer_long(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

extension Float: PCMBitRepresentation {
	static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Float>, channelTwoBuffer: UnsafePointer<Float>, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer_float(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

extension Double: PCMBitRepresentation {
	static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Double>, channelTwoBuffer: UnsafePointer<Double>, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer_ieee_double(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

