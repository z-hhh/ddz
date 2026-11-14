package cn.offline.doudizhu

import android.app.Activity
import android.media.AudioAttributes
import android.media.SoundPool
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** 原生短音效与离线系统报牌；不可用时静默，绝不拦截游戏操作。 */
class GameAudio(private val activity: Activity, messenger: BinaryMessenger) {
    private val prefs = activity.getSharedPreferences("game_audio", 0)
    private var effectsOn = prefs.getBoolean("effectsOn", true)
    private var speechOn = prefs.getBoolean("speechOn", false)
    private var muted = prefs.getBoolean("muted", false)
    private var active = true
    private var disposed = false
    private val pool = SoundPool.Builder().setMaxStreams(4).setAudioAttributes(
        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).build()
    private val sounds = mutableMapOf<String, Int>()
    private val ready = mutableSetOf<Int>()
    private val streams = ArrayDeque<Int>()
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val speechResults = mutableMapOf<String, MethodChannel.Result>()
    private var utteranceSequence = 0
    private fun completeSpeech(id: String?) {
        activity.runOnUiThread { speechResults.remove(id)?.success(null) }
    }
    private fun stopSpeech() {
        tts?.stop()
        speechResults.values.toList().forEach { it.success(null) }
        speechResults.clear()
    }
    private val channel = MethodChannel(messenger, "cn.offline.doudizhu/audio")
    init {
        pool.setOnLoadCompleteListener { _, id, status -> if (status == 0) ready.add(id) }
        try {
            tts = TextToSpeech(activity) { status ->
                if (!disposed && status == TextToSpeech.SUCCESS) {
                    // 只选择已安装、无需联网的中文语音；缺失时不请求下载。
                    val voice = tts?.voices?.firstOrNull {
                        it.locale.language == "zh" && !it.isNetworkConnectionRequired &&
                            !it.features.orEmpty().contains("notInstalled")
                    }
                    ttsReady = voice != null && tts?.setVoice(voice) == TextToSpeech.SUCCESS
                    tts?.setSpeechRate(1.05f)
                    tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(id: String?) {}
                        override fun onDone(id: String?) { completeSpeech(id) }
                        @Deprecated("Android legacy callback")
                        override fun onError(id: String?) { completeSpeech(id) }
                        override fun onStop(id: String?, interrupted: Boolean) { completeSpeech(id) }
                    })
                }
            }
        } catch (_: Exception) { ttsReady = false }
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "initialize" -> {
                        for (name in call.argument<List<String>>("effects").orEmpty()) {
                            if (!name.matches(Regex("[a-z]+")) || sounds.containsKey(name)) continue
                            try {
                                val file = File(activity.cacheDir, "ddz-$name.wav")
                                activity.assets.open("flutter_assets/assets/audio/$name.wav").use { input ->
                                    file.outputStream().use { input.copyTo(it) }
                                }
                                sounds[name] = pool.load(file.absolutePath, 1)
                            } catch (_: Exception) { /* 缺失素材静默 */ }
                        }
                        // New tempo preference starts existing installations on Fast once.
                        result.success(mapOf("effectsOn" to effectsOn, "speechOn" to speechOn, "muted" to muted, "cardSize" to prefs.getInt("cardSize", 1), "pace" to prefs.getInt("paceV2", 0), "difficulty" to prefs.getString("difficulty", "普通")))
                    }
                    "settings" -> {
                        effectsOn = call.argument<Boolean>("effectsOn") ?: true
                        speechOn = call.argument<Boolean>("speechOn") ?: false
                        muted = call.argument<Boolean>("muted") ?: false
                        prefs.edit().putBoolean("effectsOn", effectsOn).putBoolean("speechOn", speechOn)
                            .putBoolean("muted", muted).putInt("cardSize", call.argument<Int>("cardSize") ?: 1)
                            .putInt("paceV2", call.argument<Int>("pace") ?: 0)
                            .putString("difficulty", call.argument<String>("difficulty") ?: "普通").apply()
                        if (muted || !effectsOn) stopEffects()
                        if (muted || !speechOn) stopSpeech()
                        result.success(null)
                    }
                    "play" -> {
                        val id = sounds[call.argument<String>("effect")]
                        if (active && effectsOn && !muted && id != null && ready.contains(id)) {
                            val volume = (call.argument<Number>("volume")?.toFloat() ?: .4f).coerceIn(0f, 1f)
                            if (streams.size >= 8) pool.stop(streams.removeFirst())
                            streams.addLast(pool.play(id, volume, volume, 1, 0, 1f))
                        }
                        result.success(null)
                    }
                    "speak" -> {
                        stopSpeech()
                        if (active && speechOn && !muted && ttsReady) {
                            val id = "ddz-${++utteranceSequence}"
                            speechResults[id] = result
                            val status = tts?.speak(call.argument<String>("text").orEmpty().take(60), TextToSpeech.QUEUE_FLUSH,
                                android.os.Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, .65f) }, id)
                            if (status != TextToSpeech.SUCCESS) completeSpeech(id)
                        } else result.success(null)
                    }
                    "stopEffects" -> { stopEffects(); result.success(null) }
                    "stopSpeech" -> { stopSpeech(); result.success(null) }
                    "suspend" -> { suspendAudio(); result.success(null) }
                    "resume" -> { active = true; result.success(null) }
                    "dispose" -> { dispose(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.success(null) }
        }
    }
    private fun stopEffects() { streams.forEach { pool.stop(it) }; streams.clear() }
    fun suspendAudio() { active = false; stopEffects(); stopSpeech() }
    fun resumeAudio() { active = true }
    fun dispose() {
        if (disposed) return
        disposed = true; suspendAudio(); pool.release(); tts?.shutdown(); channel.setMethodCallHandler(null)
    }
}
