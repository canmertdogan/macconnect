package com.macconnect.android;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.OpenableColumns;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public class MainActivity extends Activity {
    private static final int REQ_BT_PERMS = 101;
    private static final int REQ_CALL_PERMS = 102;
    private static final int REQ_PICK_FILE = 201;

    // Header & Tabs
    private View mViewHeaderDot;
    private TextView mTvHeaderStatus;
    private Button mBtnTabTools;
    private Button mBtnTabHistory;
    private Button mBtnTabSettings;

    // Tab Containers
    private ScrollView mLayoutTabTools;
    private View mLayoutTabHistory;
    private ScrollView mLayoutTabSettings;

    // Tab 1: Connection & Tools
    private View mViewStatusDot;
    private TextView mTvStatusTitle;
    private TextView mTvStatusDetail;
    private TextView mTvBatteryBadge;
    private Spinner mSpinnerDevices;
    private Button mBtnConnect;
    private Button mBtnRefresh;

    // Text & Clipboard Sharing
    private EditText mEtShareText;
    private Button mBtnPasteClipboard;
    private Button mBtnSendText;

    // File Sharing
    private Button mBtnChooseFile;
    private TextView mTvFileStatus;
    private ProgressBar mProgressBarFile;

    // Diagnostics & Logs
    private Button mBtnTestNotif;
    private Button mBtnShowLogs;

    // Tab 2: Notification History
    private TextView mTvHistoryHeader;
    private Button mBtnClearHistory;
    private TextView mTvHistoryEmpty;
    private ListView mLvHistory;
    private NotificationHistoryAdapter mHistoryAdapter;

    // Tab 3: Settings & Battery Optimization
    private TextView mTvBatteryOptBadge;
    private Button mBtnBatteryOpt;
    private TextView mTvNotifPermStatus;
    private Button mBtnGrantNotif;
    private TextView mTvBtPermStatus;
    private Button mBtnGrantBt;
    private TextView mTvCallPermStatus;
    private Button mBtnGrantCall;
    private Button mBtnBatterySettings;

    // Bluetooth Devices
    private final List<BluetoothDevice> mDeviceList = new ArrayList<>();
    private final List<String> mDeviceLabels = new ArrayList<>();
    private ArrayAdapter<String> mSpinnerAdapter;

    private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent == null) return;
            String action = intent.getAction();
            if (Constants.ACTION_STATE_CHANGED.equals(action)) {
                int state = intent.getIntExtra(Constants.EXTRA_STATE, Constants.STATE_DISCONNECTED);
                String devName = intent.getStringExtra(Constants.EXTRA_DEVICE_NAME);
                updateConnectionUI(state, devName);
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        initViews();
        setupTabs();
        setupDeviceSpinner();
        setupNotificationHistory();
        checkAndRequestPermissions();
        startBluetoothService();
        refreshPairedDevices();
    }

    private void initViews() {
        // Header
        mViewHeaderDot = findViewById(R.id.view_header_dot);
        mTvHeaderStatus = findViewById(R.id.tv_header_status);

        // Tab buttons
        mBtnTabTools = findViewById(R.id.btn_tab_tools);
        mBtnTabHistory = findViewById(R.id.btn_tab_history);
        mBtnTabSettings = findViewById(R.id.btn_tab_settings);

        // Tab containers
        mLayoutTabTools = findViewById(R.id.layout_tab_tools);
        mLayoutTabHistory = findViewById(R.id.layout_tab_history);
        mLayoutTabSettings = findViewById(R.id.layout_tab_settings);

        // Tab 1 Views
        mViewStatusDot = findViewById(R.id.view_status_dot);
        mTvStatusTitle = findViewById(R.id.tv_status_title);
        mTvStatusDetail = findViewById(R.id.tv_status_detail);
        mTvBatteryBadge = findViewById(R.id.tv_battery_badge);
        mSpinnerDevices = findViewById(R.id.spinner_devices);
        mBtnConnect = findViewById(R.id.btn_connect);
        mBtnRefresh = findViewById(R.id.btn_refresh);

        mEtShareText = findViewById(R.id.et_share_text);
        mBtnPasteClipboard = findViewById(R.id.btn_paste_clipboard);
        mBtnSendText = findViewById(R.id.btn_send_text);

        mBtnChooseFile = findViewById(R.id.btn_choose_file);
        mTvFileStatus = findViewById(R.id.tv_file_status);
        mProgressBarFile = findViewById(R.id.progressbar_file);

        mBtnTestNotif = findViewById(R.id.btn_test_notif);
        mBtnShowLogs = findViewById(R.id.btn_show_logs);

        // Tab 2 Views
        mTvHistoryHeader = findViewById(R.id.tv_history_header);
        mBtnClearHistory = findViewById(R.id.btn_clear_history);
        mTvHistoryEmpty = findViewById(R.id.tv_history_empty);
        mLvHistory = findViewById(R.id.lv_history);

        // Tab 3 Views
        mTvBatteryOptBadge = findViewById(R.id.tv_battery_opt_badge);
        mBtnBatteryOpt = findViewById(R.id.btn_battery_opt);
        mTvNotifPermStatus = findViewById(R.id.tv_notif_perm_status);
        mBtnGrantNotif = findViewById(R.id.btn_grant_notif);
        mTvBtPermStatus = findViewById(R.id.tv_bt_perm_status);
        mBtnGrantBt = findViewById(R.id.btn_grant_bt);
        mTvCallPermStatus = findViewById(R.id.tv_call_perm_status);
        mBtnGrantCall = findViewById(R.id.btn_grant_call);
        mBtnBatterySettings = findViewById(R.id.btn_battery_settings);

        setDotColor(Color.parseColor("#EF4444"));
        updateBatteryDisplay();

        // Tab 1 Click Listeners
        mBtnConnect.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                int pos = mSpinnerDevices.getSelectedItemPosition();
                if (pos >= 0 && pos < mDeviceList.size()) {
                    BluetoothDevice device = mDeviceList.get(pos);
                    Intent intent = new Intent(MainActivity.this, BluetoothService.class);
                    intent.setAction(Constants.ACTION_CONNECT_DEVICE);
                    intent.putExtra(Constants.EXTRA_DEVICE_ADDRESS, device.getAddress());
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent);
                    } else {
                        startService(intent);
                    }
                    Toast.makeText(MainActivity.this, "Mac'e bağlanılıyor...", Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(MainActivity.this, "Lütfen listeden eşleşmiş Mac cihazını seçin.", Toast.LENGTH_LONG).show();
                }
            }
        });

        mBtnRefresh.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                refreshPairedDevices();
                BluetoothService svc = BluetoothService.getInstance();
                if (svc != null) {
                    svc.startServerListening();
                }
                Toast.makeText(MainActivity.this, "Cihazlar yenilendi ve dinleyici başlatıldı.", Toast.LENGTH_SHORT).show();
            }
        });

        mBtnPasteClipboard.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                pasteFromClipboard();
            }
        });

        mBtnSendText.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                sendTextToMac();
            }
        });

        mBtnChooseFile.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openFilePicker();
            }
        });

        mBtnTestNotif.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent intent = new Intent(MainActivity.this, BluetoothService.class);
                intent.setAction(Constants.ACTION_SEND_TEST);
                startService(intent);
                Toast.makeText(MainActivity.this, "Test bildirimi gönderildi.", Toast.LENGTH_SHORT).show();
            }
        });

        mBtnShowLogs.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showLogsDialog();
            }
        });

        // Tab 2 Click Listeners
        mBtnClearHistory.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmClearHistory();
            }
        });

        // Tab 3 Click Listeners
        mBtnBatteryOpt.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                requestIgnoreBatteryOptimizations();
            }
        });

        mBtnGrantNotif.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
                startActivity(intent);
                Toast.makeText(MainActivity.this, "MacConnect'i bulun ve izin anahtarını açın.", Toast.LENGTH_LONG).show();
            }
        });

        mBtnGrantBt.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                requestBluetoothPermissions();
            }
        });

        mBtnGrantCall.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                requestCallPermissions();
            }
        });

        mBtnBatterySettings.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                try {
                    Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                    intent.setData(Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                } catch (Exception e) {
                    Toast.makeText(MainActivity.this, "Ayarlar açılamadı.", Toast.LENGTH_SHORT).show();
                }
            }
        });
    }

    private void setupTabs() {
        mBtnTabTools.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectTab(0);
            }
        });

        mBtnTabHistory.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectTab(1);
            }
        });

        mBtnTabSettings.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                selectTab(2);
            }
        });
    }

    private void selectTab(int index) {
        mBtnTabTools.setBackgroundResource(index == 0 ? R.drawable.bg_tab_selected : R.drawable.bg_tab_unselected);
        mBtnTabTools.setTextColor(index == 0 ? Color.WHITE : Color.parseColor("#71717A"));

        mBtnTabHistory.setBackgroundResource(index == 1 ? R.drawable.bg_tab_selected : R.drawable.bg_tab_unselected);
        mBtnTabHistory.setTextColor(index == 1 ? Color.WHITE : Color.parseColor("#71717A"));

        mBtnTabSettings.setBackgroundResource(index == 2 ? R.drawable.bg_tab_selected : R.drawable.bg_tab_unselected);
        mBtnTabSettings.setTextColor(index == 2 ? Color.WHITE : Color.parseColor("#71717A"));

        mLayoutTabTools.setVisibility(index == 0 ? View.VISIBLE : View.GONE);
        mLayoutTabHistory.setVisibility(index == 1 ? View.VISIBLE : View.GONE);
        mLayoutTabSettings.setVisibility(index == 2 ? View.VISIBLE : View.GONE);

        if (index == 1) {
            refreshNotificationHistory();
        } else if (index == 2) {
            updateBatteryOptimizationUI();
        }
    }

    private void setupNotificationHistory() {
        mHistoryAdapter = new NotificationHistoryAdapter(this);
        mLvHistory.setAdapter(mHistoryAdapter);

        mLvHistory.setOnItemClickListener(new android.widget.AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(android.widget.AdapterView<?> parent, View view, int position, long id) {
                NotificationItem item = mHistoryAdapter.getItem(position);
                if (item != null) {
                    showNotificationDetailDialog(item);
                }
            }
        });
    }

    private void showNotificationDetailDialog(final NotificationItem item) {
        View dialogView = getLayoutInflater().inflate(R.layout.dialog_notification_detail, null);

        android.widget.ImageView ivIcon = dialogView.findViewById(R.id.iv_detail_icon);
        TextView tvAppName = dialogView.findViewById(R.id.tv_detail_app_name);
        TextView tvTime = dialogView.findViewById(R.id.tv_detail_time);
        TextView tvPackage = dialogView.findViewById(R.id.tv_detail_package);
        TextView tvTitle = dialogView.findViewById(R.id.tv_detail_title);
        TextView tvSubtext = dialogView.findViewById(R.id.tv_detail_subtext);
        TextView tvBody = dialogView.findViewById(R.id.tv_detail_body);
        Button btnCopy = dialogView.findViewById(R.id.btn_detail_copy);
        Button btnClose = dialogView.findViewById(R.id.btn_detail_close);

        String appName = item.getAppName().isEmpty() ? item.getPackageName() : item.getAppName();
        tvAppName.setText(appName);

        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("dd MMMM yyyy, HH:mm:ss", new Locale("tr", "TR"));
        tvTime.setText(sdf.format(new java.util.Date(item.getTimestamp())));
        tvPackage.setText(item.getPackageName());

        tvTitle.setText(item.getTitle().isEmpty() ? "(Başlık Yok)" : item.getTitle());

        if (item.getSubText() != null && !item.getSubText().isEmpty()) {
            tvSubtext.setText(item.getSubText());
            tvSubtext.setVisibility(View.VISIBLE);
        } else {
            tvSubtext.setVisibility(View.GONE);
        }

        String fullText = item.getText().isEmpty() ? item.getSubText() : item.getText();
        if (fullText.isEmpty()) {
            fullText = "(İçerik boş)";
        }
        tvBody.setText(fullText);

        try {
            android.graphics.drawable.Drawable icon = getPackageManager().getApplicationIcon(item.getPackageName());
            ivIcon.setImageDrawable(icon);
        } catch (Exception ignored) {
            ivIcon.setImageResource(R.mipmap.ic_launcher);
        }

        final AlertDialog dialog = new AlertDialog.Builder(this)
                .setView(dialogView)
                .create();

        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(Color.TRANSPARENT));
        }

        btnCopy.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                if (clipboard != null) {
                    String toCopy = (item.getTitle().isEmpty() ? "" : item.getTitle() + "\n\n") +
                                   (item.getText().isEmpty() ? item.getSubText() : item.getText());
                    ClipData clip = ClipData.newPlainText("MacConnect Notification", toCopy.trim());
                    clipboard.setPrimaryClip(clip);
                    Toast.makeText(MainActivity.this, "Bildirim içeriği panoya kopyalandı.", Toast.LENGTH_SHORT).show();
                }
            }
        });

        btnClose.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.dismiss();
            }
        });

        dialog.show();
    }

    private void refreshNotificationHistory() {
        List<NotificationItem> history = NotificationHistoryManager.getInstance(this).getHistory();
        mHistoryAdapter.updateData(history);
        mTvHistoryHeader.setText("Bildirim Geçmişi (" + history.size() + ")");

        if (history.isEmpty()) {
            mTvHistoryEmpty.setVisibility(View.VISIBLE);
            mLvHistory.setVisibility(View.GONE);
        } else {
            mTvHistoryEmpty.setVisibility(View.GONE);
            mLvHistory.setVisibility(View.VISIBLE);
        }
    }

    private void confirmClearHistory() {
        new AlertDialog.Builder(this)
                .setTitle("Geçmişi Temizle")
                .setMessage("Tüm kaydedilmiş bildirim geçmişi silinsin mi?")
                .setPositiveButton("Temizle", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        NotificationHistoryManager.getInstance(MainActivity.this).clearHistory();
                        refreshNotificationHistory();
                        Toast.makeText(MainActivity.this, "Bildirim geçmişi temizlendi.", Toast.LENGTH_SHORT).show();
                    }
                })
                .setNegativeButton("İptal", null)
                .show();
    }

    // --- Battery Optimizations ---

    private void updateBatteryDisplay() {
        try {
            IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
            Intent batteryStatus = registerReceiver(null, filter);
            if (batteryStatus != null) {
                int level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                int scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
                if (level >= 0 && scale > 0) {
                    int percent = (level * 100) / scale;
                    mTvBatteryBadge.setText("🔋 %" + percent);
                }
            }
        } catch (Exception ignored) {}
    }

    private void updateBatteryOptimizationUI() {
        boolean isIgnored = isIgnoringBatteryOptimizations();
        if (isIgnored) {
            mTvBatteryOptBadge.setText("Korumalı ✅");
            mTvBatteryOptBadge.setTextColor(Color.parseColor("#10B981"));
            mBtnBatteryOpt.setText("Pil Optimizasyonundan Muaf Tutuldu (Aktif)");
            mBtnBatteryOpt.setEnabled(false);
            mBtnBatteryOpt.setBackgroundResource(R.drawable.bg_btn_secondary);
        } else {
            mTvBatteryOptBadge.setText("Kısıtlı ⚠️");
            mTvBatteryOptBadge.setTextColor(Color.parseColor("#F59E0B"));
            mBtnBatteryOpt.setText("Pil Tasarrufundan Muaf Tut (Önerilen)");
            mBtnBatteryOpt.setEnabled(true);
            mBtnBatteryOpt.setBackgroundResource(R.drawable.bg_btn_primary);
        }
    }

    private boolean isIgnoringBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
            if (pm != null) {
                return pm.isIgnoringBatteryOptimizations(getPackageName());
            }
        }
        return true;
    }

    private void requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                intent.setData(Uri.parse("package:" + getPackageName()));
                startActivity(intent);
            } catch (Exception e) {
                try {
                    Intent intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                    startActivity(intent);
                } catch (Exception ignored) {
                    Toast.makeText(this, "Pil ayarları açılamadı.", Toast.LENGTH_SHORT).show();
                }
            }
        }
    }

    // --- Text / Clipboard Sharing ---

    private void pasteFromClipboard() {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null && clipboard.hasPrimaryClip() && clipboard.getPrimaryClip().getItemCount() > 0) {
            CharSequence text = clipboard.getPrimaryClip().getItemAt(0).getText();
            if (text != null && text.length() > 0) {
                mEtShareText.setText(text);
                Toast.makeText(this, "Metin panodan yapıştırıldı.", Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, "Panoda metin bulunamadı.", Toast.LENGTH_SHORT).show();
            }
        } else {
            Toast.makeText(this, "Pano boş.", Toast.LENGTH_SHORT).show();
        }
    }

    private void sendTextToMac() {
        String text = mEtShareText.getText().toString();
        if (TextUtils.isEmpty(text.trim())) {
            Toast.makeText(this, "Lütfen gönderilecek metni yazın.", Toast.LENGTH_SHORT).show();
            return;
        }

        BluetoothService svc = BluetoothService.getInstance();
        if (svc != null && svc.getState() == Constants.STATE_CONNECTED) {
            boolean ok = svc.sendClipboardText(text);
            if (ok) {
                Toast.makeText(this, "Metin Mac'e iletildi!", Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, "Metin gönderilemedi.", Toast.LENGTH_SHORT).show();
            }
        } else {
            Toast.makeText(this, "Mac ile Bluetooth bağlantısı henüz kurulmadı.", Toast.LENGTH_LONG).show();
        }
    }

    // --- File Sharing ---

    private void openFilePicker() {
        BluetoothService svc = BluetoothService.getInstance();
        if (svc == null || svc.getState() != Constants.STATE_CONNECTED) {
            Toast.makeText(this, "Önce Mac'e Bluetooth ile bağlanmalısınız.", Toast.LENGTH_SHORT).show();
            return;
        }

        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.setType("*/*");
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        try {
            startActivityForResult(Intent.createChooser(intent, "Mac'e Gönderilecek Dosyayı Seçin"), REQ_PICK_FILE);
        } catch (Exception e) {
            Toast.makeText(this, "Dosya seçici açılamadı: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_PICK_FILE && resultCode == RESULT_OK && data != null) {
            Uri uri = data.getData();
            if (uri != null) {
                handleFileSend(uri);
            }
        }
    }

    private void handleFileSend(final Uri uri) {
        final String fileName = getFileNameFromUri(uri);
        final long fileSize = getFileSizeFromUri(uri);

        if (fileSize <= 0) {
            Toast.makeText(this, "Dosya boyutu okunamadı.", Toast.LENGTH_SHORT).show();
            return;
        }

        mTvFileStatus.setText("Gönderiliyor: " + fileName + " (%0)");
        mProgressBarFile.setVisibility(View.VISIBLE);
        mProgressBarFile.setProgress(0);
        mBtnChooseFile.setEnabled(false);

        BluetoothService svc = BluetoothService.getInstance();
        if (svc != null) {
            svc.sendFile(uri, fileName, fileSize, this, new BluetoothService.FileSendCallback() {
                @Override
                public void onProgress(final int percent) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            mProgressBarFile.setProgress(percent);
                            mTvFileStatus.setText("Gönderiliyor: " + fileName + " (%" + percent + ")");
                        }
                    });
                }

                @Override
                public void onComplete(final String name) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            mProgressBarFile.setVisibility(View.GONE);
                            mBtnChooseFile.setEnabled(true);
                            mTvFileStatus.setText("Başarıyla Mac'e aktarıldı: " + name);
                            Toast.makeText(MainActivity.this, "Dosya Mac'e gönderildi: " + name, Toast.LENGTH_LONG).show();
                        }
                    });
                }

                @Override
                public void onError(final String error) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            mProgressBarFile.setVisibility(View.GONE);
                            mBtnChooseFile.setEnabled(true);
                            mTvFileStatus.setText("Hata: " + error);
                            Toast.makeText(MainActivity.this, "Dosya aktarılamadı: " + error, Toast.LENGTH_LONG).show();
                        }
                    });
                }
            });
        }
    }

    private String getFileNameFromUri(Uri uri) {
        String result = null;
        if ("content".equals(uri.getScheme())) {
            try (Cursor cursor = getContentResolver().query(uri, null, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    int idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                    if (idx >= 0) {
                        result = cursor.getString(idx);
                    }
                }
            } catch (Exception ignored) {}
        }
        if (result == null) {
            result = uri.getLastPathSegment();
            if (result == null) result = "dosya_" + System.currentTimeMillis();
        }
        return result;
    }

    private long getFileSizeFromUri(Uri uri) {
        long size = 0;
        if ("content".equals(uri.getScheme())) {
            try (Cursor cursor = getContentResolver().query(uri, null, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    int idx = cursor.getColumnIndex(OpenableColumns.SIZE);
                    if (idx >= 0) {
                        size = cursor.getLong(idx);
                    }
                }
            } catch (Exception ignored) {}
        }
        if (size <= 0) {
            try {
                android.content.res.AssetFileDescriptor fd = getContentResolver().openAssetFileDescriptor(uri, "r");
                if (fd != null) {
                    size = fd.getLength();
                    fd.close();
                }
            } catch (Exception ignored) {}
        }
        return size;
    }

    // --- Logs Modal Dialog ---

    private void showLogsDialog() {
        List<String> logs = BluetoothService.getLogs();
        StringBuilder sb = new StringBuilder();
        if (logs.isEmpty()) {
            sb.append("Henüz kaydedilmiş log bulunmuyor.");
        } else {
            for (String line : logs) {
                sb.append(line).append("\n");
            }
        }

        final String logText = sb.toString();

        ScrollView scrollView = new ScrollView(this);
        TextView tv = new TextView(this);
        tv.setText(logText);
        tv.setTextColor(Color.parseColor("#34D399"));
        tv.setTextSize(11);
        tv.setTypeface(android.graphics.Typeface.MONOSPACE);
        tv.setPadding(30, 20, 30, 20);
        scrollView.addView(tv);

        new AlertDialog.Builder(this)
                .setTitle("Geliştirici Logları")
                .setView(scrollView)
                .setPositiveButton("Kapat", null)
                .setNeutralButton("Temizle", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        BluetoothService.clearLogs();
                        Toast.makeText(MainActivity.this, "Loglar temizlendi.", Toast.LENGTH_SHORT).show();
                    }
                })
                .setNegativeButton("Kopyala", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                        if (cm != null) {
                            cm.setPrimaryClip(ClipData.newPlainText("MacConnect Logs", logText));
                            Toast.makeText(MainActivity.this, "Loglar panoya kopyalandı.", Toast.LENGTH_SHORT).show();
                        }
                    }
                })
                .show();
    }

    // --- Lifecycle & Bluetooth Setup ---

    private void setupDeviceSpinner() {
        mSpinnerAdapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, mDeviceLabels);
        mSpinnerDevices.setAdapter(mSpinnerAdapter);
    }

    @Override
    protected void onResume() {
        super.onResume();
        IntentFilter filter = new IntentFilter();
        filter.addAction(Constants.ACTION_STATE_CHANGED);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(mReceiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            registerReceiver(mReceiver, filter);
        }

        updatePermissionStatusUI();
        updateBatteryOptimizationUI();
        updateBatteryDisplay();

        BluetoothService svc = BluetoothService.getInstance();
        if (svc != null) {
            updateConnectionUI(svc.getState(), svc.getConnectedDeviceName());
            if (hasBluetoothPermissions()) {
                svc.startServerListening();
            }
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        try {
            unregisterReceiver(mReceiver);
        } catch (Exception ignored) {}
    }

    private void setDotColor(int color) {
        GradientDrawable shape = new GradientDrawable();
        shape.setShape(GradientDrawable.OVAL);
        shape.setColor(color);
        mViewStatusDot.setBackground(shape);

        GradientDrawable headerShape = new GradientDrawable();
        headerShape.setShape(GradientDrawable.OVAL);
        headerShape.setColor(color);
        mViewHeaderDot.setBackground(headerShape);
    }

    private void updateConnectionUI(int state, String devName) {
        if (state == Constants.STATE_CONNECTED) {
            setDotColor(Color.parseColor("#10B981")); // Emerald Green
            mTvStatusTitle.setText("Bağlantı Aktif");
            mTvHeaderStatus.setText("Bağlı");
            mTvHeaderStatus.setTextColor(Color.parseColor("#10B981"));
            mTvStatusDetail.setText("💻 " + (devName != null ? devName : "Mac") + " bağlı. Bildirimler ve veriler gerçek zamanlı aktarılıyor.");
            mBtnConnect.setText("Bağlandı");
        } else if (state == Constants.STATE_CONNECTING) {
            setDotColor(Color.parseColor("#F59E0B")); // Amber
            mTvStatusTitle.setText("Bağlanıyor...");
            mTvHeaderStatus.setText("Bağlanıyor");
            mTvHeaderStatus.setTextColor(Color.parseColor("#F59E0B"));
            mTvStatusDetail.setText("Mac ile Bluetooth kanalı kuruluyor...");
            mBtnConnect.setText("Bağlanıyor...");
        } else {
            setDotColor(Color.parseColor("#EF4444")); // Rose Red
            mTvStatusTitle.setText("Bağlantı Bekleniyor");
            mTvHeaderStatus.setText("Bağlantı Yok");
            mTvHeaderStatus.setTextColor(Color.parseColor("#A1A1AA"));
            mTvStatusDetail.setText("Mac'ten Bluetooth bağlantısı bekleniyor (veya yukarıdan bağlanın).");
            mBtnConnect.setText("Mac'e Bağlan");
        }
    }

    private boolean isNotificationListenerEnabled() {
        String flat = Settings.Secure.getString(getContentResolver(), "enabled_notification_listeners");
        if (flat != null && !flat.isEmpty()) {
            String myPkg = getPackageName();
            String[] names = flat.split(":");
            for (String name : names) {
                ComponentName cn = ComponentName.unflattenFromString(name);
                if (cn != null && myPkg.equals(cn.getPackageName())) {
                    return true;
                }
            }
        }
        return false;
    }

    private void updatePermissionStatusUI() {
        boolean notifOk = isNotificationListenerEnabled();
        if (notifOk) {
            mTvNotifPermStatus.setText("Bildirim Erişimi: Açık ✅");
            mBtnGrantNotif.setVisibility(View.GONE);
        } else {
            mTvNotifPermStatus.setText("Bildirim Erişimi: Gerekli ⚠️");
            mBtnGrantNotif.setVisibility(View.VISIBLE);
        }

        boolean btOk = hasBluetoothPermissions();
        if (btOk) {
            mTvBtPermStatus.setText("Bluetooth İzni: Açık ✅");
            mBtnGrantBt.setVisibility(View.GONE);
        } else {
            mTvBtPermStatus.setText("Bluetooth İzni: Gerekli ⚠️");
            mBtnGrantBt.setVisibility(View.VISIBLE);
        }

        boolean callOk = hasCallPermissions();
        if (mTvCallPermStatus != null) {
            if (callOk) {
                mTvCallPermStatus.setText("Arama Yanıtlama: Açık ✅");
                if (mBtnGrantCall != null) mBtnGrantCall.setVisibility(View.GONE);
            } else {
                mTvCallPermStatus.setText("Arama Yanıtlama: Gerekli ⚠️");
                if (mBtnGrantCall != null) mBtnGrantCall.setVisibility(View.VISIBLE);
            }
        }
    }

    private boolean hasCallPermissions() {
        if (checkSelfPermission(Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            return false;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (checkSelfPermission(Manifest.permission.ANSWER_PHONE_CALLS) != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        if (checkSelfPermission(Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            return false;
        }
        return true;
    }

    private void requestCallPermissions() {
        List<String> perms = new ArrayList<>();
        perms.add(Manifest.permission.CALL_PHONE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            perms.add(Manifest.permission.ANSWER_PHONE_CALLS);
        }
        perms.add(Manifest.permission.READ_PHONE_STATE);
        perms.add(Manifest.permission.READ_CALL_LOG);
        perms.add(Manifest.permission.READ_CONTACTS);

        requestPermissions(perms.toArray(new String[0]), REQ_CALL_PERMS);
    }

    private boolean hasBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
                    checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED;
        }
        return true;
    }

    private void requestBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            requestPermissions(new String[]{
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.BLUETOOTH_ADVERTISE
            }, REQ_BT_PERMS);
        }
    }

    private void checkAndRequestPermissions() {
        updatePermissionStatusUI();
        if (!hasBluetoothPermissions()) {
            requestBluetoothPermissions();
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        updatePermissionStatusUI();
        refreshPairedDevices();
        BluetoothService svc = BluetoothService.getInstance();
        if (svc != null) {
            if (requestCode == REQ_BT_PERMS && hasBluetoothPermissions()) {
                svc.startServerListening();
            } else if (requestCode == REQ_CALL_PERMS) {
                svc.refreshTelephonyListener();
            }
        }
    }

    private void refreshPairedDevices() {
        mDeviceList.clear();
        mDeviceLabels.clear();

        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        if (adapter != null && adapter.isEnabled()) {
            try {
                Set<BluetoothDevice> paired = adapter.getBondedDevices();
                int macIndex = -1;
                int idx = 0;
                if (paired != null) {
                    for (BluetoothDevice dev : paired) {
                        mDeviceList.add(dev);
                        String name = dev.getName();
                        if (name == null || name.isEmpty()) name = "Bilinmeyen Cihaz";
                        mDeviceLabels.add(name + " (" + dev.getAddress() + ")");
                        if (name.toLowerCase(Locale.ROOT).contains("mac") || name.toLowerCase(Locale.ROOT).contains("apple")) {
                            macIndex = idx;
                        }
                        idx++;
                    }
                }
                mSpinnerAdapter.notifyDataSetChanged();
                if (macIndex >= 0) {
                    mSpinnerDevices.setSelection(macIndex);
                }
            } catch (SecurityException ignored) {}
        } else {
            mDeviceLabels.add("Bluetooth kapalı");
            mSpinnerAdapter.notifyDataSetChanged();
        }
    }

    private void startBluetoothService() {
        Intent intent = new Intent(this, BluetoothService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent);
        } else {
            startService(intent);
        }
    }
}
