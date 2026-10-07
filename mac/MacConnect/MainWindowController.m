#import "MainWindowController.h"
#import "BluetoothBridge.h"

// Flipped coordinate view (y = 0 at top-left, matching iOS & modern macOS conventions)
@interface MCFlippedView : NSView
@end

@implementation MCFlippedView
- (BOOL)isFlipped {
    return YES;
}
@end

@interface MainWindowController ()

// Main Layout Views
@property (nonatomic, strong) NSVisualEffectView *sidebarEffectView;
@property (nonatomic, strong) MCFlippedView *sidebarContentView;
@property (nonatomic, strong) NSVisualEffectView *contentEffectView;
@property (nonatomic, strong) MCFlippedView *contentContainerView;
@property (nonatomic, strong) NSMutableArray<NSButton *> *navButtons;
@property (nonatomic, assign) NSInteger currentTabIndex;

// Sidebar Elements
@property (nonatomic, strong) NSBox *sidebarFooterCard;
@property (nonatomic, strong) NSView *sidebarStatusDot;
@property (nonatomic, strong) NSTextField *sidebarStatusLabel;
@property (nonatomic, strong) NSTextField *sidebarBatteryLabel;
@property (nonatomic, strong) NSButton *sidebarConnectButton;

// Tab Views (All MCFlippedView for clean top-down flow)
@property (nonatomic, strong) MCFlippedView *callsView;
@property (nonatomic, strong) MCFlippedView *notificationsView;
@property (nonatomic, strong) MCFlippedView *mediaView;
@property (nonatomic, strong) MCFlippedView *deviceView;
@property (nonatomic, strong) MCFlippedView *settingsView;

// Calls Tab Components
@property (nonatomic, strong) NSBox *callHeroCard;
@property (nonatomic, strong) NSTextField *callHeroAvatarLabel;
@property (nonatomic, strong) NSTextField *callHeroTitleLabel;
@property (nonatomic, strong) NSTextField *callHeroSubtitleLabel;
@property (nonatomic, strong) NSStackView *callHeroButtonStack;
@property (nonatomic, strong) NSButton *btnAnswerCall;
@property (nonatomic, strong) NSButton *btnAnswerSpeakerCall;
@property (nonatomic, strong) NSButton *btnTransferComputerCall;
@property (nonatomic, strong) NSButton *btnRejectCall;

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
@property (nonatomic, strong) NSBox *mediaHeroCard;
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
    NSRect frame = NSMakeRect(120, 120, 960, 620);
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

        window.title = @"MacConnect";
        window.titleVisibility = NSWindowTitleHidden;
        window.titlebarAppearsTransparent = YES;
        window.minSize = NSMakeSize(880, 560);
        window.delegate = self;
        window.backgroundColor = [NSColor windowBackgroundColor];
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

#pragma mark - Main UI Setup

- (void)setupUI {
    NSView *root = self.window.contentView;

    CGFloat sidebarWidth = 220;

    // 1. Sidebar Visual Effect View (Frosted Glass)
    self.sidebarEffectView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, sidebarWidth, root.bounds.size.height)];
    self.sidebarEffectView.material = NSVisualEffectMaterialSidebar;
    self.sidebarEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.sidebarEffectView.state = NSVisualEffectStateFollowsWindowActiveState;
    self.sidebarEffectView.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [root addSubview:self.sidebarEffectView];

    self.sidebarContentView = [[MCFlippedView alloc] initWithFrame:self.sidebarEffectView.bounds];
    self.sidebarContentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.sidebarEffectView addSubview:self.sidebarContentView];

    // Hairline Separator between Sidebar and Content
    NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(sidebarWidth - 1, 0, 1, root.bounds.size.height)];
    divider.boxType = NSBoxSeparator;
    divider.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [root addSubview:divider];

    [self buildSidebarContent];

    // 2. Content Area (Visual Effect Window Background)
    NSRect contentRect = NSMakeRect(sidebarWidth, 0, root.bounds.size.width - sidebarWidth, root.bounds.size.height);
    self.contentEffectView = [[NSVisualEffectView alloc] initWithFrame:contentRect];
    self.contentEffectView.material = NSVisualEffectMaterialWindowBackground;
    self.contentEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.contentEffectView.state = NSVisualEffectStateFollowsWindowActiveState;
    self.contentEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:self.contentEffectView];

    self.contentContainerView = [[MCFlippedView alloc] initWithFrame:self.contentEffectView.bounds];
    self.contentContainerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.contentEffectView addSubview:self.contentContainerView];

    // 3. Build All 5 Views
    [self buildCallsTab];
    [self buildNotificationsTab];
    [self buildMediaTab];
    [self buildDeviceTab];
    [self buildSettingsTab];

    [self selectTab:0];
}

#pragma mark - Sidebar Construction

- (void)buildSidebarContent {
    CGFloat w = 220;

    // Top: App Icon and Title (Offset below window traffic lights)
    NSImageView *logoView = [[NSImageView alloc] initWithFrame:NSMakeRect(18, 48, 30, 30)];
    logoView.image = [NSImage imageNamed:NSImageNameApplicationIcon];
    logoView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [self.sidebarContentView addSubview:logoView];

    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(54, 51, 150, 24)];
    titleLabel.stringValue = @"MacConnect";
    titleLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
    titleLabel.textColor = [NSColor labelColor];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    [self.sidebarContentView addSubview:titleLabel];

    // Status Pill
    NSBox *statusPill = [[NSBox alloc] initWithFrame:NSMakeRect(16, 88, w - 32, 26)];
    statusPill.boxType = NSBoxCustom;
    statusPill.cornerRadius = 13;
    statusPill.fillColor = [NSColor quaternaryLabelColor];
    statusPill.borderWidth = 0;
    [self.sidebarContentView addSubview:statusPill];

    self.sidebarStatusDot = [[NSView alloc] initWithFrame:NSMakeRect(10, 9, 8, 8)];
    self.sidebarStatusDot.wantsLayer = YES;
    self.sidebarStatusDot.layer.cornerRadius = 4;
    self.sidebarStatusDot.layer.backgroundColor = [NSColor systemRedColor].CGColor;
    [statusPill addSubview:self.sidebarStatusDot];

    self.sidebarStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(24, 4, w - 62, 18)];
    self.sidebarStatusLabel.stringValue = @"Bağlantı Yok";
    self.sidebarStatusLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.sidebarStatusLabel.textColor = [NSColor secondaryLabelColor];
    self.sidebarStatusLabel.editable = NO;
    self.sidebarStatusLabel.bordered = NO;
    self.sidebarStatusLabel.backgroundColor = [NSColor clearColor];
    [statusPill addSubview:self.sidebarStatusLabel];

    // Navigation Items
    NSArray *navItems = @[
        @{@"icon": @"📞", @"title": @"Aramalar & Tuş Takımı"},
        @{@"icon": @"🔔", @"title": @"Bildirimler"},
        @{@"icon": @"🎵", @"title": @"Şimdi Çalıyor"},
        @{@"icon": @"📱", @"title": @"Cihaz & Pano"},
        @{@"icon": @"⚙️", @"title": @"Ayarlar"}
    ];

    CGFloat btnY = 126;
    for (NSInteger i = 0; i < navItems.count; i++) {
        NSDictionary *item = navItems[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(12, btnY, w - 24, 36)];
        btn.title = [NSString stringWithFormat:@"%@  %@", item[@"icon"], item[@"title"]];
        btn.bezelStyle = NSBezelStyleRegularSquare;
        btn.wantsLayer = YES;
        btn.layer.cornerRadius = 8;
        btn.alignment = NSTextAlignmentLeft;
        btn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        btn.tag = i;
        btn.target = self;
        btn.action = @selector(navButtonClicked:);
        [self.sidebarContentView addSubview:btn];
        [self.navButtons addObject:btn];

        btnY += 42;
    }

    // Bottom Footer Card (Battery & Reconnect)
    CGFloat footerH = 76;
    self.sidebarFooterCard = [[NSBox alloc] initWithFrame:NSMakeRect(12, self.sidebarContentView.bounds.size.height - footerH - 16, w - 24, footerH)];
    self.sidebarFooterCard.boxType = NSBoxCustom;
    self.sidebarFooterCard.cornerRadius = 10;
    self.sidebarFooterCard.borderWidth = 1.0;
    self.sidebarFooterCard.borderColor = [NSColor separatorColor];
    self.sidebarFooterCard.fillColor = [NSColor quaternaryLabelColor];
    self.sidebarFooterCard.autoresizingMask = NSViewMinYMargin;
    [self.sidebarContentView addSubview:self.sidebarFooterCard];

    self.sidebarBatteryLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 46, w - 44, 20)];
    self.sidebarBatteryLabel.stringValue = @"🔋 Pil: --";
    self.sidebarBatteryLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.sidebarBatteryLabel.textColor = [NSColor secondaryLabelColor];
    self.sidebarBatteryLabel.editable = NO;
    self.sidebarBatteryLabel.bordered = NO;
    self.sidebarBatteryLabel.backgroundColor = [NSColor clearColor];
    [self.sidebarFooterCard addSubview:self.sidebarBatteryLabel];

    self.sidebarConnectButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 10, w - 44, 28)];
    self.sidebarConnectButton.title = @"Telefona Bağlan";
    self.sidebarConnectButton.bezelStyle = NSBezelStyleRounded;
    self.sidebarConnectButton.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.sidebarConnectButton.target = self;
    self.sidebarConnectButton.action = @selector(toggleConnectionClicked:);
    [self.sidebarFooterCard addSubview:self.sidebarConnectButton];
}

- (void)navButtonClicked:(NSButton *)sender {
    [self selectTab:sender.tag];
}

- (void)selectTab:(NSInteger)index {
    self.currentTabIndex = index;

    for (NSButton *btn in self.navButtons) {
        if (btn.tag == index) {
            btn.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:0.18].CGColor;
            btn.contentTintColor = [NSColor controlAccentColor];
            btn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
        } else {
            btn.layer.backgroundColor = [NSColor clearColor].CGColor;
            btn.contentTintColor = [NSColor labelColor];
            btn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        }
    }

    [self.callsView removeFromSuperview];
    [self.notificationsView removeFromSuperview];
    [self.mediaView removeFromSuperview];
    [self.deviceView removeFromSuperview];
    [self.settingsView removeFromSuperview];

    NSView *target = nil;
    switch (index) {
        case 0: target = self.callsView; break;
        case 1: target = self.notificationsView; break;
        case 2: target = self.mediaView; break;
        case 3: target = self.deviceView; break;
        case 4: target = self.settingsView; break;
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
    if (self.settingsView.superview) self.settingsView.frame = self.contentContainerView.bounds;
}

#pragma mark - Tab 1: 📞 Aramalar (Flawless Proportions & Zero Overlap)

- (void)buildCallsTab {
    self.callsView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    // Header Title
    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 300, 28)];
    tabTitle.stringValue = @"Aramalar ve Telefon Köprüsü";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.callsView addSubview:tabTitle];

    // Top: Call Hero Card (height: 84px)
    CGFloat heroCardY = 86;
    CGFloat heroCardH = 84;
    self.callHeroCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, heroCardY, self.callsView.bounds.size.width - (pad * 2), heroCardH)];
    self.callHeroCard.boxType = NSBoxCustom;
    self.callHeroCard.cornerRadius = 12;
    self.callHeroCard.borderWidth = 1.0;
    self.callHeroCard.borderColor = [NSColor separatorColor];
    self.callHeroCard.fillColor = [NSColor controlBackgroundColor];
    self.callHeroCard.autoresizingMask = NSViewWidthSizable;
    [self.callsView addSubview:self.callHeroCard];

    // Left Circle Avatar
    NSBox *avatarCircle = [[NSBox alloc] initWithFrame:NSMakeRect(16, 18, 48, 48)];
    avatarCircle.boxType = NSBoxCustom;
    avatarCircle.cornerRadius = 24;
    avatarCircle.borderWidth = 0;
    avatarCircle.fillColor = [NSColor quaternaryLabelColor];
    [self.callHeroCard addSubview:avatarCircle];

    self.callHeroAvatarLabel = [[NSTextField alloc] initWithFrame:avatarCircle.bounds];
    self.callHeroAvatarLabel.stringValue = @"📞";
    self.callHeroAvatarLabel.font = [NSFont systemFontOfSize:24];
    self.callHeroAvatarLabel.alignment = NSTextAlignmentCenter;
    self.callHeroAvatarLabel.editable = NO;
    self.callHeroAvatarLabel.bordered = NO;
    self.callHeroAvatarLabel.backgroundColor = [NSColor clearColor];
    [avatarCircle addSubview:self.callHeroAvatarLabel];

    // Name & Subtitle
    self.callHeroTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(76, 18, 320, 24)];
    self.callHeroTitleLabel.stringValue = @"Aktif Arama Yok";
    self.callHeroTitleLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
    self.callHeroTitleLabel.textColor = [NSColor labelColor];
    self.callHeroTitleLabel.editable = NO;
    self.callHeroTitleLabel.bordered = NO;
    self.callHeroTitleLabel.backgroundColor = [NSColor clearColor];
    [self.callHeroCard addSubview:self.callHeroTitleLabel];

    self.callHeroSubtitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(76, 44, 400, 20)];
    self.callHeroSubtitleLabel.stringValue = @"Tuş takımından numara çevirebilir veya gelen aramaları masanızdan yanıtlayabilirsiniz.";
    self.callHeroSubtitleLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.callHeroSubtitleLabel.textColor = [NSColor secondaryLabelColor];
    self.callHeroSubtitleLabel.editable = NO;
    self.callHeroSubtitleLabel.bordered = NO;
    self.callHeroSubtitleLabel.backgroundColor = [NSColor clearColor];
    [self.callHeroCard addSubview:self.callHeroSubtitleLabel];

    // Call Action Buttons (Right-aligned inside Hero Card)
    self.callHeroButtonStack = [[NSStackView alloc] initWithFrame:NSMakeRect(self.callHeroCard.bounds.size.width - 450, 22, 434, 40)];
    self.callHeroButtonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.callHeroButtonStack.spacing = 8;
    self.callHeroButtonStack.distribution = NSStackViewDistributionFillEqually;
    self.callHeroButtonStack.autoresizingMask = NSViewMinXMargin;
    [self.callHeroCard addSubview:self.callHeroButtonStack];

    self.btnAnswerCall = [NSButton buttonWithTitle:@"📞 Cevapla" target:self action:@selector(actionAnswerClicked:)];
    self.btnAnswerCall.bezelStyle = NSBezelStyleRounded;
    self.btnAnswerCall.contentTintColor = [NSColor systemGreenColor];
    self.btnAnswerCall.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    [self.callHeroButtonStack addArrangedSubview:self.btnAnswerCall];

    self.btnAnswerSpeakerCall = [NSButton buttonWithTitle:@"🔊 Hoparlör" target:self action:@selector(actionAnswerSpeakerClicked:)];
    self.btnAnswerSpeakerCall.bezelStyle = NSBezelStyleRounded;
    self.btnAnswerSpeakerCall.contentTintColor = [NSColor systemBlueColor];
    self.btnAnswerSpeakerCall.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    [self.callHeroButtonStack addArrangedSubview:self.btnAnswerSpeakerCall];

    self.btnTransferComputerCall = [NSButton buttonWithTitle:@"💻 Bilgisayara Al" target:self action:@selector(actionTransferComputerClicked:)];
    self.btnTransferComputerCall.bezelStyle = NSBezelStyleRounded;
    self.btnTransferComputerCall.contentTintColor = [NSColor systemPurpleColor];
    self.btnTransferComputerCall.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    [self.callHeroButtonStack addArrangedSubview:self.btnTransferComputerCall];

    self.btnRejectCall = [NSButton buttonWithTitle:@"❌ Reddet" target:self action:@selector(actionRejectClicked:)];
    self.btnRejectCall.bezelStyle = NSBezelStyleRounded;
    self.btnRejectCall.contentTintColor = [NSColor systemRedColor];
    self.btnRejectCall.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    [self.callHeroButtonStack addArrangedSubview:self.btnRejectCall];

    self.callHeroButtonStack.hidden = YES;

    // Lower Split Area:
    // Left: Dialpad Card (width: 330px, height: 410px)
    CGFloat lowerY = 184;
    CGFloat lowerH = 410;
    NSBox *dialerCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, lowerY, 330, lowerH)];
    dialerCard.boxType = NSBoxCustom;
    dialerCard.cornerRadius = 14;
    dialerCard.borderWidth = 1.0;
    dialerCard.borderColor = [NSColor separatorColor];
    dialerCard.fillColor = [NSColor controlBackgroundColor];
    [self.callsView addSubview:dialerCard];

    // Number Input & Backspace
    self.dialerNumberField = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 16, 240, 36)];
    self.dialerNumberField.placeholderString = @"Numara tuşlayın...";
    self.dialerNumberField.font = [NSFont monospacedDigitSystemFontOfSize:22 weight:NSFontWeightBold];
    self.dialerNumberField.textColor = [NSColor labelColor];
    self.dialerNumberField.backgroundColor = [NSColor textBackgroundColor];
    self.dialerNumberField.bordered = YES;
    self.dialerNumberField.focusRingType = NSFocusRingTypeNone;
    [dialerCard addSubview:self.dialerNumberField];

    NSButton *btnBackspace = [NSButton buttonWithTitle:@"⌫" target:self action:@selector(dialerBackspaceClicked:)];
    btnBackspace.frame = NSMakeRect(262, 16, 52, 36);
    btnBackspace.bezelStyle = NSBezelStyleRounded;
    btnBackspace.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
    [dialerCard addSubview:btnBackspace];

    // 3x4 Clean Keypad Buttons
    NSArray *digits = @[
        @"1", @"2", @"3",
        @"4", @"5", @"6",
        @"7", @"8", @"9",
        @"*", @"0", @"#"
    ];

    CGFloat keyW = 86;
    CGFloat keyH = 44;
    CGFloat gridStartX = 18;
    CGFloat gridStartY = 66;

    for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 3; c++) {
            int idx = r * 3 + c;
            NSString *digit = digits[idx];

            NSButton *keyBtn = [[NSButton alloc] initWithFrame:NSMakeRect(gridStartX + (c * (keyW + 14)), gridStartY + (r * (keyH + 10)), keyW, keyH)];
            keyBtn.title = digit;
            keyBtn.bezelStyle = NSBezelStyleRegularSquare;
            keyBtn.wantsLayer = YES;
            keyBtn.layer.cornerRadius = 8;
            keyBtn.layer.backgroundColor = [NSColor quaternaryLabelColor].CGColor;
            keyBtn.layer.borderWidth = 1.0;
            keyBtn.layer.borderColor = [NSColor separatorColor].CGColor;
            keyBtn.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
            keyBtn.contentTintColor = [NSColor labelColor];
            keyBtn.identifier = digit;
            keyBtn.target = self;
            keyBtn.action = @selector(dialerDigitClicked:);
            [dialerCard addSubview:keyBtn];
        }
    }

    // Call Button (Cleanly at y = 292, leaving generous margin)
    NSButton *btnCall = [NSButton buttonWithTitle:@"📞  Aramayı Başlat" target:self action:@selector(dialerCallClicked:)];
    btnCall.frame = NSMakeRect(18, 292, 294, 42);
    btnCall.bezelStyle = NSBezelStyleRounded;
    btnCall.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    btnCall.contentTintColor = [NSColor systemGreenColor];
    [dialerCard addSubview:btnCall];

    // Right: Recent Calls Card
    CGFloat recentX = pad + 330 + 18;
    CGFloat recentW = self.callsView.bounds.size.width - recentX - pad;
    NSBox *recentCard = [[NSBox alloc] initWithFrame:NSMakeRect(recentX, lowerY, recentW, lowerH)];
    recentCard.boxType = NSBoxCustom;
    recentCard.cornerRadius = 14;
    recentCard.borderWidth = 1.0;
    recentCard.borderColor = [NSColor separatorColor];
    recentCard.fillColor = [NSColor controlBackgroundColor];
    recentCard.autoresizingMask = NSViewWidthSizable;
    [self.callsView addSubview:recentCard];

    NSTextField *recentHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 16, recentW - 32, 22)];
    recentHeader.stringValue = @"Son Aramalar";
    recentHeader.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    recentHeader.textColor = [NSColor labelColor];
    recentHeader.editable = NO;
    recentHeader.bordered = NO;
    recentHeader.backgroundColor = [NSColor clearColor];
    [recentCard addSubview:recentHeader];

    self.recentCallsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(12, 48, recentW - 24, lowerH - 64)];
    self.recentCallsScrollView.hasVerticalScroller = YES;
    self.recentCallsScrollView.drawsBackground = NO;
    self.recentCallsScrollView.autoresizingMask = NSViewWidthSizable;
    [recentCard addSubview:self.recentCallsScrollView];

    self.recentCallsDocView = [[MCFlippedView alloc] initWithFrame:NSMakeRect(0, 0, recentW - 24, 100)];
    self.recentCallsDocView.autoresizingMask = NSViewWidthSizable;
    self.recentCallsScrollView.documentView = self.recentCallsDocView;
}

#pragma mark - Tab 2: 🔔 Bildirimler (Flipped Clean List)

- (void)buildNotificationsTab {
    self.notificationsView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 180, 28)];
    tabTitle.stringValue = @"Bildirimler";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.notificationsView addSubview:tabTitle];

    self.notificationsCountBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(145, 52, 80, 22)];
    self.notificationsCountBadge.stringValue = @"(0)";
    self.notificationsCountBadge.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    self.notificationsCountBadge.textColor = [NSColor secondaryLabelColor];
    self.notificationsCountBadge.editable = NO;
    self.notificationsCountBadge.bordered = NO;
    self.notificationsCountBadge.backgroundColor = [NSColor clearColor];
    [self.notificationsView addSubview:self.notificationsCountBadge];

    NSButton *btnClear = [NSButton buttonWithTitle:@"Tümünü Temizle" target:self action:@selector(clearAllNotificationsClicked:)];
    btnClear.frame = NSMakeRect(self.notificationsView.bounds.size.width - 160, 48, 136, 28);
    btnClear.bezelStyle = NSBezelStyleRounded;
    btnClear.autoresizingMask = NSViewMinXMargin;
    [self.notificationsView addSubview:btnClear];

    // Scrollable List
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
}

#pragma mark - Tab 3: 🎵 Şimdi Çalıyor

- (void)buildMediaTab {
    self.mediaView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 300, 28)];
    tabTitle.stringValue = @"Şimdi Çalıyor (Medya)";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.mediaView addSubview:tabTitle];

    CGFloat cardW = self.mediaView.bounds.size.width - (pad * 2);
    CGFloat cardH = 200;
    self.mediaHeroCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, 92, cardW, cardH)];
    self.mediaHeroCard.boxType = NSBoxCustom;
    self.mediaHeroCard.cornerRadius = 16;
    self.mediaHeroCard.borderWidth = 1.0;
    self.mediaHeroCard.borderColor = [NSColor separatorColor];
    self.mediaHeroCard.fillColor = [NSColor controlBackgroundColor];
    self.mediaHeroCard.autoresizingMask = NSViewWidthSizable;
    [self.mediaView addSubview:self.mediaHeroCard];

    // Album Artwork Box
    NSBox *artBox = [[NSBox alloc] initWithFrame:NSMakeRect(24, 28, 96, 96)];
    artBox.boxType = NSBoxCustom;
    artBox.cornerRadius = 14;
    artBox.borderWidth = 0;
    artBox.fillColor = [NSColor quaternaryLabelColor];
    [self.mediaHeroCard addSubview:artBox];

    NSTextField *artIcon = [[NSTextField alloc] initWithFrame:artBox.bounds];
    artIcon.stringValue = @"🎵";
    artIcon.font = [NSFont systemFontOfSize:44];
    artIcon.alignment = NSTextAlignmentCenter;
    artIcon.editable = NO;
    artIcon.bordered = NO;
    artIcon.backgroundColor = [NSColor clearColor];
    [artBox addSubview:artIcon];

    self.mediaAppBadgeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(136, 26, 250, 20)];
    self.mediaAppBadgeLabel.stringValue = @"Spotify / Deezer";
    self.mediaAppBadgeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    self.mediaAppBadgeLabel.textColor = [NSColor systemGreenColor];
    self.mediaAppBadgeLabel.editable = NO;
    self.mediaAppBadgeLabel.bordered = NO;
    self.mediaAppBadgeLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaAppBadgeLabel];

    self.mediaTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(136, 52, cardW - 160, 32)];
    self.mediaTitleLabel.stringValue = @"Şu anda çalan müzik yok";
    self.mediaTitleLabel.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    self.mediaTitleLabel.textColor = [NSColor labelColor];
    self.mediaTitleLabel.editable = NO;
    self.mediaTitleLabel.bordered = NO;
    self.mediaTitleLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaTitleLabel];

    self.mediaArtistLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(136, 88, cardW - 160, 22)];
    self.mediaArtistLabel.stringValue = @"Telefonda Spotify veya Deezer açtığınızda parça bilgisi burada belirecektir.";
    self.mediaArtistLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.mediaArtistLabel.textColor = [NSColor secondaryLabelColor];
    self.mediaArtistLabel.editable = NO;
    self.mediaArtistLabel.bordered = NO;
    self.mediaArtistLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaArtistLabel];

    self.mediaStatusBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(136, 140, 130, 24)];
    self.mediaStatusBadge.stringValue = @"▶ Oynatılıyor";
    self.mediaStatusBadge.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    self.mediaStatusBadge.textColor = [NSColor systemGreenColor];
    self.mediaStatusBadge.editable = NO;
    self.mediaStatusBadge.bordered = NO;
    self.mediaStatusBadge.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaStatusBadge];

    // Info Card
    NSBox *infoCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, 308, cardW, 80)];
    infoCard.boxType = NSBoxCustom;
    infoCard.cornerRadius = 12;
    infoCard.fillColor = [NSColor quaternaryLabelColor];
    infoCard.borderWidth = 0;
    infoCard.autoresizingMask = NSViewWidthSizable;
    [self.mediaView addSubview:infoCard];

    NSTextField *infoNote = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 12, cardW - 32, 56)];
    infoNote.stringValue = @"💡 Akıllı Medya Bildirim Filtresi:\nSpotify, Deezer ve YouTube Music gibi uygulamaların sürekli değişen şarkı bildirimleri Mac masaüstünüzü ve bildirim merkezinizi spamlamaz. Parça geçişleri sessizce bu ekranda toplanır.";
    infoNote.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    infoNote.textColor = [NSColor secondaryLabelColor];
    infoNote.editable = NO;
    infoNote.bordered = NO;
    infoNote.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:infoNote];
}

#pragma mark - Tab 4: 📱 Cihaz & Pano

- (void)buildDeviceTab {
    self.deviceView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 350, 28)];
    tabTitle.stringValue = @"Cihaz ve Pano Senkronizasyonu";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.deviceView addSubview:tabTitle];

    CGFloat cardW = self.deviceView.bounds.size.width - (pad * 2);

    // Hardware Card
    NSBox *infoCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, 92, cardW, 100)];
    infoCard.boxType = NSBoxCustom;
    infoCard.cornerRadius = 14;
    infoCard.borderWidth = 1.0;
    infoCard.borderColor = [NSColor separatorColor];
    infoCard.fillColor = [NSColor controlBackgroundColor];
    infoCard.autoresizingMask = NSViewWidthSizable;
    [self.deviceView addSubview:infoCard];

    self.deviceModelLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 16, cardW - 40, 22)];
    self.deviceModelLabel.stringValue = @"Cihaz: Telefon Bekleniyor...";
    self.deviceModelLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    self.deviceModelLabel.textColor = [NSColor labelColor];
    self.deviceModelLabel.editable = NO;
    self.deviceModelLabel.bordered = NO;
    self.deviceModelLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceModelLabel];

    self.deviceStatusFullLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 42, cardW - 40, 18)];
    self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (Bağlantı Yok)";
    self.deviceStatusFullLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.deviceStatusFullLabel.textColor = [NSColor secondaryLabelColor];
    self.deviceStatusFullLabel.editable = NO;
    self.deviceStatusFullLabel.bordered = NO;
    self.deviceStatusFullLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceStatusFullLabel];

    self.deviceBatteryFullLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 64, cardW - 40, 18)];
    self.deviceBatteryFullLabel.stringValue = @"Pil Durumu: --";
    self.deviceBatteryFullLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.deviceBatteryFullLabel.textColor = [NSColor secondaryLabelColor];
    self.deviceBatteryFullLabel.editable = NO;
    self.deviceBatteryFullLabel.bordered = NO;
    self.deviceBatteryFullLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceBatteryFullLabel];

    // Send Clipboard Card
    NSBox *sendCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, 208, cardW, 150)];
    sendCard.boxType = NSBoxCustom;
    sendCard.cornerRadius = 14;
    sendCard.borderWidth = 1.0;
    sendCard.borderColor = [NSColor separatorColor];
    sendCard.fillColor = [NSColor controlBackgroundColor];
    sendCard.autoresizingMask = NSViewWidthSizable;
    [self.deviceView addSubview:sendCard];

    NSTextField *sendTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 12, cardW - 32, 20)];
    sendTitle.stringValue = @"Telefona Metin Gönder (Evrensel Pano)";
    sendTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    sendTitle.textColor = [NSColor labelColor];
    sendTitle.editable = NO;
    sendTitle.bordered = NO;
    sendTitle.backgroundColor = [NSColor clearColor];
    [sendCard addSubview:sendTitle];

    NSScrollView *sendScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 38, cardW - 32, 64)];
    sendScroll.hasVerticalScroller = YES;
    sendScroll.autoresizingMask = NSViewWidthSizable;
    self.sendClipboardTextView = [[NSTextView alloc] initWithFrame:sendScroll.bounds];
    self.sendClipboardTextView.font = [NSFont systemFontOfSize:13];
    sendScroll.documentView = self.sendClipboardTextView;
    [sendCard addSubview:sendScroll];

    NSButton *btnSendClip = [NSButton buttonWithTitle:@"Telefona Gönder" target:self action:@selector(sendClipboardClicked:)];
    btnSendClip.frame = NSMakeRect(16, 110, 150, 28);
    btnSendClip.bezelStyle = NSBezelStyleRounded;
    [sendCard addSubview:btnSendClip];

    // Received Clipboard Card
    NSBox *recvCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, 374, cardW, 140)];
    recvCard.boxType = NSBoxCustom;
    recvCard.cornerRadius = 14;
    recvCard.borderWidth = 1.0;
    recvCard.borderColor = [NSColor separatorColor];
    recvCard.fillColor = [NSColor controlBackgroundColor];
    recvCard.autoresizingMask = NSViewWidthSizable;
    [self.deviceView addSubview:recvCard];

    NSTextField *recvTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 12, cardW - 32, 20)];
    recvTitle.stringValue = @"Telefondan Alınan Son Pano İçeriği";
    recvTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    recvTitle.textColor = [NSColor labelColor];
    recvTitle.editable = NO;
    recvTitle.bordered = NO;
    recvTitle.backgroundColor = [NSColor clearColor];
    [recvCard addSubview:recvTitle];

    NSScrollView *recvScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 38, cardW - 32, 86)];
    recvScroll.hasVerticalScroller = YES;
    recvScroll.autoresizingMask = NSViewWidthSizable;
    self.receivedClipboardTextView = [[NSTextView alloc] initWithFrame:recvScroll.bounds];
    self.receivedClipboardTextView.editable = NO;
    self.receivedClipboardTextView.font = [NSFont systemFontOfSize:13];
    recvScroll.documentView = self.receivedClipboardTextView;
    [recvCard addSubview:recvScroll];
}

#pragma mark - Tab 5: ⚙️ Ayarlar

- (void)buildSettingsTab {
    self.settingsView = [[MCFlippedView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 48, 300, 28)];
    tabTitle.stringValue = @"Ayarlar ve Tercihler";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    [self.settingsView addSubview:tabTitle];

    CGFloat cardW = self.settingsView.bounds.size.width - (pad * 2);

    NSBox *optionsCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, 92, cardW, 150)];
    optionsCard.boxType = NSBoxCustom;
    optionsCard.cornerRadius = 14;
    optionsCard.borderWidth = 1.0;
    optionsCard.borderColor = [NSColor separatorColor];
    optionsCard.fillColor = [NSColor controlBackgroundColor];
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

    NSBox *aboutCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, 258, cardW, 80)];
    aboutCard.boxType = NSBoxCustom;
    aboutCard.cornerRadius = 14;
    aboutCard.borderWidth = 1.0;
    aboutCard.borderColor = [NSColor separatorColor];
    aboutCard.fillColor = [NSColor controlBackgroundColor];
    aboutCard.autoresizingMask = NSViewWidthSizable;
    [self.settingsView addSubview:aboutCard];

    NSTextField *aboutBox = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 16, cardW - 40, 48)];
    aboutBox.stringValue = @"MacConnect v1.0.2 • Native macOS Entegrasyonu\nDoğrudan donanım seviyesinde Bluetooth RFCOMM köprüsü ile telefon ve Mac senkronizasyonu.\nGeliştirici: canmertdogan";
    aboutBox.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    aboutBox.textColor = [NSColor secondaryLabelColor];
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

- (void)dialerDigitClicked:(NSButton *)sender {
    NSString *digit = sender.identifier ?: @"";
    NSString *curr = self.dialerNumberField.stringValue ?: @"";
    self.dialerNumberField.stringValue = [curr stringByAppendingString:digit];
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

    [[BluetoothBridge sharedBridge] dialPhoneNumber:number];

    NSDictionary *entry = @{
        @"name": number,
        @"number": number,
        @"time": @"Az önce (Giden Arama)"
    };
    [self.recentCalls insertObject:entry atIndex:0];
    [self rebuildRecentCallsStack];

    self.callHeroCard.fillColor = [NSColor colorWithCalibratedRed:0.10 green:0.25 blue:0.15 alpha:1.0];
    self.callHeroTitleLabel.stringValue = [NSString stringWithFormat:@"📞 Aranıyor: %@", number];
    self.callHeroSubtitleLabel.stringValue = @"Arama komutu telefona iletildi.";
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

    CGFloat itemH = 50;
    CGFloat gap = 6;
    CGFloat y = 0;
    CGFloat w = self.recentCallsDocView.bounds.size.width;

    for (NSDictionary *call in self.recentCalls) {
        NSBox *itemBox = [[NSBox alloc] initWithFrame:NSMakeRect(0, y, w, itemH)];
        itemBox.boxType = NSBoxCustom;
        itemBox.cornerRadius = 8;
        itemBox.fillColor = [NSColor quaternaryLabelColor];
        itemBox.borderWidth = 1.0;
        itemBox.borderColor = [NSColor separatorColor];
        itemBox.autoresizingMask = NSViewWidthSizable;

        NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 8, w - 85, 18)];
        lbl.stringValue = call[@"name"] ?: call[@"number"];
        lbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
        lbl.textColor = [NSColor labelColor];
        lbl.editable = NO;
        lbl.bordered = NO;
        lbl.backgroundColor = [NSColor clearColor];
        [itemBox addSubview:lbl];

        NSTextField *sub = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 26, w - 85, 16)];
        sub.stringValue = call[@"time"] ?: @"";
        sub.font = [NSFont systemFontOfSize:10];
        sub.textColor = [NSColor secondaryLabelColor];
        sub.editable = NO;
        sub.bordered = NO;
        sub.backgroundColor = [NSColor clearColor];
        [itemBox addSubview:sub];

        NSButton *btnRedial = [NSButton buttonWithTitle:@"Ara" target:self action:@selector(redialClicked:)];
        btnRedial.frame = NSMakeRect(w - 70, 12, 60, 26);
        btnRedial.bezelStyle = NSBezelStyleRounded;
        btnRedial.identifier = call[@"number"];
        btnRedial.autoresizingMask = NSViewMinXMargin;
        [itemBox addSubview:btnRedial];

        [self.recentCallsDocView addSubview:itemBox];
        y += itemH + gap;
    }

    self.recentCallsDocView.frame = NSMakeRect(0, 0, w, MAX(y, self.recentCallsScrollView.bounds.size.height));
}

- (void)redialClicked:(NSButton *)sender {
    NSString *num = sender.identifier;
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

        self.callHeroCard.fillColor = [NSColor colorWithCalibratedRed:0.35 green:0.12 blue:0.14 alpha:1.0];
        self.callHeroAvatarLabel.stringValue = @"🔔";
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
        self.callHeroCard.fillColor = [NSColor controlBackgroundColor];
        self.callHeroAvatarLabel.stringValue = @"📞";
        self.callHeroTitleLabel.stringValue = @"Aktif Arama Yok";
        self.callHeroSubtitleLabel.stringValue = @"Tuş takımından numara çevirebilir veya gelen aramaları masanızdan yanıtlayabilirsiniz.";
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

    CGFloat itemH = 68;
    CGFloat gap = 8;
    CGFloat y = 0;
    CGFloat w = self.notificationsDocView.bounds.size.width;

    for (NSDictionary *n in self.notificationsList) {
        NSString *app = n[@"app_name"] ?: @"Uygulama";
        NSString *title = n[@"title"] ?: @"";
        NSString *text = n[@"text"] ?: @"";

        NSBox *card = [[NSBox alloc] initWithFrame:NSMakeRect(0, y, w, itemH)];
        card.boxType = NSBoxCustom;
        card.cornerRadius = 10;
        card.fillColor = [NSColor controlBackgroundColor];
        card.borderWidth = 1.0;
        card.borderColor = [NSColor separatorColor];
        card.autoresizingMask = NSViewWidthSizable;

        NSTextField *appLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 8, 220, 16)];
        appLbl.stringValue = app;
        appLbl.font = [NSFont systemFontOfSize:11 weight:NSFontWeightBold];
        appLbl.textColor = [NSColor controlAccentColor];
        appLbl.editable = NO;
        appLbl.bordered = NO;
        appLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:appLbl];

        NSTextField *titleLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 26, w - 100, 18)];
        titleLbl.stringValue = title;
        titleLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
        titleLbl.textColor = [NSColor labelColor];
        titleLbl.editable = NO;
        titleLbl.bordered = NO;
        titleLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:titleLbl];

        NSTextField *textLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 44, w - 100, 18)];
        textLbl.stringValue = text;
        textLbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        textLbl.textColor = [NSColor secondaryLabelColor];
        textLbl.editable = NO;
        textLbl.bordered = NO;
        textLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:textLbl];

        NSButton *btnCopy = [NSButton buttonWithTitle:@"Kopyala" target:self action:@selector(copyNotificationClicked:)];
        btnCopy.frame = NSMakeRect(w - 84, 20, 72, 26);
        btnCopy.bezelStyle = NSBezelStyleRounded;
        btnCopy.identifier = text.length > 0 ? text : title;
        btnCopy.autoresizingMask = NSViewMinXMargin;
        [card addSubview:btnCopy];

        [self.notificationsDocView addSubview:card];
        y += itemH + gap;
    }

    self.notificationsDocView.frame = NSMakeRect(0, 0, w, MAX(y, self.notificationsScrollView.bounds.size.height));
}

- (void)copyNotificationClicked:(NSButton *)sender {
    NSString *txt = sender.identifier;
    if (txt) {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb setString:txt forType:NSPasteboardTypeString];
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

@end
