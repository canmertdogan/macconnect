package com.macconnect.android;

import java.util.UUID;

public class Constants {
    // Standard Bluetooth Serial Port Profile (SPP) UUID
    public static final UUID SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");
    // Custom 128-bit MacConnect UUID for dedicated discovery
    public static final UUID MACCONNECT_UUID = UUID.fromString("94f39d29-7d6d-437d-973b-fba39e49d4ee");

    public static final String SERVICE_NAME = "MacConnect";

    // Intent actions for inter-component communication
    public static final String ACTION_STATE_CHANGED = "com.macconnect.android.ACTION_STATE_CHANGED";
    public static final String ACTION_LOG = "com.macconnect.android.ACTION_LOG";
    public static final String ACTION_CONNECT_DEVICE = "com.macconnect.android.ACTION_CONNECT_DEVICE";
    public static final String ACTION_DISCONNECT = "com.macconnect.android.ACTION_DISCONNECT";
    public static final String ACTION_SEND_TEST = "com.macconnect.android.ACTION_SEND_TEST";

    public static final String EXTRA_STATE = "extra_state";
    public static final String EXTRA_DEVICE_NAME = "extra_device_name";
    public static final String EXTRA_DEVICE_ADDRESS = "extra_device_address";
    public static final String EXTRA_LOG_MESSAGE = "extra_log_message";

    public static final int STATE_DISCONNECTED = 0;
    public static final int STATE_CONNECTING = 1;
    public static final int STATE_CONNECTED = 2;

    public static final String NOTIF_CHANNEL_ID = "macconnect_service_channel";
}
