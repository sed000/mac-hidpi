// Switches an external display to a HiDPI mode, including modes macOS hides from System Settings.
//
//   set-hidpi -l                  list external displays: id vendor product native-size
//   set-hidpi [-d ID] [WxH]       switch (defaults: first external display, its native size)

#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    uint32_t mode, flags, width, height, depth, dc2[42];
    uint16_t dc3, freq;
    uint32_t dc4[4];
    float density;
} CGSDisplayModeDescription;

extern void CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);
extern void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *count);
extern void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int index, CGSDisplayModeDescription *mode, int length);
extern CGError CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);

static int native_size(CGDirectDisplayID id, uint32_t *width, uint32_t *height) {
    const void *keys[] = {kCGDisplayShowDuplicateLowResolutionModes};
    const void *values[] = {kCFBooleanTrue};
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFArrayRef modes = CGDisplayCopyAllDisplayModes(id, options);
    CFRelease(options);

    int found = 0;
    for (CFIndex i = 0; modes && i < CFArrayGetCount(modes) && !found; i++) {
        CGDisplayModeRef mode = (CGDisplayModeRef)CFArrayGetValueAtIndex(modes, i);
        if (CGDisplayModeGetIOFlags(mode) & kDisplayModeNativeFlag) {
            *width = (uint32_t)CGDisplayModeGetPixelWidth(mode);
            *height = (uint32_t)CGDisplayModeGetPixelHeight(mode);
            found = 1;
        }
    }
    if (modes) CFRelease(modes);
    return found;
}

int main(int argc, char **argv) {
    CGDirectDisplayID ids[16];
    uint32_t count = 0;
    CGGetOnlineDisplayList(16, ids, &count);

    if (argc > 1 && strcmp(argv[1], "-l") == 0) {
        for (uint32_t i = 0; i < count; i++) {
            if (CGDisplayIsBuiltin(ids[i])) continue;
            uint32_t width = 0, height = 0;
            native_size(ids[i], &width, &height);
            printf("%u %x %x %ux%u\n", ids[i], CGDisplayVendorNumber(ids[i]), CGDisplayModelNumber(ids[i]), width, height);
        }
        return 0;
    }

    CGDirectDisplayID id = 0;
    uint32_t width = 0, height = 0;
    for (int a = 1; a < argc; a++) {
        if (strcmp(argv[a], "-d") == 0 && a + 1 < argc) {
            id = (CGDirectDisplayID)strtoul(argv[++a], NULL, 10);
        } else if (sscanf(argv[a], "%ux%u", &width, &height) != 2) {
            fprintf(stderr, "usage: set-hidpi -l | [-d ID] [WIDTHxHEIGHT]\n");
            return 2;
        }
    }
    for (uint32_t i = 0; i < count && !id; i++) {
        if (!CGDisplayIsBuiltin(ids[i])) id = ids[i];
    }
    if (!id) {
        fprintf(stderr, "No external display\n");
        return 1;
    }
    if (!width && !native_size(id, &width, &height)) {
        fprintf(stderr, "Unknown native size, pass WIDTHxHEIGHT\n");
        return 1;
    }

    int modes = 0, current = -1, best = -1, best_freq = 0;
    CGSGetNumberOfDisplayModes(id, &modes);
    CGSGetCurrentDisplayMode(id, &current);
    for (int m = 0; m < modes; m++) {
        CGSDisplayModeDescription d;
        CGSGetDisplayModeDescriptionOfLength(id, m, &d, sizeof d);
        if (d.width == width && d.height == height && d.density > 1.5 && d.freq > best_freq) {
            best = (int)d.mode;
            best_freq = d.freq;
        }
    }
    if (best < 0) {
        fprintf(stderr, "No %ux%u HiDPI mode on display %u\n", width, height, id);
        return 1;
    }
    if (best == current) {
        printf("Already on %ux%u HiDPI @ %dHz\n", width, height, best_freq);
        return 0;
    }

    CGDisplayConfigRef config;
    if (CGBeginDisplayConfiguration(&config) != kCGErrorSuccess) return 1;
    CGSConfigureDisplayMode(config, id, best);
    if (CGCompleteDisplayConfiguration(config, kCGConfigurePermanently) != kCGErrorSuccess) {
        fprintf(stderr, "macOS refused the mode change\n");
        return 1;
    }
    printf("Switched to %ux%u HiDPI @ %dHz\n", width, height, best_freq);
    return 0;
}
