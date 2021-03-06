import XCTest
@testable import SwiftIsNotLame
import CryptoKit

final class SwiftIsNotLameTests: XCTestCase {

	func testSigned16() throws {
		var stopwatch = Stopwatch()

		stopwatch.start("loading wav file")
		let signed16WavFile = Bundle.module.url(forResource: "signed16", withExtension: "wav", subdirectory: "TestResources")!

		stopwatch.logCheckpoint(note: "decoding wav header")
		let testWav = try WavFile(filePath: signed16WavFile)
		try testWav.loadIntoMemory()
		
		let mp3Data = try convert(testWav, stopwatch: &stopwatch)

		let hash = dataMd5Hash(mp3Data)

		XCTAssertEqual("f89306722b2f30a63f27c4ad7d56a3e8", hash)
	}

	private func convert(_ wavFile: WavFile, stopwatch: inout Stopwatch) throws -> Data {
		stopwatch.logCheckpoint(note: "setting up lame")
		let notLame = SwiftIsNotLame()

		notLame.bitRate = .CBR(rate: 256)
		notLame.quality = 0
		stopwatch.logCheckpoint(note: "encoding")
		return try notLame.encodeAudio(from: wavFile)
	}

	private func dataMd5Hash<D: DataProtocol>(_ data: D) -> String {
		var hasher = Insecure.MD5()
		hasher.update(data: data)
		let hash = hasher.finalize()
		return hash.map { String(format: "%02hhx", $0) }.joined()
	}
}
