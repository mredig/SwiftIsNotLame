import lame
import Foundation
import SwiftIsNotLame

let notLame = SwiftIsNotLame()
notLame.prepareForEncoding()

let sampleSize = 44100
func generateTone(hz: CGFloat) -> [Int16] {

	let sinHz = hz

	return (0..<sampleSize).map { x in
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
}

let fourforty = generateTone(hz: 440)
	.withUnsafeBufferPointer { $0 }
	.baseAddress
let fiveforty = generateTone(hz: 540)
	.withUnsafeBufferPointer { $0 }
	.baseAddress

var remainingSamples = sampleSize
var usedSamples = 0

var maxSampleSize = Int(lame_get_maximum_number_of_samples(notLame.lameGlobal, notLame.defaultMp3Buffer.count))

var mp3Data = Data()

while remainingSamples > 0 {
	let channelOne = fourforty?.advanced(by: usedSamples)
	let channelTwo = fiveforty?.advanced(by: usedSamples)

	mp3Data += try notLame.encodeChunk(channelOne: channelOne!, channelTwo: channelTwo!, sampleSize: maxSampleSize)

	remainingSamples -= maxSampleSize
	usedSamples += maxSampleSize

	if remainingSamples < maxSampleSize {
		maxSampleSize = remainingSamples
	}
}


let mp3Finisher = try notLame.finishEncoding()

mp3Data += mp3Finisher

try mp3Data.write(to: URL(fileURLWithPath: "/Users/mredig/Swap/not lame.mp3"))
