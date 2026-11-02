#pragma once

#include <algorithm>
#include <cstddef>
#include <vector>

using jobject = void*;
using jfloat = float;
using jint = int;
using jsize = int;
using jboolean = unsigned char;

struct FakeJFloatArray {
    std::vector<jfloat> values;
};
using jfloatArray = FakeJFloatArray*;

struct JNIEnv {
    jfloatArray NewFloatArray(jsize length) {
        if (length < 0) return nullptr;
        return new FakeJFloatArray{std::vector<jfloat>(static_cast<std::size_t>(length))};
    }

    void SetFloatArrayRegion(jfloatArray array, jsize start, jsize length, const jfloat* source) {
        if (array == nullptr || source == nullptr || start < 0 || length < 0) return;
        const auto first = static_cast<std::size_t>(start);
        const auto count = static_cast<std::size_t>(length);
        if (first + count > array->values.size()) return;
        std::copy(source, source + count, array->values.begin() + start);
    }
};

#define JNIEXPORT
#define JNICALL
#define JNI_TRUE static_cast<jboolean>(1)
#define JNI_FALSE static_cast<jboolean>(0)
