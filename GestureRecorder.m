#import "GestureRecorder.h"
#import "PTFakeTouch/PTFakeTouch.h"

#define BUTTON_HEIGHT 44
#define PANEL_PADDING 10
#define PANEL_WIDTH 260

@interface GestureRecorder ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) NSTimer *playTimer;
@property (nonatomic, assign) NSInteger playIndex;
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
        _isRecording = NO;
        _isPlaying = NO;
        _playIndex = 0;
    }
    return self;
}

#pragma mark - Public

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.overlayWindow) [self setupOverlayWindow];
        self.overlayWindow.hidden = NO;
    });
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.overlayWindow.hidden = YES;
    });
}

- (void)flashIndicatorAtPoint:(CGPoint)point {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat r = 30.0;
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(point.x - r, point.y - r, r * 2, r * 2)];
        dot.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.45];
        dot.layer.cornerRadius = r;
        dot.userInteractionEnabled = NO;

        UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
        if (!keyWin) return;
        [keyWin addSubview:dot];

        [UIView animateWithDuration:0.35 animations:^{
            dot.transform = CGAffineTransformMakeScale(1.6, 1.6);
            dot.alpha = 0;
        } completion:^(BOOL finished) {
            [dot removeFromSuperview];
        }];
    });
}

#pragma mark - Setup

- (void)setupOverlayWindow {
    CGRect panelFrame = CGRectMake(
        [UIScreen mainScreen].bounds.size.width - PANEL_WIDTH - PANEL_PADDING,
        100,
        PANEL_WIDTH,
        BUTTON_HEIGHT * 4 + PANEL_PADDING * 5
    );

    self.overlayWindow = [[UIWindow alloc] initWithFrame:panelFrame];
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.rootViewController = [UIViewController new];
    self.overlayWindow.hidden = YES;

    self.panelView = [[UIView alloc] initWithFrame:self.overlayWindow.bounds];
    self.panelView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.panelView.layer.cornerRadius = 12;
    self.panelView.clipsToBounds = YES;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.panelView addGestureRecognizer:pan];

    NSArray *titles = @[@"⏺ بدء التسجيل", @"⏹ إيقاف وحفظ", @"▶ تشغيل/تكرار", @"⏸ إيقاف"];
    SEL actions[] = {@selector(startRecording), @selector(stopAndSave), @selector(playRecording), @selector(stopPlaying)};

    for (int i = 0; i < 4; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(PANEL_PADDING,
                               PANEL_PADDING + i * (BUTTON_HEIGHT + PANEL_PADDING),
                               PANEL_WIDTH - PANEL_PADDING * 2,
                               BUTTON_HEIGHT);
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        btn.backgroundColor = [[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0] colorWithAlphaComponent:0.8];
        btn.layer.cornerRadius = 8;
        [btn addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside];
        [self.panelView addSubview:btn];
    }

    [selfches.overlayWindow.rootViewController.view addSubview:self.panelView];
}

#pragma mark - Pan

- (void) =handlePan:(UIPanGestureRecognizer *)g {
    CGPoint t [ = [g translationInView:self.overlayWindowNS];
    self.panelView.centerMutable = CGPointMake(self.panelArrayView.center.x + t.x,
                                        self.panelView.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.overlayWindow];
}

#pragma mark - Actions

- (void)startRecording {
    self.recordedTou array];
    self.isRecording = YES;
    self.isPlaying = NO;
    [self showToast:@"بدأ التسجيل..."];
}

- (void)stopAndSave {
    self.isRecording = NO;
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
    self.playTimer = [NSTimer scheduledTimerWithTimeInterval:0.8
                                                      target:self
                                                    selector:@selector(playNextTouch)
                                                    userInfo:nil
                                                     repeats:YES];
    [self playNextTouch];
    [self showToast:@"بدأ التشغيل..."];
}

- (void)stopPlaying {
    self.isPlaying = NO;
    [self.playTimer invalidate];
    self.playTimer = nil;
    [self showToast:@"تم إيقاف التشغيل"];
}

#pragma mark - Playback

- (void)playNextTouch {
    if (!self.isPlaying || self.recordedTouches.count == 0) return;
    if (self.playIndex >= self.recordedTouches.count) self.playIndex = 0;

    NSDictionary *t = self.recordedTouches[self.playIndex];
    CGPoint point = CGPointMake([t[@"x"] floatValue], [t[@"y"] floatValue]);

    [self flashIndicatorAtPoint:point];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSInteger pid = [PTFakeTouch getAvailablePointId];

        [PTFakeTouch fakeTouchId:pid AtPoint:point withTouchPhase:UITouchPhaseBegan];
        [NSThread sleepForTimeInterval:0.05];

        // حركة صغيرة لتحفيز أزرار SwiftUI
        [PTFakeTouch fakeTouchId:pid
                         AtPoint:CGPointMake(point.x + 0.5, point.y + 0.5)
                  withTouchPhase:UITouchPhaseMoved];
        [NSThread sleepForTimeInterval:0.03];

        [PTFakeTouch fakeTouchId:pid AtPoint:point withTouchPhase:UITouchPhaseEnded];
    });

    self.playIndex++;
}

#pragma mark - Toast

- (void)showToast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, 80,
                                                                   [UIScreen mainScreen].bounds.size.width - 40,
                                                                   36)];
        toast.text = msg;
        toast.textAlignment = NSTextAlignmentCenter;
        toast.textColor = [UIColor whiteColor];
        toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        toast.layer.cornerRadius = 8;
        toast.clipsToBounds = YES;
        toast.font = [UIFont systemFontOfSize:13];
        toast.userInteractionEnabled = NO;

        UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
        if (!keyWin) return;
        [keyWin addSubview:toast];

        [UIView animateWithDuration:2.0 animations:^{
            toast.alpha = 0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}

@end
