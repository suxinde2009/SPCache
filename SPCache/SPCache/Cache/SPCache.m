//
//  SPCache.m
//  SPCache
//
//  Created by SuXinDe on 2018/7/26.
//  Copyright © 2018年 su xinde. All rights reserved.
//

#import "SPCache.h"
#import <cache.h>
#import <UIKit/UIKit.h>

// Private libcache API
int cache_set_name(cache_t *cache, const char *name);
const char *cache_get_name(cache_t *cache);

void cache_set_minimum_values_hint(cache_t *cache, uint32_t minimum_value);
int cache_get_minimum_values_hint(cache_t *cache);

void cache_set_cost_hint(cache_t *cache, uint32_t cost);
int cache_get_cost_hint(cache_t *cache);

void cache_set_count_hint(cache_t *cache, uint32_t cost);
int cache_get_count_hint(cache_t *cache);

// TODO: What are parameters 1 and 3?
void cache_remove_with_block(cache_t *cache, int (^block)(void *a, void *data, void *c));

#pragma mark - _SPMoribundCache

static void _SPMoribundCache_invalidAccess() {
    NSLog(@"Attempting to interact with SPCache instance that is being deallocated.");
}


@interface _SPMoribundCache : SPCache
@end

@implementation _SPMoribundCache

- (NSUInteger)countLimit {
    _SPMoribundCache_invalidAccess();
    return 0;
}

- (id<SPCacheDelegate>)delegate {
    _SPMoribundCache_invalidAccess();
    return nil;
}

- (BOOL)evictsObjectsWithDiscardedContent {
    _SPMoribundCache_invalidAccess();
    return false;
}

- (NSString *)name {
    _SPMoribundCache_invalidAccess();
    return @"";
}

- (id<NSObject>)objectForKey:(id<NSObject>)key {
    _SPMoribundCache_invalidAccess();
    return nil;
}

- (void)removeAllObjects {
    _SPMoribundCache_invalidAccess();
}

- (void)removeObjectForKey:(id<NSObject>)key {
    _SPMoribundCache_invalidAccess();
}

- (void)setCountLimit:(NSUInteger)countLimit {
    _SPMoribundCache_invalidAccess();
}

- (void)setDelegate:(id<SPCacheDelegate>)delegate {
    _SPMoribundCache_invalidAccess();
}

- (void)setEvictsObjectsWithDiscardedContent:(BOOL)arg1 {
    _SPMoribundCache_invalidAccess();
}

- (void)setName:(NSString *)name {
    _SPMoribundCache_invalidAccess();
}

- (void)setObject:(id<NSObject>)obj
           forKey:(id<NSObject>)key {
    _SPMoribundCache_invalidAccess();
}

- (void)setObject:(id<NSObject>)object
           forKey:(id<NSObject>)key
             cost:(NSUInteger)cost {
    _SPMoribundCache_invalidAccess();
}

- (void)setTotalCostLimit:(NSUInteger)limit {
    _SPMoribundCache_invalidAccess();
}

- (NSUInteger)totalCostLimit {
    _SPMoribundCache_invalidAccess();
    return 0;
}

@end


@interface SPCache () {
@private
    cache_t *_cache;
    BOOL _evictsObjectsWhenApplicationEntersBackground;
}
@end

@implementation SPCache

static uintptr_t __SPCacheKeyHash(void *key, void *data) {
    return CFHash(key);
}

static bool __SPCacheKeyEqual(void *key1, void *key2, void *user_data) {
    return CFEqual(key1, key2);
}

static void __SPCacheKeyRetain(void *key_in, void **key_out, void *user_data) {
    *key_out = (void *)CFRetain(key_in);
}

static void __SPCacheKeyRelease(void *key, void *user_data) {
    CFRelease(key);
}

static void __SPCacheValueRetain(void *value_in, void *user_data) {
    CFRetain(value_in);
}

static void __SPCacheValueRelease(void *value, void *user_data) {
    SPCache *cache = (__bridge id)user_data;
    id<SPCacheDelegate> delegate = cache.delegate;
    id object = (__bridge id)value;
    
    // If the cache is currently beeing deallocated we will use shared cache that logs errors if certain methods are called
    if (cache->_didDealloc) {
        static _SPMoribundCache *moribundCache = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            moribundCache = [[_SPMoribundCache alloc] init];
        });
        
        cache = moribundCache;
    }
    
    if (delegate != nil && cache->_delegateCacheWillEvictObject) {
        [delegate cache:cache willEvictObject:object];
    }
    
    // Don't call accessor evictsObjectsWithDiscardedContent explicitly here as it would log a message
    if (cache->_evictsObjectsWithDiscardedContent && [object conformsToProtocol:@protocol(NSDiscardableContent)]) {
        [object discardContentIfPossible];
    }
    
    CFRelease(value);
}

- (instancetype)init {
    if (self = [super init]) {
        cache_attributes_t attributes;
        attributes.version = CACHE_ATTRIBUTES_VERSION_2;
        
        attributes.key_hash_cb = &__SPCacheKeyHash;
        attributes.key_is_equal_cb = &__SPCacheKeyEqual;
        
        attributes.key_retain_cb = &__SPCacheKeyRetain;
        attributes.key_release_cb = &__SPCacheKeyRelease;
        
        attributes.value_retain_cb = &__SPCacheValueRetain;
        attributes.value_release_cb = &__SPCacheValueRelease;
        
        // These calues are set to NULL in NSCache. Could also use default callbacks from cache_callbacks.h though
        // That said it's important to either register callbacks or set it explicitly to NULL, otherwise it will crash
        attributes.value_make_nonpurgeable_cb = NULL;
        attributes.value_make_purgeable_cb = NULL;
        
        attributes.user_data = (__bridge void *)self;
        
        int result = cache_create("com.su.SPCache", &attributes, &_cache);
        if (result) {
            return nil;
        }
        _didDealloc = NO;
        _evictsObjectsWithDiscardedContent = YES;
        
#if TARGET_OS_IOS
        // This is explicitly only called only on iOS
        [self setEvictsObjectsWhenApplicationEntersBackground:YES];
#endif
    }
    return self;
}

- (void)dealloc {
#if TARGET_OS_IOS
    if (_evictsObjectsWhenApplicationEntersBackground) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
    }
#endif
    _didDealloc = YES;
    
    // Destroy cache
    if (_cache != nil) {
        cache_remove_all(_cache);
        while(cache_destroy(_cache) == EAGAIN ) {
            // Yes there is really a sleep in there
            sleep(1);
        }
    }
}

- (void)setEvictsObjectsWhenApplicationEntersBackground:(BOOL)evictsObjectsWhenApplicationEntersBackground {
#if TARGET_OS_IOS
    if (evictsObjectsWhenApplicationEntersBackground != _evictsObjectsWhenApplicationEntersBackground) {
        _evictsObjectsWhenApplicationEntersBackground = evictsObjectsWhenApplicationEntersBackground;
        if (evictsObjectsWhenApplicationEntersBackground) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(__SPCacheApplicationDidEnterBackgroundCallback:)
                                                         name:UIApplicationDidEnterBackgroundNotification
                                                       object:nil];
        } else {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:UIApplicationDidEnterBackgroundNotification
                                                          object:nil];
        }
    }
#endif
}

- (BOOL)evictsObjectsWhenApplicationEntersBackground {
    return _evictsObjectsWhenApplicationEntersBackground;
}

// This uses the block based NSNotificationCenter API in NSCache.
- (void)__SPCacheApplicationDidEnterBackgroundCallback:(NSNotification *)notification {
    cache_remove_with_block(_cache, ^int(void *a, void *data, void *c) {
        __unused __strong id object = (__bridge id)data;
        // TODO: Some specific logic to remove the object
        
        // Return 0 or 1 if the data should be removed.
        return 0;
    });
}

- (void)setDelegate:(id<SPCacheDelegate>)delegate {
    _delegate = delegate;
    _delegateCacheWillEvictObject = NO;
    if ([delegate conformsToProtocol:@protocol(SPCacheDelegate)]) {
        _delegateCacheWillEvictObject = [delegate respondsToSelector:@selector(cache:willEvictObject:)];
    }
}

- (id<SPCacheDelegate>)delegate {
    return _delegate;
}

- (void)setName:(NSString *)name {
    const char *newName = [name UTF8String];
    cache_set_name(_cache, newName);
}

- (NSString *)name {
    const char *name = cache_get_name(_cache);
    return [NSString stringWithUTF8String:name];
}

- (void)setMinimumObjectCount:(int)minimumObjectCount {
    cache_set_minimum_values_hint(_cache, minimumObjectCount);
}

- (int)minimumObjectCount {
    return cache_get_minimum_values_hint(_cache);
}

- (void)setTotalCostLimit:(NSUInteger)limit {
    cache_set_cost_hint(_cache, (uint32_t)limit);
}

- (NSUInteger)totalCostLimit {
    return (NSUInteger)cache_get_cost_hint(_cache);
}

- (NSUInteger)countLimit {
    return cache_get_count_hint(_cache);
}

- (void)setCountLimit:(NSUInteger)countLimit {
    cache_set_count_hint(_cache, (uint32_t)countLimit);
}

- (void)setObject:(id<NSObject>)obj forKey:(id<NSObject>)key {
    [self setObject:obj forKey:key cost:0];
}

- (void)setObject:(id<NSObject>)object forKey:(id<NSObject>)key cost:(NSUInteger)cost {
    int result = cache_set_and_retain(_cache,
                                      (__bridge void *)key,
                                      (__bridge void *)object,
                                      cost);
    assert(result == 0);
    cache_release_value(_cache,
                        (__bridge void *)object);
}

- (id<NSObject>)objectForKey:(id<NSObject>)key {
    void *valueOut;
    cache_get_and_retain(_cache,
                         (__bridge void *)key,
                         &valueOut);
    __strong id object = (__bridge id)valueOut;
    
    // Handle evicts object with discarded content
    if (_evictsObjectsWithDiscardedContent) {
        if ([object conformsToProtocol:@protocol(NSDiscardableContent)]) {
            if ([object isContentDiscarded]) {
                cache_remove(_cache,
                             (__bridge void *)key);
            }
        }
    }
    cache_release_value(_cache, valueOut);
    return object;
}

- (void)removeObjectForKey:(id)key {
    cache_remove(_cache, (__bridge void *)key);
}

- (void)removeAllObjects {
    cache_remove_all(_cache);
}

@end
