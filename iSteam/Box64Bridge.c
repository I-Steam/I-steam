#include "Box64Bridge.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef int (*box64_main_fn)(int, char **);

static box64_main_fn resolveBox64Main(void) {
    void *handle = dlopen(NULL, RTLD_NOW | RTLD_GLOBAL);
    if (!handle) return NULL;

    box64_main_fn fn = (box64_main_fn)dlsym(handle, "box64_main");
    if (!fn) fn = (box64_main_fn)dlsym(handle, "box64_library_main");
    return fn;
}

bool box64IsAvailable(void) {
    return resolveBox64Main() != NULL;
}

int box64Run(const char *executable, const char *workingDirectory, int argc, const char *argv[]) {
    box64_main_fn fn = resolveBox64Main();
    if (!fn || !executable) return -1;

    if (workingDirectory && chdir(workingDirectory) != 0) return -2;

    int count = argc > 0 ? argc : 1;
    char **args = calloc((size_t)count + 1, sizeof(char *));
    if (!args) return -3;

    args[0] = strdup(executable);
    for (int i = 1; i < count; ++i) {
        args[i] = strdup(argv[i]);
    }

    int result = fn(count, args);

    for (int i = 0; i < count; ++i) free(args[i]);
    free(args);
    return result;
}
