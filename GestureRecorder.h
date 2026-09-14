// GestureRecorder.h
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GestureRecorder : NSObject
+ (instancetype)sharedInstance;
- (void)show;
- (void)hide;
@end
