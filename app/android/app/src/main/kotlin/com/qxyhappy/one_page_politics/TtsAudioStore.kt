package com.qxyhappy.one_page_politics

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * DeepSeek 合成音频的本地缓存与播放。
 *
 * 收到的 WAV 在后台线程解析 PCM，并用 MediaCodec 压制为 AAC-LC/M4A 后写入
 * 应用私有目录；编码器不可用或格式不支持时回退保存 WAV。播放始终读取本地
 * 文件，同一个稳定键不会重复下载。
 *
 * 平台通道只传输稳定键、WAV 字节与令牌；播放完成或出错时回传同一个令牌，
 * Dart 侧据此忽略过期回调。
 */
class TtsAudioStore(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "tts-audio-store")
    }
    private val cacheDir = File(appContext.filesDir, CACHE_DIR).apply { mkdirs() }

    private var player: MediaPlayer? = null
    private var token: String? = null
    @Volatile
    private var disposed = false
    @Volatile
    private var playbackGeneration = 0L

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("disposed", "音频存储已释放", null)
            return
        }
        when (call.method) {
            "has" -> result.success(cacheFile(call.argument<String>("key")) != null)
            "play" -> playCached(call, result)
            "storeAndPlay" -> storeAndPlay(call, result)
            "stop" -> {
                playbackGeneration++
                releasePlayer()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun playCached(call: MethodCall, result: MethodChannel.Result) {
        val newToken = call.argument<String>("token")
        val file = cacheFile(call.argument<String>("key"))
        if (file == null || newToken.isNullOrEmpty()) {
            result.error("missing_audio", "本地没有该音频", null)
            return
        }
        playFile(file, newToken, result)
    }

    private fun storeAndPlay(call: MethodCall, result: MethodChannel.Result) {
        val key = normalizedKey(call.argument<String>("key"))
        val bytes = call.argument<ByteArray>("bytes")
        val newToken = call.argument<String>("token")
        if (key == null || bytes == null || bytes.isEmpty() || newToken.isNullOrEmpty()) {
            result.error("invalid_arguments", "缺少音频数据、稳定键或令牌", null)
            return
        }

        val requestGeneration = playbackGeneration
        worker.execute {
            if (disposed || Thread.currentThread().isInterrupted) {
                postError(result, "disposed", "音频存储已释放")
                return@execute
            }
            val file = try {
                store(key, bytes)
            } catch (_: Exception) {
                null
            }
            mainHandler.post {
                if (disposed) {
                    result.error("disposed", "音频存储已释放", null)
                } else if (requestGeneration != playbackGeneration) {
                    // 压缩期间用户已暂停、切条或切换引擎：只保留文件，不再播放。
                    result.success(null)
                } else if (file == null) {
                    result.error("store_failed", "无法保存合成音频", null)
                } else {
                    playFile(file, newToken, result)
                }
            }
        }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post {
            if (!disposed) result.error(code, message, null)
        }
    }

    /**
     * 保存音频并返回可播放的文件。优先 AAC/M4A，失败时回退原始 WAV。
     * 同一键已有非空文件时直接复用。
     */
    private fun store(key: String, wavBytes: ByteArray): File? {
        cacheFile(key)?.let { return it }
        if (Thread.currentThread().isInterrupted || disposed) return null

        val wav = WavPcmParser.parse(wavBytes)
        if (wav != null) {
            val target = File(cacheDir, "$key.m4a")
            val temp = File(cacheDir, "$key.m4a.tmp")
            temp.delete()
            try {
                encodeAac(wav, temp)
                if (temp.length() > 0) {
                    if (target.exists()) target.delete()
                    if (temp.renameTo(target)) return target
                }
            } catch (_: Exception) {
                // 编码器不可用或格式异常时回退保存 WAV。
            } finally {
                temp.delete()
            }
        }

        if (Thread.currentThread().isInterrupted || disposed) return null
        val target = File(cacheDir, "$key.wav")
        val temp = File(cacheDir, "$key.wav.tmp")
        temp.delete()
        return try {
            temp.writeBytes(wavBytes)
            if (target.exists()) target.delete()
            if (temp.renameTo(target)) target else null
        } catch (_: Exception) {
            temp.delete()
            null
        }
    }

    private fun encodeAac(wav: WavPcm, target: File) {
        val mediaFormat = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC,
            wav.sampleRate,
            wav.channels,
        ).apply {
            setInteger(
                MediaFormat.KEY_AAC_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AACObjectLC,
            )
            setInteger(
                MediaFormat.KEY_BIT_RATE,
                if (wav.channels == 1) AAC_BITRATE_MONO else AAC_BITRATE_STEREO,
            )
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16 * 1024)
        }

        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var success = false
        try {
            codec.configure(
                mediaFormat,
                null,
                null,
                MediaCodec.CONFIGURE_FLAG_ENCODE,
            )
            codec.start()

            val frameBytes = wav.channels * 2
            if (frameBytes <= 0) throw IllegalStateException("无效的声道数")
            val totalBytes = wav.pcm.size - (wav.pcm.size % frameBytes)
            if (totalBytes <= 0) throw IllegalStateException("没有可编码的 PCM 数据")

            var framesQueued = 0L
            var inputDone = false
            var outputDone = false
            var trackIndex = -1
            val info = MediaCodec.BufferInfo()
            val deadline = System.currentTimeMillis() + ENCODE_TIMEOUT_MS

            while (!outputDone) {
                if (Thread.currentThread().isInterrupted || disposed) {
                    throw InterruptedException("音频存储已释放")
                }
                if (System.currentTimeMillis() > deadline) {
                    throw IllegalStateException("AAC 编码超时")
                }

                if (!inputDone) {
                    val inputIndex = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_US)
                    if (inputIndex >= 0) {
                        val buffer = codec.getInputBuffer(inputIndex)
                            ?: throw IllegalStateException("编码器未提供输入缓冲区")
                        buffer.clear()
                        val offsetBytes = (framesQueued * frameBytes).toInt()
                        if (offsetBytes >= totalBytes) {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                framesQueued * 1_000_000L / wav.sampleRate,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            var chunk = minOf(totalBytes - offsetBytes, buffer.capacity())
                            chunk -= chunk % frameBytes
                            if (chunk <= 0) {
                                throw IllegalStateException("编码器输入缓冲区过小")
                            }
                            buffer.put(wav.pcm, offsetBytes, chunk)
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                chunk,
                                framesQueued * 1_000_000L / wav.sampleRate,
                                0,
                            )
                            framesQueued += (chunk / frameBytes).toLong()
                        }
                    }
                }

                when (val outputIndex = codec.dequeueOutputBuffer(info, DEQUEUE_TIMEOUT_US)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (muxerStarted) throw IllegalStateException("编码格式重复变化")
                        val newMuxer = MediaMuxer(
                            target.absolutePath,
                            MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4,
                        )
                        val track = newMuxer.addTrack(codec.outputFormat)
                        newMuxer.start()
                        muxer = newMuxer
                        muxerStarted = true
                        trackIndex = track
                    }

                    MediaCodec.INFO_TRY_AGAIN_LATER -> Unit

                    else -> {
                        if (outputIndex >= 0) {
                            val buffer = codec.getOutputBuffer(outputIndex)
                                ?: throw IllegalStateException("编码器未提供输出缓冲区")
                            if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                                info.size = 0
                            }
                            if (info.size > 0) {
                                if (!muxerStarted) {
                                    throw IllegalStateException("编码器尚未输出格式")
                                }
                                buffer.position(info.offset)
                                buffer.limit(info.offset + info.size)
                                muxer?.writeSampleData(trackIndex, buffer, info)
                            }
                            codec.releaseOutputBuffer(outputIndex, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                outputDone = true
                            }
                        }
                    }
                }
            }

            if (!muxerStarted) throw IllegalStateException("编码器没有输出音频格式")
            muxer?.stop()
            success = true
        } finally {
            try {
                codec.stop()
            } catch (_: Exception) {
                // 编码器可能尚未启动。
            }
            codec.release()
            try {
                muxer?.stop()
            } catch (_: Exception) {
                // 已停止或未开始。
            }
            muxer?.release()
            if (!success) target.delete()
        }
    }

    private fun playFile(file: File, newToken: String, result: MethodChannel.Result) {
        releasePlayer()
        val mediaPlayer = MediaPlayer()
        player = mediaPlayer
        token = newToken
        try {
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            mediaPlayer.setDataSource(file.absolutePath)
            mediaPlayer.setOnPreparedListener { it.start() }
            mediaPlayer.setOnCompletionListener {
                notifyCompleted(newToken)
                releasePlayer()
            }
            mediaPlayer.setOnErrorListener { _, what, extra ->
                notifyError(newToken, "播放器错误（$what/$extra）")
                releasePlayer()
                true
            }
            mediaPlayer.prepareAsync()
            result.success(null)
        } catch (error: Exception) {
            notifyError(newToken, "无法播放音频：${error.message}")
            releasePlayer()
            result.error("playback_failed", "无法播放音频：${error.message}", null)
        }
    }

    private fun notifyCompleted(forToken: String) {
        if (token != forToken) return
        channel.invokeMethod("completed", forToken)
    }

    private fun notifyError(forToken: String, message: String) {
        if (token != forToken) return
        channel.invokeMethod("error", mapOf("token" to forToken, "message" to message))
    }

    private fun releasePlayer() {
        try {
            player?.release()
        } catch (_: Exception) {
            // 已释放或播放器处于非法状态时忽略。
        }
        player = null
        token = null
    }

    private fun cacheFile(rawKey: String?): File? {
        val key = normalizedKey(rawKey) ?: return null
        val aac = File(cacheDir, "$key.m4a")
        if (aac.isFile && aac.length() > 0) return aac
        val wav = File(cacheDir, "$key.wav")
        if (wav.isFile && wav.length() > 0) return wav
        return null
    }

    private fun normalizedKey(rawKey: String?): String? {
        if (rawKey == null || !KEY_PATTERN.matches(rawKey)) return null
        return rawKey
    }

    fun dispose() {
        disposed = true
        playbackGeneration++
        worker.shutdownNow()
        releasePlayer()
        channel.setMethodCallHandler(null)
    }

    private data class WavPcm(
        val sampleRate: Int,
        val channels: Int,
        val pcm: ByteArray,
    )

    private object WavPcmParser {
        fun parse(bytes: ByteArray): WavPcm? {
            if (bytes.size < 44) return null
            if (ascii(bytes, 0, 4) != "RIFF" || ascii(bytes, 8, 4) != "WAVE") {
                return null
            }

            var offset = 12
            var audioFormat = 0
            var channels = 0
            var sampleRate = 0
            var bitsPerSample = 0
            var dataOffset = -1
            var dataSize = 0L

            while (offset + 8 <= bytes.size) {
                val id = ascii(bytes, offset, 4)
                val size = readUInt32(bytes, offset + 4)
                val payload = offset + 8
                if (payload.toLong() + size > bytes.size.toLong()) break
                val chunkSize = size.toInt()
                when (id) {
                    "fmt " -> {
                        if (chunkSize < 16) return null
                        audioFormat = readUInt16(bytes, payload)
                        channels = readUInt16(bytes, payload + 2)
                        sampleRate = readUInt32(bytes, payload + 4).toInt()
                        bitsPerSample = readUInt16(bytes, payload + 14)
                        if (audioFormat == 0xFFFE && chunkSize >= 40) {
                            // WAVE_FORMAT_EXTENSIBLE：子格式 GUID 的前两字节即格式码。
                            audioFormat = readUInt16(bytes, payload + 24)
                        }
                    }

                    "data" -> {
                        dataOffset = payload
                        dataSize = size
                    }
                }
                offset = payload + chunkSize + (chunkSize and 1)
            }

            if (audioFormat != 1 || channels !in 1..2 || sampleRate <= 0 ||
                bitsPerSample != 16 || dataOffset < 0 || dataSize <= 0
            ) {
                return null
            }
            val available = bytes.size - dataOffset
            val length = minOf(dataSize, available.toLong()).toInt()
            if (length <= 0) return null
            return WavPcm(sampleRate, channels, bytes.copyOfRange(dataOffset, dataOffset + length))
        }

        private fun ascii(bytes: ByteArray, offset: Int, length: Int): String =
            String(bytes, offset, length, Charsets.US_ASCII)

        private fun readUInt16(bytes: ByteArray, offset: Int): Int =
            (bytes[offset].toInt() and 0xFF) or
                    ((bytes[offset + 1].toInt() and 0xFF) shl 8)

        private fun readUInt32(bytes: ByteArray, offset: Int): Long =
            (bytes[offset].toLong() and 0xFF) or
                    ((bytes[offset + 1].toLong() and 0xFF) shl 8) or
                    ((bytes[offset + 2].toLong() and 0xFF) shl 16) or
                    ((bytes[offset + 3].toLong() and 0xFF) shl 24)
    }

    companion object {
        private const val CHANNEL = "one_page_politics/tts_audio"
        private const val CACHE_DIR = "tts_cache"
        private const val AAC_BITRATE_MONO = 48_000
        private const val AAC_BITRATE_STEREO = 64_000
        private const val DEQUEUE_TIMEOUT_US = 10_000L
        private const val ENCODE_TIMEOUT_MS = 30_000L
        private val KEY_PATTERN = Regex("^[0-9a-f]{16}$")
    }
}
