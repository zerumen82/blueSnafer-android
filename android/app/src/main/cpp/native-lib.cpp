#include <jni.h>
#include <string>
#include <android/log.h>
#include <sys/socket.h>
#include <unistd.h>
#include <errno.h>

#define LOG_TAG "NativeBluetoothBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jstring JNICALL
Java_com_bluesnafer_1pro_NativeBluetoothBridge_helloFromJNI(
        JNIEnv* env,
        jobject /* this */) {
    std::string hello = "Hello from Native C++";
    return env->NewStringUTF(hello.c_str());
}


// Estructuras HCI necesarias (definidas manualmente para compatibilidad NDK)
struct sockaddr_hci {
    sa_family_t hciv_family;
    unsigned short hciv_dev;
    unsigned short hciv_channel;
};

#define HCI_DEV_NONE 0xffff
#define HCI_CHANNEL_RAW 0
#define HCI_CHANNEL_USER 1
#define HCI_CHANNEL_MONITOR 2

extern "C" JNIEXPORT jint JNICALL
Java_com_bluesnafer_1pro_NativeBluetoothBridge_openRawHciSocket(
        JNIEnv* env,
        jobject /* this */,
        jint devId) {
    
    // AF_BLUETOOTH = 31, SOCK_RAW = 3, BTPROTO_HCI = 1
    int fd = socket(31, 3, 1);
    if (fd < 0) {
        LOGE("Failed to open raw socket: %s (Check Root/Permissions)", strerror(errno));
        return -errno;
    }

    struct sockaddr_hci addr;
    memset(&addr, 0, sizeof(addr));
    addr.hciv_family = 31; // AF_BLUETOOTH
    addr.hciv_dev = (unsigned short) devId;
    addr.hciv_channel = HCI_CHANNEL_RAW;

    if (bind(fd, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
        LOGE("Failed to bind raw socket to hci%d: %s", devId, strerror(errno));
        close(fd);
        return -errno;
    }

    LOGI("Raw socket bound to hci%d successfully: fd=%d", devId, fd);
    return fd;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_bluesnafer_1pro_NativeBluetoothBridge_sendRawHciPacket(
        JNIEnv* env,
        jobject /* this */,
        jint fd,
        jbyteArray data) {
    
    jsize len = env->GetArrayLength(data);
    jbyte* buf = env->GetByteArrayElements(data, NULL);

    ssize_t sent = write(fd, buf, len);
    
    env->ReleaseByteArrayElements(data, buf, 0);

    if (sent < 0) {
        LOGE("Failed to write to raw socket: %s", strerror(errno));
        return -errno;
    }
    return (jint) sent;
}

extern "C" JNIEXPORT void JNICALL
Java_com_bluesnafer_1pro_NativeBluetoothBridge_closeSocket(
        JNIEnv* env,
        jobject /* this */,
        jint fd) {
    if (fd > 0) {
        close(fd);
    }
}
