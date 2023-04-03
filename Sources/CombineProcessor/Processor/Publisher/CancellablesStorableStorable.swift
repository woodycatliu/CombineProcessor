//
//  CancellablesStorableStorable.swift
//  CombineProcessor
//
//  Created by Woody Liu on 2023/2/2.
//

import Foundation
import Combine

/**
 # Protocol CancellablesStorableStorable
 The CancellablesStorableStorable protocol defines a set of methods that allow storing and cancelling cancellable objects.
 
 ## Properties
 - `storage` : A dictionary that stores a collection of AnyCancellable objects for each specific identifier.
 
 ## Methods
 
 - `insert(_ id: String, cancelable: AnyCancellable?)` : Inserts a new AnyCancellable object into the collection with the specified id.
 - `cancel(id: String)` : Cancels all AnyCancellable objects associated with the specified id.
 - `remove(_ id: String, cancelable: AnyCancellable?)` : Removes a specific AnyCancellable object from the collection with the specified id.
 */
public protocol CancellablesStorableStorable: AnyObject {
    var storage: [String: Set<AnyCancellable>] { get }
    func insert(_ id: String, cancelable: AnyCancellable?)
    func remove(_ id: String, cancelable: AnyCancellable?)
    func cancel(id: String)
}

/**
 # Documentation for CancellablesCollection
 
 The CancellablesCollection class is a concrete implementation of the CancellablesStorableStorable protocol that provides a way to manage a collection of cancellable objects.

 ## Methods

 - `insert(_ id: String, cancelable: AnyCancellable?)` :  This method adds a cancellable object to the collection, associated with a specified identifier. If the provided cancelable parameter is nil, nothing happens. If the collection does not have an entry for the specified id, a new empty set is created.

 - `cancel(id: String)` :  This method cancels all the cancellable objects associated with a specified identifier, and removes the corresponding entry from the collection. If the collection does not have an entry for the specified id, nothing happens.

- `remove(_ id: String, cancelable: AnyCancellable?)` : This method removes a specific cancellable object from the collection associated with a specified identifier. If the provided cancelable parameter is nil, nothing happens. If the collection does not have an entry for the specified id, or if the specified cancelable object is not associated with the identifier, nothing happens.

 ## Properties

 - `storage: [String: Set<AnyCancellable>]`: This property is a dictionary that stores the cancellable objects associated with each identifier. Each entry in the dictionary consists of a key-value pair, where the key is a string representing the identifier, and the value is a set of AnyCancellable objects.

 - `_storage: [String: Set<AnyCancellable>]`: This is a private property that is used to implement the storage property.

 - `lock: NSRecursiveLock`: This is a private property that is used to synchronize access to the _storage property. It is an instance of NSRecursiveLock, which is a thread synchronization object that allows the same thread to acquire the lock multiple times without deadlocking.
 
 */
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
