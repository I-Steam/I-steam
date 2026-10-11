#include "NativeGuestMemory.h"
#include <algorithm>
#include <array>
#include <cstring>
#include <memory>
#include <mutex>
#include <new>
#include <unordered_map>
namespace { constexpr uint64_t pageSize = 4096; using Page = std::array<uint8_t, pageSize>; }
struct ISteamGuestMemory { explicit ISteamGuestMemory(uint64_t n): size(n) {} uint64_t size; std::unordered_map<uint64_t,std::unique_ptr<Page>> pages; mutable std::mutex mutex; };
extern "C" {
ISteamGuestMemory *isteam_guest_memory_create(uint64_t size) { try { return new ISteamGuestMemory(size); } catch (...) { return nullptr; } }
void isteam_guest_memory_destroy(ISteamGuestMemory *m) { delete m; }
uint64_t isteam_guest_memory_size(const ISteamGuestMemory *m) { return m ? m->size : 0; }
bool isteam_guest_memory_read(ISteamGuestMemory *m,uint64_t off,uint8_t *dst,size_t len) {
 if(!m||(len&&!dst)||off>m->size||len>m->size-off)return false;if(!len)return true;std::lock_guard<std::mutex> g(m->mutex);size_t done=0;
 while(done<len){uint64_t at=off+done,idx=at/pageSize;size_t in=at%pageSize,n=std::min(len-done,(size_t)pageSize-in);auto it=m->pages.find(idx);if(it==m->pages.end())std::memset(dst+done,0,n);else std::memcpy(dst+done,it->second->data()+in,n);done+=n;}return true;
}
bool isteam_guest_memory_write(ISteamGuestMemory *m,uint64_t off,const uint8_t *src,size_t len) {
 if(!m||(len&&!src)||off>m->size||len>m->size-off)return false;if(!len)return true;std::lock_guard<std::mutex> g(m->mutex);size_t done=0;
 while(done<len){uint64_t at=off+done,idx=at/pageSize;size_t in=at%pageSize,n=std::min(len-done,(size_t)pageSize-in);auto &p=m->pages[idx];if(!p)p.reset(new(std::nothrow) Page{});if(!p)return false;std::memcpy(p->data()+in,src+done,n);done+=n;}return true;
}
bool isteam_guest_memory_zero(ISteamGuestMemory *m,uint64_t off,uint64_t len) {
 if(!m||off>m->size||len>m->size-off)return false;if(!len)return true;std::lock_guard<std::mutex> g(m->mutex);uint64_t end=off+len;
 for(uint64_t at=off;at<end;){uint64_t idx=at/pageSize;size_t in=at%pageSize,n=(size_t)std::min(end-at,pageSize-in);auto it=m->pages.find(idx);if(it!=m->pages.end())std::memset(it->second->data()+in,0,n);at+=n;}return true;
}
void isteam_guest_memory_clear(ISteamGuestMemory *m){if(!m)return;std::lock_guard<std::mutex> g(m->mutex);m->pages.clear();}
size_t isteam_guest_memory_allocated_pages(ISteamGuestMemory *m){if(!m)return 0;std::lock_guard<std::mutex> g(m->mutex);return m->pages.size();}
}
