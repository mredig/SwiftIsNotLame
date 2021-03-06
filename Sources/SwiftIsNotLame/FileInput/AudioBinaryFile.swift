import Foundation

protocol AudioBinaryFileDelegate: AnyObject {
	func offsetForSample(_ sampleIndex: Int, channel: Int, audioInfo: SwiftIsNotLame.AudioInfo, byteOrder: inout BinaryFile.ByteOrder) -> Int
}

public class AudioBinaryFile: BinaryFile {
	open private(set) var audioInfo: SwiftIsNotLame.AudioInfo?

	weak var delegate: AudioBinaryFileDelegate?

	/// Channel value is 0 indexed - if there are two channels, channel 0 and channel 1 are valid values.
	public func sample<BitRep: PCMBitRepresentation>(at sampleIndex: Int, channel: Int) throws -> BitRep {
		guard
			let info = audioInfo,
			channel < info.channels.rawValue
		else { throw AudioBinaryError.genericError("Requested sample for channel that doesnt exist") }

		var byteOrder = ByteOrder.littleEndian
		guard
			let totalOffsetFromDataPointer = delegate?.offsetForSample(sampleIndex, channel: channel, audioInfo: info, byteOrder: &byteOrder)
		else {
			fatalError("Require delegate for AudioBinaryFile")
		}

		return try read(single: BitRep.self, byteOrder: .littleEndian, startingAt: UInt64(totalOffsetFromDataPointer))
	}

	/// Channel value is 0 indexed - if there are two channels, channel 0 and channel 1 are valid values.
	public func channelBuffer<BitRep: PCMBitRepresentation>(channel: Int) throws -> ContiguousArray<BitRep> {
		guard let info = audioInfo else { return [] }
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

	enum AudioBinaryError: Error {
		case notSupported(_ description: String?)
		case genericError(_ description: String?)
		case unknown
	}
}
