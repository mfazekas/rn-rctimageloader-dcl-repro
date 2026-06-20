#import "DCLStress.h"
#import <React/RCTImageLoader.h>
#import <React/RCTImageURLLoader.h>
#import <React/RCTImageDataDecoder.h>
#import <UIKit/UIKit.h>

// imageURLLoaderForURL: / imageDataDecoderForData: are internal to RCTImageLoader
// but exist at runtime. Declaring them lets us drive the lazy-init path directly
// and concurrently, the same way #46115's reproducer hammered RCTImageLoader.
@interface RCTImageLoader (DCLStress)
- (id)imageURLLoaderForURL:(NSURL *)URL;
- (id)imageDataDecoderForData:(NSData *)data;
@end

#pragma mark - minimal real protocol conformers (returned by the providers)

@interface DCLDummyLoader : NSObject <RCTImageURLLoader>
@end
@implementation DCLDummyLoader
+ (NSString *)moduleName { return @"DCLDummyLoader"; }
- (BOOL)canLoadImageURL:(NSURL *)requestURL { return NO; }
- (float)loaderPriority { return 0; }
- (RCTImageLoaderCancellationBlock)loadImageForURL:(NSURL *)imageURL
                                              size:(CGSize)size
                                             scale:(CGFloat)scale
                                        resizeMode:(RCTResizeMode)resizeMode
                                   progressHandler:(RCTImageLoaderProgressBlock)progressHandler
                                partialLoadHandler:(RCTImageLoaderPartialLoadBlock)partialLoadHandler
                                 completionHandler:(RCTImageLoaderCompletionBlock)completionHandler { return nil; }
@end

@interface DCLDummyDecoder : NSObject <RCTImageDataDecoder>
@end
@implementation DCLDummyDecoder
+ (NSString *)moduleName { return @"DCLDummyDecoder"; }
- (BOOL)canDecodeImageData:(NSData *)imageData { return NO; }
- (float)decoderPriority { return 0; }
- (RCTImageLoaderCancellationBlock)decodeImageData:(NSData *)imageData
                                              size:(CGSize)size
                                             scale:(CGFloat)scale
                                        resizeMode:(RCTResizeMode)resizeMode
                                 completionHandler:(RCTImageLoaderCompletionBlock)completionHandler { return nil; }
@end

#pragma mark - stress

@implementation DCLStress

+ (void)run
{
  // Many fresh RCTImageLoader instances; each is hammered from 8 threads on its
  // FIRST use, while _loaders / _decoders are still nil (the only race window).
  const int kInstances = 60000;
  const int kThreads = 8;
  NSURL *url = [NSURL URLWithString:@"file:///stress.png"];
  NSData *data = [NSData dataWithBytes:"abcd" length:4];

  NSArray * (^loaders)(RCTModuleRegistry *) = ^NSArray *(RCTModuleRegistry *r) {
    return @[ [DCLDummyLoader new], [DCLDummyLoader new], [DCLDummyLoader new],
              [DCLDummyLoader new], [DCLDummyLoader new], [DCLDummyLoader new] ];
  };
  NSArray * (^decoders)(RCTModuleRegistry *) = ^NSArray *(RCTModuleRegistry *r) {
    return @[ [DCLDummyDecoder new], [DCLDummyDecoder new], [DCLDummyDecoder new],
              [DCLDummyDecoder new], [DCLDummyDecoder new], [DCLDummyDecoder new] ];
  };

  NSLog(@"[DCLStress] hammering REAL RCTImageLoader from %d threads x %d instances…", kThreads, kInstances);
  for (int i = 0; i < kInstances; i++) {
    RCTImageLoader *loader = [[RCTImageLoader alloc] initWithRedirectDelegate:nil
                                                             loadersProvider:loaders
                                                            decodersProvider:decoders];
    __unsafe_unretained RCTImageLoader *u = loader;
    dispatch_apply(kThreads, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t idx) {
      if (idx % 2 == 0) {
        (void)[u imageURLLoaderForURL:url];      // -> _loaders   (broken DCL)
      } else {
        (void)[u imageDataDecoderForData:data];  // -> _decoders  (no lock)
      }
    });
  }
  NSLog(@"[DCLStress] done — inspect the Thread Sanitizer report.");
}

@end
