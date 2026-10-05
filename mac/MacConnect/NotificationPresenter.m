#import "NotificationPresenter.h"
#import <AppKit/AppKit.h>

@interface NotificationPresenter ()
@property (nonatomic, assign) BOOL isAuthorized;
@end

@implementation NotificationPresenter

+ (instancetype)sharedPresenter {
    static NotificationPresenter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NotificationPresenter alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isAuthorized = NO;
        [self setupAuthorization];
    }
    return self;
}

- (void)setupAuthorization {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        self.isAuthorized = granted;
        NSLog(@"[NotificationPresenter] UNUserNotificationCenter authorized: %d (error: %@)", granted, error);
    }];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    // Force macOS to always display the banner and play sound even when app is active
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionList);
}

#pragma mark - Presentation

- (void)presentNotificationWithAppName:(NSString *)appName
                                 title:(NSString *)title
                                  body:(NSString *)body
                               subText:(NSString *)subText
                                 sound:(BOOL)playSound {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *displayTitle = (appName && appName.length > 0) ? appName : @"Phone";
        
        NSString *displaySubtitle = @"";
        if (title && title.length > 0) {
            if (subText && subText.length > 0) {
                displaySubtitle = [NSString stringWithFormat:@"%@ • %@", title, subText];
            } else {
                displaySubtitle = title;
            }
        } else if (subText && subText.length > 0) {
            displaySubtitle = subText;
        }

        NSString *displayBody = (body && body.length > 0) ? body : @"";

        // Try modern native macOS UserNotifications framework
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = displayTitle;
        content.subtitle = displaySubtitle;
        content.body = displayBody;
        if (playSound) {
            content.sound = [UNNotificationSound defaultSound];
        }

        NSString *reqId = [NSString stringWithFormat:@"mc_notif_%f", [[NSDate date] timeIntervalSince1970]];
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:reqId content:content trigger:nil];
        
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"[NotificationPresenter] UNUserNotificationCenter add error: %@. Falling back to AppleScript...", error);
                [self deliverViaAppleScriptWithTitle:displayTitle subtitle:displaySubtitle body:displayBody sound:playSound];
            }
        }];
        
        // Also deliver via AppleScript if not explicitly authorized yet
        if (!self.isAuthorized) {
            [self deliverViaAppleScriptWithTitle:displayTitle subtitle:displaySubtitle body:displayBody sound:playSound];
        }
    });
}

- (void)deliverViaAppleScriptWithTitle:(NSString *)displayTitle
                              subtitle:(NSString *)displaySubtitle
                                  body:(NSString *)displayBody
                                 sound:(BOOL)playSound {
    NSString *escapedBody = [[displayBody stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                                          stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *escapedTitle = [[displayTitle stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                                            stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *escapedSub = [[displaySubtitle stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                                             stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

    NSString *soundClause = playSound ? @" sound name \"Glass\"" : @"";
    NSString *scriptSource;
    if (escapedSub.length > 0) {
        scriptSource = [NSString stringWithFormat:@"display notification \"%@\" with title \"%@\" subtitle \"%@\"%@",
                        escapedBody, escapedTitle, escapedSub, soundClause];
    } else {
        scriptSource = [NSString stringWithFormat:@"display notification \"%@\" with title \"%@\"%@",
                        escapedBody, escapedTitle, soundClause];
    }

    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptSource];
    NSDictionary *errorInfo = nil;
    [appleScript executeAndReturnError:&errorInfo];
    if (errorInfo) {
        NSLog(@"[NotificationPresenter] AppleScript error: %@", errorInfo);
    }
}

@end
