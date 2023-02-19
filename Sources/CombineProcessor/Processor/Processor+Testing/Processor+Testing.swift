//
//  File.swift
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


final class PrivateActionTestProvider<State, Action, PrivateAction>:
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
        
        return nextPublisher?.receive(on: queue).handleEvents(receiveOutput: { pri in
            release(pri)()
        }).eraseToProcessor()
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

extension PrivateActionTestProvider {
    
    @discardableResult
    fileprivate func result(send privateAction: PrivateAction) async -> Output {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.processor!._send(privateAction: privateAction)
        }
    }
}

extension Processor {
    
    struct _ProcessorTestProvider {
        
        @discardableResult
        fileprivate func privateAction(processor: Processor<State, Action, PrivateAction>,
                                       send privateAction: PrivateAction,
                                       title: String? = nil,
                                       message: String? = nil,
                                       where expected: @escaping (PrivateAction?) -> Bool) async -> Output {
            
            let result = await PrivateActionTestProvider(processor).result(send: privateAction)
            
            XCTHandling(value: result.privateAction,
                        expected: expected,
                        message: message ?? "",
                        file: "PrivateAction Test - ")
            
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
    
    public struct TestProvider {
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction, message: String? = nil, where expected: @escaping (PrivateAction?) -> Bool) async -> TestProvider {
            
            await _ProcessorTestProvider().privateAction(processor: processor,
                                                         send: privateAction,
                                                         title: title,
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
            
            await self.privateAction(send: privateAction, message: message, where: expected)
            
            return TestProvider(processor, title: nil)
        }
        
        let title: String?
        
        init(_ processor: Processor<State, Action, PrivateAction>, title: String? = nil) {
            self.processor = processor
            self.title = title
        }
        
        private let processor: Processor<State, Action, PrivateAction>
    }
    
}

extension Processor {
    
    public var testAndOutput: TestOutputResultProvider {
        return TestOutputResultProvider(self)
    }
    
    public func testAndOutput(_ title: String) -> TestOutputResultProvider {
        return TestOutputResultProvider(self, title: title)
    }
    
    public struct TestOutputResultProvider {
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction,
                                  message: String? = nil,
                                  where expected: @escaping (PrivateAction?) -> Bool) async -> PrivateAction? {
            
            return await _ProcessorTestProvider().privateAction(processor: processor,
                                                                send: privateAction,
                                                                title: title,
                                                                message: message,
                                                                where: expected).privateAction
        }
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction,
                                  equal nextPrivateAction: PrivateAction,
                                  message: String? = nil) async -> PrivateAction? where PrivateAction: Equatable {
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            return await self.privateAction(send: privateAction, message: message, where: expected)
        }
        
        let title: String?
        
        init(_ processor: Processor<State, Action, PrivateAction>, title: String? = nil) {
            self.processor = processor
            self.title = title
        }
        
        private let processor: Processor<State, Action, PrivateAction>
    }
    
}

#endif
