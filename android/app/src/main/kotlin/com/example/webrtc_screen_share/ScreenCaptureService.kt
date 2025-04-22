package com.example.webrtc_screen_share

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ScreenCaptureService : Service() {

    override fun onCreate() {
        super.onCreate()

        // Create notification channel for Android O and above
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "screen_capture_channel",
                "Screen Capture Service",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        // Set up a notification for the foreground service
        val notification: Notification = NotificationCompat.Builder(this, "screen_capture_channel")
            .setContentTitle("Screen Capture Service")
            .setContentText("Capturing screen...")
            .setSmallIcon(android.R.drawable.ic_notification_overlay)
            .build()

        // Start the service as a foreground service
        startForeground(1, notification)
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        // Add screen capture logic here (e.g., use MediaProjectionManager)

        // For now, return START_STICKY to keep the service running
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
