// PTFakeTouch.h
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PTFakeTouch : NSObject
+ (NSInteger)fakeTouchId:(NSInteger)pointId atPoint:(CGPoint)point withPhase:(UITouchPhase)phase;
+ (NSInteger)getAvailablePointId;
+ (void)releasePointId:(NSInteger)pointId;
@end
