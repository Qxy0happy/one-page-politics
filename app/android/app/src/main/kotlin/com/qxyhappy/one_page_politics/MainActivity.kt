package com.qxyhappy.one_page_politics

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ttsAudioStore: TtsAudioStore? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ttsAudioStore = TtsAudioStore(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onDestroy() {
        ttsAudioStore?.dispose()
        ttsAudioStore = null
        super.onDestroy()
    }
}
