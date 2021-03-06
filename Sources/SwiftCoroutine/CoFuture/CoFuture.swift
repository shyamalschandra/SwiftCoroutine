//
//  CoFuture.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 30.12.2019.
//  Copyright © 2019 Alex Belozierov. All rights reserved.
//

import Foundation

open class CoFuture<Output> {
    
    let mutex: NSLock
    @RefBox var resultStorage: OutputResult?
    @ArcRefBox var subscriptions: [AnyHashable: OutputHandler]?
    
    init(mutex: NSLock = .init(), resultStorage: RefBox<OutputResult?> = .init(),
         subscriptions: ArcRefBox<[AnyHashable: OutputHandler]> = .init(value: [:])) {
        self.mutex = mutex
        _resultStorage = resultStorage
        _subscriptions = subscriptions
    }
    
    @inlinable open func cancel() {
        complete(with: .failure(CoFutureError.cancelled))
    }
    
    @inlinable open func cancelUpstream() {
        cancel()
    }
    
}

extension CoFuture {
    
    public var result: OutputResult? {
        mutex.lock()
        defer { mutex.unlock() }
        return resultStorage
    }
    
    @usableFromInline func complete(with result: OutputResult) {
        mutex.lock()
        guard resultStorage == nil
            else { return mutex.unlock() }
        resultStorage = result
        let handlers = subscriptions
        subscriptions?.removeAll()
        mutex.unlock()
        handlers?.values.forEach { $0(result) }
    }
    
    func newResultStorage(with value: OutputResult?) {
        _resultStorage = .init(wrappedValue: value)
    }
    
}

extension CoFuture {
    
    public convenience init(result: OutputResult) {
        self.init()
        resultStorage = result
    }
    
    @inlinable public convenience init(output: Output) {
        self.init(result: .success(output))
    }
    
    @inlinable public convenience init(error: Error) {
        self.init(result: .failure(error))
    }
    
}

extension CoFuture: CoPublisher {
    
    public typealias Output = Output
    
    public func subscribe(with identifier: AnyHashable, handler: @escaping OutputHandler) {
        mutex.lock()
        if let result = resultStorage {
            mutex.unlock()
            return handler(result)
        }
        subscriptions?[identifier] = handler
        mutex.unlock()
    }
    
    @discardableResult
    public func unsubscribe(_ identifier: AnyHashable) -> OutputHandler? {
        mutex.lock()
        defer { mutex.unlock() }
        return subscriptions?.removeValue(forKey: identifier)
    }
    
}

extension CoFuture: CoCancellable {
    
    @inlinable public var isCancelled: Bool {
        if case .failure(let error as CoFutureError) = result {
            return error == .cancelled
        }
        return false
    }
    
}

extension CoFuture: Hashable {
    
    @inlinable public static func == (lhs: CoFuture, rhs: CoFuture) -> Bool {
        lhs === rhs
    }
    
    @inlinable public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
    
}


