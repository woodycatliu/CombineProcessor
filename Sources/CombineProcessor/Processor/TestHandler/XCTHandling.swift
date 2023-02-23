//
//  XCTHandling.swift
//
//
//  Created by Woody Liu on 2023/2/17.
//

import Foundation
@_spi(CurrentTestCase) import XCTestDynamicOverlay

func XCTHandling<Value>(value: Value,
                        expected: @escaping (Value) -> Bool,
                        completion: (() -> Void)? = nil,
                        prifix: String = "",
                        message: String = "") {
    defer { completion?() }
    guard !expected(value) else { return }
    XCTFail(
          """
          \(prifix) failed ----------------------------------
          value: \(value) 。
          \(message.isEmpty ? "" : "meessage: " + message)。
          """
    )
}
