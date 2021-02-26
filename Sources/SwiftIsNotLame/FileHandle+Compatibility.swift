import Foundation

public extension FileHandle {
	func handleClose() throws {
		if #available(OSX 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
			try close()
		} else {
			closeFile()
		}
	}

	func handleOffset() throws -> UInt64 {
		if #available(OSX 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
			return try offset()
		} else {
			return offsetInFile
		}
	}

	func handleRead(_ count: Int) throws -> Data {
		if #available(OSX 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
			return try read(upToCount: count) ?? Data()
		} else {
			return readData(ofLength: count)
		}
	}

	func handleReadToEnd() throws -> Data {
		if #available(OSX 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
			return try readToEnd() ?? Data()
		} else {
			return readDataToEndOfFile()
		}
	}

	func handleSeek(toOffset offset: UInt64) throws {
		if #available(OSX 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
			try seek(toOffset: offset)
		} else {
			seek(toFileOffset: offset)
		}
	}

	@discardableResult func handleSeekToEnd() throws -> UInt64 {
		if #available(OSX 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
			return try seekToEnd()
		} else {
			return seekToEndOfFile()
		}
	}

	func handleSynchronize() throws {
		if #available(OSX 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
			try synchronize()
		} else {
			synchronizeFile()
		}
	}

	func handleTruncate(atOffset offset: UInt64) throws {
		if #available(OSX 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
			try truncate(atOffset: offset)
		} else {
			truncateFile(atOffset: offset)
		}
	}

	func handleWrite<T: DataProtocol>(contentsOf data: T) throws {
		if #available(OSX 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
			try write(contentsOf: data)
		} else {
			let outData = Data(data.map { $0 })
			write(outData)
		}
	}
}
