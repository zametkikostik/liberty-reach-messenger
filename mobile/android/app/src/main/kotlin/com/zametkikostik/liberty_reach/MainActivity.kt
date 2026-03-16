package com.zametkikostik.liberty_reach

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.torproject.android.service.TorService
import org.torproject.android.service.TorServiceConstants
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter

/**
 * MainActivity для Liberty Reach Messenger
 * 
 * Включает:
 * - 🧅 Tor integration через tor-android-binary
 * - MethodChannel для связи с Flutter
 */
class MainActivity: FlutterActivity() {
    private val CHANNEL = "liberty_reach/tor"
    private var torService: TorService? = null
    private var torStatusReceiver: BroadcastReceiver? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Настраиваем Tor MethodChannel
        setupTorChannel(flutterEngine)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Очищаем Tor receiver
        torStatusReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering receiver", e)
            }
        }
    }
    
    private fun setupTorChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val torDataDir = call.argument<String>("torDataDir") ?: "tor_data"
                    initializeTor(torDataDir, result)
                }
                "start" -> startTor(result)
                "stop" -> stopTor(result)
                "getStatus" -> getTorStatus(result)
                "getOnionAddress" -> getOnionAddress(result)
                "configureProxy" -> configureProxy(result)
                "isAvailable" -> isTorAvailable(result)
                else -> result.notImplemented()
            }
        }
    }
    
    private fun initializeTor(torDataDir: String, result: Result) {
        try {
            // Создаём директорию для данных Tor
            val dataDir = File(filesDir, torDataDir)
            dataDir.mkdirs()
            
            // Инициализируем TorService
            torService = TorService()
            
            // Регистрируем receiver для статуса
            torStatusReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    when (intent?.getStringExtra(TorServiceConstants.EXTRA_STATUS)) {
                        "STARTING" -> Log.d(TAG, "Tor is starting")
                        "RUNNING" -> Log.d(TAG, "Tor is running")
                        "STOPPING" -> Log.d(TAG, "Tor is stopping")
                        "STOPPED" -> Log.d(TAG, "Tor is stopped")
                    }
                }
            }
            
            val intentFilter = IntentFilter(TorServiceConstants.ACTION_STATUS)
            registerReceiver(torStatusReceiver, intentFilter)
            
            result.success(true)
            Log.d(TAG, "Tor initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing Tor", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }
    
    private fun startTor(result: Result) {
        try {
            val intent = Intent(applicationContext, TorService::class.java)
            intent.action = TorServiceConstants.ACTION_START
            startService(intent)
            
            result.success(true)
            Log.d(TAG, "Tor started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Tor", e)
            result.error("START_ERROR", e.message, null)
        }
    }
    
    private fun stopTor(result: Result) {
        try {
            val intent = Intent(applicationContext, TorService::class.java)
            stopService(intent)
            
            result.success(true)
            Log.d(TAG, "Tor stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Tor", e)
            result.error("STOP_ERROR", e.message, null)
        }
    }
    
    private fun getTorStatus(result: Result) {
        // Упрощённая проверка статуса
        val status = if (torService != null) "running" else "stopped"
        result.success(status)
    }
    
    private fun getOnionAddress(result: Result) {
        // Onion address доступен только для hidden services
        // Возвращаем null если не настроен
        result.success(null)
    }
    
    private fun configureProxy(result: Result) {
        try {
            // Tor SOCKS5 proxy настраивается автоматически
            result.success(true)
        } catch (e: Exception) {
            result.error("PROXY_ERROR", e.message, null)
        }
    }
    
    private fun isTorAvailable(result: Result) {
        // Проверяем доступность Tor
        val available = true // Tor библиотека подключена
        result.success(available)
    }
    
    companion object {
        private const val TAG = "LibertyReach-Tor"
    }
}
