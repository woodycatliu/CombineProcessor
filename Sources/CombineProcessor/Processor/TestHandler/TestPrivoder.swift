//
//  TestPrivoder.swift
//
//
//  Created by Woody Liu on 2023/2/17.
//


#if DEBUG
import Foundation
import Combine

extension Processor {
    
    fileprivate typealias Output = (privateAction: PrivateAction?, state: State)
    
    fileprivate typealias PrivateActionEqual = (PrivateAction?) -> Bool
}

/**
# Documentation for ProcessorTestProvider Class

 The ProcessorTestProvider class is a final class that implements the ProcessorReducerProtocol protocol. It is designed to provide testing capabilities for the Processor class.

 ## Properties

 - `reducer` : a property of type any ProcessorReducerProtocol<State, Action, PrivateAction>. It represents the reducer that the processor test provider uses to transform actions and reduce state.
 Methods

 - `init(_ processor: Processor<State, Action, PrivateAction>)` : a designated initializer that takes a Processor instance and sets up the test provider with the same initial state and reducer. It also sets the same logging and identification properties.
 - `transform(_ action: Action) -> PrivateAction` : a method that transforms an action to a private action using the reducer.
 - `reducing(state: inout State, privateAction privatization: PrivateAction) -> ProcessorPublisher<PrivateAction, Never>?` : a method that reduces state given a private action. It returns a ProcessorPublisher that emits a private action and never fails.
 - `release: (PrivateAction?) -> (() -> Void)` : a private property that returns a closure that releases a private action to a CheckedContinuation.
 - `continuation` : CheckedContinuation<Output, Never>?: a private property that holds a CheckedContinuation instance.
 - `processor` : Processor<State, Action, PrivateAction>?: a private property that holds a reference to the Processor instance used by the test provider.
 - `queue`: DispatchQueue: a private property that holds a reference to a DispatchQueue instance used by the test provider.
 
 ## Extensions

 - `fileprivate typealias Output = (privateAction: PrivateAction?, state: State)` : an extension that defines a type alias for the output of the processor, which is a tuple consisting of an optional private action and the state.
 - `fileprivate typealias PrivateActionEqual = (PrivateAction?) -> Bool` : an extension that defines a type alias for a function that compares two private actions and returns a Boolean value indicating whether they are equal.
 */
final class ProcessorTestProvider<State, Action, PrivateAction>:
    ProcessorReducerProtocol {
    
    fileprivate typealias Output = (privateAction: PrivateAction?, state: State)
    
    init(_ processor: Processor<State, Action, PrivateAction>) {
        self.reducer = processor.reducer
        self.processor = Processor(initialState: processor._state.value, reducer: self)
        self.processor?.enableLog = processor.enableLog
        self.processor?.id = processor.id
        self.processor?.logActionDescriotionFirst = processor.logActionDescriotionFirst
    }
    
    public func transform(_ action: Action) -> PrivateAction {
        return reducer.transform(action)
    }
    
    public func reducing(state: inout State, privateAction privatization: PrivateAction) -> ProcessorPublisher<PrivateAction, Never>? {
        
        let nextPublisher = self.reducer.reducing(state: &state, privateAction: privatization)
        
        let release = release
        
        if nextPublisher == nil {
            queue.async {
                release(nil)()
            }
            return nil
        }
        
        return nextPublisher?
            .receive(on: queue)
            .handleEvents(receiveOutput: { pri in
                release(pri)()
            })
            .eraseToProcessor()
    }
    
    let reducer: any ProcessorReducerProtocol<State, Action, PrivateAction>
    
    private lazy var release: (PrivateAction?) -> (() -> Void) = {
        return { pri in
            return { [weak self] in
                guard let self,
                      let conti = self.continuation else { return }
                let state = self.processor!._state.value
                self.continuation = nil
                conti.resume(returning: (pri, state))
                self.processor = nil
            }
        }
    }()
    
    private var continuation: CheckedContinuation<Output, Never>?
    
    private var processor: Processor<State, Action, PrivateAction>? = nil
    
    private let queue: DispatchQueue = DispatchQueue(label: "com.PrivateActionTestProvider.test")
    
}

extension ProcessorTestProvider {
    
    @discardableResult
    /// This method sends a private action to the processor and waits for the next output to be emitted.
    /// - Parameter privateAction: a parameter of type PrivateAction. It represents the private action to be sent to the processor.
    /// - Returns:
    ///        - `Output`: a tuple consisting of an optional private action and the state.
    fileprivate func result(send privateAction: PrivateAction) async -> Output {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.processor!._send(privateAction: privateAction)
        }
    }
}

/**
# Processor
 
 The Processor class includes several methods that aid in testing
 
 ## Properties
  - `test` : TestProvider - This property returns a TestProvider instance.
 - `test(_ title: String) -> TestProvider` :  This method returns a TestProvider instance with a specified title.
 */
extension Processor {
    
    /**
     # _ProcessorTestProvider

     The _ProcessorTestProvider struct includes private methods that are used to support the public methods of TestProvider.
     
     ## Methods
     
     - `privateAction(processor: Processor<State, Action, PrivateAction>, sendAction action: Action, message: String?, where expected: @escaping (PrivateAction?) -> Bool) async -> Output` :  This method sends an action and returns the Output instance.
     - `privateAction(processor: Processor<State, Action, PrivateAction>, send privateAction: PrivateAction, message: String?, where expected: @escaping (PrivateAction?) -> Bool) async -> Output`:   This method sends a private action and returns the Output instance.
     - `state(processor: Processor<State, Action, PrivateAction>, send privateAction: PrivateAction, message: String?, where expected: @escaping (State) -> Bool) async -> Output` :   This method sends a private action and returns the Output instance.
     */
    struct _ProcessorTestProvider {
        
        @discardableResult
        fileprivate func privateAction(processor: Processor<State, Action, PrivateAction>,
                                       sendAction action: Action,
                                       message: String? = nil,
                                       where expected: @escaping (PrivateAction?) -> Bool) async -> Output {
            let privateAction = processor.reducer.transform(action)
            
            XCTHandling(value: privateAction,
                        expected: expected,
                        prifix: "PrivateAction Test - ",
                        message: message ?? "")
            
            return (privateAction: privateAction,
                    state: processor._state.value)
        }
        
        @discardableResult
        fileprivate func privateAction(processor: Processor<State, Action, PrivateAction>,
                                       send privateAction: PrivateAction,
                                       message: String? = nil,
                                       where expected: @escaping (PrivateAction?) -> Bool) async -> Output {
            
            let result = await ProcessorTestProvider(processor).result(send: privateAction)
            
            XCTHandling(value: result.privateAction,
                        expected: expected,
                        prifix: "PrivateAction Test - ",
                        message: message ?? "")
            
            return result
        }
        
        @discardableResult
        fileprivate func state(processor: Processor<State, Action, PrivateAction>,
                               send privateAction: PrivateAction,
                               message: String? = nil,
                               where expected: @escaping (State) -> Bool) async -> Output {
            
            let result = await ProcessorTestProvider(processor).result(send: privateAction)
            
            XCTHandling(value: result.state,
                        expected: expected,
                        prifix: "State Test - ",
                        message: message ?? "")
            
            return result
        }
        
        fileprivate func _ProcessorTestProvider() {}
        
    }
    
    public var test: TestProvider {
        return TestProvider(self)
    }
    
    public func test(_ title: String) -> TestProvider {
        return TestProvider(self, title: title)
    }
    
    /**
    # TestProvider
     The TestProvider struct is used to provide several testing methods.
     
     ## Properties
     - `title: String?` :  This property contains the title for the TestProvider instance.
     
     ## Methods
     
     - `privateAction(sendAction action: Action, message: String?, where expected: (PrivateAction?) -> Bool) async -> TestProvider` :  This method sends an action and returns the TestProvider instance.
     
     - `privateAction(sendAction action: Action, equal nextPrivateAction: PrivateAction, message: String?) async -> Processor.TestProvider where PrivateAction: Equatable` :   This method sends an action and checks if the expected private action is equal to the next private action.
     - `privateAction(send privateAction: PrivateAction, message: String?, where expected: (PrivateAction?) -> Bool) async -> TestProvider` :  This method sends a private action and returns the TestProvider instance.
     - `privateAction(send privateAction: PrivateAction, equal nextPrivateAction: PrivateAction, message: String?) async -> Processor.TestProvider where PrivateAction: Equatable` :  This method sends a private action and checks if the expected private action is equal to the next private action.
     - ` state(send privateAction: PrivateAction, title: String?, message: String?, where expected: (State) -> Bool) async -> Processor.TestProvider` :  This method sends a private action and returns the TestProvider instance.
     - `state(send privateAction: PrivateAction, equal newState: State, message: String?) async -> Processor.TestProvider where State: Equatable` :  This method sends a private action and checks if the expected state is equal to the next state.
     - `state<Value>(send privateAction: PrivateAction, keyPath: KeyPath<State, Value>, equal newState: State, message: String?) async -> Processor.TestProvider where Value: Equatable` :  This method sends a private action and checks if the expected keyPath is equal to the next state.
     */
    public struct TestProvider {
        
        @discardableResult
        public func privateAction(sendAction action: Action,
                                  message: String? = nil,
                                  where expected: @escaping (PrivateAction?) -> Bool) async -> TestProvider {
            
            await _ProcessorTestProvider().privateAction(processor: processor,
                                                         sendAction: action,
                                                         message: message,
                                                         where: expected)
            
            return TestProvider(processor, title: nil)
        }
        
        @discardableResult
        public func privateAction(sendAction action: Action,
                                  equal nextPrivateAction: PrivateAction,
                                  message: String? = nil) async -> Processor.TestProvider where PrivateAction: Equatable {
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            return await self.privateAction(sendAction: action,
                                            message: message,
                                            where: expected)
        }
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction,
                                  message: String? = nil,
                                  where expected: @escaping (PrivateAction?) -> Bool) async -> TestProvider {
            
            await _ProcessorTestProvider().privateAction(processor: processor,
                                                         send: privateAction,
                                                         message: message,
                                                         where: expected)
            
            return TestProvider(processor, title: nil)
        }
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction,
                                  equal nextPrivateAction: PrivateAction,
                                  message: String? = nil) async -> Processor.TestProvider where PrivateAction: Equatable {
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            return await self.privateAction(send: privateAction,
                                            message: message,
                                            where: expected)
        }
        
        @discardableResult
        fileprivate func state(send privateAction: PrivateAction,
                               title: String? = nil,
                               message: String? = nil,
                               where expected: @escaping (State) -> Bool) async -> Processor.TestProvider {
            
            await _ProcessorTestProvider().state(processor: processor,
                                                 send: privateAction,
                                                 where: expected)
            
            return TestProvider(processor, title: nil)
        }
        
        @discardableResult
        public func state(send privateAction: PrivateAction,
                          equal newState: State,
                          message: String? = nil) async -> Processor.TestProvider where State: Equatable {
            let expected: (State) -> Bool = {
                return newState == $0
            }
            
            return await self.state(send: privateAction,
                                    message: message,
                                    where: expected)
        }
        
        @discardableResult
        public func state<Value>(send privateAction: PrivateAction,
                                 keyPath: KeyPath<State, Value>,
                                 equal newState: State,
                                 message: String? = nil) async -> Processor.TestProvider where Value: Equatable {
            let expected: (State) -> Bool = {
                return newState[keyPath: keyPath] == $0[keyPath: keyPath]
            }
            
            return await self.state(send: privateAction,
                                    message: message,
                                    where: expected)
        }
        
        let title: String?
        
        init(_ processor: Processor<State, Action, PrivateAction>, title: String? = nil) {
            self.processor = processor
            self.title = title
        }
        
        private let processor: Processor<State, Action, PrivateAction>
    }
    
}

extension Processor.TestProvider {
    
    /// The output property is a computed property that returns a structure which provides several methods for testing the output of the specified type.
    public var output: TestOutputResultProvider {
        return TestOutputResultProvider(processor, title: title)
    }
    
    public struct TestOutputResultProvider {
        
        @discardableResult
        /// For testing next private action
        /// - Parameters:
        ///   - action: enter `Action`
        ///   - message: the message will show if failed
        ///   - expected: Inject a closure to verify if the next `PrivateAction` matches the expected one.
        /// - Returns: Current `PrivateAction`
        public func privateAction(sendAction action: Action,
                                  message: String? = nil,
                                  where expected: @escaping (PrivateAction?) -> Bool) async -> PrivateAction {
            return await Processor._ProcessorTestProvider().privateAction(processor: processor,
                                                                          sendAction: action,
                                                                          message: message,
                                                                          where: expected).privateAction!
        }
        
        @discardableResult
        /// To test the next `PrivateAction` when the `PrivateAction` type confirms to Equatable,
        /// - Parameters:
        ///   - action: enter `Action`
        ///   - message: the message will show if failed
        ///   - nextPrivateAction: experted next `PrivateAction`
        /// - Returns: Current `PrivateAction`
        public func privateAction(sendAction action: Action,
                                  equal nextPrivateAction: PrivateAction,
                                  message: String? = nil) async -> PrivateAction where PrivateAction: Equatable {
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            return await self.privateAction(sendAction: action,
                                            message: message,
                                            where: expected)
        }
        
        @discardableResult
        /// To test if the next `PrivateAction` will be nil.
        /// - Parameters:
        ///   - action: enter `Action`
        ///   - message: the message will show if failed
        ///   - expected: Inject a closure to verify if the next `PrivateAction` matches the expected one.`
        /// - Returns:  Nullable `PrivateAction`
        public func privateAction(send privateAction: PrivateAction,
                                  message: String? = nil,
                                  where expected: @escaping (PrivateAction?) -> Bool) async -> PrivateAction? {
            
            return await Processor._ProcessorTestProvider().privateAction(processor: processor,
                                                                          send: privateAction,
                                                                          message: message,
                                                                          where: expected).privateAction
        }
        
        @discardableResult
        /// To test if the next `PrivateAction` will be nil.
        /// - Parameters:
        ///   - action: enter `Action`
        ///   - nextPrivateAction: experted next `PrivateAction`
        ///   - message: the message will show if failed
        /// - Returns:  Nullable `PrivateAction`
        public func privateAction(send privateAction: PrivateAction,
                                  equal nextPrivateAction: PrivateAction,
                                  message: String? = nil) async -> PrivateAction? where PrivateAction: Equatable {
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            return await self.privateAction(send: privateAction,
                                            message: message,
                                            where: expected)
        }
        
        @discardableResult
        /// To test the stored `State` after executing the `PrivateAction`.
        /// - Parameters:
        ///   - privateAction: PrivateAction
        ///   - title: Testing Title
        ///   - message: Failed message
        ///   - expected: Inject a closure to verify if the `States` matches the expected one.`
        /// - Returns: Current `State`
        fileprivate func state(send privateAction: PrivateAction,
                               title: String? = nil,
                               message: String? = nil,
                               where expected: @escaping (State) -> Bool) async -> State {
            
            return await Processor._ProcessorTestProvider().state(processor: processor,
                                                                  send: privateAction,
                                                                  message: message,
                                                                  where: expected).state
        }
        
        @discardableResult
        /// To test the stored `State` after executing the `PrivateAction`.
        /// - Parameters:
        ///   - privateAction: PrivateAction
        ///   - title: Testing Title
        ///   - message: Failed message
        ///   - expected: Inject a closure to verify if the `States` matches the expected one.`
        /// - Returns: Current `State`
        public func state(send privateAction: PrivateAction,
                          equal newState: State,
                          message: String? = nil) async -> State where State: Equatable {
            
            let expected: (State) -> Bool = {
                return newState == $0
            }
            
            return await self.state(send: privateAction,
                                    title: title,
                                    message: message,
                                    where: expected)
        }
        
        @discardableResult
        /// To test the stored `State` after executing the `PrivateAction`.
        /// - Parameters:
        ///   - privateAction: PrivateAction
        ///   - title: Testing Title
        ///   - message: Failed message
        ///   - expected: Inject a closure to verify if the `States` matches the expected one.`
        /// - Returns: Current `State`
        public func state<Value>(send privateAction: PrivateAction,
                                 keyPath: KeyPath<State, Value>,
                                 equal newState: State,
                                 message: String? = nil) async -> State where Value: Equatable {
            let expected: (State) -> Bool = {
                return newState[keyPath: keyPath] == $0[keyPath: keyPath]
            }
            
            return await self.state(send: privateAction,
                                    message: message,
                                    where: expected)
        }
        
        let title: String?
        
        init(_ processor: Processor<State, Action, PrivateAction>, title: String? = nil) {
            self.processor = processor
            self.title = title
        }
        
        private let processor: Processor<State, Action, PrivateAction>
    }
    
}

extension Processor.TestProvider {
    
    /// `composable` provides a comprehensive testing process.
    ///  Example :  PrivateAction.A -> PrivateAction.B -> PrivateAction.C
    ///  ```
    ///     let processor = Processor()
    ///
    ///     await processor.composable
    ///                    .privateAction(sendAction: Action.A, equal: PrivateAction.A)
    ///                    .nextAction(equal: PrivateAction.B)
    ///                    .nextAction(equal: PrivateAction.C)
    ///  ```
    public var composable: ComposableTestProvider {
        return ComposableTestProvider(processor, title: title)
    }
    
    public struct ComposableTestProvider {
        
        @discardableResult
        /// To test next `PrivateAction` after enter `Action.`
        /// - Parameters:
        ///   - action: enter `Action`
        ///   - expected: Inject a closure to verify if the next `PrivateAction` matches the expected one.`
        ///   - message: the message will show if failed
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func privateAction(sendAction action: Action,
                                  message: String? = nil,
                                  where expected: @escaping (PrivateAction?) -> Bool) async -> CombinedTestProvider {
            let result = await Processor._ProcessorTestProvider().privateAction(processor: processor,
                                                                                sendAction: action,
                                                                                message: message,
                                                                                where: expected)
            return CombinedTestProvider(processor: processor,
                                        state: result.state,
                                        current: result.privateAction)
        }
        
        @discardableResult
        /// To test next `PrivateAction` after enter `Action.`
        /// - Parameters:
        ///   - action: enter `Action`
        ///   - equal: experted next `PrivateACtion`
        ///   - message: the message will show if failed
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func privateAction(sendAction action: Action,
                                  equal nextPrivateAction: PrivateAction,
                                  message: String? = nil) async -> CombinedTestProvider where PrivateAction: Equatable {
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            return await self.privateAction(sendAction: action,
                                            message: message,
                                            where: expected)
        }
        
        @discardableResult
        /// To test next `PrivateAction` after enter `PrivateAction.`
        /// - Parameters:
        ///   - privateAction: enter `PrivateAction`
        ///   - expected: Inject a closure to verify if the next `PrivateAction` matches the expected one.`
        ///   - message: the message will show if failed
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func privateAction(send privateAction: PrivateAction,
                                  message: String? = nil,
                                  where expected: @escaping (PrivateAction?) -> Bool) async -> CombinedTestProvider {
            
            let resutl = await Processor._ProcessorTestProvider().privateAction(processor: processor,
                                                                                send: privateAction,
                                                                                message: message,
                                                                                where: expected)
            
            return CombinedTestProvider(processor: processor,
                                        state: resutl.state,
                                        current: resutl.privateAction)
        }
        
        @discardableResult
        /// To test next `PrivateAction` after enter `PrivateAction.`
        /// - Parameters:
        ///   - privateAction: enter `PrivateAction`
        ///   - nextPrivateAction: expected next `PrivateAction` matches the expected one.`
        ///   - message: the message will show if failed
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func privateAction(send privateAction: PrivateAction,
                                  equal nextPrivateAction: PrivateAction,
                                  message: String? = nil) async -> CombinedTestProvider where PrivateAction: Equatable {
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            return await self.privateAction(send: privateAction,
                                            message: message,
                                            where: expected)
        }
        
        @discardableResult
        /// To test `State` after enter `PrivateAction.`
        /// - Parameters:
        ///   - privateAction: enter `PrivateAction`
        ///   - expected: Inject a closure to verify if the next `State` matches the expected one.`
        ///   - message: the message will show if failed
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        fileprivate func state(send privateAction: PrivateAction,
                               message: String? = nil,
                               where expected: @escaping (State) -> Bool) async -> CombinedTestProvider {
            
            let resutl = await Processor._ProcessorTestProvider().state(processor: processor,
                                                                        send: privateAction,
                                                                        where: expected)
            
            return CombinedTestProvider(processor: processor,
                                        state: resutl.state,
                                        current: resutl.privateAction)
        }
        
        @discardableResult
        /// To test `State` after enter `PrivateAction.`
        /// - Parameters:
        ///   - privateAction: enter `PrivateAction`
        ///   - newState: expected next `State` matches the expected one.`
        ///   - message: the message will show if failed
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func state(send privateAction: PrivateAction,
                          equal newState: State,
                          message: String? = nil) async -> CombinedTestProvider where State: Equatable {
            
            let expected: (State) -> Bool = {
                return newState == $0
            }
            
            return await self.state(send: privateAction,
                                    message: message,
                                    where: expected)
        }
        
        @discardableResult
        /// To test `State`properties after enter `PrivateAction.`
        /// - Parameters:
        ///   - privateAction: enter `PrivateAction`
        ///   - keyPath: Keypath withIn State
        ///   - newState: expected next `State` matches the expected one.`
        ///   - message: the message will show if failed
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func state<Value>(send privateAction: PrivateAction,
                                 keyPath: KeyPath<State, Value>,
                                 equal newState: State,
                                 message: String? = nil) async -> CombinedTestProvider where Value: Equatable {
            
            let expected: (State) -> Bool = {
                return newState[keyPath: keyPath] == $0[keyPath: keyPath]
            }
            
            return await self.state(send: privateAction,
                                    message: message,
                                    where: expected)
        }
        
        let title: String?
        
        init(_ processor: Processor<State, Action, PrivateAction>, title: String? = nil) {
            self.processor = processor
            self.title = title
        }
        
        private let processor: Processor<State, Action, PrivateAction>
    }
    
    
    public struct CombinedTestProvider {
        
        @discardableResult
        
        /// Combined to testing next `PrivateAction`
        /// - Parameters:
        ///   - message:  the message will show if failed
        ///   - expected: Inject a closure to verify if the next `State` matches the expected one.`
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func nextPrivateAction(message: String? = nil,
                                      where expected: @escaping (PrivateAction?) -> Bool) async -> CombinedTestProvider {
            
            CombinedTestProvider.checkCurrentNotNull(current)
            
            return await ComposableTestProvider(processor).privateAction(send: current!,
                                                                         where: expected)
        }
        
        @discardableResult
        /// Combined to testing next `PrivateAction`
        /// - Parameters:
        ///   - message: the message will show if failed
        ///   - nextPrivateAction: expected next `PrivateAction` matches the expected one.`
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func nextPrivateAction(equal nextPrivateAction: PrivateAction,
                                      message: String? = nil) async -> CombinedTestProvider where PrivateAction: Equatable {
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            return await self.nextPrivateAction(message: message, where: expected)
        }
        
        @discardableResult
        /// Combined to testing next `State`
        /// - Parameters:
        ///   - message:  the message will show if failed
        ///   - expected: Inject a closure to verify if the next `State` matches the expected one.`
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func nextState(message: String? = nil,
                              where expected: @escaping (State) -> Bool) async -> CombinedTestProvider {
            
            CombinedTestProvider.checkCurrentNotNull(current)
            
            return await ComposableTestProvider(processor).state(send: current!,
                                                                 where: expected)
        }
        
        @discardableResult
        /// Combined to testing next `State`
        /// - Parameters:
        ///   - message:  the message will show if failed
        ///   - newState: expected next `State` matches the expected one.`
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func nextState(equal newState: State,
                              message: String? = nil) async -> CombinedTestProvider where State: Equatable {
            
            let expected: (State) -> Bool = {
                return newState == $0
            }
            
            return await self.nextState(message: message, where: expected)
        }
        
        @discardableResult
        /// Combined to testing next `State`
        /// - Parameters:
        ///   - keyPath: Keypath withIn State
        ///   - message: the message will show if failed
        ///   - newState: expected next `State` matches the expected one.`
        /// - Returns: `CombinedTestProvider` provider next `PrivateAction` or `State`  after executing the current `PrivateAction`
        public func nextState<Value>(keyPath: KeyPath<State, Value>,
                                     equal newState: State,
                                     message: String? = nil) async -> CombinedTestProvider where Value: Equatable {
            
            let expected: (State) -> Bool = {
                return newState[keyPath: keyPath] == $0[keyPath: keyPath]
            }
            
            return await self.nextState(message: message,
                                        where: expected)
        }
        
        /// To test the final step of the entire process.
        ///  `Point`: `The PrivateAction` is always nil in final step .
        /// - Parameters:
        ///   - message: the message will show if failed
        ///   - expected: Inject a closure to verify if the next `State` matches the expected one.`
        public func final(message: String? = nil, whereState expected: @escaping (State) -> Bool) async {
            
            await self.nextPrivateAction(message: message, where: {
                $0 == nil
            })
            
           await self.nextState(message: message, where: expected)
        }
        
        /// To test the final step of the entire process.
        ///  `Point`: `The PrivateAction` is always nil in final step .
        /// - Parameters:
        ///   - message: the message will show if failed
        ///   - newState: expected next `State` matches the expected one.
        public func final(equal newState: State, message: String? = nil) async where State : Equatable {
            
            await self.nextPrivateAction(message: message, where: {
                $0 == nil
            })
            
            await self.nextState(equal: newState, message: message)
        }
        
        /// To test the final step of the entire process.
        ///  `Point`: `The PrivateAction` is always nil in final step .
        /// - Parameters:
        ///   - keyPath: Keypath withIn State
        ///   - message: the message will show if failed
        ///   - newState: expected next `State` matches the expected one.
        public func final<Value>(keyPath: KeyPath<State, Value>, equal newState: State, message: String? = nil) async where Value : Equatable {
            
            await self.nextPrivateAction(message: message, where: {
                $0 == nil
            })
            
            await self.nextState(keyPath: keyPath, equal: newState)
        }
        
        init(processor: Processor<State, Action, PrivateAction>, state: State, current privateAction: PrivateAction?) {
                        
            self.current = privateAction
            
            self.processor = Processor(initialState: state, reducer: processor.reducer)
            
            self.processor.enableLog = processor.enableLog
            
            self.processor.logActionDescriotionFirst = processor.logActionDescriotionFirst
            
            self.processor.id = processor.id
        }
        
        private let current: PrivateAction?
        
        private let processor: Processor<State, Action, PrivateAction>
        
        static func checkCurrentNotNull(_ privateAction: PrivateAction?) {
            XCTHandling(value: privateAction, expected: {
                $0 != nil
            })
        }
    }
    
}

#endif
