//
//  ProcessorReducerProtocol.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

import Foundation


/**
 # ProcessorReducerProtocol

 A protocol that defines a transformation and a reducing function for a state machine that processes actions.

 ## Overview

 The ProcessorReducerProtocol protocol defines a set of methods that allow for transforming and reducing actions within a state machine. The transform method takes an Action and returns a PrivateAction, which is a type-safe representation of the action that can be safely used by the state machine. The reducing function takes a State and a PrivateAction, and returns an instance of ProcessorPublisher that emits a stream of PrivateAction values.

 ## Associated Type

 - `State` : A generic type that represents the state of the machine.
 - `Action` : A generic type that represents the input action.
 - `PrivateAction`: A generic type that represents the transformed and processed action.
 
 ## Methods

 - `ansform(_:)`: A method that takes an Action as input and returns a PrivateAction as output. This method is responsible for transforming the input action into a type-safe representation that can be safely used by the state machine.
 - `reducing(state:privateAction:)` : A method that takes the current State and a PrivateAction as input, and returns a ProcessorPublisher that emits a stream of PrivateAction values. This method is responsible for reducing the state based on the input action and emitting any resulting PrivateAction values.
 */
public protocol ProcessorReducerProtocol<State, Action, PrivateAction> {
        
    associatedtype State
    associatedtype Action
    associatedtype PrivateAction
        
    func transform(_ action: Action) -> PrivateAction
    
    func reducing(state: inout State, privateAction privatization: PrivateAction) -> ProcessorPublisher<PrivateAction, Never>?
}
