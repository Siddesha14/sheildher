package com.example.shieldher

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.KeyEvent
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.shieldher/power_button"
    private var pressCount = 0
    private var lastPressTime: Long = 0

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastPressTime > 3000) {
                pressCount = 1
            } else {
                pressCount++
            }
            lastPressTime = currentTime

            if (pressCount >= 3) {
                pressCount = 0
                // Trigger SOS in Flutter
                flutterEngine?.dartExecutor?.binaryMessenger?.let {
                    MethodChannel(it, CHANNEL).invokeMethod("triggerSOS", null)
                }
            }
        }
    }

    private val VOLUME_CHANNEL = "com.example.shieldher/hardware_buttons"
    private val volumeHandler = Handler(Looper.getMainLooper())
    private val fakeCallRunnable = Runnable {
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, VOLUME_CHANNEL).invokeMethod("triggerFakeCall", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(screenReceiver, filter)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            if (event?.repeatCount == 0) {
                volumeHandler.postDelayed(fakeCallRunnable, 2000)
            }
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            volumeHandler.removeCallbacks(fakeCallRunnable)
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    override fun onDestroy() {
        unregisterReceiver(screenReceiver)
        super.onDestroy()
    }
}
