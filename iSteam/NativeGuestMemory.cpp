#include "NativeGuestMemory.h"
#include <algorithm>
#include <array>
#include <cstring>
#include <memory>
#include <mutex>
#include <new>
#include <unordered_map>

namespace {
constexpr uint64_t kPageSize = 4096;
using Page = std::array<uint8_t, kPageSize>;
}
struct ISteamGuestMemory {
    explicit ISteamGuestMemory(uint64_t requestedSize) : size(requestedSize) {}
    uint64_t size;
    std::unordered_map<uint64_t, std::unique_ptr<Page>> pages;
    mutable std::mutex mutex;
};
extern "C" {
ISTeamGuestMemory *isteam_guest_memory_create(uint64_t size) {
    try { return new ISteamGuestMemory(size); } catch (...) { return nullptr; }
}
void isteam_guest_memory_destroy(ISTeamGuestMemory *memory) { delete memory; }
uint64_t isteam_guest_memory_size(const ISTeamGuestMemory *memory) { return memory ? memory->size : 0; }
bool isteam_guest_memory_read(ISTeamGuestMemory *m, uint64_t offset, uint8_t *dst, size_t length) {
    if (!m || (length && !dst) || offset > m->size || length > m->size - offset) return false;
    if (!length) return true;
    std::lock_guard<std::mutex> guard(m->mutex);
    size_t done = 0;
    while (done < length) {
        const uint64_t at = offset + done, pageIndex = at / kPageSize;
        const size_t inPage = static_cast<size_t>(at % kPageSize);
        const size_t count = std::min(length - done, static_cast<size_t>(kPageSize) - inPage);
        auto it = m->pages.find(pageIndex);
        if (it == m->pages.end()) std::memset(dst + done, 0, count);
        else std::memcpy(dst + done, it->second->data() + inPage, count);
        done += count;
    }
    return true;
}
bool isteam_guest_memory_write(ISTeamGuestMemory *m, uint64_t offset, const uint8_t *src, size_t length) {
    if (!m || (length && !src) || offset > m->size || length > m->size - offset) return false;
    if (!length) return true;
    std::lock_guard<std::mutex> guard(m->mutex);
    size_t done = 0;
    while (done < length) {
        const uint64_t at = offset + done, pageIndex = at / kPageSize;
        const size_t inPage = static_cast<size_t>(at % kPageSize);
        const size_t count = std::min(length - done, static_cast<size_t>(kPageSize) - inPage);
        auto &slot = m->pages[pageIndex];
        if (!slot) slot.reset(new (std::nothrow) Page{});
        if (!slot) return false;
        std::memcpy(slot->data() + inPage, src + done, count);
        done += count;
    }
    return true;
}
bool isteam_guest_memory_zero(ISTeamGuestMemory *m, uint64_t offset, uint64_t length) {
    if (!m || offset > m->size || length > m->size - offset) return false;
    if (!length) return true;
    std::lock_guard<std::mutex> guard(m->mutex);
    const uint64_t end = offset + length;
    for (uint64_t at = offset; at < end;) {
        const uint64_t pageIndex = at / kPageSize;
        const size_t inPage = static_cast<size_t>(at % kPageSize);
        const size_t count = static_cast<size_t>(std::min(end - at, kPageSize - inPage));
        auto it = m->pages.find(pageIndex);
        if (it != m->pages.end()) std::memset(it->second->data() + inPage, 0, count);
        at += count;
    }
    return true;
}
void isteam_guest_memory_clear(ISTeamGuestMemory *m) {
    if (!m) return;
    std::lock_guard<std::mutex> guard(m->mutex);
    m->pages.clear();
}
size_t isteam_guest_memory_allocated_pages(ISTeamGuestMemory *m) {
    if (!m) return 0;
    std::lock_guard<std::mutex> guard(m->mutex);
    return m->pages.size();
}
}
