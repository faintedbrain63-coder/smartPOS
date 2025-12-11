package com.smartpos.smart_pos

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class ServerForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    
    companion object {
        private const val CHANNEL_ID = "smartpos_server_channel"
        private const val NOTIFICATION_ID = 1001
        private const val WAKELOCK_TAG = "SmartPOS::ServerWakeLock"
        
        var isRunning = false
            private set
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> startForegroundService()
            "STOP" -> stopForegroundService()
        }
        return START_STICKY
    }
    
    private fun startForegroundService() {
        isRunning = true
        
        // Acquire wake lock to prevent CPU from sleeping
        // Use timeout of 24 hours (will be renewed if still running)
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKELOCK_TAG
        ).apply {
            setReferenceCounted(false)
            acquire(24 * 60 * 60 * 1000L) // 24 hours timeout
        }
        
        println("✅ ServerForegroundService: Wake lock acquired")
        
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
    }
    
    private fun stopForegroundService() {
        isRunning = false
        wakeLock?.release()
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SmartPOS Server",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the POS server running in the background"
                setShowBadge(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SmartPOS Server Active")
            .setContentText("POS server is running and accepting connections")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        isRunning = false
        wakeLock?.release()
        super.onDestroy()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        // When app is swiped, stop the service because Dart engine is dead
        super.onTaskRemoved(rootIntent)
        stopForegroundService()
    }
}
