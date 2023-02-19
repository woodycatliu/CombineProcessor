//
//  File.swift
//  
//
//  Created by Woody Liu on 2023/2/17.
//


#if DEBUG
import Foundation
import Combine

final class PrivateActionTestProvider<State, Action, PrivateAction>:
    ProcessorReducerProtocol {
    
    typealias Output = (privateAction: PrivateAction?, state: State)
    
    init(_ processor: Processor<State, Action, PrivateAction>, title: String? = nil) {
        self.reducer = processor.reducer
        self.title = title
//        self._processor = processor
        self.processor = Processor(initialState: processor._state.value, reducer: self)
    }
    
    public func transform(_ action: Action) -> PrivateAction {
        return reducer.transform(action)
    }
    
    public func reducing(state: inout State, privateAction privatization: PrivateAction) -> ProcessorPublisher<PrivateAction, Never>? {
        
        let nextPublisher = self.reducer.reducing(state: &state, privateAction: privatization)
        
        let release = release
        
        let message = message
        
        guard let expected else {
            return nextPublisher
        }
        
        if nextPublisher == nil {
            release(nil)()
//            XCTHandling(nil, expected, release(nil), message, file: "PrivateAction Test - ")
            return nil
        }
        
        return nextPublisher?.receive(on: queue).handleEvents(receiveOutput: { [weak self] pri in
            self?.release(pri)()
//            XCTHandling(pri, expected, release(pri), message, file: "PrivateAction Test - ")
        }).eraseToProcessor()
    }
                
    let reducer: any ProcessorReducerProtocol<State, Action, PrivateAction>
    
    private lazy var release: (PrivateAction?) -> (() -> Void) = {
        return { pri in
            return { [weak self] in
                guard let self,
                      let conti = self.continuation else { return }
                self.lock.lock()
                defer { self.lock.unlock() }
                let state = self.processor!._state.value
                self.continuation = nil
                conti.resume(returning: (pri, state))
                self.processor = nil
            }
        }
    }()
    
    private let title: String?
    
    private var message: String = ""
    
    private var expected: PrivateActionEqual?
    
    private typealias PrivateActionEqual = (PrivateAction?) -> Bool
    
    private var continuation: CheckedContinuation<Output, Never>?
        
    private var processor: Processor<State, Action, PrivateAction>? = nil
    
    private let lock: NSRecursiveLock = NSRecursiveLock()
    
    private let queue: DispatchQueue = DispatchQueue(label: "com.PrivateActionTestProvider.test")
    
}

extension PrivateActionTestProvider {
    
    @discardableResult
    public func privateAction(send privateAction: PrivateAction, _ message: String? = nil, where expected: @escaping (PrivateAction?) -> Bool) async -> Output {
        
        self.expected = expected
        
        self.message = message ?? ""
        
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.processor!._send(privateAction: privateAction)
        }
    }
    
    @discardableResult
    public func privateAction(send privateAction: PrivateAction, equal nextPrivateAction: PrivateAction, _ message: String? = nil) async -> Output  where PrivateAction: Equatable {
        
        self.message = message ?? ""
        
        let equal: PrivateActionEqual = {
            return nextPrivateAction == $0
        }
        
        return await self.privateAction(send: privateAction, message, where: equal)
    }
    
    func logTitle(_ title: String?) {
        guard let title else { return }
        NSLog(title, ":")
    }
}

extension Processor {
    
   public var test: TestPrivoder {
        return TestPrivoder(self)
    }
    
   public func test(_ title: String) -> TestPrivoder {
        return TestPrivoder(self, title: title)
    }
    
    public struct TestPrivoder {
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction, message: String? = nil, where expected: @escaping (PrivateAction?) -> Bool) async -> TestPrivoder {
            let tuple = await PrivateActionTestProvider(processor, title: title).privateAction(send: privateAction, message, where: expected)
            
            XCTHandling(tuple.privateAction, expected, {}, message ?? "", file: "PrivateAction Test - ")
            
            return TestPrivoder(processor, title: title)
        }
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction, equal nextPrivateAction: PrivateAction, message: String? = nil) async -> Processor.TestPrivoder where PrivateAction: Equatable {

            let tuple = await PrivateActionTestProvider(processor, title: title).privateAction(send: privateAction, equal: nextPrivateAction, message)
            
            let expected: (PrivateAction?) -> Bool = {
                return nextPrivateAction == $0
            }
            
            XCTHandling(tuple.privateAction, expected, {}, message ?? "", file: "PrivateAction Test - ")

            return TestPrivoder(processor, title: title)
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
    
    public var testAndOutput: TestOutputResultPrivoder {
        return TestOutputResultPrivoder(self)
    }
    
    public func testAndOutput(_ title: String) -> TestOutputResultPrivoder {
         return TestOutputResultPrivoder(self, title: title)
     }
    
    public struct TestOutputResultPrivoder {
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction, message: String? = nil, where expected: @escaping (PrivateAction?) -> Bool) async -> PrivateAction? {
            return await PrivateActionTestProvider(processor, title: title).privateAction(send: privateAction, message, where: expected).privateAction
        }
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction, equal nextPrivateAction: PrivateAction, message: String? = nil) async -> PrivateAction? where PrivateAction: Equatable {
            
            return await PrivateActionTestProvider(processor, title: title).privateAction(send: privateAction, equal: nextPrivateAction, message).privateAction
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
