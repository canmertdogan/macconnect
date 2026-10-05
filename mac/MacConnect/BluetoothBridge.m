#import "BluetoothBridge.h"
#import <AppKit/AppKit.h>

@interface BluetoothBridge () {
    IOBluetoothRFCOMMChannel *_activeChannel;
    IOBluetoothUserNotification *_channelNotificationGeneral;
    NSMutableData *_incomingBuffer;
    NSTimer *_connectingTimeoutTimer;
    NSTimer *_autoConnectTimer;
    BOOL _isQueryingSDP;
}

@property (nonatomic, readwrite) MacConnectState state;
@property (nonatomic, readwrite, copy) NSString *connectedDeviceName;
@property (nonatomic, readwrite, copy) NSString *connectedDeviceAddress;
@property (nonatomic, readwrite) NSInteger batteryLevel;
@property (nonatomic, copy) NSString *lastTargetAddress;
@property (nonatomic, strong) NSMutableData *fileReceiveBuffer;
@property (nonatomic, copy) NSString *fileReceiveName;
@property (nonatomic, assign) NSInteger fileReceiveExpectedChunks;
@property (nonatomic, assign) NSInteger fileReceiveReceivedChunks;

@end

@implementation BluetoothBridge

+ (instancetype)sharedBridge {
    static BluetoothBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BluetoothBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = MacConnectStateDisconnected;
        _incomingBuffer = [[NSMutableData alloc] init];
        _connectedDeviceName = @"";
        _connectedDeviceAddress = @"";
        _batteryLevel = -1;
    }
    return self;
}

- (void)start {
    [self log:@"Starting MacConnect Bluetooth Bridge..."];

    // Register for incoming notifications as fallback
    _channelNotificationGeneral = [IOBluetoothRFCOMMChannel registerForChannelOpenNotifications:self
                                                                                       selector:@selector(channelOpenedNotification:channel:)];

    self.state = MacConnectStateDisconnected;
    [self notifyStateChanged];

    // Start auto-connect timer every 6 seconds to probe phone
    if (!_autoConnectTimer) {
        _autoConnectTimer = [NSTimer scheduledTimerWithTimeInterval:6.0
                                                             target:self
                                                           selector:@selector(autoConnectTick:)
                                                           userInfo:nil
                                                            repeats:YES];
    }

    [self connectToPairedPhone];
}

- (void)stop {
    [self disconnect];
    if (_autoConnectTimer) {
        [_autoConnectTimer invalidate];
        _autoConnectTimer = nil;
    }
    if (_connectingTimeoutTimer) {
        [_connectingTimeoutTimer invalidate];
        _connectingTimeoutTimer = nil;
    }
    if (_channelNotificationGeneral) {
        [_channelNotificationGeneral unregister];
        _channelNotificationGeneral = nil;
    }
}

- (NSArray<IOBluetoothDevice *> *)pairedPhones {
    NSMutableArray<IOBluetoothDevice *> *phones = [NSMutableArray array];
    NSArray *devices = [IOBluetoothDevice pairedDevices];
    for (IOBluetoothDevice *dev in devices) {
        NSString *name = [dev name];
        BluetoothClassOfDevice cod = [dev classOfDevice];
        BluetoothDeviceClassMajor major = (cod & 0x1F00) >> 8;
        if (major == 0x02 || [name localizedCaseInsensitiveContainsString:@"redmi"] ||
            [name localizedCaseInsensitiveContainsString:@"pixel"] ||
            [name localizedCaseInsensitiveContainsString:@"samsung"] ||
            [name localizedCaseInsensitiveContainsString:@"xiaomi"]) {
            [phones addObject:dev];
        }
    }
    if (phones.count == 0 && devices.count > 0) {
        return devices;
    }
    return phones;
}

- (void)autoConnectTick:(NSTimer *)timer {
    if (self.state == MacConnectStateDisconnected) {
        [self connectToPairedPhone];
    }
}

- (void)connectToPairedPhone {
    if (self.state == MacConnectStateConnected || self.state == MacConnectStateConnecting) {
        return;
    }

    NSArray<IOBluetoothDevice *> *phones = [self pairedPhones];
    if (phones.count > 0) {
        IOBluetoothDevice *target = phones.firstObject;
        [self connectToAddress:[target addressString]];
    }
}

- (void)connectToAddress:(NSString *)address {
    if (!address || address.length == 0) return;
    if (self.state == MacConnectStateConnected || self.state == MacConnectStateConnecting) return;

    if (_activeChannel) {
        [_activeChannel closeChannel];
        _activeChannel = nil;
    }

    self.lastTargetAddress = address;
    IOBluetoothDevice *device = [IOBluetoothDevice deviceWithAddressString:address];
    if (!device) return;

    self.state = MacConnectStateConnecting;
    self.connectedDeviceName = [device name] ? [device name] : @"Android Phone";
    self.connectedDeviceAddress = address;
    [self notifyStateChanged];

    if (_connectingTimeoutTimer) {
        [_connectingTimeoutTimer invalidate];
    }
    _connectingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:6.0
                                                               target:self
                                                             selector:@selector(connectionTimedOut:)
                                                             userInfo:nil
                                                              repeats:NO];

    _isQueryingSDP = YES;
    [device performSDPQuery:self];
}

- (void)sdpQueryComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
    if (!_isQueryingSDP) return;
    _isQueryingSDP = NO;

    if (self.state != MacConnectStateConnecting) return;

    NSArray *services = [device services];
    BluetoothRFCOMMChannelID targetChannel = 0;

    for (IOBluetoothSDPServiceRecord *rec in services) {
        NSString *name = [rec getServiceName];
        NSDictionary *attrs = [rec attributes];
        id attr1 = attrs[@1];

        // Match by "MacConnect" name or by UUID 94f39d29 in attribute 1
        if ((name && [name localizedCaseInsensitiveContainsString:@"MacConnect"]) ||
            (attr1 && [[attr1 description] containsString:@"94 f3 9d 29"])) {
            [rec getRFCOMMChannelID:&targetChannel];
            if (targetChannel > 0) {
                [self log:[NSString stringWithFormat:@"Found MacConnect on channel %d", targetChannel]];
                break;
            }
        }
    }

    if (targetChannel > 0) {
        IOBluetoothRFCOMMChannel *channel = nil;
        IOReturn ret = [device openRFCOMMChannelAsync:&channel withChannelID:targetChannel delegate:self];
        if (ret != kIOReturnSuccess) {
            [self resetToDisconnected];
        }
    } else {
        [self resetToDisconnected];
    }
}

- (void)connectionTimedOut:(NSTimer *)timer {
    if (self.state == MacConnectStateConnecting) {
        [self resetToDisconnected];
    }
}

- (void)resetToDisconnected {
    if (_connectingTimeoutTimer) {
        [_connectingTimeoutTimer invalidate];
        _connectingTimeoutTimer = nil;
    }
    _isQueryingSDP = NO;
    self.state = MacConnectStateDisconnected;
    self.connectedDeviceName = @"";
    self.connectedDeviceAddress = @"";
    self.fileReceiveBuffer = nil;
    self.fileReceiveName = nil;
    [self notifyStateChanged];
}

- (void)disconnect {
    if (_connectingTimeoutTimer) {
        [_connectingTimeoutTimer invalidate];
        _connectingTimeoutTimer = nil;
    }
    if (_activeChannel) {
        [_activeChannel setDelegate:nil];
        [_activeChannel closeChannel];
        _activeChannel = nil;
    }
    [self resetToDisconnected];
}

#pragma mark - Incoming Channel Notifications

- (void)channelOpenedNotification:(IOBluetoothUserNotification *)notification channel:(IOBluetoothRFCOMMChannel *)channel {
    if (_connectingTimeoutTimer) {
        [_connectingTimeoutTimer invalidate];
        _connectingTimeoutTimer = nil;
    }

    if (_activeChannel) {
        [_activeChannel closeChannel];
    }
    _activeChannel = channel;
    [_activeChannel setDelegate:self];

    IOBluetoothDevice *dev = [channel getDevice];
    self.connectedDeviceName = [dev name] ? [dev name] : @"Android Phone";
    self.connectedDeviceAddress = [dev addressString] ? [dev addressString] : @"";
    self.state = MacConnectStateConnected;
    [self notifyStateChanged];

    [self sendHandshakeAck];
}

#pragma mark - IOBluetoothRFCOMMChannelDelegate

- (void)rfcommChannelOpenComplete:(IOBluetoothRFCOMMChannel *)rfcommChannel status:(IOReturn)error {
    if (_connectingTimeoutTimer) {
        [_connectingTimeoutTimer invalidate];
        _connectingTimeoutTimer = nil;
    }

    if (error == kIOReturnSuccess) {
        _activeChannel = rfcommChannel;
        [_activeChannel setDelegate:self];

        IOBluetoothDevice *dev = [rfcommChannel getDevice];
        self.connectedDeviceName = [dev name] ? [dev name] : @"Android Phone";
        self.connectedDeviceAddress = [dev addressString] ? [dev addressString] : @"";
        self.state = MacConnectStateConnected;
        [self notifyStateChanged];

        [self log:[NSString stringWithFormat:@"Connected to %@!", self.connectedDeviceName]];
        [self sendHandshakeAck];
    } else {
        [self resetToDisconnected];
    }
}

- (void)rfcommChannelClosed:(IOBluetoothRFCOMMChannel *)rfcommChannel {
    [self log:@"Bluetooth connection closed."];
    if (_activeChannel == rfcommChannel) {
        _activeChannel = nil;
    }
    [self resetToDisconnected];
}

- (void)rfcommChannelData:(IOBluetoothRFCOMMChannel *)rfcommChannel data:(void *)dataPointer length:(size_t)dataLength {
    if (dataLength == 0 || !dataPointer) return;

    [_incomingBuffer appendBytes:dataPointer length:dataLength];

    const char *bytes = (const char *)[_incomingBuffer bytes];
    NSUInteger length = [_incomingBuffer length];
    NSUInteger startIndex = 0;

    for (NSUInteger i = 0; i < length; i++) {
        if (bytes[i] == '\n') {
            NSUInteger lineLength = i - startIndex;
            if (lineLength > 0) {
                NSData *lineData = [_incomingBuffer subdataWithRange:NSMakeRange(startIndex, lineLength)];
                [self processIncomingPacket:lineData];
            }
            startIndex = i + 1;
        }
    }

    if (startIndex > 0) {
        if (startIndex < length) {
            NSData *remaining = [_incomingBuffer subdataWithRange:NSMakeRange(startIndex, length - startIndex)];
            [_incomingBuffer setData:remaining];
        } else {
            [_incomingBuffer setLength:0];
        }
    }
}

#pragma mark - Packet Processing

- (void)processIncomingPacket:(NSData *)lineData {
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:&error];
    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSString *type = json[@"type"];
    if ([@"notification_posted" isEqualToString:type]) {
        [self log:[NSString stringWithFormat:@"Notification from [%@]: %@", json[@"app_name"], json[@"title"]]];
        if ([self.delegate respondsToSelector:@selector(bridge:didReceiveNotification:)]) {
            [self.delegate bridge:self didReceiveNotification:json];
        }
    } else if ([@"handshake" isEqualToString:type]) {
        NSString *deviceName = json[@"device_name"];
        if (deviceName && deviceName.length > 0) {
            self.connectedDeviceName = deviceName;
        }
        id battery = json[@"battery"];
        if (battery && [battery isKindOfClass:[NSNumber class]]) {
            self.batteryLevel = [battery integerValue];
            if ([self.delegate respondsToSelector:@selector(bridge:didUpdateBattery:)]) {
                [self.delegate bridge:self didUpdateBattery:self.batteryLevel];
            }
        }
        [self log:[NSString stringWithFormat:@"Phone linked: %@ (Battery: %ld%%)", self.connectedDeviceName, (long)self.batteryLevel]];
        [self notifyStateChanged];
        [self sendHandshakeAck];
    } else if ([@"ping" isEqualToString:type]) {
        id battery = json[@"battery"];
        if (battery && [battery isKindOfClass:[NSNumber class]]) {
            self.batteryLevel = [battery integerValue];
            if ([self.delegate respondsToSelector:@selector(bridge:didUpdateBattery:)]) {
                [self.delegate bridge:self didUpdateBattery:self.batteryLevel];
            }
        }
        [self sendData:[@"{\"type\":\"pong\"}\n" dataUsingEncoding:NSUTF8StringEncoding]];
    } else if ([@"pong" isEqualToString:type] || [@"battery" isEqualToString:type]) {
        id battery = json[@"battery"] ? json[@"battery"] : json[@"level"];
        if (battery && [battery isKindOfClass:[NSNumber class]]) {
            self.batteryLevel = [battery integerValue];
            if ([self.delegate respondsToSelector:@selector(bridge:didUpdateBattery:)]) {
                [self.delegate bridge:self didUpdateBattery:self.batteryLevel];
            }
        }
    } else if ([@"clipboard_text" isEqualToString:type]) {
        NSString *text = json[@"text"];
        if (text && [text isKindOfClass:[NSString class]] && text.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                [pasteboard clearContents];
                [pasteboard setString:text forType:NSPasteboardTypeString];

                if ([self.delegate respondsToSelector:@selector(bridge:didReceiveClipboardText:)]) {
                    [self.delegate bridge:self didReceiveClipboardText:text];
                }
            });
            [self log:[NSString stringWithFormat:@"Copied text from phone to Mac clipboard (%lu chars)", (unsigned long)text.length]];
        }
    } else if ([@"file_start" isEqualToString:type]) {
        NSString *fileName = json[@"file_name"];
        if (!fileName || fileName.length == 0) {
            fileName = [NSString stringWithFormat:@"file_%ld", (long)[[NSDate date] timeIntervalSince1970]];
        }
        self.fileReceiveName = fileName;
        self.fileReceiveBuffer = [NSMutableData data];
        self.fileReceiveExpectedChunks = [json[@"total_chunks"] integerValue];
        self.fileReceiveReceivedChunks = 0;
        [self log:[NSString stringWithFormat:@"Incoming file '%@' (total chunks: %ld)", fileName, (long)self.fileReceiveExpectedChunks]];
    } else if ([@"file_chunk" isEqualToString:type]) {
        NSString *b64Data = json[@"data"];
        if (b64Data && self.fileReceiveBuffer) {
            NSData *chunk = [[NSData alloc] initWithBase64EncodedString:b64Data options:NSDataBase64DecodingIgnoreUnknownCharacters];
            if (chunk) {
                [self.fileReceiveBuffer appendData:chunk];
                self.fileReceiveReceivedChunks++;
            }
        }
    } else if ([@"file_end" isEqualToString:type]) {
        if (self.fileReceiveBuffer && self.fileReceiveName) {
            NSString *downloadsPath = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) firstObject];
            NSString *destDir = [downloadsPath stringByAppendingPathComponent:@"MacConnect"];
            [[NSFileManager defaultManager] createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];

            NSString *destPath = [destDir stringByAppendingPathComponent:self.fileReceiveName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
                NSString *nameWithoutExt = [self.fileReceiveName stringByDeletingPathExtension];
                NSString *ext = [self.fileReceiveName pathExtension];
                NSString *uniqueName = [NSString stringWithFormat:@"%@_%ld.%@", nameWithoutExt, (long)[[NSDate date] timeIntervalSince1970], ext];
                destPath = [destDir stringByAppendingPathComponent:uniqueName];
            }

            BOOL written = [self.fileReceiveBuffer writeToFile:destPath atomically:YES];
            if (written) {
                [self log:[NSString stringWithFormat:@"Saved file to %@", destPath]];
                if ([self.delegate respondsToSelector:@selector(bridge:didReceiveFileAtPath:fileName:fileSize:)]) {
                    [self.delegate bridge:self didReceiveFileAtPath:destPath fileName:self.fileReceiveName fileSize:self.fileReceiveBuffer.length];
                }
            } else {
                [self log:[NSString stringWithFormat:@"Failed to write file to %@", destPath]];
            }
            self.fileReceiveBuffer = nil;
            self.fileReceiveName = nil;
        }
    }
}

- (void)sendHandshakeAck {
    NSString *hostName = [[NSHost currentHost] localizedName];
    if (!hostName || hostName.length == 0) hostName = @"Mac";
    NSDictionary *ack = @{
        @"type": @"handshake_ack",
        @"mac_name": hostName,
        @"status": @"ok"
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:ack options:0 error:nil];
    if (data) {
        NSMutableData *line = [NSMutableData dataWithData:data];
        [line appendBytes:"\n" length:1];
        [self sendData:line];
    }
}

- (void)sendDismissForNotificationId:(NSString *)notifId {
    if (!notifId || notifId.length == 0) return;
    NSDictionary *cmd = @{
        @"type": @"dismiss_notification",
        @"id": notifId
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:cmd options:0 error:nil];
    if (data) {
        NSMutableData *line = [NSMutableData dataWithData:data];
        [line appendBytes:"\n" length:1];
        [self sendData:line];
    }
}

- (void)sendData:(NSData *)data {
    if (_activeChannel && self.state == MacConnectStateConnected) {
        [_activeChannel writeAsync:(void *)[data bytes] length:[data length] refcon:nil];
    }
}

- (void)notifyStateChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(bridge:didChangeState:deviceName:)]) {
            [self.delegate bridge:self didChangeState:self.state deviceName:self.connectedDeviceName];
        }
    });
}

- (void)log:(NSString *)message {
    NSLog(@"[BluetoothBridge] %@", message);
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(bridge:didLogMessage:)]) {
            [self.delegate bridge:self didLogMessage:message];
        }
    });
}

@end
