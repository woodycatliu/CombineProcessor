//
//  Processor.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

import Foundation
import Combine

/**
# Processor.swift

The Processor class is a generic class that provides a way to process actions and private actions and to manage state changes. It is designed to work with Combine framework.

## Properties:

- `id`: a unique identifier for each instance of the Processor class, used for logging and debugging purposes.
- `logActionDescriotionFirst`: a boolean property that determines whether the description of actions and private actions should be printed first in the log messages. The default value is true.
- `enableLog`: a boolean property that determines whether logging is enabled. The default value is true.
- `publisher`: a read-only property that returns an AnyPublisher instance of the current state.
- `reducer`: an instance of ProcessorReducerProtocol that defines the behavior of the reducer, which takes actions and private actions and mutates the state accordingly.
- `_state`: a CurrentValueSubject instance that stores the current state.
- `collection`: a CancellablesCollection instance that stores all the cancellables for the publishers used in the reducer.
- `queue`: a DispatchQueue instance that is used to handle the cancellables in the collection.
 
## Methods:

- `init(initialState:reducer:environment:)`: a convenience initializer that takes an initial state, a reducer, and an environment, which is used by the reducer to perform its tasks.
- `init(initialState:reducer:)`: a designated initializer that takes an initial state and a reducer.
- `send(_:)`: a method that takes an action and sends it to the reducer to process. It then sends the resulting private action to itself to update the state.
- `_send(privateAction:)`: a private method that takes a private action and sends it to itself to update the state.
- `subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value`: a subscript that allows accessing the properties of the state using the dot syntax.
 
## Private methods:

- `prefix`: a private property that returns a string that includes the first three characters of the processor's id, used in logging messages.
- `log(obj:)`: a private method that takes an object and logs it if logging is enabled.
- `_log(action:)`: a private method that logs an action.
- `_log(privateAction:)`: a private method that logs a private action.
- `logDivid()`: a private method that logs a divider in the log messages.
 */

@dynamicMemberLookup
public final class Processor<State, Action, PrivateAction>: Identifiable {
    
    /// name: Define the name of the process.
    public var name: String?
    
    ///`id`: a unique identifier for each instance of the Processor class, used for logging and debugging purposes.
    public var id: String = UUID().uuidString
    
    /// `logActionDescriotionFirst`: a boolean property that determines whether the description of actions and private actions should be printed first in the log messages. The default value is true.
    public var logActionDescriotionFirst: Bool = true
    
    /// `enableLog`: a boolean property that determines whether logging is enabled. The default value is true.
    public var enableLog: Bool = true
    
    public var logger: ProcessorLogger = Processor.Logger()
    
    public var autoCancelLatestAction: Bool = false
    
    /// `publisher`: a read-only property that returns an AnyPublisher instance of the current state.
    public var publisher: AnyPublisher<State, Never> {
        return _state.eraseToAnyPublisher()
    }
    
    public typealias Mutated = (_ action: Action) -> PrivateAction
    
    /// `init(initialState:reducer:environment:)`: a convenience initializer that takes an initial state, a reducer, and an environment, which is used by the reducer to perform its tasks.
    /// - Parameters:
    ///   - initialState: Default State
    ///   - reducer: `reducer`: an instance of ProcessorReducerProtocol that defines the behavior of the reducer, which takes actions and private actions and mutates the state accordingly.
    ///   - environment: Injection use case or any other model
    public convenience init<Environment>(initialState: State,
                     reducer: AnyProcessorReducer<State, Action, PrivateAction, Environment>,
                        environment: Environment) {
        self.init(initialState: initialState,
                  reducer: ProcessorReducer(mutated: reducer.mutated,
                                               reduce: { state, privateAction in
            reducer.reduce(&state, privateAction, environment)
        }))
    }
    
    public init<R: ProcessorReducerProtocol>(initialState: State ,reducer: R)
    where R.State == State, R.Action == Action, R.PrivateAction == PrivateAction {
        self.reducer = reducer
        self._state = .init(initialState)
    }
    
    /// `send(_:)`: a method that takes an action and sends it to the reducer to process. It then sends the resulting private action to itself to update the state.
    /// - Parameter action: request a command
    public func send(_ action: Action) {
        log(obj: action)
        if autoCancelLatestAction { cancelAllAction() }
        let privatization = reducer.transform(action)
        _send(privateAction: privatization)
    }
    
    public func cancelAllAction() {
        collection.cancelAll()
    }
    
    func _send(privateAction privatization: PrivateAction) {
        log(obj: privatization)
        if let publisher = reducer.reducing(state: &_state.value, privateAction: privatization) {
            let uuid = UUID().uuidString
    
            let cancelable = publisher
                .cancellable(id: uuid, in: collection)
                .receive(on: queue)
                .sink(receiveValue: { [weak self] privateAction in
                    guard let self = self else { return }
                    self._send(privateAction: privateAction)
                })
            collection.insert(uuid, cancelable: cancelable)
        } else {
            logDivid()
        }
    }
    
    /// `reducer`: an instance of ProcessorReducerProtocol that defines the behavior of the reducer, which takes actions and private actions and mutates the state accordingly.
    let reducer: any ProcessorReducerProtocol<State, Action, PrivateAction>
    
    /// `_state`: a CurrentValueSubject instance that stores the current state.
    let _state: CurrentValueSubject<State, Never>
    
    let collection: CancellablesCollection = CancellablesCollection()
        
    let queue: DispatchQueue = {
        DispatchQueue(label: "com.AnyProcessor.\(UUID().uuidString)")
    }()
    
}

extension Processor {
    public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
        return self._state.value[keyPath: keyPath]
    }
}

fileprivate extension Processor {
    
    private var prefix: String {
        let _prefix = name ?? String(id.prefix(3))
        return "[Processor][\(_prefix)]"
    }
    
    func log(obj: Any) {
        guard enableLog else { return }
        if let privateAction = obj as? PrivateAction {
            _log(privateAction: privateAction)
        } else if let action = obj as? Action {
            _log(action: action)
        }
    }
    
    func _log(action: Action) {
      #if DEBUG
        if let act = action as? CustomStringConvertible,
           logActionDescriotionFirst {
            logger.log("\(prefix)[Action] \(act.description) - date: \(Date())")
            return
        }
        
        logger.log("\(prefix)[Action] \(dump(action)) - date: \(Date())")
      #endif
    }
    
    func _log(privateAction: PrivateAction) {
        #if DEBUG
        if let act = privateAction as? CustomStringConvertible,
           logActionDescriotionFirst {
            logger.log("\(prefix)[PrivateAction]\(act.description) - date: \(Date())")
            return
        }
        
        logger.log("\(prefix)[PrivateAction] \(dump(privateAction)) - date: \(Date())")
        #endif
    }
   
    func logDivid() {
        guard enableLog else { return }
        #if DEBUG
        logger.log("\(prefix) End -------------------------------------")
        #endif
    }
 
}

extension Processor {
    struct Logger: ProcessorLogger {
        func log(_ message: String) {
          #if DEBUG
            NSLog(message)
          #endif
        }
    }
}
