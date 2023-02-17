//
//  File.swift
//  
//
//  Created by Woody Liu on 2023/2/17.
//

import Foundation
@_spi(CurrentTestCase) import XCTestDynamicOverlay

func XCTHandling<Value>(_ value: Value,
                       _ expected: @escaping (Value) -> Bool,
                       _ completion: @escaping () -> Void,
                       _ message: String = "",
                       file: StaticString = #file,
                       line: UInt = #line) {
    defer { completion() }
    guard !expected(value) else { return }
    XCTFail(
          """
          XCTHandling failed: expected value is \(value)"\
          \(message.isEmpty ? "" : " - " + message)
          """,
          file: file,
          line: line
    )
}
