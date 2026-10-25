// Private CoreGraphics display mode API. Unlike the public API, it lists and switches to hidden modes.

#import <CoreGraphics/CoreGraphics.h>

typedef struct {
    uint32_t mode, flags, width, height, depth, dc2[42];
    uint16_t dc3, freq;
    uint32_t dc4[4];
    float density;
} CGSDisplayModeDescription;

void CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);
void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *count);
void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int index, CGSDisplayModeDescription *mode, int length);
CGError CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
