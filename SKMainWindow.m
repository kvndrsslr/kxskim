//
//  SKMainWindow.m
//  Skim
//
//  Created by Christiaan Hofman on 4/24/07.
/*
 This software is Copyright (c) 2007
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SKMainWindow.h"
#import "NSEvent_SKExtensions.h"


@interface NSWindow (SKPrivateDeclarations)
- (NSTitlebarAccessoryViewController *)_tabBarAccessoryViewController;
@end

#pragma mark -

@implementation SKWindow

- (void)keyDown:(NSEvent *)event {
    if (([event deviceIndependentModifierFlags] & ~NSEventModifierFlagNumericPad) == (NSEventModifierFlagCommand | NSEventModifierFlagOption)) {
        unichar eventChar = [event firstCharacter];
        if (eventChar >= '1' && eventChar <= '9') {
            NSArray *windows = [self tabbedWindows];
            if ([windows count] > MAX(1UL, eventChar - '1')) {
                [self setValue:[windows objectAtIndex:eventChar - '1'] forKeyPath:@"tabGroup.selectedWindow"];
                return;
            }
        }
    }
    [super keyDown:event];
}

@end

#pragma mark -

@class SKTitleBarHoverView;

@interface SKMainWindow ()
{
    SKTitleBarHoverView *titleBarHoverView;
    BOOL toolbarShown;
}
- (void)setTitleBarHovered:(BOOL)hovered;
@end

@interface SKTitleBarHoverView : NSView
@property (nullable, weak) SKMainWindow *mainWindow;
@end

@implementation SKTitleBarHoverView

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

- (void)updateTrackingAreas {
    for (NSTrackingArea *area in [self trackingAreas])
        [self removeTrackingArea:area];
    [super updateTrackingAreas];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

- (void)mouseMoved:(NSEvent *)theEvent {
    NSWindow *window = [self window];
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [[self mainWindow] setTitleBarHovered:NSMaxY([self bounds]) - point.y <= NSHeight([window frame]) - NSHeight([window contentLayoutRect])];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [[self mainWindow] setTitleBarHovered:NO];
}

@end

#pragma mark -

@implementation SKMainWindow

@synthesize autoTitleVisibility, autoHidesTitleBar;
@dynamic delegate;

- (void)updateTitleBarChrome {
    BOOL hidden = autoHidesTitleBar && titleBarHovered == NO && 0 == ([self styleMask] & NSWindowStyleMaskFullScreen);
    // the toolbar hides and shows together with the title bar, but only its *visibility* is
    // suppressed while the chrome is hidden; the user's preference in toolbarShown is never
    // changed here, so it is restored exactly when the chrome shows again
    if (autoHidesTitleBar) {
        BOOL showToolbar = toolbarShown && hidden == NO;
        if ([[self toolbar] isVisible] != showToolbar)
            [[self toolbar] setVisible:showToolbar];
    }
    [self setTitlebarAppearsTransparent:hidden];
    [self setTitlebarSeparatorStyle:hidden ? NSTitlebarSeparatorStyleNone : NSTitlebarSeparatorStyleAutomatic];
    if (hidden) {
        [self setTitleVisibility:NSWindowTitleHidden];
    } else if (autoTitleVisibility == SKWindowTitleHiddenForTabBar) {
        NSTitlebarAccessoryViewController *tabBarController = [self safeTabBarViewController];
        [self setTitleVisibility:(tabBarController && [[self titlebarAccessoryViewControllers] containsObject:tabBarController]) ? NSWindowTitleHidden : NSWindowTitleVisible];
    } else if (autoTitleVisibility) {
        [self updateForToolbarVisibility:[[self toolbar] isVisible]];
    } else {
        [self setTitleVisibility:NSWindowTitleVisible];
    }
    for (NSWindowButton button = NSWindowCloseButton; button <= NSWindowZoomButton; button++)
        [[self standardWindowButton:button] setHidden:hidden];
}

- (void)setTitleBarHovered:(BOOL)hovered {
    if (titleBarHovered == hovered)
        return;
    titleBarHovered = hovered;
    [self updateTitleBarChrome];
}

- (void)setAutoHidesTitleBar:(BOOL)flag {
    if (autoHidesTitleBar == flag)
        return;
    autoHidesTitleBar = flag;
    if (flag) {
        // remember whether the user wants the toolbar, as its visibility is the truth we
        // need to restore when the chrome shows or the feature is turned off again
        toolbarShown = [[self toolbar] isVisible];
        NSView *frameView = [[self contentView] superview];
        if (titleBarHoverView == nil) {
            titleBarHoverView = [[SKTitleBarHoverView alloc] initWithFrame:[frameView bounds]];
            [titleBarHoverView setMainWindow:self];
            [titleBarHoverView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        }
        [frameView addSubview:titleBarHoverView positioned:NSWindowAbove relativeTo:nil];
        titleBarHovered = NO;
    } else {
        [titleBarHoverView removeFromSuperview];
        titleBarHoverView = nil;
        titleBarHovered = YES;
        // the feature is off, so the user's preference is the effective visibility
        if ([[self toolbar] isVisible] != toolbarShown)
            [[self toolbar] setVisible:toolbarShown];
    }
    [self updateTitleBarChrome];
}

- (void)setStyleMask:(NSWindowStyleMask)styleMask {
    if (0 != (styleMask & NSWindowStyleMaskFullScreen) && 0 == ([self styleMask] & NSWindowStyleMaskFullScreen) && [[self delegate] respondsToSelector:@selector(windowWillEnterFullScreenStyle:)])
        [[self delegate] windowWillEnterFullScreenStyle:self];
    else if (0 == (styleMask & NSWindowStyleMaskFullScreen) && 0 != ([self styleMask] & NSWindowStyleMaskFullScreen) && [[self delegate] respondsToSelector:@selector(windowWillExitFullScreenStyle:)])
        [[self delegate] windowWillExitFullScreenStyle:self];
    [super setStyleMask:styleMask];
    if (autoHidesTitleBar)
        [self updateTitleBarChrome];
}

- (void)sendEvent:(NSEvent *)theEvent {
    if ([theEvent type] == NSEventTypeLeftMouseDown || [theEvent type] == NSEventTypeRightMouseDown || [theEvent type] == NSEventTypeKeyDown) {
        if ([[self delegate] respondsToSelector:@selector(window:willSendEvent:)])
            [[self delegate] window:self willSendEvent:theEvent];
    } else if ([theEvent type] == NSEventTypeScrollWheel && ([theEvent modifierFlags] & NSEventModifierFlagOption)) {
        NSResponder *target = (NSResponder *)[[self contentView] hitTest:[theEvent locationInWindow]] ?: (NSResponder *)self;
        while (target && [target respondsToSelector:@selector(magnifyWheel:)] == NO)
            target = [target nextResponder];
        if (target) {
            [target magnifyWheel:theEvent];
            return;
        }
    }
    [super sendEvent:theEvent];
}

- (void)performClose:(id)sender {
    if ([self delegate])
        [super performClose:sender];
}

- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen {
    return disableConstrainedFrame ? frameRect : [super constrainFrameRect:frameRect toScreen:screen];
}

- (void)setFrameWithoutConstrain:(NSRect)frameRect {
    disableConstrainedFrame = YES;
    [self setFrame:frameRect display:YES];
    disableConstrainedFrame = NO;
}

- (NSTitlebarAccessoryViewController *)safeTabBarViewController {
    if ([self respondsToSelector:@selector(_tabBarAccessoryViewController)])
        return [self _tabBarAccessoryViewController];
    return nil;
}

- (void)updateForToolbarVisibility:(BOOL)toolbarIsVisible {
    if (autoTitleVisibility == SKWindowTitleHiddenForTabBar) {
        NSLayoutAttribute layoutAttribute = toolbarIsVisible ? NSLayoutAttributeBottom : NSLayoutAttributeTop;
        NSTitlebarAccessoryViewController *tabBarController = [self safeTabBarViewController];
        if (tabBarController && [tabBarController layoutAttribute] != layoutAttribute) {
            NSUInteger i = [[self titlebarAccessoryViewControllers] indexOfObject:tabBarController];
            if (i != NSNotFound) {
                [super removeTitlebarAccessoryViewControllerAtIndex:i];
                [tabBarController setLayoutAttribute:layoutAttribute];
                [super addTitlebarAccessoryViewController:tabBarController];
            }
        }
    } else if (autoTitleVisibility == SKWindowTitleHiddenForToolbar) {
        [self setTitleVisibility:toolbarIsVisible ? NSWindowTitleHidden : NSWindowTitleVisible];
    }
}

- (void)setAutoTitleVisibility:(SKAutoWindowTitleVisibility)visibility {
    if (autoTitleVisibility != visibility) {
        autoTitleVisibility = visibility;
        if (autoTitleVisibility) {
            [self updateForToolbarVisibility:[[self toolbar] isVisible]];
            if (autoTitleVisibility == SKWindowTitleHiddenForTabBar && [self safeTabBarViewController] && [[self titlebarAccessoryViewControllers] containsObject:[self safeTabBarViewController]])
                [self setTitleVisibility:NSWindowTitleHidden];
        }
    }
}

- (void)toggleToolbarShown:(id)sender {
    if (autoTitleVisibility) {
        BOOL willBeVisible = [[self toolbar] isVisible] == NO;
        NSString *identifier = [[self toolbar] identifier];
        for (NSWindow *window in [NSApp windows]) {
            if ([[[window toolbar] identifier] isEqualToString:identifier] && [window respondsToSelector:@selector(updateForToolbarVisibility:)])
                [(SKMainWindow *)window updateForToolbarVisibility:willBeVisible];
        }
    }
    [super toggleToolbarShown:sender];
    if (autoHidesTitleBar) {
        // the user's toggle is the truth, so record it as the preference and then re-apply the
        // hiding of the chrome (the toolbar may have been shown only to toggle its state)
        toolbarShown = [[self toolbar] isVisible];
        [self updateTitleBarChrome];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    BOOL enabled = [super validateMenuItem:menuItem];
    // the check mark must show the user's preference, not whether the toolbar is currently
    // hidden because the title bar is hidden until hovered
    if (autoHidesTitleBar && [menuItem action] == @selector(toggleToolbarShown:))
        [menuItem setState:toolbarShown ? NSControlStateValueOn : NSControlStateValueOff];
    return enabled;
}

- (void)addTitlebarAccessoryViewController:(NSTitlebarAccessoryViewController *)childViewController {
    if ([self autoTitleVisibility] == SKWindowTitleHiddenForTabBar && [self safeTabBarViewController] == childViewController) {
        [self setTitleVisibility:NSWindowTitleHidden];
        if ([[self toolbar] isVisible] == NO) {
            [childViewController setLayoutAttribute:NSLayoutAttributeTop];
            NSURL *url = [self representedURL];
            [self setRepresentedURL:nil];
            [self setRepresentedURL:url];
        } else {
            [childViewController setLayoutAttribute:NSLayoutAttributeBottom];
        }
    }
    [super addTitlebarAccessoryViewController:childViewController];
}

- (void)removeTitlebarAccessoryViewControllerAtIndex:(NSInteger)index {
    if ([self autoTitleVisibility] == SKWindowTitleHiddenForTabBar && [self safeTabBarViewController] == [[self titlebarAccessoryViewControllers] objectAtIndex:index]) {
        [super removeTitlebarAccessoryViewControllerAtIndex:index];
        [self setTitleVisibility:NSWindowTitleVisible];
        if ([[self toolbar] isVisible] == NO) {
            NSURL *url = [self representedURL];
            [self setRepresentedURL:nil];
            [self setRepresentedURL:url];
        }
    } else {
        [super removeTitlebarAccessoryViewControllerAtIndex:index];
    }
}

@end
