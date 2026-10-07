#import "MainWindowController.h"
#import "BluetoothBridge.h"
#import <QuartzCore/QuartzCore.h>

@interface MainWindowController ()

// Root Views & Materials
@property (nonatomic, strong) NSVisualEffectView *sidebarEffectView;
@property (nonatomic, strong) NSVisualEffectView *contentEffectView;
@property (nonatomic, strong) NSView *contentContainerView;
@property (nonatomic, strong) NSMutableArray<NSButton *> *navButtons;
@property (nonatomic, assign) NSInteger currentTabIndex;

// Sidebar Header & Status
@property (nonatomic, strong) NSTextField *sidebarStatusLabel;
@property (nonatomic, strong) NSView *sidebarStatusDot;
@property (nonatomic, strong) NSTextField *sidebarBatteryLabel;
@property (nonatomic, strong) NSLevelIndicator *sidebarBatteryIndicator;
@property (nonatomic, strong) NSButton *sidebarConnectButton;

// Tab Views
@property (nonatomic, strong) NSView *callsView;
@property (nonatomic, strong) NSView *notificationsView;
@property (nonatomic, strong) NSView *mediaView;
@property (nonatomic, strong) NSView *deviceView;
@property (nonatomic, strong) NSView *settingsView;

// Calls Tab Subviews
@property (nonatomic, strong) NSBox *callHeroCard;
@property (nonatomic, strong) NSTextField *callHeroAvatarLabel;
@property (nonatomic, strong) NSTextField *callHeroTitleLabel;
@property (nonatomic, strong) NSTextField *callHeroSubtitleLabel;
@property (nonatomic, strong) NSTextField *callHeroStatusBadge;
@property (nonatomic, strong) NSStackView *callHeroButtonStack;
@property (nonatomic, strong) NSButton *btnAnswerCall;
@property (nonatomic, strong) NSButton *btnAnswerSpeakerCall;
@property (nonatomic, strong) NSButton *btnTransferComputerCall;
@property (nonatomic, strong) NSButton *btnRejectCall;
@property (nonatomic, strong) NSTextField *dialerNumberField;
@property (nonatomic, strong) NSScrollView *recentCallsScrollView;
@property (nonatomic, strong) NSStackView *recentCallsStackView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recentCalls;
@property (nonatomic, strong) NSDictionary *activeCallInfo;

// Notifications Tab Subviews
@property (nonatomic, strong) NSTextField *notificationsCountBadge;
@property (nonatomic, strong) NSScrollView *notificationsScrollView;
@property (nonatomic, strong) NSStackView *notificationsStackView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *notificationsList;

// Media Tab Subviews
@property (nonatomic, strong) NSBox *mediaHeroCard;
@property (nonatomic, strong) NSTextField *mediaAppBadgeLabel;
@property (nonatomic, strong) NSTextField *mediaTitleLabel;
@property (nonatomic, strong) NSTextField *mediaArtistLabel;
@property (nonatomic, strong) NSTextField *mediaStatusBadge;
@property (nonatomic, strong) NSImageView *mediaCoverArtView;
@property (nonatomic, strong) NSStackView *mediaWaveformStack;

// Device & Clipboard Tab Subviews
@property (nonatomic, strong) NSTextField *deviceModelLabel;
@property (nonatomic, strong) NSTextField *deviceBtAddressLabel;
@property (nonatomic, strong) NSTextField *deviceStatusFullLabel;
@property (nonatomic, strong) NSTextField *deviceBatteryFullLabel;
@property (nonatomic, strong) NSTextView *sendClipboardTextView;
@property (nonatomic, strong) NSTextView *receivedClipboardTextView;

// Settings Subviews
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
        window.minSize = NSMakeSize(860, 540);
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

#pragma mark - UI Setup (Native macOS Sequoia / 27 Design)

- (void)setupUI {
    NSView *root = self.window.contentView;
    root.wantsLayer = YES;

    CGFloat sidebarWidth = 230;

    // 1. Sidebar with Native macOS Frosted Glass (Sidebar Material)
    NSRect sidebarRect = NSMakeRect(0, 0, sidebarWidth, root.bounds.size.height);
    self.sidebarEffectView = [[NSVisualEffectView alloc] initWithFrame:sidebarRect];
    self.sidebarEffectView.material = NSVisualEffectMaterialSidebar;
    self.sidebarEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.sidebarEffectView.state = NSVisualEffectStateFollowsWindowActiveState;
    self.sidebarEffectView.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [root addSubview:self.sidebarEffectView];

    // 1px Vertical Hairline Divider
    NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(sidebarWidth - 1, 0, 1, root.bounds.size.height)];
    divider.boxType = NSBoxSeparator;
    divider.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [root addSubview:divider];

    [self setupSidebar];

    // 2. Main Content View with Window Background Material
    NSRect contentRect = NSMakeRect(sidebarWidth, 0, root.bounds.size.width - sidebarWidth, root.bounds.size.height);
    self.contentEffectView = [[NSVisualEffectView alloc] initWithFrame:contentRect];
    self.contentEffectView.material = NSVisualEffectMaterialWindowBackground;
    self.contentEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.contentEffectView.state = NSVisualEffectStateFollowsWindowActiveState;
    self.contentEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:self.contentEffectView];

    self.contentContainerView = [[NSView alloc] initWithFrame:self.contentEffectView.bounds];
    self.contentContainerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.contentEffectView addSubview:self.contentContainerView];

    // 3. Build All Navigation Tab Views
    [self setupCallsTab];
    [self setupNotificationsTab];
    [self setupMediaTab];
    [self setupDeviceTab];
    [self setupSettingsTab];

    // Default Selection: Aramalar & Tuş Takımı
    [self selectTab:0];
}

#pragma mark - Sidebar Implementation

- (void)setupSidebar {
    CGFloat w = 230;
    CGFloat h = self.sidebarEffectView.bounds.size.height;

    // Header Area: offset under native window traffic light buttons (top padding = 54px)
    CGFloat headerY = h - 68;

    NSImageView *logoView = [[NSImageView alloc] initWithFrame:NSMakeRect(18, headerY, 32, 32)];
    logoView.image = [NSImage imageNamed:NSImageNameApplicationIcon];
    logoView.imageScaling = NSImageScaleProportionallyUpOrDown;
    logoView.autoresizingMask = NSViewMinYMargin;
    [self.sidebarEffectView addSubview:logoView];

    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(58, headerY + 4, 150, 24)];
    titleLabel.stringValue = @"MacConnect";
    titleLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
    titleLabel.textColor = [NSColor labelColor];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.autoresizingMask = NSViewMinYMargin;
    [self.sidebarEffectView addSubview:titleLabel];

    // Subtitle & Status Badge
    NSBox *statusPill = [[NSBox alloc] initWithFrame:NSMakeRect(18, headerY - 26, w - 36, 24)];
    statusPill.boxType = NSBoxCustom;
    statusPill.cornerRadius = 12;
    statusPill.fillColor = [NSColor tertiaryLabelColor];
    statusPill.borderWidth = 0;
    statusPill.autoresizingMask = NSViewMinYMargin;
    [self.sidebarEffectView addSubview:statusPill];

    self.sidebarStatusDot = [[NSView alloc] initWithFrame:NSMakeRect(8, 8, 8, 8)];
    self.sidebarStatusDot.wantsLayer = YES;
    self.sidebarStatusDot.layer.cornerRadius = 4;
    self.sidebarStatusDot.layer.backgroundColor = [NSColor systemRedColor].CGColor;
    [statusPill addSubview:self.sidebarStatusDot];

    self.sidebarStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(22, 3, w - 66, 18)];
    self.sidebarStatusLabel.stringValue = @"Bağlantı Yok";
    self.sidebarStatusLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.sidebarStatusLabel.textColor = [NSColor secondaryLabelColor];
    self.sidebarStatusLabel.editable = NO;
    self.sidebarStatusLabel.bordered = NO;
    self.sidebarStatusLabel.backgroundColor = [NSColor clearColor];
    [statusPill addSubview:self.sidebarStatusLabel];

    // Navigation Items (Styled Apple Sidebar Buttons)
    NSArray *navItems = @[
        @{@"icon": @"📞", @"title": @"Aramalar & Tuş Takımı"},
        @{@"icon": @"🔔", @"title": @"Bildirimler"},
        @{@"icon": @"🎵", @"title": @"Şimdi Çalıyor"},
        @{@"icon": @"📱", @"title": @"Cihaz & Pano"},
        @{@"icon": @"⚙️", @"title": @"Ayarlar"}
    ];

    CGFloat btnY = headerY - 70;
    for (NSInteger i = 0; i < navItems.count; i++) {
        NSDictionary *item = navItems[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(12, btnY, w - 24, 38)];
        btn.title = [NSString stringWithFormat:@"%@  %@", item[@"icon"], item[@"title"]];
        btn.bezelStyle = NSBezelStyleRegularSquare;
        btn.wantsLayer = YES;
        btn.layer.cornerRadius = 8;
        btn.alignment = NSTextAlignmentLeft;
        btn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        btn.tag = i;
        btn.target = self;
        btn.action = @selector(navButtonClicked:);
        btn.autoresizingMask = NSViewMinYMargin;
        [self.sidebarEffectView addSubview:btn];
        [self.navButtons addObject:btn];

        btnY -= 44;
    }

    // Sidebar Footer: Battery & Connection Card
    NSBox *footerCard = [[NSBox alloc] initWithFrame:NSMakeRect(12, 16, w - 24, 78)];
    footerCard.boxType = NSBoxCustom;
    footerCard.cornerRadius = 10;
    footerCard.borderWidth = 1.0;
    footerCard.borderColor = [NSColor separatorColor];
    footerCard.fillColor = [NSColor quaternaryLabelColor];
    footerCard.autoresizingMask = NSViewMaxYMargin;
    [self.sidebarEffectView addSubview:footerCard];

    self.sidebarBatteryLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 48, w - 44, 20)];
    self.sidebarBatteryLabel.stringValue = @"🔋 Pil: --";
    self.sidebarBatteryLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.sidebarBatteryLabel.textColor = [NSColor secondaryLabelColor];
    self.sidebarBatteryLabel.editable = NO;
    self.sidebarBatteryLabel.bordered = NO;
    self.sidebarBatteryLabel.backgroundColor = [NSColor clearColor];
    [footerCard addSubview:self.sidebarBatteryLabel];

    self.sidebarConnectButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 10, w - 44, 28)];
    self.sidebarConnectButton.title = @"Telefona Bağlan";
    self.sidebarConnectButton.bezelStyle = NSBezelStyleRounded;
    self.sidebarConnectButton.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.sidebarConnectButton.target = self;
    self.sidebarConnectButton.action = @selector(toggleConnectionClicked:);
    [footerCard addSubview:self.sidebarConnectButton];
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

    NSView *targetView = nil;
    switch (index) {
        case 0: targetView = self.callsView; break;
        case 1: targetView = self.notificationsView; break;
        case 2: targetView = self.mediaView; break;
        case 3: targetView = self.deviceView; break;
        case 4: targetView = self.settingsView; break;
    }

    if (targetView) {
        targetView.frame = self.contentContainerView.bounds;
        targetView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self.contentContainerView addSubview:targetView];
    }
}

#pragma mark - Tab 1: 📞 Aramalar & Tuş Takımı (FaceTime / iPhone Mirroring Grade)

- (void)setupCallsTab {
    self.callsView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;
    CGFloat topBarH = 50;

    // Titlebar Header
    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.callsView.bounds.size.height - topBarH, 300, 28)];
    tabTitle.stringValue = @"Aramalar ve Telefon Köprüsü";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    tabTitle.autoresizingMask = NSViewMinYMargin;
    [self.callsView addSubview:tabTitle];

    // 1. Floating Incoming / Active Call Hero Banner
    CGFloat cardH = 150;
    CGFloat cardY = self.callsView.bounds.size.height - topBarH - cardH - 10;
    self.callHeroCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, cardY, self.callsView.bounds.size.width - (pad * 2), cardH)];
    self.callHeroCard.boxType = NSBoxCustom;
    self.callHeroCard.cornerRadius = 14;
    self.callHeroCard.borderWidth = 1.0;
    self.callHeroCard.borderColor = [NSColor separatorColor];
    self.callHeroCard.fillColor = [NSColor controlBackgroundColor];
    self.callHeroCard.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.callsView addSubview:self.callHeroCard];

    // Caller Avatar Badge (Circular)
    NSBox *avatarCircle = [[NSBox alloc] initWithFrame:NSMakeRect(20, cardH - 74, 54, 54)];
    avatarCircle.boxType = NSBoxCustom;
    avatarCircle.cornerRadius = 27;
    avatarCircle.borderWidth = 0;
    avatarCircle.fillColor = [NSColor quaternaryLabelColor];
    [self.callHeroCard addSubview:avatarCircle];

    self.callHeroAvatarLabel = [[NSTextField alloc] initWithFrame:avatarCircle.bounds];
    self.callHeroAvatarLabel.stringValue = @"📞";
    self.callHeroAvatarLabel.font = [NSFont systemFontOfSize:28];
    self.callHeroAvatarLabel.alignment = NSTextAlignmentCenter;
    self.callHeroAvatarLabel.editable = NO;
    self.callHeroAvatarLabel.bordered = NO;
    self.callHeroAvatarLabel.backgroundColor = [NSColor clearColor];
    [avatarCircle addSubview:self.callHeroAvatarLabel];

    // Call Name & Number Labels
    self.callHeroTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(88, cardH - 50, self.callHeroCard.bounds.size.width - 240, 28)];
    self.callHeroTitleLabel.stringValue = @"Aktif Arama Yok";
    self.callHeroTitleLabel.font = [NSFont systemFontOfSize:19 weight:NSFontWeightBold];
    self.callHeroTitleLabel.textColor = [NSColor labelColor];
    self.callHeroTitleLabel.editable = NO;
    self.callHeroTitleLabel.bordered = NO;
    self.callHeroTitleLabel.backgroundColor = [NSColor clearColor];
    self.callHeroTitleLabel.autoresizingMask = NSViewWidthSizable;
    [self.callHeroCard addSubview:self.callHeroTitleLabel];

    self.callHeroSubtitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(88, cardH - 75, self.callHeroCard.bounds.size.width - 240, 20)];
    self.callHeroSubtitleLabel.stringValue = @"Aşağıdaki tuş takımından doğrudan numara çevirebilir veya gelen aramaları yanıtlayabilirsiniz.";
    self.callHeroSubtitleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.callHeroSubtitleLabel.textColor = [NSColor secondaryLabelColor];
    self.callHeroSubtitleLabel.editable = NO;
    self.callHeroSubtitleLabel.bordered = NO;
    self.callHeroSubtitleLabel.backgroundColor = [NSColor clearColor];
    self.callHeroSubtitleLabel.autoresizingMask = NSViewWidthSizable;
    [self.callHeroCard addSubview:self.callHeroSubtitleLabel];

    // Call Action Buttons Stack
    self.callHeroButtonStack = [[NSStackView alloc] initWithFrame:NSMakeRect(88, 16, self.callHeroCard.bounds.size.width - 108, 40)];
    self.callHeroButtonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.callHeroButtonStack.spacing = 12;
    self.callHeroButtonStack.distribution = NSStackViewDistributionFillEqually;
    self.callHeroButtonStack.autoresizingMask = NSViewWidthSizable;
    [self.callHeroCard addSubview:self.callHeroButtonStack];

    self.btnAnswerCall = [NSButton buttonWithTitle:@"📞 Cevapla" target:self action:@selector(actionAnswerClicked:)];
    self.btnAnswerCall.bezelStyle = NSBezelStyleRounded;
    self.btnAnswerCall.contentTintColor = [NSColor systemGreenColor];
    self.btnAnswerCall.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    [self.callHeroButtonStack addArrangedSubview:self.btnAnswerCall];

    self.btnAnswerSpeakerCall = [NSButton buttonWithTitle:@"🔊 Hoparlörle Aç" target:self action:@selector(actionAnswerSpeakerClicked:)];
    self.btnAnswerSpeakerCall.bezelStyle = NSBezelStyleRounded;
    self.btnAnswerSpeakerCall.contentTintColor = [NSColor systemBlueColor];
    self.btnAnswerSpeakerCall.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    [self.callHeroButtonStack addArrangedSubview:self.btnAnswerSpeakerCall];

    self.btnTransferComputerCall = [NSButton buttonWithTitle:@"💻 Bilgisayara Al" target:self action:@selector(actionTransferComputerClicked:)];
    self.btnTransferComputerCall.bezelStyle = NSBezelStyleRounded;
    self.btnTransferComputerCall.contentTintColor = [NSColor systemPurpleColor];
    self.btnTransferComputerCall.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    [self.callHeroButtonStack addArrangedSubview:self.btnTransferComputerCall];

    self.btnRejectCall = [NSButton buttonWithTitle:@"❌ Reddet / Kapat" target:self action:@selector(actionRejectClicked:)];
    self.btnRejectCall.bezelStyle = NSBezelStyleRounded;
    self.btnRejectCall.contentTintColor = [NSColor systemRedColor];
    self.btnRejectCall.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    [self.callHeroButtonStack addArrangedSubview:self.btnRejectCall];

    self.callHeroButtonStack.hidden = YES;

    // 2. Bottom Split: Left = Apple-style Dialpad (width: 340), Right = Recent Calls Card
    CGFloat lowerH = cardY - (pad * 2);
    NSBox *dialerCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, pad, 350, lowerH)];
    dialerCard.boxType = NSBoxCustom;
    dialerCard.cornerRadius = 14;
    dialerCard.borderWidth = 1.0;
    dialerCard.borderColor = [NSColor separatorColor];
    dialerCard.fillColor = [NSColor controlBackgroundColor];
    dialerCard.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [self.callsView addSubview:dialerCard];

    // Dialer Number Input Field with SF Monospaced Digits
    self.dialerNumberField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, lowerH - 56, 255, 42)];
    self.dialerNumberField.placeholderString = @"Numara tuşlayın...";
    self.dialerNumberField.font = [NSFont monospacedDigitSystemFontOfSize:24 weight:NSFontWeightBold];
    self.dialerNumberField.textColor = [NSColor labelColor];
    self.dialerNumberField.backgroundColor = [NSColor textBackgroundColor];
    self.dialerNumberField.bordered = YES;
    self.dialerNumberField.focusRingType = NSFocusRingTypeNone;
    [dialerCard addSubview:self.dialerNumberField];

    NSButton *btnBackspace = [NSButton buttonWithTitle:@"⌫" target:self action:@selector(dialerBackspaceClicked:)];
    btnBackspace.frame = NSMakeRect(284, lowerH - 56, 46, 42);
    btnBackspace.bezelStyle = NSBezelStyleRounded;
    btnBackspace.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
    [dialerCard addSubview:btnBackspace];

    // Apple iPhone Style 3x4 Keypad with Letters
    NSArray *keypadDefs = @[
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

    CGFloat keyW = 92;
    CGFloat keyH = 44;
    CGFloat gridX = 20;
    CGFloat gridY = lowerH - 114;

    for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 3; c++) {
            int idx = r * 3 + c;
            NSDictionary *def = keypadDefs[idx];
            NSString *digit = def[@"num"];
            NSString *letters = def[@"sub"];

            NSButton *keyBtn = [[NSButton alloc] initWithFrame:NSMakeRect(gridX + (c * (keyW + 16)), gridY - (r * (keyH + 10)), keyW, keyH)];
            keyBtn.bezelStyle = NSBezelStyleRegularSquare;
            keyBtn.wantsLayer = YES;
            keyBtn.layer.cornerRadius = 8;
            keyBtn.layer.backgroundColor = [NSColor quaternaryLabelColor].CGColor;
            keyBtn.layer.borderWidth = 1.0;
            keyBtn.layer.borderColor = [NSColor separatorColor].CGColor;
            keyBtn.identifier = digit;
            keyBtn.target = self;
            keyBtn.action = @selector(dialerDigitClicked:);

            // Multiline Attributed Title (Digit + Small Letters underneath)
            NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:digit attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:17 weight:NSFontWeightBold],
                NSForegroundColorAttributeName: [NSColor labelColor]
            }];
            if (letters.length > 0) {
                [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@", letters] attributes:@{
                    NSFontAttributeName: [NSFont systemFontOfSize:8 weight:NSFontWeightBold],
                    NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
                }]];
            }
            keyBtn.attributedTitle = attr;
            [dialerCard addSubview:keyBtn];
        }
    }

    // Call Action Button (Vibrant Apple Green)
    NSButton *btnCall = [NSButton buttonWithTitle:@"📞  Aramayı Başlat" target:self action:@selector(dialerCallClicked:)];
    btnCall.frame = NSMakeRect(20, 14, 310, 44);
    btnCall.bezelStyle = NSBezelStyleRounded;
    btnCall.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    btnCall.contentTintColor = [NSColor systemGreenColor];
    [dialerCard addSubview:btnCall];

    // Right Side: Son Aramalar (Recent Calls Card)
    CGFloat recentX = pad + 350 + 18;
    CGFloat recentW = self.callsView.bounds.size.width - recentX - pad;
    NSBox *recentCard = [[NSBox alloc] initWithFrame:NSMakeRect(recentX, pad, recentW, lowerH)];
    recentCard.boxType = NSBoxCustom;
    recentCard.cornerRadius = 14;
    recentCard.borderWidth = 1.0;
    recentCard.borderColor = [NSColor separatorColor];
    recentCard.fillColor = [NSColor controlBackgroundColor];
    recentCard.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.callsView addSubview:recentCard];

    NSTextField *recentHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(18, lowerH - 42, recentW - 36, 22)];
    recentHeader.stringValue = @"Son Aramalar";
    recentHeader.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    recentHeader.textColor = [NSColor labelColor];
    recentHeader.editable = NO;
    recentHeader.bordered = NO;
    recentHeader.backgroundColor = [NSColor clearColor];
    [recentCard addSubview:recentHeader];

    self.recentCallsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(14, 14, recentW - 28, lowerH - 60)];
    self.recentCallsScrollView.hasVerticalScroller = YES;
    self.recentCallsScrollView.drawsBackground = NO;
    self.recentCallsScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [recentCard addSubview:self.recentCallsScrollView];

    NSView *recentDoc = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, recentW - 28, 100)];
    recentDoc.autoresizingMask = NSViewWidthSizable;
    self.recentCallsScrollView.documentView = recentDoc;

    self.recentCallsStackView = [[NSStackView alloc] initWithFrame:recentDoc.bounds];
    self.recentCallsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.recentCallsStackView.alignment = NSLayoutAttributeLeading;
    self.recentCallsStackView.spacing = 8;
    self.recentCallsStackView.autoresizingMask = NSViewWidthSizable;
    [recentDoc addSubview:self.recentCallsStackView];
}

#pragma mark - Tab 2: 🔔 Bildirimler (macOS Notification Center Feed)

- (void)setupNotificationsTab {
    self.notificationsView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.notificationsView.bounds.size.height - 50, 180, 28)];
    tabTitle.stringValue = @"Bildirimler";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    tabTitle.autoresizingMask = NSViewMinYMargin;
    [self.notificationsView addSubview:tabTitle];

    self.notificationsCountBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(145, self.notificationsView.bounds.size.height - 48, 80, 22)];
    self.notificationsCountBadge.stringValue = @"(0)";
    self.notificationsCountBadge.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    self.notificationsCountBadge.textColor = [NSColor secondaryLabelColor];
    self.notificationsCountBadge.editable = NO;
    self.notificationsCountBadge.bordered = NO;
    self.notificationsCountBadge.backgroundColor = [NSColor clearColor];
    self.notificationsCountBadge.autoresizingMask = NSViewMinYMargin;
    [self.notificationsView addSubview:self.notificationsCountBadge];

    NSButton *btnClear = [NSButton buttonWithTitle:@"Tümünü Temizle" target:self action:@selector(clearAllNotificationsClicked:)];
    btnClear.frame = NSMakeRect(self.notificationsView.bounds.size.width - 160, self.notificationsView.bounds.size.height - 50, 136, 28);
    btnClear.bezelStyle = NSBezelStyleRounded;
    btnClear.autoresizingMask = NSViewMinYMargin | NSViewMinXMargin;
    [self.notificationsView addSubview:btnClear];

    CGFloat listH = self.notificationsView.bounds.size.height - 76;
    self.notificationsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(pad, 16, self.notificationsView.bounds.size.width - (pad * 2), listH)];
    self.notificationsScrollView.hasVerticalScroller = YES;
    self.notificationsScrollView.drawsBackground = NO;
    self.notificationsScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.notificationsView addSubview:self.notificationsScrollView];

    NSView *notifDoc = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, self.notificationsScrollView.bounds.size.width, 100)];
    notifDoc.autoresizingMask = NSViewWidthSizable;
    self.notificationsScrollView.documentView = notifDoc;

    self.notificationsStackView = [[NSStackView alloc] initWithFrame:notifDoc.bounds];
    self.notificationsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.notificationsStackView.alignment = NSLayoutAttributeLeading;
    self.notificationsStackView.spacing = 10;
    self.notificationsStackView.autoresizingMask = NSViewWidthSizable;
    [notifDoc addSubview:self.notificationsStackView];
}

#pragma mark - Tab 3: 🎵 Şimdi Çalıyor (macOS Control Center Now Playing)

- (void)setupMediaTab {
    self.mediaView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.mediaView.bounds.size.height - 50, 300, 28)];
    tabTitle.stringValue = @"Şimdi Çalıyor (Medya)";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    tabTitle.autoresizingMask = NSViewMinYMargin;
    [self.mediaView addSubview:tabTitle];

    CGFloat cardW = self.mediaView.bounds.size.width - (pad * 2);
    CGFloat cardH = 260;
    self.mediaHeroCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, self.mediaView.bounds.size.height - cardH - 74, cardW, cardH)];
    self.mediaHeroCard.boxType = NSBoxCustom;
    self.mediaHeroCard.cornerRadius = 16;
    self.mediaHeroCard.borderWidth = 1.0;
    self.mediaHeroCard.borderColor = [NSColor separatorColor];
    self.mediaHeroCard.fillColor = [NSColor controlBackgroundColor];
    self.mediaHeroCard.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.mediaView addSubview:self.mediaHeroCard];

    // Vinyl / Album Artwork Mock
    NSBox *artBox = [[NSBox alloc] initWithFrame:NSMakeRect(24, cardH - 120, 96, 96)];
    artBox.boxType = NSBoxCustom;
    artBox.cornerRadius = 14;
    artBox.borderWidth = 0;
    artBox.fillColor = [NSColor quaternaryLabelColor];
    [self.mediaHeroCard addSubview:artBox];

    NSTextField *artIcon = [[NSTextField alloc] initWithFrame:artBox.bounds];
    artIcon.stringValue = @"🎵";
    artIcon.font = [NSFont systemFontOfSize:48];
    artIcon.alignment = NSTextAlignmentCenter;
    artIcon.editable = NO;
    artIcon.bordered = NO;
    artIcon.backgroundColor = [NSColor clearColor];
    [artBox addSubview:artIcon];

    self.mediaAppBadgeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(136, cardH - 45, 200, 20)];
    self.mediaAppBadgeLabel.stringValue = @"Spotify / Deezer";
    self.mediaAppBadgeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    self.mediaAppBadgeLabel.textColor = [NSColor systemGreenColor];
    self.mediaAppBadgeLabel.editable = NO;
    self.mediaAppBadgeLabel.bordered = NO;
    self.mediaAppBadgeLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaAppBadgeLabel];

    self.mediaTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(136, cardH - 85, cardW - 160, 34)];
    self.mediaTitleLabel.stringValue = @"Şu anda çalan müzik yok";
    self.mediaTitleLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    self.mediaTitleLabel.textColor = [NSColor labelColor];
    self.mediaTitleLabel.editable = NO;
    self.mediaTitleLabel.bordered = NO;
    self.mediaTitleLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaTitleLabel];

    self.mediaArtistLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(136, cardH - 115, cardW - 160, 22)];
    self.mediaArtistLabel.stringValue = @"Telefonda Spotify veya Deezer açtığınızda parça bilgisi burada belirecektir.";
    self.mediaArtistLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.mediaArtistLabel.textColor = [NSColor secondaryLabelColor];
    self.mediaArtistLabel.editable = NO;
    self.mediaArtistLabel.bordered = NO;
    self.mediaArtistLabel.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaArtistLabel];

    self.mediaStatusBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(24, 24, 130, 24)];
    self.mediaStatusBadge.stringValue = @"▶ Oynatılıyor";
    self.mediaStatusBadge.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    self.mediaStatusBadge.textColor = [NSColor systemGreenColor];
    self.mediaStatusBadge.editable = NO;
    self.mediaStatusBadge.bordered = NO;
    self.mediaStatusBadge.backgroundColor = [NSColor clearColor];
    [self.mediaHeroCard addSubview:self.mediaStatusBadge];

    // Informative Card
    NSTextField *infoNote = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 40, cardW, 70)];
    infoNote.stringValue = @"💡 Akıllı Medya Bildirim Filtresi:\nSpotify, Deezer ve YouTube Music gibi uygulamaların sürekli değişen şarkı bildirimleri Mac masaüstünüzü ve bildirim merkezinizi spamlamaz. Parça geçişleri sessizce bu ekranda toplanır.";
    infoNote.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    infoNote.textColor = [NSColor secondaryLabelColor];
    infoNote.editable = NO;
    infoNote.bordered = NO;
    infoNote.backgroundColor = [NSColor clearColor];
    infoNote.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [self.mediaView addSubview:infoNote];
}

#pragma mark - Tab 4: 📱 Cihaz & Pano (Universal Clipboard & Hardware Info)

- (void)setupDeviceTab {
    self.deviceView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 24;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.deviceView.bounds.size.height - 50, 300, 28)];
    tabTitle.stringValue = @"Cihaz ve Pano Senkronizasyonu";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    tabTitle.autoresizingMask = NSViewMinYMargin;
    [self.deviceView addSubview:tabTitle];

    CGFloat cardW = self.deviceView.bounds.size.width - (pad * 2);
    NSBox *infoCard = [[NSBox alloc] initWithFrame:NSMakeRect(pad, self.deviceView.bounds.size.height - 180, cardW, 116)];
    infoCard.boxType = NSBoxCustom;
    infoCard.cornerRadius = 14;
    infoCard.borderWidth = 1.0;
    infoCard.borderColor = [NSColor separatorColor];
    infoCard.fillColor = [NSColor controlBackgroundColor];
    infoCard.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.deviceView addSubview:infoCard];

    self.deviceModelLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 72, cardW - 40, 24)];
    self.deviceModelLabel.stringValue = @"Cihaz: Telefon Bekleniyor...";
    self.deviceModelLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    self.deviceModelLabel.textColor = [NSColor labelColor];
    self.deviceModelLabel.editable = NO;
    self.deviceModelLabel.bordered = NO;
    self.deviceModelLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceModelLabel];

    self.deviceStatusFullLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 46, cardW - 40, 20)];
    self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (Bağlantı Yok)";
    self.deviceStatusFullLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.deviceStatusFullLabel.textColor = [NSColor secondaryLabelColor];
    self.deviceStatusFullLabel.editable = NO;
    self.deviceStatusFullLabel.bordered = NO;
    self.deviceStatusFullLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceStatusFullLabel];

    self.deviceBatteryFullLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 18, cardW - 40, 20)];
    self.deviceBatteryFullLabel.stringValue = @"Pil Durumu: --";
    self.deviceBatteryFullLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.deviceBatteryFullLabel.textColor = [NSColor secondaryLabelColor];
    self.deviceBatteryFullLabel.editable = NO;
    self.deviceBatteryFullLabel.bordered = NO;
    self.deviceBatteryFullLabel.backgroundColor = [NSColor clearColor];
    [infoCard addSubview:self.deviceBatteryFullLabel];

    // Universal Clipboard Section
    CGFloat clipY = self.deviceView.bounds.size.height - 355;
    NSTextField *clipTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, clipY + 135, cardW, 22)];
    clipTitle.stringValue = @"Telefona Metin Gönder (Evrensel Pano)";
    clipTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    clipTitle.textColor = [NSColor labelColor];
    clipTitle.editable = NO;
    clipTitle.bordered = NO;
    clipTitle.backgroundColor = [NSColor clearColor];
    clipTitle.autoresizingMask = NSViewMinYMargin;
    [self.deviceView addSubview:clipTitle];

    NSScrollView *sendScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(pad, clipY + 35, cardW, 90)];
    sendScroll.hasVerticalScroller = YES;
    sendScroll.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    self.sendClipboardTextView = [[NSTextView alloc] initWithFrame:sendScroll.bounds];
    self.sendClipboardTextView.font = [NSFont systemFontOfSize:13];
    sendScroll.documentView = self.sendClipboardTextView;
    [self.deviceView addSubview:sendScroll];

    NSButton *btnSendClip = [NSButton buttonWithTitle:@"Telefona Gönder" target:self action:@selector(sendClipboardClicked:)];
    btnSendClip.frame = NSMakeRect(pad, clipY, 160, 28);
    btnSendClip.bezelStyle = NSBezelStyleRounded;
    btnSendClip.autoresizingMask = NSViewMinYMargin;
    [self.deviceView addSubview:btnSendClip];

    NSTextField *recvTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, clipY - 35, cardW, 22)];
    recvTitle.stringValue = @"Telefondan Alınan Son Pano İçeriği";
    recvTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    recvTitle.textColor = [NSColor labelColor];
    recvTitle.editable = NO;
    recvTitle.bordered = NO;
    recvTitle.backgroundColor = [NSColor clearColor];
    recvTitle.autoresizingMask = NSViewMinYMargin;
    [self.deviceView addSubview:recvTitle];

    NSScrollView *recvScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(pad, 20, cardW, clipY - 65)];
    recvScroll.hasVerticalScroller = YES;
    recvScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.receivedClipboardTextView = [[NSTextView alloc] initWithFrame:recvScroll.bounds];
    self.receivedClipboardTextView.editable = NO;
    self.receivedClipboardTextView.font = [NSFont systemFontOfSize:13];
    recvScroll.documentView = self.receivedClipboardTextView;
    [self.deviceView addSubview:recvScroll];
}

#pragma mark - Tab 5: ⚙️ Ayarlar (System Settings Style)

- (void)setupSettingsTab {
    self.settingsView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 28;

    NSTextField *tabTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.settingsView.bounds.size.height - 50, 300, 28)];
    tabTitle.stringValue = @"Ayarlar ve Tercihler";
    tabTitle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    tabTitle.textColor = [NSColor labelColor];
    tabTitle.editable = NO;
    tabTitle.bordered = NO;
    tabTitle.backgroundColor = [NSColor clearColor];
    tabTitle.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:tabTitle];

    CGFloat optY = self.settingsView.bounds.size.height - 110;

    self.checkFilterMedia = [NSButton checkboxWithTitle:@"Müzik çalar bildirimlerini sessize al ve filtrele (Spotify, Deezer vb.)" target:nil action:nil];
    self.checkFilterMedia.frame = NSMakeRect(pad, optY, 540, 24);
    self.checkFilterMedia.state = NSControlStateValueOn;
    self.checkFilterMedia.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.checkFilterMedia.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:self.checkFilterMedia];

    optY -= 42;
    self.checkAutoRaiseOnCall = [NSButton checkboxWithTitle:@"Gelen arama olduğunda MacConnect penceresini otomatik öne getir" target:nil action:nil];
    self.checkAutoRaiseOnCall.frame = NSMakeRect(pad, optY, 540, 24);
    self.checkAutoRaiseOnCall.state = NSControlStateValueOn;
    self.checkAutoRaiseOnCall.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.checkAutoRaiseOnCall.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:self.checkAutoRaiseOnCall];

    optY -= 42;
    self.checkPlaySound = [NSButton checkboxWithTitle:@"Bildirim geldiğinde yerel sistem sesini çal" target:nil action:nil];
    self.checkPlaySound.frame = NSMakeRect(pad, optY, 540, 24);
    self.checkPlaySound.state = NSControlStateValueOn;
    self.checkPlaySound.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.checkPlaySound.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:self.checkPlaySound];

    optY -= 75;
    NSTextField *aboutBox = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, optY, 540, 60)];
    aboutBox.stringValue = @"MacConnect v1.0.2 • Native macOS Sequoia Entegrasyonu\nDoğrudan donanım seviyesinde Bluetooth RFCOMM köprüsü ile telefon ve Mac senkronizasyonu.\nGeliştirici: canmertdogan";
    aboutBox.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    aboutBox.textColor = [NSColor secondaryLabelColor];
    aboutBox.editable = NO;
    aboutBox.bordered = NO;
    aboutBox.backgroundColor = [NSColor clearColor];
    aboutBox.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:aboutBox];
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
    for (NSView *v in self.recentCallsStackView.arrangedSubviews) {
        [self.recentCallsStackView removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    for (NSDictionary *call in self.recentCalls) {
        NSBox *itemBox = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 260, 48)];
        itemBox.boxType = NSBoxCustom;
        itemBox.cornerRadius = 8;
        itemBox.fillColor = [NSColor quaternaryLabelColor];
        itemBox.borderWidth = 1.0;
        itemBox.borderColor = [NSColor separatorColor];

        NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 22, 170, 18)];
        lbl.stringValue = call[@"name"] ?: call[@"number"];
        lbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
        lbl.textColor = [NSColor labelColor];
        lbl.editable = NO;
        lbl.bordered = NO;
        lbl.backgroundColor = [NSColor clearColor];
        [itemBox addSubview:lbl];

        NSTextField *sub = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 4, 170, 16)];
        sub.stringValue = call[@"time"] ?: @"";
        sub.font = [NSFont systemFontOfSize:10];
        sub.textColor = [NSColor secondaryLabelColor];
        sub.editable = NO;
        sub.bordered = NO;
        sub.backgroundColor = [NSColor clearColor];
        [itemBox addSubview:sub];

        NSButton *btnRedial = [NSButton buttonWithTitle:@"Ara" target:self action:@selector(redialClicked:)];
        btnRedial.frame = NSMakeRect(190, 10, 60, 26);
        btnRedial.bezelStyle = NSBezelStyleRounded;
        btnRedial.identifier = call[@"number"];
        [itemBox addSubview:btnRedial];

        [self.recentCallsStackView addArrangedSubview:itemBox];
    }
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
        self.callHeroSubtitleLabel.stringValue = @"Aşağıdaki tuş takımından doğrudan numara çevirebilir veya gelen aramaları yanıtlayabilirsiniz.";
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
    for (NSView *v in self.notificationsStackView.arrangedSubviews) {
        [self.notificationsStackView removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    for (NSDictionary *n in self.notificationsList) {
        NSString *app = n[@"app_name"] ?: @"Uygulama";
        NSString *title = n[@"title"] ?: @"";
        NSString *text = n[@"text"] ?: @"";

        NSBox *card = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, self.notificationsScrollView.bounds.size.width - 32, 74)];
        card.boxType = NSBoxCustom;
        card.cornerRadius = 10;
        card.fillColor = [NSColor controlBackgroundColor];
        card.borderWidth = 1.0;
        card.borderColor = [NSColor separatorColor];

        NSTextField *appLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 48, 220, 16)];
        appLbl.stringValue = app;
        appLbl.font = [NSFont systemFontOfSize:11 weight:NSFontWeightBold];
        appLbl.textColor = [NSColor controlAccentColor];
        appLbl.editable = NO;
        appLbl.bordered = NO;
        appLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:appLbl];

        NSTextField *titleLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 28, card.bounds.size.width - 110, 18)];
        titleLbl.stringValue = title;
        titleLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
        titleLbl.textColor = [NSColor labelColor];
        titleLbl.editable = NO;
        titleLbl.bordered = NO;
        titleLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:titleLbl];

        NSTextField *textLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 8, card.bounds.size.width - 110, 18)];
        textLbl.stringValue = text;
        textLbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        textLbl.textColor = [NSColor secondaryLabelColor];
        textLbl.editable = NO;
        textLbl.bordered = NO;
        textLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:textLbl];

        NSButton *btnCopy = [NSButton buttonWithTitle:@"Kopyala" target:self action:@selector(copyNotificationClicked:)];
        btnCopy.frame = NSMakeRect(card.bounds.size.width - 86, 22, 72, 26);
        btnCopy.bezelStyle = NSBezelStyleRounded;
        btnCopy.identifier = text.length > 0 ? text : title;
        [card addSubview:btnCopy];

        [self.notificationsStackView addArrangedSubview:card];
    }
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
