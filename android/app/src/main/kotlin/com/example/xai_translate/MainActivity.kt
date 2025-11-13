package com.example.xai_translate

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val CHANNEL = "whisper_channel"
    private val scope = CoroutineScope(Dispatchers.Main)
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
}

