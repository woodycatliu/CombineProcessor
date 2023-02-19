//
//  AnyProcessorReducer.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

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
