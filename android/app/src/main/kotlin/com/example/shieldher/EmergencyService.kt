package com.example.shieldher

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import android.net.Uri

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.sqrt

class EmergencyService : Service(), SensorEventListener {
    private val CHANNEL_ID = "EmergencyServiceChannel"
    private val NOTIFICATION_ID = 101
    private val POWER_CHANNEL = "com.example.shieldher/power_button"
    
    private var pressCount = 0
    private var lastPressTime: Long = 0

    // Shake detection
    private var sensorManager: SensorManager? = null
    private var acceleration = 0f
    private var currentAcceleration = 0f
    private var lastAcceleration = 0f
    private val SHAKE_THRESHOLD = 70f // Increased from 45f to ensure only vigorous shaking triggers it
    private var lastTriggerTime: Long = 0
    private val TRIGGER_COOLDOWN = 30000 // 30 seconds cooldown

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
                triggerEmergencyActions()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "TRIGGER_SOS") {
            triggerEmergencyActions()
        }
        return START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = createNotification()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(screenReceiver, filter)

        // Initialize Shake Detection
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorManager?.registerListener(
            this,
            sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER),
            SensorManager.SENSOR_DELAY_NORMAL
        )
        acceleration = 10f
        currentAcceleration = SensorManager.GRAVITY_EARTH
        lastAcceleration = SensorManager.GRAVITY_EARTH
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        lastAcceleration = currentAcceleration
        currentAcceleration = sqrt(x * x + y * y + z * z)
        val delta = currentAcceleration - lastAcceleration
        acceleration = acceleration * 0.9f + delta

        if (acceleration > SHAKE_THRESHOLD) {
            triggerEmergencyActions()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun triggerEmergencyActions() {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastTriggerTime < TRIGGER_COOLDOWN) {
            Log.d("EmergencyService", "SOS Trigger ignored (cooldown active)")
            return
        }
        lastTriggerTime = currentTime
        
        Log.d("EmergencyService", "SOS Triggered from Background!")
        
        // 1. Get contacts from SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val contactsJson = prefs.getString("flutter.emergency_contacts", null)
        
        if (contactsJson != null) {
            try {
                val contacts = JSONArray(contactsJson)
                val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    getSystemService(SmsManager::class.java)
                } else {
                    SmsManager.getDefault()
                }

                for (i in 0 until contacts.length()) {
                    val contact = contacts.getJSONObject(i)
                    val phone = contact.getString("phone")
                    
                    // 2. Send SMS
                    smsManager.sendTextMessage(phone, null, "EMERGENCY! I need help. My location tracking is active. Check ShieldHer app.", null, null)
                }

                // 3. Call first contact
                if (contacts.length() > 0) {
                    val firstPhone = contacts.getJSONObject(0).getString("phone")
                    val callIntent = Intent(Intent.ACTION_CALL).apply {
                        data = Uri.parse("tel:$firstPhone")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(callIntent)
                }
            } catch (e: Exception) {
                Log.e("EmergencyService", "Error triggering SOS: ${e.message}")
            }
        }

        // 4. Try to wake up the app for Map/Guidance
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("trigger_sos_ui", true)
        }
        startActivity(launchIntent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "ShieldHer Active Protection",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ShieldHer is Protecting You")
            .setContentText("Power button monitoring active")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(pendingIntent)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        unregisterReceiver(screenReceiver)
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }
}
