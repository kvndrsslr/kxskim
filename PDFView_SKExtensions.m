//
//  PDFView_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 7/3/11.
/*
 This software is Copyright (c) 2011
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

#import "PDFView_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import "SKMainDocument.h"
#import "SKPDFSynchronizer.h"
#import "PDFPage_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKStringConstants.h"
#import "NSGraphics_SKExtensions.h"
#import "SKApplication.h"
#import "NSView_SKExtensions.h"
#import "NSImage_SKExtensions.h"

const NSPoint SKUnspecifiedPoint = (NSPoint){FLT_MAX, FLT_MAX};

#define PAGE_BREAK_MARGIN 4.0

@implementation PDFView (SKExtensions)

static inline CGFloat physicalScaleFactorForView(NSView *view) {
    NSScreen *screen = [[view window] screen];
    NSDictionary *deviceDescription = [screen deviceDescription];
	CGDirectDisplayID displayID = (CGDirectDisplayID)[[deviceDescription objectForKey:@"NSScreenNumber"] unsignedIntValue];
	CGSize physicalSize = CGDisplayScreenSize(displayID);
    NSSize resolution = [[deviceDescription objectForKey:NSDeviceResolution] sizeValue];
    CGFloat backingScaleFactor = [screen backingScaleFactor];
	return CGSizeEqualToSize(physicalSize, CGSizeZero) ? 1.0 : (physicalSize.width * resolution.width) / (CGDisplayPixelsWide(displayID) * backingScaleFactor * 25.4f);
}

- (CGFloat)physicalScaleFactor {
    return [self scaleFactor] * physicalScaleFactorForView(self);
}

- (void)setPhysicalScaleFactor:(CGFloat)scale {
    [self setScaleFactor:scale / physicalScaleFactorForView(self)];
}

- (NSScrollView *)embeddedScrollView {
    // don't go through the documentView, because that may not exist,
    // e.g. in init or when the document is locked
    // also when -documentView is called from -initWithCoder: it may crash
    return [self descendantOfClass:[NSScrollView class]];
}

- (void)doPdfsyncWithEvent:(NSEvent *)theEvent {
    // eat up mouseDragged/mouseUp events, so we won't get their event handlers
    while (YES) {
        if ([[[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged] type] == NSEventTypeLeftMouseUp)
            break;
    }
    
    SKMainDocument *document = (SKMainDocument *)[[[self window] windowController] document];
    
    if ([document respondsToSelector:@selector(synchronizer)]) {
        
        NSPoint location = NSZeroPoint;
        PDFPage *page = [self pageAndPoint:&location forEvent:theEvent nearest:YES];
        NSUInteger pageIndex = [page pageIndex];
        PDFSelection *sel = [page selectionForLineAtPoint:location];
        NSRect rect = [sel hasCharacters] ? [sel boundsForPage:page] : NSMakeRect(location.x - 20.0, location.y - 5.0, 40.0, 10.0);
        
        [[document synchronizer] findFileAndLineForLocation:location inRect:rect pageBounds:[page boundsForBox:kPDFDisplayBoxMediaBox] atPageIndex:pageIndex];
    }
}

- (void)doDragContentWithEvent:(NSEvent *)theEvent {
    NSScrollView *scrollView = [self embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSPoint startLocation = [clipView convertPoint:[theEvent locationInWindow] fromView:nil];
	
    [[NSCursor closedHandCursor] push];
    
	while (YES) {
        
		theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
        if ([theEvent type] == NSEventTypeLeftMouseUp)
            break;
        
        // convert takes flipping and scaling into account
        NSPoint	newLocation = [clipView convertPoint:[theEvent locationInWindow] fromView:nil];
        NSRect bounds = [clipView bounds];
        bounds.origin = SKAddPoints(bounds.origin, SKSubstractPoints(startLocation, newLocation));
        bounds = [clipView constrainBoundsRect:bounds];
        
        [clipView scrollToPoint:bounds.origin];
        [scrollView reflectScrolledClipView:clipView];
	}
    
    [NSCursor pop];
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
}

#pragma mark NSDraggingSource protocol

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return context == NSDraggingContextWithinApplication ? NSDragOperationNone : NSDragOperationCopy;
}

- (BOOL)doDragSelectedTextWithEvent:(NSEvent *)theEvent {
    if ([[self currentSelection] hasCharacters] == NO)
        return NO;
    
    NSPoint point;
    PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:NO];
    
    if (page == nil || NSPointInRect(point, [[self currentSelection] boundsForPage:page]) == NO || [NSApp willDragMouse] == NO)
        return NO;
    
    NSImage *dragImage = [NSImage bitmapImageWithSize:NSMakeSize(32.0, 32.0) forView:self drawingHandler:^(NSRect rect){
        [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kClippingTextType)] drawInRect:rect fromRect:rect operation:NSCompositingOperationCopy fraction:1.0 respectFlipped:YES hints:nil];
    }];
    
    NSRect dragFrame = SKRectFromCenterAndSize([self convertPoint:[theEvent locationInWindow] fromView:nil], [dragImage size]);
    
    NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:[[self currentSelection] attributedString]];
    [dragItem setDraggingFrame:dragFrame contents:dragImage];
    [self beginDraggingSessionWithItems:@[dragItem] event:theEvent source:self];

    return YES;
}

- (PDFPage *)pageAndPoint:(NSPoint *)point forEvent:(NSEvent *)event nearest:(BOOL)nearest {
    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    PDFPage *page = [self pageForPoint:p nearest:nearest];
    if (page && point)
        *point = [self convertPoint:p toPage:page];
    return page;
}

- (SKDestination)currentSKDestination:(BOOL)invalidatePointWhenRotated {
    PDFPage *page = [self currentPage];
    NSPoint point = SKUnspecifiedPoint;
    if ([[page document] isLocked] == NO && (invalidatePointWhenRotated == NO || [page rotation] == [page intrinsicRotation])) {
        // don't use currentDestination, as that always gives the top-left of the page in non-continuous mode, rather than the visible area
        point = SKTopLeftPoint([self bounds]);
        point.y -= [[self embeddedScrollView] contentInsets].top;
        point = [self convertPoint:point toPage:page];
    }
    return (SKDestination){[page pageIndex], point};
}

// the horizontal origin that aligns the leading edge of a page with the leading content inset, the
// way the vertical scrolling aligns its top edge with the top content inset; it is clamped to the
// scrollable document range, and keeps the current origin when the document fits the clip view
- (CGFloat)horizontalScrollOriginForPage:(PDFPage *)page {
    NSScrollView *scrollView = [self embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    if (NSWidth(docRect) <= NSWidth(bounds))
        return bounds.origin.x;
    NSRect pageRect = [self convertRect:[self convertRect:[page boundsForBox:[self displayBox]] fromPage:page] toView:clipView];
    CGFloat inset = [clipView contentInsets].left;
    CGFloat margin = 0.0;
    if ([self displaysPageBreaks])
        margin = [self pageBreakMargins].left;
    return fmin(fmax(NSMinX(pageRect) - margin - inset, NSMinX(docRect) - inset), NSMaxX(docRect) - NSWidth(bounds));
}

- (void)goToSKDestination:(SKDestination)dest {
    PDFPage *page = [[self document] pageAtIndex:dest.pageIndex];
    if (NSEqualPoints(dest.point, SKUnspecifiedPoint)) {
        [self goAndScrollToPage:page];
    } else {
        PDFDestination *destination = [[PDFDestination alloc] initWithPage:page atPoint:dest.point];
        [self goToDestination:destination];
        if (@available(macOS 12.0, *)) {
            NSScrollView *scrollView = [self embeddedScrollView];
            NSClipView *clipView = [scrollView contentView];
            NSRect bounds = [clipView bounds];
            NSPoint origin = bounds.origin;
            bounds.origin = [self convertPoint:[self convertPoint:dest.point fromPage:page] toView:clipView];
            if ([clipView isFlipped])
                bounds.origin.y -= [clipView contentInsets].top;
            else
                bounds.origin.y -= NSHeight(bounds) - [clipView contentInsets].top;
            if ([self displayMode] == kPDFDisplaySinglePageContinuous && [self displayDirection] == kPDFDisplayDirectionHorizontal)
                bounds.origin.x = [self horizontalScrollOriginForPage:page];
            bounds = [clipView constrainBoundsRect:bounds];
            if (NSEqualPoints(bounds.origin, origin) == NO) {
                [clipView scrollToPoint:bounds.origin];
                [scrollView reflectScrolledClipView:clipView];
            }
        }
    }
}

- (void)goAndScrollToPage:(PDFPage *)page {
    [self goToPage:page];
}

- (NSRange)displayedPageIndexRange {
    NSUInteger pageCount = [[self document] pageCount];
    PDFDisplayMode displayMode = [self displayMode];
    NSRange range = NSMakeRange(0, pageCount);
    if (pageCount > 0 && (displayMode & kPDFDisplaySinglePageContinuous) == 0) {
        range = NSMakeRange([[self currentPage] pageIndex], 1);
        if (displayMode == kPDFDisplayTwoUp) {
            if ([self displaysAsBook] == (BOOL)(range.location % 2)) {
                if (NSMaxRange(range) < pageCount)
                    range.length = 2;
            } else if (range.location > 0) {
                range.location -= 1;
                range.length = 2;
            }
        }
    }
    return range;
}

- (BOOL)isPageAtIndexDisplayed:(NSUInteger)pageIndex {
    return NSLocationInRange(pageIndex, [self displayedPageIndexRange]);
}

- (BOOL)isPageAtIndexesDisplayed:(NSIndexSet *)pageIndexes {
    return [pageIndexes intersectsIndexesInRange:[self displayedPageIndexRange]];
}

- (NSArray *)displayedPages {
    NSMutableArray *displayedPages = [NSMutableArray array];
    PDFDocument *pdfDoc = [self document];
    NSRange range = [self displayedPageIndexRange];
    NSUInteger i;
    for (i = range.location; i < NSMaxRange(range); i++)
        [displayedPages addObject:[pdfDoc pageAtIndex:i]];
    return displayedPages;
}

- (NSRect)unobscuredContentRect {
    NSScrollView *scrollView = [self embeddedScrollView];
    NSView *clipView = [scrollView contentView];
    NSRect rect = [self convertRect:[clipView bounds] fromView:clipView];
    rect.size.height -= [scrollView contentInsets].top;
    return rect;
}

- (NSRect)boundsIncludingMarginsForPage:(PDFPage *)page {
    NSRect pageRect = [page boundsForBox:[self displayBox]];
    if ([self displaysPageBreaks]) {
        NSEdgeInsets margins = [self pageBreakMargins];
        switch ([page rotation]) {
            case 0:
                pageRect = NSInsetRect(pageRect, -margins.left, -margins.bottom);
                pageRect.size.width += margins.right - margins.left;
                pageRect.size.height += margins.top - margins.bottom;
                break;
            case 90:
                pageRect = NSInsetRect(pageRect, -margins.top, -margins.left);
                pageRect.size.width += margins.bottom - margins.top;
                pageRect.size.height += margins.right - margins.left;
                break;
            case 180:
                pageRect = NSInsetRect(pageRect, -margins.right, -margins.top);
                pageRect.size.width += margins.left - margins.right;
                pageRect.size.height += margins.bottom - margins.top;
                break;
            case 270:
                pageRect = NSInsetRect(pageRect, -margins.bottom, -margins.right);
                pageRect.size.width += margins.top - margins.bottom;
                pageRect.size.height += margins.left - margins.right;
                break;
        }
    }
    return pageRect;
}

- (void)setCursorForMouse:(NSEvent *)theEvent {
    if (theEvent == nil)
        theEvent = [NSEvent mouseEventWithType:NSEventTypeMouseMoved
                                      location:[[self window] mouseLocationOutsideOfEventStream]
                                 modifierFlags:[NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask
                                     timestamp:0
                                  windowNumber:[[self window] windowNumber]
                                       context:nil
                                   eventNumber:0
                                    clickCount:1
                                      pressure:0.0];
    [self setCursorForAreaOfInterest:[self areaOfInterestForMouse:theEvent]];
}

static NSColor *defaultBackgroundColor(NSString *backgroundColorKey, NSString *darkBackgroundColorKey) {
    NSColor *color = nil;
    if (SKHasDarkAppearance())
        color = [[NSUserDefaults standardUserDefaults] colorForKey:darkBackgroundColorKey];
    if (color == nil)
        color = [[NSUserDefaults standardUserDefaults] colorForKey:backgroundColorKey];
    return color;
}

+ (NSColor *)defaultBackgroundColor {
    return defaultBackgroundColor(SKBackgroundColorKey, SKDarkBackgroundColorKey);
}

+ (NSColor *)defaultFullScreenBackgroundColor {
    return defaultBackgroundColor(SKFullScreenBackgroundColorKey, SKDarkFullScreenBackgroundColorKey) ?: defaultBackgroundColor(SKBackgroundColorKey, SKDarkBackgroundColorKey);
}

- (BOOL)accessibilityPerformShowMenu {
    NSRect rect = [self unobscuredContentRect];
    NSPoint point = NSMakePoint(NSMidX(rect), floor(NSMinY(rect) + 0.75 * NSHeight(rect)));
    NSEvent *event = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown
                                        location:[self convertPoint:point toView:nil]
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:[[self window] windowNumber]
                                         context:nil
                                     eventNumber:0
                                      clickCount:1
                                        pressure:0.0];
    NSMenu *menu = [self menuForEvent:event];
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
    return YES;
}

@end
