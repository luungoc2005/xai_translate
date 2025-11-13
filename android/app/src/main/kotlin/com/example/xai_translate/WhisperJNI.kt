package com.example.xai_translate

object WhisperJNI {
    init {
        System.loadLibrary("whisper_flutter")
    }
    
    external fun initContext(modelPath: String): Long
    external fun transcribe(contextPtr: Long, audioPath: String): String
    external fun freeContext(contextPtr: Long)
    external fun getVersion(): String
}
