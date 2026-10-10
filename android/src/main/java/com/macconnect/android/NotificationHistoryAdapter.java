package com.macconnect.android;

import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.drawable.Drawable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class NotificationHistoryAdapter extends BaseAdapter {
    private final Context mContext;
    private final LayoutInflater mInflater;
    private final List<NotificationItem> mItems = new ArrayList<>();
    private final SimpleDateFormat mTimeFormat = new SimpleDateFormat("HH:mm", Locale.getDefault());
    private final Map<String, Drawable> mIconCache = new HashMap<>();

    public NotificationHistoryAdapter(Context context) {
        mContext = context;
        mInflater = LayoutInflater.from(context);
    }

    public void updateData(List<NotificationItem> items) {
        mItems.clear();
        if (items != null) {
            mItems.addAll(items);
        }
        notifyDataSetChanged();
    }

    @Override
    public int getCount() {
        return mItems.size();
    }

    @Override
    public NotificationItem getItem(int position) {
        return mItems.get(position);
    }

    @Override
    public long getItemId(int position) {
        return position;
    }

    private static class ViewHolder {
        ImageView ivIcon;
        TextView tvAppName;
        TextView tvTime;
        TextView tvTitle;
        TextView tvBody;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        ViewHolder holder;
        if (convertView == null) {
            convertView = mInflater.inflate(R.layout.item_notification, parent, false);
            holder = new ViewHolder();
            holder.ivIcon = convertView.findViewById(R.id.iv_item_icon);
            holder.tvAppName = convertView.findViewById(R.id.tv_item_app_name);
            holder.tvTime = convertView.findViewById(R.id.tv_item_time);
            holder.tvTitle = convertView.findViewById(R.id.tv_item_title);
            holder.tvBody = convertView.findViewById(R.id.tv_item_body);
            convertView.setTag(holder);
        } else {
            holder = (ViewHolder) convertView.getTag();
        }

        NotificationItem item = getItem(position);
        if (item != null) {
            holder.tvAppName.setText(item.getAppName().isEmpty() ? item.getPackageName() : item.getAppName());
            holder.tvTime.setText(mTimeFormat.format(new Date(item.getTimestamp())));
            holder.tvTitle.setText(item.getTitle().isEmpty() ? "(No Title)" : item.getTitle());
            holder.tvBody.setText(item.getText().isEmpty() ? item.getSubText() : item.getText());

            Drawable icon = getCachedAppIcon(item.getPackageName());
            if (icon != null) {
                holder.ivIcon.setImageDrawable(icon);
            } else {
                holder.ivIcon.setImageResource(R.mipmap.ic_launcher);
            }
        }

        return convertView;
    }

    private Drawable getCachedAppIcon(String packageName) {
        if (packageName == null || packageName.isEmpty()) return null;
        if (mIconCache.containsKey(packageName)) {
            return mIconCache.get(packageName);
        }
        try {
            PackageManager pm = mContext.getPackageManager();
            Drawable d = pm.getApplicationIcon(packageName);
            mIconCache.put(packageName, d);
            return d;
        } catch (Exception ignored) {
            return null;
        }
    }
}
