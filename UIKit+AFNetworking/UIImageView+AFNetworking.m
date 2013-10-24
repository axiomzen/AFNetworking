// UIImageView+AFNetworking.m
//
// Copyright (c) 2013 AFNetworking (http://afnetworking.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "UIImageView+AFNetworking.h"

#import <objc/runtime.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#import "AFHTTPRequestOperation.h"

@interface AFImageCache : NSCache
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request;
- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request;
    @end

#pragma mark -

static char kAFImageRequestOperationKey;
static char kAFResponseSerializerKey;

@interface UIImageView (_AFNetworking)
    @property (readwrite, nonatomic, strong, setter = af_setImageRequestOperation:) AFHTTPRequestOperation *af_imageRequestOperation;
    @end

@implementation UIImageView (_AFNetworking)
    
+ (NSOperationQueue *)af_sharedImageRequestOperationQueue {
    static NSOperationQueue *_af_sharedImageRequestOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _af_sharedImageRequestOperationQueue = [[NSOperationQueue alloc] init];
        _af_sharedImageRequestOperationQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
    });
    
    return _af_sharedImageRequestOperationQueue;
}
    
+ (AFImageCache *)af_sharedImageCache {
    static AFImageCache *_af_imageCache = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _af_imageCache = [[AFImageCache alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * __unused notification) {
            [_af_imageCache removeAllObjects];
        }];
    });
    
    return _af_imageCache;
}
    
- (AFHTTPRequestOperation *)af_imageRequestOperation {
    return (AFHTTPRequestOperation *)objc_getAssociatedObject(self, &kAFImageRequestOperationKey);
}
    
- (void)af_setImageRequestOperation:(AFHTTPRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, &kAFImageRequestOperationKey, imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
    
    @end

#pragma mark -

@implementation UIImageView (AFNetworking)
    @dynamic imageResponseSerializer;
    
- (id <AFURLResponseSerialization>)imageResponseSerializer {
    static id <AFURLResponseSerialization> _af_defaultImageResponseSerializer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _af_defaultImageResponseSerializer = [AFImageResponseSerializer serializer];
    });
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    return objc_getAssociatedObject(self, &kAFResponseSerializerKey) ?: _af_defaultImageResponseSerializer;
#pragma clang diagnostic pop
}
    
- (void)setImageResponseSerializer:(id <AFURLResponseSerialization>)serializer {
    objc_setAssociatedObject(self, &kAFResponseSerializerKey, serializer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
    
#pragma mark -
    
-(UIActivityIndicatorView*)defaultActivityView {
    UIActivityIndicatorView * av = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    av.backgroundColor = [UIColor clearColor];
    av.hidesWhenStopped = YES;
    CGSize size = self.frame.size;
    [av setCenter:CGPointMake(size.width/2, size.height/2)];
    return av;
}
    
- (void)setImageWithURL:(NSURL *)url {
    [self setImageWithURL:url placeholderImage:nil];
}
    
// if activity, uses a default activity view (transparent background, grey spinner)
// otherwise, same as calling setimagewithurl
-(void)setImageWithURL:(NSURL *)url useActivityIndicator:(BOOL)activity {
    if(activity) {
        // use default activity indicator, no fallback image
        [self setImageWithURL:url fallbackImage:nil useActivityIndicator:YES];
    } else {
        [self setImageWithURL:url];
    }
}
    
// if activity = NO, then this is same as [setimagewithurl placeholderImage]
-(void)setImageWithURL:(NSURL *)url fallbackImage:(UIImage*)fallbackImage useActivityIndicator:(BOOL)useActivityIndicator {
    if(useActivityIndicator) {
        [self setImageWithURL:url fallbackImage:fallbackImage activityIndicatorView:[self defaultActivityView]];
    } else {
        [self setImageWithURL:ulr placeholderImage:fallbackImage];
    }
}
    
    // uses the activity indicator that you send in as the placeholderview, then fallback image if it fails to download
-(void)setImageWithURL:(NSURL *)url fallbackImage:(UIImage*)fallbackImage activityIndicatorView:(UIActivityIndicatorView *)activityIndicatorView {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    [self setImageWithURLRequest:request fallbackImage:fallbackImage activityIndicatorView:activityIndicatorView success:nil failure:nil];
}
    
#define AFN_FADEOUT 0.2f
#define AFN_FADEIN 0.3f
    // do some nice animations
    // todo: decide whether to fade out or just stop and fade in
+(void)animateSetImage:(UIImageView*)imageView newImage:(UIImage*)image activityIndicatorView:(UIActivityIndicatorView*)activityIndicatorView {
    [UIView animateWithDuration:AFN_FADEOUT animations:^{
        activityIndicatorView.alpha = 0.f;
    } completion:^(BOOL finished) {
        [activityIndicatorView stopAnimating];
        // fade in new image
        imageView.alpha = 0.f;
        imageView.image = image;
        [UIView animateWithDuration:AFN_FADEIN animations:^{
            imageView.alpha = 1.f;
        } completion:^(BOOL finished) {
            
        }];
    }];
}
    // uses the activity indicator that you send in as the placeholderview, then fallback image if it fails to download
    // allows you to intercept the succes and failure blocks
- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
                 fallbackImage:(UIImage *)fallbackImage
         activityIndicatorView:(UIActivityIndicatorView *)activityIndicatorView
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure {
    [self cancelImageRequestOperation];
    //todo: set center here always or does the calling view set the center?
    [self addSubview:activityIndicatorView];
    [activityIndicatorView startAnimating];
    
    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        if (success) {
            success(nil, nil, cachedImage);
        } else {
            
            [UIImageView animateSetImage:self newImage:cachedImage activityIndicatorView:activityIndicatorView];
        }
        
        self.af_imageRequestOperation = nil;
    } else {
        // dont set this right away, set if we fail
        //self.image = placeholderImage;
        __weak __typeof(self)weakSelf = self;
        self.af_imageRequestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:urlRequest];
        self.af_imageRequestOperation.responseSerializer = self.imageResponseSerializer;
        [self.af_imageRequestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            if ([[urlRequest URL] isEqual:[operation.request URL]]) {
                if (success) {
                    success(urlRequest, operation.response, responseObject);
                } else if (responseObject) {
                    //do some nice animations
                    // todo: decide whether to fade out or just stop and fade in
                    [UIImageView animateSetImage:strongSelf newImage:responseObject activityIndicatorView:activityIndicatorView];
                }
            } else {
                // todo: when is this the case?
                [UIImageView animateSetImage:strongSelf newImage:fallbackImage activityIndicatorView:activityIndicatorView];
            }
            
            [[[strongSelf class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([[urlRequest URL] isEqual:[operation.request URL]]) {
                if (failure) {
                    failure(urlRequest, operation.response, error);
                } else {
                    [UIImageView animateSetImage:strongSelf newImage:fallbackImage activityIndicatorView:activityIndicatorView];
                }
            }
        }];
        
        [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_imageRequestOperation];
    }
}
    
- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
    {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
        
        [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
    }
    
- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
    {
        [self cancelImageRequestOperation];
        
        UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
        if (cachedImage) {
            if (success) {
                success(nil, nil, cachedImage);
            } else {
                self.image = cachedImage;
            }
            
            self.af_imageRequestOperation = nil;
        } else {
            self.image = placeholderImage;
            
            __weak __typeof(self)weakSelf = self;
            self.af_imageRequestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:urlRequest];
            self.af_imageRequestOperation.responseSerializer = self.imageResponseSerializer;
            [self.af_imageRequestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if ([[urlRequest URL] isEqual:[operation.request URL]]) {
                    if (success) {
                        success(urlRequest, operation.response, responseObject);
                    } else if (responseObject) {
                        strongSelf.image = responseObject;
                    }
                } else {
                    
                }
                
                [[[strongSelf class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if ([[urlRequest URL] isEqual:[operation.request URL]]) {
                    if (failure) {
                        failure(urlRequest, operation.response, error);
                    }
                }
            }];
            
            [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_imageRequestOperation];
        }
    }
    
- (void)cancelImageRequestOperation {
    [self.af_imageRequestOperation cancel];
    self.af_imageRequestOperation = nil;
}
    
    @end

#pragma mark -

static inline NSString * AFImageCacheKeyFromURLRequest(NSURLRequest *request) {
    return [[request URL] absoluteString];
}

@implementation AFImageCache
    
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request {
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
        return nil;
        default:
        break;
    }
    
	return [self objectForKey:AFImageCacheKeyFromURLRequest(request)];
}
    
- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
    {
        if (image && request) {
            [self setObject:image forKey:AFImageCacheKeyFromURLRequest(request)];
        }
    }
    
    @end

#endif
