#include "mac_window_chrome.h"

#include <QColor>
#include <QWidget>

#import <Cocoa/Cocoa.h>

void applyMacWindowChrome(QWidget *window, const QColor &background)
{
    if (window == nullptr) {
        return;
    }

    NSView *view = reinterpret_cast<NSView *>(window->winId());
    NSWindow *nativeWindow = view != nil ? view.window : nil;
    if (nativeWindow == nil) {
        return;
    }

    nativeWindow.titlebarAppearsTransparent = YES;
    nativeWindow.titleVisibility = NSWindowTitleVisible;
    if (@available(macOS 11.0, *)) {
        nativeWindow.toolbarStyle = NSWindowToolbarStyleUnifiedCompact;
    }
    nativeWindow.backgroundColor = [NSColor colorWithSRGBRed:background.redF()
                                                        green:background.greenF()
                                                         blue:background.blueF()
                                                        alpha:background.alphaF()];
    nativeWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
}
