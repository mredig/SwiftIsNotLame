//
//  OptionUnwrapThrow.swift
//  SwiftIsNotLame
//
//  Created by Michael Redig on 2/21/21.
//

import Foundation

public extension Optional {
	func unwrap() throws -> Wrapped {
		guard case .some(let wrappedValue) = self else { throw OptionalError.noValue }
		return wrappedValue
	}

	enum OptionalError: Error {
		case noValue
	}
}
