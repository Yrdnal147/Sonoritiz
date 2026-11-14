package com.example.sonoritiz

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.example.sonoritiz/audio_output"
    private val EVENT_CHANNEL = "com.example.sonoritiz/audio_output_events"
    private var eventSink: EventChannel.EventSink? = null
    private var audioDeviceCallback: AudioDeviceCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openOutputSwitcher" -> {
                    try {
                        var opened = false
                        // 1. Android 11+ (API 30+) Native Media Output Switcher Dialog
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val intent = Intent("com.android.settings.panel.action.MEDIA_OUTPUT").apply {
                                putExtra("com.android.settings.panel.extra.PACKAGE_NAME", packageName)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                opened = true
                            }
                        }
                        // 2. Android 10 (API 29) Volume & Media Output Panel
                        if (!opened && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val intent = Intent(Settings.Panel.ACTION_VOLUME).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                opened = true
                            }
                        }
                        // 3. Fallback: Bluetooth Settings
                        if (!opened) {
                            val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            opened = true
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_SOUND_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.message, null)
                        }
                    }
                }
                "getCurrentDevice" -> {
                    result.success(getAudioDeviceInfo())
                }
                "setKeepScreenOn" -> {
                    try {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    setupAudioDeviceCallback()
                    events?.success(getAudioDeviceInfo())
                }

                override fun onCancel(arguments: Any?) {
                    teardownAudioDeviceCallback()
                    eventSink = null
                }
            }
        )
    }

    private fun getAudioDeviceInfo(): Map<String, Any?> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        var deviceName = "Haut-parleur du téléphone"
        var deviceType = "speaker"
        var isExternal = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (dev in devices) {
                val pName = dev.productName?.toString()?.trim()
                when (dev.type) {
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_BLE_HEADSET,
                    AudioDeviceInfo.TYPE_BLE_SPEAKER,
                    AudioDeviceInfo.TYPE_HEARING_AID -> {
                        deviceName = if (!pName.isNullOrEmpty()) pName else "Appareil Bluetooth"
                        deviceType = "bluetooth"
                        isExternal = true
                        break
                    }
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_LINE_ANALOG,
                    AudioDeviceInfo.TYPE_AUX_LINE -> {
                        deviceName = if (!pName.isNullOrEmpty()) pName else "Écouteurs filaires"
                        deviceType = "headphones"
                        isExternal = true
                    }
                    AudioDeviceInfo.TYPE_USB_DEVICE,
                    AudioDeviceInfo.TYPE_USB_HEADSET -> {
                        deviceName = if (!pName.isNullOrEmpty()) pName else "Sortie USB"
                        deviceType = "usb"
                        isExternal = true
                    }
                }
            }
        } else {
            @Suppress("DEPRECATION")
            if (audioManager.isBluetoothA2dpOn) {
                deviceName = "Appareil Bluetooth"
                deviceType = "bluetooth"
                isExternal = true
            } else if (@Suppress("DEPRECATION") audioManager.isWiredHeadsetOn) {
                deviceName = "Écouteurs filaires"
                deviceType = "headphones"
                isExternal = true
            }
        }

        return mapOf(
            "name" to deviceName,
            "type" to deviceType,
            "isExternal" to isExternal
        )
    }

    private fun setupAudioDeviceCallback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioDeviceCallback = object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
                    runOnUiThread {
                        eventSink?.success(getAudioDeviceInfo())
                    }
                }

                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                    runOnUiThread {
                        eventSink?.success(getAudioDeviceInfo())
                    }
                }
            }
            audioManager.registerAudioDeviceCallback(audioDeviceCallback, null)
        }
    }

    private fun teardownAudioDeviceCallback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && audioDeviceCallback != null) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.unregisterAudioDeviceCallback(audioDeviceCallback)
            audioDeviceCallback = null
        }
    }
}
