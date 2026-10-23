#ifndef iSteam_QEMUNativeBridge_h
#define iSteam_QEMUNativeBridge_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Loads an app-bundled, code-signed QEMU runtime and starts its in-process
/// system emulator. Returns false with a diagnostic if the runtime or required
/// QEMU lifecycle symbols are unavailable.
bool isteam_qemu_start(int argc, const char * _Nonnull const * _Nonnull argv,
                       const char * _Nonnull library_path,
                       char * _Nonnull error_buffer, int error_capacity);
void isteam_qemu_request_stop(void);
bool isteam_qemu_is_running(void);
const char * _Nonnull isteam_qemu_last_error(void);

#ifdef __cplusplus
}
#endif
#endif
