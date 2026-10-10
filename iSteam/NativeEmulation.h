#ifndef NativeEmulation_h
#define NativeEmulation_h
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Small hot-path primitives shared by the Swift runtime and native emulator modules. */
bool isteam_read_le32(const uint8_t *bytes, size_t length, size_t offset, uint32_t *outValue);
bool isteam_read_le64(const uint8_t *bytes, size_t length, size_t offset, uint64_t *outValue);
void isteam_write_le64(uint8_t bytes[8], uint64_t value);
#ifdef __cplusplus
}
#endif
#endif
