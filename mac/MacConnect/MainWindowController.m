#import "MainWindowController.h"
#import "BluetoothBridge.h"

@interface MainWindowController ()

// Main Layout
@property (nonatomic, strong) NSView *sidebarView;
@property (nonatomic, strong) NSView *contentContainerView;
@property (nonatomic, strong) NSMutableArray<NSButton *> *navButtons;
@property (nonatomic, assign) NSInteger currentTabIndex;

// Sidebar Header & Footer
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
@property (nonatomic, strong) NSBox *callCardBox;
@property (nonatomic, strong) NSTextField *callCardAvatarLabel;
@property (nonatomic, strong) NSTextField *callCardTitleLabel;
@property (nonatomic, strong) NSTextField *callCardSubtitleLabel;
@property (nonatomic, strong) NSTextField *callCardStatusLabel;
@property (nonatomic, strong) NSStackView *callCardButtonStack;
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
@property (nonatomic, strong) NSTextField *notificationsCountLabel;
@property (nonatomic, strong) NSScrollView *notificationsScrollView;
@property (nonatomic, strong) NSStackView *notificationsStackView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *notificationsList;

// Media Tab Subviews
@property (nonatomic, strong) NSBox *mediaCardBox;
@property (nonatomic, strong) NSTextField *mediaAppLabel;
@property (nonatomic, strong) NSTextField *mediaTitleLabel;
@property (nonatomic, strong) NSTextField *mediaArtistLabel;
@property (nonatomic, strong) NSTextField *mediaBadgeLabel;
@property (nonatomic, strong) NSImageView *mediaAppIconView;

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
    NSRect frame = NSMakeRect(150, 150, 920, 580);
    NSWindowStyleMask style = (NSWindowStyleMaskTitled |
                               NSWindowStyleMaskClosable |
                               NSWindowStyleMaskMiniaturizable |
                               NSWindowStyleMaskResizable);
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
        window.minSize = NSMakeSize(800, 500);
        window.delegate = self;
        window.backgroundColor = [NSColor colorWithCalibratedRed:0.06 green:0.06 blue:0.08 alpha:1.0];

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
    // Hide window instead of terminating app (keeps background Bluetooth bridge alive)
    [self.window orderOut:nil];
    return NO;
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *root = self.window.contentView;
    root.wantsLayer = YES;

    // 1. Sidebar (Navbar)
    NSRect sidebarRect = NSMakeRect(0, 0, 220, root.bounds.size.height);
    self.sidebarView = [[NSView alloc] initWithFrame:sidebarRect];
    self.sidebarView.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    self.sidebarView.wantsLayer = YES;
    self.sidebarView.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.10 blue:0.13 alpha:1.0].CGColor;
    [root addSubview:self.sidebarView];

    [self setupSidebar];

    // 2. Content Container
    NSRect contentRect = NSMakeRect(220, 0, root.bounds.size.width - 220, root.bounds.size.height);
    self.contentContainerView = [[NSView alloc] initWithFrame:contentRect];
    self.contentContainerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.contentContainerView.wantsLayer = YES;
    self.contentContainerView.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.06 green:0.06 blue:0.08 alpha:1.0].CGColor;
    [root addSubview:self.contentContainerView];

    // 3. Build Tab Views
    [self setupCallsTab];
    [self setupNotificationsTab];
    [self setupMediaTab];
    [self setupDeviceTab];
    [self setupSettingsTab];

    // Default Tab: Aramalar (Calls)
    [self selectTab:0];
}

#pragma mark - Sidebar Setup

- (void)setupSidebar {
    CGFloat w = 220;
    CGFloat h = self.sidebarView.bounds.size.height;

    // Header: App Logo & Title
    NSImageView *logoView = [[NSImageView alloc] initWithFrame:NSMakeRect(20, h - 55, 36, 36)];
    logoView.image = [NSImage imageNamed:NSImageNameApplicationIcon];
    logoView.autoresizingMask = NSViewMinYMargin;
    [self.sidebarView addSubview:logoView];

    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(64, h - 45, 140, 24)];
    titleLabel.stringValue = @"MacConnect";
    titleLabel.font = [NSFont systemFontOfSize:17 weight:NSFontWeightBold];
    titleLabel.textColor = [NSColor whiteColor];
    titleLabel.editable = NO;
    titleLabel.bordered = NO;
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.autoresizingMask = NSViewMinYMargin;
    [self.sidebarView addSubview:titleLabel];

    // Connection Status Pill
    self.sidebarStatusDot = [[NSView alloc] initWithFrame:NSMakeRect(22, h - 80, 8, 8)];
    self.sidebarStatusDot.wantsLayer = YES;
    self.sidebarStatusDot.layer.cornerRadius = 4;
    self.sidebarStatusDot.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.94 green:0.27 blue:0.27 alpha:1.0].CGColor;
    self.sidebarStatusDot.autoresizingMask = NSViewMinYMargin;
    [self.sidebarView addSubview:self.sidebarStatusDot];

    self.sidebarStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(36, h - 85, 170, 18)];
    self.sidebarStatusLabel.stringValue = @"Bağlantı Yok";
    self.sidebarStatusLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.sidebarStatusLabel.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    self.sidebarStatusLabel.editable = NO;
    self.sidebarStatusLabel.bordered = NO;
    self.sidebarStatusLabel.backgroundColor = [NSColor clearColor];
    self.sidebarStatusLabel.autoresizingMask = NSViewMinYMargin;
    [self.sidebarView addSubview:self.sidebarStatusLabel];

    // Navigation Buttons Stack
    NSArray *titles = @[
        @"📞  Aramalar",
        @"🔔  Bildirimler",
        @"🎵  Şimdi Çalıyor",
        @"📱  Cihaz & Pano",
        @"⚙️  Ayarlar"
    ];

    CGFloat btnY = h - 130;
    for (NSInteger i = 0; i < titles.count; i++) {
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(14, btnY, w - 28, 36)];
        btn.title = titles[i];
        btn.bezelStyle = NSBezelStyleRegularSquare;
        btn.wantsLayer = YES;
        btn.layer.cornerRadius = 6;
        btn.alignment = NSTextAlignmentLeft;
        btn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        btn.tag = i;
        btn.target = self;
        btn.action = @selector(navButtonClicked:);
        btn.autoresizingMask = NSViewMinYMargin;
        [self.sidebarView addSubview:btn];
        [self.navButtons addObject:btn];

        btnY -= 42;
    }

    // Bottom: Battery Indicator & Connect Button
    self.sidebarBatteryLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 55, w - 36, 18)];
    self.sidebarBatteryLabel.stringValue = @"🔋 Pil: --";
    self.sidebarBatteryLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.sidebarBatteryLabel.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    self.sidebarBatteryLabel.editable = NO;
    self.sidebarBatteryLabel.bordered = NO;
    self.sidebarBatteryLabel.backgroundColor = [NSColor clearColor];
    self.sidebarBatteryLabel.autoresizingMask = NSViewMaxYMargin;
    [self.sidebarView addSubview:self.sidebarBatteryLabel];

    self.sidebarConnectButton = [[NSButton alloc] initWithFrame:NSMakeRect(14, 16, w - 28, 30)];
    self.sidebarConnectButton.title = @"Telefona Bağlan";
    self.sidebarConnectButton.bezelStyle = NSBezelStyleRounded;
    self.sidebarConnectButton.target = self;
    self.sidebarConnectButton.action = @selector(toggleConnectionClicked:);
    self.sidebarConnectButton.autoresizingMask = NSViewMaxYMargin;
    [self.sidebarView addSubview:self.sidebarConnectButton];
}

- (void)navButtonClicked:(NSButton *)sender {
    [self selectTab:sender.tag];
}

- (void)selectTab:(NSInteger)index {
    self.currentTabIndex = index;

    // Update button styles
    for (NSButton *btn in self.navButtons) {
        if (btn.tag == index) {
            btn.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.32 alpha:1.0].CGColor;
            btn.contentTintColor = [NSColor whiteColor];
        } else {
            btn.layer.backgroundColor = [NSColor clearColor].CGColor;
            btn.contentTintColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
        }
    }

    // Switch container view
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

#pragma mark - Calls Tab (Dialer & Incoming / Active Call Panel)

- (void)setupCallsTab {
    self.callsView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];

    CGFloat topH = 150;
    CGFloat pad = 20;

    // Top: Active / Incoming Call Box
    self.callCardBox = [[NSBox alloc] initWithFrame:NSMakeRect(pad, self.callsView.bounds.size.height - topH - pad, self.callsView.bounds.size.width - (pad * 2), topH)];
    self.callCardBox.boxType = NSBoxCustom;
    self.callCardBox.cornerRadius = 10;
    self.callCardBox.borderWidth = 1.0;
    self.callCardBox.borderColor = [NSColor colorWithCalibratedRed:0.25 green:0.25 blue:0.30 alpha:1.0];
    self.callCardBox.fillColor = [NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.15 alpha:1.0];
    self.callCardBox.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.callsView addSubview:self.callCardBox];

    // Call Avatar Icon
    self.callCardAvatarLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, topH - 65, 46, 46)];
    self.callCardAvatarLabel.stringValue = @"📞";
    self.callCardAvatarLabel.font = [NSFont systemFontOfSize:32];
    self.callCardAvatarLabel.alignment = NSTextAlignmentCenter;
    self.callCardAvatarLabel.editable = NO;
    self.callCardAvatarLabel.bordered = NO;
    self.callCardAvatarLabel.backgroundColor = [NSColor clearColor];
    [self.callCardBox addSubview:self.callCardAvatarLabel];

    // Call Title Label
    self.callCardTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(70, topH - 45, self.callCardBox.bounds.size.width - 80, 26)];
    self.callCardTitleLabel.stringValue = @"Aktif Arama Yok";
    self.callCardTitleLabel.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
    self.callCardTitleLabel.textColor = [NSColor whiteColor];
    self.callCardTitleLabel.editable = NO;
    self.callCardTitleLabel.bordered = NO;
    self.callCardTitleLabel.backgroundColor = [NSColor clearColor];
    self.callCardTitleLabel.autoresizingMask = NSViewWidthSizable;
    [self.callCardBox addSubview:self.callCardTitleLabel];

    // Call Subtitle Label
    self.callCardSubtitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(70, topH - 68, self.callCardBox.bounds.size.width - 80, 18)];
    self.callCardSubtitleLabel.stringValue = @"Aşağıdaki tuş takımından numara arayabilir veya gelen aramaları yanıtlayabilirsiniz.";
    self.callCardSubtitleLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    self.callCardSubtitleLabel.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.callCardSubtitleLabel.editable = NO;
    self.callCardSubtitleLabel.bordered = NO;
    self.callCardSubtitleLabel.backgroundColor = [NSColor clearColor];
    self.callCardSubtitleLabel.autoresizingMask = NSViewWidthSizable;
    [self.callCardBox addSubview:self.callCardSubtitleLabel];

    // Call Action Buttons (shown when call is ringing or active)
    self.callCardButtonStack = [[NSStackView alloc] initWithFrame:NSMakeRect(70, 16, self.callCardBox.bounds.size.width - 90, 36)];
    self.callCardButtonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.callCardButtonStack.spacing = 10;
    self.callCardButtonStack.distribution = NSStackViewDistributionFillEqually;
    self.callCardButtonStack.autoresizingMask = NSViewWidthSizable;
    [self.callCardBox addSubview:self.callCardButtonStack];

    self.btnAnswerCall = [NSButton buttonWithTitle:@"📞 Cevapla" target:self action:@selector(actionAnswerClicked:)];
    self.btnAnswerCall.bezelStyle = NSBezelStyleRounded;
    self.btnAnswerCall.contentTintColor = [NSColor colorWithCalibratedRed:0.2 green:0.8 blue:0.3 alpha:1.0];
    [self.callCardButtonStack addArrangedSubview:self.btnAnswerCall];

    self.btnAnswerSpeakerCall = [NSButton buttonWithTitle:@"🔊 Hoparlörle Aç" target:self action:@selector(actionAnswerSpeakerClicked:)];
    self.btnAnswerSpeakerCall.bezelStyle = NSBezelStyleRounded;
    self.btnAnswerSpeakerCall.contentTintColor = [NSColor colorWithCalibratedRed:0.3 green:0.6 blue:0.9 alpha:1.0];
    [self.callCardButtonStack addArrangedSubview:self.btnAnswerSpeakerCall];

    self.btnTransferComputerCall = [NSButton buttonWithTitle:@"💻 Bilgisayara Al" target:self action:@selector(actionTransferComputerClicked:)];
    self.btnTransferComputerCall.bezelStyle = NSBezelStyleRounded;
    self.btnTransferComputerCall.contentTintColor = [NSColor colorWithCalibratedRed:0.7 green:0.4 blue:0.9 alpha:1.0];
    [self.callCardButtonStack addArrangedSubview:self.btnTransferComputerCall];

    self.btnRejectCall = [NSButton buttonWithTitle:@"❌ Reddet / Kapat" target:self action:@selector(actionRejectClicked:)];
    self.btnRejectCall.bezelStyle = NSBezelStyleRounded;
    self.btnRejectCall.contentTintColor = [NSColor colorWithCalibratedRed:0.9 green:0.3 blue:0.3 alpha:1.0];
    [self.callCardButtonStack addArrangedSubview:self.btnRejectCall];

    // Hide call buttons by default when idle
    self.callCardButtonStack.hidden = YES;

    // Bottom Left: Dialer & Keypad (width: 320)
    CGFloat lowerH = self.callsView.bounds.size.height - topH - (pad * 3);
    NSBox *dialerBox = [[NSBox alloc] initWithFrame:NSMakeRect(pad, pad, 330, lowerH)];
    dialerBox.boxType = NSBoxCustom;
    dialerBox.cornerRadius = 10;
    dialerBox.borderWidth = 1.0;
    dialerBox.borderColor = [NSColor colorWithCalibratedRed:0.25 green:0.25 blue:0.30 alpha:1.0];
    dialerBox.fillColor = [NSColor colorWithCalibratedRed:0.10 green:0.10 blue:0.12 alpha:1.0];
    dialerBox.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [self.callsView addSubview:dialerBox];

    // Number Input Field & Backspace
    self.dialerNumberField = [[NSTextField alloc] initWithFrame:NSMakeRect(16, lowerH - 50, 240, 36)];
    self.dialerNumberField.placeholderString = @"Numara tuşlayın...";
    self.dialerNumberField.font = [NSFont monospacedDigitSystemFontOfSize:20 weight:NSFontWeightBold];
    self.dialerNumberField.textColor = [NSColor whiteColor];
    self.dialerNumberField.backgroundColor = [NSColor colorWithCalibratedRed:0.15 green:0.15 blue:0.18 alpha:1.0];
    self.dialerNumberField.bordered = YES;
    self.dialerNumberField.focusRingType = NSFocusRingTypeNone;
    [dialerBox addSubview:self.dialerNumberField];

    NSButton *btnBackspace = [NSButton buttonWithTitle:@"⌫" target:self action:@selector(dialerBackspaceClicked:)];
    btnBackspace.frame = NSMakeRect(262, lowerH - 50, 48, 36);
    btnBackspace.bezelStyle = NSBezelStyleRounded;
    btnBackspace.font = [NSFont systemFontOfSize:18];
    [dialerBox addSubview:btnBackspace];

    // 3x4 Dialpad Grid
    NSArray *keys = @[
        @"1", @"2", @"3",
        @"4", @"5", @"6",
        @"7", @"8", @"9",
        @"*", @"0", @"#"
    ];

    CGFloat keyW = 86;
    CGFloat keyH = 40;
    CGFloat gridStartX = 18;
    CGFloat gridStartY = lowerH - 105;

    for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 3; c++) {
            int idx = r * 3 + c;
            NSString *digit = keys[idx];
            NSButton *keyBtn = [[NSButton alloc] initWithFrame:NSMakeRect(gridStartX + (c * (keyW + 12)), gridStartY - (r * (keyH + 10)), keyW, keyH)];
            keyBtn.title = digit;
            keyBtn.bezelStyle = NSBezelStyleRegularSquare;
            keyBtn.wantsLayer = YES;
            keyBtn.layer.cornerRadius = 6;
            keyBtn.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.16 green:0.16 blue:0.20 alpha:1.0].CGColor;
            keyBtn.font = [NSFont systemFontOfSize:18 weight:NSFontWeightMedium];
            keyBtn.contentTintColor = [NSColor whiteColor];
            keyBtn.target = self;
            keyBtn.action = @selector(dialerDigitClicked:);
            [dialerBox addSubview:keyBtn];
        }
    }

    // Big Green "📞 Ara" Button
    NSButton *btnCall = [NSButton buttonWithTitle:@"📞 Aramayı Başlat" target:self action:@selector(dialerCallClicked:)];
    btnCall.frame = NSMakeRect(18, 14, 286, 42);
    btnCall.bezelStyle = NSBezelStyleRounded;
    btnCall.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    btnCall.contentTintColor = [NSColor colorWithCalibratedRed:0.1 green:0.85 blue:0.3 alpha:1.0];
    [dialerBox addSubview:btnCall];

    // Bottom Right: Son Aramalar (Recent Calls) List
    CGFloat recentX = pad + 330 + 16;
    CGFloat recentW = self.callsView.bounds.size.width - recentX - pad;
    NSBox *recentBox = [[NSBox alloc] initWithFrame:NSMakeRect(recentX, pad, recentW, lowerH)];
    recentBox.boxType = NSBoxCustom;
    recentBox.cornerRadius = 10;
    recentBox.borderWidth = 1.0;
    recentBox.borderColor = [NSColor colorWithCalibratedRed:0.25 green:0.25 blue:0.30 alpha:1.0];
    recentBox.fillColor = [NSColor colorWithCalibratedRed:0.10 green:0.10 blue:0.12 alpha:1.0];
    recentBox.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.callsView addSubview:recentBox];

    NSTextField *recentTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, lowerH - 35, recentW - 32, 22)];
    recentTitle.stringValue = @"Son Aramalar";
    recentTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    recentTitle.textColor = [NSColor whiteColor];
    recentTitle.editable = NO;
    recentTitle.bordered = NO;
    recentTitle.backgroundColor = [NSColor clearColor];
    [recentBox addSubview:recentTitle];

    self.recentCallsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(12, 12, recentW - 24, lowerH - 52)];
    self.recentCallsScrollView.hasVerticalScroller = YES;
    self.recentCallsScrollView.drawsBackground = NO;
    self.recentCallsScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [recentBox addSubview:self.recentCallsScrollView];

    NSView *recentDocView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, recentW - 24, 100)];
    recentDocView.autoresizingMask = NSViewWidthSizable;
    self.recentCallsScrollView.documentView = recentDocView;

    self.recentCallsStackView = [[NSStackView alloc] initWithFrame:recentDocView.bounds];
    self.recentCallsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.recentCallsStackView.alignment = NSLayoutAttributeLeading;
    self.recentCallsStackView.spacing = 8;
    self.recentCallsStackView.autoresizingMask = NSViewWidthSizable;
    [recentDocView addSubview:self.recentCallsStackView];
}

#pragma mark - Notifications Tab

- (void)setupNotificationsTab {
    self.notificationsView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 20;

    // Header
    NSTextField *headerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.notificationsView.bounds.size.height - 45, 200, 26)];
    headerTitle.stringValue = @"Bildirimler";
    headerTitle.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
    headerTitle.textColor = [NSColor whiteColor];
    headerTitle.editable = NO;
    headerTitle.bordered = NO;
    headerTitle.backgroundColor = [NSColor clearColor];
    headerTitle.autoresizingMask = NSViewMinYMargin;
    [self.notificationsView addSubview:headerTitle];

    self.notificationsCountLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(140, self.notificationsView.bounds.size.height - 43, 100, 20)];
    self.notificationsCountLabel.stringValue = @"(0)";
    self.notificationsCountLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.notificationsCountLabel.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    self.notificationsCountLabel.editable = NO;
    self.notificationsCountLabel.bordered = NO;
    self.notificationsCountLabel.backgroundColor = [NSColor clearColor];
    self.notificationsCountLabel.autoresizingMask = NSViewMinYMargin;
    [self.notificationsView addSubview:self.notificationsCountLabel];

    NSButton *btnClear = [NSButton buttonWithTitle:@"Tümünü Temizle" target:self action:@selector(clearAllNotificationsClicked:)];
    btnClear.frame = NSMakeRect(self.notificationsView.bounds.size.width - 160, self.notificationsView.bounds.size.height - 45, 140, 26);
    btnClear.bezelStyle = NSBezelStyleRounded;
    btnClear.autoresizingMask = NSViewMinYMargin | NSViewMinXMargin;
    [self.notificationsView addSubview:btnClear];

    // Scrollable Notifications List
    CGFloat listH = self.notificationsView.bounds.size.height - 70;
    self.notificationsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(pad, 16, self.notificationsView.bounds.size.width - (pad * 2), listH)];
    self.notificationsScrollView.hasVerticalScroller = YES;
    self.notificationsScrollView.drawsBackground = NO;
    self.notificationsScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.notificationsView addSubview:self.notificationsScrollView];

    NSView *notifDocView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, self.notificationsScrollView.bounds.size.width, 100)];
    notifDocView.autoresizingMask = NSViewWidthSizable;
    self.notificationsScrollView.documentView = notifDocView;

    self.notificationsStackView = [[NSStackView alloc] initWithFrame:notifDocView.bounds];
    self.notificationsStackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.notificationsStackView.alignment = NSLayoutAttributeLeading;
    self.notificationsStackView.spacing = 10;
    self.notificationsStackView.autoresizingMask = NSViewWidthSizable;
    [notifDocView addSubview:self.notificationsStackView];
}

#pragma mark - Media Tab (Now Playing)

- (void)setupMediaTab {
    self.mediaView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 25;

    // Header
    NSTextField *headerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.mediaView.bounds.size.height - 50, 300, 26)];
    headerTitle.stringValue = @"Şimdi Çalıyor (Medya)";
    headerTitle.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
    headerTitle.textColor = [NSColor whiteColor];
    headerTitle.editable = NO;
    headerTitle.bordered = NO;
    headerTitle.backgroundColor = [NSColor clearColor];
    headerTitle.autoresizingMask = NSViewMinYMargin;
    [self.mediaView addSubview:headerTitle];

    // Media Card Box
    CGFloat cardW = self.mediaView.bounds.size.width - (pad * 2);
    CGFloat cardH = 260;
    self.mediaCardBox = [[NSBox alloc] initWithFrame:NSMakeRect(pad, self.mediaView.bounds.size.height - cardH - 70, cardW, cardH)];
    self.mediaCardBox.boxType = NSBoxCustom;
    self.mediaCardBox.cornerRadius = 12;
    self.mediaCardBox.borderWidth = 1.0;
    self.mediaCardBox.borderColor = [NSColor colorWithCalibratedRed:0.25 green:0.25 blue:0.32 alpha:1.0];
    self.mediaCardBox.fillColor = [NSColor colorWithCalibratedRed:0.11 green:0.11 blue:0.14 alpha:1.0];
    self.mediaCardBox.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.mediaView addSubview:self.mediaCardBox];

    // App Badge
    self.mediaAppLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(24, cardH - 45, 200, 20)];
    self.mediaAppLabel.stringValue = @"🎵 Müzik Çalar";
    self.mediaAppLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    self.mediaAppLabel.textColor = [NSColor colorWithCalibratedRed:0.3 green:0.8 blue:0.5 alpha:1.0];
    self.mediaAppLabel.editable = NO;
    self.mediaAppLabel.bordered = NO;
    self.mediaAppLabel.backgroundColor = [NSColor clearColor];
    [self.mediaCardBox addSubview:self.mediaAppLabel];

    // Title & Artist
    self.mediaTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(24, cardH - 95, cardW - 48, 36)];
    self.mediaTitleLabel.stringValue = @"Şu anda çalan parça yok";
    self.mediaTitleLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    self.mediaTitleLabel.textColor = [NSColor whiteColor];
    self.mediaTitleLabel.editable = NO;
    self.mediaTitleLabel.bordered = NO;
    self.mediaTitleLabel.backgroundColor = [NSColor clearColor];
    [self.mediaCardBox addSubview:self.mediaTitleLabel];

    self.mediaArtistLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(24, cardH - 130, cardW - 48, 24)];
    self.mediaArtistLabel.stringValue = @"Spotify veya Deezer'dan müzik başlattığınızda burada görünecektir.";
    self.mediaArtistLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightRegular];
    self.mediaArtistLabel.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    self.mediaArtistLabel.editable = NO;
    self.mediaArtistLabel.bordered = NO;
    self.mediaArtistLabel.backgroundColor = [NSColor clearColor];
    [self.mediaCardBox addSubview:self.mediaArtistLabel];

    self.mediaBadgeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(24, 25, 120, 26)];
    self.mediaBadgeLabel.stringValue = @"▶ Oynatılıyor";
    self.mediaBadgeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
    self.mediaBadgeLabel.textColor = [NSColor colorWithCalibratedRed:0.2 green:0.85 blue:0.4 alpha:1.0];
    self.mediaBadgeLabel.editable = NO;
    self.mediaBadgeLabel.bordered = NO;
    self.mediaBadgeLabel.backgroundColor = [NSColor clearColor];
    [self.mediaCardBox addSubview:self.mediaBadgeLabel];

    // Explanatory Note below Card
    NSTextField *noteLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, 40, cardW, 60)];
    noteLabel.stringValue = @"💡 Müzik Çalar Akıllı Filtresi:\nSpotify, Deezer ve YouTube Music gibi uygulamaların sürekli değişen şarkı bildirimleri Mac masaüstünüzü spamlamaz. Parça bilgisi sessizce bu ekranda güncellenir.";
    noteLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    noteLabel.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    noteLabel.editable = NO;
    noteLabel.bordered = NO;
    noteLabel.backgroundColor = [NSColor clearColor];
    noteLabel.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [self.mediaView addSubview:noteLabel];
}

#pragma mark - Device & Clipboard Tab

- (void)setupDeviceTab {
    self.deviceView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 25;

    // Header
    NSTextField *headerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.deviceView.bounds.size.height - 45, 300, 26)];
    headerTitle.stringValue = @"Cihaz ve Pano Senkronizasyonu";
    headerTitle.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
    headerTitle.textColor = [NSColor whiteColor];
    headerTitle.editable = NO;
    headerTitle.bordered = NO;
    headerTitle.backgroundColor = [NSColor clearColor];
    headerTitle.autoresizingMask = NSViewMinYMargin;
    [self.deviceView addSubview:headerTitle];

    // Device Info Card
    CGFloat cardW = self.deviceView.bounds.size.width - (pad * 2);
    NSBox *infoBox = [[NSBox alloc] initWithFrame:NSMakeRect(pad, self.deviceView.bounds.size.height - 180, cardW, 120)];
    infoBox.boxType = NSBoxCustom;
    infoBox.cornerRadius = 10;
    infoBox.borderWidth = 1.0;
    infoBox.borderColor = [NSColor colorWithCalibratedRed:0.25 green:0.25 blue:0.30 alpha:1.0];
    infoBox.fillColor = [NSColor colorWithCalibratedRed:0.11 green:0.11 blue:0.13 alpha:1.0];
    infoBox.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.deviceView addSubview:infoBox];

    self.deviceModelLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 75, cardW - 40, 24)];
    self.deviceModelLabel.stringValue = @"Cihaz: Telefon Bekleniyor...";
    self.deviceModelLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    self.deviceModelLabel.textColor = [NSColor whiteColor];
    self.deviceModelLabel.editable = NO;
    self.deviceModelLabel.bordered = NO;
    self.deviceModelLabel.backgroundColor = [NSColor clearColor];
    [infoBox addSubview:self.deviceModelLabel];

    self.deviceStatusFullLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 48, cardW - 40, 20)];
    self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (Bağlantı Yok)";
    self.deviceStatusFullLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.deviceStatusFullLabel.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    self.deviceStatusFullLabel.editable = NO;
    self.deviceStatusFullLabel.bordered = NO;
    self.deviceStatusFullLabel.backgroundColor = [NSColor clearColor];
    [infoBox addSubview:self.deviceStatusFullLabel];

    self.deviceBatteryFullLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, cardW - 40, 20)];
    self.deviceBatteryFullLabel.stringValue = @"Pil Durumu: --";
    self.deviceBatteryFullLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.deviceBatteryFullLabel.textColor = [NSColor colorWithCalibratedWhite:0.7 alpha:1.0];
    self.deviceBatteryFullLabel.editable = NO;
    self.deviceBatteryFullLabel.bordered = NO;
    self.deviceBatteryFullLabel.backgroundColor = [NSColor clearColor];
    [infoBox addSubview:self.deviceBatteryFullLabel];

    // Clipboard Section
    CGFloat clipY = self.deviceView.bounds.size.height - 350;
    NSTextField *clipTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, clipY + 135, cardW, 22)];
    clipTitle.stringValue = @"Telefona Metin Gönder (Pano Eşitleme)";
    clipTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    clipTitle.textColor = [NSColor whiteColor];
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

    // Received Clipboard Section
    NSTextField *recvTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, clipY - 35, cardW, 22)];
    recvTitle.stringValue = @"Telefondan Alınan Son Pano İçeriği";
    recvTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    recvTitle.textColor = [NSColor whiteColor];
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

#pragma mark - Settings Tab

- (void)setupSettingsTab {
    self.settingsView = [[NSView alloc] initWithFrame:self.contentContainerView.bounds];
    CGFloat pad = 30;

    NSTextField *headerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, self.settingsView.bounds.size.height - 50, 300, 26)];
    headerTitle.stringValue = @"Ayarlar ve Tercihler";
    headerTitle.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
    headerTitle.textColor = [NSColor whiteColor];
    headerTitle.editable = NO;
    headerTitle.bordered = NO;
    headerTitle.backgroundColor = [NSColor clearColor];
    headerTitle.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:headerTitle];

    CGFloat optY = self.settingsView.bounds.size.height - 100;

    self.checkFilterMedia = [NSButton checkboxWithTitle:@"Müzik çalar bildirimlerini sessize al ve filtrele (Spotify, Deezer vb.)" target:nil action:nil];
    self.checkFilterMedia.frame = NSMakeRect(pad, optY, 500, 22);
    self.checkFilterMedia.state = NSControlStateValueOn;
    self.checkFilterMedia.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:self.checkFilterMedia];

    optY -= 40;
    self.checkAutoRaiseOnCall = [NSButton checkboxWithTitle:@"Arama geldiğinde MacConnect penceresini otomatik öne getir" target:nil action:nil];
    self.checkAutoRaiseOnCall.frame = NSMakeRect(pad, optY, 500, 22);
    self.checkAutoRaiseOnCall.state = NSControlStateValueOn;
    self.checkAutoRaiseOnCall.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:self.checkAutoRaiseOnCall];

    optY -= 40;
    self.checkPlaySound = [NSButton checkboxWithTitle:@"Gelen bildirimlerde sistem sesini çal" target:nil action:nil];
    self.checkPlaySound.frame = NSMakeRect(pad, optY, 500, 22);
    self.checkPlaySound.state = NSControlStateValueOn;
    self.checkPlaySound.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:self.checkPlaySound];

    optY -= 80;
    NSTextField *aboutLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, optY, 500, 50)];
    aboutLabel.stringValue = @"MacConnect v1.0.2\nDoğrudan Bluetooth RFCOMM köprüsü ile macOS ve Android entegrasyonu.\nGeliştirici: canmertdogan";
    aboutLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    aboutLabel.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    aboutLabel.editable = NO;
    aboutLabel.bordered = NO;
    aboutLabel.backgroundColor = [NSColor clearColor];
    aboutLabel.autoresizingMask = NSViewMinYMargin;
    [self.settingsView addSubview:aboutLabel];
}

#pragma mark - Call Action Handlers

- (void)actionAnswerClicked:(id)sender {
    [[BluetoothBridge sharedBridge] sendCallAction:@"answer"];
    self.callCardStatusLabel.stringValue = @"Görüşme Açıldı (Telefonda)";
}

- (void)actionAnswerSpeakerClicked:(id)sender {
    [[BluetoothBridge sharedBridge] sendCallAction:@"answer_speaker"];
    self.callCardTitleLabel.stringValue = @"🔊 Hoparlör Açık (Eller Serbest)";
    self.callCardSubtitleLabel.stringValue = @"Telefon hoparlörü devrede. Masadan konuşabilirsiniz.";
}

- (void)actionTransferComputerClicked:(id)sender {
    [[BluetoothBridge sharedBridge] sendCallAction:@"transfer_computer"];
    self.callCardTitleLabel.stringValue = @"💻 Bilgisayar Masası Modu";
    self.callCardSubtitleLabel.stringValue = @"Telefon eller serbest iletişim moduna alındı. Görüşmeyi masanızdan sürdürebilirsiniz.";
}

- (void)actionRejectClicked:(id)sender {
    [[BluetoothBridge sharedBridge] sendCallAction:@"reject"];
    [self dismissIncomingCall];
}

- (void)dialerDigitClicked:(NSButton *)sender {
    NSString *curr = self.dialerNumberField.stringValue ?: @"";
    self.dialerNumberField.stringValue = [curr stringByAppendingString:sender.title];
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

    // Add to recent calls list
    NSDictionary *entry = @{
        @"name": number,
        @"number": number,
        @"time": @"Az önce (Giden Arama)"
    };
    [self.recentCalls insertObject:entry atIndex:0];
    [self rebuildRecentCallsStack];

    self.callCardBox.fillColor = [NSColor colorWithCalibratedRed:0.10 green:0.22 blue:0.15 alpha:1.0];
    self.callCardTitleLabel.stringValue = [NSString stringWithFormat:@"📞 Aranıyor: %@", number];
    self.callCardSubtitleLabel.stringValue = @"Arama komutu telefona iletildi.";
    self.callCardButtonStack.hidden = NO;
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
        NSBox *itemBox = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 240, 48)];
        itemBox.boxType = NSBoxCustom;
        itemBox.cornerRadius = 6;
        itemBox.fillColor = [NSColor colorWithCalibratedRed:0.14 green:0.14 blue:0.18 alpha:1.0];
        itemBox.borderWidth = 0;

        NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 22, 160, 18)];
        lbl.stringValue = call[@"name"] ?: call[@"number"];
        lbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightBold];
        lbl.textColor = [NSColor whiteColor];
        lbl.editable = NO;
        lbl.bordered = NO;
        lbl.backgroundColor = [NSColor clearColor];
        [itemBox addSubview:lbl];

        NSTextField *sub = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 4, 160, 16)];
        sub.stringValue = call[@"time"] ?: @"";
        sub.font = [NSFont systemFontOfSize:10];
        sub.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
        sub.editable = NO;
        sub.bordered = NO;
        sub.backgroundColor = [NSColor clearColor];
        [itemBox addSubview:sub];

        NSButton *btnRedial = [NSButton buttonWithTitle:@"Ara" target:self action:@selector(redialClicked:)];
        btnRedial.frame = NSMakeRect(174, 10, 56, 26);
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

        self.callCardBox.fillColor = [NSColor colorWithCalibratedRed:0.25 green:0.12 blue:0.14 alpha:1.0];
        self.callCardAvatarLabel.stringValue = @"🔔";
        self.callCardTitleLabel.stringValue = [NSString stringWithFormat:@"Gelen Arama: %@", name];
        self.callCardSubtitleLabel.stringValue = [NSString stringWithFormat:@"%@ • %@", number, appName];

        self.callCardButtonStack.hidden = NO;
        self.btnAnswerCall.hidden = NO;
        self.btnAnswerSpeakerCall.hidden = NO;
        self.btnTransferComputerCall.hidden = NO;
        self.btnRejectCall.hidden = NO;

        // Auto bring window to front if enabled in settings
        if (self.checkAutoRaiseOnCall.state == NSControlStateValueOn) {
            [self showWindowAndActivate];
            [self selectTab:0];
        }
    });
}

- (void)dismissIncomingCall {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.activeCallInfo = nil;
        self.callCardBox.fillColor = [NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.15 alpha:1.0];
        self.callCardAvatarLabel.stringValue = @"📞";
        self.callCardTitleLabel.stringValue = @"Aktif Arama Yok";
        self.callCardSubtitleLabel.stringValue = @"Aşağıdaki tuş takımından numara arayabilir veya gelen aramaları yanıtlayabilirsiniz.";
        self.callCardButtonStack.hidden = YES;
    });
}

- (void)updateCallStatus:(NSString *)status message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([@"on_computer" isEqualToString:status]) {
            self.callCardTitleLabel.stringValue = @"💻 Bilgisayar Masası Modunda";
            self.callCardSubtitleLabel.stringValue = message ?: @"Hoparlör ve eller serbest iletişim devrede.";
        }
    });
}

- (void)addNotification:(NSDictionary *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.notificationsList insertObject:notification atIndex:0];
        if (self.notificationsList.count > 50) {
            [self.notificationsList removeLastObject];
        }
        self.notificationsCountLabel.stringValue = [NSString stringWithFormat:@"(%lu)", (unsigned long)self.notificationsList.count];
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

        NSBox *card = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, self.notificationsScrollView.bounds.size.width - 30, 72)];
        card.boxType = NSBoxCustom;
        card.cornerRadius = 8;
        card.fillColor = [NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.15 alpha:1.0];
        card.borderWidth = 1.0;
        card.borderColor = [NSColor colorWithCalibratedRed:0.20 green:0.20 blue:0.24 alpha:1.0];

        NSTextField *appLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 48, 200, 16)];
        appLbl.stringValue = app;
        appLbl.font = [NSFont systemFontOfSize:11 weight:NSFontWeightBold];
        appLbl.textColor = [NSColor colorWithCalibratedRed:0.3 green:0.6 blue:0.95 alpha:1.0];
        appLbl.editable = NO;
        appLbl.bordered = NO;
        appLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:appLbl];

        NSTextField *titleLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 28, card.bounds.size.width - 100, 18)];
        titleLbl.stringValue = title;
        titleLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
        titleLbl.textColor = [NSColor whiteColor];
        titleLbl.editable = NO;
        titleLbl.bordered = NO;
        titleLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:titleLbl];

        NSTextField *textLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 8, card.bounds.size.width - 100, 18)];
        textLbl.stringValue = text;
        textLbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        textLbl.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
        textLbl.editable = NO;
        textLbl.bordered = NO;
        textLbl.backgroundColor = [NSColor clearColor];
        [card addSubview:textLbl];

        NSButton *btnCopy = [NSButton buttonWithTitle:@"Kopyala" target:self action:@selector(copyNotificationClicked:)];
        btnCopy.frame = NSMakeRect(card.bounds.size.width - 80, 20, 70, 26);
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
    self.notificationsCountLabel.stringValue = @"(0)";
    [self rebuildNotificationsStack];
}

- (void)updateMediaPlayback:(NSDictionary *)mediaInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *app = mediaInfo[@"app_name"] ?: @"Müzik Çalar";
        NSString *title = mediaInfo[@"title"] ?: @"";
        NSString *artist = mediaInfo[@"artist"] ?: @"";

        self.mediaAppLabel.stringValue = [NSString stringWithFormat:@"🎵 %@", app];
        self.mediaTitleLabel.stringValue = title.length > 0 ? title : @"Parça Adı Yok";
        self.mediaArtistLabel.stringValue = artist.length > 0 ? artist : @"Sanatçı Bilgisi Yok";
        self.mediaBadgeLabel.stringValue = @"▶ Oynatılıyor";
    });
}

- (void)updateDeviceState:(MacConnectState)state name:(NSString *)name {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (state == MacConnectStateConnected) {
            NSString *dev = (name.length > 0) ? name : @"Android";
            self.sidebarStatusDot.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.18 green:0.80 blue:0.44 alpha:1.0].CGColor;
            self.sidebarStatusLabel.stringValue = [NSString stringWithFormat:@"Bağlı: %@", dev];
            self.sidebarConnectButton.title = @"Bağlantıyı Kes";
            self.deviceModelLabel.stringValue = [NSString stringWithFormat:@"Cihaz: %@", dev];
            self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (🟢 Bağlı)";
        } else if (state == MacConnectStateConnecting) {
            self.sidebarStatusDot.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.95 green:0.77 blue:0.06 alpha:1.0].CGColor;
            self.sidebarStatusLabel.stringValue = @"Bağlanıyor...";
            self.sidebarConnectButton.title = @"İptal";
            self.deviceStatusFullLabel.stringValue = @"Bağlantı: Bluetooth RFCOMM (🟡 Bağlanıyor...)";
        } else {
            self.sidebarStatusDot.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.94 green:0.27 blue:0.27 alpha:1.0].CGColor;
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
        alert.informativeText = @"Metin başarıyla telefonun panosuna gönderildi.";
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
