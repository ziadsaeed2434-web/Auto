// GestureRecorder.m
#import "GestureRecorder.h"
#import "PTFakeTouch.h"

#define BUTTON_HEIGHT 44
#define PANEL_PADDING 10
#define PANEL_WIDTH 280

@interface GestureRecorder ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) NSMutableArray *recordedTouches;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) NSTimer *playTimer;
@property (nonatomic, assign) NSInteger playIndex;
@property (nonatomic, strong) NSMutableArray *indicatorLayers;
@end

@implementation GestureRecorder

+ (instancetype)sharedInstance {
    static GestureRecorder *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GestureRecorder alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _recordedTouches = [NSMutableArray array];
        _indicatorLayers = [NSMutableArray array];
        _isRecording = NO;
        _isPlaying = NO;
        _playIndex = 0;
    }
    return self;
}

#pragma mark - Public Methods

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.overlayWindow) {
            [self setupOverlayWindow];
        }
        self.overlayWindow.hidden = NO;
    });
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.overlayWindow.hidden = YES;
    });
}

#pragma mark - Setup

- (void)setupOverlayWindow {
    // إنشاء نافذة شفافة فوق كل شيء
    self.overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayWindow.windowLevel = UIWindowLevelStatusBar + 100;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.rootViewController = [UIViewController new];
    self.overlayWindow.hidden = YES;

    // لوحة التحكم العائمة
    self.panelView = [[UIView alloc] initWithFrame:CGRectMake(
        [UIScreen mainScreen].bounds.size.width - PANEL_WIDTH - PANEL_PADDING,
        100,
        PANEL_WIDTH,
        BUTTON_HEIGHT * 4 + PANEL_PADDING * 5
    )];
    self.panelView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    self.panelView.layer.cornerRadius = 12;
    self.panelView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.panelView.layer.shadowOpacity = 0.5;
    self.panelView.layer.shadowRadius = 8;
    self.panelView.userInteractionEnabled = YES;

    // جعل اللوحة قابلة للسحب
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.panelView addGestureRecognizer:pan];

    // إنشاء الأزرار الأربعة
    NSArray *titles = @[@"⏺ بدء التسجيل", @"⏹ إيقاف وحفظ", @"▶ تشغيل/تكرار", @"⏸ إيقاف"];
    SEL actions[] = {@selector(startRecording), @selector(stopAndSave), @selector(playRecording), @selector(stopPlaying)};

    for (int i = 0; i < 4; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(PANEL_PADDING, PANEL_PADDING + i * (BUTTON_HEIGHT + PANEL_PADDING),
                               PANEL_WIDTH - PANEL_PADDING * 2, BUTTON_HEIGHT);
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        btn.backgroundColor = [[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0] colorWithAlphaComponent:0.7];
        btn.layer.cornerRadius = 8;
        btn.tag = i;
        [btn addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside];
        [self.panelView addSubview:btn];
    }

    [self.overlayWindow.rootViewController.view addSubview:self.panelView];
}

#pragma mark - Actions

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.overlayWindow];
    self.panelView.center = CGPointMake(self.panelView.center.x + translation.x,
                                        self.panelView.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.overlayWindow];
}

- (void)startRecording {
    self.recordedTouches = [NSMutableArray array];
    self.isRecording = YES;
    self.isPlaying = NO;

    // إضافة Tap Gesture Recognizer للشاشة لتسجيل اللمسات
    UITapGestureRecognizer *tapRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(recordTouch:)];
    tapRec.cancelsTouchesInView = NO;
    tapRec.delegate = self;
    [self.overlayWindow.rootViewController.view addGestureRecognizer:tapRec];

    [self showToast:@"بدأ التسجيل... المس الشاشة الآن"];
}

- (void)recordTouch:(UITapGestureRecognizer *)gesture {
    if (!self.isRecording) return;

    CGPoint point = [gesture locationInView:self.overlayWindow];
    NSDictionary *touchInfo = @{
        @"x": @(point.x),
        @"y": @(point.y),
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    [self.recordedTouches addObject:touchInfo];

    // إظهار مؤشر بصري أثناء التسجيل أيضاً
    [self showTouchIndicatorAtPoint:point];
}

- (void)stopAndSave {
    self.isRecording = NO;
    // إزالة Tap Gesture Recognizer
    for (UIGestureRecognizer *rec in self.overlayWindow.rootViewController.view.gestureRecognizers) {
        if ([rec isKindOfClass:[UITapGestureRecognizer class]]) {
            [self.overlayWindow.rootViewController.view removeGestureRecognizer:rec];
        }
    }
    [self showToast:[NSString stringWithFormat:@"تم الحفظ: %lu لمسة", (unsigned long)self.recordedTouches.count]];
}

- (void)playRecording {
    if (self.recordedTouches.count == 0) {
        [self showToast:@"لا توجد لمسات مسجلة"];
        return;
    }
    if (self.isPlaying) return;

    self.isPlaying = YES;
    self.playIndex = 0;
    [self startPlayTimer];
    [self showToast:@"بدأ التشغيل المتكرر..."];
}

- (void)stopPlaying {
    self.isPlaying = NO;
    [self.playTimer invalidate];
    self.playTimer = nil;
    [self showToast:@"تم إيقاف التشغيل"];
}

#pragma mark - Playback

- (void)startPlayTimer {
    self.playTimer = [NSTimer scheduledTimerWithTimeInterval:0.8
                                                      target:self
                                                    selector:@selector(playNextTouch)
                                                    userInfo:nil
                                                     repeats:YES];
    [self playNextTouch]; // تشغيل أول لمسة فوراً
}

- (void)playNextTouch {
    if (!self.isPlaying || self.recordedTouches.count == 0) return;

    if (self.playIndex >= self.recordedTouches.count) {
        self.playIndex = 0; // إعادة التعيين للتكرار
    }

    NSDictionary *touchInfo = self.recordedTouches[self.playIndex];
    CGPoint point = CGPointMake([touchInfo[@"x"] floatValue], [touchInfo[@"y"] floatValue]);

    // 1. إظهار المؤشر البصري
    [self showTouchIndicatorAtPoint:point];

    // 2. تنفيذ اللمسة الحقيقية عبر PTFakeTouch
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSInteger pointId = [PTFakeTouch getAvailablePointId];
        [PTFakeTouch fakeTouchId:pointId atPoint:point withPhase:UITouchPhaseBegan];
        [NSThread sleepForTimeInterval:0.05]; // ضغطة سريعة
        [PTFakeTouch fakeTouchId:pointId atPoint:point withPhase:UITouchPhaseEnded];
    });

    self.playIndex++;
}

#pragma mark - Touch Indicator

- (void)showTouchIndicatorAtPoint:(CGPoint)point {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat radius = 30.0;
        UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(point.x - radius, point.y - radius, radius * 2, radius * 2)];
        indicator.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.4];
        indicator.layer.cornerRadius = radius;
        indicator.userInteractionEnabled = NO;

        [self.overlayWindow.rootViewController.view addSubview:indicator];

        [UIView animateWithDuration:0.3 animations:^{
            indicator.transform = CGAffineTransformMakeScale(1.5, 1.5);
            indicator.alpha = 0;
        } completion:^(BOOL finished) {
            [indicator removeFromSuperview];
        }];
    });
}

#pragma mark - Toast

- (void)showToast:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, [UIScreen mainScreen].bounds.size.width - 40, 40)];
        toast.text = message;
        toast.textAlignment = NSTextAlignmentCenter;
        toast.textColor = [UIColor whiteColor];
        toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        toast.layer.cornerRadius = 8;
        toast.clipsToBounds = YES;
        toast.font = [UIFont systemFontOfSize:14];

        [self.overlayWindow.rootViewController.view addSubview:toast];

        [UIView animateWithDuration:2.0 animations:^{
            toast.alpha = 0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // عدم تسجيل اللمسات على لوحة التحكم نفسها
    if ([touch.view isDescendantOfView:self.panelView]) {
        return NO;
    }
    return YES;
}

@end
