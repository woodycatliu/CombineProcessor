//
//  CancellablesStorableStorable.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

import Foundation
import Combine

public protocol CancellablesStorableStorable: AnyObject {
    var storage: [String: Set<AnyCancellable>] { get }
    func insert(_ id: String, cancelable: AnyCancellable?)
    func remove(_ id: String, cancelable: AnyCancellable?)
    func cancel(id: String)
}

class CancellablesCollection: CancellablesStorableStorable {
 
    public func insert(_ id: String, cancelable: AnyCancellable?) {
        guard let cancelable = cancelable else { return }
        if storage[id] == nil {
           storage[id] = []
        }
        storage[id]?.insert(cancelable)
    }
    
    public func cancel(id: String) {
        storage[id]?.forEach {
            $0.cancel()
        }
        storage[id] = nil
    }
    
    public func remove(_ id: String, cancelable: AnyCancellable?) {
        if let cancelable = cancelable,
           storage[id] != nil,
           storage[id]!.contains(cancelable) {
            cancelable.cancel()
            storage[id]?.remove(cancelable)
        }
    }
        
    private(set) var storage: [String: Set<AnyCancellable>] {
        set  {
            defer { lock.unlock() }
            lock.lock()
            _storage = newValue
        }
        
        get {
            return _storage
        }
    }
    
    private var _storage: [String: Set<AnyCancellable>] = [:]
    
    private let lock: NSRecursiveLock = NSRecursiveLock()

}
