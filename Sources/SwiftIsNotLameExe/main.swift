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

		let xVal: CGFloat = CGFloat(x) / sampleRate

		let y = sin(xVal * freq)
		let y2 = y * CGFloat(Int16.max)
		guard x != (sampleSize - 1) else { return Int16.max }
		return Int16(y2)
	}
}

let fourforty = Array(repeating: generateTone(hz: 440), count: 10)
	.flatMap { $0 }

let fiveforty = Array(repeating: generateTone(hz: 540), count: 10)
	.flatMap { $0 }

let c1Buff = fourforty.withUnsafeBufferPointer { $0 }
let c2Buff = fiveforty.withUnsafeBufferPointer { $0 }
var mp3Data = notLame.encodeAudio(c1Buff, c2Buff)

let mp3Finisher = try notLame.finishEncoding()

mp3Data += mp3Finisher

try mp3Data.write(to: URL(fileURLWithPath: "/Users/mredig/Swap/not lame.mp3"))

print("output finished")
