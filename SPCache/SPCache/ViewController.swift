//
//  ViewController.swift
//  SPCache
//
//  Created by SuXinDe on 2018/7/26.
//  Copyright © 2018年 su xinde. All rights reserved.
//

import UIKit

class CacheObject : NSObject {
    deinit {
        NSLog("dealloc: %@", NSStringFromClass(CacheObject.self));
    }
}

class DiscardableContentCacheObject : CacheObject, NSDiscardableContent {
    var didDiscardContentIfPossible: Bool?
    public func beginContentAccess() -> Bool { return true }
    public func endContentAccess() {}
    public func discardContentIfPossible() { didDiscardContentIfPossible = true }
    public func isContentDiscarded() -> Bool { return false }
}

@objc class CacheDelegateImpl : NSObject, SPCacheDelegate {
    func cache(_ cache: SPCache, willEvictObject obj: Any) {
        NSLog("Cache: \(cache) will evict object: \(obj)")
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        testCases()
    }

    func testCases() {
        let delegate = CacheDelegateImpl()
        
        let cache = SPCache()
        cache.delegate = delegate
        cache.name = "TestCache"
        
        let cacheObject = CacheObject()
        cache.setObject(cacheObject, forKey: "key" as NSObjectProtocol)
        assert(cache.object(forKey: "key" as NSObjectProtocol) as? CacheObject == cacheObject,
               "Should be the same object.")
        
        cache.removeAllObjects()
        assert(cache.object(forKey: "key" as NSObjectProtocol) == nil,
               "Object should not be in the cache anymore")
        
        let discardableContentObject = DiscardableContentCacheObject()
        cache.setObject(discardableContentObject, forKey: "key" as NSObjectProtocol)
        cache.removeAllObjects()
        assert(discardableContentObject.didDiscardContentIfPossible == true,
               "Content should be discarded if possible.")
        assert(cache.object(forKey: "key" as NSObjectProtocol) == nil,
               "Object should not be in the cache anymore")
        
    }

}

