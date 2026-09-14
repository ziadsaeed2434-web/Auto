// Tweak.xm
#import <UIKit/UIKit.h>
#import "GestureRecorder.h"

// تشغيل المسجل عند بدء التطبيق
%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    // تأخير بسيط للتأكد من جاهزية النافذة الرئيسية
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[GestureRecorder sharedInstance] show];
    });
}

%end

// إضافة زر للتبديل (اختياري) عند النقر المطول على زر الطاقة أو أي مكان
%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[GestureRecorder sharedInstance] show];
    });
}

%end
