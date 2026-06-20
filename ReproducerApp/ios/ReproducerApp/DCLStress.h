#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reproduces the data race in React Native's REAL linked RCTImageLoader:
///   - imageURLLoaderForURL:    -> _loaders  (broken double-checked locking)
///   - imageDataDecoderForData: -> _decoders (no lock at all)
/// Builds with Thread Sanitizer enabled. Call +run as early as possible.
@interface DCLStress : NSObject
+ (void)run;
@end

NS_ASSUME_NONNULL_END
