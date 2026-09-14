#import <UIKit/UIKit.h>
#import "GestureRecorder.h"

static BOOL g_didShowPanel = NO;

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    // نعرض اللوحة مرة واحدة فقط، عند ظهور نافذة التطبيق الرئيسية
    if (!g_didShowPanel && self.windowScene != nil) {
        g_didShowPanel = YES;
        NSLog(@"[GestureRecorder] Window became key, showing panel. Scene: %@", self.windowScene);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[GestureRecorder sharedInstance] showInWindowScene:self.windowScene];
        });
    }
}

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

// تسجيل تشخيصي عند التحميل
%ctor {
    NSLog(@"[GestureRecorder] Tweak loaded successfully!");
}
