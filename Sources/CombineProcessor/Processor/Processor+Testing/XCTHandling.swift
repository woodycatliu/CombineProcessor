//
//  File.swift
//  
//
//  Created by Woody Liu on 2023/2/17.
//

import Foundation
@_spi(CurrentTestCase) import XCTestDynamicOverlay

func XCTHandling<Value>(value: Value,
                       expected: @escaping (Value) -> Bool,
                       completion: (() -> Void)? = nil,
                       message: String = "",
                       file: StaticString = #file,
                       line: UInt = #line) {
    defer { completion?() }
    guard !expected(value) else { return }
    XCTFail(
          """
          failed: expected value is \(value)"\
          \(message.isEmpty ? "" : " - " + message)
          """,
          file: file,
          line: line
    )
}
