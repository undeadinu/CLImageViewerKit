//
//  CLDownloadManager.m
//  CLImageViewerDemo
//
//  Created by sho yakushiji on 2014/04/04.
//  Copyright (c) 2014年 CALACULU. All rights reserved.
//

#import "CLDownloadManager.h"

#import "NSString+MD5Hash.h"

typedef void (^CLDownloadCompletionBlock)(NSData *data, NSURL *url, NSError *error);

@implementation CLDownloadManager
{
    NSMutableDictionary *_completionBlocks;
}

#pragma mark singleton pattern

static id _sharedInstance = nil;

+ (id)manager
{
    static dispatch_once_t  onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (_sharedInstance == nil) {
            _sharedInstance = [super allocWithZone:zone];
            return _sharedInstance;
        }
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)init
{
    self = [super init];
    if(self){
        _downloadURLs = [NSMutableArray array];
        _completionBlocks = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark- Class methods

+ (void)downloadFromURL:(NSURL*)url completion:(void(^)(NSData *data, NSURL *url, NSError *error))completionBlock
{
    [self.manager downloadFromURL:url completion:completionBlock];
}

+ (NSOperationQueue*)downloadQueue
{
    static NSOperationQueue *_sharedQueue = nil;
    
    if(_sharedQueue==nil){
        _sharedQueue = [NSOperationQueue new];
        [_sharedQueue setMaxConcurrentOperationCount:3];
    }
    
    return _sharedQueue;
}

+ (void)dataWithContentsOfURL:(NSURL *)url completionBlock:(void (^)(NSURL *url, NSData *data, NSError *error))completion
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:5.0];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[self downloadQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if(completion){
                                   completion(url, data, connectionError);
                               }
                           }
     ];
}

#pragma mark- Instance methods

- (void)downloadFromURL:(NSURL*)url completion:(void(^)(NSData *data, NSURL *url, NSError *error))completionBlock
{
    if(url.absoluteString.length>0){
        id urlHash = url.absoluteString.MD5Hash;
        NSMutableArray *blocks = _completionBlocks[urlHash];
        
        if(blocks==nil){
            blocks = @[[completionBlock copy]].mutableCopy;
            _completionBlocks[urlHash] = blocks;
            
            [self.class dataWithContentsOfURL:url completionBlock:^(NSURL *url, NSData *data, NSError *error) {
                [self didFinishedDownloadWithData:data url:url error:error];
            }];
        }
        else{
            @synchronized(blocks){
                [blocks addObject:[completionBlock copy]];
            }
        }
    }
    else{
        completionBlock(nil, url, [NSError errorWithDomain:@"jp.calaculu.CLDowonloadManagerErrorDomain" code:0 userInfo:@{NSLocalizedDescriptionKey:@"[CLDowonloadManager]: URL must not be nill."}]);
    }
}

- (void)didFinishedDownloadWithData:(NSData*)data url:(NSURL*)url error:(NSError*)error
{
    id urlHash = url.absoluteString.MD5Hash;
    NSMutableArray *blocks = _completionBlocks[urlHash];
    
    @synchronized(blocks){
        for(CLDownloadCompletionBlock block in blocks){
            block(data, url, error);
        }
    }
    [_completionBlocks removeObjectForKey:urlHash];
}

@end
