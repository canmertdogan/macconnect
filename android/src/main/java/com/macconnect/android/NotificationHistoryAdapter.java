package com.macconnect.android;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class NotificationHistoryAdapter extends BaseAdapter {
    private final Context mContext;
    private final LayoutInflater mInflater;
    private final List<NotificationItem> mItems = new ArrayList<>();
    private final SimpleDateFormat mTimeFormat = new SimpleDateFormat("HH:mm:ss", Locale.getDefault());

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
            holder.tvTitle.setText(item.getTitle().isEmpty() ? "(Başlık Yok)" : item.getTitle());
            holder.tvBody.setText(item.getText().isEmpty() ? item.getSubText() : item.getText());
        }

        return convertView;
    }
}
