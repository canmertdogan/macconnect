#import "MainWindowController.h"
#import "BluetoothBridge.h"
#import <QuartzCore/QuartzCore.h>

// Utility: Pretty app name resolution
static NSString *MCResolvePrettyAppName(NSString *rawAppName, NSString *packageName) {
    if (rawAppName && rawAppName.length > 0 && ![rawAppName containsString:@"."] && ![rawAppName isEqualToString:packageName]) {
        return rawAppName;
    }
    NSString *pkg = (packageName && packageName.length > 0) ? packageName : rawAppName;
    if (!pkg || pkg.length == 0) return @"Uygulama";

    NSDictionary *known = @{
        @"com.google.android.calendar": @"Google Takvim",
        @"com.google.android.gm": @"Gmail",
        @"com.google.android.apps.messaging": @"Google Mesajlar",
        @"com.google.android.youtube": @"YouTube",
        @"com.google.android.apps.photos": @"Google Fotoğraflar",
        @"com.google.android.apps.maps": @"Google Haritalar",
        @"com.google.android.deskclock": @"Saat",
        @"com.google.android.keep": @"Google Keep",
        @"com.whatsapp": @"WhatsApp",
        @"org.telegram.messenger": @"Telegram",
        @"com.instagram.android": @"Instagram",
        @"com.twitter.android": @"X",
        @"com.x.android": @"X",
        @"com.spotify.music": @"Spotify",
        @"com.facebook.katana": @"Facebook",
        @"com.facebook.orca": @"Messenger",
        @"com.slack": @"Slack",
        @"com.discord": @"Discord",
        @"com.microsoft.teams": @"Microsoft Teams",
        @"com.microsoft.office.outlook": @"Outlook",
        @"com.netflix.mediaclient": @"Netflix",
        @"com.android.phone": @"Telefon",
        @"com.google.android.dialer": @"Telefon",
        @"com.samsung.android.incallui": @"Telefon",
        @"com.apple.android.music": @"Apple Music",
        @"deezer.android.app": @"Deezer"
    };

    if (known[pkg]) {
        return known[pkg];
    }

    NSArray *parts = [pkg componentsSeparatedByString:@"."];
    if (parts.count >= 2) {
        NSString *last = [parts lastObject];
        if ([last localizedCaseInsensitiveCompare:@"android"] == NSOrderedSame ||
            [last localizedCaseInsensitiveCompare:@"app"] == NSOrderedSame) {
            last = parts[parts.count - 2];
        }
        if (last.length > 0) {
            return [last capitalizedString];
        }
    }
    return pkg;
}

static NSImage *MCDecodeBase64Icon(NSString *base64Str) {
    if (!base64Str || base64Str.length == 0) return nil;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data || data.length == 0) return nil;
    return [[NSImage alloc] initWithData:data];
}

// Flipped coordinate view (y = 0 at top-left)
@interface MCFlippedView : NSView
@end

@implementation MCFlippedView
- (BOOL)isFlipped {
    return YES;
}
@end

// Liquid Glass Card View (Layer-backed with frosted translucent surface and subtle rim border)
@interface MCGlassCardView : MCFlippedView
@property (nonatomic, strong) NSColor *glassFillColor;
@property (nonatomic, strong) NSColor *glassStrokeColor;
@property (nonatomic, assign) CGFloat glassCornerRadius;
@end

@implementation MCGlassCardView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        _glassCornerRadius = 16.0;
        _glassFillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.07];
        _glassStrokeColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.18];
        [self applyGlassStyle];
    }
    return self;
}

- (void)applyGlassStyle {
    self.layer.cornerRadius = _glassCornerRadius;
    self.layer.masksToBounds = NO;
    self.layer.backgroundColor = _glassFillColor.CGColor;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = _glassStrokeColor.CGColor;
    self.layer.shadowColor = [NSColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.35;
    self.layer.shadowRadius = 16.0;
    self.layer.shadowOffset = CGSizeMake(0, -4);
}

- (void)setGlassFillColor:(NSColor *)color {
    _glassFillColor = color;
    self.layer.backgroundColor = color.CGColor;
}

- (void)setGlassStrokeColor:(NSColor *)color {
    _glassStrokeColor = color;
    self.layer.borderColor = color.CGColor;
}

- (void)setGlassCornerRadius:(CGFloat)radius {
    _glassCornerRadius = radius;
    self.layer.cornerRadius = radius;
}

@end

// Passive label that never intercepts mouse clicks
@interface MCHitThroughLabel : NSTextField
@end

@implementation MCHitThroughLabel
- (NSView *)hitTest:(NSPoint)point {
    return nil;
}
@end

// Custom Circular & Pill Liquid Glass Buttons
@interface MCGlassButton : NSButton
@property (nonatomic, copy) NSString *customIdentifier;
@property (nonatomic, copy) void (^onClickBlock)(void);
@end

@implementation MCGlassButton

- (BOOL)isFlipped { return YES; }

- (NSView *)hitTest:(NSPoint)point {
    // In AppKit, point is in superview's coordinate space
    NSPoint local = [self convertPoint:point fromView:self.superview];
    if (NSPointInRect(local, self.bounds) && !self.isHidden && self.isEnabled) {
        return self;
    }
    return nil;
}

- (void)mouseDown:(NSEvent *)event {
    self.layer.opacity = 0.50;
    BOOL keepOn = YES;
    BOOL isInside = YES;
    while (keepOn) {
        NSEvent *nextEvent = [self.window nextEventMatchingMask:(NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged)];
        if (!nextEvent) break;
        NSPoint mouseLoc = [self convertPoint:nextEvent.locationInWindow fromView:nil];
        isInside = NSPointInRect(mouseLoc, self.bounds);
        self.layer.opacity = isInside ? 0.50 : 1.0;
        if (nextEvent.type == NSEventTypeLeftMouseUp) {
            keepOn = NO;
        }
    }
    self.layer.opacity = 1.0;
    if (isInside) {
        if (self.target && self.action && [self.target respondsToSelector:self.action]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.target performSelector:self.action withObject:self];
            #pragma clang diagnostic pop
        }
        if (self.onClickBlock) {
            self.onClickBlock();
        }
    }
}

+ (instancetype)circularDialButtonWithDigit:(NSString *)digit subtext:(NSString *)subtext target:(id)target action:(SEL)action {
    MCGlassButton *btn = [[MCGlassButton alloc] initWithFrame:NSMakeRect(0, 0, 62, 62)];
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 31;
    btn.layer.masksToBounds = YES;
    btn.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.09].CGColor;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.18].CGColor;
    btn.bezelStyle = NSBezelStyleRegularSquare;
    btn.bordered = NO;
    btn.title = @""; // Clear default AppKit "Button" title!
    [btn setButtonType:NSButtonTypeMomentaryChange];
    btn.target = target;
    btn.action = action;
    btn.customIdentifier = digit;

    MCHitThroughLabel *digitLbl = [[MCHitThroughLabel alloc] initWithFrame:NSMakeRect(0, subtext.length > 0 ? 8 : 16, 62, 28)];
    digitLbl.stringValue = digit;
    digitLbl.font = [NSFont systemFontOfSize:23 weight:NSFontWeightLight];
    digitLbl.textColor = [NSColor whiteColor];
    digitLbl.alignment = NSTextAlignmentCenter;
    digitLbl.editable = NO;
    digitLbl.selectable = NO;
    digitLbl.bordered = NO;
    digitLbl.backgroundColor = [NSColor clearColor];
    [btn addSubview:digitLbl];

    if (subtext.length > 0) {
        MCHitThroughLabel *subLbl = [[MCHitThroughLabel alloc] initWithFrame:NSMakeRect(0, 36, 62, 14)];
        subLbl.stringValue = subtext;
        subLbl.font = [NSFont systemFontOfSize:8.5 weight:NSFontWeightBold];
        subLbl.textColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.60];
        subLbl.alignment = NSTextAlignmentCenter;
        subLbl.editable = NO;
        subLbl.selectable = NO;
        subLbl.bordered = NO;
        subLbl.backgroundColor = [NSColor clearColor];
        [btn addSubview:subLbl];
    }

    return btn;
}

+ (instancetype)callActionButtonWithTarget:(id)target action:(SEL)action {
    MCGlassButton *btn = [[MCGlassButton alloc] initWithFrame:NSMakeRect(0, 0, 62, 62)];
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 31;
    btn.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.18 green:0.80 blue:0.44 alpha:1.0].CGColor;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [NSColor colorWithCalibratedRed:0.3 green:0.95 blue:0.55 alpha:0.8].CGColor;
    btn.layer.shadowColor = [NSColor colorWithCalibratedRed:0.18 green:0.80 blue:0.44 alpha:1.0].CGColor;
    btn.layer.shadowOpacity = 0.55;
    btn.layer.shadowRadius = 12;
    btn.layer.shadowOffset = CGSizeMake(0, -2);
    btn.bezelStyle = NSBezelStyleRegularSquare;
    btn.bordered = NO;
    btn.title = @""; // Clear default AppKit "Button" title!
    [btn setButtonType:NSButtonTypeMomentaryChange];
    btn.target = target;
    btn.action = action;

    NSImageView *callIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(18, 18, 26, 26)];
    callIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
    if (@available(macOS 11.0, *)) {
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:22 weight:NSFontWeightBold];
        callIcon.image = [[NSImage imageWithSystemSymbolName:@"phone.fill" accessibilityDescription:nil] imageWithSymbolConfiguration:cfg];
        callIcon.contentTintColor = [NSColor whiteColor];
    }
    [btn addSubview:callIcon];

    return btn;
}

+ (instancetype)pillButtonWithTitle:(NSString *)title bgAlpha:(CGFloat)bgAlpha tintColor:(NSColor *)tint target:(id)target action:(SEL)action {
    MCGlassButton *btn = [[MCGlassButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 32)];
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 16;
    btn.layer.backgroundColor = [tint colorWithAlphaComponent:bgAlpha].CGColor;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [tint colorWithAlphaComponent:0.5].CGColor;
    btn.bezelStyle = NSBezelStyleRegularSquare;
    btn.bordered = NO;
    btn.title = title;
    btn.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    btn.contentTintColor = tint;
    btn.target = target;
    btn.action = action;
    return btn;
}

@end

static NSString *MCFindAdbPath(void) {
    NSArray *candidates = @[
        @"/opt/homebrew/bin/adb",
        @"/usr/local/bin/adb",
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Android/sdk/platform-tools/adb"],
        @"/usr/bin/adb"
    ];
    for (NSString *p in candidates) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:p]) {
            return p;
        }
    }
    return @"adb";
}

static NSString *MCFindScrcpyPath(void) {
    NSArray *candidates = @[
        @"/opt/homebrew/bin/scrcpy",
        @"/usr/local/bin/scrcpy",
        [NSHomeDirectory() stringByAppendingPathComponent:@".local/bin/scrcpy"]
    ];
    for (NSString *p in candidates) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:p]) {
            return p;
        }
    }
    return nil;
}

@interface MainWindowController ()

// Main Layout Views
@property (nonatomic, strong) NSVisualEffectView *sidebarEffectView;
@property (nonatomic, strong) MCFlippedView *sidebarContentView;
@property (nonatomic, strong) NSVisualEffectView *contentEffectView;
@property (nonatomic, strong) MCFlippedView *contentContainerView;
@property (nonatomic, strong) NSMutableArray<NSButton *> *navButtons;
@property (nonatomic, assign) NSInteger currentTabIndex;

// Modal Overlay for Notification Details
@property (nonatomic, strong) MCFlippedView *detailOverlayView;
@property (nonatomic, strong) MCGlassCardView *detailModalCard;

// Sidebar Elements
@property (nonatomic, strong) MCGlassCardView *sidebarFooterCard;
@property (nonatomic, strong) NSView *sidebarStatusDot;
@property (nonatomic, strong) NSTextField *sidebarStatusLabel;
@property (nonatomic, strong) NSTextField *sidebarBatteryLabel;
@property (nonatomic, strong) NSButton *sidebarConnectButton;

// Tab Views
@property (nonatomic, strong) MCFlippedView *callsView;
@property (nonatomic, strong) MCFlippedView *notificationsView;
@property (nonatomic, strong) MCFlippedView *mediaView;
@property (nonatomic, strong) MCFlippedView *deviceView;
@property (nonatomic, strong) MCFlippedView *mirrorView;
@property (nonatomic, strong) MCFlippedView *settingsView;

// Screen Mirroring Components
@property (nonatomic, strong) NSTextField *mirrorStatusLabel;
@property (nonatomic, strong) NSTextField *mirrorIpField;
@property (nonatomic, strong) NSTextField *mirrorLogLabel;
@property (nonatomic, strong) MCGlassButton *btnLaunchWirelessMirror;
@property (nonatomic, strong) MCGlassButton *btnLaunchUsbMirror;
@property (nonatomic, strong) MCGlassButton *btnAdbTcpip;
@property (nonatomic, strong) MCGlassButton *btnInstallScrcpy;

// Continuity Clipboard indicator in Device Tab
@property (nonatomic, strong) NSTextField *clipboardSyncBadge;
@property (nonatomic, strong) NSTextField *clipboardLastSyncTimeLabel;

// Calls Tab Components
@property (nonatomic, strong) MCGlassCardView *callHeroCard;
@property (nonatomic, strong) NSImageView *callHeroAvatarImageView;
@property (nonatomic, strong) NSTextField *callHeroTitleLabel;
@property (nonatomic, strong) NSTextField *callHeroSubtitleLabel;
@property (nonatomic, strong) NSStackView *callHeroButtonStack;
@property (nonatomic, strong) MCGlassButton *btnAnswerCall;
@property (nonatomic, strong) MCGlassButton *btnAnswerSpeakerCall;
@property (nonatomic, strong) MCGlassButton *btnTransferComputerCall;
@property (nonatomic, strong) MCGlassButton *btnRejectCall;

@property (nonatomic, strong) NSTextField *dialerNumberField;
@property (nonatomic, strong) NSScrollView *recentCallsScrollView;
@property (nonatomic, strong) MCFlippedView *recentCallsDocView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recentCalls;
@property (nonatomic, strong) NSDictionary *activeCallInfo;

// Notifications Tab Components
@property (nonatomic, strong) NSTextField *notificationsCountBadge;
@property (nonatomic, strong) NSScrollView *notificationsScrollView;
@property (nonatomic, strong) MCFlippedView *notificationsDocView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *notificationsList;

// Media Tab Components
@property (nonatomic, strong) MCGlassCardView *mediaHeroCard;
@property (nonatomic, strong) NSTextField *mediaAppBadgeLabel;
@property (nonatomic, strong) NSTextField *mediaTitleLabel;
@property (nonatomic, strong) NSTextField *mediaArtistLabel;
@property (nonatomic, strong) NSTextField *mediaStatusBadge;

// Device Tab Components
@property (nonatomic, strong) NSTextField *deviceModelLabel;
@property (nonatomic, strong) NSTextField *deviceStatusFullLabel;
@property (nonatomic, strong) NSTextField *deviceBatteryFullLabel;
@property (nonatomic, strong) NSTextView *sendClipboardTextView;
@property (nonatomic, strong) NSTextView *receivedClipboardTextView;

// Settings Components
@property (nonatomic, strong) NSButton *checkFilterMedia;
@property (nonatomic, strong) NSButton *checkAutoRaiseOnCall;
@property (nonatomic, strong) NSButton *checkPlaySound;

@end

@implementation MainWindowController

+ (instancetype)sharedController {
    static MainWindowController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MainWindowController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(100, 100, 1020, 720);
    NSWindowStyleMask style = (NSWindowStyleMaskTitled |
                               NSWindowStyleMaskClosable |
                               NSWindowStyleMaskMiniaturizable |
                               NSWindowStyleMaskResizable |
                               NSWindowStyleMaskFullSizeContentView);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        _recentCalls = [[NSMutableArray alloc] init];
        _notificationsList = [[NSMutableArray alloc] init];
        _navButtons = [[NSMutableArray alloc] init];
        _currentTabIndex = 0;

        // Force Apple Dark Aqua appearance for the ultimate Liquid Glass feel
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];

        // TRUE LIQUID GLASS: Make window non-opaque and clear background so visual effects blur desktop wallpaper
        window.opaque = NO;
        window.backgroundColor = [NSColor clearColor];
        window.hasShadow = YES;

        window.title = @"MacConnect";
        window.titleVisibility = NSWindowTitleHidden;
        window.titlebarAppearsTransparent = YES;
        window.minSize = NSMakeSize(960, 680);
        window.delegate = self;
        window.movableByWindowBackground = YES;

        [self setupUI];
    }
    return self;
}

- (void)showWindowAndActivate {
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - Window Delegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [self.window orderOut:nil];
    return NO;
}

- (void)windowDidResize:(NSNotification *)notification {
    [self layoutAllViews];
}

#pragma mark - UI Setup (True Liquid Glass & Translucent Materials)

- (void)setupUI {
    NSView *root = self.window.contentView;

    CGFloat sidebarWidth = 230;

    // 1. Sidebar with Native macOS Frosted Glass (Sidebar Material)
    self.sidebarEffectView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, sidebarWidth, root.bounds.size.height)];
    self.sidebarEffectView.material = NSVisualEffectMaterialSidebar;
    self.sidebarEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.sidebarEffectView.state = NSVisualEffectStateActive;
    self.sidebarEffectView.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [root addSubview:self.sidebarEffectView];

    self.sidebarContentView = [[MCFlippedView alloc] initWithFrame:self.sidebarEffectView.bounds];
    self.sidebarContentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.sidebarEffectView addSubview:self.sidebarContentView];

    // Subtle 1px Glass Hairline Divider
    NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(sidebarWidth - 1, 0, 1, root.bounds.size.height)];
    divider.boxType = NSBoxCustom;
    divider.borderWidth = 0;
    divider.fillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.12];
    divider.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [root addSubview:divider];

    [self buildSidebarContent];

    // 2. Content Area with Translucent Liquid Glass Material
    NSRect contentRect = NSMakeRect(sidebarWidth, 0, root.bounds.size.width - sidebarWidth, root.bounds.size.height);
    self.contentEffectView = [[NSVisualEffectView alloc] initWithFrame:contentRect];
    self.contentEffectView.material = NSVisualEffectMaterialUnderWindowBackground;
    self.contentEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.contentEffectView.state = NSVisualEffectStateActive;
    self.contentEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:self.contentEffectView];

    self.contentContainerView = [[MCFlippedView alloc] initWithFrame:self.contentEffectView.bounds];
    self.contentContainerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.contentEffectView addSubview:self.contentContainerView];

    // 3. Build All 6 Liquid Glass Tab Views
    [self buildCallsTab];
    [self buildNotificationsTab];
    [self buildMediaTab];
    [self buildDeviceTab];
    [self buildScreenMirroringTab];
    [self buildSettingsTab];

    [self selectTab:0];
}

#pragma mark - Sidebar Construction

- (void)buildSidebarContent {
    CGFloat w = 230;

    // Header: App Icon and Title (Offset below window traffic lights at y = 50)
    NSImageView *logoView = [[NSImageView alloc] initWithFrame:NSMakeRect(20, 50, 32, 32)];
    logoView.image = [NSImage imageNamed:NSImageNameApplicationIcon];
    logoView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [self.sidebarContentView addSubview:logoView];

    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(60, 53, 150, 26)];
    titleLabel.stringValue = @"MacConnect";
    titleLabel.font = [NSFont systemFontOfSize:17 weight:NSFontWeightBold];
    titleLabel.textColor = [NSColor whiteColor];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    [self.sidebarContentView addSubview:titleLabel];

    // Status Pill (Translucent Glass Pill)
    MCGlassCardView *statusPill = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(16, 92, w - 32, 28)];
    statusPill.glassCornerRadius = 14;
    statusPill.glassFillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.08];
    statusPill.glassStrokeColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.15];
    [self.sidebarContentView addSubview:statusPill];

    self.sidebarStatusDot = [[NSView alloc] initWithFrame:NSMakeRect(10, 10, 8, 8)];
    self.sidebarStatusDot.wantsLayer = YES;
    self.sidebarStatusDot.layer.cornerRadius = 4;
    self.sidebarStatusDot.layer.backgroundColor = [NSColor systemRedColor].CGColor;
    [statusPill addSubview:self.sidebarStatusDot];

    self.sidebarStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(26, 5, w - 66, 18)];
    self.sidebarStatusLabel.stringValue = @"Bağlantı Yok";
    self.sidebarStatusLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.sidebarStatusLabel.textColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    self.sidebarStatusLabel.editable = NO;
    self.sidebarStatusLabel.bordered = NO;
    self.sidebarStatusLabel.backgroundColor = [NSColor clearColor];
    [statusPill addSubview:self.sidebarStatusLabel];

    // Navigation Items (Floating Liquid Glass Pills)
    NSArray *navItems = @[
        @{@"icon": @"📞", @"title": @"Aramalar & Tuş Takımı"},
        @{@"icon": @"🔔", @"title": @"Bildirimler"},
        @{@"icon": @"🎵", @"title": @"Şimdi Çalıyor"},
        @{@"icon": @"📋", @"title": @"Cihaz & Pano"},
        @{@"icon": @"🖥️", @"title": @"Ekran Yansıtma"},
        @{@"icon": @"⚙️", @"title": @"Ayarlar"}
    ];

    CGFloat btnY = 132;
    for (NSInteger i = 0; i < navItems.count; i++) {
        NSDictionary *item = navItems[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(12, btnY, w - 24, 38)];
        btn.title = [NSString stringWithFormat:@"%@  %@", item[@"icon"], item[@"title"]];
        btn.bezelStyle = NSBezelStyleRegularSquare;
        btn.wantsLayer = YES;
        btn.layer.cornerRadius = 10;
        btn.alignment = NSTextAlignmentLeft;
        btn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        btn.tag = i;
        btn.target = self;
        btn.action = @selector(navButtonClicked:);
        [self.sidebarContentView addSubview:btn];
        [self.navButtons addObject:btn];

        btnY += 44;
    }

    // Sidebar Footer: Battery & Connection Glass Card
    CGFloat footerH = 82;
    self.sidebarFooterCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(12, self.sidebarContentView.bounds.size.height - footerH - 18, w - 24, footerH)];
    self.sidebarFooterCard.glassCornerRadius = 14;
    self.sidebarFooterCard.autoresizingMask = NSViewMinYMargin;
    [self.sidebarContentView addSubview:self.sidebarFooterCard];

    self.sidebarBatteryLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, 48, w - 48, 20)];
    self.sidebarBatteryLabel.stringValue = @"🔋 Pil: --";
    self.sidebarBatteryLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.sidebarBatteryLabel.textColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    self.sidebarBatteryLabel.editable = NO;
    self.sidebarBatteryLabel.bordered = NO;
    self.sidebarBatteryLabel.backgroundColor = [NSColor clearColor];
    [self.sidebarFooterCard addSubview:self.sidebarBatteryLabel];

    self.sidebarConnectButton = [MCGlassButton pillButtonWithTitle:@"Telefona Bağlan"
                                                           bgAlpha:0.18
                                                         tintColor:[NSColor systemBlueColor]
                                                            target:self
                                                            action:@selector(toggleConnectionClicked:)];
    self.sidebarConnectButton.frame = NSMakeRect(12, 10, w - 48, 30);
    [self.sidebarFooterCard addSubview:self.sidebarConnectButton];
}

- (void)navButtonClicked:(NSButton *)sender {
    [self selectTab:sender.tag];
}

- (void)selectTab:(NSInteger)index {
    self.currentTabIndex = index;

    for (NSButton *btn in self.navButtons) {
        if (btn.tag == index) {
            btn.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:0.25].CGColor;
            btn.layer.borderWidth = 1.0;
            btn.layer.borderColor = [NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:0.5].CGColor;
            btn.contentTintColor = [NSColor whiteColor];
            btn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
        } else {
            btn.layer.backgroundColor = [NSColor clearColor].CGColor;
            btn.layer.borderWidth = 0.0;
            btn.contentTintColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
            btn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        }
    }

    [self.callsView removeFromSuperview];
    [self.notificationsView removeFromSuperview];
    [self.mediaView removeFromSuperview];
    [self.deviceView removeFromSuperview];
    [self.mirrorView removeFromSuperview];
    [self.settingsView removeFromSuperview];

    NSView *target = nil;
    switch (index) {
        case 0: target = self.callsView; break;
        case 1: target = self.notificationsView; break;
        case 2: target = self.mediaView; break;
        case 3: target = self.deviceView; break;
        case 4: target = self.mirrorView; break;
        case 5: target = self.settingsView; break;
    }

    if (target) {
        target.frame = self.contentContainerView.bounds;
        target.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self.contentContainerView addSubview:target];
    }
}

- (void)layoutAllViews {
    if (self.callsView.superview) self.callsView.frame = self.contentContainerView.bounds;
    if (self.notificationsView.superview) self.notificationsView.frame = self.contentContainerView.bounds;
    if (self.mediaView.superview) self.mediaView.frame = self.contentContainerView.bounds;
    if (self.deviceView.superview) self.deviceView.frame = self.contentContainerView.bounds;
    if (self.mirrorView.superview) self.mirrorView.frame = self.contentContainerView.bounds;
    if (self.settingsView.superview) self.settingsView.frame = self.contentContainerView.bounds;
    if (self.detailOverlayView) self.detailOverlayView.frame = self.contentContainerView.bounds;
}

#pragma mark - Tab 1: 📞 Aramalar (FaceTime Grade iPhone Style Circular Dialpad)

- (void)buildCallsTab {
    self.callsView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    // Header Title
    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 380, 28)];
    tabTitle.stringValue = @"Aramalar ve Telefon Köprüsü";
    tabTitle.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor whiteColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.callsView addSubview:tabTitle];

    // 1. Floating Incoming / Active Call Glass Card (y = 86, height = 90)
    CGFloat heroCardY = 86;
    CGFloat heroCardH = 90;
    self.callHeroCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, heroCardY, self.callsView.bounds.size.width - (pad * 2), heroCardH)];
    self.callHeroCard.autoresizingMask = NSViewWidthSizable;
    [self.callsView addSubview:self.callHeroCard];

    // Left Circle Avatar with Glow (Using native MCGlassCardView and perfectly centered SF Symbol)
    MCGlassCardView *avatarCircle = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(18, 20, 50, 50)];
    avatarCircle.glassCornerRadius = 25;
    avatarCircle.glassFillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.12];
    avatarCircle.glassStrokeColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.25];
    [self.callHeroCard addSubview:avatarCircle];

    self.callHeroAvatarImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(13, 13, 24, 24)];
    self.callHeroAvatarImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    if (@available(macOS 11.0, *)) {
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightMedium];
        NSImage *img = [[NSImage imageWithSystemSymbolName:@"phone.fill" accessibilityDescription:nil] imageWithSymbolConfiguration:cfg];
        self.callHeroAvatarImageView.image = img;
        self.callHeroAvatarImageView.contentTintColor = [NSColor whiteColor];
    }
    [avatarCircle addSubview:self.callHeroAvatarImageView];

    // Name & Subtitle
    self.callHeroTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(82, 16, self.callHeroCard.bounds.size.width - 520, 26)];
    self.callHeroTitleLabel.autoresizingMask = NSViewWidthSizable;
    self.callHeroTitleLabel.stringValue = @"Aktif Arama Yok";
    self.callHeroTitleLabel.font = [NSFont systemFontOfSize:17 weight:NSFontWeightBold];
    self.callHeroTitleLabel.textColor = [NSColor whiteColor];
    self.callHeroTitleLabel.editable = NO;
    self.callHeroTitleLabel.bordered = NO;
    self.callHeroTitleLabel.backgroundColor = [NSColor clearColor];
    [self.callHeroCard addSubview:self.callHeroTitleLabel];

    self.callHeroSubtitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(82, 44, self.callHeroCard.bounds.size.width - 100, 38)];
    self.callHeroSubtitleLabel.autoresizingMask = NSViewWidthSizable;
    self.callHeroSubtitleLabel.stringValue = @"Tuş takımından numara arayabilir veya gelen aramaları masanızdan yanıtlayabilirsiniz.";
    self.callHeroSubtitleLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.callHeroSubtitleLabel.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    self.callHeroSubtitleLabel.editable = NO;
    self.callHeroSubtitleLabel.bordered = NO;
    self.callHeroSubtitleLabel.backgroundColor = [NSColor clearColor];
    self.callHeroSubtitleLabel.cell.wraps = YES;
    self.callHeroSubtitleLabel.cell.scrollable = NO;
    [self.callHeroCard addSubview:self.callHeroSubtitleLabel];

    // Call Action Buttons (Right-aligned inside Hero Card)
    self.callHeroButtonStack = [[NSStackView alloc] initWithFrame:NSMakeRect(self.callHeroCard.bounds.size.width - 450, 28, 430, 34)];
    self.callHeroButtonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.callHeroButtonStack.spacing = 8;
    self.callHeroButtonStack.distribution = NSStackViewDistributionFillEqually;
    self.callHeroButtonStack.autoresizingMask = NSViewMinXMargin;
    [self.callHeroCard addSubview:self.callHeroButtonStack];

    self.btnAnswerCall = [MCGlassButton pillButtonWithTitle:@"📞 Cevapla" bgAlpha:0.25 tintColor:[NSColor systemGreenColor] target:self action:@selector(actionAnswerClicked:)];
    [self.callHeroButtonStack addArrangedSubview:self.btnAnswerCall];

    self.btnAnswerSpeakerCall = [MCGlassButton pillButtonWithTitle:@"🔊 Hoparlör" bgAlpha:0.25 tintColor:[NSColor systemBlueColor] target:self action:@selector(actionAnswerSpeakerClicked:)];
    [self.callHeroButtonStack addArrangedSubview:self.btnAnswerSpeakerCall];

    self.btnTransferComputerCall = [MCGlassButton pillButtonWithTitle:@"💻 Bilgisayara Al" bgAlpha:0.25 tintColor:[NSColor systemPurpleColor] target:self action:@selector(actionTransferComputerClicked:)];
    [self.callHeroButtonStack addArrangedSubview:self.btnTransferComputerCall];

    self.btnRejectCall = [MCGlassButton pillButtonWithTitle:@"❌ Reddet" bgAlpha:0.25 tintColor:[NSColor systemRedColor] target:self action:@selector(actionRejectClicked:)];
    [self.callHeroButtonStack addArrangedSubview:self.btnRejectCall];

    self.callHeroButtonStack.hidden = YES;

    // 2. Lower Area: Left = iPhone Style Liquid Glass Dialpad (width: 340, height: 436)
    CGFloat lowerY = 188;
    CGFloat lowerH = 436;
    MCGlassCardView *dialerCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, lowerY, 340, lowerH)];
    [self.callsView addSubview:dialerCard];

    // TOP OF DIALPAD CARD: Number Input Field with Monospaced Digits (y = 14)
    self.dialerNumberField = [[NSTextField alloc] initWithFrame:NSMakeRect(24, 14, 244, 38)];
    self.dialerNumberField.placeholderString = @"Numara tuşlayın...";
    self.dialerNumberField.font = [NSFont monospacedDigitSystemFontOfSize:25 weight:NSFontWeightLight];
    self.dialerNumberField.textColor = [NSColor whiteColor];
    self.dialerNumberField.backgroundColor = [NSColor clearColor];
    self.dialerNumberField.bordered = NO;
    self.dialerNumberField.editable = YES;
    self.dialerNumberField.selectable = YES;
    self.dialerNumberField.target = self;
    self.dialerNumberField.action = @selector(dialerCallClicked:);
    self.dialerNumberField.focusRingType = NSFocusRingTypeNone;
    [dialerCard addSubview:self.dialerNumberField];

    // Backspace Glass Button
    NSButton *btnBackspace = [MCGlassButton pillButtonWithTitle:@"⌫" bgAlpha:0.12 tintColor:[NSColor whiteColor] target:self action:@selector(dialerBackspaceClicked:)];
    btnBackspace.frame = NSMakeRect(276, 14, 44, 36);
    btnBackspace.font = [NSFont systemFontOfSize:17 weight:NSFontWeightBold];
    [dialerCard addSubview:btnBackspace];

    // 1px Glass Divider under Number Field
    NSBox *numDivider = [[NSBox alloc] initWithFrame:NSMakeRect(24, 56, 292, 1)];
    numDivider.boxType = NSBoxCustom;
    numDivider.borderWidth = 0;
    numDivider.fillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.15];
    [dialerCard addSubview:numDivider];

    // 3x4 CIRCULAR GLASS BUTTONS GRID (iPhone / FaceTime Dialpad Layout)
    NSArray *keypadData = @[
        @{@"num": @"1", @"sub": @""},
        @{@"num": @"2", @"sub": @"ABC"},
        @{@"num": @"3", @"sub": @"DEF"},
        @{@"num": @"4", @"sub": @"GHI"},
        @{@"num": @"5", @"sub": @"JKL"},
        @{@"num": @"6", @"sub": @"MNO"},
        @{@"num": @"7", @"sub": @"PQRS"},
        @{@"num": @"8", @"sub": @"TUV"},
        @{@"num": @"9", @"sub": @"WXYZ"},
        @{@"num": @"*", @"sub": @""},
        @{@"num": @"0", @"sub": @"+"},
        @{@"num": @"#", @"sub": @""}
    ];

    CGFloat btnDiameter = 62;
    CGFloat colGap = 22;
    CGFloat rowGap = 8;
    CGFloat startX = (340 - (3 * btnDiameter + 2 * colGap)) / 2; // Perfectly centered (55px)
    CGFloat startY = 68;

    for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 3; c++) {
            int idx = r * 3 + c;
            NSDictionary *data = keypadData[idx];
            NSString *digit = data[@"num"];
            NSString *sub = data[@"sub"];

            MCGlassButton *circleBtn = [MCGlassButton circularDialButtonWithDigit:digit
                                                                          subtext:sub
                                                                           target:self
                                                                           action:@selector(dialerDigitClicked:)];
            circleBtn.frame = NSMakeRect(startX + (c * (btnDiameter + colGap)), startY + (r * (btnDiameter + rowGap)), btnDiameter, btnDiameter);
            [dialerCard addSubview:circleBtn];
        }
    }

    // Centered Circular Apple Green Call Action Button below 0 (Row 5 at y = 350)
    MCGlassButton *btnCall = [MCGlassButton callActionButtonWithTarget:self action:@selector(dialerCallClicked:)];
    btnCall.frame = NSMakeRect(startX + (1 * (btnDiameter + colGap)), startY + (4 * (btnDiameter + rowGap)) + 4, btnDiameter, btnDiameter);
    [dialerCard addSubview:btnCall];

    // 3. Right: Son Aramalar (Recent Calls Glass Card)
    CGFloat recentX = pad + 340 + 18;
    CGFloat recentW = self.callsView.bounds.size.width - recentX - pad;
    MCGlassCardView *recentCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(recentX, lowerY, recentW, lowerH)];
    recentCard.autoresizingMask = NSViewWidthSizable;
    [self.callsView addSubview:recentCard];

    NSTextField *recentHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 18, recentW - 36, 22)];
    recentHeader.stringValue = @"Son Aramalar";
    recentHeader.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    recentHeader.textColor = [NSColor whiteColor];
    recentHeader.editable = NO;
    recentHeader.bordered = NO;
    recentHeader.backgroundColor = [NSColor clearColor];
    [recentCard addSubview:recentHeader];

    self.recentCallsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(14, 52, recentW - 28, lowerH - 68)];
    self.recentCallsScrollView.hasVerticalScroller = YES;
    self.recentCallsScrollView.drawsBackground = NO;
    self.recentCallsScrollView.autoresizingMask = NSViewWidthSizable;
    [recentCard addSubview:self.recentCallsScrollView];

    self.recentCallsDocView = [[MCFlippedView alloc] initWithFrame:NSMakeRect(0, 0, recentW - 28, 100)];
    self.recentCallsDocView.autoresizingMask = NSViewWidthSizable;
    self.recentCallsScrollView.documentView = self.recentCallsDocView;

    [self rebuildRecentCallsStack];
}

#pragma mark - Tab 2: 🔔 Bildirimler (Notification Center Glass Feed & Full Detail)

- (void)buildNotificationsTab {
    self.notificationsView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 180, 28)];
    tabTitle.stringValue = @"Bildirimler";
    tabTitle.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor whiteColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.notificationsView addSubview:tabTitle];

    self.notificationsCountBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(150, 52, 80, 22)];
    self.notificationsCountBadge.stringValue = @"(0)";
    self.notificationsCountBadge.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    self.notificationsCountBadge.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    self.notificationsCountBadge.editable = NO;
    self.notificationsCountBadge.bordered = NO;
    self.notificationsCountBadge.backgroundColor = [NSColor clearColor];
    [self.notificationsView addSubview:self.notificationsCountBadge];

    NSButton *btnClear = [MCGlassButton pillButtonWithTitle:@"Tümünü Temizle" bgAlpha:0.12 tintColor:[NSColor whiteColor] target:self action:@selector(clearAllNotificationsClicked:)];
    btnClear.frame = NSMakeRect(self.notificationsView.bounds.size.width - 160, 48, 136, 30);
    btnClear.autoresizingMask = NSViewMinXMargin;
    [self.notificationsView addSubview:btnClear];

    // Scrollable Feed
    CGFloat listY = 92;
    CGFloat listH = self.notificationsView.bounds.size.height - listY - 20;
    self.notificationsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(pad, listY, self.notificationsView.bounds.size.width - (pad * 2), listH)];
    self.notificationsScrollView.hasVerticalScroller = YES;
    self.notificationsScrollView.drawsBackground = NO;
    self.notificationsScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.notificationsView addSubview:self.notificationsScrollView];

    self.notificationsDocView = [[MCFlippedView alloc] initWithFrame:NSMakeRect(0, 0, self.notificationsScrollView.bounds.size.width, 100)];
    self.notificationsDocView.autoresizingMask = NSViewWidthSizable;
    self.notificationsScrollView.documentView = self.notificationsDocView;

    [self rebuildNotificationsStack];
}

#pragma mark - Tab 3: 🎵 Şimdi Çalıyor (Liquid Glass Control Center Music Widget)

- (void)buildMediaTab {
    self.mediaView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 300, 28)];
    tabTitle.stringValue = @"Şimdi Çalıyor (Medya)";
    tabTitle.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor whiteColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.mediaView addSubview:tabTitle];

    CGFloat cardW = self.mediaView.bounds.size.width - (pad * 2);
    CGFloat cardH = 220;
    self.mediaHeroCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 92, cardW, cardH)];
    self.mediaHeroCard.autoresizingMask = NSViewWidthSizable;
    [self.mediaView addSubview:self.mediaHeroCard];

    // Glowing Vinyl / Album Art Box
    NSBox *artBox = [[NSBox alloc] initWithFrame:NSMakeRect(28, 30, 100, 100)];
    artBox.boxType = NSBoxCustom;
    artBox.cornerRadius = 16;
    artBox.borderWidth = 1.0;
    artBox.borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.25];
    artBox.fillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.12];
    [self.mediaHeroCard addSubview:artBox];

    NSTextField *artIcon = [[NSTextField alloc] initWithFrame:artBox.bounds];
    artIcon.stringValue = @"🎵";
    artIcon.font = [NSFont systemFontOfSize:46];
    artIcon.alignment = NSTextAlignmentCenter;
    artIcon.editable = NO;
    artIcon.bordered = NO;
    artIcon.backgroundColor = [NSColor clearColor];
    [artBox addSubview:artIcon];

    self.mediaAppBadgeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(148, 26, 250, 20)];
    self.mediaAppBadgeLabel.stringValue = @"Spotify / Deezer";
    self.mediaAppBadgeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    self.mediaAppBadgeLabel.textColor = [NSColor systemGreenColor];
    self.mediaAppBadgeLabel.editable = NO;
    self.mediaAppBadgeLabel.bordered = NO;
    self.mediaAppBadgeLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaAppBadgeLabel];

    self.mediaTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(148, 54, cardW - 170, 34)];
    self.mediaTitleLabel.stringValue = @"Şu anda çalan müzik yok";
    self.mediaTitleLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    self.mediaTitleLabel.textColor = [NSColor whiteColor];
    self.mediaTitleLabel.editable = NO;
    self.mediaTitleLabel.bordered = NO;
    self.mediaTitleLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaTitleLabel];

    self.mediaArtistLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(148, 92, cardW - 170, 22)];
    self.mediaArtistLabel.stringValue = @"Telefonda Spotify veya Deezer açtığınızda parça bilgisi burada belirecektir.";
    self.mediaArtistLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.mediaArtistLabel.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    self.mediaArtistLabel.editable = NO;
    self.mediaArtistLabel.bordered = NO;
    self.mediaArtistLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaArtistLabel];

    self.mediaStatusBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(148, 148, 130, 24)];
    self.mediaStatusBadge.stringValue = @"▶ Oynatılıyor";
    self.mediaStatusBadge.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    self.mediaStatusBadge.textColor = [NSColor systemGreenColor];
    self.mediaStatusBadge.editable = NO;
    self.mediaStatusBadge.bordered = NO;
    self.mediaStatusBadge.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaStatusBadge];

    // Info Glass Card
    MCGlassCardView *infoCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 332, cardW, 84)];
    infoCard.autoresizingMask = NSViewWidthSizable;
    [self.mediaView addSubview:infoCard];

    NSTextField *infoNote = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 14, cardW - 40, 56)];
    infoNote.stringValue = @"💡 Akıllı Medya Bildirim Filtresi:\nSpotify, Deezer ve YouTube Music gibi uygulamaların sürekli değişen şarkı bildirimleri Mac masaüstünüzü spamlamaz. Parça geçişleri sessizce bu ekranda toplanır.";
    infoNote.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    infoNote.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    infoNote.editable = NO;
    infoNote.bordered = NO;
    infoNote.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:infoNote];
}

#pragma mark - Tab 4: 📋 Cihaz & Pano

- (void)buildDeviceTab {
    self.deviceView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 380, 28)];
    tabTitle.stringValue = @"Cihaz & Evrensel Pano";
    tabTitle.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor whiteColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.deviceView addSubview:tabTitle];

    CGFloat cardW = self.deviceView.bounds.size.width - (pad * 2);

    // 1. Hardware Info Glass Card
    MCGlassCardView *infoCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 92, cardW, 104)];
    infoCard.autoresizingMask = NSViewWidthSizable;
    [self.deviceView addSubview:infoCard];

    self.deviceModelLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 16, cardW - 40, 22)];
    self.deviceModelLabel.stringValue = @"Cihaz: Telefon Bekleniyor...";
    self.deviceModelLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    self.deviceModelLabel.textColor = [NSColor whiteColor];
    self.deviceModelLabel.editable = NO;
    self.deviceModelLabel.bordered = NO;
    self.deviceModelLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceModelLabel];

    self.deviceStatusFullLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 42, cardW - 40, 18)];
    self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (Bağlantı Yok)";
    self.deviceStatusFullLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.deviceStatusFullLabel.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    self.deviceStatusFullLabel.editable = NO;
    self.deviceStatusFullLabel.bordered = NO;
    self.deviceStatusFullLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceStatusFullLabel];

    self.deviceBatteryFullLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 64, cardW - 40, 18)];
    self.deviceBatteryFullLabel.stringValue = @"Pil Durumu: --";
    self.deviceBatteryFullLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.deviceBatteryFullLabel.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    self.deviceBatteryFullLabel.editable = NO;
    self.deviceBatteryFullLabel.bordered = NO;
    self.deviceBatteryFullLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceBatteryFullLabel];

    // 2. Universal Continuity Clipboard Status Hero Card
    MCGlassCardView *clipHeroCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 208, cardW, 90)];
    clipHeroCard.glassCornerRadius = 14;
    clipHeroCard.glassFillColor = [NSColor colorWithCalibratedRed:0.0 green:0.45 blue:0.25 alpha:0.22];
    clipHeroCard.glassStrokeColor = [NSColor colorWithCalibratedRed:0.2 green:0.8 blue:0.45 alpha:0.45];
    clipHeroCard.autoresizingMask = NSViewWidthSizable;
    [self.deviceView addSubview:clipHeroCard];

    NSTextField *clipBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 14, cardW - 36, 22)];
    clipBadge.stringValue = @"🟢 Çift Yönlü Otomatik Pano Aktif (Universal Continuity Clipboard)";
    clipBadge.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    clipBadge.textColor = [NSColor colorWithCalibratedRed:0.4 green:0.95 blue:0.6 alpha:1.0];
    clipBadge.editable = NO;
    clipBadge.bordered = NO;
    clipBadge.backgroundColor = [NSColor clearColor];
    [clipHeroCard addSubview:clipBadge];

    NSTextField *clipDesc = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 38, cardW - 36, 44)];
    clipDesc.stringValue = @"Mac'te Cmd+C ile kopyaladığınız her metin anında telefonun panosuna geçer.\nTelefonda kopyaladığınız her metin anında Mac panosuna aktarılır. Herhangi bir butona basmanız gerekmez.";
    clipDesc.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightRegular];
    clipDesc.textColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    clipDesc.editable = NO;
    clipDesc.bordered = NO;
    clipDesc.backgroundColor = [NSColor clearColor];
    [clipHeroCard addSubview:clipDesc];

    // 3. Received Clipboard Glass Card
    MCGlassCardView *recvCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 310, cardW, 140)];
    recvCard.autoresizingMask = NSViewWidthSizable;
    [self.deviceView addSubview:recvCard];

    NSTextField *recvTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 12, cardW - 36, 20)];
    recvTitle.stringValue = @"📋 Telefondan Otomatik Alınan Son Pano İçeriği";
    recvTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    recvTitle.textColor = [NSColor whiteColor];
    recvTitle.editable = NO;
    recvTitle.bordered = NO;
    recvTitle.backgroundColor = [NSColor clearColor];
    [recvCard addSubview:recvTitle];

    NSScrollView *recvScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(18, 36, cardW - 36, 90)];
    recvScroll.hasVerticalScroller = YES;
    recvScroll.drawsBackground = NO;
    recvScroll.autoresizingMask = NSViewWidthSizable;
    self.receivedClipboardTextView = [[NSTextView alloc] initWithFrame:recvScroll.bounds];
    self.receivedClipboardTextView.editable = NO;
    self.receivedClipboardTextView.font = [NSFont systemFontOfSize:13];
    self.receivedClipboardTextView.textColor = [NSColor whiteColor];
    self.receivedClipboardTextView.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.04];
    recvScroll.documentView = self.receivedClipboardTextView;
    [recvCard addSubview:recvScroll];

    // 4. Send Clipboard Glass Card (Manual Test / Send)
    MCGlassCardView *sendCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 462, cardW, 150)];
    sendCard.autoresizingMask = NSViewWidthSizable;
    [self.deviceView addSubview:sendCard];

    NSTextField *sendTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 12, cardW - 36, 20)];
    sendTitle.stringValue = @"Telefona Manuel Metin Gönder";
    sendTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    sendTitle.textColor = [NSColor whiteColor];
    sendTitle.editable = NO;
    sendTitle.bordered = NO;
    sendTitle.backgroundColor = [NSColor clearColor];
    [sendCard addSubview:sendTitle];

    NSScrollView *sendScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(18, 36, cardW - 36, 64)];
    sendScroll.hasVerticalScroller = YES;
    sendScroll.drawsBackground = NO;
    sendScroll.autoresizingMask = NSViewWidthSizable;
    self.sendClipboardTextView = [[NSTextView alloc] initWithFrame:sendScroll.bounds];
    self.sendClipboardTextView.font = [NSFont systemFontOfSize:13];
    self.sendClipboardTextView.textColor = [NSColor whiteColor];
    self.sendClipboardTextView.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.04];
    sendScroll.documentView = self.sendClipboardTextView;
    [sendCard addSubview:sendScroll];

    NSButton *btnSendClip = [MCGlassButton pillButtonWithTitle:@"Telefona Gönder" bgAlpha:0.25 tintColor:[NSColor systemBlueColor] target:self action:@selector(sendClipboardClicked:)];
    btnSendClip.frame = NSMakeRect(18, 108, 150, 30);
    [sendCard addSubview:btnSendClip];
}

#pragma mark - Tab 5: 🖥️ Ekran Yansıtma (Screen Mirroring)

- (void)buildScreenMirroringTab {
    self.mirrorView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 450, 28)];
    tabTitle.stringValue = @"Ekran Yansıtma (Screen Mirroring)";
    tabTitle.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor whiteColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.mirrorView addSubview:tabTitle];

    CGFloat cardW = self.mirrorView.bounds.size.width - (pad * 2);

    // Hero Info Card
    MCGlassCardView *heroCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 92, cardW, 116)];
    heroCard.autoresizingMask = NSViewWidthSizable;
    [self.mirrorView addSubview:heroCard];

    NSImageView *screenIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(20, 20, 48, 48)];
    if (@available(macOS 11.0, *)) {
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:30 weight:NSFontWeightMedium];
        screenIcon.image = [[NSImage imageWithSystemSymbolName:@"display" accessibilityDescription:nil] imageWithSymbolConfiguration:cfg];
        screenIcon.contentTintColor = [NSColor colorWithCalibratedRed:0.2 green:0.75 blue:1.0 alpha:1.0];
    }
    [heroCard addSubview:screenIcon];

    self.mirrorStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 18, cardW - 100, 24)];
    self.mirrorStatusLabel.stringValue = @"Telefon Ekranını Mac'te Yönetin (Ultra Akıcı 60 FPS)";
    self.mirrorStatusLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
    self.mirrorStatusLabel.textColor = [NSColor whiteColor];
    self.mirrorStatusLabel.editable = NO;
    self.mirrorStatusLabel.bordered = NO;
    self.mirrorStatusLabel.backgroundColor = [NSColor clearColor];
    [heroCard addSubview:self.mirrorStatusLabel];

    NSTextField *subDesc = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 44, cardW - 100, 38)];
    subDesc.stringValue = @"Scrcpy ve ADB motoru ile telefonunuzun dokunmatik ekranını klavye & farenizle kontrol edin. Ses ve görüntü sıfır gecikmeyle aktarılır.";
    subDesc.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    subDesc.textColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    subDesc.editable = NO;
    subDesc.bordered = NO;
    subDesc.backgroundColor = [NSColor clearColor];
    [heroCard addSubview:subDesc];

    // Connection Control Card
    MCGlassCardView *controlCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 224, cardW, 230)];
    controlCard.autoresizingMask = NSViewWidthSizable;
    [self.mirrorView addSubview:controlCard];

    NSTextField *cardHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 14, cardW - 40, 20)];
    cardHeader.stringValue = @"Yansıtma Yöntemi Seçin";
    cardHeader.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    cardHeader.textColor = [NSColor whiteColor];
    cardHeader.editable = NO;
    cardHeader.bordered = NO;
    cardHeader.backgroundColor = [NSColor clearColor];
    [controlCard addSubview:cardHeader];

    // IP Field
    NSTextField *ipTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 46, 120, 20)];
    ipTitle.stringValue = @"Telefon Wi-Fi IP:";
    ipTitle.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    ipTitle.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    ipTitle.editable = NO;
    ipTitle.bordered = NO;
    ipTitle.backgroundColor = [NSColor clearColor];
    [controlCard addSubview:ipTitle];

    self.mirrorIpField = [[NSTextField alloc] initWithFrame:NSMakeRect(140, 44, 180, 24)];
    self.mirrorIpField.placeholderString = @"192.168.1.xxx";
    self.mirrorIpField.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.mirrorIpField.stringValue = [BluetoothBridge sharedBridge].deviceIpAddress ?: @"";
    [controlCard addSubview:self.mirrorIpField];

    // Buttons
    // 1. Wireless Mirror button
    self.btnLaunchWirelessMirror = [MCGlassButton pillButtonWithTitle:@"🚀 Kablosuz Ekranı Başlat (Wi-Fi)" bgAlpha:0.35 tintColor:[NSColor colorWithCalibratedRed:0.18 green:0.80 blue:0.44 alpha:1.0] target:self action:@selector(launchWirelessMirrorClicked:)];
    self.btnLaunchWirelessMirror.frame = NSMakeRect(20, 84, 250, 36);
    [controlCard addSubview:self.btnLaunchWirelessMirror];

    // 2. USB Mirror button
    self.btnLaunchUsbMirror = [MCGlassButton pillButtonWithTitle:@"🔌 Kablolu USB Ekranı Başlat" bgAlpha:0.25 tintColor:[NSColor systemBlueColor] target:self action:@selector(launchUsbMirrorClicked:)];
    self.btnLaunchUsbMirror.frame = NSMakeRect(280, 84, 210, 36);
    [controlCard addSubview:self.btnLaunchUsbMirror];

    // 3. ADB TCP/IP button
    self.btnAdbTcpip = [MCGlassButton pillButtonWithTitle:@"📡 Kablosuz ADB Modunu Aç (Port 5555)" bgAlpha:0.18 tintColor:[NSColor systemOrangeColor] target:self action:@selector(enableAdbTcpipClicked:)];
    self.btnAdbTcpip.frame = NSMakeRect(20, 130, 270, 32);
    [controlCard addSubview:self.btnAdbTcpip];

    // 4. Install / Check scrcpy button
    self.btnInstallScrcpy = [MCGlassButton pillButtonWithTitle:@"⚙️ scrcpy Kur / Güncelle" bgAlpha:0.15 tintColor:[NSColor whiteColor] target:self action:@selector(installScrcpyClicked:)];
    self.btnInstallScrcpy.frame = NSMakeRect(300, 130, 200, 32);
    [controlCard addSubview:self.btnInstallScrcpy];

    // Status / Console Label
    self.mirrorLogLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 176, cardW - 40, 42)];
    self.mirrorLogLabel.stringValue = MCFindScrcpyPath() ? [NSString stringWithFormat:@"✓ scrcpy kurulu: %@", MCFindScrcpyPath()] : @"⚠️ scrcpy bulunamadı. Kurulum için sağdaki butona tıklayın (brew install scrcpy).";
    self.mirrorLogLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    self.mirrorLogLabel.textColor = MCFindScrcpyPath() ? [NSColor colorWithCalibratedRed:0.4 green:0.9 blue:0.5 alpha:1.0] : [NSColor systemYellowColor];
    self.mirrorLogLabel.editable = NO;
    self.mirrorLogLabel.bordered = NO;
    self.mirrorLogLabel.backgroundColor = [NSColor clearColor];
    [controlCard addSubview:self.mirrorLogLabel];

    // Instructions Card
    MCGlassCardView *guideCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 468, cardW, 140)];
    guideCard.autoresizingMask = NSViewWidthSizable;
    [self.mirrorView addSubview:guideCard];

    NSTextField *guideTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 12, cardW - 40, 20)];
    guideTitle.stringValue = @"Nasıl Kullanılır?";
    guideTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    guideTitle.textColor = [NSColor whiteColor];
    guideTitle.editable = NO;
    guideTitle.bordered = NO;
    guideTitle.backgroundColor = [NSColor clearColor];
    [guideCard addSubview:guideTitle];

    NSTextField *guideText = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 36, cardW - 40, 94)];
    guideText.stringValue = @"1. Telefonda 'Geliştirici Seçenekleri' -> 'USB Hata Ayıklama' açık olmalıdır.\n2. Kablosuz Yansıtma için: Telefonu bir kez USB ile bağlayıp 'Kablosuz ADB Modunu Aç'a basın.\n3. Ardından USB kablosunu çıkarabilirsiniz. 'Kablosuz Ekranı Başlat'a basarak anında bağlanabilirsiniz!\n4. Görüntü ultra akıcı 60 FPS ayrı pencerede açılır; klavye ve farenizle kontrol edebilirsiniz.";
    guideText.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    guideText.textColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    guideText.editable = NO;
    guideText.bordered = NO;
    guideText.backgroundColor = [NSColor clearColor];
    [guideCard addSubview:guideText];
}

#pragma mark - Screen Mirroring Actions

- (void)launchWirelessMirrorClicked:(id)sender {
    NSString *ip = [self.mirrorIpField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (ip.length == 0) {
        ip = [BluetoothBridge sharedBridge].deviceIpAddress;
    }
    if (ip.length == 0) {
        self.mirrorLogLabel.stringValue = @"⚠️ Telefon Wi-Fi IP adresi bulunamadı. Lütfen telefonun IP adresini girin.";
        return;
    }

    NSString *scrcpy = MCFindScrcpyPath();
    if (!scrcpy) {
        [self installScrcpyClicked:nil];
        return;
    }

    NSString *adb = MCFindAdbPath();
    self.mirrorLogLabel.stringValue = [NSString stringWithFormat:@"Kablosuz ADB bağlanıyor: %@:5555 ...", ip];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 1. adb connect <IP>:5555
        NSTask *adbTask = [[NSTask alloc] init];
        adbTask.launchPath = adb;
        adbTask.arguments = @[@"connect", [NSString stringWithFormat:@"%@:5555", ip]];
        [adbTask launch];
        [adbTask waitUntilExit];

        // 2. Launch scrcpy --tcpip=<IP>:5555
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mirrorLogLabel.stringValue = [NSString stringWithFormat:@"🚀 Ekran yansıtma başlatıldı: %@:5555", ip];
        });

        NSTask *scrcpyTask = [[NSTask alloc] init];
        scrcpyTask.launchPath = scrcpy;
        scrcpyTask.arguments = @[
            [NSString stringWithFormat:@"--tcpip=%@:5555", ip],
            @"--window-title=MacConnect - Telefon Ekranı",
            @"--stay-awake",
            @"--max-fps=60"
        ];
        NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
        NSString *adbDir = [adb stringByDeletingLastPathComponent];
        env[@"PATH"] = [NSString stringWithFormat:@"%@:/opt/homebrew/bin:/usr/local/bin:%@", adbDir, env[@"PATH"] ?: @""];
        env[@"ADB"] = adb;
        scrcpyTask.environment = env;
        @try {
            [scrcpyTask launch];
        } @catch (NSException *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.mirrorLogLabel.stringValue = [NSString stringWithFormat:@"Hata: %@", e.reason];
            });
        }
    });
}

- (void)launchUsbMirrorClicked:(id)sender {
    NSString *scrcpy = MCFindScrcpyPath();
    if (!scrcpy) {
        [self installScrcpyClicked:nil];
        return;
    }
    NSString *adb = MCFindAdbPath();
    self.mirrorLogLabel.stringValue = @"🔌 USB Ekran yansıtma başlatılıyor...";

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *scrcpyTask = [[NSTask alloc] init];
        scrcpyTask.launchPath = scrcpy;
        scrcpyTask.arguments = @[
            @"--window-title=MacConnect - Telefon Ekranı (USB)",
            @"--stay-awake",
            @"--max-fps=60"
        ];
        NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
        NSString *adbDir = [adb stringByDeletingLastPathComponent];
        env[@"PATH"] = [NSString stringWithFormat:@"%@:/opt/homebrew/bin:/usr/local/bin:%@", adbDir, env[@"PATH"] ?: @""];
        env[@"ADB"] = adb;
        scrcpyTask.environment = env;
        @try {
            [scrcpyTask launch];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.mirrorLogLabel.stringValue = @"🚀 USB Ekran yansıtma devrede!";
            });
        } @catch (NSException *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.mirrorLogLabel.stringValue = [NSString stringWithFormat:@"Hata: %@", e.reason];
            });
        }
    });
}

- (void)enableAdbTcpipClicked:(id)sender {
    NSString *adb = MCFindAdbPath();
    self.mirrorLogLabel.stringValue = @"📡 'adb tcpip 5555' komutu çalıştırılıyor...";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = adb;
        task.arguments = @[@"tcpip", @"5555"];
        [task launch];
        [task waitUntilExit];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mirrorLogLabel.stringValue = @"✓ Telefon kablosuz ADB (5555) moduna alındı. Artık USB kablosunu çıkarıp kablosuz bağlanabilirsiniz!";
        });
    });
}

- (void)installScrcpyClicked:(id)sender {
    NSString *brewPath = @"/opt/homebrew/bin/brew";
    if (![[NSFileManager defaultManager] fileExistsAtPath:brewPath]) {
        brewPath = @"/usr/local/bin/brew";
    }
    NSString *cmd = [NSString stringWithFormat:@"%@ install scrcpy android-platform-tools", brewPath];
    NSString *script = [NSString stringWithFormat:@"tell application \"Terminal\" to do script \"%@\"", cmd];
    NSAppleScript *as = [[NSAppleScript alloc] initWithSource:script];
    [as executeAndReturnError:nil];
    self.mirrorLogLabel.stringValue = @"Terminal açılarak 'brew install scrcpy' başlatıldı. Kurulum tamamlandığında ekran yansıtmayı kullanabilirsiniz.";
}

#pragma mark - Tab 5: ⚙️ Ayarlar

- (void)buildSettingsTab {
    self.settingsView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 300, 28)];
    tabTitle.stringValue = @"Ayarlar ve Tercihler";
    tabTitle.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor whiteColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.settingsView addSubview:tabTitle];

    CGFloat cardW = self.settingsView.bounds.size.width - (pad * 2);

    MCGlassCardView *optionsCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 92, cardW, 150)];
    optionsCard.autoresizingMask = NSViewWidthSizable;
    [self.settingsView addSubview:optionsCard];

    self.checkFilterMedia = [NSButton checkboxWithTitle:@"Müzik çalar bildirimlerini sessize al ve filtrele (Spotify, Deezer vb.)" target:nil action:nil];
    self.checkFilterMedia.frame = NSMakeRect(20, 18, cardW - 40, 24);
    self.checkFilterMedia.state = NSControlStateValueOn;
    self.checkFilterMedia.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [optionsCard addSubview:self.checkFilterMedia];

    self.checkAutoRaiseOnCall = [NSButton checkboxWithTitle:@"Gelen arama olduğunda MacConnect penceresini otomatik öne getir" target:nil action:nil];
    self.checkAutoRaiseOnCall.frame = NSMakeRect(20, 60, cardW - 40, 24);
    self.checkAutoRaiseOnCall.state = NSControlStateValueOn;
    self.checkAutoRaiseOnCall.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [optionsCard addSubview:self.checkAutoRaiseOnCall];

    self.checkPlaySound = [NSButton checkboxWithTitle:@"Bildirim geldiğinde yerel sistem sesini çal" target:nil action:nil];
    self.checkPlaySound.frame = NSMakeRect(20, 102, cardW - 40, 24);
    self.checkPlaySound.state = NSControlStateValueOn;
    self.checkPlaySound.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [optionsCard addSubview:self.checkPlaySound];

    MCGlassCardView *aboutCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(pad, 258, cardW, 84)];
    aboutCard.autoresizingMask = NSViewWidthSizable;
    [self.settingsView addSubview:aboutCard];

    NSTextField *aboutBox = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 16, cardW - 40, 52)];
    aboutBox.stringValue = @"MacConnect v1.0.2 • Native macOS Liquid Glass Edition\nDoğrudan donanım seviyesinde Bluetooth RFCOMM köprüsü ile telefon ve Mac senkronizasyonu.\nGeliştirici: canmertdogan";
    aboutBox.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    aboutBox.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    aboutBox.editable = NO;
    aboutBox.bordered = NO;
    aboutBox.backgroundColor = [NSColor clearColor];
    [aboutCard addSubview:aboutBox];
}

#pragma mark - Call Actions

- (void)actionAnswerClicked:(id)sender {
    [[BluetoothBridge sharedBridge] sendCallAction:@"answer"];
    self.callHeroTitleLabel.stringValue = @"Görüşme Açıldı (Telefonda)";
}

- (void)actionAnswerSpeakerClicked:(id)sender {
    [[BluetoothBridge sharedBridge] sendCallAction:@"answer_speaker"];
    self.callHeroTitleLabel.stringValue = @"🔊 Hoparlör Açık (Eller Serbest)";
    self.callHeroSubtitleLabel.stringValue = @"Telefon hoparlörü devrede. Masadan konuşabilirsiniz.";
}

- (void)actionTransferComputerClicked:(id)sender {
    [[BluetoothBridge sharedBridge] sendCallAction:@"transfer_computer"];
    self.callHeroTitleLabel.stringValue = @"💻 Bilgisayar Masası Modunda";
    self.callHeroSubtitleLabel.stringValue = @"Telefon eller serbest iletişim moduna alındı. Görüşmeyi masanızdan sürdürebilirsiniz.";
}

- (void)actionRejectClicked:(id)sender {
    [[BluetoothBridge sharedBridge] sendCallAction:@"reject"];
    [self dismissIncomingCall];
}

- (void)appendDigitToDialer:(NSString *)digit {
    if (!digit || digit.length == 0) return;
    NSString *curr = self.dialerNumberField.stringValue ?: @"";
    self.dialerNumberField.stringValue = [curr stringByAppendingString:digit];
}

- (void)dialerDigitClicked:(MCGlassButton *)sender {
    NSString *digit = sender.customIdentifier ?: @"";
    [self appendDigitToDialer:digit];
}

- (void)dialerBackspaceClicked:(id)sender {
    NSString *curr = self.dialerNumberField.stringValue ?: @"";
    if (curr.length > 0) {
        self.dialerNumberField.stringValue = [curr substringToIndex:curr.length - 1];
    }
}

- (void)dialerCallClicked:(id)sender {
    NSString *number = [self.dialerNumberField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (number.length == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Numara Girilmedi";
        alert.informativeText = @"Lütfen aramak istediğiniz telefon numarasını tuşlayın.";
        [alert runModal];
        return;
    }

    BluetoothBridge *bridge = [BluetoothBridge sharedBridge];
    if (bridge.state != MacConnectStateConnected) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleWarning;
        alert.messageText = @"Telefon Bağlı Değil";
        alert.informativeText = @"Arama yapabilmek için telefonunuzun Bluetooth ile bağlı olması gerekir. Lütfen sol menüdeki 'Telefona Bağlan' butonuna tıklayarak telefonunuza bağlanın.";
        [alert runModal];
        return;
    }

    [bridge dialPhoneNumber:number];
    NSLog(@"[Dialer] Sent dial command to phone: %@", number);

    NSDictionary *entry = @{
        @"name": number,
        @"number": number,
        @"time": @"Az önce (Giden Arama)"
    };
    [self.recentCalls insertObject:entry atIndex:0];
    [self rebuildRecentCallsStack];

    self.callHeroCard.glassFillColor = [NSColor colorWithCalibratedRed:0.10 green:0.35 blue:0.18 alpha:0.4];
    self.callHeroCard.glassStrokeColor = [NSColor colorWithCalibratedRed:0.18 green:0.80 blue:0.44 alpha:0.6];
    if (@available(macOS 11.0, *)) {
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightMedium];
        self.callHeroAvatarImageView.image = [[NSImage imageWithSystemSymbolName:@"phone.arrow.up.right.fill" accessibilityDescription:nil] imageWithSymbolConfiguration:cfg];
        self.callHeroAvatarImageView.contentTintColor = [NSColor colorWithCalibratedRed:0.25 green:0.90 blue:0.45 alpha:1.0];
    }
    self.callHeroTitleLabel.stringValue = [NSString stringWithFormat:@"Aranıyor: %@", number];
    self.callHeroSubtitleLabel.stringValue = @"Arama komutu telefona iletildi. Telefonunuz aramayı başlatıyor...";
    self.callHeroButtonStack.hidden = NO;
    self.btnAnswerCall.hidden = YES;
    self.btnAnswerSpeakerCall.hidden = YES;
    self.btnTransferComputerCall.hidden = YES;
    self.btnRejectCall.hidden = NO;
}

- (void)rebuildRecentCallsStack {
    for (NSView *v in self.recentCallsDocView.subviews) {
        [v removeFromSuperview];
    }

    CGFloat w = self.recentCallsDocView.bounds.size.width;

    if (self.recentCalls.count == 0) {
        NSTextField *emptyLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 90, w - 40, 70)];
        emptyLbl.stringValue = @"📞\nHenüz son arama kaydı yok\nTuş takımından numara arayabilir veya gelen aramaları masanızdan yanıtlayabilirsiniz.";
        emptyLbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
        emptyLbl.textColor = [NSColor colorWithCalibratedWhite:0.55 alpha:1.0];
        emptyLbl.alignment = NSTextAlignmentCenter;
        emptyLbl.editable = NO;
        emptyLbl.bordered = NO;
        emptyLbl.backgroundColor = [NSColor clearColor];
        emptyLbl.autoresizingMask = NSViewWidthSizable;
        [self.recentCallsDocView addSubview:emptyLbl];
        return;
    }

    CGFloat itemH = 50;
    CGFloat gap = 8;
    CGFloat y = 0;

    for (NSDictionary *call in self.recentCalls) {
        MCGlassCardView *itemBox = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(0, y, w, itemH)];
        itemBox.glassCornerRadius = 10;
        itemBox.autoresizingMask = NSViewWidthSizable;

        NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 8, w - 90, 18)];
        lbl.stringValue = call[@"name"] ?: call[@"number"];
        lbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
        lbl.textColor = [NSColor whiteColor];
        lbl.editable = NO;
        lbl.bordered = NO;
        lbl.backgroundColor = [NSColor clearColor];
        [itemBox addSubview:lbl];

        NSTextField *sub = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 26, w - 90, 16)];
        sub.stringValue = call[@"time"] ?: @"";
        sub.font = [NSFont systemFontOfSize:11];
        sub.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
        sub.editable = NO;
        sub.bordered = NO;
        sub.backgroundColor = [NSColor clearColor];
        [itemBox addSubview:sub];

        MCGlassButton *btnRedial = [MCGlassButton pillButtonWithTitle:@"Ara" bgAlpha:0.25 tintColor:[NSColor systemGreenColor] target:self action:@selector(redialClicked:)];
        btnRedial.frame = NSMakeRect(w - 74, 11, 60, 28);
        btnRedial.customIdentifier = call[@"number"];
        btnRedial.autoresizingMask = NSViewMinXMargin;
        [itemBox addSubview:btnRedial];

        [self.recentCallsDocView addSubview:itemBox];
        y += itemH + gap;
    }

    self.recentCallsDocView.frame = NSMakeRect(0, 0, w, MAX(y, self.recentCallsScrollView.bounds.size.height));
}

- (void)redialClicked:(MCGlassButton *)sender {
    NSString *num = sender.customIdentifier;
    if (num) {
        self.dialerNumberField.stringValue = num;
        [self dialerCallClicked:nil];
    }
}

#pragma mark - Public Bridge Callback Methods

- (void)showIncomingCall:(NSDictionary *)callInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.activeCallInfo = callInfo;
        NSString *name = callInfo[@"name"] ?: @"Bilinmeyen Arayan";
        NSString *number = callInfo[@"number"] ?: @"";
        NSString *appName = callInfo[@"app_name"] ?: @"Telefon";

        self.callHeroCard.glassFillColor = [NSColor colorWithCalibratedRed:0.45 green:0.12 blue:0.14 alpha:0.45];
        self.callHeroCard.glassStrokeColor = [NSColor colorWithCalibratedRed:0.95 green:0.27 blue:0.27 alpha:0.7];
        if (@available(macOS 11.0, *)) {
            NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightMedium];
            self.callHeroAvatarImageView.image = [[NSImage imageWithSystemSymbolName:@"phone.arrow.down.left.fill" accessibilityDescription:nil] imageWithSymbolConfiguration:cfg];
            self.callHeroAvatarImageView.contentTintColor = [NSColor colorWithCalibratedRed:1.0 green:0.35 blue:0.35 alpha:1.0];
        }
        self.callHeroTitleLabel.stringValue = [NSString stringWithFormat:@"Gelen Arama: %@", name];
        self.callHeroSubtitleLabel.stringValue = [NSString stringWithFormat:@"%@ • %@", number, appName];

        self.callHeroButtonStack.hidden = NO;
        self.btnAnswerCall.hidden = NO;
        self.btnAnswerSpeakerCall.hidden = NO;
        self.btnTransferComputerCall.hidden = NO;
        self.btnRejectCall.hidden = NO;

        if (self.checkAutoRaiseOnCall.state == NSControlStateValueOn) {
            [self showWindowAndActivate];
            [self selectTab:0];
        }
    });
}

- (void)dismissIncomingCall {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.activeCallInfo = nil;
        self.callHeroCard.glassFillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.07];
        self.callHeroCard.glassStrokeColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.18];
        if (@available(macOS 11.0, *)) {
            NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightMedium];
            self.callHeroAvatarImageView.image = [[NSImage imageWithSystemSymbolName:@"phone.fill" accessibilityDescription:nil] imageWithSymbolConfiguration:cfg];
            self.callHeroAvatarImageView.contentTintColor = [NSColor whiteColor];
        }
        self.callHeroTitleLabel.stringValue = @"Aktif Arama Yok";
        self.callHeroSubtitleLabel.stringValue = @"Tuş takımından numara arayabilir veya gelen aramaları masanızdan yanıtlayabilirsiniz.";
        self.callHeroButtonStack.hidden = YES;
    });
}

- (void)updateCallStatus:(NSString *)status message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([@"on_computer" isEqualToString:status]) {
            self.callHeroTitleLabel.stringValue = @"💻 Bilgisayar Masası Modunda";
            self.callHeroSubtitleLabel.stringValue = message ?: @"Hoparlör ve eller serbest iletişim devrede.";
        }
    });
}

- (void)addNotification:(NSDictionary *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.notificationsList insertObject:notification atIndex:0];
        if (self.notificationsList.count > 50) {
            [self.notificationsList removeLastObject];
        }
        self.notificationsCountBadge.stringValue = [NSString stringWithFormat:@"(%lu)", (unsigned long)self.notificationsList.count];
        [self rebuildNotificationsStack];
    });
}

- (void)rebuildNotificationsStack {
    for (NSView *v in self.notificationsDocView.subviews) {
        [v removeFromSuperview];
    }

    CGFloat w = self.notificationsDocView.bounds.size.width;

    if (self.notificationsList.count == 0) {
        NSTextField *emptyLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 100, w - 40, 60)];
        emptyLbl.stringValue = @"🔔\nHenüz bildirim yok\nTelefondan gelen bildirimler anında burada listelenir.";
        emptyLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        emptyLbl.textColor = [NSColor colorWithCalibratedWhite:0.55 alpha:1.0];
        emptyLbl.alignment = NSTextAlignmentCenter;
        emptyLbl.editable = NO;
        emptyLbl.bordered = NO;
        emptyLbl.backgroundColor = [NSColor clearColor];
        emptyLbl.autoresizingMask = NSViewWidthSizable;
        [self.notificationsDocView addSubview:emptyLbl];
        return;
    }

    CGFloat itemH = 76;
    CGFloat gap = 10;
    CGFloat y = 0;

    for (NSInteger i = 0; i < self.notificationsList.count; i++) {
        NSDictionary *n = self.notificationsList[i];
        NSString *pkg = n[@"package_name"] ?: @"";
        NSString *rawApp = n[@"app_name"] ?: @"";
        NSString *app = MCResolvePrettyAppName(rawApp, pkg);
        NSString *title = n[@"title"] ?: @"";
        NSString *text = n[@"text"] ?: @"";
        NSString *iconB64 = n[@"icon"];

        MCGlassCardView *card = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(0, y, w, itemH)];
        card.glassCornerRadius = 14;
        card.autoresizingMask = NSViewWidthSizable;

        // App Icon (Decoded or Styled Glyph)
        NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(14, 16, 44, 44)];
        iconView.wantsLayer = YES;
        iconView.layer.cornerRadius = 10;
        iconView.layer.masksToBounds = YES;
        iconView.imageScaling = NSImageScaleProportionallyUpOrDown;

        NSImage *appIconImg = MCDecodeBase64Icon(iconB64);
        if (appIconImg) {
            iconView.image = appIconImg;
        } else {
            // High-aesthetic fallback initial badge
            iconView.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:0.35].CGColor;
            iconView.layer.borderWidth = 1.0;
            iconView.layer.borderColor = [NSColor colorWithCalibratedRed:0.2 green:0.6 blue:1.0 alpha:0.5].CGColor;
            NSTextField *badgeLetter = [[NSTextField alloc] initWithFrame:iconView.bounds];
            badgeLetter.stringValue = (app.length > 0) ? [app substringToIndex:1] : @"🔔";
            badgeLetter.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
            badgeLetter.textColor = [NSColor whiteColor];
            badgeLetter.alignment = NSTextAlignmentCenter;
            badgeLetter.editable = NO;
            badgeLetter.bordered = NO;
            badgeLetter.backgroundColor = [NSColor clearColor];
            [iconView addSubview:badgeLetter];
        }
        [card addSubview:iconView];

        // Content Texts
        CGFloat textX = 68;
        CGFloat textW = w - textX - 160;

        NSTextField *appLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(textX, 8, textW, 16)];
        appLbl.stringValue = app;
        appLbl.font = [NSFont systemFontOfSize:11 weight:NSFontWeightBold];
        appLbl.textColor = [NSColor colorWithCalibratedRed:0.3 green:0.7 blue:1.0 alpha:1.0];
        appLbl.editable = NO;
        appLbl.bordered = NO;
        appLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:appLbl];

        NSTextField *titleLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(textX, 26, textW, 20)];
        titleLbl.stringValue = title;
        titleLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
        titleLbl.textColor = [NSColor whiteColor];
        titleLbl.editable = NO;
        titleLbl.bordered = NO;
        titleLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:titleLbl];

        NSTextField *textLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(textX, 48, textW, 18)];
        textLbl.stringValue = text;
        textLbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        textLbl.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
        textLbl.editable = NO;
        textLbl.bordered = NO;
        textLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:textLbl];

        BOOL canReply = [n[@"can_reply"] boolValue];
        if (!canReply && pkg && (
            [pkg containsString:@"whatsapp"] ||
            [pkg containsString:@"telegram"] ||
            [pkg containsString:@"messaging"] ||
            [pkg containsString:@"instagram"] ||
            [pkg containsString:@"signal"])) {
            canReply = YES;
        }

        if (canReply) {
            MCGlassButton *btnReply = [MCGlassButton pillButtonWithTitle:@"💬 Yanıtla" bgAlpha:0.25 tintColor:[NSColor systemGreenColor] target:self action:@selector(notificationDetailClicked:)];
            btnReply.frame = NSMakeRect(w - 230, 23, 74, 28);
            btnReply.customIdentifier = [NSString stringWithFormat:@"%ld", (long)i];
            btnReply.autoresizingMask = NSViewMinXMargin;
            [card addSubview:btnReply];
        }

        // Action: Detay Görüntüle Pill Button
        MCGlassButton *btnDetail = [MCGlassButton pillButtonWithTitle:@"👁 Detay" bgAlpha:0.18 tintColor:[NSColor systemBlueColor] target:self action:@selector(notificationDetailClicked:)];
        btnDetail.frame = NSMakeRect(w - 150, 23, 68, 28);
        btnDetail.customIdentifier = [NSString stringWithFormat:@"%ld", (long)i];
        btnDetail.autoresizingMask = NSViewMinXMargin;
        [card addSubview:btnDetail];

        // Action: Kopyala Pill Button
        MCGlassButton *btnCopy = [MCGlassButton pillButtonWithTitle:@"📋 Kopyala" bgAlpha:0.12 tintColor:[NSColor whiteColor] target:self action:@selector(copyNotificationClicked:)];
        btnCopy.frame = NSMakeRect(w - 74, 23, 64, 28);
        btnCopy.customIdentifier = text.length > 0 ? text : title;
        btnCopy.autoresizingMask = NSViewMinXMargin;
        [card addSubview:btnCopy];

        [self.notificationsDocView addSubview:card];
        y += itemH + gap;
    }

    self.notificationsDocView.frame = NSMakeRect(0, 0, w, MAX(y, self.notificationsScrollView.bounds.size.height));
}

- (void)copyNotificationClicked:(MCGlassButton *)sender {
    NSString *txt = sender.customIdentifier;
    if (txt) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb setString:txt forType:NSPasteboardTypeString];
    }
}

- (void)notificationDetailClicked:(MCGlassButton *)sender {
    NSInteger idx = [sender.customIdentifier integerValue];
    if (idx >= 0 && idx < self.notificationsList.count) {
        [self showNotificationDetailModal:self.notificationsList[idx]];
    }
}

#pragma mark - Liquid Glass Notification Detail Modal

- (void)showNotificationDetailModal:(NSDictionary *)notif {
    if (self.detailOverlayView) {
        [self.detailOverlayView removeFromSuperview];
        self.detailOverlayView = nil;
    }

    NSRect bounds = self.contentContainerView.bounds;
    self.detailOverlayView = [[MCFlippedView alloc] initWithFrame:bounds];
    self.detailOverlayView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.detailOverlayView.wantsLayer = YES;
    self.detailOverlayView.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.65].CGColor;
    [self.contentContainerView addSubview:self.detailOverlayView];

    NSString *pkg = notif[@"package_name"] ?: @"";
    NSString *app = MCResolvePrettyAppName(notif[@"app_name"], pkg);
    NSString *title = notif[@"title"] ?: @"";
    NSString *text = notif[@"text"] ?: @"";
    NSString *subText = notif[@"sub_text"] ?: @"";
    NSString *iconB64 = notif[@"icon"];
    NSString *notifId = notif[@"id"] ?: @"";

    BOOL canReply = [notif[@"can_reply"] boolValue];
    if (!canReply && pkg && (
        [pkg containsString:@"whatsapp"] ||
        [pkg containsString:@"telegram"] ||
        [pkg containsString:@"messaging"] ||
        [pkg containsString:@"instagram"] ||
        [pkg containsString:@"signal"])) {
        canReply = YES;
    }

    CGFloat modalW = MIN(560, bounds.size.width - 40);
    CGFloat modalH = canReply ? 490 : 440;
    CGFloat modalX = (bounds.size.width - modalW) / 2;
    CGFloat modalY = (bounds.size.height - modalH) / 2;

    self.detailModalCard = [[MCGlassCardView alloc] initWithFrame:NSMakeRect(modalX, modalY, modalW, modalH)];
    self.detailModalCard.glassCornerRadius = 18;
    self.detailModalCard.glassFillColor = [NSColor colorWithCalibratedRed:0.12 green:0.13 blue:0.16 alpha:0.95];
    self.detailModalCard.glassStrokeColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.25];
    [self.detailOverlayView addSubview:self.detailModalCard];

    // App Icon (48x48)
    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(20, 20, 48, 48)];
    iconView.wantsLayer = YES;
    iconView.layer.cornerRadius = 12;
    iconView.layer.masksToBounds = YES;
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    NSImage *appIconImg = MCDecodeBase64Icon(iconB64);
    if (appIconImg) {
        iconView.image = appIconImg;
    } else {
        iconView.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:0.4].CGColor;
        NSTextField *badgeLetter = [[NSTextField alloc] initWithFrame:iconView.bounds];
        badgeLetter.stringValue = (app.length > 0) ? [app substringToIndex:1] : @"🔔";
        badgeLetter.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
        badgeLetter.textColor = [NSColor whiteColor];
        badgeLetter.alignment = NSTextAlignmentCenter;
        badgeLetter.editable = NO;
        badgeLetter.bordered = NO;
        badgeLetter.backgroundColor = [NSColor clearColor];
        [iconView addSubview:badgeLetter];
    }
    [self.detailModalCard addSubview:iconView];

    // App Title & Package
    NSTextField *appLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 20, modalW - 140, 24)];
    appLbl.stringValue = app;
    appLbl.font = [NSFont systemFontOfSize:17 weight:NSFontWeightBold];
    appLbl.textColor = [NSColor whiteColor];
    appLbl.editable = NO;
    appLbl.bordered = NO;
    appLbl.backgroundColor = [NSColor clearColor];
    [self.detailModalCard addSubview:appLbl];

    NSTextField *pkgLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 44, modalW - 140, 18)];
    pkgLbl.stringValue = subText.length > 0 ? [NSString stringWithFormat:@"%@ • %@", subText, pkg] : pkg;
    pkgLbl.font = [NSFont systemFontOfSize:11];
    pkgLbl.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    pkgLbl.editable = NO;
    pkgLbl.bordered = NO;
    pkgLbl.backgroundColor = [NSColor clearColor];
    [self.detailModalCard addSubview:pkgLbl];

    // Close Button (✕)
    MCGlassButton *btnClose = [MCGlassButton pillButtonWithTitle:@"✕" bgAlpha:0.15 tintColor:[NSColor whiteColor] target:self action:@selector(closeDetailModalClicked:)];
    btnClose.frame = NSMakeRect(modalW - 46, 18, 30, 30);
    btnClose.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    [self.detailModalCard addSubview:btnClose];

    // Divider
    NSBox *div = [[NSBox alloc] initWithFrame:NSMakeRect(20, 78, modalW - 40, 1)];
    div.boxType = NSBoxCustom;
    div.borderWidth = 0;
    div.fillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.15];
    [self.detailModalCard addSubview:div];

    // Notification Title
    NSTextField *notifTitleLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 88, modalW - 40, 24)];
    notifTitleLbl.stringValue = title.length > 0 ? title : @"(Başlık Yok)";
    notifTitleLbl.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    notifTitleLbl.textColor = [NSColor whiteColor];
    notifTitleLbl.editable = NO;
    notifTitleLbl.bordered = NO;
    notifTitleLbl.backgroundColor = [NSColor clearColor];
    [self.detailModalCard addSubview:notifTitleLbl];

    CGFloat bodyH = canReply ? 140 : 240;
    NSScrollView *bodyScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 118, modalW - 40, bodyH)];
    bodyScroll.hasVerticalScroller = YES;
    bodyScroll.drawsBackground = NO;

    NSTextView *bodyTextView = [[NSTextView alloc] initWithFrame:bodyScroll.bounds];
    bodyTextView.string = text.length > 0 ? text : @"(İçerik Yok)";
    bodyTextView.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    bodyTextView.textColor = [NSColor colorWithCalibratedWhite:0.9 alpha:1.0];
    bodyTextView.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.04];
    bodyTextView.editable = NO;
    bodyTextView.selectable = YES;
    bodyScroll.documentView = bodyTextView;
    [self.detailModalCard addSubview:bodyScroll];

    CGFloat bottomBarY = 376;

    if (canReply) {
        NSBox *div2 = [[NSBox alloc] initWithFrame:NSMakeRect(20, 268, modalW - 40, 1)];
        div2.boxType = NSBoxCustom;
        div2.borderWidth = 0;
        div2.fillColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.15];
        [self.detailModalCard addSubview:div2];

        NSTextField *replyHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 276, modalW - 40, 18)];
        replyHeader.stringValue = @"💬 Doğrudan Yanıt Gönder:";
        replyHeader.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
        replyHeader.textColor = [NSColor colorWithCalibratedRed:0.4 green:0.95 blue:0.6 alpha:1.0];
        replyHeader.editable = NO;
        replyHeader.bordered = NO;
        replyHeader.backgroundColor = [NSColor clearColor];
        [self.detailModalCard addSubview:replyHeader];

        NSTextField *replyInput = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 300, modalW - 130, 32)];
        replyInput.placeholderString = @"Cevabınızı buraya yazın...";
        replyInput.font = [NSFont systemFontOfSize:13];
        [self.detailModalCard addSubview:replyInput];

        MCGlassButton *btnSend = [MCGlassButton pillButtonWithTitle:@"Gönder ➔" bgAlpha:0.35 tintColor:[NSColor colorWithCalibratedRed:0.18 green:0.80 blue:0.44 alpha:1.0] target:nil action:nil];
        btnSend.frame = NSMakeRect(modalW - 100, 300, 80, 32);
        __weak typeof(btnSend) weakSendBtn = btnSend;
        __weak typeof(replyInput) weakReplyInput = replyInput;
        btnSend.onClickBlock = ^{
            NSString *replyStr = weakReplyInput.stringValue;
            if (replyStr.length > 0) {
                [[BluetoothBridge sharedBridge] replyToNotificationWithId:notifId text:replyStr];
                weakSendBtn.title = @"✓ İletildi!";
                weakReplyInput.stringValue = @"";
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    weakSendBtn.title = @"Gönder ➔";
                });
            }
        };
        [self.detailModalCard addSubview:btnSend];

        bottomBarY = 436;
    }

    // Bottom Action Bar: Copy and Close
    MCGlassButton *btnCopyFull = [MCGlassButton pillButtonWithTitle:@"📋 Tam Metni Kopyala" bgAlpha:0.25 tintColor:[NSColor systemBlueColor] target:nil action:nil];
    btnCopyFull.frame = NSMakeRect(20, bottomBarY, 180, 34);
    __weak typeof(btnCopyFull) weakBtn = btnCopyFull;
    btnCopyFull.onClickBlock = ^{
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb setString:(text.length > 0 ? text : title) forType:NSPasteboardTypeString];
        weakBtn.title = @"✓ Kopyalandı!";
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            weakBtn.title = @"📋 Tam Metni Kopyala";
        });
    };
    [self.detailModalCard addSubview:btnCopyFull];

    MCGlassButton *btnDismiss = [MCGlassButton pillButtonWithTitle:@"Kapat" bgAlpha:0.15 tintColor:[NSColor whiteColor] target:self action:@selector(closeDetailModalClicked:)];
    btnDismiss.frame = NSMakeRect(modalW - 110, bottomBarY, 90, 34);
    [self.detailModalCard addSubview:btnDismiss];
}

- (void)closeDetailModalClicked:(id)sender {
    if (self.detailOverlayView) {
        [self.detailOverlayView removeFromSuperview];
        self.detailOverlayView = nil;
    }
}

- (void)clearAllNotificationsClicked:(id)sender {
    [self.notificationsList removeAllObjects];
    self.notificationsCountBadge.stringValue = @"(0)";
    [self rebuildNotificationsStack];
}

- (void)updateMediaPlayback:(NSDictionary *)mediaInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *app = mediaInfo[@"app_name"] ?: @"Müzik Çalar";
        NSString *title = mediaInfo[@"title"] ?: @"";
        NSString *artist = mediaInfo[@"artist"] ?: @"";

        self.mediaAppBadgeLabel.stringValue = [NSString stringWithFormat:@"🎵 %@", app];
        self.mediaTitleLabel.stringValue = title.length > 0 ? title : @"Parça Adı Yok";
        self.mediaArtistLabel.stringValue = artist.length > 0 ? artist : @"Sanatçı Bilgisi Yok";
        self.mediaStatusBadge.stringValue = @"▶ Oynatılıyor";
    });
}

- (void)updateDeviceState:(MacConnectState)state name:(NSString *)name {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (state == MacConnectStateConnected) {
            NSString *dev = (name.length > 0) ? name : @"Android";
            self.sidebarStatusDot.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
            self.sidebarStatusLabel.stringValue = [NSString stringWithFormat:@"Bağlı: %@", dev];
            self.sidebarConnectButton.title = @"Bağlantıyı Kes";
            self.deviceModelLabel.stringValue = [NSString stringWithFormat:@"Cihaz: %@", dev];
            self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (🟢 Bağlı)";
        } else if (state == MacConnectStateConnecting) {
            self.sidebarStatusDot.layer.backgroundColor = [NSColor systemYellowColor].CGColor;
            self.sidebarStatusLabel.stringValue = @"Bağlanıyor...";
            self.sidebarConnectButton.title = @"İptal";
            self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (🟡 Bağlanıyor...)";
        } else {
            self.sidebarStatusDot.layer.backgroundColor = [NSColor systemRedColor].CGColor;
            self.sidebarStatusLabel.stringValue = @"Bağlantı Yok";
            self.sidebarConnectButton.title = @"Telefona Bağlan";
            self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (🔴 Bağlantı Kesildi)";
        }
    });
}

- (void)updateBatteryLevel:(NSInteger)level {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (level >= 0) {
            self.sidebarBatteryLabel.stringValue = [NSString stringWithFormat:@"🔋 Pil: %%%ld", (long)level];
            self.deviceBatteryFullLabel.stringValue = [NSString stringWithFormat:@"Pil Durumu: %%%ld", (long)level];
        } else {
            self.sidebarBatteryLabel.stringValue = @"🔋 Pil: --";
            self.deviceBatteryFullLabel.stringValue = @"Pil Durumu: --";
        }
    });
}

- (void)updateClipboardText:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.receivedClipboardTextView.string = text ?: @"";
    });
}

- (void)sendClipboardClicked:(id)sender {
    NSString *txt = self.sendClipboardTextView.string;
    if (txt && txt.length > 0) {
        [[BluetoothBridge sharedBridge] sendClipboardText:txt];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Metin İletildi";
        alert.informativeText = @"Metin başarıyla telefonun panosuna aktarıldı.";
        [alert runModal];
    }
}

- (void)toggleConnectionClicked:(id)sender {
    BluetoothBridge *bridge = [BluetoothBridge sharedBridge];
    if (bridge.state == MacConnectStateConnected || bridge.state == MacConnectStateConnecting) {
        [bridge disconnect];
    } else {
        [bridge connectToPairedPhone];
    }
}

- (void)updateDeviceIpAddress:(NSString *)ipAddress {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (ipAddress && ipAddress.length > 0 && self.mirrorIpField) {
            if (self.mirrorIpField.stringValue.length == 0 || [self.mirrorIpField.stringValue isEqualToString:@"192.168.1.xxx"]) {
                self.mirrorIpField.stringValue = ipAddress;
            }
        }
    });
}

- (void)updateReplyStatus:(BOOL)success notifId:(NSString *)notifId message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.detailModalCard) {
            // Modal open, provide feedback
            NSLog(@"[MainWindowController] Reply status: %d (%@)", success, message);
        }
    });
}

@end
