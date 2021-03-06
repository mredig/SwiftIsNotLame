import Foundation

public class BinaryFile {
	let filePath: URL

	let handle: FileHandle

	open private(set) var audioInfo: SwiftIsNotLame.AudioInfo?

	var offset: UInt64 {
		if memoryRepresentation != nil {
			return UInt64(memoryOffset)
		} else {
			do {
				return try handle.handleOffset()
			} catch {
				NSLog("Error getting file offset: \(error)")
				return 0
			}
		}
	}

	private var memoryOffset: Int = 0
	private var memoryRepresentation: Data?

	init(filePath: URL) throws {
		self.filePath = filePath
		self.handle = try FileHandle(forReadingFrom: filePath)
	}

	public func loadIntoMemory() throws {
		memoryRepresentation = try Data(contentsOf: filePath)
		memoryOffset = Int(try handle.handleOffset())
	}

	enum ByteOrder {
		case bigEndian
		case littleEndian
	}

	func read(_ byteCount: Int, byteOrder: ByteOrder = .bigEndian, startingAt offset: UInt64? = nil) throws -> [UInt8] {
		let bytesData: Data
		if let memoryRep = memoryRepresentation {
			let startOffset = offset.map { Int($0) } ?? memoryOffset
			let endOffset = startOffset + byteCount

			bytesData = memoryRep[startOffset..<endOffset]
			memoryOffset = endOffset
		} else {
			if let offset = offset {
				try handle.handleSeek(toOffset: offset)
			}

			bytesData = try handle.handleRead(byteCount)
		}

		switch byteOrder {
		case .bigEndian:
			return Array(bytesData)
		case .littleEndian:
			return bytesData.reversed()
		}
	}

	func read<BitRep: BitConversion>(single type: BitRep.Type, byteOrder: ByteOrder = .bigEndian, startingAt offset: UInt64? = nil) throws -> BitRep {
		let size = MemoryLayout<BitRep>.size
		return try read(size, byteOrder: byteOrder, startingAt: offset)
			.converted(to: BitRep.self)
	}
}
