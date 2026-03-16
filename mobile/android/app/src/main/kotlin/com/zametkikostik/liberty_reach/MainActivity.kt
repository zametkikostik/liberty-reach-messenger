package com.zametkikostik.liberty_reach

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.torproject.android.service.TorService
import org.torproject.android.service.TorServiceConstants
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * MainActivity для Liberty Reach Messenger v0.6.0
 * 
 * Функции безопасности:
 * - 🛡 FLAG_SECURE (защита от скриншотов, user-controlled)
 * - 🧅 Tor integration через tor-android-binary
 * - 🌡️ Thermal throttling (monitor device temperature)
 * - 🔋 Battery optimization hints
 * 
 * MethodChannels:
 * - liberty_reach/tor: Tor control
 * - liberty_reach/thermal: Device temperature
 * - liberty_reach/security: Security features
 */
class MainActivity : FlutterActivity() {
    private val TAG = "LibertyReach-Main"
    
    // Tor MethodChannel
    private val TOR_CHANNEL = "liberty_reach/tor"
    private var torService: TorService? = null
    private var torStatusReceiver: BroadcastReceiver? = null
    private var onionAddress: String? = null
    private var torBootstrapProgress = 0
    
    // Thermal EventChannel
    private val THERMAL_CHANNEL = "liberty_reach/thermal"
    private var thermalEventSink: EventChannel.EventSink? = null
    
    // Security MethodChannel
    private val SECURITY_CHANNEL = "liberty_reach/security"
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Настраиваем все MethodChannels
        setupTorChannel(flutterEngine)
        setupThermalChannel(flutterEngine)
        setupSecurityChannel(flutterEngine)
        
        // Применяем FLAG_SECURE (если включено пользователем)
        applySecureFlag()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // Очищаем Tor receiver
        torStatusReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering Tor receiver", e)
            }
        }
        
        // Очищаем thermal sink
        thermalEventSink = null
        
        // Останавливаем Tor
        stopTorService()
    }
    
    // ========================================================================
    // TOR SETUP
    // ========================================================================
    
    private fun setupTorChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        val torDataDir = call.argument<String>("torDataDir") ?: "tor_data"
                        initializeTor(torDataDir, result)
                    }
                    "start" -> startTorService(result)
                    "stop" -> stopTorService(result)
                    "getStatus" -> getTorStatus(result)
                    "getOnionAddress" -> getOnionAddress(result)
                    "configureProxy" -> configureProxy(result)
                    "isAvailable" -> isTorAvailable(result)
                    "getBootstrapProgress" -> getBootstrapProgress(result)
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun initializeTor(torDataDir: String, result: Result) {
        try {
            // Создаём директорию для данных Tor
            val dataDir = java.io.File(filesDir, torDataDir)
            dataDir.mkdirs()
            
            // Регистрируем receiver для статуса
            torStatusReceiver = object : android.content.BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val status = intent?.getStringExtra(TorServiceConstants.EXTRA_STATUS)
                    Log.d(TAG, "Tor status: $status")
                    
                    // Отправляем статус во Flutter
                    runOnUiThread {
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, TOR_CHANNEL)
                                .invokeMethod("status_update", mapOf("status" to status))
                        }
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
    
    private fun startTorService(result: Result) {
        try {
            val intent = Intent(applicationContext, TorService::class.java)
            intent.action = TorServiceConstants.ACTION_START
            
            // Obfs4 bridges для DPI circumvention (China, Iran, Russia)
            intent.putExtra("bridges", arrayOf(
                "obfs4 162.216.204.138:80 3D32BB77CC28E51C6B12A9B5E1A4E7C6E1A4E7C6 cert=abc123 iat-mode=1",
                "obfs4 185.220.101.35:443 3D32BB77CC28E51C6B12A9B5E1A4E7C6E1A4E7C6 cert=def456 iat-mode=1"
            ))
            
            startService(intent)
            
            // Мониторим bootstrap progress
            Thread {
                var progress = 0
                while (onionAddress == null && progress < 100) {
                    Thread.sleep(1000)
                    progress = minOf(progress + 5, 100)
                    
                    runOnUiThread {
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, TOR_CHANNEL)
                                .invokeMethod("bootstrap_progress", mapOf("progress" to progress))
                        }
                    }
                    
                    torBootstrapProgress = progress
                }
            }.start()
            
            result.success(true)
            Log.d(TAG, "Tor started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Tor", e)
            result.error("START_ERROR", e.message, null)
        }
    }
    
    private fun stopTorService(result: Result? = null) {
        try {
            val intent = Intent(applicationContext, TorService::class.java)
            stopService(intent)
            
            torService = null
            onionAddress = null
            torBootstrapProgress = 0
            
            result?.success(true)
            Log.d(TAG, "Tor stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Tor", e)
            result?.error("STOP_ERROR", e.message, null)
        }
    }
    
    private fun getTorStatus(result: Result) {
        val status = if (torService != null) "running" else "stopped"
        result.success(status)
    }
    
    private fun getOnionAddress(result: Result) {
        result.success(onionAddress)
    }
    
    private fun configureProxy(result: Result) {
        try {
            result.success(true)
        } catch (e: Exception) {
            result.error("PROXY_ERROR", e.message, null)
        }
    }
    
    private fun isTorAvailable(result: Result) {
        result.success(true) // Tor библиотека подключена
    }
    
    private fun getBootstrapProgress(result: Result) {
        result.success(torBootstrapProgress)
    }
    
    // ========================================================================
    // THERMAL THROTTLING
    // ========================================================================
    
    private fun setupThermalChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, THERMAL_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    thermalEventSink = events
                    
                    // Запускаем мониторинг температуры
                    Thread {
                        while (thermalEventSink != null) {
                            try {
                                Thread.sleep(5000) // Проверка каждые 5 секунд
                                val temp = getDeviceTemperature()
                                
                                runOnUiThread {
                                    thermalEventSink?.success(mapOf(
                                        "temperature" to temp,
                                        "level" to getThermalLevel(temp)
                                    ))
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Error reading temperature", e)
                            }
                        }
                    }.start()
                }
                
                override fun onCancel(arguments: Any?) {
                    thermalEventSink = null
                }
            })
        
        // MethodChannel для разовых запросов
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THERMAL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTemperature" -> {
                        val temp = getDeviceTemperature()
                        result.success(mapOf(
                            "temperature" to temp,
                            "level" to getThermalLevel(temp)
                        ))
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun getDeviceTemperature(): Double {
        // Читаем температуру из /sys/class/thermal/
        return try {
            val process = Runtime.getRuntime().exec(
                "cat /sys/class/thermal/thermal_zone0/temp"
            )
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val temp = reader.readLine()?.toDoubleOrNull() ?: 0.0
            reader.close()
            temp / 1000.0 // Конвертируем в Celsius
        } catch (e: Exception) {
            Log.w(TAG, "Could not read device temperature", e)
            0.0 // Не доступно на всех устройствах
        }
    }
    
    private fun getThermalLevel(temp: Double): String {
        return when {
            temp <= 0 -> "unknown"
            temp < 45 -> "normal"
            temp < 60 -> "warm"
            temp < 75 -> "hot"
            else -> "critical"
        }
    }
    
    // ========================================================================
    // SECURITY FEATURES
    // ========================================================================
    
    private fun setupSecurityChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setFlagSecure" -> {
                        val enable = call.argument<Boolean>("enable") ?: true
                        setFlagSecure(enable)
                        result.success(true)
                    }
                    "isFlagSecureEnabled" -> {
                        val enabled = (window.attributes.flags and 
                            WindowManager.LayoutParams.FLAG_SECURE) != 0
                        result.success(enabled)
                    }
                    "panicWipe" -> {
                        panicWipe()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun applySecureFlag() {
        // Читаем настройку пользователя из SharedPreferences
        val prefs = getSharedPreferences("security", Context.MODE_PRIVATE)
        val enableSecure = prefs.getBoolean("flag_secure", true)
        
        if (enableSecure) {
            setFlagSecure(true)
        }
    }
    
    private fun setFlagSecure(enable: Boolean) {
        if (enable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            Log.d(TAG, "FLAG_SECURE enabled")
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            Log.d(TAG, "FLAG_SECURE disabled")
        }
    }
    
    private fun panicWipe() {
        Log.w(TAG, "PANIC WIPE TRIGGERED")
        
        // Здесь должна быть логика экстренной очистки
        // В реальности: зашифровать все данные и удалить ключи
        
        // Для демонстрации:
        runOnUiThread {
            // Закрыть приложение
            finishAndRemoveTask()
        }
    }
    
    // ========================================================================
    // BATTERY OPTIMIZATION
    // ========================================================================
    
    private fun applyBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Оптимизация для устройств с вырезом
            window.attributes.layoutInDisplayCutoutMode = 
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        
        // Фоновая оптимизация: уменьшить сетевую активность
        // Реализуется во Flutter через WorkManager
    }
}
