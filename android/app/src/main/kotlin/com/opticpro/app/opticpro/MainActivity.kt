package com.opticpro.app.opticpro

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler {
    private val HARDWARE_CHANNEL = "com.opticpro/hardware"
    private var methodChannel: MethodChannel? = null

    // Audio recording monitor state
    private var audioRecord: AudioRecord? = null
    private val isAudioMeasuring = AtomicBoolean(false)
    private var audioThread: Thread? = null
    @Volatile private var latestRmsDb: Float = -60.0f
    @Volatile private var latestPeakDb: Float = -60.0f
    @Volatile private var latestIsClipping: Boolean = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HARDWARE_CHANNEL)
        methodChannel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCameraCapabilities" -> {
                try {
                    val caps = getCameraCapabilities()
                    result.success(caps)
                } catch (e: Exception) {
                    result.error("CAMERA_CAPS_ERROR", e.localizedMessage, e.stackTraceToString())
                }
            }
            "getSystemTelemetry" -> {
                try {
                    val telemetry = getSystemTelemetry()
                    result.success(telemetry)
                } catch (e: Exception) {
                    result.error("TELEMETRY_ERROR", e.localizedMessage, e.stackTraceToString())
                }
            }
            "startAudioMeter" -> {
                try {
                    val success = startAudioMeasurement()
                    result.success(success)
                } catch (e: Exception) {
                    result.error("AUDIO_METER_ERROR", e.localizedMessage, e.stackTraceToString())
                }
            }
            "stopAudioMeter" -> {
                stopAudioMeasurement()
                result.success(true)
            }
            "getAudioLevel" -> {
                val levels = mapOf(
                    "rmsDb" to latestRmsDb,
                    "peakDb" to latestPeakDb,
                    "isClipping" to latestIsClipping
                )
                result.success(levels)
            }
            else -> result.notImplemented()
        }
    }

    private fun getCameraCapabilities(): List<Map<String, Any?>> {
        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return emptyList()
        val cameraList = mutableListOf<Map<String, Any?>>()

        for (cameraId in cameraManager.cameraIdList) {
            try {
                val chars = cameraManager.getCameraCharacteristics(cameraId)
                val facingInt = chars.get(CameraCharacteristics.LENS_FACING) ?: CameraCharacteristics.LENS_FACING_BACK
                val facingStr = when (facingInt) {
                    CameraCharacteristics.LENS_FACING_FRONT -> "FRONT"
                    CameraCharacteristics.LENS_FACING_EXTERNAL -> "EXTERNAL"
                    else -> "BACK"
                }

                val hwLevelInt = chars.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)
                    ?: CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY
                val hwLevelStr = when (hwLevelInt) {
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY -> "LEGACY"
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED -> "LIMITED"
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> "FULL"
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> "LEVEL_3"
                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_EXTERNAL -> "EXTERNAL"
                    else -> "UNKNOWN"
                }

                // Capabilities array
                val availableCaps = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES) ?: intArrayOf()
                val hasManualSensor = availableCaps.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR)
                val hasManualPostProcessing = availableCaps.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_POST_PROCESSING)
                val hasRaw = availableCaps.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_RAW)

                var hasTenBitHdr = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    hasTenBitHdr = availableCaps.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_DYNAMIC_RANGE_TEN_BIT)
                }

                // Focal lengths and apertures
                val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.toList() ?: emptyList<Float>()
                val apertures = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)?.toList() ?: emptyList<Float>()
                val minFocusDistance = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
                val canManualFocus = minFocusDistance > 0.0f

                // ISO and Exposure Time Ranges
                val isoRange = chars.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
                val isoMin = isoRange?.lower ?: 100
                val isoMax = isoRange?.upper ?: 800

                val exposureTimeRange = chars.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
                val exposureMinNs = exposureTimeRange?.lower ?: 100000L // 0.1ms
                val exposureMaxNs = exposureTimeRange?.upper ?: 1000000000L // 1s

                // Exposure compensation
                val expRange = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
                val expMin = expRange?.lower ?: -4
                val expMax = expRange?.upper ?: 4
                val expStepRational = chars.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
                val expStep = expStepRational?.toFloat() ?: 0.5f

                // Stabilization
                val opticalStabModes = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION) ?: intArrayOf()
                val hasOis = opticalStabModes.contains(CameraCharacteristics.LENS_OPTICAL_STABILIZATION_MODE_ON)

                val videoStabModes = chars.get(CameraCharacteristics.CONTROL_AVAILABLE_VIDEO_STABILIZATION_MODES) ?: intArrayOf()
                val hasEis = videoStabModes.contains(CameraCharacteristics.CONTROL_VIDEO_STABILIZATION_MODE_ON)

                // Stream configuration
                val streamMap = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                val videoResolutions = mutableListOf<Map<String, Any>>()
                val rawFormats = mutableListOf<String>()

                if (streamMap != null) {
                    val formats = streamMap.outputFormats
                    for (fmt in formats) {
                        when (fmt) {
                            ImageFormat.RAW_SENSOR -> rawFormats.add("RAW_SENSOR (DNG)")
                            ImageFormat.RAW10 -> rawFormats.add("RAW10")
                            ImageFormat.RAW12 -> rawFormats.add("RAW12")
                        }
                    }

                    // Query video recording resolutions supported
                    val sizes = streamMap.getOutputSizes(MediaRecorder::class.java)
                        ?: streamMap.getOutputSizes(android.graphics.SurfaceTexture::class.java)
                        ?: emptyArray()

                    for (size in sizes) {
                        // Filter standard creator resolutions
                        val width = size.width
                        val height = size.height
                        // Estimate max FPS for this size from min frame duration
                        val minDuration = streamMap.getOutputMinFrameDuration(MediaRecorder::class.java, size)
                        val maxFps = if (minDuration > 0) (1_000_000_000.0 / minDuration).toInt().coerceAtMost(60) else 30

                        videoResolutions.add(mapOf(
                            "width" to width,
                            "height" to height,
                            "maxFps" to maxFps
                        ))
                    }
                }

                // Physical cameras on multi-camera systems (Android 9+)
                val physicalCameraIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    chars.physicalCameraIds.toList()
                } else {
                    emptyList()
                }

                // Plain language capability explanations
                val rawStillSupported = hasRaw && rawFormats.isNotEmpty()
                val rawVideoSupported = false // Consumer Android MediaRecorder/Camera2 does not expose raw uncompressed video stream recording
                val rawVideoExplanation = "Standard Android camera pipelines output compressed H.264/HEVC or YUV frames. Direct continuous RAW video stream dumping is not supported by this device's camera driver."

                val logSupported = hasTenBitHdr
                val logExplanation = if (hasTenBitHdr) {
                    "10-bit HDR / HLG dynamic range profile is exposed on this lens."
                } else {
                    "Hardware does not expose 10-bit HDR / Log color space profiles. An accurate flat/neutral profile and real-time Rec.709 monitoring LUT are available."
                }

                cameraList.add(mapOf(
                    "cameraId" to cameraId,
                    "facing" to facingStr,
                    "hardwareLevel" to hwLevelStr,
                    "focalLengths" to focalLengths,
                    "apertures" to apertures,
                    "minFocusDistance" to minFocusDistance,
                    "canManualFocus" to canManualFocus,
                    "hasManualSensor" to hasManualSensor,
                    "hasManualPostProcessing" to hasManualPostProcessing,
                    "isoMin" to isoMin,
                    "isoMax" to isoMax,
                    "exposureMinNs" to exposureMinNs,
                    "exposureMaxNs" to exposureMaxNs,
                    "expMin" to expMin,
                    "expMax" to expMax,
                    "expStep" to expStep,
                    "hasOis" to hasOis,
                    "hasEis" to hasEis,
                    "supportsRawStill" to rawStillSupported,
                    "rawFormats" to rawFormats,
                    "supportsRawVideo" to rawVideoSupported,
                    "rawVideoExplanation" to rawVideoExplanation,
                    "supportsTenBitHdr" to hasTenBitHdr,
                    "supportsLogProfile" to logSupported,
                    "logExplanation" to logExplanation,
                    "videoResolutions" to videoResolutions,
                    "physicalCameraIds" to physicalCameraIds
                ))
            } catch (e: Exception) {
                // Ignore inaccessible camera and continue
            }
        }
        return cameraList
    }

    private fun getSystemTelemetry(): Map<String, Any?> {
        val dataDir = Environment.getDataDirectory()
        val stat = StatFs(dataDir.path)
        val freeBytes = stat.availableBlocksLong * stat.blockSizeLong
        val totalBytes = stat.blockCountLong * stat.blockSizeLong

        // Battery
        val ifilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus = registerReceiver(null, ifilter)
        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else 100
        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        val rawTemp = batteryStatus?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
        val batteryTempC = rawTemp / 10.0f

        // Thermal status
        var thermalStatus = "NORMAL"
        var thermalInt = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager != null) {
                thermalInt = powerManager.currentThermalStatus
                thermalStatus = when (thermalInt) {
                    PowerManager.THERMAL_STATUS_NONE -> "NORMAL"
                    PowerManager.THERMAL_STATUS_LIGHT -> "LIGHT"
                    PowerManager.THERMAL_STATUS_MODERATE -> "MODERATE"
                    PowerManager.THERMAL_STATUS_SEVERE -> "SEVERE"
                    PowerManager.THERMAL_STATUS_CRITICAL -> "CRITICAL"
                    PowerManager.THERMAL_STATUS_EMERGENCY -> "EMERGENCY"
                    PowerManager.THERMAL_STATUS_SHUTDOWN -> "SHUTDOWN"
                    else -> "NORMAL"
                }
            }
        }

        // Audio Inputs
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val audioDevices = mutableListOf<Map<String, Any>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && audioManager != null) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
            for (dev in devices) {
                val isExternal = when (dev.type) {
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_USB_DEVICE,
                    AudioDeviceInfo.TYPE_USB_HEADSET,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_BLE_HEADSET -> true
                    else -> false
                }
                val typeName = when (dev.type) {
                    AudioDeviceInfo.TYPE_BUILTIN_MIC -> "Built-in Microphone"
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired External Mic"
                    AudioDeviceInfo.TYPE_USB_DEVICE,
                    AudioDeviceInfo.TYPE_USB_HEADSET -> "USB Audio Interface / Mic"
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_BLE_HEADSET -> "Wireless / Bluetooth Mic"
                    else -> "Audio Input"
                }
                audioDevices.add(mapOf(
                    "id" to dev.id,
                    "name" to (dev.productName?.toString() ?: typeName),
                    "typeName" to typeName,
                    "isExternal" to isExternal
                ))
            }
        }

        return mapOf(
            "freeStorageBytes" to freeBytes,
            "totalStorageBytes" to totalBytes,
            "batteryPct" to batteryPct,
            "isCharging" to isCharging,
            "batteryTempC" to batteryTempC,
            "thermalStatus" to thermalStatus,
            "thermalInt" to thermalInt,
            "audioDevices" to audioDevices
        )
    }

    private fun startAudioMeasurement(): Boolean {
        if (isAudioMeasuring.get()) return true
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return false
        }

        try {
            val sampleRate = 44100
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val bufferSize = max(
                AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat),
                2048
            )

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                audioRecord?.release()
                audioRecord = null
                return false
            }

            audioRecord?.startRecording()
            isAudioMeasuring.set(true)

            audioThread = Thread {
                val buffer = ShortArray(1024)
                while (isAudioMeasuring.get()) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (read > 0) {
                        var sumSquare = 0.0
                        var peak = 0
                        for (i in 0 until read) {
                            val sample = buffer[i].toInt()
                            val abs = kotlin.math.abs(sample)
                            if (abs > peak) peak = abs
                            sumSquare += (sample * sample).toDouble()
                        }
                        val rms = sqrt(sumSquare / read)
                        val rmsDb = if (rms > 0) (20 * log10(rms / 32768.0)).toFloat().coerceIn(-60.0f, 0.0f) else -60.0f
                        val peakDb = if (peak > 0) (20 * log10(peak / 32768.0)).toFloat().coerceIn(-60.0f, 0.0f) else -60.0f

                        latestRmsDb = rmsDb
                        latestPeakDb = peakDb
                        latestIsClipping = peakDb >= -0.8f
                    }
                    try {
                        Thread.sleep(40) // ~25 FPS audio level refresh
                    } catch (e: InterruptedException) {
                        break
                    }
                }
            }
            audioThread?.start()
            return true
        } catch (e: Exception) {
            audioRecord?.release()
            audioRecord = null
            isAudioMeasuring.set(false)
            return false
        }
    }

    private fun stopAudioMeasurement() {
        isAudioMeasuring.set(false)
        try {
            audioThread?.interrupt()
            audioThread = null
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            // Ignore cleanup errors
        }
    }

    override fun onDestroy() {
        stopAudioMeasurement()
        super.onDestroy()
    }
}
