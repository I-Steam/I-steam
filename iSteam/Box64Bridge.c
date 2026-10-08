#include "Box64Bridge.h"
#include <dlfcn.h>
#include <unistd.h>
#include <errno.h>

typedef int (*box64_main_fn)(int, char **);

static box64_main_fn resolveBox64Main(void) {
    void *handle = dlopen(NULL, RTLD_NOW | RTLD_GLOBAL);
    if (!handle) return NULL;
    box64_main_fn fn = (box64_main_fn)dlsym(handle, "box64_library_main");
    if (!fn) fn = (box64_main_fn)dlsym(handle, "box64_main");
    return fn;
}

bool box64IsAvailable(void) { return resolveBox64Main() != NULL; }

int box64Run(const char *executable, const char *workingDirectory, int argc, const char *argv[]) {
    (void)executable;
    if (!workingDirectory || chdir(workingDirectory) != 0) return errno ? -errno : -1;
    box64_main_fn fn = resolveBox64Main();
    if (!fn) return -2;
    return fn(argc, (char **)argv);
}
