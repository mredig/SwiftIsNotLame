import lame
import Foundation

let lameGlobal = lame_init()

lame_set_errorf(lameGlobal) { format, args in
	print("Error occurred:\nformat: \(String(describing: format))\nargs: \(String(describing: args))")
}

lame_set_debugf(lameGlobal) { (format, args) in
	print("Debug output occurred:\nformat: \(String(describing: format))\nargs: \(String(describing: args))")
}

lame_set_msgf(lameGlobal) { format, args in
	print("message output occurred:\nformat: \(String(describing: format))\nargs: \(String(describing: args))")
}

lame_set_num_channels(lameGlobal, 2)
lame_set_in_samplerate(lameGlobal, 44100)
lame_set_brate(lameGlobal, 128)
lame_set_mode(lameGlobal, JOINT_STEREO)
lame_set_quality(lameGlobal, 2)

var success = lame_init_params(lameGlobal)
guard success >= 0 else {
	fatalError("Error with param init: \(success)")
}

//let opaquePointer = U

var myRNG = MyRNG(seed: 40)

let fakePCM: [UInt8] = (0..<100).map { _ in UInt8.random(in: 0..<(.max), using: &myRNG)}
//let buffer = UnsafeBufferPointer(
let buffer: UnsafePointer<Int16>? = fakePCM.withUnsafeBytes { bytes in
	let address = bytes.baseAddress?.bindMemory(to: Int16.self, capacity: 50)

	return UnsafePointer<Int16>(address)
}


//var mp3Data = Data()
let mp3BufferSize = Int(1.25 * 50 + 7200) + 1
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
printData(mp3Data, count: 20)

var bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))

//badBuffer.
//print(badBuffer?[0])

printData(mp3Data, count: 20)

print(bytesWritten)
