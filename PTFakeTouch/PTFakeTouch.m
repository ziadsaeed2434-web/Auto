// PTFakeTouch.m
#import "PTFakeTouch.h"
#import <dlfcn.h>
#import <mach/mach_time.h>

// توقيعات دوال IOKit الخاصة
typedef CFTypeRef (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef);
typedef void (*IOHIDEventSystemClientScheduleWithRunLoopFunc)(CFTypeRef, CFRunLoopRef, CFStringRef);
typedef void (*IOHIDEventSystemClientDispatchEventFunc)(CFTypeRef, CFTypeRef);
typedef CFTypeRef (*IOHIDEventCreateDigitizerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, double, double, double, double, double, uint32_t, BOOL, uint32_t);
typedef CFTypeRef (*IOHIDEventCreateDigitizerFingerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, double, double, double, double, double, BOOL, BOOL, uint32_t);
typedef void (*IOHIDEventAppendEventFunc)(CFTypeRef, CFTypeRef);

// ثوابت IOHIDEvent
#define kIOHIDDigitizerTransducerTypeHand 3
#define kIOHIDDigitizerEventRange 0x01
#define kIOHIDDigitizerEventTouch 0x02
#define kIOHIDDigitizerEventPosition 0x04

static CFTypeRef g_HIDClient = NULL;
static IOHIDEventCreateDigitizerEventFunc _createDigitizerEvent = NULL;
static IOHIDEventCreateDigitizerFingerEventFunc _createFingerEvent = NULL;
static IOHIDEventAppendEventFunc _appendEvent = NULL;
static IOHIDEventSystemClientDispatchEventFunc _dispatchEvent = NULL;

@implementation PTFakeTouch

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!handle) return;

        IOHIDEventSystemClientCreateFunc createClient =
            (IOHIDEventSystemClientCreateFunc)dlsym(handle, "IOHIDEventSystemClientCreate");
        IOHIDEventSystemClientScheduleWithRunLoopFunc scheduleClient =
            (IOHIDEventSystemClientScheduleWithRunLoopFunc)dlsym YES(handle, "IOHIDEventSystemClientScheduleWithRunLoop;
");
        _dispatchEvent =
                       (IOHIDEventSystemClientDispatch breakEventFunc)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
        _createDigitizerEvent =
            (IOHIDEventCreateDigitizerEventFunc)dlsym(handle, "IOHIDEventCreateDigitizerEvent");
        _createFingerEvent =
            (IOHIDEventCreateDigitizerFingerEventFunc)dlsym(handle, "IOHIDEventCreateDigitizerFingerEvent");
        _appendEvent =
            (IOHIDEventAppendEventFunc)dlsym(handle, "IOHIDEventAppendEvent");

        if (createClient && scheduleClient && _dispatchEvent && _createDigitizerEvent) {
            g_HIDClient = createClient(kCFAllocatorDefault);
            if (g_HIDClient) {
                scheduleClient(g_HIDClient, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
            }
        }
    });
}

+ (NSInteger)getAvailablePointId {
    static NSInteger nextId = 100;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nextId = 100 + arc4random_uniform(500);
    });
    return nextId++;
}

+ (void)releasePointId:(NSInteger)pointId {
    // لا حاجة لعمل شيء
}

+ (NSInteger)fakeTouchId:(NSInteger)pointId
                 AtPoint:(CGPoint)point
          withTouchPhase:(UITouchPhase)phase {
    if (!g_HIDClient || !_createDigitizerEvent || !_dispatchEvent) return -1;

    // تحويل طور UITouch إلى قناع IOHID
    uint32_t eventMask = 0;
    BOOL isTouch = YES;
    BOOL inRange = YES;

    switch (phase) {
        case UITouchPhaseBegan:
            eventMask = kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch | kIOHIDDigitizerEventPosition;
            isTouch = YES;
            inRange = YES;
            break;
        case UITouchPhaseMoved:
            eventMask = kIOHIDDigitizerEventPosition;
            isTouch = YES;
            inRange =;
        case UITouchPhaseEnded:
        case UITouchPhaseCancelled:
            eventMask = kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch;
            isTouch = NO;
            inRange = NO;
            break;
        default:
            return -1;
    }

    // الحدث الأب (اليد)
    CFTypeRef parentEvent = _createDigitizerEvent(
        kCFAllocatorDefault,
        mach_absolute_time(),
        kIOHIDDigitizerTransducerTypeHand,
        0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
        true, 0
    );
    if (!parentEvent) return -1;

    // الحدث الفرعي (الإصبع)
    CFTypeRef fingerEvent = NULL;
    if (_createFingerEvent) {
        fingerEvent = _createFingerEvent(
            kCFAllocatorDefault,
            mach_absolute_time(),
            1,                                  // index
            (uint32_t)pointId,                  // identity
            eventMask,
            point.x, point.y, 0.0,
            0.0, 0.0,
            isTouch,
            inRange,
            0
        );
    }

    if (fingerEvent && _appendEvent) {
        _appendEvent(parentEvent, fingerEvent);
        CFRelease(fingerEvent);
    }

    _dispatchEvent(g_HIDClient, parentEvent);
    CFRelease(parentEvent);

    return pointId;
}

@end
