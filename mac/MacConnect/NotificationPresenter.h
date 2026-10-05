#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

@interface NotificationPresenter : NSObject <UNUserNotificationCenterDelegate>

+ (instancetype)sharedPresenter;

- (void)setupAuthorization;

- (void)presentNotificationWithAppName:(NSString *)appName
                                 title:(NSString *)title
                                  body:(NSString *)body
                               subText:(NSString *)subText
                                 sound:(BOOL)playSound;

@end
