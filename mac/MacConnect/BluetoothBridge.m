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

- (void)log:(NSString *)message;
- (void)notifyStateChanged;
- (void)sendHandshakeAck;
- (void)sendData:(NSData *)data;
- (void)resetToDisconnected;
- (void)processIncomingPacket:(NSData *)lineData;

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

    // Start auto-connect timer every 12 seconds to probe phone without thrashing
    if (!_autoConnectTimer) {
        _autoConnectTimer = [NSTimer scheduledTimerWithTimeInterval:12.0
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
        NSString *name = [dev name] ? [dev name] : @"";
        BluetoothClassOfDevice cod = [dev classOfDevice];
        BluetoothDeviceClassMajor major = (cod & 0x1F00) >> 8;

        // Skip headphones, speakers, mice, keyboards, printers
        if (major == 0x04 || major == 0x05 || major == 0x06) {
            continue;
        }

        if (major == 0x02 ||
            [name localizedCaseInsensitiveContainsString:@"phone"] ||
            [name localizedCaseInsensitiveContainsString:@"android"] ||
            [name localizedCaseInsensitiveContainsString:@"galaxy"] ||
            [name localizedCaseInsensitiveContainsString:@"redmi"] ||
            [name localizedCaseInsensitiveContainsString:@"pixel"] ||
            [name localizedCaseInsensitiveContainsString:@"samsung"] ||
            [name localizedCaseInsensitiveContainsString:@"xiaomi"] ||
            [name localizedCaseInsensitiveContainsString:@"oneplus"] ||
            [name localizedCaseInsensitiveContainsString:@"huawei"] ||
            [name localizedCaseInsensitiveContainsString:@"oppo"] ||
            [name localizedCaseInsensitiveContainsString:@"vivo"] ||
            [name localizedCaseInsensitiveContainsString:@"realme"] ||
            [name localizedCaseInsensitiveContainsString:@"poco"] ||
            [name localizedCaseInsensitiveContainsString:@"honor"] ||
            [name localizedCaseInsensitiveContainsString:@"motorola"] ||
            [name localizedCaseInsensitiveContainsString:@"moto"] ||
            [name localizedCaseInsensitiveContainsString:@"sony"] ||
            [name localizedCaseInsensitiveContainsString:@"xperia"] ||
            [name localizedCaseInsensitiveContainsString:@"nothing"]) {
            [phones addObject:dev];
        }
    }

    if (phones.count == 0 && devices.count > 0) {
        // Fallback: exclude non-phone peripherals if possible
        for (IOBluetoothDevice *dev in devices) {
            BluetoothClassOfDevice cod = [dev classOfDevice];
            BluetoothDeviceClassMajor major = (cod & 0x1F00) >> 8;
            if (major != 0x04 && major != 0x05 && major != 0x06) {
                [phones addObject:dev];
            }
        }
    }
    return (phones.count > 0) ? phones : devices;
}

- (void)autoConnectTick:(NSTimer *)timer {
    if (self.state == MacConnectStateDisconnected && !_isQueryingSDP) {
        [self connectToPairedPhone];
    }
}

- (void)connectToPairedPhone {
    if (self.state == MacConnectStateConnected || self.state == MacConnectStateConnecting || _isQueryingSDP) {
        return;
    }

    // 1. Check if we have a remembered phone address
    NSString *lastAddr = [[NSUserDefaults standardUserDefaults] stringForKey:@"LastConnectedPhoneAddress"];
    if (lastAddr && lastAddr.length > 0) {
        NSArray *paired = [IOBluetoothDevice pairedDevices];
        for (IOBluetoothDevice *dev in paired) {
            if ([[dev addressString] isEqualToString:lastAddr]) {
                [self log:[NSString stringWithFormat:@"Remembered phone found: %@ (%@). Connecting...", [dev name], lastAddr]];
                [self connectToAddress:lastAddr];
                return;
            }
        }
    }

    // 2. Otherwise try paired phones list
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
    // Generous 15-second timeout for baseband paging and SDP query
    _connectingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                               target:self
                                                             selector:@selector(connectionTimedOut:)
                                                             userInfo:nil
                                                              repeats:NO];

    _isQueryingSDP = YES;
    [self log:[NSString stringWithFormat:@"Querying SDP services on %@ (%@)...", self.connectedDeviceName, address]];
    [device performSDPQuery:self];
}

- (void)sdpQueryComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
    if (!_isQueryingSDP) return;
    _isQueryingSDP = NO;

    if (self.state != MacConnectStateConnecting) return;

    NSArray *services = [device services];
    BluetoothRFCOMMChannelID targetChannel = 0;
    BluetoothRFCOMMChannelID sppFallbackChannel = 0;

    for (IOBluetoothSDPServiceRecord *rec in services) {
        NSString *name = [rec getServiceName];
        NSString *recDesc = [rec description];
        BluetoothRFCOMMChannelID ch = 0;

        if ([rec getRFCOMMChannelID:&ch] == kIOReturnSuccess && ch > 0) {
            // 1. Match by service name containing "MacConnect"
            if (name && [name localizedCaseInsensitiveContainsString:@"MacConnect"]) {
                targetChannel = ch;
                [self log:[NSString stringWithFormat:@"Matched MacConnect service by name on channel %d", targetChannel]];
                break;
            }

            // 2. Match by UUID (94f39d29...)
            NSString *cleanDesc = [[recDesc lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
            cleanDesc = [cleanDesc stringByReplacingOccurrencesOfString:@" " withString:@""];
            if ([cleanDesc containsString:@"94f39d297d6d437d973bfba39e49d4ee"] ||
                [cleanDesc containsString:@"94f39d29"]) {
                targetChannel = ch;
                [self log:[NSString stringWithFormat:@"Matched MacConnect service by UUID on channel %d", targetChannel]];
                break;
            }

            // 3. Match standard SPP UUID (0x1101)
            NSDictionary *attrs = [rec attributes];
            id attr1 = attrs[@1];
            if (attr1 && ([[attr1 description] containsString:@"1101"] || [[attr1 description] containsString:@"11 01"])) {
                if (sppFallbackChannel == 0) {
                    sppFallbackChannel = ch;
                }
            }
        }
    }

    if (targetChannel == 0 && sppFallbackChannel > 0) {
        targetChannel = sppFallbackChannel;
        [self log:[NSString stringWithFormat:@"Using standard SPP channel %d fallback", targetChannel]];
    }

    // 4. Cached channel fallback
    if (targetChannel == 0 && [device addressString]) {
        NSString *cacheKey = [NSString stringWithFormat:@"LastRFCOMMChannel_%@", [device addressString]];
        NSInteger cachedCh = [[NSUserDefaults standardUserDefaults] integerForKey:cacheKey];
        if (cachedCh > 0 && cachedCh < 30) {
            targetChannel = (BluetoothRFCOMMChannelID)cachedCh;
            [self log:[NSString stringWithFormat:@"Using remembered RFCOMM channel %d for %@", targetChannel, [device name]]];
        }
    }

    if (targetChannel > 0) {
        // Reset timeout for RFCOMM channel connection negotiation (10 seconds)
        if (_connectingTimeoutTimer) {
            [_connectingTimeoutTimer invalidate];
        }
        _connectingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                                   target:self
                                                                 selector:@selector(connectionTimedOut:)
                                                                 userInfo:nil
                                                                  repeats:NO];

        [self log:[NSString stringWithFormat:@"Opening RFCOMM channel %d to %@...", targetChannel, [device name]]];
        IOBluetoothRFCOMMChannel *channel = nil;
        IOReturn ret = [device openRFCOMMChannelAsync:&channel withChannelID:targetChannel delegate:self];
        if (ret != kIOReturnSuccess) {
            [self log:[NSString stringWithFormat:@"openRFCOMMChannelAsync failed with status %d", (int)ret]];
            [self resetToDisconnected];
        }
    } else {
        [self log:@"MacConnect RFCOMM service not found in SDP query."];
        [self resetToDisconnected];
    }
}

- (void)connectionTimedOut:(NSTimer *)timer {
    if (self.state == MacConnectStateConnecting) {
        [self log:@"Bluetooth connection attempt timed out."];
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

    if (self.connectedDeviceAddress.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:self.connectedDeviceAddress forKey:@"LastConnectedPhoneAddress"];
        BluetoothRFCOMMChannelID chID = [channel getChannelID];
        if (chID > 0) {
            NSString *cacheKey = [NSString stringWithFormat:@"LastRFCOMMChannel_%@", self.connectedDeviceAddress];
            [[NSUserDefaults standardUserDefaults] setInteger:chID forKey:cacheKey];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    [self log:[NSString stringWithFormat:@"Incoming connection accepted from %@ (Channel %d)!", self.connectedDeviceName, [channel getChannelID]]];
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

        if (self.connectedDeviceAddress.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:self.connectedDeviceAddress forKey:@"LastConnectedPhoneAddress"];
            BluetoothRFCOMMChannelID chID = [rfcommChannel getChannelID];
            if (chID > 0) {
                NSString *cacheKey = [NSString stringWithFormat:@"LastRFCOMMChannel_%@", self.connectedDeviceAddress];
                [[NSUserDefaults standardUserDefaults] setInteger:chID forKey:cacheKey];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        [self log:[NSString stringWithFormat:@"Connected successfully to %@ (Channel %d)!", self.connectedDeviceName, [rfcommChannel getChannelID]]];
        [self sendHandshakeAck];
    } else {
        [self log:[NSString stringWithFormat:@"RFCOMM channel open failed (IOReturn %d)", (int)error]];
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
    } else if ([@"incoming_call" isEqualToString:type]) {
        [self log:[NSString stringWithFormat:@"Incoming call: %@ (%@)", json[@"name"], json[@"number"]]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bridge:didReceiveIncomingCall:)]) {
                [self.delegate bridge:self didReceiveIncomingCall:json];
            }
        });
    } else if ([@"call_ended" isEqualToString:type]) {
        [self log:@"Call ended on phone"];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bridgeDidEndCall:)]) {
                [self.delegate bridgeDidEndCall:self];
            }
        });
    } else if ([@"call_status" isEqualToString:type]) {
        NSString *status = json[@"status"];
        NSString *msg = json[@"message"];
        [self log:[NSString stringWithFormat:@"Call status update: %@ - %@", status, msg]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bridge:didUpdateCallStatus:message:)]) {
                [self.delegate bridge:self didUpdateCallStatus:status message:msg];
            }
        });
    } else if ([@"media_playback" isEqualToString:type]) {
        [self log:[NSString stringWithFormat:@"Media playback: [%@] %@ - %@", json[@"app_name"], json[@"title"], json[@"artist"]]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(bridge:didReceiveMediaPlayback:)]) {
                [self.delegate bridge:self didReceiveMediaPlayback:json];
            }
        });
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

- (void)sendCallAction:(NSString *)action {
    [self sendCallAction:action withData:nil];
}

- (void)sendCallAction:(NSString *)action withData:(NSDictionary *)data {
    if (!action || action.length == 0) return;
    NSMutableDictionary *cmd = [NSMutableDictionary dictionaryWithDictionary:data ?: @{}];
    cmd[@"type"] = @"call_action";
    cmd[@"action"] = action;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:cmd options:0 error:nil];
    if (jsonData) {
        NSMutableData *line = [NSMutableData dataWithData:jsonData];
        [line appendBytes:"\n" length:1];
        [self sendData:line];
        [self log:[NSString stringWithFormat:@"Sent call action: %@ (payload: %@)", action, cmd]];
    }
}

- (void)dialPhoneNumber:(NSString *)phoneNumber {
    if (!phoneNumber || phoneNumber.length == 0) return;
    [self sendCallAction:@"dial" withData:@{@"number": phoneNumber}];
}

- (void)sendClipboardText:(NSString *)text {
    if (!text || text.length == 0) return;
    NSDictionary *cmd = @{
        @"type": @"clipboard_text",
        @"text": text
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:cmd options:0 error:nil];
    if (jsonData) {
        NSMutableData *line = [NSMutableData dataWithData:jsonData];
        [line appendBytes:"\n" length:1];
        [self sendData:line];
        [self log:[NSString stringWithFormat:@"Sent clipboard text to phone (%lu chars)", (unsigned long)text.length]];
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
