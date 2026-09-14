#import "PTFakeTouch.h"
#import <dlfcn.h>
#import <mach/mach_time.h>

typedef CFTypeRef (*CreateClientFunc)(CFAllocatorRef);
typedef void (*ScheduleClientFunc)(CFTypeRef, CFRunLoopRef, CFStringRef);
typedef void (*DispatchEventFunc)(CFTypeRef, CFTypeRef);
typedef CFTypeRef (*CreateDigitizerFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, double, double, double, double, double, uint32_t, BOOL, uint32_t);
typedef CFTypeRef (*CreateFingerFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, double, double, double, double, double, BOOL, BOOL, uint32_t);
typedef void (*AppendEventFunc)(CFTypeRef, CFTypeRef);

static CFTypeRef g_Client = NULL;
static CreateDigitizerFunc fn_createDigitizer = NULL;
static CreateFingerFunc fn_createFinger = NULL;
static AppendEventFunc fn_append = NULL;
static DispatchEventFunc fn_dispatch = NULL;

#define kTransducerHand 3
#define kEventRange 0x01
#define kEventTouch 0x02
#define kEventPosition 0x04

@implementation PTFakeTouch

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (h == NULL) {
            return;
        }

        CreateClientFunc fn_create = (CreateClientFunc)dlsym(h, "IOHIDEventSystemClientCreate");
        ScheduleClientFunc fn_schedule = (ScheduleClientFunc)dlsym(h, "IOHIDEventSystemClientScheduleWithRunLoop");
        fn_dispatch = (DispatchEventFunc)dlsym(h, "IOHIDEventSystemClientDispatchEvent");
        fn_createDigitizer = (CreateDigitizerFunc)dlsym(h, "IOHIDEventCreateDigitizerEvent");
        fn_createFinger = (CreateFingerFunc)dlsym(h, "IOHIDEventCreateDigitizerFingerEvent");
        fn_append = (AppendEventFunc)dlsym(h, "IOHIDEventAppendEvent");

        if (fn_create == NULL || fn_dispatch == NULL || fn_createDigitizer == NULL) {
            return;
        }

        g_Client = fn_create(kCFAllocatorDefault);
        if (g_Client != NULL && fn_schedule != NULL) {
            fn_schedule(g_Client, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        }
    });
}

+ (NSInteger)getAvailablePointId {
    static NSInteger counter = 0;
    counter = counter + 1;
    if (counter > 900) {
        counter = 100;
    }
    return counter + 100;
}

+ (void)releasePointId:(NSInteger)pointId {
    // لا شيء
}

+ (NSInteger)fakeTouchId:(NSInteger)pointId
                 AtPoint:(CGPoint)point
          withTouchPhase:(UITouchPhase)phase {

    if (g_Client == NULL || fn_createDigitizer == NULL || fn_dispatch == NULL) {
        return -1;
    }

    uint32_t mask = 0;
    BOOL touchFlag = YES;
    BOOL rangeFlag = YES;

    if (phase == UITouchPhaseBegan) {
        mask = kEventRange | kEventTouch | kEventPosition;
        touchFlag = YES;
        rangeFlag = YES;
    } else if (phase == UITouchPhaseMoved) {
        mask = kEventPosition;
        touchFlag = YES;
        rangeFlag = YES;
    } else if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
        mask = kEventRange | kEventTouch;
        touchFlag = NO;
        rangeFlag = NO;
    } else {
        return -1;
    }

    CFTypeRef parent = fn_createDigitizer(
        kCFAllocatorDefault,
        mach_absolute_time(),
        kTransducerHand,
        0, 0, 0, 0,
        0.0, 0.0, 0.0, 0.0, 0.0,
        0,
        true,
        0
    );

    if (parent == NULL) {
        return -1;
    }

    if (fn_createFinger != NULL) {
        CFTypeRef finger = fn_createFinger(
            kCFAllocatorDefault,
            mach_absolute_time(),
            1,
            (uint32_t)pointId,
            mask,
            (double)point.x,
            (double)point.y,
            0.0,
            0.0,
            0.0,
            rangeFlag,
            touchFlag,
            0
        );

        if (finger != NULL) {
            if (fn_append != NULL) {
                fn_append(parent, finger);
            }
            CFRelease(finger);
        }
    }

    fn_dispatch(g_Client, parent);
    CFRelease(parent);

    return pointId;
}

@end
