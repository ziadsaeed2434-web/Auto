#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PTFakeTouch : NSObject

+ (NSInteger)fakeTouchId:(NSInteger)pointId
                 AtPoint:(CGPoint)point
          withTouchPhase:(UITouchPhase)phase;

+ (NSInteger)getAvailablePointId;
+ (void)releasePointId:(NSInteger)pointId;

@end
