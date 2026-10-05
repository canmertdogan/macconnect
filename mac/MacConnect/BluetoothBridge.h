#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>

typedef NS_ENUM(NSInteger, MacConnectState) {
    MacConnectStateDisconnected = 0,
    MacConnectStateConnecting = 1,
    MacConnectStateConnected = 2
};

@class BluetoothBridge;

@protocol BluetoothBridgeDelegate <NSObject>
@optional
- (void)bridge:(BluetoothBridge *)bridge didChangeState:(MacConnectState)state deviceName:(NSString *)deviceName;
- (void)bridge:(BluetoothBridge *)bridge didReceiveNotification:(NSDictionary *)notification;
- (void)bridge:(BluetoothBridge *)bridge didUpdateBattery:(NSInteger)batteryLevel;
- (void)bridge:(BluetoothBridge *)bridge didLogMessage:(NSString *)message;
- (void)bridge:(BluetoothBridge *)bridge didReceiveClipboardText:(NSString *)text;
- (void)bridge:(BluetoothBridge *)bridge didReceiveFileAtPath:(NSString *)filePath fileName:(NSString *)fileName fileSize:(NSUInteger)fileSize;
@end

@interface BluetoothBridge : NSObject <IOBluetoothRFCOMMChannelDelegate>

@property (nonatomic, weak) id<BluetoothBridgeDelegate> delegate;
@property (nonatomic, readonly) MacConnectState state;
@property (nonatomic, readonly, copy) NSString *connectedDeviceName;
@property (nonatomic, readonly, copy) NSString *connectedDeviceAddress;
@property (nonatomic, readonly) NSInteger batteryLevel;

+ (instancetype)sharedBridge;

- (void)start;
- (void)stop;
- (void)connectToAddress:(NSString *)address;
- (void)connectToPairedPhone;
- (void)disconnect;
- (void)sendDismissForNotificationId:(NSString *)notifId;
- (NSArray<IOBluetoothDevice *> *)pairedPhones;

@end
