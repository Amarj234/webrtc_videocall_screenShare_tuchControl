package com.example.webrtc_screen_share

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class RemoteControlService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d("REMOTE_TOUCH", "Accessibility service connected")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    fun performTouch(x: Float, y: Float) {
        val screenWidth = resources.displayMetrics.widthPixels.toFloat()
        val screenHeight = resources.displayMetrics.heightPixels.toFloat()

        val safeX = x.coerceIn(0f, screenWidth - 1)
        val safeY = y.coerceIn(0f, screenHeight - 1)

        Log.d("REMOTE_TOUCH", "Adjusted tap at: $safeX, $safeY")

        val path = Path().apply {
            moveTo(safeX, safeY)
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()

        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                super.onCompleted(gestureDescription)
                Log.d("REMOTE_TOUCH", "Touch performed at: $safeX, $safeY")
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                super.onCancelled(gestureDescription)
                Log.e("REMOTE_TOUCH", "Touch cancelled!")
            }
        }, null)
    }


    companion object {
        var instance: RemoteControlService? = null
    }
}
