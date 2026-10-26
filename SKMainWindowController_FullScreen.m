//
//  SKMainWindowController_FullScreen.m
//  Skim
//
//  Created by Christiaan on 14/06/2019.
/*
 This software is Copyright (c) 2019
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

#import "SKMainWindowController_FullScreen.h"
#import "SKMainWindowController_UI.h"
#import "SKMainWindowController_Actions.h"
#import "SKSideWindow.h"
#import "SKFullScreenWindow.h"
#import "SKSideViewController.h"
#import "SKLeftSideViewController.h"
#import "SKRightSideViewController.h"
#import "SKApplication.h"
#import "SKTableView.h"
#import "SKStringConstants.h"
#import "SKMainTouchBarController.h"
#import "SKMainDocument.h"
#import "SKSnapshotPDFView.h"
#import "SKSecondaryPDFView.h"
#import "SKOverviewView.h"
#import "SKTopBarView.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSScreen_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "SKStatusBar.h"
#import "SKAnimatedBorderlessWindow.h"
#import "SKPresentationView.h"
#import "NSWindow_SKExtensions.h"
#import "SKImageToolTipWindow.h"
#import "SKNoteToolbarController.h"
#import "SKPresentationNotesAuxiliary.h"
#import "SKTimerView.h"

#define MAINWINDOWFRAME_KEY         @"windowFrame"
#define TABGROUP_KEY                @"tabGroup"
#define TABINDEX_KEY                @"tabIndex"
#define LEFTSIDEPANEWIDTH_KEY       @"leftSidePaneWidth"
#define RIGHTSIDEPANEWIDTH_KEY      @"rightSidePaneWidth"

#define SKShowToolbarInFullScreenKey @"SKShowToolbarInFullScreen"
#define SKShowSidePanesInFullScreenKey @"SKShowSidePanesInFullScreen"
#define SKResizablePresentationKey @"SKResizablePresentation"

#define AppleMenuBarVisibleInFullscreenKey @"AppleMenuBarVisibleInFullscreen"

#define PRESENTATION_DURATION 0.5

static CGFloat fullScreenToolbarOffset = 0.0;

@implementation SKMainWindowController (FullScreen)

#pragma mark Side Windows

- (void)showSideWindow {
    if ([[leftSideController.view window] firstResponderIsDescendantOf:leftSideController.sideView])
        [[leftSideController.sideView window] makeFirstResponder:nil];
    
    if (sideWindow == nil)
        sideWindow = [[SKSideWindow alloc] initWithView:leftSideController.sideView];
    
    if (mwcFlags.fullSizeContent) {
        [leftSideController.topBar setStyle:SKTopBarStylePresentation];
        [leftSideController setTopInset:0.0];
    } else {
        [leftSideController.topBar setDrawsBackground:NO];
    }

    if (mwcFlags.thumbnailsUpdatedDuringPresentaton == 0 && fabs([[self window] backingScaleFactor] - [savedNormalWindow backingScaleFactor]) > 0.0) {
        [self allThumbnailsNeedUpdate];
        mwcFlags.thumbnailsUpdatedDuringPresentaton = 1;
    }
    
    mwcFlags.savedLeftSidePaneState = [self leftSidePaneState];
    [self setLeftSidePaneState:SKSidePaneStateThumbnail];
    [sideWindow makeFirstResponder:leftSideController.thumbnailTableView];
    [sideWindow attachToWindow:[self window]];
}

- (void)hideSideWindow {
    if ([[leftSideController.sideView window] isEqual:sideWindow]) {
        [sideWindow remove];
        
        if ([sideWindow firstResponderIsDescendantOf:leftSideController.sideView])
            [sideWindow makeFirstResponder:nil];
        if (mwcFlags.fullSizeContent) {
            [leftSideController.topBar setStyle:SKTopBarStyleSearchBar];
            [leftSideController setTopInset:titleBarHeight];
        } else {
            [leftSideController.topBar setDrawsBackground:YES];
        }
        
        [leftSideController.sideView setFrame:[leftSideController.view bounds]];
        
        [leftSideController.view addSubviewWithConstraints:leftSideController.sideView];
        
        [self setLeftSidePaneState:mwcFlags.savedLeftSidePaneState];
        
        sideWindow = nil;
    }
}

#pragma mark Presentation Support Methods

- (NSScreen *)screenForPresentationWindowAvoidingScreen:(NSScreen *)screenToAvoid preferExternal:(BOOL)preferExternal {
    NSScreen *mainScreen = [savedNormalWindow screen];
    if (screenToAvoid || preferExternal) {
        NSArray *allScreens = [NSScreen screens];
        if ([allScreens count] > 1) {
            NSMutableDictionary *screens = [NSMutableDictionary dictionary];
            NSMutableArray *screenNumbers = [NSMutableArray array];
            NSNumber *avoidScreenNumber = nil;
            NSNumber *builtinScreenNumber = nil;
            NSNumber *mainScreenNumber = nil;
            for (NSScreen *aScreen in allScreens) {
                NSDictionary *deviceDescription = [aScreen deviceDescription];
                if ([deviceDescription objectForKey:NSDeviceIsScreen] == nil)
                    continue;
                NSNumber *aScreenNumber = [deviceDescription objectForKey:@"NSScreenNumber"];
                CGDirectDisplayID displayID = (CGDirectDisplayID)[aScreenNumber unsignedIntValue];
                CGDirectDisplayID primaryDisplayID = CGDisplayMirrorsDisplay(displayID);
                if (primaryDisplayID == kCGNullDirectDisplay) {
                    [screenNumbers addObject:aScreenNumber];
                    [screens setObject:aScreen forKey:aScreenNumber];
                } else {
                    aScreenNumber = [NSNumber numberWithUnsignedInt:primaryDisplayID];
                }
                if (avoidScreenNumber == nil && [aScreen isEqual:screenToAvoid])
                    avoidScreenNumber = aScreenNumber;
                if (preferExternal && builtinScreenNumber == nil && CGDisplayIsBuiltin(displayID))
                    builtinScreenNumber = aScreenNumber;
                if (mainScreenNumber == nil && [aScreen isEqual:mainScreen])
                    mainScreenNumber = aScreenNumber;
            }
            if (avoidScreenNumber)
                [screenNumbers removeObject:avoidScreenNumber];
            if (builtinScreenNumber && [screenNumbers count] > 1)
                [screenNumbers removeObject:builtinScreenNumber];
            if ([screenNumbers count] > 0 && [screenNumbers containsObject:mainScreenNumber] == NO)
                return [screens objectForKey:[screenNumbers firstObject]];
        }
    }
    return mainScreen;
}

- (PDFPage *)pageForPresentationNotes {
    NSDocument *notesDocument = [self presentationNotesDocument];
    NSInteger offset = [self presentationNotesOffset];
    PDFPage *page = [pdfView currentPage];
    if (notesDocument != [self document] || offset != 0) {
        PDFDocument *pdfDoc = [notesDocument pdfDocument];
        page = [pdfDoc pageAtIndex:MAX(0, MIN((NSInteger)[pdfDoc pageCount] - 1, (NSInteger)[page pageIndex] + offset))];
    }
    return page;
}

- (void)handlePresentationViewPageChanged:(NSNotification *)notification {
    PDFPage *page = [presentationView page];
    if (page) {
        if (page != [pdfView currentPage]) {
            // make sure we can synchronize the page between the presentationView and the pdfView
            if ([pdfView displayMode] != kPDFDisplaySinglePage)
                [pdfView setExtendedDisplayMode:kPDFDisplaySinglePage];
            [pdfView goToPage:page];
        }
        if ([self presentationNotesDocument]) {
            PDFPage *page = [self pageForPresentationNotes];
            if ([self presentationNotesDocument] == [self document])
                [[[presentationNotesAuxiliary previewController] pdfView] goAndScrollToPage:page];
            else
                [[self presentationNotesDocument] setCurrentPage:page];
        }
    }
}

#pragma mark API

- (void)enterFullscreen {
    if ([self canEnterFullscreen]) {
        if ([self interactionMode] == SKPresentationMode) {
            mwcFlags.wantsPresentationOrFullScreen = 1;
            [self exitPresentation];
        } else {
            [[self window] toggleFullScreen:nil];
        }
    }
}

- (void)exitFullscreen {
    if ([self canExitFullscreen])
        [[self window] toggleFullScreen:nil];
}

- (void)enterPresentation {
    if ([self canEnterPresentation] == NO)
        return;
    
    if ([[[self window] tabbedWindows] count] > 1) {
        NSWindowTabGroup *tabGroup = [[self window] tabGroup];
        if ([tabGroup selectedWindow] != [self window]) {
            if (([[tabGroup selectedWindow] styleMask] & NSWindowStyleMaskFullScreen))
                return;
            [tabGroup setSelectedWindow:[self window]];
        }
    }
    
    if ([self interactionMode] == SKFullScreenMode) {
        mwcFlags.wantsPresentationOrFullScreen = 1;
        [[self window] toggleFullScreen:nil];
        return;
    }
    
    mwcFlags.isSwitchingFullScreen = 1;
    
    // clean up extra windows, as we will not receive windowWillResignMain:
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
    if ([[[NSColorPanel sharedColorPanel] accessoryView] isEqual:colorAccessoryView] || [[[NSColorPanel sharedColorPanel] accessoryView] isEqual:textColorAccessoryView])
        [[NSColorPanel sharedColorPanel] setAccessoryView:nil];
    
    // remember normal setup to return to, we must do this before changing the interactionMode
    [savedNormalSetup setDictionary:[pdfView displaySettings]];
    
    NSWindow *normalWindow = [self window];
    savedNormalWindow = normalWindow;
    
    [normalWindow setDelegate:nil];
    
    interactionMode = SKPresentationMode;
    
    NSDocument *notesDocument = [self presentationNotesDocument];
    NSScreen *screen = nil;
    BOOL preferExternal = [[NSUserDefaults standardUserDefaults] boolForKey:SKPreferExternalDisplayForPresentationKey];
    if (notesDocument && notesDocument != [self document])
        screen = [[notesDocument primaryWindow] screen];
    screen = [self screenForPresentationWindowAvoidingScreen:screen preferExternal:preferExternal];
    
    NSWindow *presentationWindow = [[SKFullScreenWindow alloc] initWithContentRect:[screen frame]];
    [presentationWindow setAlphaValue:0.0];
    
    if (presentationView == nil)
        presentationView = [[SKPresentationView alloc] initWithFrame:[[presentationWindow contentView] bounds]];
    else
        [presentationView setFrame:[[presentationWindow contentView] bounds]];
    [[presentationWindow contentView] addSubviewWithConstraints:presentationView];
    [presentationWindow makeFirstResponder:presentationView];
    [presentationView setAutoScales:YES];
    [presentationView setPage:[pdfView currentPage]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePresentationViewPageChanged:) name:SKPresentationViewPageChangedNotification object:presentationView];
    
    [presentationWindow orderFront:nil];
    
    if (notesDocument) {
        if (presentationNotesAuxiliary == nil)
            presentationNotesAuxiliary = [[SKPresentationNotesAuxiliary alloc] init];
        PDFPage *page = [self pageForPresentationNotes];
        if (notesDocument == [self document]) {
            screen = [self screenForPresentationWindowAvoidingScreen:screen preferExternal:NO];
            [self showSnapshotAtPage:page previewOnScreen:screen];
        } else {
            [notesDocument setCurrentPage:page];
        }
    }
    
    BOOL shouldFadeOut = NO;
    if ([[normalWindow tabbedWindows] count] > 1) {
        NSUInteger tabIndex = [[normalWindow tabbedWindows] indexOfObject:normalWindow];
        [savedNormalSetup setObject:[normalWindow tabGroup] forKey:TABGROUP_KEY];
        [savedNormalSetup setObject:[NSNumber numberWithUnsignedInteger:tabIndex] forKey:TABINDEX_KEY];
    } else if (NSContainsRect([presentationWindow frame], [normalWindow frame]) == NO) {
        shouldFadeOut = YES;
    }
    
    [self setWindow:presentationWindow];
    
    [presentationWindow setDelegate:self];
    
    // prevent sleep
    if (activity == nil)
        activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated | NSActivityIdleDisplaySleepDisabled | NSActivityIdleSystemSleepDisabled  reason:@"Presentation"];
    
    [touchBarController interactionModeChanged];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:PRESENTATION_DURATION];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [[presentationWindow animator] setAlphaValue:1.0];
            if (shouldFadeOut)
                [[normalWindow animator] setAlphaValue:0.0];
            [[[[presentationNotesAuxiliary previewController] window] animator] setAlphaValue:1.0];
        }
        completionHandler:^{
            // only hide the dock and menubar when the presentation window is on the primary screen, otherwise no need to block main menu and dock
            if ([[presentationWindow screen] hasMenuBar])
                [NSApp setPresentationOptions:NSApplicationPresentationHideDock | NSApplicationPresentationHideMenuBar];
            
            [normalWindow orderOutWithoutAnimation];
            [normalWindow setAlphaValue:1.0];
            if ([self hasOverview])
                [self hideOverviewAnimating:NO];
            
            [presentationWindow setLevel:[[NSUserDefaults standardUserDefaults] boolForKey:SKUseNormalLevelForPresentationKey] ? NSNormalWindowLevel : NSPopUpMenuWindowLevel];
            [presentationWindow makeKeyAndOrderFront:nil];
            [NSApp addWindowsItem:presentationWindow title:[self windowTitleForDocumentDisplayName:[[self document] displayName]] filename:NO];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:SKResizablePresentationKey]) {
                [presentationWindow setStyleMask:[presentationWindow styleMask] | NSWindowStyleMaskResizable];
                [presentationWindow setHasShadow:YES];
            }
            
            [presentationView didOpen];
            
            if (notesDocument)
                [self addPresentationNotesNavigation];
            
            mwcFlags.isSwitchingFullScreen = 0;
        }];
}

- (void)exitPresentation {
    if ([self canExitPresentation] == NO)
        return;
    
    mwcFlags.isSwitchingFullScreen = 1;
    
    if ([sideWindow isVisible])
        [self hideSideWindow];
    
    if ([[presentationNotesAuxiliary notes] count]) {
        PDFDocument *pdfDoc = [self pdfDocument];
        for (PDFAnnotation *annotation in [[presentationNotesAuxiliary notes] copy])
            [pdfDoc removeAnnotation:annotation];
    }
    
    [presentationView willClose];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SKPresentationViewPageChangedNotification object:presentationView];
    
    NSWindow *presentationWindow = [self window];
    
    while ([[presentationWindow childWindows] count] > 0) {
        NSWindow *childWindow = [[presentationWindow childWindows] lastObject];
        [presentationWindow removeChildWindow:childWindow];
        [childWindow orderOut:nil];
    }
    
    [presentationWindow setDelegate:nil];
    [presentationWindow makeFirstResponder:nil];
    
    interactionMode = SKNormalMode;
    
    if (activity) {
        [[NSProcessInfo processInfo] endActivity:activity];
        activity = nil;
    }
    
    [self removePresentationNotesNavigation];
    
    PDFDisplayMode mode = [[savedNormalSetup objectForKey:@"displayMode"] integerValue];
    if (mode == kPDFDisplaySinglePageContinuous && [[savedNormalSetup objectForKey:@"displayDirection"] boolValue])
        mode = kPDFDisplayHorizontalContinuous;
    //make sure we reset the display mode
    if (mode != [pdfView extendedDisplayMode])
        [pdfView setExtendedDisplayModeAndRewind:mode];
    
    NSWindow *normalWindow = savedNormalWindow;
    savedNormalWindow = nil;
    
    [self setWindow:normalWindow];
    
    if (@available(macOS 11.0, *)) {} else
        [self synchronizeWindowTitleWithDocumentName];
    
    if (mwcFlags.thumbnailsNeedUpdateAfterPresentaton) {
        mwcFlags.thumbnailsNeedUpdateAfterPresentaton = 0;
        [self allThumbnailsNeedUpdate];
    }
    mwcFlags.thumbnailsUpdatedDuringPresentaton = 0;
    
    NSWindowTabGroup *tabGroup = [savedNormalSetup objectForKey:TABGROUP_KEY];
    BOOL moveToTab = [[tabGroup windows] count] > 0;
    
    [normalWindow setAlphaValue:0.0];
    if (NSPointInRect(SKCenterPoint([normalWindow frame]), [[presentationWindow screen] frame]) && moveToTab == NO) {
        NSWindowCollectionBehavior collectionBehavior = [normalWindow collectionBehavior];
        // trick to make sure the main window shows up in the same space as the fullscreen window
        [normalWindow setCollectionBehavior:collectionBehavior | NSWindowCollectionBehaviorMoveToActiveSpace];
        [normalWindow orderFrontWithoutAnimation];
        dispatch_async(dispatch_get_main_queue(), ^{ [normalWindow setCollectionBehavior:collectionBehavior]; });
    } else {
        [normalWindow orderFrontWithoutAnimation];
    }
    if ([pdfView window] == normalWindow)
        [normalWindow makeFirstResponder:pdfView];
    [normalWindow setDelegate:self];
    [normalWindow makeKeyWindow];
    
    [NSApp removeWindowsItem:presentationWindow];
    [presentationWindow setLevel:NSPopUpMenuWindowLevel];
    
    [NSApp setPresentationOptions:NSApplicationPresentationDefault];
    
    if (moveToTab) {
        NSUInteger tabIndex = [[savedNormalSetup objectForKey:TABINDEX_KEY] unsignedIntegerValue];
        [normalWindow setAlphaValue:1.0];
        [tabGroup insertWindow:normalWindow atIndex:MIN(tabIndex, [[tabGroup windows] count])];
    } else if (NSContainsRect([presentationWindow frame], [normalWindow frame])) {
        [normalWindow setAlphaValue:1.0];
    }
    
    [savedNormalSetup removeAllObjects];
    
    // the page number may have changed
    [self updateSubtitle];
    
    [touchBarController interactionModeChanged];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:PRESENTATION_DURATION];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            if ([normalWindow alphaValue] < 1.0)
                [[normalWindow animator] setAlphaValue:1.0];
            [[presentationWindow animator] setAlphaValue:0.0];
            [[[[presentationNotesAuxiliary previewController] window] animator] setAlphaValue:0.0];
        }
        completionHandler:^{
            if ([self hasOverview])
                [self hideOverviewAnimating:NO];
            [presentationWindow orderOut:nil];
            [presentationView setPage:nil];
            [presentationView setAutoScales:NO];
            
            if ([presentationNotesAuxiliary previewController]) {
                [[[presentationNotesAuxiliary previewController] window] setAnimationBehavior:NSWindowAnimationBehaviorNone];
                [[presentationNotesAuxiliary previewController] close];
            }
            
            presentationNotesAuxiliary = nil;
            
            mwcFlags.isSwitchingFullScreen = 0;
            
            if (mwcFlags.wantsPresentationOrFullScreen) {
                mwcFlags.wantsPresentationOrFullScreen = 0;
                [self enterFullscreen];
            }
        }];
}

- (BOOL)canEnterFullscreen {
    return mwcFlags.isSwitchingFullScreen == 0 && [self interactionMode] != SKFullScreenMode;
}

- (BOOL)canEnterPresentation {
    return mwcFlags.isSwitchingFullScreen == 0 && [[self pdfDocument] isLocked] == NO && [[[[NSDocumentController sharedDocumentController] documents] valueForKeyPath:@"@max.interactionMode"] integerValue] != SKPresentationMode;
}

- (BOOL)canExitFullscreen {
    return mwcFlags.isSwitchingFullScreen == 0 && [self interactionMode] == SKFullScreenMode;
}

- (BOOL)canExitPresentation {
    return mwcFlags.isSwitchingFullScreen == 0 && [self interactionMode] == SKPresentationMode;
}

#pragma mark Full Screen Support Methods

- (void)forceSubwindowsOnTop:(BOOL)flag {
    for (NSWindowController *wc in [[self document] windowControllers]) {
        if ([wc respondsToSelector:@selector(setForceOnTop:)] && wc != [presentationNotesAuxiliary previewController])
            [(id)wc setForceOnTop:flag];
    }
}

- (void)displayStaticContentInWindow:(NSWindow *)displayWindow ordered:(NSWindowOrderingMode)place {
    NSWindow *window = [self window];
    NSRect frame = [window frame];
    CALayer *layer = [CALayer layer];
    CGImageRef cgImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, (CGWindowID)[window windowNumber], kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution);
    [layer setMasksToBounds:YES];
    [layer setBounds:[[window contentView] bounds]];
    [layer setContentsScale:[window backingScaleFactor]];
    [layer setContents:CFBridgingRelease(cgImage)];
    if (([window styleMask] & NSWindowStyleMaskFullScreen) != 0 && NSHeight([window frame]) > NSHeight([window contentLayoutRect])) {
        for (NSWindow *tbWindow in [window childWindows]) {
            if ([NSStringFromClass([tbWindow class]) containsString:@"Toolbar"]) {
                CGImageRef tbCgImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, (CGWindowID)[tbWindow windowNumber], kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution);
                CALayer *tbLayer = [CALayer layer];
                [tbLayer setMasksToBounds:YES];
                [tbLayer setFrame:[window convertRectFromScreen:[tbWindow frame]]];
                [tbLayer setContentsScale:[window backingScaleFactor]];
                [tbLayer setContents:CFBridgingRelease(tbCgImage)];
                [layer addSublayer:tbLayer];
                break;
            }
        }
    }
    [displayWindow setFrame:frame display:NO];
    [[displayWindow contentView] setLayer:layer];
    [[displayWindow contentView] setWantsLayer:YES];
    [displayWindow setHasShadow:[window hasShadow]];
    [displayWindow setLevel:[window level]];
    [displayWindow orderWindow:place relativeTo:window];
    [window setAlphaValue:0.0];
}

#pragma mark NSWindowDelegate Full Screen Methods

static inline BOOL hasUnifiedToolbar(NSWindow *window) {
    if (@available(macOS 11.0, *))
        return [window toolbarStyle] != NSWindowToolbarStyleExpanded;
    return NO;
}

static inline CGFloat toolbarViewOffset(NSWindow *window) {
    NSToolbar *toolbar = [window toolbar];
    NSView *view = nil;
    if ([toolbar displayMode] == NSToolbarDisplayModeLabelOnly) {
        @try { view = [toolbar valueForKey:@"toolbarView"]; }
        @catch (id e) {}
    } else {
        for (NSToolbarItem *item in [toolbar visibleItems])
            if ((view = [item view]))
                break;
    }
    return view ? NSMaxY([[view window] convertRectToScreen:[view convertRect:[view bounds] toView:nil]]) - NSMaxY([[view window] frame]) : 0.0;
}

static inline CGFloat fullScreenOffset(NSWindow *window) {
    if (hasUnifiedToolbar(window))
        return 0.0;
    if (fullScreenToolbarOffset <= 0.0)
        fullScreenToolbarOffset = toolbarViewOffset(window);
    if (fullScreenToolbarOffset > 0.0)
        return fullScreenToolbarOffset;
    else if (@available(macOS 11.0, *))
        return 16.0;
    else
        return 17.0;
}

static inline void saveFullScreenToolbarOffset(NSWindow *window) {
    if (fullScreenToolbarOffset < 0.0 && [[NSUserDefaults standardUserDefaults] integerForKey:SKShowToolbarInFullScreenKey] && [[window toolbar] isVisible] && hasUnifiedToolbar(window) == NO) {
        CGFloat toolbarItemOffset = toolbarViewOffset(window);
        if (toolbarItemOffset < 0.0)
            // save the offset for the next time, we may guess it wrong as it varies between OS versions
            fullScreenToolbarOffset = toolbarItemOffset - fullScreenToolbarOffset;
    }
}

- (void)windowWillEnterFullScreenStyle:(NSWindow *)window {
    if (interactionMode != SKFullScreenMode) {
        interactionMode = SKFullScreenMode;
        NSColor *backgroundColor = [PDFView defaultFullScreenBackgroundColor];
        [pdfView setBackgroundColor:backgroundColor];
        [secondaryPdfView setBackgroundColor:backgroundColor];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKShowSidePanesInFullScreenKey] == NO) {
            [savedNormalSetup setObject:[NSNumber numberWithDouble:[self leftSideWidth]] forKey:LEFTSIDEPANEWIDTH_KEY];
             [savedNormalSetup setObject:[NSNumber numberWithDouble:[self rightSideWidth]] forKey:RIGHTSIDEPANEWIDTH_KEY];
            [self setLeftSideWidth:0.0];
            [self setRightSideWidth:0.0];
        }
        if ([[pdfView document] isLocked] == NO) {
            NSDictionary *fullScreenSetup = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey];
            if ([fullScreenSetup count])
                [pdfView setDisplaySettingsAndRewind:fullScreenSetup];
        }
    }
}

- (void)windowWillExitFullScreenStyle:(NSWindow *)window {
    if (interactionMode != SKNormalMode) {
        interactionMode = SKNormalMode;
        NSColor *backgroundColor = [PDFView defaultBackgroundColor];
        [pdfView setBackgroundColor:backgroundColor];
        [secondaryPdfView setBackgroundColor:backgroundColor];
        if ([savedNormalSetup objectForKey:LEFTSIDEPANEWIDTH_KEY]) {
            [self setLeftSideWidth:[[savedNormalSetup objectForKey:LEFTSIDEPANEWIDTH_KEY] doubleValue]];
            [self setRightSideWidth:[[savedNormalSetup objectForKey:RIGHTSIDEPANEWIDTH_KEY] doubleValue]];
        }
        if ([[[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey] count])
            [pdfView setDisplaySettingsAndRewind:savedNormalSetup];
    }
}

- (void)windowWillEnterFullScreen:(NSWindow *)window {
    mwcFlags.isSwitchingFullScreen = 1;
    if ([[pdfView document] isLocked] == NO || [savedNormalSetup count] == 0)
        [savedNormalSetup setDictionary:[pdfView displaySettings]];
    NSString *frameString = NSStringFromRect([[self window] frame]);
    [savedNormalSetup setObject:frameString forKey:MAINWINDOWFRAME_KEY];
    [self forceSubwindowsOnTop:YES];
}

- (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions {
    if ([[NSUserDefaults standardUserDefaults] integerForKey:SKShowToolbarInFullScreenKey])
        return proposedOptions;
    else
        return proposedOptions | NSApplicationPresentationAutoHideToolbar;
}

- (NSArray *)customWindowsToEnterFullScreenForWindow:(NSWindow *)window {
    NSMutableArray *windows = [NSMutableArray array];
    for (NSWindowController *wc in [[self document] windowControllers])
        [windows addObject:[wc window]];
    savedNormalWindow = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:[window frame]];
    [windows addObject:savedNormalWindow];
    return windows;
}

- (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration {
    NSRect frame = [[window screen] frame];
    BOOL showMenuBarInFullScreen = [[NSUserDefaults standardUserDefaults] boolForKey:AppleMenuBarVisibleInFullscreenKey];
    if (showMenuBarInFullScreen)
        frame.size.height -= [[NSApp mainMenu] menuBarHeight] ?: 24.0;
    NSWindow *displayWindow = savedNormalWindow;
    savedNormalWindow = nil;
    [self displayStaticContentInWindow:displayWindow ordered:NSWindowBelow];
    BOOL showToolbarWindow = [[NSUserDefaults standardUserDefaults] integerForKey:SKShowToolbarInFullScreenKey];
    CGFloat offset = 0.0;
    NSTitlebarAccessoryViewController *noteToolbar = nil;
    CALayer *blackLayer = nil;
    if (showToolbarWindow) {
        if ([[window toolbar] isVisible]) {
            offset = fullScreenOffset(window);
            if (noteToolbarController && [noteToolbarController isHidden] == NO && [noteToolbarController fullScreenMinHeight] <= 0.0 && [[window titlebarAccessoryViewControllers] containsObject:noteToolbarController]) {
                noteToolbar = noteToolbarController;
                [noteToolbar setHidden:YES];
            }
            for (NSView *view in [[[window standardWindowButton:NSWindowCloseButton] superview] subviews]) {
                if ([view isKindOfClass:[NSControl class]])
                    [view setAlphaValue:0.0];
            }
        } else {
            for (NSTitlebarAccessoryViewController *accessory in [window titlebarAccessoryViewControllers]) {
                if ([accessory isHidden] == NO && [accessory layoutAttribute] == NSLayoutAttributeBottom)
                    offset -= [accessory fullScreenMinHeight];
            }
            if (offset < 0.0)
                offset += NSHeight([window frame]) - NSHeight([window contentLayoutRect]);
            else
                showToolbarWindow = NO;
        }
    }
    if (showToolbarWindow) {
        frame.size.height += offset;
        [(SKMainWindow *)window setFrameWithoutConstrain:frame];
        if (showMenuBarInFullScreen && offset > 0.0) {
            blackLayer = [CALayer layer];
            [blackLayer setBackgroundColor:CGColorGetConstantColor(kCGColorBlack)];
            [blackLayer setZPosition:1.0];
            [blackLayer setFrame:SKSliceRect([window convertRectFromScreen:frame], offset, NSRectEdgeMaxY)];
            [[[[window contentView] superview] layer] addSublayer:blackLayer];
        }
        [self windowWillEnterFullScreenStyle:window];
    } else {
        [window setStyleMask:[window styleMask] | NSWindowStyleMaskFullScreen];
        [window setFrame:frame display:YES];
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:duration];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [[window animator] setAlphaValue:1.0];
        }
        completionHandler:^{
            [displayWindow orderOut:nil];
            [blackLayer removeFromSuperlayer];
            [noteToolbar setHidden:NO];
        }];
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    saveFullScreenToolbarOffset([self window]);
    [touchBarController interactionModeChanged];
    mwcFlags.isSwitchingFullScreen = 0;
}

- (void)windowDidFailToEnterFullScreen:(NSWindow *)window {
    [self windowWillExitFullScreenStyle:window];
    if ([[pdfView document] isLocked] == NO)
        [savedNormalSetup removeAllObjects];
    else
        [savedNormalSetup removeObjectsForKeys:@[MAINWINDOWFRAME_KEY, LEFTSIDEPANEWIDTH_KEY, RIGHTSIDEPANEWIDTH_KEY]];
    [self forceSubwindowsOnTop:NO];
    savedNormalWindow = nil;
    mwcFlags.isSwitchingFullScreen = 0;
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
    mwcFlags.isSwitchingFullScreen = 1;
}

- (NSArray *)customWindowsToExitFullScreenForWindow:(NSWindow *)window {
    return [self customWindowsToEnterFullScreenForWindow:window];
}

- (void)window:(NSWindow *)window startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration {
    NSRect frame = NSRectFromString([savedNormalSetup objectForKey:MAINWINDOWFRAME_KEY]);
    BOOL covered = NSContainsRect([window frame], frame);
    NSWindow *displayWindow = savedNormalWindow;
    savedNormalWindow = nil;
    [self displayStaticContentInWindow:displayWindow ordered:NSWindowAbove];
    [window setStyleMask:[window styleMask] & ~NSWindowStyleMaskFullScreen];
    [window setFrame:frame display:YES];
    if (covered)
        [window setAlphaValue:1.0];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:duration];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            if (covered == NO)
                [[window animator] setAlphaValue:1.0];
            [[displayWindow animator] setAlphaValue:0.0];
        }
        completionHandler:^{
            [displayWindow orderOut:nil];
        }];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    NSString *frameString = [savedNormalSetup objectForKey:MAINWINDOWFRAME_KEY];
    if (frameString)
        [[self window] setFrame:NSRectFromString(frameString) display:YES];
    if ([[pdfView document] isLocked] == NO)
        [savedNormalSetup removeAllObjects];
    else
        [savedNormalSetup removeObjectsForKeys:@[MAINWINDOWFRAME_KEY, LEFTSIDEPANEWIDTH_KEY, RIGHTSIDEPANEWIDTH_KEY]];
    [self forceSubwindowsOnTop:NO];
    mwcFlags.isSwitchingFullScreen = 0;
    if (mwcFlags.wantsPresentationOrFullScreen) {
        mwcFlags.wantsPresentationOrFullScreen = 0;
        // make sure the window fully finishes full screen
        // calling this immediately can crash when -moveTabToNewWindow: is called
        dispatch_async(dispatch_get_main_queue(), ^{ [self enterPresentation]; });
    } else {
        [touchBarController interactionModeChanged];
    }
}

- (void)windowDidFailToExitFullScreen:(NSWindow *)window {
    [self windowWillEnterFullScreenStyle:window];
    savedNormalWindow = nil;
    mwcFlags.isSwitchingFullScreen = 0;
    mwcFlags.wantsPresentationOrFullScreen = 0;
}

#pragma mark Presentation Notes Navigation

- (NSView *)presentationNotesView {
    NSDocument *notesDocument = [self presentationNotesDocument];
    if (notesDocument == nil)
        return nil;
    else if ([notesDocument isEqual:[self document]])
        return [[presentationNotesAuxiliary previewController] pdfView];
    else
        return [(SKMainDocument *)notesDocument pdfView];
}

- (void)addPresentationNotesNavigation {
    NSView *notesView = [self presentationNotesView];
    if (notesView) {
        NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect owner:self userInfo:nil];
        [notesView addTrackingArea:trackingArea];
        [presentationNotesAuxiliary setTrackingArea:trackingArea];
    }
}

- (void)removePresentationNotesNavigation {
    if ([presentationNotesAuxiliary trackingArea]) {
        [[self presentationNotesView] removeTrackingArea:[presentationNotesAuxiliary trackingArea]];
        [presentationNotesAuxiliary setTrackingArea:nil];
    }
    if ([presentationNotesAuxiliary button]) {
        [[presentationNotesAuxiliary button] removeFromSuperview];
        [presentationNotesAuxiliary setButton:nil];
    }
    if ([presentationNotesAuxiliary timerView]) {
        [[presentationNotesAuxiliary timerView] removeFromSuperview];
        [presentationNotesAuxiliary setTimerView:nil];
    }
}

- (void)mouseEntered:(NSEvent *)event {
    if ([[event trackingArea] isEqual:[presentationNotesAuxiliary trackingArea]]) {
        NSView *notesView = [self presentationNotesView];
        NSButton *button = [presentationNotesAuxiliary button];
        SKTimerView *timerView = [presentationNotesAuxiliary timerView];
        BOOL shouldAddTimer = [timerView superview] == nil;
        if (button == nil) {
            button = [[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 30.0, 50.0)];
            [button setButtonType:NSMomentaryChangeButton];
            [button setBordered:NO];
            [button setImage:[NSImage imageWithSize:NSMakeSize(30.0, 50.0) flipped:NO drawingHandler:^(NSRect rect){
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(5.0, 45.0)];
                [path lineToPoint:NSMakePoint(25.0, 25.0)];
                [path lineToPoint:NSMakePoint(5.0, 5.0)];
                [path setLineCapStyle:NSRoundLineCapStyle];
                [path setLineWidth:10.0];
                [[NSColor whiteColor] setStroke];
                [path stroke];
                [path setLineWidth:5.0];
                [[NSColor blackColor] setStroke];
                [path stroke];
                return YES;
            }]];
            [button setTarget:self];
            [button setAction:@selector(doGoToNextPage:)];
            [button setToolTip:NSLocalizedString(@"Next", @"Tool tip message")];
            [button setTranslatesAutoresizingMaskIntoConstraints:NO];
            [[button cell] setAccessibilityLabel:NSLocalizedString(@"Next", @"")];
            [presentationNotesAuxiliary setButton:button];
        }
        [button setAlphaValue:0.0];
        [notesView addSubview:button positioned:NSWindowAbove relativeTo:nil];
        [NSLayoutConstraint activateConstraints:@[
            [[button centerXAnchor] constraintEqualToAnchor:[notesView centerXAnchor]],
            [[notesView centerYAnchor] constraintEqualToAnchor:[button centerYAnchor]]]];
        if (timerView == nil) {
            timerView = [[SKTimerView alloc] init];
            [presentationNotesAuxiliary setTimerView:timerView];
        }
        if (shouldAddTimer) {
            [timerView setAlphaValue:0.0];
            [notesView addSubview:timerView positioned:NSWindowAbove relativeTo:nil];
            [NSLayoutConstraint activateConstraints:@[
                [[timerView centerXAnchor] constraintEqualToAnchor:[notesView centerXAnchor]],
                [[notesView bottomAnchor] constraintEqualToAnchor:[timerView bottomAnchor] constant:20.0]]];
        }
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [[button animator] setAlphaValue:1.0];
            if (shouldAddTimer)
                [[timerView animator] setAlphaValue:1.0];
        }];
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor(notesView), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild(button), NSAccessibilityUIElementsKey, nil]);
    } else if ([[SKMainWindowController superclass] instancesRespondToSelector:_cmd]) {
        [super mouseEntered:event];
    }
}

- (void)mouseExited:(NSEvent *)event {
    if ([[event trackingArea] isEqual:[presentationNotesAuxiliary trackingArea]] && [presentationNotesAuxiliary button]) {
        BOOL shouldRemoveTimer = [[presentationNotesAuxiliary timerView] showsTime] == NO;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [[[presentationNotesAuxiliary button] animator] setAlphaValue:0.0];
            if (shouldRemoveTimer)
                [[[presentationNotesAuxiliary timerView] animator] setAlphaValue:0.0];
        } completionHandler:^{
            [[presentationNotesAuxiliary button] removeFromSuperview];
            if (shouldRemoveTimer)
                [[presentationNotesAuxiliary timerView] removeFromSuperview];
        }];
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([self presentationNotesView]), NSAccessibilityLayoutChangedNotification, nil);
    } else if ([[SKMainWindowController superclass] instancesRespondToSelector:_cmd]) {
        [super mouseExited:event];
    }
}

@end
