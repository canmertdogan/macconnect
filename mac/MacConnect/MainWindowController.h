#import <Cocoa/Cocoa.h>
#import "BluetoothBridge.h"

@interface MainWindowController : NSWindowController <BluetoothBridgeDelegate, NSWindowDelegate>

+ (instancetype)sharedController;

- (void)showWindowAndActivate;
- (void)updateDeviceState:(MacConnectState)state name:(NSString *)name;
- (void)updateBatteryLevel:(NSInteger)level;
- (void)addNotification:(NSDictionary *)notification;
- (void)updateMediaPlayback:(NSDictionary *)mediaInfo;
- (void)showIncomingCall:(NSDictionary *)callInfo;
- (void)dismissIncomingCall;
- (void)updateCallStatus:(NSString *)status message:(NSString *)message;
- (void)updateClipboardText:(NSString *)text;
- (void)updateDeviceIpAddress:(NSString *)ipAddress;
- (void)updateReplyStatus:(BOOL)success notifId:(NSString *)notifId message:(NSString *)message;

@end
