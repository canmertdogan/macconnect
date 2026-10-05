#import "AppDelegate.h"
#import "NotificationPresenter.h"

@interface AppDelegate ()

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong) NSMenuItem *statusMenuItem;
@property (nonatomic, strong) NSMenuItem *batteryMenuItem;
@property (nonatomic, strong) NSMenuItem *recentNotificationsMenuItem;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recentNotifications;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _recentNotifications = [[NSMutableArray alloc] init];

    // Configure status bar item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"🔴";
    self.statusItem.button.toolTip = @"MacConnect: Disconnected (Waiting for phone...)";

    [self buildMenu];

    // Initialize Notification Presenter and request system notification permissions
    [NotificationPresenter sharedPresenter];

    // Initialize Bluetooth Bridge
    BluetoothBridge *bridge = [BluetoothBridge sharedBridge];
    bridge.delegate = self;
    [bridge start];
}

- (void)buildMenu {
    self.statusMenu = [[NSMenu alloc] initWithTitle:@"MacConnect"];

    // App Title Header
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:@"MacConnect" action:nil keyEquivalent:@""];
    [headerItem setEnabled:NO];
    [self.statusMenu addItem:headerItem];

    // Connection Status
    self.statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"🔴 Disconnected (Waiting...)" action:nil keyEquivalent:@""];
    [self.statusMenuItem setEnabled:NO];
    [self.statusMenu addItem:self.statusMenuItem];

    // Battery Status
    self.batteryMenuItem = [[NSMenuItem alloc] initWithTitle:@"🔋 Battery: --" action:nil keyEquivalent:@""];
    [self.batteryMenuItem setHidden:YES];
    [self.statusMenu addItem:self.batteryMenuItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // Recent Notifications Submenu
    self.recentNotificationsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Recent Notifications (0)" action:nil keyEquivalent:@""];
    NSMenu *recentSubmenu = [[NSMenu alloc] init];
    NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"No notifications yet" action:nil keyEquivalent:@""];
    [emptyItem setEnabled:NO];
    [recentSubmenu addItem:emptyItem];
    [self.recentNotificationsMenuItem setSubmenu:recentSubmenu];
    [self.statusMenu addItem:self.recentNotificationsMenuItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // Action: Connect to Phone
    NSMenuItem *connectItem = [[NSMenuItem alloc] initWithTitle:@"Connect to Phone" action:@selector(connectToPhoneClicked:) keyEquivalent:@"c"];
    [connectItem setTarget:self];
    [self.statusMenu addItem:connectItem];

    // Action: Send Test Notification
    NSMenuItem *testItem = [[NSMenuItem alloc] initWithTitle:@"Send Test Notification" action:@selector(sendTestNotificationClicked:) keyEquivalent:@"t"];
    [testItem setTarget:self];
    [self.statusMenu addItem:testItem];

    // Action: Disconnect
    NSMenuItem *disconnectItem = [[NSMenuItem alloc] initWithTitle:@"Disconnect" action:@selector(disconnectClicked:) keyEquivalent:@"d"];
    [disconnectItem setTarget:self];
    [self.statusMenu addItem:disconnectItem];

    // Action: Open Downloads
    NSMenuItem *downloadsItem = [[NSMenuItem alloc] initWithTitle:@"Open MacConnect Downloads" action:@selector(openDownloadsClicked:) keyEquivalent:@"o"];
    [downloadsItem setTarget:self];
    [self.statusMenu addItem:downloadsItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // Action: Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit MacConnect" action:@selector(quitClicked:) keyEquivalent:@"q"];
    [quitItem setTarget:self];
    [self.statusMenu addItem:quitItem];

    self.statusItem.menu = self.statusMenu;
}

- (void)updateRecentSubmenu {
    NSMenu *recentSubmenu = [[NSMenu alloc] init];
    if (self.recentNotifications.count == 0) {
        NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"No notifications yet" action:nil keyEquivalent:@""];
        [emptyItem setEnabled:NO];
        [recentSubmenu addItem:emptyItem];
    } else {
        for (NSDictionary *notif in self.recentNotifications) {
            NSString *app = notif[@"app_name"] ? notif[@"app_name"] : @"App";
            NSString *title = notif[@"title"] ? notif[@"title"] : @"";
            NSString *text = notif[@"text"] ? notif[@"text"] : @"";

            NSString *display;
            if (title.length > 0) {
                display = [NSString stringWithFormat:@"[%@] %@: %@", app, title, text];
            } else {
                display = [NSString stringWithFormat:@"[%@] %@", app, text];
            }
            if (display.length > 50) {
                display = [NSString stringWithFormat:@"%@...", [display substringToIndex:47]];
            }

            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:display action:@selector(recentItemClicked:) keyEquivalent:@""];
            item.representedObject = notif;
            item.target = self;
            [recentSubmenu addItem:item];
        }

        [recentSubmenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *clearItem = [[NSMenuItem alloc] initWithTitle:@"Clear Recent" action:@selector(clearRecentClicked:) keyEquivalent:@""];
        clearItem.target = self;
        [recentSubmenu addItem:clearItem];
    }

    self.recentNotificationsMenuItem.title = [NSString stringWithFormat:@"Recent Notifications (%lu)", (unsigned long)self.recentNotifications.count];
    [self.recentNotificationsMenuItem setSubmenu:recentSubmenu];
}

#pragma mark - Menu Actions

- (void)connectToPhoneClicked:(id)sender {
    [[BluetoothBridge sharedBridge] connectToPairedPhone];
}

- (void)disconnectClicked:(id)sender {
    [[BluetoothBridge sharedBridge] disconnect];
}

- (void)sendTestNotificationClicked:(id)sender {
    [[NotificationPresenter sharedPresenter] presentNotificationWithAppName:@"WhatsApp"
                                                                      title:@"John Doe (Phone)"
                                                                       body:@"Hey! MacConnect notification test is working like iPhone Mirroring!"
                                                                    subText:@"Direct Bluetooth"
                                                                      sound:YES];
}

- (void)recentItemClicked:(NSMenuItem *)sender {
    NSDictionary *notif = sender.representedObject;
    if (notif) {
        NSString *text = notif[@"text"] ? notif[@"text"] : notif[@"title"];
        if (text) {
            NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
            [pasteboard clearContents];
            [pasteboard setString:text forType:NSPasteboardTypeString];
        }
    }
}

- (void)clearRecentClicked:(id)sender {
    [self.recentNotifications removeAllObjects];
    [self updateRecentSubmenu];
}

- (void)quitClicked:(id)sender {
    [[BluetoothBridge sharedBridge] stop];
    [NSApp terminate:nil];
}

#pragma mark - BluetoothBridgeDelegate

- (void)bridge:(BluetoothBridge *)bridge didChangeState:(MacConnectState)state deviceName:(NSString *)deviceName {
    if (state == MacConnectStateConnected) {
        self.statusItem.button.title = @"🟢";
        self.statusItem.button.toolTip = [NSString stringWithFormat:@"MacConnect: Connected to %@", (deviceName.length > 0 ? deviceName : @"Android")];
        self.statusMenuItem.title = [NSString stringWithFormat:@"🟢 Connected: %@", (deviceName.length > 0 ? deviceName : @"Android")];
    } else if (state == MacConnectStateConnecting) {
        self.statusItem.button.title = @"🟡";
        self.statusItem.button.toolTip = [NSString stringWithFormat:@"MacConnect: Connecting to %@...", (deviceName.length > 0 ? deviceName : @"Android")];
        self.statusMenuItem.title = [NSString stringWithFormat:@"🟡 Connecting: %@...", (deviceName.length > 0 ? deviceName : @"Android")];
    } else {
        self.statusItem.button.title = @"🔴";
        self.statusItem.button.toolTip = @"MacConnect: Disconnected (Waiting for phone...)";
        self.statusMenuItem.title = @"🔴 Disconnected (Waiting...)";
        self.batteryMenuItem.hidden = YES;
    }
}

- (void)bridge:(BluetoothBridge *)bridge didReceiveNotification:(NSDictionary *)notification {
    NSString *appName = notification[@"app_name"];
    NSString *title = notification[@"title"];
    NSString *text = notification[@"text"];
    NSString *subText = notification[@"sub_text"];

    // Deliver native macOS notification banner
    [[NotificationPresenter sharedPresenter] presentNotificationWithAppName:appName
                                                                      title:title
                                                                       body:text
                                                                    subText:subText
                                                                      sound:YES];

    // Record in recent list
    [self.recentNotifications insertObject:notification atIndex:0];
    if (self.recentNotifications.count > 15) {
        [self.recentNotifications removeLastObject];
    }
    [self updateRecentSubmenu];
}

- (void)bridge:(BluetoothBridge *)bridge didUpdateBattery:(NSInteger)batteryLevel {
    if (batteryLevel >= 0) {
        self.batteryMenuItem.title = [NSString stringWithFormat:@"🔋 Battery: %ld%%", (long)batteryLevel];
        self.batteryMenuItem.hidden = NO;
    } else {
        self.batteryMenuItem.hidden = YES;
    }
}

- (void)openDownloadsClicked:(id)sender {
    NSString *downloadsPath = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) firstObject];
    NSString *destDir = [downloadsPath stringByAppendingPathComponent:@"MacConnect"];
    [[NSFileManager defaultManager] createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:destDir]];
}

- (void)bridge:(BluetoothBridge *)bridge didLogMessage:(NSString *)message {
    // NSLog handles output
}

- (void)bridge:(BluetoothBridge *)bridge didReceiveClipboardText:(NSString *)text {
    NSString *preview = text.length > 80 ? [NSString stringWithFormat:@"%@...", [text substringToIndex:80]] : text;
    [[NotificationPresenter sharedPresenter] presentNotificationWithAppName:@"MacConnect"
                                                                      title:@"Metin Panoya Kopyalandı"
                                                                       body:preview
                                                                    subText:@"Telefondan Gönderildi"
                                                                      sound:YES];
}

- (void)bridge:(BluetoothBridge *)bridge didReceiveFileAtPath:(NSString *)filePath fileName:(NSString *)fileName fileSize:(NSUInteger)fileSize {
    NSString *sizeStr = [NSByteCountFormatter stringFromByteCount:fileSize countStyle:NSByteCountFormatterCountStyleFile];
    [[NotificationPresenter sharedPresenter] presentNotificationWithAppName:@"MacConnect"
                                                                      title:@"Dosya Alındı"
                                                                       body:[NSString stringWithFormat:@"%@ (%@) ~/Downloads/MacConnect klasörüne kaydedildi.", fileName, sizeStr]
                                                                    subText:@"Telefondan Gönderildi"
                                                                      sound:YES];
}

@end
