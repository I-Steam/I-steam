#include "QEMUNativeBridge.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void (*qemu_init_fn)(int, char **);
typedef int (*qemu_main_loop_fn)(void);
typedef void (*qemu_cleanup_fn)(void);
typedef void (*qemu_shutdown_request_fn)(void);

static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static void *g_library = NULL;
static pthread_t g_thread;
static bool g_thread_created = false;
static bool g_running = false;
static char g_error[512] = {0};
static int g_argc = 0;
static char **g_argv = NULL;
static qemu_init_fn g_qemu_init = NULL;
static qemu_main_loop_fn g_qemu_main_loop = NULL;
static qemu_cleanup_fn g_qemu_cleanup = NULL;
static qemu_shutdown_request_fn g_qemu_shutdown = NULL;

static void set_error(const char *message) {
    pthread_mutex_lock(&g_lock);
    snprintf(g_error, sizeof(g_error), "%s", message ? message : "Unknown QEMU error");
    pthread_mutex_unlock(&g_lock);
}

static void release_arguments(void) {
    if (!g_argv) return;
    for (int i = 0; i < g_argc; ++i) free(g_argv[i]);
    free(g_argv);
    g_argv = NULL;
    g_argc = 0;
}

static void *qemu_thread_main(void *unused) {
    (void)unused;
    g_qemu_init(g_argc, g_argv);
    pthread_mutex_lock(&g_lock);
    g_running = true;
    pthread_mutex_unlock(&g_lock);

    int loop_result = g_qemu_main_loop();
    if (loop_result != 0) {
        char message[128];
        snprintf(message, sizeof(message), "QEMU main loop exited with status %d", loop_result);
        set_error(message);
    }

    if (g_qemu_cleanup) g_qemu_cleanup();
    pthread_mutex_lock(&g_lock);
    g_running = false;
    g_thread_created = false;
    release_arguments();
    pthread_mutex_unlock(&g_lock);
    return NULL;
}

bool isteam_qemu_start(int argc, const char * const *argv,
                       const char *library_path, char *error_buffer, int error_capacity) {
    if (argc < 1 || !argv || !library_path || !library_path[0]) {
        if (error_buffer && error_capacity > 0) snprintf(error_buffer, error_capacity, "Invalid QEMU launch arguments");
        return false;
    }

    pthread_mutex_lock(&g_lock);
    if (g_thread_created || g_running) {
        pthread_mutex_unlock(&g_lock);
        if (error_buffer && error_capacity > 0) snprintf(error_buffer, error_capacity, "A QEMU session is already active");
        return false;
    }
    g_error[0] = '\0';
    pthread_mutex_unlock(&g_lock);

    void *library = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        const char *reason = dlerror();
        if (error_buffer && error_capacity > 0) snprintf(error_buffer, error_capacity, "Could not load bundled QEMU: %s", reason ? reason : "unknown loader error");
        return false;
    }

    qemu_init_fn init_fn = (qemu_init_fn)dlsym(library, "qemu_init");
    qemu_main_loop_fn loop_fn = (qemu_main_loop_fn)dlsym(library, "qemu_main_loop");
    qemu_cleanup_fn cleanup_fn = (qemu_cleanup_fn)dlsym(library, "qemu_cleanup");
    qemu_shutdown_request_fn shutdown_fn = (qemu_shutdown_request_fn)dlsym(library, "qemu_system_shutdown_request");
    if (!init_fn || !loop_fn || !cleanup_fn || !shutdown_fn) {
        dlclose(library);
        if (error_buffer && error_capacity > 0) snprintf(error_buffer, error_capacity, "QEMU library lacks required exported lifecycle symbols (qemu_init, qemu_main_loop, qemu_cleanup, qemu_system_shutdown_request)");
        return false;
    }

    char **copied_argv = calloc((size_t)argc + 1, sizeof(char *));
    if (!copied_argv) {
        dlclose(library);
        if (error_buffer && error_capacity > 0) snprintf(error_buffer, error_capacity, "Out of memory preparing QEMU arguments");
        return false;
    }
    for (int i = 0; i < argc; ++i) {
        copied_argv[i] = strdup(argv[i] ? argv[i] : "");
        if (!copied_argv[i]) {
            for (int j = 0; j < i; ++j) free(copied_argv[j]);
            free(copied_argv);
            dlclose(library);
            if (error_buffer && error_capacity > 0) snprintf(error_buffer, error_capacity, "Out of memory copying QEMU arguments");
            return false;
        }
    }

    pthread_mutex_lock(&g_lock);
    g_library = library;
    g_qemu_init = init_fn;
    g_qemu_main_loop = loop_fn;
    g_qemu_cleanup = cleanup_fn;
    g_qemu_shutdown = shutdown_fn;
    g_argc = argc;
    g_argv = copied_argv;
    g_thread_created = true;
    int result = pthread_create(&g_thread, NULL, qemu_thread_main, NULL);
    if (result != 0) {
        g_thread_created = false;
        g_library = NULL;
        g_qemu_init = NULL;
        g_qemu_main_loop = NULL;
        g_qemu_cleanup = NULL;
        g_qemu_shutdown = NULL;
        g_argc = 0;
        g_argv = NULL;
        pthread_mutex_unlock(&g_lock);
        for (int i = 0; i < argc; ++i) free(copied_argv[i]);
        free(copied_argv);
        dlclose(library);
        if (error_buffer && error_capacity > 0) snprintf(error_buffer, error_capacity, "Could not create QEMU worker thread");
        return false;
    }
    pthread_detach(g_thread);
    pthread_mutex_unlock(&g_lock);
    return true;
}

void isteam_qemu_request_stop(void) {
    pthread_mutex_lock(&g_lock);
    bool active = g_thread_created || g_running;
    qemu_shutdown_request_fn shutdown_fn = g_qemu_shutdown;
    pthread_mutex_unlock(&g_lock);
    if (active && shutdown_fn) shutdown_fn();
}

bool isteam_qemu_is_running(void) {
    pthread_mutex_lock(&g_lock);
    bool value = g_running;
    pthread_mutex_unlock(&g_lock);
    return value;
}

const char *isteam_qemu_last_error(void) { return g_error; }
