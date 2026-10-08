#ifndef JIT26Protocol_h
#define JIT26Protocol_h
#include <stdbool.h>
#include <stddef.h>
bool iSteamJITIsSupported(void);
void iSteamJITDetach(void);
void *iSteamJITPrepareRegion(void *address, size_t length);
#endif
