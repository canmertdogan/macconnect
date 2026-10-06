#import "NotificationPresenter.h"
#import "BluetoothBridge.h"
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

    // Call Action Category
    UNNotificationAction *answerAction = [UNNotificationAction actionWithIdentifier:@"ACTION_ANSWER"
                                                                              title:@"📞 Cevapla"
                                                                            options:UNNotificationActionOptionForeground];
    UNNotificationAction *rejectAction = [UNNotificationAction actionWithIdentifier:@"ACTION_REJECT"
                                                                              title:@"❌ Reddet"
                                                                            options:UNNotificationActionOptionDestructive];

    UNNotificationCategory *callCategory = [UNNotificationCategory categoryWithIdentifier:@"MC_INCOMING_CALL"
                                                                                   actions:@[answerAction, rejectAction]
                                                                         intentIdentifiers:@[]
                                                                                   options:UNNotificationCategoryOptionCustomDismissAction];

    NSSet *categories = [NSSet setWithObject:callCategory];
    [center setNotificationCategories:categories];
    
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

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    NSString *actionId = response.actionIdentifier;
    if ([@"ACTION_ANSWER" isEqualToString:actionId]) {
        [[BluetoothBridge sharedBridge] sendCallAction:@"answer"];
        [self dismissIncomingCall];
    } else if ([@"ACTION_REJECT" isEqualToString:actionId]) {
        [[BluetoothBridge sharedBridge] sendCallAction:@"reject"];
        [self dismissIncomingCall];
    }
    completionHandler();
}

#pragma mark - Presentation

- (void)presentNotificationWithAppName:(NSString *)appName
                                 title:(NSString *)title
                                  body:(NSString *)body
                               subText:(NSString *)subText
                                 sound:(BOOL)playSound {
    [self presentNotificationWithAppName:appName title:title body:body subText:subText iconBase64:nil packageName:nil sound:playSound];
}

- (void)presentNotificationWithAppName:(NSString *)appName
                                 title:(NSString *)title
                                  body:(NSString *)body
                               subText:(NSString *)subText
                            iconBase64:(NSString *)iconBase64
                           packageName:(NSString *)packageName
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

        // Modern native macOS UserNotifications framework
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = displayTitle;
        content.subtitle = displaySubtitle;
        content.body = displayBody;
        if (playSound) {
            content.sound = [UNNotificationSound defaultSound];
        }

        // Attach application icon if provided
        if (iconBase64 && iconBase64.length > 0) {
            NSData *iconData = [[NSData alloc] initWithBase64EncodedString:iconBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
            if (iconData && iconData.length > 0) {
                NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
                NSString *iconDir = [cachesDir stringByAppendingPathComponent:@"com.macconnect.macos/icons"];
                [[NSFileManager defaultManager] createDirectoryAtPath:iconDir withIntermediateDirectories:YES attributes:nil error:nil];
                
                NSString *safePkg = (packageName && packageName.length > 0) ? packageName : @"app";
                safePkg = [safePkg stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
                NSString *iconPath = [iconDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", safePkg]];
                [iconData writeToFile:iconPath atomically:YES];

                NSError *attError = nil;
                UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:[NSString stringWithFormat:@"icon_%@", safePkg]
                                                                                                     URL:[NSURL fileURLWithPath:iconPath]
                                                                                                 options:nil
                                                                                                   error:&attError];
                if (attachment) {
                    content.attachments = @[attachment];
                }
            }
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

- (void)presentIncomingCallWithName:(NSString *)name
                             number:(NSString *)number
                            appName:(NSString *)appName {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *caller = (name && name.length > 0) ? name : @"Bilinmeyen Arayan";
        NSString *num = (number && number.length > 0) ? number : @"";
        NSString *sourceApp = (appName && appName.length > 0) ? appName : @"Telefon";

        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = [NSString stringWithFormat:@"📞 Gelen Arama: %@", caller];
        content.subtitle = sourceApp;
        content.body = num.length > 0 ? num : @"Mac'ten yanıtlayabilir veya reddedebilirsiniz.";
        content.sound = [UNNotificationSound defaultSound];
        content.categoryIdentifier = @"MC_INCOMING_CALL";

        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"mc_incoming_call"
                                                                              content:content
                                                                              trigger:nil];

        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"[NotificationPresenter] Error presenting call: %@", error);
            }
        }];

        if (!self.isAuthorized) {
            [self deliverViaAppleScriptWithTitle:[NSString stringWithFormat:@"📞 Gelen Arama: %@", caller]
                                        subtitle:sourceApp
                                            body:num
                                           sound:YES];
        }
    });
}

- (void)dismissIncomingCall {
    dispatch_async(dispatch_get_main_queue(), ^{
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center removePendingNotificationRequestsWithIdentifiers:@[@"mc_incoming_call"]];
        [center removeDeliveredNotificationsWithIdentifiers:@[@"mc_incoming_call"]];
    });
}

@end
