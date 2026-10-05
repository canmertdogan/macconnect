package com.macconnect.android;

import android.app.Notification;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

public class NotificationListener extends NotificationListenerService {
    private static final String TAG = "MacConnectNotif";
    private static NotificationListener sInstance;

    public static NotificationListener getInstance() {
        return sInstance;
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        sInstance = this;
        Log.d(TAG, "NotificationListener connected.");
    }

    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        sInstance = null;
        Log.d(TAG, "NotificationListener disconnected.");
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null) return;

        String packageName = sbn.getPackageName();
        // Ignore our own notifications
        if (getPackageName().equals(packageName)) {
            return;
        }

        Notification notification = sbn.getNotification();
        if (notification == null) return;

        // Skip ongoing notifications that are just persistent foreground services (music players, download bars)
        // unless they have valid non-empty content
        boolean isOngoing = sbn.isOngoing();

        Bundle extras = notification.extras;
        if (extras == null) return;

        CharSequence titleCs = extras.getCharSequence(Notification.EXTRA_TITLE);
        CharSequence textCs = extras.getCharSequence(Notification.EXTRA_TEXT);
        CharSequence bigTextCs = extras.getCharSequence(Notification.EXTRA_BIG_TEXT);
        CharSequence subTextCs = extras.getCharSequence(Notification.EXTRA_SUB_TEXT);

        String title = titleCs != null ? titleCs.toString() : "";
        String text = (bigTextCs != null && bigTextCs.length() > 0) ? bigTextCs.toString() : (textCs != null ? textCs.toString() : "");
        String subText = subTextCs != null ? subTextCs.toString() : "";

        // If both title and text are blank, ignore
        if (title.trim().isEmpty() && text.trim().isEmpty()) {
            return;
        }

        String appName = packageName;
        try {
            PackageManager pm = getPackageManager();
            ApplicationInfo appInfo = pm.getApplicationInfo(packageName, 0);
            CharSequence label = pm.getApplicationLabel(appInfo);
            if (label != null) {
                appName = label.toString();
            }
        } catch (Exception ignored) {}

        BluetoothService btService = BluetoothService.getInstance();
        if (btService != null) {
            btService.sendNotification(
                    sbn.getKey(),
                    packageName,
                    appName,
                    title,
                    text,
                    subText,
                    sbn.getPostTime(),
                    isOngoing
            );
        }

        // Save to persistent notification history
        NotificationHistoryManager.getInstance(this).addNotification(
                new NotificationItem(sbn.getKey(), packageName, appName, title, text, subText, sbn.getPostTime())
        );
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        if (sbn == null) return;
        if (getPackageName().equals(sbn.getPackageName())) return;

        BluetoothService btService = BluetoothService.getInstance();
        if (btService != null) {
            btService.sendNotificationRemoved(sbn.getKey(), sbn.getPackageName());
        }
    }

    public void cancelNotificationByKey(String key) {
        try {
            cancelNotification(key);
        } catch (Exception e) {
            Log.e(TAG, "Error cancelling notification", e);
        }
    }
}
