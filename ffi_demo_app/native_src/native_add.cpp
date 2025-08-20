#include <stdint.h> // For int32_t

// プラットフォームに応じたエクスポートマクロを定義
#if defined(_WIN32) || defined(_WIN64)
    #define API extern "C" __declspec(dllexport)
#elif defined(__APPLE__) || defined(__linux__)
    #define API extern "C" __attribute__((visibility("default")))
#else
    #define API extern "C"
#endif

API int32_t native_add(int32_t a, int32_t b) {
    return a + b;
}