//
//  AnyProcessorReducer.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

/**
 # Documentation for AnyProcessorReducer

 The `AnyProcessorReducer` struct is a type-erased wrapper around a processor reducer that works with a specific state, action, private action, and environment. It is a generic type that accepts four parameters:

 - `State` : The state that the reducer works with.
 - `Action` : The action that the reducer takes as input.
 - `PrivateAction`: The private action that the reducer returns after processing an action.
 - `Environment`: The environment that the reducer operates in.
 
 ## Properties:

 - `mutated`: A closure that transforms an Action into a PrivateAction.
 - `reduce`: A closure that mutates the state with a PrivateAction and an Environment, and returns a ProcessorPublisher of PrivateAction or Never.
 
 >   AnyProcessorReducer is initialized with these two closures, which can be used to define how the reducer works.
 */
public struct AnyProcessorReducer<State, Action, PrivateAction, Environment> {
        
    public let mutated: Mutated
    
    public let reduce: Reduce
    
    public typealias Reduce = (_ state: inout State, _ privateAction: PrivateAction, _ envi: Environment) -> ProcessorPublisher<PrivateAction, Never>?
    
    public typealias Mutated = (_ action: Action) -> PrivateAction
    
    public init(mutated: @escaping Mutated, reduce: @escaping Reduce) {
        self.mutated = mutated
        self.reduce = reduce
    }

}

/**
 # Documentation for ProcessorReducer

 The `ProcessorReducer`  struct is a generic type that conforms to the `ProcessorReducerProtocol` protocol. It defines a processor reducer that works with a specific state, action, and private action.

 ## Properties:

 - `mutated` : A closure that transforms an Action into a PrivateAction.
 - `reduce`: A closure that mutates the state with a PrivateAction, and returns a ProcessorPublisher of PrivateAction or Never.
 
 > `ProcessorReducer` is initialized with these two closures, which can be used to define how the reducer works.
 >   The struct also conforms to the `ProcessorReducerProtoco`  protocol, which requires it to implement two methods:

 - `transform`: A method that takes an Action and returns a PrivateAction.
 - `reducing`: A method that mutates the state with a PrivateAction, and returns a ProcessorPublisher of PrivateAction or Never.
 */
public struct ProcessorReducer<State, Action, PrivateAction>: ProcessorReducerProtocol {
    
    public typealias Mutated = (_ action: Action) -> PrivateAction
    
    public typealias Reduce = (_ state: inout State, _ privateAction: PrivateAction) -> ProcessorPublisher<PrivateAction, Never>?
    
    public init(mutated: @escaping Mutated, reduce: @escaping Reduce) {
        self.mutated = mutated
        self.reduce = reduce
    }
    
    public func transform(_ action: Action) -> PrivateAction {
        return mutated(action)
    }

    public func reducing(state: inout State, privateAction privatization: PrivateAction) -> ProcessorPublisher<PrivateAction, Never>? {
        return reduce(&state, privatization)
    }
    
    private let mutated: Mutated
    
    private let reduce: Reduce
}
