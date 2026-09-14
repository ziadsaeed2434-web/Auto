#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GestureRecorder : NSObject

+ (instancetype)sharedInstance;
- (void)showInWindowScene:(UIWindowScene *)scene;
- (void)hide;
- (void)flashIndicatorAtPoint:(CGPoint)point;

@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) NSMutableArray *recordedTouches;

@end
