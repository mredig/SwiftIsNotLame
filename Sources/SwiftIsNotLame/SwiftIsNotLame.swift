import lame
import Foundation

public class SwiftIsNotLame {

	/// probably make private
	public let lameGlobal = lame_init()

	public enum ChannelCount: Int32 {
		case one = 1
		case two
	}

	public var channels = ChannelCount.two

	public enum SampleRate: Int32 {
		case hz44100 = 44100
		case hz48000 = 48000
	}
	public var sampleRate = SampleRate.hz44100

	public enum Mode {
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
	public var mode = Mode.jointStereo

	/*
	add id3 tags (looks like it happens during/before prep stage)

	look for `--tt <title>    audio/song title (max 30 chars for version 1 tag)` related info in parse.c
	*/

	/*
	notes for future bitrate management
	from parse.c

	lame_set_VBR(gfp, vbr_mtrh);
	lame_set_VBR(gfp, vbr_off);
	case 'b':
		argUsed = getIntValue("b", arg, &int_value);
		if (argUsed) {
			lame_set_brate(gfp, int_value);
			lame_set_VBR_min_bitrate_kbps(gfp, lame_get_brate(gfp));
		}
		break;
	case 'B':
		argUsed = getIntValue("B", arg, &int_value);
		if (argUsed) {
			lame_set_VBR_max_bitrate_kbps(gfp, int_value);
		}
		break;

	// add ABR
		T_ELIF("abr")
			/* values larger than 8000 are bps (like Fraunhofer), so it's strange to get 320000 bps MP3 when specifying 8000 bps MP3 */
			argUsed = getIntValue(token, nextArg, &int_value);
			if (argUsed) {
				if (int_value >= 8000) {
					int_value = (int_value + 500) / 1000;
				}
				if (int_value > 320) {
					int_value = 320;
				}
				if (int_value < 8) {
					int_value = 8;
				}
				lame_set_VBR(gfp, vbr_abr);
				lame_set_VBR_mean_bitrate_kbps(gfp, int_value);
			}
	*/
	public enum Bitrate {
		case CBR(rate: Int32)
		case VBR(rate: Int32) // set min and max
	}
	public var bitRate = Bitrate.CBR(rate: 128) {
		didSet { validateBitrate() }
	}

	public var quality = UInt8(2) {
		didSet { validateQuality() }
	}

	private var _mp3Buffer: UnsafeMutableBufferPointer<UInt8>

	public var defaultMp3Buffer: UnsafeBufferPointer<UInt8> { UnsafeBufferPointer(_mp3Buffer) }

	public init(mp3BufferSize: Int = 8641) {
		let pointer = UnsafeMutableRawPointer.allocate(
			byteCount: mp3BufferSize,
			alignment: MemoryLayout<UInt8>.alignment)
			.bindMemory(to: UInt8.self, capacity: mp3BufferSize)

		_mp3Buffer = UnsafeMutableBufferPointer(start: pointer, count: mp3BufferSize)

		lame_set_errorf(lameGlobal) { format, args in
			SwiftIsNotLame.logFromLame(format, args, source: "Error")
		}

		lame_set_debugf(lameGlobal) { format, args in
			guard ProcessInfo.processInfo.environment["DEBUG_PRINT"] == "TRUE" else { return }
			SwiftIsNotLame.logFromLame(format, args, source: "Debug")
		}

		lame_set_msgf(lameGlobal) { format, args in
			SwiftIsNotLame.logFromLame(format, args, source: "Message")
		}
	}

	deinit {
		_mp3Buffer.deallocate()
		lame_close(lameGlobal)
	}

	// MARK: - Layer 1
	/// still needs `prepareForEncoding` called before and `finishEncoding` called afterwards, as well as concatenation of returned data
	/// takes entire channels for input and chunks them up to feed to `encodeChunk` in a loop
	public func encodeAudio<BitRep: PCMBitRepresentation>(_ rawChannelOne: UnsafeBufferPointer<BitRep>, _ rawChannelTwo: UnsafeBufferPointer<BitRep>?) throws -> Data {
		let maxSamples = lame_get_maximum_number_of_samples(lameGlobal, defaultMp3Buffer.count) / 2
//		lame_get_framesize // alternative (preferred?) sample size determination
		let frameSize = lame_get_framesize(lameGlobal)
		let maxSampleSize = Int(min(maxSamples, frameSize))

		var mp3Data = Data()

		var remainingSamples = rawChannelOne.count
		var usedSamples = 0

		while remainingSamples > 0 {
			let endIndexAddend = min(maxSampleSize, remainingSamples)
			let range = usedSamples..<(usedSamples + endIndexAddend)

			let c1 = rawChannelOne[range]
			let channelOneBuffer = UnsafeBufferPointer<BitRep>(rebasing: c1)
			let channelTwoBuffer: UnsafeBufferPointer<BitRep>? = rawChannelTwo.map { (buff: UnsafeBufferPointer<BitRep>) in
				let c2 = buff[range]
				return UnsafeBufferPointer<BitRep>(rebasing: c2)
			}

			mp3Data += try encodeChunk(channelOne: channelOneBuffer, channelTwo: channelTwoBuffer)

			usedSamples = range.upperBound
			remainingSamples = rawChannelOne.count - usedSamples
		}

		return mp3Data
	}

	// MARK: - Layer 0
	public func prepareForEncoding() {
		// look into `lame_set_write_id3tag_automatic` like used in lame_main.c

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

	public func finishEncoding() throws -> Data {
		let bytesWritten = lame_encode_flush(lameGlobal, _mp3Buffer.baseAddress, Int32(_mp3Buffer.count))
		try validateBytesWritten(bytesWritten)

		return Data(bytes: _mp3Buffer.baseAddress!, count: Int(bytesWritten))
	}

	public func encodeChunk<BitRep: PCMBitRepresentation>(channelOne: UnsafeBufferPointer<BitRep>!, channelTwo: UnsafeBufferPointer<BitRep>? = nil, mp3Buffer: UnsafeMutableBufferPointer<UInt8>? = nil) throws -> Data {
		let mp3Buffer = mp3Buffer ?? _mp3Buffer

		guard let mp3Pointer = mp3Buffer.baseAddress else {
			throw LameError.improperlyFormattedMp3Buffer
		}

		guard let channelOne = channelOne else {
			throw LameError.noBufferInput
		}

		let channel2 = channelTwo ?? channelOne

		let bytesWritten = BitRep.lameEncode(lameGlobal, channelOneBuffer: channelOne.baseAddress, channelTwoBuffer: channel2.baseAddress, sampleSize: channelOne.count, mp3Buffer: mp3Pointer, mp3BufferCount: mp3Buffer.count)

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

	public enum LameError: Error {
		case improperlyFormattedMp3Buffer
		case mp3BufferTooSmall
		case mismatchedChannelSamplesProvided
		case noBufferInput
		case mp3InternalError(code: Int32)
	}
}

public protocol PCMBitRepresentation {
	static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Self>!, channelTwoBuffer: UnsafePointer<Self>!, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>!, mp3BufferCount: Int) -> Int32
}

extension Int16: PCMBitRepresentation {
	public static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Int16>!, channelTwoBuffer: UnsafePointer<Int16>!, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>!, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

extension Int32: PCMBitRepresentation {
	public static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Int32>!, channelTwoBuffer: UnsafePointer<Int32>!, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>!, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer_int(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

extension Int: PCMBitRepresentation {
	public static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Int>!, channelTwoBuffer: UnsafePointer<Int>!, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>!, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer_long(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

extension Float: PCMBitRepresentation {
	public static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Float>!, channelTwoBuffer: UnsafePointer<Float>!, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>!, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer_float(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

extension Double: PCMBitRepresentation {
	public static func lameEncode(_ lame: lame_t!, channelOneBuffer: UnsafePointer<Double>!, channelTwoBuffer: UnsafePointer<Double>!, sampleSize: Int, mp3Buffer: UnsafeMutablePointer<UInt8>!, mp3BufferCount: Int) -> Int32 {
		lame_encode_buffer_ieee_double(lame, channelOneBuffer, channelTwoBuffer, Int32(sampleSize), mp3Buffer, Int32(mp3BufferCount))
	}
}

