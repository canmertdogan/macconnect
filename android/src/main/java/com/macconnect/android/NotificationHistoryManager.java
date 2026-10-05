package com.macconnect.android;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class NotificationHistoryManager {
    private static final String FILE_NAME = "notification_history.json";
    private static final int MAX_ITEMS = 200;
    private static NotificationHistoryManager sInstance;

    private final Context mContext;
    private final List<NotificationItem> mItems = new ArrayList<>();
    private boolean mLoaded = false;

    public static synchronized NotificationHistoryManager getInstance(Context context) {
        if (sInstance == null) {
            sInstance = new NotificationHistoryManager(context.getApplicationContext());
        }
        return sInstance;
    }

    private NotificationHistoryManager(Context context) {
        mContext = context;
        load();
    }

    public synchronized void addNotification(NotificationItem item) {
        if (item == null) return;
        if (!mLoaded) load();

        // Add to front (newest first)
        mItems.add(0, item);
        if (mItems.size() > MAX_ITEMS) {
            mItems.remove(mItems.size() - 1);
        }
        save();
    }

    public synchronized List<NotificationItem> getHistory() {
        if (!mLoaded) load();
        return new ArrayList<>(mItems);
    }

    public synchronized void clearHistory() {
        mItems.clear();
        save();
    }

    private void load() {
        mItems.clear();
        File file = new File(mContext.getFilesDir(), FILE_NAME);
        if (!file.exists()) {
            mLoaded = true;
            return;
        }

        try (FileInputStream fis = new FileInputStream(file);
             BufferedReader reader = new BufferedReader(new InputStreamReader(fis, StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line);
            }
            JSONArray arr = new JSONArray(sb.toString());
            for (int i = 0; i < arr.length(); i++) {
                JSONObject obj = arr.getJSONObject(i);
                NotificationItem item = NotificationItem.fromJson(obj);
                if (item != null) {
                    mItems.add(item);
                }
            }
        } catch (Exception ignored) {}
        mLoaded = true;
    }

    private void save() {
        try {
            JSONArray arr = new JSONArray();
            for (NotificationItem item : mItems) {
                arr.put(item.toJson());
            }
            File file = new File(mContext.getFilesDir(), FILE_NAME);
            try (FileOutputStream fos = new FileOutputStream(file)) {
                fos.write(arr.toString().getBytes(StandardCharsets.UTF_8));
            }
        } catch (Exception ignored) {}
    }
}
