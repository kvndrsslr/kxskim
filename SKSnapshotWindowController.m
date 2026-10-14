//
//  SKSnapshotWindowController.m
//  Skim
//
//  Created by Michael McCracken on 12/6/06.
/*
 This software is Copyright (c) 2006
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "SKSnapshotWindowController.h"
#import "SKMainWindowController.h"
#import "SKMainDocument.h"
#import <Quartz/Quartz.h>
#import "SKSnapshotPDFView.h"
#import <SkimNotes/SkimNotes.h>
#import "SKSnapshotWindow.h"
#import "SKSnapshotConfiguration.h"
#import "NSWindowController_SKExtensions.h"
#import "SKStringConstants.h"
#import "NSGeometry_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "SKAnimatedBorderlessWindow.h"
#import "NSColor_SKExtensions.h"
#import "NSPasteboard_SKExtensions.h"
#import "NSURL_SKExtensions.h"
#import "NSWindow_SKExtensions.h"
#import "SKApplication.h"
#import "PDFDocument_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSScroller_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSView_SKExtensions.h"

#define SMALL_DELAY 0.1
#define RESIZE_TIME_FACTOR 1.0

NSString * const SKSnapshotCurrentSetupKey = @"currentSetup";

#define PAGE_KEY            @"page"
#define RECT_KEY            @"rect"
#define SCALEFACTOR_KEY     @"scaleFactor"
#define AUTOFITS_KEY        @"autoFits"
#define WINDOWFRAME_KEY     @"windowFrame"
#define HASWINDOW_KEY       @"hasWindow"
#define PAGELABEL_KEY       @"pageLabel"
#define STRING_KEY          @"string"

#define SKSnapshotWindowFrameAutosaveName @"SKSnapshotWindow"
#define SKSnapshotViewChangedNotification @"SKSnapshotViewChangedNotification"

static char SKSnaphotWindowDefaultsObservationContext;

@interface SKSnapshotWindowController ()
@property (nonatomic) BOOL hasWindow;
@end

@implementation SKSnapshotWindowController

@synthesize pdfView, delegate, thumbnail, updateDate, pageLabel, string, hasWindow, forceOnTop;
@dynamic bounds, pageIndex, currentSetup, currentConfiguration, thumbnailAttachment, thumbnail512Attachment, thumbnail256Attachment, thumbnail128Attachment, thumbnail64Attachment, thumbnail32Attachment;

- (NSString *)windowNibName {
    return @"SnapshotWindow";
}

- (void)updateWindowLevel {
    BOOL onTop = forceOnTop || [[NSUserDefaults standardUserDefaults] boolForKey:SKSnapshotsOnTopKey];
    [[self window] setLevel:onTop ? NSFloatingWindowLevel : NSNormalWindowLevel];
    [[self window] setHidesOnDeactivate:onTop];
    [[self window] setCollectionBehavior:(onTop ? (NSWindowCollectionBehaviorManaged | NSWindowCollectionBehaviorFullScreenAuxiliary) : NSWindowCollectionBehaviorFullScreenAuxiliary)];
}

- (void)windowDidLoad {
    [self updateWindowLevel];
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    [sud addObserver:self forKeyPath:SKSnapshotsOnTopKey options:0 context:&SKSnaphotWindowDefaultsObservationContext];
    [sud addObserver:self forKeyPath:SKInterpolationQualityKey options:0 context:&SKSnaphotWindowDefaultsObservationContext];
    // the window is initialially exposed. The windowDidExpose notification is useless, it has nothing to do with showing the window
    [self setHasWindow:YES];
    [pdfView setScaleFactor:1.0];
    [pdfView setAutoScales:NO];
    [pdfView setDisplaysPageBreaks:NO];
    [pdfView setDisplayBox:kPDFDisplayBoxCropBox];
    [pdfView setInterpolationQuality:[[NSUserDefaults standardUserDefaults] integerForKey:SKInterpolationQualityKey]];
    [pdfView setBackgroundColor:[NSColor whiteColor]];
}

// these should never be reached, but just to be sure

- (void)windowDidMiniaturize:(NSNotification *)notification {
    [[self window] orderOut:nil];
    [self setHasWindow:NO];
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
    [self updateWindowLevel];
    [self setHasWindow:YES];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
    if (@available(macOS 11.0, *))
        return displayName;
    else
        return [displayName stringByAppendingEmDashAndString:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [self pageLabel]]];
}

- (void)updateString {
    NSMutableString *mutableString = [NSMutableString string];
    NSRect rect = [pdfView unobscuredContentRect];
    
    for (PDFPage *page in [pdfView displayedPages]) {
        PDFSelection *sel = [page selectionForRect:[pdfView convertRect:rect toPage:page]];
        if ([sel hasCharacters]) {
            if ([mutableString length] > 0)
                [mutableString appendString:@"\n"];
            [mutableString appendString:[sel string]];
        }
    }
    [self willChangeValueForKey:STRING_KEY];
    string = [mutableString copy];
    [self didChangeValueForKey:STRING_KEY];
}

- (void)updatePageLabel {
    [self willChangeValueForKey:PAGELABEL_KEY];
    pageLabel = [[[pdfView currentPage] displayLabel] copy];
    [self didChangeValueForKey:PAGELABEL_KEY];
    if (@available(macOS 11.0, *))
        [[self window] setSubtitle:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [self pageLabel]]];
    else
        [self synchronizeWindowTitleWithDocumentName];
}

- (void)handlePDFViewChanged {
    if ([[self delegate] respondsToSelector:@selector(snapshotControllerDidChange:)]) {
        NSNotification *note = [NSNotification notificationWithName:SKSnapshotViewChangedNotification object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
    }
}

- (void)handlePageChangedNotification:(NSNotification *)notification {
    [self updatePageLabel];
    [self handlePDFViewChanged];
}

- (void)handleDocumentDidUnlockNotification:(NSNotification *)notification {
    [self updatePageLabel];
    [self handlePDFViewChanged];
}

- (void)handlePDFViewFrameChangedNotification:(NSNotification *)notification {
    [self handlePDFViewChanged];
}

- (void)handleViewChangedNotification:(NSNotification *)notification {
    [self updateString];
    if ([[self delegate] respondsToSelector:@selector(snapshotControllerDidChange:)])
        [[self delegate] snapshotControllerDidChange:self];
}

- (void)handleDidAddAnnotationNotification:(NSNotification *)notification {
    PDFPage *page = [[notification userInfo] objectForKey:SKPDFDocumentPageKey];
    if ([self isPageVisible:page]) {
        PDFAnnotation *annotation = [[notification userInfo] objectForKey:SKPDFDocumentAnnotationKey];
        PDFAnnotation *popup = [annotation popup];
        [pdfView addedAnnotation:annotation onPage:page];
        if (popup)
            [pdfView addedAnnotation:popup onPage:page];
    }
}

- (void)handleDidRemoveAnnotationNotification:(NSNotification *)notification {
    PDFPage *page = [[notification userInfo] objectForKey:SKPDFDocumentPageKey];
    if ([self isPageVisible:page]) {
        PDFAnnotation *annotation = [[notification userInfo] objectForKey:SKPDFDocumentAnnotationKey];
        PDFAnnotation *popup = [annotation popup];
        [pdfView removedAnnotation:annotation onPage:page];
        if (popup)
            [pdfView removedAnnotation:popup onPage:page];
    }
}

- (void)handleDidMoveAnnotationNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [notification object];
    PDFPage *oldPage = [[notification userInfo] objectForKey:SKPDFDocumentOldPageKey];
    PDFPage *newPage = [[notification userInfo] objectForKey:SKPDFDocumentPageKey];
    if ([self isPageVisible:oldPage])
        [pdfView removedAnnotation:annotation onPage:oldPage];
    if ([self isPageVisible:newPage])
        [pdfView addedAnnotation:annotation onPage:newPage];
}

- (void)windowWillClose:(NSNotification *)notification {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    @try { [sud removeObserver:self forKeyPath:SKSnapshotsOnTopKey context:&SKSnaphotWindowDefaultsObservationContext]; }
    @catch (id e) {}
    @try { [sud removeObserver:self forKeyPath:SKInterpolationQualityKey context:&SKSnaphotWindowDefaultsObservationContext]; }
    @catch (id e) {}
    if ([[self delegate] respondsToSelector:@selector(snapshotControllerWillClose:)])
        [[self delegate] snapshotControllerWillClose:self];
    [self setDelegate:nil];
}

- (void)windowDidMove:(NSNotification *)notification {
    if ([[self delegate] respondsToSelector:@selector(snapshotControllerDidMove:)])
        [[self delegate] snapshotControllerDidMove:self];
}

- (void)PDFView:(PDFView *)aPDFView goToExternalDestination:(PDFDestination *)destination {
    if ([[self delegate] respondsToSelector:@selector(snapshotController:goToDestination:)])
        [[self delegate] snapshotController:self goToDestination:destination];
}

- (void)goToRect:(NSRect)rect openType:(SKSnapshotOpenType)openType {
    [pdfView goToRect:rect onPage:[pdfView currentPage]];
    [pdfView resetHistory];
    
    [self updateString];
    
    [[self window] makeFirstResponder:pdfView];
	
    [self updatePageLabel];
    [self handlePDFViewChanged];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePageChangedNotification:) 
                                                 name:PDFViewPageChangedNotification object:pdfView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentDidUnlockNotification:) 
                                                 name:PDFDocumentDidUnlockNotification object:[pdfView document]];
    
    NSView *clipView = [[pdfView embeddedScrollView] contentView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePDFViewFrameChangedNotification:) 
                                                 name:NSViewFrameDidChangeNotification object:clipView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePDFViewFrameChangedNotification:) 
                                                 name:NSViewBoundsDidChangeNotification object:clipView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleViewChangedNotification:) 
                                                 name:SKSnapshotViewChangedNotification object:self];
    PDFDocument *pdfDoc = [pdfView document];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidAddAnnotationNotification:)
                                                 name:SKPDFDocumentDidAddAnnotationNotification object:pdfDoc];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidRemoveAnnotationNotification:)
                                                 name:SKPDFDocumentDidRemoveAnnotationNotification object:pdfDoc];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidMoveAnnotationNotification:) 
                                                 name:SKPDFDocumentDidMoveAnnotationNotification object:pdfDoc];
    if ([[self delegate] respondsToSelector:@selector(snapshotController:didFinishSetup:)])
        DISPATCH_MAIN_AFTER_SEC(SMALL_DELAY, ^{
            [[self delegate] snapshotController:self didFinishSetup:openType];
        });
    
    if (openType == SKSnapshotOpenPreview) {
        [[self window] setAlphaValue:0.0];
        [[self window] orderFrontWithoutAnimation];
    } else if ([self hasWindow]) {
        [self showWindow:nil];
    }
}

- (void)loadPdfDocument:(PDFDocument *)pdfDocument {
    [self window];
    [pdfView setDocument:pdfDocument];
}

- (void)goToPage:(PDFPage *)page rect:(NSRect)rect scaleFactor:(CGFloat)factor autoFits:(BOOL)autoFits screen:(NSScreen *)screen openType:(SKSnapshotOpenType)openType {
    NSWindow *window = [self window];
    
    [pdfView setScaleFactor:factor];
    
    NSRect frame = [pdfView convertRect:rect fromPage:page];
    CGFloat scrollerWidth = [NSScroller effectiveScrollerWidth];
    if (scrollerWidth > 0.0) {
        frame.size.width += scrollerWidth;
        frame.size.height += scrollerWidth;
    }
    frame = [pdfView convertRect:frame toView:nil];
    frame = [NSWindow frameRectForContentRect:frame styleMask:[window styleMask] & ~NSWindowStyleMaskFullSizeContentView];
    
    if (openType == SKSnapshotOpenNormal) {
        [self setWindowFrameAutosaveNameOrCascade:SKSnapshotWindowFrameAutosaveName];
        frame.origin = SKTopLeftPoint([window frame]);
        frame.origin.y -= NSHeight(frame);
    } else if (openType == SKSnapshotOpenFromSetup) {
        frame.origin = SKTopLeftPoint([window frame]);
        frame.origin.y -= NSHeight(frame);
        [self setShouldCascadeWindows:NO];
        [window setFrameAutosaveName:SKSnapshotWindowFrameAutosaveName];
    } else if (openType == SKSnapshotOpenPreview) {
        [pdfView setDisplayMode:kPDFDisplaySinglePage];
        frame = SKConstrainRect(SKRectFromCenterAndSize(SKCenterPoint([screen frame]), frame.size), [screen visibleFrame]);
        [(SKSnapshotWindow *)[self window] setWindowControllerMiniaturizesWindow:NO];
    }
    
    [window setFrame:NSIntegralRect(frame) display:NO animate:NO];
    [pdfView goAndScrollToPage:page];
    
    if (autoFits) {
        [pdfView setAutoFits:autoFits];
        if (openType == SKSnapshotOpenPreview)
            [pdfView setShouldAutoFit:NO];
    }
    
    // Delayed to allow PDFView to finish its bookkeeping 
    // fixes bug of apparently ignoring the point but getting the page right.
    if (openType == SKSnapshotOpenPreview) {
        [self goToRect:rect openType:openType];
    } else {
        DISPATCH_MAIN_AFTER_SEC(SMALL_DELAY, ^{
            [self goToRect:rect openType:openType];
        });
    }
}

- (void)displayPage:(PDFPage *)page rect:(NSRect)rect scaleFactor:(CGFloat)factor autoFits:(BOOL)autoFits {
    [self goToPage:page
              rect:rect
       scaleFactor:factor
          autoFits:autoFits
            screen:nil
          openType:SKSnapshotOpenNormal];
}

- (void)displayPage:(PDFPage *)page previewOnScreen:(NSScreen *)screen {
    [self goToPage:page
              rect:[page boundsForBox:kPDFDisplayBoxCropBox]
       scaleFactor:1.0
          autoFits:YES
            screen:screen
          openType:SKSnapshotOpenPreview];
}

- (void)displaySetup:(NSDictionary *)setup {
    [self goToPage:[[pdfView document] pageAtIndex:[[setup objectForKey:PAGE_KEY] unsignedIntegerValue]]
              rect:NSRectFromString([setup objectForKey:RECT_KEY])
       scaleFactor:[[setup objectForKey:SCALEFACTOR_KEY] doubleValue]
          autoFits:[[setup objectForKey:AUTOFITS_KEY] boolValue]
            screen:nil
          openType:SKSnapshotOpenFromSetup];
    
    [self setHasWindow:[[setup objectForKey:HASWINDOW_KEY] boolValue]];
    if ([setup objectForKey:WINDOWFRAME_KEY])
        [[self window] setFrame:NSRectFromString([setup objectForKey:WINDOWFRAME_KEY]) display:NO];
}

- (BOOL)isPageVisible:(PDFPage *)page {
    return [[page document] isEqual:[pdfView document]] && [pdfView isPageAtIndexDisplayed:[page pageIndex]];
}

- (BOOL)isPageInIndexesVisible:(NSIndexSet *)pageIndexes {
    return [pdfView isPageAtIndexesDisplayed:pageIndexes];
}

#pragma mark Acessors

- (NSRect)bounds {
    return [pdfView convertRect:[pdfView unobscuredContentRect] toPage:[pdfView currentPage]];
}

- (NSUInteger)pageIndex {
    return [[pdfView currentPage] pageIndex];
}

- (void)setThumbnail:(NSImage *)newThumbnail {
    if (newThumbnail != thumbnail) {
        thumbnail = newThumbnail;
        [thumbnail setAccessibilityDescription:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [self pageLabel]]];
    }
}

- (void)setForceOnTop:(BOOL)flag {
    forceOnTop = flag;
    if ([[self window] isVisible])
        [self updateWindowLevel];
}

- (NSDictionary *)currentSetup {
    return @{PAGE_KEY:[NSNumber numberWithUnsignedInteger:[self pageIndex]], RECT_KEY:NSStringFromRect([self bounds]), SCALEFACTOR_KEY:[NSNumber numberWithDouble:[pdfView scaleFactor]], AUTOFITS_KEY:[NSNumber numberWithBool:[pdfView autoFits]], HASWINDOW_KEY:[NSNumber numberWithBool:[[self window] isVisible]], WINDOWFRAME_KEY:NSStringFromRect([[self window] frame])};
}

- (SKSnapshotConfiguration *)currentConfiguration {
    return [[SKSnapshotConfiguration alloc] initWithPDFView:pdfView];
}

#pragma mark Actions

- (IBAction)doGoToNextPage:(id)sender {
    [pdfView goToNextPage:sender];
}

- (IBAction)doGoToPreviousPage:(id)sender {
    [pdfView goToPreviousPage:sender];
}

- (IBAction)doGoToFirstPage:(id)sender {
    [pdfView goToFirstPage:sender];
}

- (IBAction)doGoToLastPage:(id)sender {
    [pdfView goToLastPage:sender];
}

- (IBAction)doGoBack:(id)sender {
    [pdfView goBack:sender];
}

- (IBAction)doGoForward:(id)sender {
    [pdfView goForward:sender];
}

- (IBAction)doZoomIn:(id)sender {
    [pdfView zoomIn:sender];
}

- (IBAction)doZoomOut:(id)sender {
    [pdfView zoomOut:sender];
}

- (IBAction)doZoomToPhysicalSize:(id)sender {
    [pdfView setPhysicalScaleFactor:1.0];
}

- (IBAction)doZoomToActualSize:(id)sender {
    [pdfView setScaleFactor:1.0];
}

- (IBAction)toggleAutoScale:(id)sender {
    [pdfView setAutoFits:[pdfView autoFits] == NO];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(doGoToNextPage:)) {
        return [pdfView canGoToNextPage];
    } else if (action == @selector(doGoToPreviousPage:)) {
        return [pdfView canGoToPreviousPage];
    } else if (action == @selector(doGoToFirstPage:)) {
        return [pdfView canGoToFirstPage];
    } else if (action == @selector(doGoToLastPage:)) {
        return [pdfView canGoToLastPage];
    } else if (action == @selector(doGoBack:)) {
        return [pdfView canGoBack];
    } else if (action == @selector(doGoForward:)) {
        return [pdfView canGoForward];
    } else if (action == @selector(doZoomIn:)) {
        return [pdfView canZoomIn];
    } else if (action == @selector(doZoomOut:)) {
        return [pdfView canZoomOut];
    } else if (action == @selector(doZoomToActualSize:)) {
        return fabs([pdfView scaleFactor] - 1.0) > 0.0;
    } else if (action == @selector(doZoomToPhysicalSize:)) {
        return fabs([pdfView physicalScaleFactor] - 1.0) > 0.001;
    } else if (action == @selector(toggleAutoScale:)) {
        [menuItem setState:[pdfView autoFits] ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    }
    return YES;
}

#pragma mark Thumbnails

- (NSAttributedString *)thumbnailAttachmentWithSize:(CGFloat)size {
    SKSnapshotConfiguration *configuration = [self currentConfiguration];
    NSBitmapImageRep *imageRep1 = [configuration bitmapImageRepWithSize:size scale:1.0];
    NSBitmapImageRep *imageRep2 = [configuration bitmapImageRepWithSize:size scale:2.0];
    NSData *data = [NSBitmapImageRep TIFFRepresentationOfImageRepsInArray:@[imageRep1, imageRep2]];
    
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents:data];
    NSString *filename = [NSString stringWithFormat:@"snapshot_page_%lu.tiff",(unsigned long)( [self pageIndex] + 1)];
    [wrapper setFilename:filename];
    [wrapper setPreferredFilename:filename];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
    NSAttributedString *attrString = [NSAttributedString attributedStringWithAttachment:attachment];
    
    return attrString;
}

- (NSAttributedString *)thumbnailAttachment {
    return [self thumbnailAttachmentWithSize:0.0];
}

- (NSAttributedString *)thumbnail512Attachment {
    return [self thumbnailAttachmentWithSize:512.0];
}

- (NSAttributedString *)thumbnail256Attachment {
    return [self thumbnailAttachmentWithSize:256.0];
}

- (NSAttributedString *)thumbnail128Attachment {
    return [self thumbnailAttachmentWithSize:128.0];
}

- (NSAttributedString *)thumbnail64Attachment {
    return [self thumbnailAttachmentWithSize:64.0];
}

- (NSAttributedString *)thumbnail32Attachment {
    return [self thumbnailAttachmentWithSize:32.0];
}

#pragma mark Miniaturize / Deminiaturize

- (NSRect)miniaturizedRectForDockingRect:(NSRect)dockRect {
    NSRect sourceRect = [pdfView convertRect:[pdfView unobscuredContentRect] toView:nil];
    NSRect targetRect;
    NSSize windowSize = [[self window] frame].size;
    NSSize thumbSize = [thumbnail size];
    CGFloat thumbRatio = thumbSize.height / thumbSize.width;
    CGFloat dockRatio = NSHeight(dockRect) / NSWidth(dockRect);
    CGFloat scaleFactor;
    CGFloat scale = round([[[thumbnail representations] firstObject] pixelsHigh] / thumbSize.height);
    CGFloat shadowRadius = round(scale * fmax(thumbSize.width, thumbSize.height) / 32.0) / scale;
    CGFloat shadowOffset = ceil(0.75 * scale * shadowRadius) / scale;
    
    if (thumbRatio > dockRatio) {
        targetRect = NSInsetRect(dockRect, 0.5 * NSWidth(dockRect) * (1.0 - dockRatio / thumbRatio), 0.0);
        scaleFactor = NSHeight(targetRect) / thumbSize.height;
    } else {
        targetRect = NSInsetRect(dockRect, 0.0, 0.5 * NSHeight(dockRect) * (1.0 - thumbRatio / dockRatio));
        scaleFactor = NSWidth(targetRect) / thumbSize.width;
    }
    shadowRadius *= scaleFactor;
    shadowOffset *= scaleFactor;
    targetRect = NSOffsetRect(NSInsetRect(targetRect, shadowRadius, shadowRadius), 0.0, shadowOffset);
    scaleFactor = thumbRatio > dockRatio ? NSHeight(targetRect) / NSHeight(sourceRect) : NSWidth(targetRect) / NSWidth(sourceRect);
    
    return NSMakeRect(NSMinX(targetRect) - scaleFactor * NSMinX(sourceRect), NSMinY(targetRect) - scaleFactor * NSMinY(sourceRect), scaleFactor * windowSize.width, scaleFactor * windowSize.height);
}

- (NSImage *)contentImage {
    NSRect rect = [pdfView unobscuredContentRect];
    NSRect bounds = [[self window] frame];
    bounds.origin = NSZeroPoint;
    NSImage *image = [[NSImage alloc] initWithSize:bounds.size];
    NSBitmapImageRep *imageRep = [[[[self window] contentView] superview] bitmapImageRepForCachingDisplayInRect:bounds];
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    [[NSBezierPath bezierPathWithRoundedRect:bounds xRadius:10.0 yRadius:10.0] addClip];
    [[NSColor whiteColor] set];
    NSRectFill(rect);
    
    [[NSBezierPath bezierPathWithRect:rect] addClip];
    
    CGContextRef context = [nsContext CGContext];
    PDFDisplayBox *box = [pdfView displayBox];
    CGFloat scale = [pdfView scaleFactor];
    
    CGContextSetInterpolationQuality(context, [pdfView interpolationQuality] + 1);
    for (PDFPage *page in [pdfView visiblePages]) {
        NSRect pageRect = [pdfView convertRect:[page boundsForBox:box] fromPage:page];
        if (NSIntersectsRect(pageRect, bounds)) {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, NSMinX(pageRect), NSMinY(pageRect));
            CGContextScaleCTM(context, scale, scale);
            [page drawWithBox:box toContext:context];
            CGContextRestoreGState(context);
        }
    }
    
    [NSGraphicsContext restoreGraphicsState];
    
    [image addRepresentation:imageRep];
    
    return image;
}

static void roundCornersAndApplyFiltersToImageRep(NSBitmapImageRep *imageRep, NSArray *filters, NSRect rect) {
    NSRect bounds = {NSZeroPoint, [imageRep size]};
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:10.0 yRadius:10.0];
    [path appendBezierPathWithRect:bounds];
    [path setWindingRule:NSEvenOddWindingRule];
    
    CIImage *image = nil;
    NSRect scaledRect = rect;
    if ([filters count]) {
        CGFloat scale = [imageRep pixelsWide] / [imageRep size].width;
        scaledRect = NSMakeRect(scale * NSMinX(rect), scale * NSMinY(rect), scale * NSWidth(rect), scale * NSHeight(rect));
        image = [[CIImage alloc] initWithBitmapImageRep:imageRep];
        for (CIFilter *filter in filters) {
            [filter setValue:image forKey:kCIInputImageKey];
            image = [filter outputImage];
        }
    }
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep]];
    [image drawInRect:rect fromRect:scaledRect operation:NSCompositingOperationCopy fraction:1.0];
    [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationClear];
    [path fill];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)miniaturizeWindow:(BOOL)miniaturize {
    if (animating)
        return;
    if ([[self delegate] respondsToSelector:@selector(snapshotController:miniaturizedRect:)]) {
        NSWindow *window = [self window];
        NSArray *filters = SKColorEffectFilters();
        NSImage *contentImage = [self contentImage];
        NSImage *windowImage;
        NSRect windowRect = [window frame];
        NSRect dockRect = [[self delegate] snapshotController:self miniaturizedRect:miniaturize];
        dockRect = [self miniaturizedRectForDockingRect:dockRect];
        windowImage = [[NSImage alloc] initWithSize:windowRect.size];
        NSBitmapImageRep *imageRep = [[[window contentView] superview] bitmapImageRepCachingDisplay];
        if (imageRep) {
            roundCornersAndApplyFiltersToImageRep(imageRep, filters, [window contentLayoutRect]);
            [windowImage addRepresentation:imageRep];
        }
        
        SKAnimatedBorderlessWindow *miniaturizeWindow = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:miniaturize ? windowRect : dockRect];
        [miniaturizeWindow setLevel:NSFloatingWindowLevel];
        [miniaturizeWindow setHasShadow:YES];
        [[miniaturizeWindow contentView] setWantsLayer:YES];
        NSImageView *imageView = [miniaturizeWindow addImageViewWithImage:windowImage];
        NSImageView *contentImageView = [miniaturizeWindow addImageViewWithImage:contentImage];
        [contentImageView setContentFilters:filters];
        if (miniaturize == NO)
            [imageView setAlphaValue:0.0];
        
        [miniaturizeWindow orderFront:nil];
        
        if (miniaturize) {
            [window orderOutWithoutAnimation];
        }
        
        animating = YES;
        
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [context setDuration:RESIZE_TIME_FACTOR * [miniaturizeWindow animationResizeTime:miniaturize ? dockRect : windowRect]];
                [[miniaturizeWindow animator] setFrame:miniaturize ? dockRect : windowRect display:YES];
                [[imageView animator] setAlphaValue:miniaturize ? 0.0 : 1.0];
            }
            completionHandler:^{
                if (miniaturize == NO) {
                    [window orderFrontWithoutAnimation];
                    [self updateWindowLevel];
                }
                [miniaturizeWindow orderOut:nil];
                animating = NO;
        }];
    } else if (miniaturize) {
        [[self window] orderOut:nil];
    } else {
        [[self window] orderFront:nil];
    }
    [self setHasWindow:miniaturize == NO];
}

- (void)miniaturize {
    [self miniaturizeWindow:YES];
}

- (void)deminiaturize {
    [self miniaturizeWindow:NO];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKSnaphotWindowDefaultsObservationContext) {
        if ([keyPath isEqualToString:SKSnapshotsOnTopKey]) {
            if ([[self window] isVisible])
                [self updateWindowLevel];
        } else if ([keyPath isEqualToString:SKInterpolationQualityKey]) {
            [pdfView setInterpolationQuality:[[NSUserDefaults standardUserDefaults] integerForKey:SKInterpolationQualityKey]];
            [pdfView setNeedsDisplay:YES];
            if ([[self delegate] respondsToSelector:@selector(snapshotControllerDidChange:)])
                [[self delegate] snapshotControllerDidChange:self];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark NSFilePromiseProviderDelegate protocol

- (NSString *)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider fileNameForType:(NSString *)fileType {
    PDFPage *page = [[[self pdfView] document] pageAtIndex:[self pageIndex]];
    NSString *filename = [([[[self document] displayName] stringByDeletingPathExtension] ?: @"PDF") stringByAppendingDashAndString:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [page displayLabel]]];
    return [filename stringByAppendingPathExtension:@"tiff"];
}

- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider writePromiseToURL:(NSURL *)fileURL completionHandler:(void (^)(NSError *))completionHandler {
    SKSnapshotConfiguration *configuration = [self currentConfiguration];
    NSBitmapImageRep *imageRep1 = [configuration bitmapImageRepWithSize:0.0 scale:1.0];
    NSBitmapImageRep *imageRep2 = [configuration bitmapImageRepWithSize:0.0 scale:2.0];
    NSData *data = [NSBitmapImageRep TIFFRepresentationOfImageRepsInArray:@[imageRep1, imageRep2]];
    NSError *error = nil;
    [data writeToURL:fileURL options:NSDataWritingAtomic error:&error];
    completionHandler(error);
}

@end
