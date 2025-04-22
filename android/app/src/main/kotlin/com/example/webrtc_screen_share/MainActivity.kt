package com.example.webrtc_screen_share

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SCREEN_CHANNEL = "com.example.webrtc_screen_share/screen"
    private val TOUCH_CHANNEL = "com.example.remote_control/touch"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Screen Sharing Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "startScreenService") {
                    val intent = Intent(this, ScreenCaptureService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // Remote Control Touch Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TOUCH_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendTouch") {
                    val x = call.argument<Float>("x") ?: 0f
                    val y = call.argument<Float>("y") ?: 0f
                    val service = RemoteControlService()
                    service.performTouch(x, y)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
