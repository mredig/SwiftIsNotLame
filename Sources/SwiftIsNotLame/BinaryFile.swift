import Foundation

public class BinaryFile {
	let filePath: URL

	let handle: FileHandle

	init(filePath: URL) throws {
		self.filePath = filePath
		self.handle = try FileHandle(forReadingFrom: filePath)
	}

	enum ByteOrder {
		case bigEndian
		case littleEndian
	}

	private func read(_ byteCount: Int, byteOrder: ByteOrder = .bigEndian, startingAt offset: UInt64? = nil) throws -> [UInt8] {
		if let offset = offset {
			try handle.handleSeek(toOffset: offset)
		}

		let bytesData = try handle.handleRead(byteCount)

		switch byteOrder {
		case .bigEndian:
			return Array(bytesData)
		case .littleEndian:
			return bytesData.reversed()
		}
	}

	private func read<BitRep: FixedWidthInteger>(single type: BitRep.Type, byteOrder: ByteOrder = .bigEndian, startingAt offset: UInt64? = nil) throws -> BitRep {
		let size = MemoryLayout<BitRep>.size
		return try read(size, byteOrder: byteOrder, startingAt: offset)
			.converted(to: BitRep.self)
	}

	enum BinaryFileError: Error {
		case handleNil
	}
}
