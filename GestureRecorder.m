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

#pragma mark - Helper

- (UIWindow *)activeWindow {
    UIWindow *found = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) { found = w; break; }
                }
                if (!found && ws.windows.count > 0) found = ws.windows.firstObject;
            }
            if (found) break;
        }
    }
    if (!found) {
        found = [UIApplication sharedApplication].windows.firstObject;
    }
    return found;
}

#pragma mark - Public

- (void)showInWindowScene:(UIWindowScene *)scene {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) {
            self.overlayWindow.hidden = NO;
            return;
        }

        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGRect panelFrame = CGRectMake(
            screenBounds.size.width - PANEL_WIDTH - PANEL_PADDING,
            100,
            PANEL_WIDTH,
            BUTTON_HEIGHT * 4 + PANEL_PADDING * 5
        );

        // مهم: إنشاء النافذة عبر windowScene للتوافق مع iOS 13+
        if (@available(iOS 13.0, *)) {
            if (scene != nil) {
                self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
                self.overlayWindow.frame = panelFrame;
            } else {
                self.overlayWindow = [[UIWindow alloc] initWithFrame:panelFrame];
            }
        } else {
            self.overlayWindow = [[UIWindow alloc] initWithFrame:panelFrame];
        }

        self.overlayWindow.windowLevel = UIWindowLevelAlert + 100;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.rootViewController = [UIViewController new];
        self.overlayWindow.hidden = NO;

        NSLog(@"[GestureRecorder] Overlay window created: %@", self.overlayWindow);

        [self buildPanel];
    });
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.overlayWindow.hidden = YES;
    });
}

#pragma mark - Build UI

- (void)buildPanel {
    self.panelView = [[UIView alloc] initWithFrame:self.overlayWindow.bounds];
    self.panelView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.panelView.layer.cornerRadius = 12;
    self.panelView.clipsToBounds = YES;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(handlePan:)];
    [self.panelView addGestureRecognizer:pan];

    NSArray *titles = @[@"بدء التسجيل", @"إيقاف وحفظ", @"تشغيل/تكرار", @"إيقاف"];
    SEL actions[4] = {@selector(startRecording),
                      @selector(stopAndSave),
                      @selector(playRecording),
                      @selector(stopPlaying)};

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

    [self.overlayWindow.rootViewController.view addSubview:self.panelView];
}

#pragma mark - Pan

- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.overlayWindow];
    self.overlayWindow.center = CGPointMake(self.overlayWindow.center.x + t.x,
                                            self.overlayWindow.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.overlayWindow];
}

#pragma mark - Actions

- (void)startRecording {
    self.recordedTouches = [NSMutableArray array];
    self.isRecording = YES;
    self.isPlaying = NO;
    [self showToast:@"بدأ التسجيل..."];
    NSLog(@"[GestureRecorder] Recording started");
}

- (void)stopAndSave {
    self.isRecording = NO;
    [self showToast:[NSString stringWithFormat:@"تم الحفظ: %lu", (unsigned long)self.recordedTouches.count]];
    NSLog(@"[GestureRecorder] Saved %lu touches", (unsigned long)self.recordedTouches.count);
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
    if (self.playIndex >= (NSInteger)self.recordedTouches.count) self.playIndex = 0;

    NSDictionary *t = self.recordedTouches[self.playIndex];
    CGPoint point = CGPointMake([t[@"x"] floatValue], [t[@"y"] floatValue]);

    [self flashIndicatorAtPoint:point];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSInteger pid = [PTFakeTouch getAvailablePointId];

        [PTFakeTouch fakeTouchId:pid AtPoint:point withTouchPhase:UITouchPhaseBegan];
        [NSThread sleepForTimeInterval:0.05];
        [PTFakeTouch fakeTouchId:pid
                         AtPoint:CGPointMake(point.x + 0.5, point.y + 0.5)
                  withTouchPhase:UITouchPhaseMoved];
        [NSThread sleepForTimeInterval:0.03];
        [PTFakeTouch fakeTouchId:pid AtPoint:point withTouchPhase:UITouchPhaseEnded];
    });

    self.playIndex++;
}

#pragma mark - Visual

- (void)flashIndicatorAtPoint:(CGPoint)point {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *host = [self activeWindow];
        if (!host) host = self.overlayWindow;
        if (!host) return;

        CGFloat r = 30.0;
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(point.x - r, point.y - r, r * 2, r * 2)];
        dot.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.45];
        dot.layer.cornerRadius = r;
        dot.userInteractionEnabled = NO;
        [host addSubview:dot];

        [UIView animateWithDuration:0.35 animations:^{
            dot.transform = CGAffineTransformMakeScale(1.6, 1.6);
            dot.alpha = 0;
        } completion:^(BOOL finished) {
            [dot removeFromSuperview];
        }];
    });
}

- (void)showToast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *host = [self activeWindow];
        if (!host) return;

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
        [host addSubview:toast];

        [UIView animateWithDuration:2.0 animations:^{
            toast.alpha = 0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}

@end
