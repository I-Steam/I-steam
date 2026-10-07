#ifndef Box64Bridge_h
#define Box64Bridge_h

#include <stdbool.h>

bool box64IsAvailable(void);
int box64Run(const char *executable, const char *workingDirectory, int argc, const char *argv[]);

#endif
