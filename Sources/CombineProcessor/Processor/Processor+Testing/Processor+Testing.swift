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
    
    init(_ processor: Processor<State, Action, PrivateAction>, title: String? = nil) {
        self.reducer = processor.reducer
        self.title = title
        
        self.processor = Processor(initialState: processor._state.value, reducer: self)
    }
    
    public func transform(_ action: Action) -> PrivateAction {
        return reducer.transform(action)
    }
    
    public func reducing(state: inout State, privateAction privatization: PrivateAction) -> ProcessorPublisher<PrivateAction, Never>? {
        
        let nextPublisher = reducer.reducing(state: &state, privateAction: privatization)
        
        let release = release
        
        let message = message
        
        guard let expected else {
            return nextPublisher
        }
        
        if nextPublisher == nil {
            XCTHandling(nil, expected, release, message)
            return nil
        }
        
        return nextPublisher?.handleEvents(receiveOutput: { pri in
            XCTHandling(pri, expected, release, message)
        }).eraseToProcessor()
    }
            
    private var processor: Processor<State, Action, PrivateAction>? = nil
    
    let reducer: any ProcessorReducerProtocol<State, Action, PrivateAction>
    
    private lazy var release: () -> Void = {
        { [weak self] in
            self?.processor = nil
        }
    }()
    
    private let title: String?
    
    private var message: String = ""
    
    private var expected: PrivateActionEqual?
    
    private typealias PrivateActionEqual = (PrivateAction?) -> Bool
    
}


extension PrivateActionTestProvider {
    
    @discardableResult
    public func privateAction(send privateAction: PrivateAction, _ message: String? = nil, where transform: @escaping (PrivateAction?) -> Bool) -> Processor<State, Action, PrivateAction> {
        
        self.expected = transform
        
        self.processor!._send(privateAction: privateAction)
                
        return processor!
    }
    
    @discardableResult
    public func privateAction(send privateAction: PrivateAction, equal nextPrivateAction: PrivateAction, _ message: String? = nil) -> Processor<State, Action, PrivateAction>  where PrivateAction: Equatable {
        
        let equal: PrivateActionEqual = {
            return nextPrivateAction == $0
        }
        
        self.privateAction(send: privateAction, message, where: equal)
                
        return processor!
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
        
        let title: String?
        
        init(_ processor: Processor<State, Action, PrivateAction>, title: String? = nil) {
            self.processor = processor
            self.title = title
        }
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction, _ message: String? = nil, where transform: @escaping (PrivateAction?) -> Bool) -> Processor<State, Action, PrivateAction> {
            return PrivateActionTestProvider(processor, title: title).privateAction(send: privateAction, where: transform)
        }
        
        @discardableResult
        public func privateAction(send privateAction: PrivateAction, equal nextPrivateAction: PrivateAction, _ message: String? = nil) -> Processor<State, Action, PrivateAction>  where PrivateAction: Equatable {
            return PrivateActionTestProvider(processor, title: title).privateAction(send: privateAction, equal: nextPrivateAction, message)
        }
        
        private let processor: Processor<State, Action, PrivateAction>

    }
    
}
#endif
