package com.example.xai_translate

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.content.Intent
import android.os.Bundle
import android.os.Build
import android.util.Log
import java.util.ArrayList

class MainActivity : FlutterActivity() {
    private val CHANNEL = "whisper_channel"
    private val SPEECH_CHANNEL = "com.example.xai_translate/speech"
    private val scope = CoroutineScope(Dispatchers.Main)
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    
    private var speechRecognizer: SpeechRecognizer? = null
    private var speechMethodChannel: MethodChannel? = null
    private var shouldListen = false
    private var lastIntent: Intent? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        speechMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
        speechMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    val locales = call.argument<List<String>>("locales")
                    if (locales != null) {
                        startListening(locales, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "locales list is required", null)
                    }
                }
                "stopListening" -> {
                    stopListening()
                    result.success(null)
                }
                "cancel" -> {
                    cancelListening()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initContext" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath != null) {
                        scope.launch {
                            try {
                                val contextPtr = withContext(Dispatchers.IO) {
                                    WhisperJNI.initContext(modelPath)
                                }
                                result.success(contextPtr)
                            } catch (e: Exception) {
                                result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "modelPath is required", null)
                    }
                }
                "transcribe" -> {
                    val contextPtr = call.argument<Long>("contextPtr")
                    val audioPath = call.argument<String>("audioPath")
                    if (contextPtr != null && audioPath != null) {
                        scope.launch {
                            try {
                                val text = withContext(Dispatchers.IO) {
                                    WhisperJNI.transcribe(contextPtr, audioPath)
                                }
                                result.success(text)
                            } catch (e: Exception) {
                                result.error("TRANSCRIBE_ERROR", "Failed to transcribe: ${e.message}", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "contextPtr and audioPath are required", null)
                    }
                }
                "freeContext" -> {
                    val contextPtr = call.argument<Long>("contextPtr")
                    if (contextPtr != null) {
                        scope.launch {
                            try {
                                withContext(Dispatchers.IO) {
                                    WhisperJNI.freeContext(contextPtr)
                                }
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("FREE_ERROR", "Failed to free context: ${e.message}", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "contextPtr is required", null)
                    }
                }
                "getVersion" -> {
                    try {
                        val version = WhisperJNI.getVersion()
                        result.success(version)
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", "Failed to get version: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startListening(locales: List<String>, result: MethodChannel.Result) {
        runOnUiThread {
            try {
                shouldListen = true
                if (speechRecognizer == null) {
                    createSpeechRecognizer()
                }

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
                intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)

                // Increase silence timeouts to prevent early cutoff
                intent.putExtra("android.speech.extras.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS", 5000L)
                intent.putExtra("android.speech.extras.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS", 5000L)
                
                if (locales.isNotEmpty()) {
                    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, locales[0])
                    Log.d("Speech", "Starting listening with primary locale: ${locales[0]}")
                }

                if (Build.VERSION.SDK_INT >= 33 && locales.size > 1) {
                    val arrayList = ArrayList(locales)
                    intent.putStringArrayListExtra("android.speech.extra.LANGUAGE_DETECTION_ALLOWED_LANGUAGES", arrayList)
                    intent.putExtra("android.speech.extra.ENABLE_LANGUAGE_DETECTION", true)
                }

                lastIntent = intent
                speechRecognizer?.startListening(intent)
                result.success(null)
            } catch (e: Exception) {
                result.error("START_ERROR", "Failed to start listening: ${e.message}", null)
            }
        }
    }

    private fun createSpeechRecognizer() {
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {
                speechMethodChannel?.invokeMethod("onSoundLevelChanged", rmsdB)
            }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {
                speechMethodChannel?.invokeMethod("onError", error.toString())
                if (shouldListen) {
                    // Handle permanent errors
                    if (error == 9) { // ERROR_INSUFFICIENT_PERMISSIONS
                        shouldListen = false
                        return
                    }

                    // Add delay before restarting to prevent tight loops and server disconnects
                    // Error 7 (NO_MATCH) is common, wait a bit
                    // Error 11 (SERVER_DISCONNECTED) needs longer backoff
                    val delay = when (error) {
                        7 -> 300L  // ERROR_NO_MATCH
                        11 -> 1000L // ERROR_SERVER_DISCONNECTED
                        else -> 500L
                    }

                    handler.postDelayed({
                        if (shouldListen) {
                            restartListening()
                        }
                    }, delay)
                }
            }
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (matches != null && matches.isNotEmpty()) {
                    val text = matches[0]
                    if (!text.isNullOrEmpty()) {
                        speechMethodChannel?.invokeMethod("onResult", mapOf("text" to text, "final" to true))
                    }
                }
                if (shouldListen) {
                    handler.post {
                        try {
                            speechRecognizer?.startListening(lastIntent)
                        } catch (e: Exception) {
                            Log.e("Speech", "Start listening failed in onResults", e)
                            restartListening()
                        }
                    }
                }
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (matches != null && matches.isNotEmpty()) {
                    val text = matches[0]
                    if (!text.isNullOrEmpty()) {
                        speechMethodChannel?.invokeMethod("onResult", mapOf("text" to text, "final" to false))
                    }
                }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
    }

    private fun restartListening() {
        if (!shouldListen) return
        
        try {
            // Recreate recognizer to ensure clean state
            speechRecognizer?.destroy()
            speechRecognizer = null
            createSpeechRecognizer()
            speechRecognizer?.startListening(lastIntent)
        } catch (e: Exception) {
            Log.e("Speech", "Restart failed", e)
            // Retry after delay
            handler.postDelayed({
                if (shouldListen) {
                    restartListening()
                }
            }, 1000)
        }
    }


    private fun stopListening() {
        runOnUiThread {
            shouldListen = false
            speechRecognizer?.stopListening()
        }
    }

    private fun cancelListening() {
        runOnUiThread {
            shouldListen = false
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
    }
}

