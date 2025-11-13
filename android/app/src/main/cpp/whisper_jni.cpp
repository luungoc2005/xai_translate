#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <cstdio>

extern "C" {
#include "whisper.h"
}

#define TAG "WhisperJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

// Simple WAV file reader
bool read_wav(const char *fname, std::vector<float> &pcmf32, unsigned int &sample_rate) {
    FILE *f = fopen(fname, "rb");
    if (f == NULL) {
        LOGE("Failed to open WAV file: %s", fname);
        return false;
    }

    // Read WAV header
    char header[44];
    if (fread(header, 1, 44, f) != 44) {
        LOGE("Failed to read WAV header");
        fclose(f);
        return false;
    }

    // Check for RIFF and WAVE
    if (memcmp(header, "RIFF", 4) != 0 || memcmp(header + 8, "WAVE", 4) != 0) {
        LOGE("Invalid WAV file format");
        fclose(f);
        return false;
    }

    // Get sample rate and channels
    sample_rate = *(unsigned int *)(header + 24);
    unsigned short channels = *(unsigned short *)(header + 22);
    unsigned short bits_per_sample = *(unsigned short *)(header + 34);

    LOGI("WAV: sample_rate=%d, channels=%d, bits=%d", sample_rate, channels, bits_per_sample);

    // Read audio data
    fseek(f, 0, SEEK_END);
    long file_size = ftell(f);
    long data_size = file_size - 44;
    fseek(f, 44, SEEK_SET);

    if (bits_per_sample == 16) {
        std::vector<short> pcm16;
        pcm16.resize(data_size / 2);
        fread(pcm16.data(), 1, data_size, f);
        
        // Convert to float and handle stereo->mono
        pcmf32.resize(pcm16.size() / channels);
        for (size_t i = 0; i < pcmf32.size(); i++) {
            float sum = 0.0f;
            for (int c = 0; c < channels; c++) {
                sum += pcm16[i * channels + c] / 32768.0f;
            }
            pcmf32[i] = sum / channels;
        }
    }

    fclose(f);
    LOGI("Read %zu samples from WAV file", pcmf32.size());
    return true;
}

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_example_xai_1translate_WhisperJNI_initContext(JNIEnv *env, jclass clazz, jstring model_path) {
    const char *path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model from: %s", path);
    
    struct whisper_context_params cparams = whisper_context_default_params();
    struct whisper_context *ctx = whisper_init_from_file_with_params(path, cparams);
    
    env->ReleaseStringUTFChars(model_path, path);
    
    if (ctx == NULL) {
        LOGE("Failed to initialize whisper context");
        return 0;
    }
    
    LOGI("Whisper context initialized successfully");
    return (jlong) ctx;
}

JNIEXPORT jstring JNICALL
Java_com_example_xai_1translate_WhisperJNI_transcribe(
    JNIEnv *env, jclass clazz, jlong context_ptr, jstring audio_path) {
    
    struct whisper_context *ctx = (struct whisper_context *) context_ptr;
    if (ctx == NULL) {
        LOGE("Invalid context");
        return env->NewStringUTF("");
    }
    
    const char *path = env->GetStringUTFChars(audio_path, nullptr);
    LOGI("Transcribing audio from: %s", path);
    
    // Read WAV file
    std::vector<float> pcmf32;
    unsigned int sample_rate = 0;
    
    if (!read_wav(path, pcmf32, sample_rate)) {
        env->ReleaseStringUTFChars(audio_path, path);
        return env->NewStringUTF("");
    }
    
    env->ReleaseStringUTFChars(audio_path, path);
    
    // Setup whisper parameters - optimized for speed
    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.print_realtime = false;
    wparams.print_progress = false;
    wparams.print_timestamps = false;
    wparams.print_special = false;
    wparams.translate = false;
    wparams.language = nullptr;  // Auto-detect language (supports Chinese, English, etc.)
    wparams.n_threads = 8;  // Increased from 4 to 8 for modern devices
    wparams.offset_ms = 0;
    wparams.no_context = true;
    wparams.single_segment = false;
    wparams.audio_ctx = 512;  // Reduced from default (1500) for speed
    wparams.suppress_blank = true;  // Skip silent segments
    wparams.suppress_nst = false;  // Keep non-speech tokens enabled
    
    // Run inference
    if (whisper_full(ctx, wparams, pcmf32.data(), pcmf32.size()) != 0) {
        LOGE("Failed to process audio");
        return env->NewStringUTF("");
    }
    
    // Get transcription
    const int n_segments = whisper_full_n_segments(ctx);
    std::string result;
    
    for (int i = 0; i < n_segments; i++) {
        const char *text = whisper_full_get_segment_text(ctx, i);
        result += text;
    }
    
    LOGI("Transcription: %s", result.c_str());
    return env->NewStringUTF(result.c_str());
}

JNIEXPORT void JNICALL
Java_com_example_xai_1translate_WhisperJNI_freeContext(JNIEnv *env, jclass clazz, jlong context_ptr) {
    struct whisper_context *ctx = (struct whisper_context *) context_ptr;
    if (ctx != NULL) {
        whisper_free(ctx);
        LOGI("Whisper context freed");
    }
}

JNIEXPORT jstring JNICALL
Java_com_example_xai_1translate_WhisperJNI_getVersion(JNIEnv *env, jclass clazz) {
    return env->NewStringUTF("whisper.cpp");
}

} // extern "C"
