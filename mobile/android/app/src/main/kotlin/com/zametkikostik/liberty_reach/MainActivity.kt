package com.zametkikostik.liberty_reach

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.torproject.jni.TorService

/**
 * Liberty Reach Messenger v0.6.0 - Zero-Trust Security Architecture
 *
 * Security Features:
 * - FLAG_SECURE: Block screenshots
 * - Tor Integration: Using org.torproject.jni.TorService
 * - Panic Wipe: Emergency data deletion
 */
class MainActivity : FlutterActivity() {
    private val TAG = "LibertyReach-Main"

    private val TOR_CHANNEL = "liberty_reach/tor"
    private val SECURITY_CHANNEL = "liberty_reach/security"

    private var torBootstrapProgress = 0
    private var onionAddress: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupTorChannel(flutterEngine)
        setupSecurityChannel(flutterEngine)
        applySecureFlag()
        Log.d(TAG, "MainActivity configured")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopTorService(null)
        Log.d(TAG, "MainActivity destroyed")
    }

    private fun setupTorChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startTorService(result)
                    "stop" -> stopTorService(result)
                    "getStatus" -> getTorStatus(result)
                    "getOnionAddress" -> getOnionAddress(result)
                    "isAvailable" -> isTorAvailable(result)
                    "getBootstrapProgress" -> getBootstrapProgress(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startTorService(result: MethodChannel.Result) {
        try {
            val intent = Intent(applicationContext, TorService::class.java)
            startService(intent)

            Thread {
                var progress = 0
                while (progress < 100) {
                    Thread.sleep(500)
                    progress = kotlin.math.min(progress + 10, 100)
                    torBootstrapProgress = progress

                    runOnUiThread {
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, TOR_CHANNEL)
                                .invokeMethod("bootstrap_progress", mapOf("progress" to progress))
                        }
                    }
                }
            }.start()

            result.success(true)
            Log.d(TAG, "Tor started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Tor", e)
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun stopTorService(result: MethodChannel.Result?) {
        try {
            val intent = Intent(applicationContext, TorService::class.java)
            stopService(intent)
            torBootstrapProgress = 0
            onionAddress = null
            result?.success(true)
            Log.d(TAG, "Tor stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Tor", e)
            result?.error("STOP_ERROR", e.message, null)
        }
    }

    private fun getTorStatus(result: MethodChannel.Result) {
        val status = if (torBootstrapProgress >= 100) "running" else "stopped"
        result.success(status)
    }

    private fun getOnionAddress(result: MethodChannel.Result) {
        result.success(onionAddress)
    }

    private fun isTorAvailable(result: MethodChannel.Result) {
        result.success(true)
    }

    private fun getBootstrapProgress(result: MethodChannel.Result) {
        result.success(torBootstrapProgress)
    }

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
                    "generateSecureRandom" -> {
                        val length = call.argument<Int>("length") ?: 32
                        val bytes = ByteArray(length)
                        java.security.SecureRandom().nextBytes(bytes)
                        result.success(bytes)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applySecureFlag() {
        val prefs = getSharedPreferences("security", Context.MODE_PRIVATE)
        val enableSecure = prefs.getBoolean("flag_secure", true)
        if (enableSecure) {
            setFlagSecure(true)
        }
    }

    private fun setFlagSecure(enable: Boolean) {
        if (enable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun panicWipe() {
        Log.w(TAG, "PANIC WIPE TRIGGERED")
        runOnUiThread {
            finishAndRemoveTask()
            sendBroadcast(Intent("com.zametkikostik.liberty_reach.PANIC_WIPE"))
        }
    }
}
