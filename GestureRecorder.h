#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GestureRecorder : NSObject

+ (instancetype)sharedInstance;
- (void)show;
- (void)hide;
- (void)flashIndicatorAtPoint:(CGPoint)point;

@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) NSMutableArray *recordedTouches;

@end
