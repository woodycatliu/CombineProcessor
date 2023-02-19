//
//  ProcessorReducerProtocol.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

import Foundation

public protocol ProcessorReducerProtocol<State, Action, PrivateAction> {
        
    associatedtype State
    associatedtype Action
    associatedtype PrivateAction
        
    func transform(_ action: Action) -> PrivateAction
    
    func reducing(state: inout State, privateAction privatization: PrivateAction) -> ProcessorPublisher<PrivateAction, Never>?
}
