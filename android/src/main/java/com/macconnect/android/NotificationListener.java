package com.macconnect.android;

import android.app.Notification;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.app.RemoteInput;
import android.content.Intent;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Base64;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.util.HashMap;
import java.util.Map;

public class NotificationListener extends NotificationListenerService {
    private static final String TAG = "MacConnectNotif";
    private static NotificationListener sInstance;

    public static class ReplyActionHolder {
        public final Notification.Action action;
        public final RemoteInput[] remoteInputs;

        public ReplyActionHolder(Notification.Action action, RemoteInput[] remoteInputs) {
            this.action = action;
            this.remoteInputs = remoteInputs;
        }
    }

    private static final Map<String, ReplyActionHolder> sReplyHolders = new HashMap<>();
    private static final Map<String, String> sNameCache = new HashMap<>();
    private static final Map<String, String> sIconCache = new HashMap<>();

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
        if (packageName == null || getPackageName().equals(packageName)) {
            return;
        }

        Notification notification = sbn.getNotification();
        if (notification == null) return;

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

        // Check for InboxStyle text lines (multi-message notifications)
        CharSequence[] textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES);
        if (textLines != null && textLines.length > 0) {
            StringBuilder sb = new StringBuilder();
            if (text.length() > 0) {
                sb.append(text).append("\n");
            }
            for (CharSequence line : textLines) {
                if (line != null && line.length() > 0) {
                    sb.append(line).append("\n");
                }
            }
            text = sb.toString().trim();
        }

        // If both title and text are blank, ignore
        if (title.trim().isEmpty() && text.trim().isEmpty()) {
            return;
        }

        String appName = resolveAppName(packageName);
        String iconB64 = getAppIconBase64(packageName);

        BluetoothService btService = BluetoothService.getInstance();

        // VoIP / Call Detection (WhatsApp, Telegram, etc.)
        boolean isCallCategory = Notification.CATEGORY_CALL.equals(notification.category);
        // Direct reply detection (WhatsApp, Telegram, SMS, Signal, etc.)
        boolean canReply = false;
        Notification.Action answerAction = null;
        Notification.Action declineAction = null;

        if (notification.actions != null) {
            for (Notification.Action act : notification.actions) {
                if (act == null) continue;
                if (act.title != null) {
                    String actTitle = act.title.toString().toLowerCase(java.util.Locale.ROOT);
                    if (actTitle.contains("cevapla") || actTitle.contains("yanıtla") || actTitle.contains("answer") || actTitle.contains("accept")) {
                        answerAction = act;
                    } else if (actTitle.contains("reddet") || actTitle.contains("decline") || actTitle.contains("dismiss") || actTitle.contains("iptal") || actTitle.contains("asla")) {
                        declineAction = act;
                    }
                }
                RemoteInput[] ris = act.getRemoteInputs();
                if (ris != null && ris.length > 0) {
                    sReplyHolders.put(sbn.getKey(), new ReplyActionHolder(act, ris));
                    canReply = true;
                }
            }
        }

        // Media Player Detection (Spotify, Deezer, YouTube Music, podcasts, etc.)
        boolean isMedia = false;
        if (Notification.CATEGORY_TRANSPORT.equals(notification.category)) {
            isMedia = true;
        } else if (extras.containsKey(Notification.EXTRA_MEDIA_SESSION)) {
            isMedia = true;
        } else {
            String template = extras.getString(Notification.EXTRA_TEMPLATE, "");
            if (template != null && template.contains("MediaStyle")) {
                isMedia = true;
            } else if (packageName != null) {
                String pkgLower = packageName.toLowerCase(java.util.Locale.ROOT);
                if ((pkgLower.contains("spotify") || pkgLower.contains("deezer") || pkgLower.contains("music") ||
                     pkgLower.contains("podcast") || pkgLower.contains("tidal") || pkgLower.contains("soundcloud") ||
                     pkgLower.contains("audioplayer")) && isOngoing) {
                    isMedia = true;
                }
            }
        }

        if (isMedia) {
            if (btService != null) {
                btService.sendMediaPlayback(packageName, appName, title, text, subText, iconB64);
            }
            // Do not spam regular notification banners or sound on Mac for ongoing media playback ticks
            return;
        }

        if (isCallCategory || (answerAction != null && declineAction != null)) {
            if (btService != null) {
                btService.registerVoipCall(sbn.getKey(), packageName, appName, title, subText, answerAction, declineAction);
            }
        }

        if (btService != null) {
            btService.sendNotification(
                    sbn.getKey(),
                    packageName,
                    appName,
                    title,
                    text,
                    subText,
                    iconB64,
                    sbn.getPostTime(),
                    isOngoing,
                    canReply
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

        sReplyHolders.remove(sbn.getKey());

        BluetoothService btService = BluetoothService.getInstance();
        if (btService != null) {
            btService.unregisterVoipCall(sbn.getKey());
            btService.sendNotificationRemoved(sbn.getKey(), sbn.getPackageName());
        }
    }

    public boolean replyToNotification(String key, String text) {
        if (key == null || text == null || text.trim().isEmpty()) return false;
        ReplyActionHolder holder = sReplyHolders.get(key);
        if (holder == null || holder.action == null || holder.remoteInputs == null) {
            Log.w(TAG, "No reply action holder found for notification key: " + key);
            return false;
        }
        try {
            Intent replyIntent = new Intent();
            Bundle bundle = new Bundle();
            for (RemoteInput ri : holder.remoteInputs) {
                bundle.putCharSequence(ri.getResultKey(), text);
            }
            RemoteInput.addResultsToIntent(holder.remoteInputs, replyIntent, bundle);
            holder.action.actionIntent.send(this, 0, replyIntent);
            Log.d(TAG, "Direct reply sent successfully to " + key + ": " + text);
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Failed to send direct reply to notification: " + key, e);
            return false;
        }
    }

    public void cancelNotificationByKey(String key) {
        try {
            cancelNotification(key);
        } catch (Exception e) {
            Log.e(TAG, "Error cancelling notification", e);
        }
    }

    private String resolveAppName(String packageName) {
        if (packageName == null || packageName.isEmpty()) return "Phone";
        synchronized (sNameCache) {
            if (sNameCache.containsKey(packageName)) {
                return sNameCache.get(packageName);
            }
        }

        String appName = null;
        try {
            PackageManager pm = getPackageManager();
            ApplicationInfo appInfo = pm.getApplicationInfo(packageName, 0);
            CharSequence label = pm.getApplicationLabel(appInfo);
            if (label != null && label.length() > 0) {
                appName = label.toString().trim();
            }
        } catch (Exception ignored) {}

        if (appName == null || appName.isEmpty() || appName.equalsIgnoreCase(packageName)) {
            appName = cleanPackageName(packageName);
        }

        synchronized (sNameCache) {
            sNameCache.put(packageName, appName);
        }
        return appName;
    }

    private String cleanPackageName(String pkg) {
        if ("com.google.android.calendar".equals(pkg)) return "Google Calendar";
        if ("com.google.android.gm".equals(pkg)) return "Gmail";
        if ("com.google.android.apps.messaging".equals(pkg)) return "Messages";
        if ("com.google.android.youtube".equals(pkg)) return "YouTube";
        if ("com.google.android.apps.photos".equals(pkg)) return "Google Photos";
        if ("com.google.android.apps.maps".equals(pkg)) return "Google Maps";
        if ("com.google.android.deskclock".equals(pkg)) return "Clock";
        if ("com.google.android.keep".equals(pkg)) return "Google Keep";
        if ("com.whatsapp".equals(pkg)) return "WhatsApp";
        if ("org.telegram.messenger".equals(pkg)) return "Telegram";
        if ("com.instagram.android".equals(pkg)) return "Instagram";
        if ("com.twitter.android".equals(pkg) || "com.x.android".equals(pkg)) return "X";
        if ("com.spotify.music".equals(pkg)) return "Spotify";
        if ("com.facebook.katana".equals(pkg)) return "Facebook";
        if ("com.facebook.orca".equals(pkg)) return "Messenger";
        if ("com.slack".equals(pkg)) return "Slack";
        if ("com.discord".equals(pkg)) return "Discord";
        if ("com.microsoft.teams".equals(pkg)) return "Teams";
        if ("com.microsoft.office.outlook".equals(pkg)) return "Outlook";
        if ("com.netflix.mediaclient".equals(pkg)) return "Netflix";

        // Fallback: extract meaningful segment e.g. com.miui.notes -> Notes
        try {
            String last = pkg;
            int lastDot = pkg.lastIndexOf('.');
            if (lastDot >= 0 && lastDot < pkg.length() - 1) {
                last = pkg.substring(lastDot + 1);
            }
            if (last.equalsIgnoreCase("android") || last.equalsIgnoreCase("app")) {
                String[] parts = pkg.split("\\.");
                if (parts.length >= 2) {
                    last = parts[parts.length - 2];
                }
            }
            last = last.replace('_', ' ');
            if (last.length() > 0) {
                return Character.toUpperCase(last.charAt(0)) + last.substring(1);
            }
        } catch (Exception ignored) {}

        return pkg;
    }

    private String getAppIconBase64(String packageName) {
        if (packageName == null || packageName.isEmpty()) return "";
        synchronized (sIconCache) {
            if (sIconCache.containsKey(packageName)) {
                return sIconCache.get(packageName);
            }
        }
        String b64 = "";
        try {
            PackageManager pm = getPackageManager();
            Drawable drawable = pm.getApplicationIcon(packageName);
            b64 = drawableToBase64(drawable, 96);
        } catch (Exception ignored) {}

        synchronized (sIconCache) {
            sIconCache.put(packageName, b64);
        }
        return b64;
    }

    private String drawableToBase64(Drawable drawable, int targetSize) {
        if (drawable == null) return "";
        try {
            Bitmap bitmap;
            if (drawable instanceof BitmapDrawable) {
                Bitmap orig = ((BitmapDrawable) drawable).getBitmap();
                if (orig != null) {
                    if (orig.getWidth() > targetSize || orig.getHeight() > targetSize) {
                        bitmap = Bitmap.createScaledBitmap(orig, targetSize, targetSize, true);
                    } else {
                        bitmap = orig;
                    }
                } else {
                    bitmap = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888);
                }
            } else {
                int width = drawable.getIntrinsicWidth() > 0 ? Math.min(drawable.getIntrinsicWidth(), targetSize) : targetSize;
                int height = drawable.getIntrinsicHeight() > 0 ? Math.min(drawable.getIntrinsicHeight(), targetSize) : targetSize;
                bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                Canvas canvas = new Canvas(bitmap);
                drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
                drawable.draw(canvas);
            }

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            bitmap.compress(Bitmap.CompressFormat.PNG, 90, baos);
            return Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP);
        } catch (Exception e) {
            return "";
        }
    }
}
