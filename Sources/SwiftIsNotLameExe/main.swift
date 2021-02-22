import lame
import Foundation
import SwiftIsNotLame
import ArgumentParser

//let sampleSize = 44100
//func generateTone(hz: CGFloat) -> [Int16] {
//
//	let sinHz = hz
//
//	return (0..<sampleSize).map { x in
//	//	Int16(sin(Double($0) * 0.00001) * Double(Int16.max))
//		let normalizePeriodValue = CGFloat.pi * 2
//		let sampleRate: CGFloat = 44100
//	//	let sinHz: CGFloat = 320
//
//		let freq = sinHz * normalizePeriodValue
//
//		let xVal: CGFloat = CGFloat(x) / sampleRate
//
//		let y = sin(xVal * freq)
//		let y2 = y * CGFloat(Int16.max)
//		guard x != (sampleSize - 1) else { return Int16.max }
//		return Int16(y2)
//	}
//}

struct SwiftIsNotLameExe: ParsableCommand {
	@Option(name: .shortAndLong, help: "The input wav file", transform: { URL(fileURLWithPath: $0) })
	var inputFile: URL

	@Option(name: .shortAndLong, help: "The output mp3 file", transform: { URL(fileURLWithPath: $0) })
	var outputFile: URL


	func run() throws {
		var stopwatch = Stopwatch()

		stopwatch.start("loading wav file")
		let lampshadeWavFile = inputFile
		let lampshadeData = try Data(contentsOf: lampshadeWavFile)
		let testWav = WavFile(sourceData: lampshadeData)
		stopwatch.logCheckpoint(note: "decoding wav header")
		try testWav.processHeader()

		stopwatch.logCheckpoint(note: "setting up lame")
		let notLame = SwiftIsNotLame()
		notLame.channels = testWav.wavInfo?.channels ?? notLame.channels
		notLame.sampleRate = testWav.wavInfo?.sampleRate ?? notLame.sampleRate
		notLame.mode = .stereo
		notLame.bitRate = .CBR(rate: 256)
		notLame.prepareForEncoding()
		notLame.quality = 0


		stopwatch.logCheckpoint(note: "getting decoded Int16 array")
		let leftChannel: [Int16] = Array(try testWav.channelBuffer(channel: 0))
		let rightChannel: [Int16] = Array(try testWav.channelBuffer(channel: 1))

		stopwatch.logCheckpoint(note: "starting mp3 encode")
		var mp3Data = try notLame.encodeAudio(leftChannel, rightChannel)

		mp3Data += try notLame.finishEncoding()

		try mp3Data.write(to: outputFile)

		stopwatch.logCheckpoint(note: "done")
		stopwatch.printResults()
	}
}


SwiftIsNotLameExe.main()
