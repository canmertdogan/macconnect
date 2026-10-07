package com.macconnect.android;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.Manifest;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Looper;
import android.provider.ContactsContract;
import android.telecom.TelecomManager;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import android.util.Log;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

public class BluetoothService extends Service {
    private static final String TAG = "MacConnectBT";
    private static final int NOTIF_ID = 1001;

    private static BluetoothService sInstance;
    private BluetoothAdapter mAdapter;

    private AcceptThread mAcceptThread;
    private ConnectThread mConnectThread;
    private ConnectedThread mConnectedThread;

    private int mState = Constants.STATE_DISCONNECTED;
    private String mConnectedDeviceName = "";
    private String mConnectedDeviceAddress = "";
    private String mLastTargetAddress = "";

    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private boolean mIsRunning = false;
    private int mCurrentBatteryLevel = 100;

    // Telephony and Call management
    private TelephonyManager mTelephonyManager;
    private PhoneStateListener mPhoneStateListener;
    private boolean mIsCellularRinging = false;
    private String mActiveVoipCallKey = null;
    private Notification.Action mActiveVoipAnswerAction = null;
    private Notification.Action mActiveVoipDeclineAction = null;

    private final BroadcastReceiver mBatteryReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent != null) {
                int level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                int scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
                if (level >= 0 && scale > 0) {
                    mCurrentBatteryLevel = (level * 100) / scale;
                }
            }
        }
    };

    public static BluetoothService getInstance() {
        return sInstance;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        sInstance = this;
        mIsRunning = true;
        mAdapter = BluetoothAdapter.getDefaultAdapter();

        try {
            registerReceiver(mBatteryReceiver, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        } catch (Exception ignored) {}

        createNotificationChannel();
        startForeground(NOTIF_ID, buildForegroundNotification("MacConnect aktif"));

        log("Bluetooth Service started.");
        startServerListening();
        initTelephonyListener();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null) {
            String action = intent.getAction();
            if (Constants.ACTION_CONNECT_DEVICE.equals(action)) {
                String address = intent.getStringExtra(Constants.EXTRA_DEVICE_ADDRESS);
                if (address != null && !address.isEmpty()) {
                    connectToDevice(address);
                }
            } else if (Constants.ACTION_DISCONNECT.equals(action)) {
                disconnect();
            } else if (Constants.ACTION_SEND_TEST.equals(action)) {
                sendTestNotification();
            }
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        mIsRunning = false;
        try {
            unregisterReceiver(mBatteryReceiver);
        } catch (Exception ignored) {}
        if (mTelephonyManager != null && mPhoneStateListener != null) {
            try {
                mTelephonyManager.listen(mPhoneStateListener, PhoneStateListener.LISTEN_NONE);
            } catch (Exception ignored) {}
            mPhoneStateListener = null;
        }
        disconnect();
        sInstance = null;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    public synchronized int getState() {
        return mState;
    }

    public synchronized String getConnectedDeviceName() {
        return mConnectedDeviceName;
    }

    private synchronized void setState(int state, String devName, String devAddr) {
        mState = state;
        mConnectedDeviceName = devName != null ? devName : "";
        mConnectedDeviceAddress = devAddr != null ? devAddr : "";

        String statusText;
        if (state == Constants.STATE_CONNECTED) {
            statusText = "Connected to " + mConnectedDeviceName;
        } else if (state == Constants.STATE_CONNECTING) {
            statusText = "Connecting to " + (devName != null ? devName : "Mac");
        } else {
            statusText = "Waiting for Mac Bluetooth...";
        }

        updateForegroundNotification(statusText);

        Intent intent = new Intent(Constants.ACTION_STATE_CHANGED);
        intent.putExtra(Constants.EXTRA_STATE, state);
        intent.putExtra(Constants.EXTRA_DEVICE_NAME, mConnectedDeviceName);
        intent.putExtra(Constants.EXTRA_DEVICE_ADDRESS, mConnectedDeviceAddress);
        sendBroadcast(intent);
    }

    public synchronized void startServerListening() {
        if (mAdapter == null || !mAdapter.isEnabled()) {
            log("Bluetooth adapter not available or disabled.");
            return;
        }

        if (mConnectThread != null) {
            mConnectThread.cancel();
            mConnectThread = null;
        }

        if (mAcceptThread != null && !mAcceptThread.isAlive()) {
            mAcceptThread.cancel();
            mAcceptThread = null;
        }

        if (mAcceptThread == null) {
            mAcceptThread = new AcceptThread();
            mAcceptThread.start();
            log("Listening for incoming Bluetooth connections from Mac...");
        }
    }

    public synchronized void connectToDevice(String address) {
        if (mAdapter == null || !mAdapter.isEnabled()) {
            log("Bluetooth is disabled. Enable Bluetooth first.");
            return;
        }

        mLastTargetAddress = address;
        BluetoothDevice device;
        try {
            device = mAdapter.getRemoteDevice(address);
        } catch (IllegalArgumentException e) {
            log("Invalid Bluetooth address: " + address);
            return;
        }

        if (mState == Constants.STATE_CONNECTING && mConnectThread != null) {
            mConnectThread.cancel();
            mConnectThread = null;
        }

        if (mConnectedThread != null) {
            mConnectedThread.cancel();
            mConnectedThread = null;
        }

        mConnectThread = new ConnectThread(device);
        mConnectThread.start();
        setState(Constants.STATE_CONNECTING, device.getName(), device.getAddress());
        log("Initiating connection to: " + device.getName() + " (" + address + ")");
    }

    public synchronized void connected(BluetoothSocket socket, BluetoothDevice device) {
        if (mConnectThread != null) {
            mConnectThread.cancel();
            mConnectThread = null;
        }
        if (mConnectedThread != null) {
            mConnectedThread.cancel();
            mConnectedThread = null;
        }
        if (mAcceptThread != null) {
            mAcceptThread.cancel();
            mAcceptThread = null;
        }

        mConnectedThread = new ConnectedThread(socket);
        mConnectedThread.start();

        String devName = device.getName();
        if (devName == null || devName.isEmpty()) devName = "Mac Device";
        setState(Constants.STATE_CONNECTED, devName, device.getAddress());
        log("Bluetooth connected to: " + devName + " (" + device.getAddress() + ")");

        // Send handshake
        sendHandshake();
    }

    public synchronized void disconnect() {
        if (mConnectThread != null) {
            mConnectThread.cancel();
            mConnectThread = null;
        }
        if (mConnectedThread != null) {
            mConnectedThread.cancel();
            mConnectedThread = null;
        }
        if (mAcceptThread != null) {
            mAcceptThread.cancel();
            mAcceptThread = null;
        }
        setState(Constants.STATE_DISCONNECTED, null, null);
    }

    private void connectionLost() {
        log("Bluetooth disconnected. Listening for Mac...");
        setState(Constants.STATE_DISCONNECTED, null, null);
        if (mIsRunning) {
            mHandler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    if (mIsRunning && mState == Constants.STATE_DISCONNECTED) {
                        startServerListening();
                    }
                }
            }, 1000);
        }
    }

    public void sendJson(JSONObject json) {
        if (mConnectedThread != null && mState == Constants.STATE_CONNECTED) {
            mConnectedThread.write(json.toString() + "\n");
        } else {
            log("Cannot send: Bluetooth not connected.");
        }
    }

    public void sendNotification(String id, String pkg, String appName, String title, String text, String subText, String iconB64, long timestamp, boolean isOngoing) {
        try {
            JSONObject obj = new JSONObject();
            obj.put("type", "notification_posted");
            obj.put("id", id != null ? id : "");
            obj.put("package_name", pkg != null ? pkg : "");
            obj.put("app_name", appName != null ? appName : pkg);
            obj.put("title", title != null ? title : "");
            obj.put("text", text != null ? text : "");
            obj.put("sub_text", subText != null ? subText : "");
            if (iconB64 != null && !iconB64.isEmpty()) {
                obj.put("icon", iconB64);
            }
            obj.put("timestamp", timestamp > 0 ? timestamp : System.currentTimeMillis());
            obj.put("is_ongoing", isOngoing);
            sendJson(obj);
            log("Forwarded notification: [" + appName + "] " + (title != null ? title : ""));
        } catch (Exception e) {
            Log.e(TAG, "Error building notification JSON", e);
        }
    }

    public void sendNotification(String id, String pkg, String appName, String title, String text, String subText, long timestamp, boolean isOngoing) {
        sendNotification(id, pkg, appName, title, text, subText, null, timestamp, isOngoing);
    }

    public void sendNotificationRemoved(String id, String pkg) {
        try {
            JSONObject obj = new JSONObject();
            obj.put("type", "notification_removed");
            obj.put("id", id != null ? id : "");
            obj.put("package_name", pkg != null ? pkg : "");
            sendJson(obj);
        } catch (Exception e) {
            Log.e(TAG, "Error building remove JSON", e);
        }
    }

    public void sendTestNotification() {
        sendNotification("test_" + System.currentTimeMillis(), "com.macconnect.android", "MacConnect",
                "Test Notification", "Hello from Android! Notifications are working over Bluetooth.", "MacConnect Phone Bridge",
                System.currentTimeMillis(), false);
    }

    private void sendHandshake() {
        try {
            JSONObject obj = new JSONObject();
            obj.put("type", "handshake");
            obj.put("device_name", Build.MODEL);
            obj.put("manufacturer", Build.MANUFACTURER);
            obj.put("android_version", Build.VERSION.RELEASE);
            obj.put("battery", getBatteryLevel());
            sendJson(obj);
        } catch (Exception e) {
            Log.e(TAG, "Handshake error", e);
        }
    }

    private int getBatteryLevel() {
        return mCurrentBatteryLevel > 0 ? mCurrentBatteryLevel : 100;
    }

    private void handleIncomingMessage(String line) {
        try {
            JSONObject json = new JSONObject(line);
            String type = json.optString("type");
            if ("ping".equals(type)) {
                JSONObject pong = new JSONObject();
                pong.put("type", "pong");
                pong.put("battery", getBatteryLevel());
                sendJson(pong);
            } else if ("handshake_ack".equals(type)) {
                log("Mac acknowledged connection: " + json.optString("mac_name", "Mac"));
            } else if ("dismiss_notification".equals(type)) {
                String id = json.optString("id");
                if (NotificationListener.getInstance() != null && id != null) {
                    NotificationListener.getInstance().cancelNotificationByKey(id);
                }
            } else if ("call_action".equals(type)) {
                String action = json.optString("action");
                handleCallAction(action, json);
            } else if ("clipboard_text".equals(type)) {
                final String text = json.optString("text");
                if (text != null && !text.isEmpty()) {
                    mHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                android.content.ClipboardManager cb = (android.content.ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                                if (cb != null) {
                                    android.content.ClipData clip = android.content.ClipData.newPlainText("MacConnect", text);
                                    cb.setPrimaryClip(clip);
                                    log("Pano Mac tarafından güncellendi: " + (text.length() > 25 ? text.substring(0, 25) + "..." : text));
                                }
                            } catch (Exception e) {
                                log("Pano güncellenemedi: " + e.getMessage());
                            }
                        }
                    });
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error parsing incoming JSON: " + line, e);
        }
    }

    private String mLastMediaTitle = "";
    private String mLastMediaArtist = "";

    public void sendMediaPlayback(String pkg, String appName, String title, String artist, String subText, String iconB64) {
        if (title == null) title = "";
        if (artist == null) artist = "";

        if (title.equals(mLastMediaTitle) && artist.equals(mLastMediaArtist)) {
            return;
        }
        mLastMediaTitle = title;
        mLastMediaArtist = artist;

        try {
            JSONObject obj = new JSONObject();
            obj.put("type", "media_playback");
            obj.put("package_name", pkg != null ? pkg : "");
            obj.put("app_name", appName != null ? appName : "Müzik");
            obj.put("title", title);
            obj.put("artist", artist);
            obj.put("sub_text", subText != null ? subText : "");
            if (iconB64 != null && !iconB64.isEmpty()) {
                obj.put("icon", iconB64);
            }
            obj.put("timestamp", System.currentTimeMillis());
            sendJson(obj);
            log("Medya yayını iletildi: " + appName + " - " + title + " (" + artist + ")");
        } catch (Exception e) {
            Log.e(TAG, "Error building media_playback JSON", e);
        }
    }

    // --- Call Management & Telephony ---

    public void refreshTelephonyListener() {
        initTelephonyListener();
    }

    private synchronized void initTelephonyListener() {
        if (mTelephonyManager == null) {
            mTelephonyManager = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
        }
        if (mTelephonyManager == null) return;

        if (mPhoneStateListener == null) {
            try {
                mPhoneStateListener = new PhoneStateListener() {
                    @Override
                    public void onCallStateChanged(int state, String incomingNumber) {
                        super.onCallStateChanged(state, incomingNumber);
                        handleCellularCallState(state, incomingNumber);
                    }
                };
                mTelephonyManager.listen(mPhoneStateListener, PhoneStateListener.LISTEN_CALL_STATE);
                log("Telephony call listener registered.");
            } catch (Exception e) {
                Log.e(TAG, "Error registering phone state listener", e);
            }
        }
    }

    private void handleCellularCallState(int state, String incomingNumber) {
        if (state == TelephonyManager.CALL_STATE_RINGING) {
            mIsCellularRinging = true;
            String callerName = resolveContactName(incomingNumber);
            if (callerName == null || callerName.isEmpty()) {
                callerName = (incomingNumber != null && !incomingNumber.isEmpty()) ? incomingNumber : "Bilinmeyen Numara";
            }
            try {
                JSONObject obj = new JSONObject();
                obj.put("type", "incoming_call");
                obj.put("call_type", "cellular");
                obj.put("app_name", "Telefon");
                obj.put("name", callerName);
                obj.put("number", incomingNumber != null ? incomingNumber : "");
                sendJson(obj);
                log("Incoming cellular call ringing: " + callerName + " (" + incomingNumber + ")");
            } catch (Exception e) {
                Log.e(TAG, "Error sending cellular incoming call JSON", e);
            }
        } else if (state == TelephonyManager.CALL_STATE_IDLE || state == TelephonyManager.CALL_STATE_OFFHOOK) {
            if (mIsCellularRinging) {
                mIsCellularRinging = false;
                try {
                    JSONObject obj = new JSONObject();
                    obj.put("type", "call_ended");
                    sendJson(obj);
                    log("Cellular call ended or answered (state: " + state + ")");
                } catch (Exception ignored) {}
            }
        }
    }

    public String resolveContactName(String phoneNumber) {
        if (phoneNumber == null || phoneNumber.trim().isEmpty()) return "";
        Cursor cursor = null;
        try {
            if (checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                return "";
            }
            Uri uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(phoneNumber));
            cursor = getContentResolver().query(uri, new String[]{ContactsContract.PhoneLookup.DISPLAY_NAME}, null, null, null);
            if (cursor != null && cursor.moveToFirst()) {
                int nameIdx = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME);
                if (nameIdx >= 0) {
                    return cursor.getString(nameIdx);
                }
            }
        } catch (Exception ignored) {
        } finally {
            if (cursor != null) cursor.close();
        }
        return "";
    }

    public synchronized void registerVoipCall(String key, String packageName, String appName, String title, String subText, Notification.Action answer, Notification.Action decline) {
        mActiveVoipCallKey = key;
        mActiveVoipAnswerAction = answer;
        mActiveVoipDeclineAction = decline;

        try {
            JSONObject obj = new JSONObject();
            obj.put("type", "incoming_call");
            obj.put("call_type", "voip");
            obj.put("package_name", packageName != null ? packageName : "");
            obj.put("app_name", appName != null ? appName : "VoIP");
            obj.put("name", (title != null && !title.isEmpty()) ? title : appName);
            obj.put("number", (subText != null && !subText.isEmpty()) ? subText : appName);
            sendJson(obj);
            log("Incoming VoIP call (" + appName + "): " + title);
        } catch (Exception e) {
            Log.e(TAG, "Error building VoIP incoming call JSON", e);
        }
    }

    public synchronized void unregisterVoipCall(String key) {
        if (key != null && key.equals(mActiveVoipCallKey)) {
            mActiveVoipCallKey = null;
            mActiveVoipAnswerAction = null;
            mActiveVoipDeclineAction = null;
            try {
                JSONObject obj = new JSONObject();
                obj.put("type", "call_ended");
                sendJson(obj);
                log("VoIP call ended/dismissed");
            } catch (Exception ignored) {}
        }
    }

    private void enableSpeakerphone() {
        mHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                try {
                    android.media.AudioManager am = (android.media.AudioManager) getSystemService(Context.AUDIO_SERVICE);
                    if (am == null) return;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        java.util.List<android.media.AudioDeviceInfo> devices = am.getAvailableCommunicationDevices();
                        for (android.media.AudioDeviceInfo dev : devices) {
                            if (dev.getType() == android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                                am.setCommunicationDevice(dev);
                                log("Communication device set to built-in speaker (Android 12+)");
                                return;
                            }
                        }
                    }
                    am.setMode(android.media.AudioManager.MODE_IN_CALL);
                    am.setSpeakerphoneOn(true);
                    log("Speakerphone enabled via AudioManager.");
                } catch (Exception e) {
                    log("Error enabling speakerphone: " + e.getMessage());
                }
            }
        }, 600);
    }

    private void handleCallAction(String action, JSONObject extraData) {
        log("Received call action from Mac: " + action);

        // 0. Handle Outgoing Call (Dialing from Mac)
        if ("dial".equalsIgnoreCase(action)) {
            String number = (extraData != null) ? extraData.optString("number", "") : "";
            if (!number.isEmpty()) {
                try {
                    Intent callIntent;
                    if (checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                        callIntent = new Intent(Intent.ACTION_CALL, Uri.parse("tel:" + Uri.encode(number)));
                    } else {
                        callIntent = new Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(number)));
                    }
                    callIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(callIntent);
                    log("Arama başlatıldı: " + number);
                } catch (Exception e) {
                    log("Arama başlatılamadı (" + number + "): " + e.getMessage());
                }
            }
            return;
        }

        boolean answerNormal = "answer".equalsIgnoreCase(action);
        boolean answerSpeaker = "answer_speaker".equalsIgnoreCase(action);
        boolean answerComputer = "transfer_computer".equalsIgnoreCase(action) || "answer_computer".equalsIgnoreCase(action);

        if (answerNormal || answerSpeaker || answerComputer) {
            if (answerComputer) {
                try {
                    JSONObject statusObj = new JSONObject();
                    statusObj.put("type", "call_status");
                    statusObj.put("status", "on_computer");
                    statusObj.put("message", "Arama bilgisayar masası modunda aktif. Eller serbest hoparlör devrede.");
                    sendJson(statusObj);
                } catch (Exception ignored) {}
            }
            // 1. Check if there is an active VoIP call
            if (mActiveVoipAnswerAction != null && mActiveVoipAnswerAction.actionIntent != null) {
                try {
                    mActiveVoipAnswerAction.actionIntent.send();
                    log("Answered VoIP call via PendingIntent");
                    if (answerSpeaker || answerComputer) {
                        enableSpeakerphone();
                    }
                    return;
                } catch (Exception e) {
                    log("Error answering VoIP call via PendingIntent: " + e.getMessage());
                }
            }

            // 2. Cellular call answer via TelecomManager
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                    if (telecomManager != null) {
                        if (checkSelfPermission(Manifest.permission.ANSWER_PHONE_CALLS) == PackageManager.PERMISSION_GRANTED) {
                            telecomManager.acceptRingingCall();
                            log("Accepted ringing call via TelecomManager");
                            if (answerSpeaker || answerComputer) {
                                enableSpeakerphone();
                            }
                            return;
                        } else {
                            log("ANSWER_PHONE_CALLS permission not granted!");
                        }
                    }
                }
            } catch (SecurityException se) {
                log("SecurityException answering call: " + se.getMessage());
            } catch (Exception e) {
                log("Error accepting call: " + e.getMessage());
            }

            // 3. Fallback: simulate headset hook key event
            try {
                android.media.AudioManager audioManager = (android.media.AudioManager) getSystemService(Context.AUDIO_SERVICE);
                if (audioManager != null) {
                    long now = android.os.SystemClock.uptimeMillis();
                    android.view.KeyEvent down = new android.view.KeyEvent(now, now, android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_HEADSETHOOK, 0);
                    android.view.KeyEvent up = new android.view.KeyEvent(now, now, android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_HEADSETHOOK, 0);
                    audioManager.dispatchMediaKeyEvent(down);
                    audioManager.dispatchMediaKeyEvent(up);
                    log("Dispatched HEADSETHOOK event for answering call");
                    if (answerSpeaker || answerComputer) {
                        enableSpeakerphone();
                    }
                }
            } catch (Exception e) {
                log("Fallback headset hook failed: " + e.getMessage());
            }
        } else if ("reject".equalsIgnoreCase(action) || "decline".equalsIgnoreCase(action) || "end".equalsIgnoreCase(action)) {
            // 1. Check active VoIP call
            if (mActiveVoipDeclineAction != null && mActiveVoipDeclineAction.actionIntent != null) {
                try {
                    mActiveVoipDeclineAction.actionIntent.send();
                    log("Declined VoIP call via PendingIntent");
                    return;
                } catch (Exception e) {
                    log("Error declining VoIP call via PendingIntent: " + e.getMessage());
                }
            }

            // 2. Cellular call decline via TelecomManager
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    TelecomManager telecomManager = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                    if (telecomManager != null) {
                        if (checkSelfPermission(Manifest.permission.ANSWER_PHONE_CALLS) == PackageManager.PERMISSION_GRANTED) {
                            telecomManager.endCall();
                            log("Ended call via TelecomManager");
                            return;
                        }
                    }
                }
            } catch (SecurityException se) {
                log("SecurityException ending call: " + se.getMessage());
            } catch (Exception e) {
                log("Error ending call: " + e.getMessage());
            }

            // 3. Fallback reflection for ITelephony endCall on older Android versions
            try {
                if (mTelephonyManager != null) {
                    Method getITelephony = mTelephonyManager.getClass().getDeclaredMethod("getITelephony");
                    getITelephony.setAccessible(true);
                    Object iTelephony = getITelephony.invoke(mTelephonyManager);
                    if (iTelephony != null) {
                        Method endCall = iTelephony.getClass().getDeclaredMethod("endCall");
                        endCall.invoke(iTelephony);
                        log("Ended call via ITelephony reflection");
                    }
                }
            } catch (Exception e) {
                log("Fallback ITelephony reflection failed: " + e.getMessage());
            }
        }
    }

    private static final java.util.List<String> sLogBuffer = new java.util.ArrayList<>();

    public static synchronized java.util.List<String> getLogs() {
        return new java.util.ArrayList<>(sLogBuffer);
    }

    public static synchronized void clearLogs() {
        sLogBuffer.clear();
    }

    private void log(String msg) {
        Log.d(TAG, msg);
        synchronized (sLogBuffer) {
            String time = new java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(new java.util.Date());
            sLogBuffer.add("[" + time + "] " + msg);
            if (sLogBuffer.size() > 100) {
                sLogBuffer.remove(0);
            }
        }
    }

    public boolean sendClipboardText(String text) {
        if (text == null || text.trim().isEmpty()) return false;
        try {
            JSONObject obj = new JSONObject();
            obj.put("type", "clipboard_text");
            obj.put("text", text);
            obj.put("timestamp", System.currentTimeMillis());
            sendJson(obj);
            log("Sent text to Mac: " + (text.length() > 30 ? text.substring(0, 30) + "..." : text));
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error sending text", e);
            return false;
        }
    }

    public interface FileSendCallback {
        void onProgress(int percent);
        void onComplete(String fileName);
        void onError(String error);
    }

    public void sendFile(final android.net.Uri uri, final String fileName, final long fileSize, final Context context, final FileSendCallback callback) {
        if (mState != Constants.STATE_CONNECTED) {
            if (callback != null) callback.onError("Bluetooth is not connected to Mac.");
            return;
        }

        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    int chunkSize = 12 * 1024;
                    int totalChunks = (int) Math.ceil((double) fileSize / chunkSize);

                    JSONObject startObj = new JSONObject();
                    startObj.put("type", "file_start");
                    startObj.put("file_name", fileName);
                    startObj.put("file_size", fileSize);
                    startObj.put("total_chunks", totalChunks);
                    sendJson(startObj);

                    java.io.InputStream is = context.getContentResolver().openInputStream(uri);
                    if (is == null) {
                        if (callback != null) callback.onError("Cannot open file stream.");
                        return;
                    }

                    byte[] buffer = new byte[chunkSize];
                    int bytesRead;
                    int chunkIdx = 0;
                    long sentBytes = 0;

                    while ((bytesRead = is.read(buffer)) > 0) {
                        String b64 = android.util.Base64.encodeToString(buffer, 0, bytesRead, android.util.Base64.NO_WRAP);
                        JSONObject chunkObj = new JSONObject();
                        chunkObj.put("type", "file_chunk");
                        chunkObj.put("file_name", fileName);
                        chunkObj.put("chunk_index", chunkIdx++);
                        chunkObj.put("data", b64);
                        sendJson(chunkObj);

                        sentBytes += bytesRead;
                        final int progress = (int) ((sentBytes * 100) / (fileSize > 0 ? fileSize : 1));
                        if (callback != null) {
                            mHandler.post(new Runnable() {
                                @Override
                                public void run() {
                                    callback.onProgress(progress);
                                }
                            });
                        }
                        Thread.sleep(15);
                    }
                    is.close();

                    JSONObject endObj = new JSONObject();
                    endObj.put("type", "file_end");
                    endObj.put("file_name", fileName);
                    sendJson(endObj);

                    log("File sent to Mac: " + fileName);
                    if (callback != null) {
                        mHandler.post(new Runnable() {
                            @Override
                            public void run() {
                                callback.onComplete(fileName);
                            }
                        });
                    }
                } catch (Exception e) {
                    Log.e(TAG, "File send error", e);
                    final String err = e.getMessage() != null ? e.getMessage() : "Send error";
                    if (callback != null) {
                        mHandler.post(new Runnable() {
                            @Override
                            public void run() {
                                callback.onError(err);
                            }
                        });
                    }
                }
            }
        }, "FileSenderThread").start();
    }

    // --- Threads ---

    private class AcceptThread extends Thread {
        private BluetoothServerSocket mmServerSocket;

        public AcceptThread() {
            try {
                mmServerSocket = mAdapter.listenUsingInsecureRfcommWithServiceRecord(Constants.SERVICE_NAME, Constants.MACCONNECT_UUID);
                log("Server socket listening on MACCONNECT_UUID");
            } catch (Exception e) {
                log("Insecure listen failed: " + e.getMessage());
                try {
                    mmServerSocket = mAdapter.listenUsingRfcommWithServiceRecord(Constants.SERVICE_NAME, Constants.MACCONNECT_UUID);
                    log("Secure listen socket opened");
                } catch (Exception ex) {
                    log("Server socket error: " + ex.getMessage());
                }
            }
        }

        public void run() {
            setName("AcceptThread");
            while (mState != Constants.STATE_CONNECTED && mmServerSocket != null) {
                try {
                    BluetoothSocket socket = mmServerSocket.accept();
                    if (socket != null) {
                        synchronized (BluetoothService.this) {
                            switch (mState) {
                                case Constants.STATE_DISCONNECTED:
                                case Constants.STATE_CONNECTING:
                                    connected(socket, socket.getRemoteDevice());
                                    break;
                                case Constants.STATE_CONNECTED:
                                    try {
                                        socket.close();
                                    } catch (Exception ignored) {}
                                    break;
                            }
                        }
                        break;
                    }
                } catch (Exception e) {
                    break;
                }
            }
        }

        public void cancel() {
            try {
                if (mmServerSocket != null) mmServerSocket.close();
            } catch (Exception ignored) {}
        }
    }

    private class ConnectThread extends Thread {
        private final BluetoothDevice mmDevice;
        private BluetoothSocket mmSocket;

        public ConnectThread(BluetoothDevice device) {
            mmDevice = device;
            BluetoothSocket tmp = null;
            try {
                tmp = device.createInsecureRfcommSocketToServiceRecord(Constants.MACCONNECT_UUID);
            } catch (Exception e) {
                log("createInsecureRfcommSocket error: " + e.getMessage());
            }
            mmSocket = tmp;
        }

        public void run() {
            setName("ConnectThread");
            if (mAdapter.isDiscovering()) {
                mAdapter.cancelDiscovery();
            }

            boolean success = false;
            try {
                if (mmSocket != null) {
                    mmSocket.connect();
                    success = true;
                }
            } catch (Exception e1) {
                Log.w(TAG, "Standard connect failed, attempting reflection channel 1 fallback...", e1);
                try {
                    Method m = mmDevice.getClass().getMethod("createRfcommSocket", int.class);
                    mmSocket = (BluetoothSocket) m.invoke(mmDevice, 1);
                    if (mmSocket != null) {
                        mmSocket.connect();
                        success = true;
                    }
                } catch (Exception e2) {
                    Log.e(TAG, "Reflection connect fallback also failed", e2);
                    try {
                        if (mmSocket != null) mmSocket.close();
                    } catch (Exception ignored) {}
                }
            }

            if (!success) {
                log("Failed to connect to " + mmDevice.getName());
                connectionLost();
                return;
            }

            synchronized (BluetoothService.this) {
                mConnectThread = null;
            }

            connected(mmSocket, mmDevice);
        }

        public void cancel() {
            try {
                if (mmSocket != null) mmSocket.close();
            } catch (Exception ignored) {}
        }
    }

    private class ConnectedThread extends Thread {
        private final BluetoothSocket mmSocket;
        private final InputStream mmInStream;
        private final OutputStream mmOutStream;
        private final BlockingQueue<String> mSendQueue = new LinkedBlockingQueue<>();
        private volatile boolean mRunning = true;

        public ConnectedThread(BluetoothSocket socket) {
            mmSocket = socket;
            InputStream tmpIn = null;
            OutputStream tmpOut = null;
            try {
                tmpIn = socket.getInputStream();
                tmpOut = socket.getOutputStream();
            } catch (Exception e) {
                Log.e(TAG, "Error getting socket streams", e);
            }
            mmInStream = tmpIn;
            mmOutStream = tmpOut;
        }

        public void run() {
            setName("ConnectedThread");

            // Dedicated writer thread
            Thread writerThread = new Thread(new Runnable() {
                @Override
                public void run() {
                    while (mRunning) {
                        try {
                            String msg = mSendQueue.take();
                            if (mmOutStream != null) {
                                mmOutStream.write(msg.getBytes(StandardCharsets.UTF_8));
                                mmOutStream.flush();
                            }
                        } catch (InterruptedException e) {
                            break;
                        } catch (Exception e) {
                            Log.e(TAG, "Write error", e);
                            cancel();
                            break;
                        }
                    }
                }
            }, "ConnectedWriterThread");
            writerThread.start();

            // Reader
            try {
                BufferedReader reader = new BufferedReader(new InputStreamReader(mmInStream, StandardCharsets.UTF_8));
                String line;
                while (mRunning && (line = reader.readLine()) != null) {
                    final String msg = line.trim();
                    if (!msg.isEmpty()) {
                        mHandler.post(new Runnable() {
                            @Override
                            public void run() {
                                handleIncomingMessage(msg);
                            }
                        });
                    }
                }
            } catch (Exception e) {
                Log.d(TAG, "Disconnected or stream closed", e);
            } finally {
                mRunning = false;
                writerThread.interrupt();
                cancel();
                connectionLost();
            }
        }

        public void write(String data) {
            mSendQueue.offer(data);
        }

        public void cancel() {
            mRunning = false;
            try {
                if (mmSocket != null) mmSocket.close();
            } catch (Exception ignored) {}
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    Constants.NOTIF_CHANNEL_ID,
                    getString(R.string.notif_channel_name),
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription(getString(R.string.notif_channel_desc));
            channel.setShowBadge(false);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) {
                nm.createNotificationChannel(channel);
            }
        }
    }

    private Notification buildForegroundNotification(String statusText) {
        Intent notifIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this, 0, notifIntent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
        );

        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, Constants.NOTIF_CHANNEL_ID);
        } else {
            builder = new Notification.Builder(this);
        }

        return builder.setContentTitle("MacConnect")
                .setContentText(statusText)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build();
    }

    private void updateForegroundNotification(String statusText) {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) {
            nm.notify(NOTIF_ID, buildForegroundNotification(statusText));
        }
    }
}
