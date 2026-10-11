#ifndef NativeGuestMemory_h
#define NativeGuestMemory_h
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct ISteamGuestMemory ISteamGuestMemory;
ISteamGuestMemory *isteam_guest_memory_create(uint64_t size);
void isteam_guest_memory_destroy(ISTeamGuestMemory *memory);
uint64_t isteam_guest_memory_size(const ISteamGuestMemory *memory);
bool isteam_guest_memory_read(ISTeamGuestMemory *memory, uint64_t offset, uint8_t *destination, size_t length);
bool isteam_guest_memory_write(ISTeamGuestMemory *memory, uint64_t offset, const uint8_t *source, size_t length);
bool isteam_guest_memory_zero(ISTeamGuestMemory *memory, uint64_t offset, uint64_t length);
void isteam_guest_memory_clear(ISTeamGuestMemory *memory);
size_t isteam_guest_memory_allocated_pages(ISTeamGuestMemory *memory);
#ifdef __cplusplus
}
#endif
#endif
