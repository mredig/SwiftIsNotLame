import XCTest
@testable import SwiftIsNotLame
import CryptoKit

final class SwiftIsNotLameTests: XCTestCase {

	func testSigned16() throws {
		let signed16WavFile = Bundle.module.url(forResource: "signed16", withExtension: "wav", subdirectory: "TestResources")!

		let testWav = try WavFile(filePath: signed16WavFile)
		try testWav.loadIntoMemory()
		
		let mp3Data = try convert(testWav)

		let hash = dataMd5Hash(mp3Data)

		XCTAssertEqual("f89306722b2f30a63f27c4ad7d56a3e8", hash)
	}

	func testSigned24() throws {
		let wavFileURL = Bundle.module.url(forResource: "signed24", withExtension: "wav", subdirectory: "TestResources")!

		let testWav = try WavFile(filePath: wavFileURL)
		try testWav.loadIntoMemory()

		let mp3Data = try convert(testWav)

		let hash = dataMd5Hash(mp3Data)

		XCTAssertEqual("eb814f46aaed19ed069ebcbb7033ec79", hash)
	}

	func testSigned32() throws {
		let wavFileURL = Bundle.module.url(forResource: "signed32", withExtension: "wav", subdirectory: "TestResources")!

		let testWav = try WavFile(filePath: wavFileURL)
		try testWav.loadIntoMemory()

		let mp3Data = try convert(testWav)

		let hash = dataMd5Hash(mp3Data)

		XCTAssertEqual("1d8d0622fba87a813d6a8de00454ae09", hash)
	}

//	func testUnsigned8() throws {
//		let wavFileURL = Bundle.module.url(forResource: "unsigned8", withExtension: "wav", subdirectory: "TestResources")!
//
//		let testWav = try WavFile(filePath: wavFileURL)
//		try testWav.loadIntoMemory()
//
//		let mp3Data = try convert(testWav)
//
//		let hash = dataMd5Hash(mp3Data)
//
//		XCTAssertEqual("1d8d0622fba87a813d6a8de00454ae09", hash)
//	}

	func testFloat32() throws {
		let wavFileURL = Bundle.module.url(forResource: "float32", withExtension: "wav", subdirectory: "TestResources")!

		let testWav = try WavFile(filePath: wavFileURL)
		try testWav.loadIntoMemory()

		let mp3Data = try convert(testWav)

		let hash = dataMd5Hash(mp3Data)

		XCTAssertEqual("e3054cc83ce36cbda0e222ae2d58ce02", hash)
	}

	func testFloat64() throws {
		let wavFileURL = Bundle.module.url(forResource: "float64", withExtension: "wav", subdirectory: "TestResources")!

		let testWav = try WavFile(filePath: wavFileURL)
		try testWav.loadIntoMemory()

		let mp3Data = try convert(testWav)

		let hash = dataMd5Hash(mp3Data)

		XCTAssertEqual("e3054cc83ce36cbda0e222ae2d58ce02", hash)
	}

	func testCafFloat32() throws {
		let cafFileURL = Bundle.module.url(forResource: "sample", withExtension: "caf", subdirectory: "TestResources")!

//		let testWav = try WavFile(filePath: wavFileURL)
		let testCaf = try CafFile(filePath: cafFileURL)
		try testCaf.loadIntoMemory()

//		let mp3Data = try convert(testCaf)
//
//		let hash = dataMd5Hash(mp3Data)
//
//		XCTAssertEqual("e3054cc83ce36cbda0e222ae2d58ce02", hash)
	}

	private func convert(_ wavFile: WavFile) throws -> Data {
		let notLame = SwiftIsNotLame()

		notLame.bitRate = .CBR(rate: 256)
		notLame.quality = 0
		return try notLame.encodeAudio(from: wavFile)
	}

	private func dataMd5Hash<D: DataProtocol>(_ data: D) -> String {
		var hasher = Insecure.MD5()
		hasher.update(data: data)
		let hash = hasher.finalize()
		return hash.map { String(format: "%02hhx", $0) }.joined()
	}
}
