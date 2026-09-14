// PTFakeTouch.m
#import "PTFakeTouch.h"
#import <dlfcn.h>

// أسماء الدوال الخاصة المطلوبة من IOKit
typedef void* (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef);
typedef void (*IOHIDEventSystemClientScheduleWithRunLoopFunc)(void*, CFRunLoopRef, CFStringRef);
typedef void (*IOHIDEventSystemClientDispatchEventFunc)(void*, void*);
typedef void* (*IOHIDEventCreateDigitizerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, bool);
typedef void (*IOHIDEventAppendEventFunc)(void*, void*);
typedef void (*IOHIDEventSetIntegerValueFunc)(void*, uint32_t, CFIndex);
typedef void (*IOHIDEventSetFloatValueFunc)(void*, uint32_t, double);

static void* g_HIDSystemClient = NULL;
static IOHIDEventSystemClientDispatchEventFunc g_dispatchEvent = NULL;
static IOHIDEventCreateDigitizerEventFunc g_createDigitizerEvent = NULL;
static IOHIDEventAppendEventFunc g_appendEvent = NULL;
static IOHIDEventSetIntegerValueFunc g_setIntegerValue = NULL;
static IOHIDEventSetFloatValueFunc g_setFloatValue = NULL;

@implementation PTFakeTouch

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setupIOKit];
    });
}

+ (void)setupIOKit {
    void* handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!handle) return;

    IOHIDEventSystemClientCreateFunc createClient = (IOHIDEventSystemClientCreateFunc)dlsym(handle, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientScheduleWithRunLoopFunc scheduleClient = (IOHIDEventSystemClientScheduleWithRunLoopFunc)dlsym(handle, "IOHIDEventSystemClientScheduleWithRunLoop");
    g_dispatchEvent = (IOHIDEventSystemClientDispatchEventFunc)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
    g_createDigitizerEvent = (IOHIDEventCreateDigitizerEventFunc)dlsym(handle, "IOHIDEventCreateDigitizerEvent");
    g_appendEvent = (IOHIDEventAppendEventFunc)dlsym(handle, "IOHIDEventAppendEvent");
    g_setIntegerValue = (IOHIDEventSetIntegerValueFunc)dlsym(handle, "IOHIDEventSetIntegerValue");
    g_setFloatValue = (IOHIDEventSetFloatValueFunc)dlsym(handle, "IOHIDEventSetFloatValue");

    if (createClient && scheduleClient && g_dispatchEvent && g_createDigitizerEvent) {
        g_HIDSystemClient = createClient(kCFAllocatorDefault);
        if (g_HIDSystemClient) {
            scheduleClient(g_HIDSystemClient, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        }
    }
}

+ (NSInteger)fakeTouchId:(NSInteger)pointId atPoint:(CGPoint)point withPhase:(UITouchPhase)phase {
    if (!g_HIDSystemClient || !g_createDigitizerEvent || !g_dispatchEvent) {
        return -1;
    }

    // إنشاء حدث لمسة الإصبع
    void* fingerEvent = g_createDigitizerEvent(kCFAllocatorDefault,
                                               0, // Timestamp
                                               3, // Type: Touch
                                               0, // Index
                                               1, // Identity
                                               phase, // Phase
                                               0, // Pressure
                                               0, // Twist
                                               0, // MajorRadius
                                               0, // MinorRadius
                                               0, // Quality
                                               true); // IsAbsolute

    if (!fingerEvent) return -1;

    // تعيين إحداثيات اللمس
    g_setFloatValue(fingerEvent, 0x00000006, point.x); // kIOHIDEventFieldDigitizerX
    g_setFloatValue(fingerEvent, 0x00000007, point.y); // kIOHIDEventFieldDigitizerY
    g_setIntegerValue(fingerEvent, 0x00000008, pointId); // kIOHIDEventFieldDigitizerIdentity

    // إنشاء حدث النظام وإضافة حدث اللمس
    void* systemEvent = g_createDigitizerEvent(kCFAllocatorDefault,
                                               0, // Timestamp
                                               3, // Type: Touch
                                               0, // Index
                                               0, // Identity
                                               0, // Phase (None)
                                               0, 0, 0, 0, 0, true);
    if (!systemEvent) {
        CFRelease(fingerEvent);
        return -1;
    }

    g_appendEvent(systemEvent, fingerEvent);
    CFRelease(fingerEvent);

    // إرسال الحدث
    g_dispatchEvent(g_HIDSystemClient, systemEvent);
    CFRelease(systemEvent);

    return pointId;
}

+ (NSInteger)getAvailablePointId {
    static NSInteger nextId = 1;
    return nextId++;
}

+ (void)releasePointId:(NSInteger)pointId {
    // لا حاجة لفعل شيء حالياً، يمكن تركها فارغة
}

@end
