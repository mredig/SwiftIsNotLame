import lame
import Foundation

let lameGlobal = lame_init()

func logFromLame(_ unsafeFormat: UnsafePointer<Int8>?, _ args: CVaListPointer?, source: String) {
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

lame_set_errorf(lameGlobal) { format, args in
	logFromLame(format, args, source: "Error")
}

lame_set_debugf(lameGlobal) { format, args in
	logFromLame(format, args, source: "Debug")
}

lame_set_msgf(lameGlobal) { format, args in
	logFromLame(format, args, source: "Message")
}

lame_set_num_samples(lameGlobal, 130661)
lame_set_num_channels(lameGlobal, 2)
lame_set_in_samplerate(lameGlobal, 44100)
lame_set_brate(lameGlobal, 128)
lame_set_mode(lameGlobal, JOINT_STEREO)
lame_set_quality(lameGlobal, 2)
lame_set_bWriteVbrTag(lameGlobal, 0)

var success = lame_init_params(lameGlobal)
guard success >= 0 else {
	fatalError("Error with param init: \(success)")
}

//let opaquePointer = U

var myRNG = MyRNG(seed: 40)

let sampleSize = 50000

let fakePCM: [UInt8] = (0..<(sampleSize * 2)).map { _ in UInt8.random(in: 0..<(.max), using: &myRNG)}
//let buffer = UnsafeBufferPointer(
let buffer: UnsafePointer<Int16>? = fakePCM.withUnsafeBytes { bytes in
	let address = bytes.baseAddress?.bindMemory(to: Int16.self, capacity: 50)

	return UnsafePointer<Int16>(address)
}


//var mp3Data = Data()
let mp3BufferSize = Int(1.25 * Double(sampleSize) + 7200) + 1
let mp3Data = UnsafeMutableRawPointer.allocate(
	byteCount: mp3BufferSize,
	alignment: MemoryLayout<UInt8>.alignment)
	.bindMemory(to: UInt8.self, capacity: mp3BufferSize)

mp3Data.initialize(repeating: 0, count: mp3BufferSize)

func printData<Element>(_ t: UnsafePointer<Element>, count: Int) {
	print("printing contents of: \(t)")
	for i in 0..<count {
		print(t[i])
	}
	print("done\n\n")
}

printData(fakePCM, count: 20)

for _ in 0..<20 {
	let fakePCM: [UInt8] = (0..<(sampleSize * 2)).map { _ in UInt8.random(in: 0..<(.max), using: &myRNG)}
	//let buffer = UnsafeBufferPointer(
	let buffer: UnsafePointer<Int16>? = fakePCM.withUnsafeBytes { bytes in
		let address = bytes.baseAddress?.bindMemory(to: Int16.self, capacity: 50)

		return UnsafePointer<Int16>(address)
	}

	let bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, Int32(sampleSize), mp3Data, Int32(mp3BufferSize))
	print("wrote \(bytesWritten) bytes")
}

var bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, Int32(sampleSize), mp3Data, Int32(mp3BufferSize))
//bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))
//bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))
//bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))
//bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))

bytesWritten = lame_encode_flush(lameGlobal, mp3Data, Int32(mp3BufferSize))

//lame_mp3_tags_fid(lameGlobal, <#T##fid: UnsafeMutablePointer<FILE>!##UnsafeMutablePointer<FILE>!#>)

printData(mp3Data, count: 20)

let data = Data(bytesNoCopy: mp3Data, count: mp3BufferSize, deallocator: .free)

print(bytesWritten)

print(data)

try data.write(to: URL(fileURLWithPath: "/Users/mredig/Swap/lamed.mp3"))
