//
//  Stopwatch.swift
//  SwiftIsNotLame
//
//  Created by Michael Redig on 2/21/21.
//

import Foundation

public struct Stopwatch {
	var checkpoints: [(note: String, time: TimeInterval)] = []

	var printLiveUpdates = true

	static let formatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.maximumFractionDigits = 5
		return formatter
	}()

	public init() {}

	public mutating func logCheckpoint(note: String) {
		checkpoints.append((note: note, time: CFAbsoluteTimeGetCurrent()))
		guard
			printLiveUpdates,
			let lastUpdate = checkpoints.last
		else { return }
		print(lastUpdate)
	}

	public mutating func start(_ customNote: String? = nil) {
		let note = "start" + (customNote.map { ": " + $0 } ?? "")
		logCheckpoint(note: note)
	}

	public func printResults() {
		for (i, checkpoint) in checkpoints.enumerated() where i != 0 {
			let previous = checkpoints[i - 1]
			let secondsSinceLast = checkpoint.time - previous.time

			let humanReadableSeconds = Self.formatter.string(from: secondsSinceLast as NSNumber) ?? "??"

			print("\(humanReadableSeconds) seconds: from '\(previous.note)' -> '\(checkpoint.note)'")
		}
	}
}
