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

//lame_set_debugf(lameGlobal) { format, args in
//	logFromLame(format, args, source: "Debug")
//}

lame_set_msgf(lameGlobal) { format, args in
	logFromLame(format, args, source: "Message")
}

//lame_set_num_samples(lameGlobal, 130661)
lame_set_num_channels(lameGlobal, 2)
lame_set_in_samplerate(lameGlobal, 44100)
lame_set_brate(lameGlobal, 256)
lame_set_mode(lameGlobal, STEREO)
lame_set_quality(lameGlobal, 0)
lame_set_bWriteVbrTag(lameGlobal, 1)

var success = lame_init_params(lameGlobal)
guard success >= 0 else {
	fatalError("Error with param init: \(success)")
}

//let opaquePointer = U

var myRNG = MyRNG(seed: 40)

let sampleSize = 44100

let sinHz = CGFloat.random(in: 220..<880)

let facePCM1: [Int16] = (0..<sampleSize).map { x in
//	Int16(sin(Double($0) * 0.00001) * Double(Int16.max))
	let normalizePeriodValue = CGFloat.pi * 2
	let sampleRate: CGFloat = 44100
//	let sinHz: CGFloat = 320

	let freq = sinHz * normalizePeriodValue

	let x: CGFloat = CGFloat(x) / sampleRate

	let y = sin(x * freq)
	let y2 = y * CGFloat(Int16.max)
	return Int16(y2)
}

let buffer1: UnsafePointer<Int16>? = facePCM1.withUnsafeBytes {
	$0.baseAddress?.bindMemory(to: Int16.self, capacity: sampleSize)
}

//let fakePCM: [UInt8] = (0..<(sampleSize * 2)).map { _ in UInt8.random(in: 0..<(.max), using: &myRNG)}
////let buffer = UnsafeBufferPointer(
//let buffer: UnsafePointer<Int16>? = fakePCM.withUnsafeBytes { bytes in
//	let address = bytes.baseAddress?.bindMemory(to: Int16.self, capacity: sampleSize / 2)
//
//	return UnsafePointer<Int16>(address)
//}


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

//printData(fakePCM, count: 20)

var mp3Out = Data()

func appendBuffer(_ buffer: UnsafePointer<UInt8>, count: Int, to data: inout Data) {
	let mp3Buffer = Data(bytes: buffer, count: count)
	data.append(mp3Buffer)
}

for _ in 0..<20 {
//	let fakePCM: [UInt8] = (0..<(sampleSize * 2)).map { _ in UInt8.random(in: 0..<(.max), using: &myRNG)}
	//let buffer = UnsafeBufferPointer(
//	let buffer: UnsafePointer<Int16>? = fakePCM.withUnsafeBytes { bytes in
//		let address = bytes.baseAddress?.bindMemory(to: Int16.self, capacity: 50)
//
//		return UnsafePointer<Int16>(address)
//	}

	let bytesWritten = lame_encode_buffer(lameGlobal, buffer1, buffer1, Int32(sampleSize), mp3Data, Int32(mp3BufferSize))
	print("wrote \(bytesWritten) bytes")

//	let mp3Buffer = Data(bytes: mp3Data, count: Int(bytesWritten))
//	mp3Out.append(mp3Buffer)
	appendBuffer(mp3Data, count: Int(bytesWritten), to: &mp3Out)
}

//var bytesWritten = lame_encode_buffer(lameGlobal, buffer1, buffer, Int32(sampleSize), mp3Data, Int32(mp3BufferSize))
//bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))
//bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))
//bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))
//bytesWritten = lame_encode_buffer(lameGlobal, buffer, buffer, 50, mp3Data, Int32(mp3BufferSize))

let bytesWritten = lame_encode_flush(lameGlobal, mp3Data, Int32(mp3BufferSize))
appendBuffer(mp3Data, count: Int(bytesWritten), to: &mp3Out)

//lame_mp3_tags_fid(lameGlobal, <#T##fid: UnsafeMutablePointer<FILE>!##UnsafeMutablePointer<FILE>!#>)

//printData(mp3Data, count: 20)

//let data = Data(bytesNoCopy: mp3Data, count: mp3BufferSize, deallocator: .free)

print(bytesWritten)


try mp3Out.write(to: URL(fileURLWithPath: "/Users/mredig/Swap/lamed.mp3"))
