//
//  ProcessorPublisher.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

import Combine

public struct ProcessorPublisher<Output, Failure: Error>: Publisher {
    public let upstream: AnyPublisher<Output, Failure>

    public init<P: Publisher>(_ publisher: P) where P.Output == Output, P.Failure == Failure {
        self.upstream = publisher.eraseToAnyPublisher()
      }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        self.upstream.subscribe(subscriber)
    }
    
    public func cancellable(id: String, in collectionCancellables: CancellablesStorableStorable)-> ProcessorPublisher {
        let cancellableSubject = PassthroughSubject<Void, Never>()
        var cancellationCancellable: AnyCancellable!
        cancellationCancellable = AnyCancellable { [weak collectionCancellables] in
            cancellableSubject.send(())
            cancellableSubject.send(completion: .finished)
            collectionCancellables?.remove(id, cancelable: cancellationCancellable)
            
            if collectionCancellables?.storage[id]?.isEmpty == .some(true) {
                collectionCancellables?.cancel(id: id)
            }
        }
        
        return
            Deferred { () -> Publishers.HandleEvents<Publishers.PrefixUntilOutput<Self, PassthroughSubject<Void, Never>>> in
        
                return self.prefix(untilOutputFrom: cancellableSubject)
                    .handleEvents(receiveSubscription: { [weak collectionCancellables] _ in
                        
                        collectionCancellables?.insert(id, cancelable: cancellationCancellable)
                        
                    }, receiveCompletion: { _ in cancellationCancellable.cancel() }, receiveCancel: cancellationCancellable.cancel)
            }.eraseToProcessor()
    }
    
}

extension ProcessorPublisher {
    
    public static func send(_ value: Output) -> Self {
        Self(Just(value).setFailureType(to: Failure.self))
    }
    
}

extension Publisher {
    public func eraseToProcessor() -> ProcessorPublisher<Output, Failure> {
        ProcessorPublisher(self)
      }
}

// MARK: Catch
extension Publisher {
    
    public func catchToResultProcessor<T>(_ transform: @escaping (Result<Output, Failure>) -> T) -> ProcessorPublisher<T, Never> {
        return catchToResult()
            .map { transform($0) }
            .eraseToProcessor()
    }
    
    public func catchToDeresultProcessor<T>(onSuccess: @escaping (Output) -> T, onError: @escaping (Failure) -> T) -> ProcessorPublisher<T, Never> {
        return catchToResult()
            .map {
                switch $0 {
                case .success(let value):
                    return onSuccess(value)
                case .failure(let error):
                    return onError(error)
                }
            }.eraseToProcessor()
    }
    
    fileprivate func catchToResult() -> AnyPublisher<Result<Output, Failure>, Never> {
        return map(Result.success)
            .catch { Just(.failure($0)) }
            .eraseToAnyPublisher()
    }
}
