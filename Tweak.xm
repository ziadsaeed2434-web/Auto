#import <UIKit/UIKit.h>
#import "GestureRecorder.h"

// hook على UIWindow لالتقاط كل اللمسات داخل التطبيق
%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    GestureRecorder *rec = [GestureRecorder sharedInstance];
    if (rec.isRecording) {
        for (UITouch *touch in event.allTouches) {
            if (touch.phase == UITouchPhaseBegan) {
                CGPoint p = [touch locationInView:self];
                [rec.recordedTouches addObject:@{@"x": @(p.x), @"y": @(p.y)}];
                [rec flashIndicatorAtPoint:p];
            }
        }
    }
    %orig;
}

%end

// إظهار اللوحة عند اكتمال تشغيل التطبيق
%hook UIApplication

- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[GestureRecorder sharedInstance] show];
    });
}

%end
