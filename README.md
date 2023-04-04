# CombineProcessor

[![Language](http://img.shields.io/badge/language-swift-orange.svg?style=flat)](https://developer.apple.com/swift)
[![SPM compatible](https://img.shields.io/badge/Swift_Package_Manager-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)

## Introduce

`CombineProcessor` is a lightweight Swift library that was developed with reference to both  [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) and  [Redux](https://cn.redux.js.org/).</br>
It particularly shows many shades of `TCA`, so if you are already familiar with `TCA`, then `CombineProcessor` should not be a problem for you.

`CombineProcessor` provides an extremely lightweight state management machine with a limited API, which is particularly useful for quickly developing any app with complex and repetitive workflows. Unlike `TCA`, `CombineProcessor` is just a simple state machine framework that does not provide any UI layer API, but rather focuses only on the input and output of an independent layer (such as the View Model, Manager, and Controller).

 - Easy: Simple and limited API
 - Testable: Supporting unit tests without side effects.

## Key Points

- `State` : The current state of your application, stored as a struct. This should be a pure value type, without any side effects.
- `Action`: An event that occurs in your application that can cause a state change. Actions are simple structs that can optionally carry associated data.
- `PrivateAction`: An action that can only be dispatched internally by the processor. This is useful for actions that should not be triggered by external events.
- `Processor`: A class that manages your application state and handles actions. The processor is responsible for transforming the current state into a new state based on the action received.

## Usage

 1. Define your `State`, `Action`, and `PrivateAction` structs and also `Environment`
 2. Assemble `State`, `Action`, `PrivateAction`, and `Environment` using `AnyProcessorReducer`.
 3. Injection in `Processor`.
 
 ```=swift
 
  let reducer: AnyProcessorReducer<States, Action, PrivateAction, Environment> {
        return AnyProcessorReducer(mutated: { action in
            return convertToPrivateAction(action)
        }, reduce: { states, privateAction, environment -> ProcessorPublisher<PrivateAction, Never>? in 
    
          ...
        }
 
  let processor = Processor(initialState: States(),
                  reducer: reducer,
                  environment: Environment())
 
 // Observe
 
 processor.publisher
           .sink(receiveValue: { ... })
          .store(in: &bag)
          
// Send Event

 processor.send(Action.event)

// Test 

 func testProcessor() {
     await processor.test
         .privateAction(sendAction: Action.event, equal: PrivateAction.event)
  
     await processor.test
          .state(send: Action.event, equal: State())
  }
  
}
 
 ```
 
*[Please refer to the example for detail](https://github.com/woodycatliu/SignINProcessor)*


