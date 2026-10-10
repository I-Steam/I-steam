#include "NativeEmulation.h"
#include <limits.h>

bool isteam_read_le32(const uint8_t *bytes, size_t length, size_t offset, uint32_t *outValue) {
    if (!bytes || !outValue || offset > length || length - offset < 4) return false;
    const uint8_t *p = bytes + offset;
    *outValue = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
    return true;
}

bool isteam_read_le64(const uint8_t *bytes, size_t length, size_t offset, uint64_t *outValue) {
    if (!bytes || !outValue || offset > length || length - offset < 8) return false;
    const uint8_t *p = bytes + offset;
    uint64_t value = 0;
    for (unsigned i = 0; i < 8; ++i) value |= ((uint64_t)p[i]) << (i * 8);
    *outValue = value;
    return true;
}

void isteam_write_le64(uint8_t bytes[8], uint64_t value) {
    if (!bytes) return;
    for (unsigned i = 0; i < 8; ++i) bytes[i] = (uint8_t)(value >> (i * 8));
}
