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


let lampLeftRaw = try Data(contentsOf: URL(fileURLWithPath: "/Users/mredig/Swap/lampshades left.raw"))
let lampRightRaw = try Data(contentsOf: URL(fileURLWithPath: "/Users/mredig/Swap/lampshades right.raw"))

let c1 = lampLeftRaw.withUnsafeBytes {
	$0.bindMemory(to: Int16.self)
}

let c2 = lampRightRaw.withUnsafeBytes {
	$0.bindMemory(to: Int16.self)
}

var mp3Data = notLame.encodeAudio(c1, c2)

let mp3Finisher = try notLame.finishEncoding()

mp3Data += mp3Finisher

try mp3Data.write(to: URL(fileURLWithPath: "/Users/mredig/Swap/not lame.mp3"))

print("output finished")
