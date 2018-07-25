//
//  SPCache.h
//  SPCache
//
//  Created by SuXinDe on 2018/7/26.
//  Copyright © 2018年 su xinde. All rights reserved.
//


// Reference: https://medium.com/@maicki/behind-the-curtains-of-nscache-1dce85603dc

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@protocol SPCacheDelegate;

@interface SPCache : NSObject {
@private
    __weak id _delegate;
    // void *_private[5]; // NSCache implementation of some of this variables below
    
    BOOL _delegateCacheWillEvictObject;
    
    BOOL _didDealloc;
}

@property (copy) NSString *name;
@property NSUInteger totalCostLimit;    // limits are imprecise/not strict
@property NSUInteger countLimit;    // limits are imprecise/not strict
@property BOOL evictsObjectsWithDiscardedContent;

@property (nullable, weak) id<SPCacheDelegate> delegate;

- (nullable id<NSObject>)objectForKey:(id<NSObject>)key;

- (void)setObject:(id<NSObject>)obj
           forKey:(id<NSObject>)key; // 0 cost

- (void)setObject:(id<NSObject>)obj
           forKey:(id<NSObject>)key
             cost:(NSUInteger)cost;

- (void)removeObjectForKey:(id<NSObject>)key;

- (void)removeAllObjects;

@end

@protocol SPCacheDelegate <NSObject>
@optional
- (void)cache:(SPCache *)cache willEvictObject:(id)obj;
@end

NS_ASSUME_NONNULL_END
