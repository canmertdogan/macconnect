package com.macconnect.android;

import org.json.JSONObject;

public class NotificationItem {
    private final String id;
    private final String packageName;
    private final String appName;
    private final String title;
    private final String text;
    private final String subText;
    private final long timestamp;

    public NotificationItem(String id, String packageName, String appName, String title, String text, String subText, long timestamp) {
        this.id = id != null ? id : "";
        this.packageName = packageName != null ? packageName : "";
        this.appName = appName != null ? appName : packageName;
        this.title = title != null ? title : "";
        this.text = text != null ? text : "";
        this.subText = subText != null ? subText : "";
        this.timestamp = timestamp > 0 ? timestamp : System.currentTimeMillis();
    }

    public String getId() { return id; }
    public String getPackageName() { return packageName; }
    public String getAppName() { return appName; }
    public String getTitle() { return title; }
    public String getText() { return text; }
    public String getSubText() { return subText; }
    public long getTimestamp() { return timestamp; }

    public JSONObject toJson() {
        JSONObject obj = new JSONObject();
        try {
            obj.put("id", id);
            obj.put("package", packageName);
            obj.put("app_name", appName);
            obj.put("title", title);
            obj.put("text", text);
            obj.put("sub_text", subText);
            obj.put("timestamp", timestamp);
        } catch (Exception ignored) {}
        return obj;
    }

    public static NotificationItem fromJson(JSONObject obj) {
        if (obj == null) return null;
        return new NotificationItem(
                obj.optString("id"),
                obj.optString("package"),
                obj.optString("app_name"),
                obj.optString("title"),
                obj.optString("text"),
                obj.optString("sub_text"),
                obj.optLong("timestamp")
        );
    }
}
