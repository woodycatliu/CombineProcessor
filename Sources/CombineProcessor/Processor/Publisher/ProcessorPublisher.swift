//
//  ProcessorPublisher.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

import Combine

/**
 # Documentation for ProcessorPublisher

 `ProcessorPublisher` is a generic type that conforms to the `Publisher` protocol, which provides a mechanism for publishing a sequence of values and error conditions over time. It allows you to process a stream of data, modify it, and publish it again to downstream subscribers.

 ## Properties
 
 - `upstream` : A property that holds the upstream publisher.
 
 ## Methods
 
 - `init(_ publisher: P)` : A method that initializes an instance of `ProcessorPublisher` with the provided upstream publisher.
 - `receive(subscriber:)` : A method that subscribes a downstream subscriber to the upstream publisher.
 - `cancellable(id:in:)` : A method that returns a `ProcessorPublisher` that cancels the subscription when a specific condition is met.
 - `send(_ value: Output)`: A static method that returns a `ProcessorPublisher` with a single value of type Output.
 
 ## Extensions
 
 - `eraseToProcessor()`: An extension method on Publisher that returns a `ProcessorPublisher` by erasing the type of the upstream publisher's failure condition.
 - `catchToResultProcessor(_ transform:)` : An extension method on Publisher that returns a `ProcessorPublisher` that transforms the publisher's failure condition into a Result type.
 - `catchToDeresultProcessor(onSuccess:onError:)`: An extension method on Publisher that returns a `ProcessorPublisher` that transforms the publisher's output and failure conditions into a specific type based on provided onSuccess and onError functions.
 
 
 */

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
            
            // If the collection is empty, cancel the subscription
            if collectionCancellables?.storage[id]?.isEmpty == .some(true) {
                collectionCancellables?.cancel(id: id)
            }
        }
        
        // Subscribe to the upstream publisher until the PassthroughSubject receives an output event.
        // Inserts cancellationCancellable into the CancellablesStorable collection when a new subscription is received,
        // and cancels the cancellationCancellable when a completion event is received or when the subscription is cancelled.
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
