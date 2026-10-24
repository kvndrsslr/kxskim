//
//  SKPDFView.m
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

#import "SKPDFView.h"
#import "SKImageToolTipWindow.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKNPDFAnnotationNote_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSCursor_SKExtensions.h"
#import "SKApplication.h"
#import "SKStringConstants.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKReadingBar.h"
#import "SKTextNoteEditor.h"
#import "SKSyncDot.h"
#import "SKLineInspector.h"
#import "SKLineWell.h"
#import "SKTypeSelectHelper.h"
#import "NSDocument_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "NSBezierPath_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import "PDFDocumentView_SKExtensions.h"
#import "NSWindow_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "NSScroller_SKExtensions.h"
#import "SKColorMenuView.h"
#import "NSObject_SKExtensions.h"
#import "SKLoupeController.h"
#import "PDFDestination_SKExtensions.h"

#define ANNOTATION_MODE_COUNT 9
#define TOOL_MODE_COUNT 5

#define IS_MARKUP(noteType) (noteType == SKNoteTypeHighlight || noteType == SKNoteTypeUnderline || noteType == SKNoteTypeStrikeOut)
#define IS_MARKUP_TOOL(tempToolMode) (tempToolMode == SKToolModeHighlight || tempToolMode == SKToolModeUnderline || tempToolMode == SKToolModeStrikeOut)
#define IS_TEXT_OR_NOTE_TOOL (toolMode == SKToolModeText || toolMode == SKToolModeNote)

#define NOTE_TYPE_FROM_TEMP_TOOL_MODE(tempToolMode) (SKNoteType)(tempToolMode - SKToolModeFreeText)
#define TEMP_TOOL_MODE_FROM_NOTE_TYPE(noteType) (SKTemporaryToolMode)(noteType + SKToolModeFreeText)

#define READINGBAR_RESIZE_EDGE_HEIGHT 3.0

#define TEXT_SELECT_MARGIN_SIZE ((NSSize){80.0, 100.0})

#define TOOLTIP_OFFSET_FRACTION 0.3

#define DEFAULT_SNAPSHOT_HEIGHT 200.0

#define MIN_NOTE_SIZE 8.0

#define HANDLE_SIZE 4.0

#define DEFAULT_MAGNIFICATION 2.5
#define SMALL_MAGNIFICATION   1.5
#define LARGE_MAGNIFICATION   4.0

// based on: reading speed: 240 words/min
// layout: 10 words/line, 40 line/page, 600 points/page
#define DEFAULT_PACER_SPEED 6.0
#define PACER_LINE_HEIGHT 15.0

NSNotificationName const SKPDFViewDisplaysAsBookChangedNotification = @"SKPDFViewDisplaysAsBookChangedNotification";
NSNotificationName const SKPDFViewDisplaysPageBreaksChangedNotification = @"SKPDFViewDisplaysPageBreaksChangedNotification";
NSNotificationName const SKPDFViewDisplayDirectionChangedNotification = @"SKPDFViewDisplayDirectionChangedNotification";
NSNotificationName const SKPDFViewDisplaysRTLChangedNotification = @"SKPDFViewDisplaysRTLChangedNotification";
NSNotificationName const SKPDFViewAutoScalesChangedNotification = @"SKPDFViewAutoScalesChangedNotification";
NSNotificationName const SKPDFViewToolModeChangedNotification = @"SKPDFViewToolModeChangedNotification";
NSNotificationName const SKPDFViewTemporaryToolModeChangedNotification = @"SKPDFViewTemporaryToolModeChangedNotification";
NSNotificationName const SKPDFViewAnnotationModeChangedNotification = @"SKPDFViewAnnotationModeChangedNotification";
NSNotificationName const SKPDFViewCurrentAnnotationChangedNotification = @"SKPDFViewCurrentAnnotationChangedNotification";
NSNotificationName const SKPDFViewReadingBarDidChangeNotification = @"SKPDFViewReadingBarDidChangeNotification";
NSNotificationName const SKPDFViewSelectionChangedNotification = @"SKPDFViewSelectionChangedNotification";
NSNotificationName const SKPDFViewMagnificationChangedNotification = @"SKPDFViewMagnificationChangedNotification";
NSNotificationName const SKPDFViewPacerStartedOrStoppedNotification = @"SKPDFViewPacerStartedOrStoppedNotification";
NSNotificationName const SKPDFViewCanSelectNoteDidChangeNotification = @"SKPDFViewCanSelectNoteDidChangeNotification";
NSNotificationName const SKPDFViewPaddingChangedNotification = @"SKPDFViewPaddingChangedNotification";

NSString * const SKPDFViewAnnotationKey = @"annotation";
NSString * const SKPDFViewPageKey = @"page";

#define SKMoveReadingBarModifiersKey @"SKMoveReadingBarModifiers"
#define SKResizeReadingBarModifiersKey @"SKResizeReadingBarModifiers"
#define SKUseToolModeCursorsKey @"SKUseToolModeCursors"
#define SKMagnifyWithMousePressedKey @"SKMagnifyWithMousePressed"
#define SKPacerSpeedKey @"SKPacerSpeed"

#define SKAnnotationKey @"SKAnnotation"

#define SCALEFACTOR_KEY             @"scaleFactor"
#define AUTOSCALES_KEY              @"autoScales"
#define DISPLAYSPAGEBREAKS_KEY      @"displaysPageBreaks"
#define DISPLAYSASBOOK_KEY          @"displaysAsBook"
#define DISPLAYMODE_KEY             @"displayMode"
#define DISPLAYDIRECTION_KEY        @"displayDirection"
#define DISPLAYSRTL_KEY             @"displaysRTL"
#define DISPLAYBOX_KEY              @"displayBox"
#define PADDINGTOP_KEY              @"paddingTop"
#define PADDINGLEFT_KEY             @"paddingLeft"
#define PADDINGBOTTOM_KEY           @"paddingBottom"
#define PADDINGRIGHT_KEY            @"paddingRight"
#define PAGEGAP_KEY                 @"pageGap"

static char SKPDFViewDefaultsObservationContext;
static char SKPDFViewScrollBoundsObservationContext;

static NSUInteger moveReadingBarModifiers = NSEventModifierFlagCommand;
static NSUInteger resizeReadingBarModifiers = NSEventModifierFlagCommand | NSEventModifierFlagShift;

static BOOL useToolModeCursors = NO;

static inline PDFAreaOfInterest SKAreaOfInterestForResizeHandle(SKRectEdges mask, PDFPage *page);

static inline NSSize SKFitTextNoteSize(NSString *string, NSFont *font, CGFloat width);

static inline NSEdgeInsets SKPaddingFromSettings(NSDictionary *settings, NSEdgeInsets padding) {
    NSNumber *number;
    if ((number = [settings objectForKey:PADDINGTOP_KEY]))
        padding.top = fmax([number doubleValue], 0.0);
    if ((number = [settings objectForKey:PADDINGLEFT_KEY]))
        padding.left = fmax([number doubleValue], 0.0);
    if ((number = [settings objectForKey:PADDINGBOTTOM_KEY]))
        padding.bottom = fmax([number doubleValue], 0.0);
    if ((number = [settings objectForKey:PADDINGRIGHT_KEY]))
        padding.right = fmax([number doubleValue], 0.0);
    return padding;
}

static NSString *SKTypeForNoteType(SKNoteType annotationType);

enum {
    SKLayerNone,
    SKLayerUse,
    SKLayerAdd,
    SKLayerRemove
};

enum {
    SKLayerTypeNote,
    SKLayerTypeRect
};

@protocol SKLayerDelegate <NSObject>
- (void)drawLayerControllerInContext:(CGContextRef)context;
@end

// this class is a proxy for the layer delegate
// to avoid overriding NSView's CALayerDelegate methods
@interface SKLayerController : NSObject <CALayerDelegate> {
    CALayer *layer;
    __weak id<SKLayerDelegate> delegate;
    NSRect rect;
    NSInteger type;
    PDFAnnotation *annotation;
}
@property (nonatomic, strong) CALayer *layer;
@property (nonatomic, weak) id<SKLayerDelegate> delegate;
@property (nonatomic) NSRect rect;
@property (nonatomic) NSInteger type;
@property (nonatomic, strong) PDFAnnotation *annotation;
@end

#pragma mark -

// a transient focus ring drawn around a destination after a jump, to draw the eye to the target;
// modelled on SKSyncDot: a repeating timer drives a phase counter, the owner redraws the marker's
// bounds on every tick and drops the marker on the final tick
static const NSInteger SKFocusMarkerTicks = 16;

@interface SKFocusMarker : NSObject {
    NSRect rect;
    NSRect bounds;
    PDFPage *page;
    __weak PDFView *view;
    NSTimer *timer;
    _Atomic(NSInteger) phase;
    NSUInteger skipped;
    void (^handler)(BOOL finished);
}
@property (nonatomic, readonly) NSRect rect;
@property (nonatomic, readonly) PDFPage *page;
@property (nonatomic, readonly) NSRect bounds;

- (instancetype)initWithRect:(NSRect)aRect page:(PDFPage *)aPage view:(PDFView *)aView updateHandler:(void (^)(BOOL finished))aHandler;
- (instancetype)init NS_UNAVAILABLE;

- (void)invalidate;

- (void)drawInContext:(CGContextRef)context lineWidth:(CGFloat)lineWidth;

@end

@implementation SKFocusMarker

@synthesize rect, page, bounds;

- (instancetype)initWithRect:(NSRect)aRect page:(PDFPage *)aPage view:(PDFView *)aView updateHandler:(void (^)(BOOL))aHandler {
    self = [super init];
    if (self) {
        rect = aRect;
        page = aPage;
        view = aView;
        phase = 0;
        skipped = 0;
        // the marker contracts from 150% to 100% of the target size, so invalidate the largest extent
        bounds = NSInsetRect(SKRectFromCenterAndSize(NSMakePoint(NSMidX(rect), NSMidY(rect)), NSMakeSize(1.5 * NSWidth(rect), 1.5 * NSHeight(rect))), -3.0, -3.0);
        __weak SKFocusMarker *weakSelf = self;
        timer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *t){ [weakSelf animate]; }];
        handler = [aHandler copy];
    }
    return self;
}

- (void)dealloc {
    [timer invalidate];
}

- (void)finish {
    [timer invalidate];
    timer = nil;
    if (handler) {
        handler(YES);
        handler = nil;
    }
}

- (void)animate {
    // don't burn the animation while the target page is not displayed, e.g. during a slow relayout
    if (page && view && [view isPageAtIndexDisplayed:[page pageIndex]] == NO) {
        if (++skipped > 40)
            [self finish];
        return;
    }
    if (atomic_fetch_add(&phase, 1) + 1 >= SKFocusMarkerTicks) {
        [self finish];
        return;
    }
    if (handler)
        handler(NO);
}

- (void)invalidate {
    [timer invalidate];
    timer = nil;
    handler = nil;
}

- (void)drawInContext:(CGContextRef)context lineWidth:(CGFloat)lineWidth {
    NSInteger aPhase = atomic_load(&phase);
    if (aPhase >= SKFocusMarkerTicks)
        return;
    CGFloat progress = (CGFloat)aPhase / (CGFloat)SKFocusMarkerTicks;
    CGFloat alpha, scale;
    if (progress < 1.0 / 3.0) {
        // contract from 150% to 100% while fading in
        CGFloat t = 3.0 * progress;
        alpha = 0.6 * t;
        scale = 1.5 - 0.5 * t;
    } else if (progress < 0.5) {
        alpha = 0.6;
        scale = 1.0;
    } else {
        // fade out over the last half
        alpha = 0.6 * (1.0 - 2.0 * (progress - 0.5));
        scale = 1.0;
    }
    NSRect r = SKRectFromCenterAndSize(NSMakePoint(NSMidX(rect), NSMidY(rect)), NSMakeSize(scale * NSWidth(rect), scale * NSHeight(rect)));
    NSColor *color = [[NSColor selectionHighlightColor:YES] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (color == nil)
        color = [NSColor controlAccentColor];
    CGFloat red = 0.0, green = 0.0, blue = 1.0, baseAlpha = 1.0;
    [color getRed:&red green:&green blue:&blue alpha:&baseAlpha];
    CGFloat radius = MIN(4.0, 0.5 * MIN(NSWidth(r), NSHeight(r)));
    CGPathRef path = CGPathCreateWithRoundedRect(NSRectToCGRect(r), radius, radius, NULL);
    CGColorRef fillColor = CGColorCreateGenericRGB(red, green, blue, baseAlpha * alpha * 0.15);
    CGColorRef strokeColor = CGColorCreateGenericRGB(red, green, blue, baseAlpha * alpha);
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextSetFillColorWithColor(context, fillColor);
    CGContextFillPath(context);
    CGContextAddPath(context, path);
    CGContextSetStrokeColorWithColor(context, strokeColor);
    CGContextSetLineWidth(context, lineWidth);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
    CGPathRelease(path);
    CGColorRelease(fillColor);
    CGColorRelease(strokeColor);
}

@end

#pragma mark -

@interface PDFView (SKPrivateDeclarations)
- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;
- (void)enableSwipeGestures:(BOOL)flag;
@end

@interface SKPDFView () <SKReadingBarDelegate, SKLayerDelegate, SKTextNoteEditorDelegate>

@property (strong) SKReadingBar *readingBar;
@property (strong) SKSyncDot *syncDot;
@property (strong) SKFocusMarker *focusMarker;

- (void)showFocusMarkerForDestination:(PDFDestination *)destination;
- (void)clearFocusMarker;

- (void)editTextNoteWithEvent:(NSEvent *)theEvent;
- (BOOL)isEditingAnnotation:(PDFAnnotation *)annotation;

- (void)beginNewUndoGroupIfNeeded;

- (void)addAnnotation:(PDFAnnotation *)annotation toPage:(PDFPage *)page select:(BOOL)shouldSelect;
- (void)addAnnotations:(NSArray *)annotationsAndPages;
- (void)removeAnnotation:(PDFAnnotation *)annotation;

- (void)addMarkupAnnotationWithType:(SKNoteType)annotationType selection:(PDFSelection *)selection;

- (void)addAnnotationForPoint:(id)sender;

- (void)stopPacer;
- (void)updatePacer;

- (void)setNeedsDisplay:(BOOL)needsDisplay forReadingBarBounds:(NSRect)rect onPage:(PDFPage *)page notify:(BOOL)notify;

- (void)updateSwipeGestures;

- (void)doMoveCurrentAnnotationForKey:(unichar)eventChar byAmount:(CGFloat)delta;
- (void)doResizeCurrentAnnotationForKey:(unichar)eventChar byAmount:(CGFloat)delta;
- (void)doAutoSizeActiveNoteIgnoringWidth:(BOOL)ignoreWidth;
- (void)doMoveReadingBarForKey:(unichar)eventChar;
- (void)doResizeReadingBarForKey:(unichar)eventChar;

- (BOOL)doSelectAnnotationWithEvent:(NSEvent *)theEvent;
- (void)doDragAnnotationWithEvent:(NSEvent *)theEvent;
- (void)doClickLinkWithEvent:(NSEvent *)theEvent;
- (void)doSelectSnapshotWithEvent:(NSEvent *)theEvent;
- (void)doMagnifyWithEvent:(NSEvent *)theEvent;
- (void)doDrawFreehandNoteWithEvent:(NSEvent *)theEvent;
- (void)doEraseAnnotationsWithEvent:(NSEvent *)theEvent;
- (void)doSelectWithEvent:(NSEvent *)theEvent;
- (void)doDragReadingBarWithEvent:(NSEvent *)theEvent;
- (void)doResizeReadingBarWithEvent:(NSEvent *)theEvent;
- (void)doMarqueeZoomWithEvent:(NSEvent *)theEvent;
- (BOOL)doDragMouseWithEvent:(NSEvent *)theEvent;
- (void)showHelpMenu;

- (void)removeLoupeWindow;

- (void)alignScrollOriginToDevicePixels;
- (void)handleScrollBoundsDidChangeNotification:(NSNotification *)notification;

- (void)handlePageChangedNotification:(NSNotification *)notification;
- (void)handleScaleChangedNotification:(NSNotification *)notification;
- (void)handleUpdateTrackingAreasNotification:(NSNotification *)notification;
- (void)handleOpenOrCloseUndoGroupNotification:(NSNotification *)notification;
- (void)registerForDocumentNotifications;
- (void)unregisterForDocumentNotifications;

@end

#pragma mark -

@implementation SKPDFView

@synthesize toolMode, annotationMode, temporaryToolMode, currentAnnotation, readingBar, pacerSpeed, typeSelectHelper, syncDot, focusMarker, hideNotes, zooming;
@dynamic extendedDisplayMode, displaySettings, canAddNotes, canSelectNote, hasReadingBar, hasPacer, selectToolPage, selectToolRect, magnifyToolMagnification, needsRewind, editing, delegate;

+ (void)initialize {
    SKINITIALIZE;
    
    NSArray *sendTypes = @[NSPasteboardTypePDF, NSPasteboardTypeTIFF, NSPasteboardTypeString, NSPasteboardTypeRTF];
    [NSApp registerServicesMenuSendTypes:sendTypes returnTypes:@[]];
    
    NSNumber *moveReadingBarModifiersNumber = [[NSUserDefaults standardUserDefaults] objectForKey:SKMoveReadingBarModifiersKey];
    NSNumber *resizeReadingBarModifiersNumber = [[NSUserDefaults standardUserDefaults] objectForKey:SKResizeReadingBarModifiersKey];
    if (moveReadingBarModifiersNumber)
        moveReadingBarModifiers = [moveReadingBarModifiersNumber integerValue];
    if (resizeReadingBarModifiersNumber)
        resizeReadingBarModifiers = [resizeReadingBarModifiersNumber integerValue];
    
    useToolModeCursors = [[NSUserDefaults standardUserDefaults] boolForKey:SKUseToolModeCursorsKey];
    
    SKSwizzlePDFDocumentViewMethods();
    SKSwizzlePDFPageViewMethods();
    SKSwizzlePDFAccessibilityNodeAnnotationMethods();
}

- (void)commonInitialization {
    toolMode = [[NSUserDefaults standardUserDefaults] integerForKey:SKLastToolModeKey];
    annotationMode = [[NSUserDefaults standardUserDefaults] integerForKey:SKLastAnnotationModeKey];
    
    typeSelectHelper = nil;
    
    spellingTag = [NSSpellChecker uniqueSpellDocumentTag];
    
    hideNotes = NO;
    wantsNewUndoGroup = NO;
    
    if (@available(macOS 15.0, *))
        drawsActiveSelection = NO;
    else
        drawsActiveSelection = YES;
    
    readingBar = nil;
    
    pacerTimer = nil;
    pacerSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:SKPacerSpeedKey];
    if (pacerSpeed <= 0.0)
        pacerSpeed = DEFAULT_PACER_SPEED;
    
    currentAnnotation = nil;
    selectionRect = NSZeroRect;
    selectionPageIndex = NSNotFound;
    
    syncDot = nil;
    
    gestureRotation = 0.0;
    gesturePageIndex = NSNotFound;
    
    // start from the registered defaults, so documents whose saved setup predates these settings get the configured values
    NSDictionary *displaySettings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultPDFDisplaySettingsKey];
    pdfViewPadding = SKPaddingFromSettings(displaySettings, NSEdgeInsetsZero);
    NSNumber *number = [displaySettings objectForKey:PAGEGAP_KEY];
    pageGap = number ? fmax([number doubleValue], 0.0) : 0.0;
    // PDFKit starts with nonzero margins, so force the first application
    pageBreakMarginValues = NSEdgeInsetsMake(-1.0, -1.0, -1.0, -1.0);
    [self updatePageBreakMargins];
    
    NSTrackingAreaOptions options = NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited;
    for (NSTrackingArea *area in [self trackingAreas]) {
        if (([area options] & NSTrackingInVisibleRect))
            options &= ~[area options];
    }
    if (options)
        [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:options | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    
    [self updateSwipeGestures];
    
    [self registerForDraggedTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle, NSPasteboardTypeFileURL]];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handlePageChangedNotification:)
                                                 name:PDFViewPageChangedNotification object:self];
    [nc addObserver:self selector:@selector(handleScaleChangedNotification:)
                                                 name:PDFViewScaleChangedNotification object:self];
    NSView *view = [[self embeddedScrollView] contentView];
    if (view) {
        [nc addObserver:self selector:@selector(handleUpdateTrackingAreasNotification:) name:NSViewDidUpdateTrackingAreasNotification object:view];
        // PDFKit lays out pages at fractional device-pixel positions at many zoom levels, which antialiases the
        // white page background into a visible 1px seam at the page edges; keep the scroll origin on the device
        // pixel grid so page rects land on integral device pixels
        [view addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionPrior context:&SKPDFViewScrollBoundsObservationContext];
    }
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    [sud addObserver:self forKeyPath:SKReadingBarColorKey options:0 context:&SKPDFViewDefaultsObservationContext];
    [sud addObserver:self forKeyPath:SKReadingBarInvertKey options:0 context:&SKPDFViewDefaultsObservationContext];
    
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInitialization];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self commonInitialization];
    }
    return self;
}

- (void)cleanup {
    [[NSSpellChecker sharedSpellChecker] closeSpellDocumentWithTag:spellingTag];
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    [sud removeObserver:self forKeyPath:SKReadingBarColorKey context:&SKPDFViewDefaultsObservationContext];
    [sud removeObserver:self forKeyPath:SKReadingBarInvertKey context:&SKPDFViewDefaultsObservationContext];
    NSClipView *clipView = [[self embeddedScrollView] contentView];
    if (clipView)
        [clipView removeObserver:self forKeyPath:@"bounds" context:&SKPDFViewScrollBoundsObservationContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
    [self removePDFToolTipRects];
    [syncDot invalidate];
    syncDot = nil;
    [self clearFocusMarker];
    [self stopPacer];
    [self removeLoupeWindow];
}

#pragma mark Tool Tips

- (void)removePDFToolTipRects {
    NSView *docView = [self documentView];
    NSArray *trackingAreas = [[docView trackingAreas] copy];
    for (NSTrackingArea *area in trackingAreas) {
        if ([area owner] == self && [[area userInfo] objectForKey:SKAnnotationKey])
            [docView removeTrackingArea:area];
    }
}

- (void)resetPDFToolTipRects {
    [self removePDFToolTipRects];
    
    if ([self document] && [self window]) {
        NSRect visibleRect = [self unobscuredContentRect];
        NSView *docView = [self documentView];
        BOOL hasLinkToolTips = toolMode != SKToolModeMagnify;
        NSPoint mouseLoc = [docView convertPoint:[[self window] convertPointFromScreen:[NSEvent mouseLocation]] fromView:nil];
        BOOL mouseInView = [[self window] isVisible] && NSMouseInRect(mouseLoc, [docView visibleRect], [docView isFlipped]);
        NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow;
        PDFAnnotation *hoverAnnotation = nil;
        
        for (PDFPage *page in [self visiblePages]) {
            for (PDFAnnotation *annotation in [page annotations]) {
                if ([annotation isNote] || (hasLinkToolTips && [annotation destination])) {
                    NSRect rect = NSIntersectionRect([self convertRect:[annotation bounds] fromPage:page], visibleRect);
                    if (NSIsEmptyRect(rect) == NO) {
                        rect = [self convertRect:rect toView:docView];
                        if (mouseInView && NSMouseInRect(mouseLoc, rect, [docView isFlipped]))
                            hoverAnnotation = annotation;
                        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:rect options:options owner:self userInfo:@{SKAnnotationKey: annotation}];
                        [docView addTrackingArea:area];
                    }
                }
            }
        }
        
        if (mouseInView && hoverAnnotation != [[SKImageToolTipWindow sharedToolTipWindow] currentImageContext]) {
            if (hoverAnnotation)
                [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:hoverAnnotation scale:[self scaleFactor] atPoint:NSZeroPoint];
            else
                [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
        }
    }
}

#pragma mark Layout

- (void)layoutDocumentView {
    [super layoutDocumentView];
    [self resetPDFToolTipRects];
    if (editor) {
        if ([self isPageAtIndexDisplayed:[currentAnnotation pageIndex]])
            [self textNoteEditorSetFrame:editor];
        else
            [self commitEditing];
    }
}

#pragma mark Drawing

- (BOOL)drawsActiveSelections {
    return atomic_load(&drawsActiveSelection);
}

- (CGFloat)unitWidthOnPage:(PDFPage *)page {
    return NSWidth([self convertRect:NSMakeRect(0.0, 0.0, 1.0, 1.0) toPage:page]);
}

- (void)drawSelectionRect:(NSRect)rect atIndex:(NSUInteger)pageIndex forPage:(PDFPage *)pdfPage inContext:(CGContextRef)context {
    CGRect bounds = NSRectToCGRect([pdfPage boundsForBox:[self displayBox]]);
    CGColorRef color = CGColorCreateGenericGray(0.0, 0.6);
    CGRect r = CGContextConvertRectToUserSpace(context, CGRectIntegral(CGContextConvertRectToDeviceSpace(context, NSRectToCGRect(rect))));
    CGContextSetFillColorWithColor(context, color);
    CGColorRelease(color);
    CGContextBeginPath(context);
    CGContextAddRect(context, bounds);
    CGContextAddRect(context, r);
    CGContextEOFillPath(context);
    if ([pdfPage pageIndex] != pageIndex) {
        color = CGColorCreateGenericGray(0.0, 0.3);
        CGContextSetFillColorWithColor(context, color);
        CGColorRelease(color);
        CGContextFillRect(context, r);
    }
    SKDrawResizeHandles(context, NSRectFromCGRect(r), [self unitWidthOnPage:pdfPage], NO, [self drawsActiveSelections]);
}

- (void)drawHighlights:(BOOL)drawAnnotationHighlight forPage:(PDFPage *)pdfPage toContext:(CGContextRef)context {
    PDFAnnotation *annotation = nil;
    NSRect rect;
    NSUInteger pageIndex;
    @synchronized (self) {
        if (drawAnnotationHighlight && [[currentAnnotation page] isEqual:pdfPage])
            annotation = currentAnnotation;
        pageIndex = selectionPageIndex;
        rect = selectionRect;
    }
    SKReadingBar *aReadingBar = [self readingBar];
    SKSyncDot *aSyncDot = [self syncDot];
    if ([[aSyncDot page] isEqual:pdfPage] == NO)
        aSyncDot = nil;
    SKFocusMarker *aFocusMarker = [self focusMarker];
    if ([[aFocusMarker page] isEqual:pdfPage] == NO)
        aFocusMarker = nil;
    
    if (annotation == nil && pageIndex == NSNotFound && aReadingBar == nil && aSyncDot == nil && aFocusMarker == nil)
        return;
    
    CGContextSaveGState(context);
    
    [pdfPage transformContext:context forBox:[self displayBox]];
    
    [aReadingBar drawForPage:pdfPage withBox:[self displayBox] inContext:context];
    
    if (annotation)
        [annotation drawSelectionHighlightWithUnitWidth:[self unitWidthOnPage:pdfPage] active:[self drawsActiveSelections] inContext:context];
    
    if (pageIndex != NSNotFound)
        [self drawSelectionRect:rect atIndex:pageIndex forPage:pdfPage inContext:context];
    
    [aSyncDot drawInContext:context];
    
    [aFocusMarker drawInContext:context lineWidth:2.0 / fmax([self scaleFactor], 0.01)];
    
    CGContextRestoreGState(context);
}

- (void)drawPage:(PDFPage *)pdfPage toContext:(CGContextRef)context {
    NSInteger state = atomic_load(&highlightLayerState);
    if (state == SKLayerAdd) {
        state = SKLayerUse;
        atomic_store(&highlightLayerState, SKLayerUse);
        dispatch_async(dispatch_get_main_queue(), ^{ [self makeHighlightLayerForType:SKLayerTypeNote]; });
    } else if (state == SKLayerRemove) {
        state = SKLayerNone;
        atomic_store(&highlightLayerState, SKLayerNone);
        dispatch_async(dispatch_get_main_queue(), ^{ [self removeHighlightLayer]; });
    }

    // Let PDFView do most of the hard work.
    [super drawPage:pdfPage toContext:context];
    [self drawHighlights:state != SKLayerUse forPage:pdfPage toContext:context];
}

- (void)drawLayerControllerInContext:(CGContextRef)context {
    if ([highlightLayerController type] == SKLayerTypeNote) {
        if (currentAnnotation == nil)
            return;
        PDFPage *page = [currentAnnotation page];
        NSPoint offset = [self convertRect:[page boundsForBox:[self displayBox]] fromPage:page].origin;
        CGFloat scaleFactor = [self scaleFactor];
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, offset.x, offset.y);
        CGContextScaleCTM(context, scaleFactor, scaleFactor);
        [page transformContext:context forBox:[self displayBox]];
        [currentAnnotation drawSelectionHighlightWithUnitWidth:1.0 / scaleFactor active:[self drawsActiveSelections] inContext:context];
        CGContextRestoreGState(context);
    } else {
        CGRect rect = NSRectToCGRect([highlightLayerController rect]);
        if (CGRectIsEmpty(rect))
            return;
        rect = CGContextConvertRectToUserSpace(context, CGRectIntegral(CGContextConvertRectToDeviceSpace(context, NSRectToCGRect(rect))));
        CGContextSaveGState(context);
        if (CGRectGetWidth(rect) > 1.0 && CGRectGetHeight(rect) > 1.0) {
            CGContextSetStrokeColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            CGContextSetLineWidth(context, 1.0);
            CGContextStrokeRect(context, CGRectInset(rect, 0.5, 0.5 ));
        } else {
            CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            CGContextFillRect(context, rect);
        }
        CGContextRestoreGState(context);
    }
}

- (void)makeHighlightLayerForType:(NSInteger)type {
    if (highlightLayerController) {
        [[highlightLayerController layer] removeFromSuperlayer];
    }
    CALayer *layer = [[CALayer alloc] init];
    [layer setFrame:NSRectToCGRect([self unobscuredContentRect])];
    [layer setBounds:[layer frame]];
    [layer setMasksToBounds:YES];
    [layer setZPosition:1.0];
    [layer setContentsScale:[[self layer] contentsScale]];
    [layer setFilters:SKColorEffectFilters()];
    highlightLayerController = [[SKLayerController alloc] init];
    [highlightLayerController setType:type];
    [highlightLayerController setDelegate:self];
    [highlightLayerController setLayer:layer];
    [layer setDelegate:highlightLayerController];
    [[self layer] addSublayer:layer];
    [layer setNeedsDisplay];
}

- (void)removeHighlightLayer {
    [[highlightLayerController layer] removeFromSuperlayer];
    highlightLayerController = nil;
}

#pragma mark Destination focus

- (void)goToDestination:(PDFDestination *)destination {
    [super goToDestination:destination];
    // gate on the RAW destination point, before effectiveDestinationForView: resolves it: that method
    // substitutes a real page corner for an unspecified coordinate (Fit/FitB/FitBH/FitBV/XYZ), which would
    // ring a corner the caller never named; a half-specified point is rejected too because the line lookup
    // needs a sane x
    PDFPage *page = [destination page];
    NSPoint point = [destination point];
    if (page != nil && point.x < kPDFDestinationUnspecifiedValue && point.y < kPDFDestinationUnspecifiedValue)
        [self showFocusMarkerForDestination:[destination effectiveDestinationForView:self]];
}

- (void)showFocusMarkerForDestination:(PDFDestination *)destination {
    // keep document-open/restore and off-screen jumps silent
    if ([[self window] isVisible] == NO)
        return;
    if ([NSView shouldShowFadeAnimation] == NO || [NSView shouldShowSlideAnimation] == NO)
        return;
    PDFPage *page = [destination page];
    NSPoint point = [destination point];
    if (page == nil || NSEqualPoints(point, SKUnspecifiedPoint))
        return;
    
    NSRect rect = NSZeroRect;
    NSPointerArray *lineRects = [page lineRects];
    // a destination point is the top-left of the target line; indexOfLineRectAtPoint:lower:NO returns
    // that line (lower:YES returns the line above it, contrary to what its name suggests)
    NSInteger line = [page indexOfLineRectAtPoint:point lower:NO];
    if (line >= 0 && (NSUInteger)line < [lineRects count])
        rect = [lineRects rectAtIndex:(NSUInteger)line];
    if (NSIsEmptyRect(rect))
        rect = SKRectFromCenterAndSquareSize(point, 10.0);
    // inflate so the ring surrounds the target line/point
    rect = NSInsetRect(rect, -2.0, -2.0);
    if (NSIsEmptyRect(rect))
        return;
    
    [focusMarker invalidate];
    __weak __typeof__(self) weakSelf = self;
    [self setFocusMarker:[[SKFocusMarker alloc] initWithRect:rect page:page view:self updateHandler:^(BOOL finished){
            if (finished) {
                [weakSelf clearFocusMarker];
            } else {
                [weakSelf setNeedsDisplayInRect:[[weakSelf focusMarker] bounds] ofPage:[[weakSelf focusMarker] page]];
            }
        }]];
    [self setNeedsDisplayInRect:[focusMarker bounds] ofPage:page];
}

- (void)clearFocusMarker {
    SKFocusMarker *marker = focusMarker;
    if (marker == nil)
        return;
    [self setFocusMarker:nil];
    [self setNeedsDisplayInRect:[marker bounds] ofPage:[marker page]];
    [marker invalidate];
}

#pragma mark Accessors

- (void)setDocument:(PDFDocument *)document {
    [self setNeedsRewind:nil];
    
    BOOL shouldHideReadingBar = [syncDot shouldHideReadingBar];
    [syncDot invalidate];
    [self setSyncDot:nil];
    [self clearFocusMarker];
    
    @synchronized (self) {
        selectionRect = NSZeroRect;
        selectionPageIndex = NSNotFound;
    }
    
    [self removePDFToolTipRects];
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
    
    NSUInteger readingBarPageIndex = NSNotFound;
    NSInteger readingBarLine = -1;
    [self stopPacer];
    if ([self hasReadingBar]) {
        if (shouldHideReadingBar == NO) {
            readingBarPageIndex = [[readingBar page] pageIndex];
            readingBarLine = [readingBar currentLine];
        }
        [self setReadingBar:nil];
    }
    
    if ([self document])
        [self unregisterForDocumentNotifications];
    
    [super setDocument:document];
    
    if (document)
        [self registerForDocumentNotifications];
    
    [self resetPDFToolTipRects];
    
    if (readingBarPageIndex != NSNotFound) {
        PDFPage *page = nil;
        if (readingBarPageIndex < [document pageCount]) {
            page = [document pageAtIndex:readingBarPageIndex];
        } else if ([document pageCount] > 0) {
            page = [document pageAtIndex:[document pageCount] - 1];
            readingBarLine = 0;
        }
        if (page) {
            SKReadingBar *aReadingBar = [[SKReadingBar alloc] initWithPage:page line:readingBarLine delegate:self];
            [self setReadingBar:aReadingBar];
        }
    }
    
    [loupeController updateContents];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewCanSelectNoteDidChangeNotification object:self];
}

- (void)setBackgroundColor:(NSColor *)newBackgroundColor {
    [super setBackgroundColor:newBackgroundColor];
    [loupeController updateBackgroundColor];
}

- (NSColor *)backgroundColor {
    if (@available(macOS 11.0, *)) {} else if (@available(macOS 10.15, *))
        return [super backgroundColor] ?: [[self embeddedScrollView] backgroundColor];
    return [super backgroundColor];
}

- (void)setToolMode:(SKToolMode)newToolMode {
    if (toolMode != newToolMode) {
        [self setTemporaryToolMode:SKToolModeNone];
        if (IS_TEXT_OR_NOTE_TOOL) {
            if (newToolMode != SKToolModeText) {
                if (newToolMode != SKToolModeNote && currentAnnotation)
                    [self setCurrentAnnotation:nil];
                if ([[self currentSelection] hasCharacters])
                    [self setCurrentSelection:nil];
            }
        } else if (toolMode == SKToolModeSelect) {
            if (NSEqualRects(selectionRect, NSZeroRect) == NO) {
                [self setSelectToolRect:NSZeroRect];
                [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
            }
        } else if (toolMode == SKToolModeMagnify) {
            [self removeLoupeWindow];
        }
        
        toolMode = newToolMode;
        
        [[NSUserDefaults standardUserDefaults] setInteger:toolMode forKey:SKLastToolModeKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewToolModeChangedNotification object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewCanSelectNoteDidChangeNotification object:self];
        [self setCursorForMouse:nil];
        [self resetPDFToolTipRects];
        if (toolMode == SKToolModeMagnify && [[NSUserDefaults standardUserDefaults] boolForKey:SKMagnifyWithMousePressedKey] == NO)
            [self doMagnifyWithEvent:nil];
    }
}

- (void)setAnnotationMode:(SKNoteType)newAnnotationMode {
    if (annotationMode != newAnnotationMode) {
        annotationMode = newAnnotationMode;
        [[NSUserDefaults standardUserDefaults] setInteger:annotationMode forKey:SKLastAnnotationModeKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewAnnotationModeChangedNotification object:self];
        // hack to make sure we update the cursor
        [self setCursorForMouse:nil];
    }
}

- (void)performTemporaryMarkupToolMode {
    if (IS_MARKUP_TOOL(temporaryToolMode) && [[self currentSelection] hasCharacters])
        [self addMarkupAnnotationWithType:NOTE_TYPE_FROM_TEMP_TOOL_MODE(temporaryToolMode) selection:nil];
    [self setTemporaryToolMode:SKToolModeNone];
}

- (void)setTemporaryToolMode:(SKTemporaryToolMode)newTemporaryToolMode {
    if (temporaryToolMode != newTemporaryToolMode) {
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(performTemporaryMarkupToolMode) object:nil];
        temporaryToolMode = newTemporaryToolMode;
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewTemporaryToolModeChangedNotification object:self];
    }
}

- (void)setCurrentAnnotation:(PDFAnnotation *)newAnnotation {
	if (newAnnotation != currentAnnotation) {
        NSDictionary *userInfo = currentAnnotation ? @{SKPDFViewAnnotationKey:currentAnnotation} : nil;
        
        // Will need to redraw old active anotation.
        if (currentAnnotation != nil) {
            [self updatedAnnotation:currentAnnotation];
            [self commitEditing];
        }
        
        // Assign.
        @synchronized (self) {
            currentAnnotation = newAnnotation;
        }
        if (newAnnotation != nil) {
            // Force redisplay.
            [self updatedAnnotation:currentAnnotation];
        }
        
		[[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewCurrentAnnotationChangedNotification object:self userInfo:userInfo];
    }
}

- (BOOL)isEditing {
    return editor != nil;
}

- (PDFDisplayMode)extendedDisplayMode {
    PDFDisplayMode displayMode = [self displayMode];
    if (displayMode == kPDFDisplaySinglePageContinuous && [self displayDirection] == kPDFDisplayDirectionHorizontal)
        return kPDFDisplayHorizontalContinuous;
    return displayMode;
}

- (void)setExtendedDisplayMode:(PDFDisplayMode)mode {
    if (mode == kPDFDisplayHorizontalContinuous) {
        [self setDisplayMode:kPDFDisplaySinglePageContinuous];
        [self setDisplayDirection:kPDFDisplayDirectionHorizontal];
    } else {
        [self setDisplayMode:mode];
        [self setDisplayDirection:kPDFDisplayDirectionVertical];
    }
}

- (void)setExtendedDisplayModeAndRewind:(PDFDisplayMode)mode {
    if (mode != [self extendedDisplayMode]) {
        if (mode != kPDFDisplaySinglePage)
            [self setNeedsRewind:YES];
        [self setExtendedDisplayMode:mode];
    }
}

- (void)setDisplayMode:(PDFDisplayMode)displayMode {
    if (displayMode != [self displayMode]) {
        [super setDisplayMode:displayMode];
        [self updatePageBreakMargins];
    }
}

- (void)setDisplayDirection:(PDFDisplayDirection)displayDirection {
    if (displayDirection != [self displayDirection]) {
        [super setDisplayDirection:displayDirection];
        [self updatePageBreakMargins];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDisplayDirectionChangedNotification object:self];
    }
}

- (void)setDisplayDirectionAndRewind:(PDFDisplayDirection)displayDirection {
    if (displayDirection != [self displayDirection]) {
        [self setNeedsRewind:YES];
        [self setDisplayDirection:displayDirection];
        [self setDisplayMode:kPDFDisplaySinglePageContinuous];
    }
}

- (void)setDisplaysRTL:(BOOL)flag {
    if (flag != [self displaysRTL]) {
        [super setDisplaysRTL:flag];
        // on 10.15 this does not relayout the view...
        [self layoutDocumentView];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDisplaysRTLChangedNotification object:self];
    }
}

- (void)setDisplaysRTLAndRewind:(BOOL)flag {
    if (flag != [self displaysRTL]) {
        [self setNeedsRewind:YES];
        [self setDisplaysRTL:flag];
        [self setDisplayMode:[self displayMode] | kPDFDisplayTwoUp];
        [self setDisplayDirection:kPDFDisplayDirectionVertical];
    }
}

- (void)setDisplaysAsBook:(BOOL)asBook {
    if (asBook != [self displaysAsBook]) {
        [super setDisplaysAsBook:asBook];
		[[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDisplaysAsBookChangedNotification object:self];
    }
}

- (void)setDisplaysAsBookAndRewind:(BOOL)asBook {
    if (asBook != [self displaysAsBook]) {
        [self setNeedsRewind:YES];
        [self setDisplaysAsBook:asBook];
        [self setDisplayMode:[self displayMode] | kPDFDisplayTwoUp];
        [self setDisplayDirection:kPDFDisplayDirectionVertical];
    }
}

- (void)setDisplaysPageBreaks:(BOOL)pageBreaks {
    if (pageBreaks != [self displaysPageBreaks]) {
        [super setDisplaysPageBreaks:pageBreaks];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDisplaysPageBreaksChangedNotification object:self];
    }
}

- (void)setDisplayBoxAndRewind:(PDFDisplayBox)box {
    if (box != [self displayBox]) {
        if ([self displayMode] != kPDFDisplaySinglePage)
            [self setNeedsRewind:YES];
        [self setDisplayBox:box];
    }
}

- (void)setAutoScales:(BOOL)autoScales {
    if (autoScales != [self autoScales]) {
        [super setAutoScales:autoScales];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewAutoScalesChangedNotification object:self];
    }
}

- (void)setCurrentSelection:(PDFSelection *)selection {
    if ((toolMode == SKToolModeNote && annotationMode == SKNoteTypeHighlight) || temporaryToolMode == SKToolModeHighlight)
        [selection setColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKHighlightNoteColorKey]];
    [super setCurrentSelection:selection];
}

- (NSRect)selectToolRect {
    if (toolMode == SKToolModeSelect)
        return selectionRect;
    return NSZeroRect;
}

- (void)setSelectToolRect:(NSRect)rect {
    if (toolMode == SKToolModeSelect) {
        if (NSEqualRects(selectionRect, rect) == NO)
            [self setNeedsDisplay:YES];
        @synchronized (self) {
            if (NSIsEmptyRect(rect)) {
                selectionRect = NSZeroRect;
                selectionPageIndex = NSNotFound;
            } else {
                selectionRect = rect;
                if (selectionPageIndex == NSNotFound)
                    selectionPageIndex = [[self currentPage] pageIndex];
            }
        }
    }
}

- (PDFPage *)selectToolPage {
    return selectionPageIndex == NSNotFound ? nil : [[self document] pageAtIndex:selectionPageIndex];
}

- (void)setSelectToolPage:(PDFPage *)page {
    if (toolMode == SKToolModeSelect) {
        if (selectionPageIndex != (page ? [page pageIndex] : NSNotFound))
            [self setNeedsDisplay:YES];
        @synchronized (self) {
            if (page == nil) {
                selectionPageIndex = NSNotFound;
                selectionRect = NSZeroRect;
            } else {
                selectionPageIndex = [page pageIndex];
                if (NSIsEmptyRect(selectionRect))
                    selectionRect = [page boundsForBox:kPDFDisplayBoxCropBox];
            }
        }
    }
}

- (CGFloat)magnifyToolMagnification {
    return loupeController ? [loupeController magnification] : 0.0;
}

- (NSUndoManager *)undoManager {
    // make sure we get the correct undoManager also when we are not in the document's window,
    // e.g. in presentation mode
    // this can happen when undoing form edits
    NSUndoManager *undoManager = nil;
    if ([[self delegate] respondsToSelector:@selector(undoManagerForPDFView:)])
        undoManager = [[self delegate] undoManagerForPDFView:self];
    if (undoManager == nil)
        undoManager = [super undoManager];
    return undoManager;
}

- (void)setHideNotes:(BOOL)flag {
    hideNotes = flag;
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewCanSelectNoteDidChangeNotification object:self];
}

- (BOOL)canAddNotes {
    return hideNotes == NO && [[self document] allowsNotes];
}

- (BOOL)canSelectNote {
    return [self canAddNotes] && IS_TEXT_OR_NOTE_TOOL;
}

- (NSEdgeInsets)pdfViewPadding {
    return pdfViewPadding;
}

- (void)setPdfViewPadding:(NSEdgeInsets)padding {
    padding.top = fmax(padding.top, 0.0);
    padding.left = fmax(padding.left, 0.0);
    padding.bottom = fmax(padding.bottom, 0.0);
    padding.right = fmax(padding.right, 0.0);
    if (NSEdgeInsetsEqual(padding, pdfViewPadding))
        return;
    pdfViewPadding = padding;
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewPaddingChangedNotification object:self];
}

- (CGFloat)pageGap {
    return pageGap;
}

- (void)setPageGap:(CGFloat)gap {
    gap = fmax(gap, 0.0);
    if (gap == pageGap)
        return;
    pageGap = gap;
    [self updatePageBreakMargins];
}

// PDFKit applies pageBreakMargins around every page, so we only inset along the axes along which pages repeat,
// which keeps the fitted axis flush with the pane; the gap is split between the neighbouring pages
- (void)updatePageBreakMargins {
    CGFloat gap = pageGap;
    NSEdgeInsets margins = NSEdgeInsetsZero;
    if (gap > 0.0) {
        switch ([self extendedDisplayMode]) {
            case kPDFDisplaySinglePageContinuous:
                margins = NSEdgeInsetsMake(0.5 * gap, 0.0, 0.5 * gap, 0.0);
                break;
            case kPDFDisplayHorizontalContinuous:
            case kPDFDisplayTwoUp:
                margins = NSEdgeInsetsMake(0.0, 0.5 * gap, 0.0, 0.5 * gap);
                break;
            case kPDFDisplayTwoUpContinuous:
                margins = NSEdgeInsetsMake(0.5 * gap, 0.5 * gap, 0.5 * gap, 0.5 * gap);
                break;
            default:
                break;
        }
    }
    // PDFKit ignores and reports zero margins when page breaks are not displayed, so keep track of what we applied
    if (NSEdgeInsetsEqual(margins, pageBreakMarginValues))
        return;
    pageBreakMarginValues = margins;
    [self setPageBreakMargins:margins];
    // PDFKit does not relayout on a pageBreakMargins change
    if ([self document])
        [self layoutDocumentView];
}

- (NSDictionary *)displaySettings {
    return @{DISPLAYSPAGEBREAKS_KEY: [NSNumber numberWithBool:[self displaysPageBreaks]],
            DISPLAYSASBOOK_KEY:      [NSNumber numberWithBool:[self displaysAsBook]],
            DISPLAYBOX_KEY:          [NSNumber numberWithInteger:[self displayBox]],
            SCALEFACTOR_KEY:         [NSNumber numberWithDouble:[self scaleFactor]],
            AUTOSCALES_KEY:          [NSNumber numberWithBool:[self autoScales]],
            DISPLAYMODE_KEY:         [NSNumber numberWithInteger:[self displayMode]],
            DISPLAYDIRECTION_KEY:    [NSNumber numberWithInteger:[self displayDirection]],
            DISPLAYSRTL_KEY:         [NSNumber numberWithBool:[self displaysRTL]],
            PADDINGTOP_KEY:          [NSNumber numberWithDouble:pdfViewPadding.top],
            PADDINGLEFT_KEY:         [NSNumber numberWithDouble:pdfViewPadding.left],
            PADDINGBOTTOM_KEY:       [NSNumber numberWithDouble:pdfViewPadding.bottom],
            PADDINGRIGHT_KEY:        [NSNumber numberWithDouble:pdfViewPadding.right],
            PAGEGAP_KEY:             [NSNumber numberWithDouble:pageGap]};
}

- (void)applyPaddingSettings:(NSDictionary *)settings {
    NSNumber *number = [settings objectForKey:PAGEGAP_KEY];
    if (number)
        [self setPageGap:[number doubleValue]];
    [self setPdfViewPadding:SKPaddingFromSettings(settings, pdfViewPadding)];
}

- (void)setDisplaySettings:(NSDictionary *)setup {
    NSNumber *number;
    [self applyPaddingSettings:setup];
    if ((number = [setup objectForKey:AUTOSCALES_KEY]))
        [self setAutoScales:[number boolValue]];
    if ([self autoScales] == NO && (number = [setup objectForKey:SCALEFACTOR_KEY]))
        [self setScaleFactor:[number doubleValue]];
    if ((number = [setup objectForKey:DISPLAYSPAGEBREAKS_KEY]))
        [self setDisplaysPageBreaks:[number boolValue]];
    if ((number = [setup objectForKey:DISPLAYSASBOOK_KEY]))
        [self setDisplaysAsBook:[number boolValue]];
    if ((number = [setup objectForKey:DISPLAYMODE_KEY])) {
        [self setDisplayMode:[number integerValue]];
        if ([self displayMode] == kPDFDisplaySinglePageContinuous && (number = [setup objectForKey:DISPLAYDIRECTION_KEY]))
            [self setDisplayDirection:[number integerValue]];
        else
            [self setDisplayDirection:kPDFDisplayDirectionVertical];
    }
    if ((number = [setup objectForKey:DISPLAYSRTL_KEY]))
        [self setDisplaysRTL:[number boolValue]];
    if ((number = [setup objectForKey:DISPLAYBOX_KEY]))
        [self setDisplayBox:[number integerValue]];
}

- (void)setDisplaySettingsAndRewind:(NSDictionary *)setup {
    if ([setup count])
        [self setNeedsRewind:YES];
    [self setDisplaySettings:setup];
}

#pragma mark Reading bar

- (BOOL)hasReadingBar {
    return readingBar != nil;
}

- (void)toggleReadingBar {
    PDFPage *page = nil;
    NSRect bounds = NSZeroRect;
    if (readingBar) {
        page = [readingBar page];
        bounds = [readingBar currentBounds];
        [self setReadingBar:nil];
    } else {
        page = [self currentPage];
        NSInteger line = 0;
        PDFSelection *sel = [self currentSelection];
        if ([[sel pages] containsObject:page]) {
            NSRect rect = [sel boundsForPage:page];
            NSPoint point = [page lineDirectionAngle] < 180 ? NSMakePoint(NSMinX(rect) + 1.0, NSMinY(rect) + 1.0) : NSMakePoint(NSMaxY(rect) - 1.0, NSMaxY(rect) - 1.0);
            line = [page indexOfLineRectAtPoint:point lower:YES];
        }
        SKReadingBar *aReadingBar = [[SKReadingBar alloc] initWithPage:page line:line delegate:self];
        if ([aReadingBar currentLine] == -1) {
            NSBeep();
            return;
        }
        page = [aReadingBar page];
        bounds = [aReadingBar currentBounds];
        NSRect rect = [aReadingBar currentBounds];
        rect = ([page lineDirectionAngle] % 180) ? NSInsetRect(rect, 0.0, -20.0) : NSInsetRect(rect, -20.0, 0.0);
        [self goToRect:rect onPage:page];
        [self setReadingBar:aReadingBar];
    }
    [self updatePacer];
    [self setNeedsDisplay:[[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey] forReadingBarBounds:bounds onPage:page notify:YES];
}

- (void)readingBarDidChangeBounds:(NSRect)oldBounds onPage:(PDFPage *)oldPage toBounds:(NSRect)newBounds onPage:(PDFPage *)newPage scroll:(BOOL)shouldScroll {
    [syncDot setShouldHideReadingBar:NO];
    
    if (shouldScroll) {
        NSRect rect = newBounds;
        NSInteger lineAngle = [newPage lineDirectionAngle];
        if ((lineAngle % 180)) {
            rect = NSInsetRect(rect, 0.0, -20.0) ;
            if (([self displayMode] & kPDFDisplaySinglePageContinuous)) {
                NSRect visibleRect = [self convertRect:[self unobscuredContentRect] toPage:newPage];
                rect = NSInsetRect(rect, 0.0, - floor( ( NSHeight(visibleRect) - NSHeight(rect) ) / 2.0 ) );
                if (NSWidth(rect) <= NSWidth(visibleRect)) {
                    if (NSMinX(rect) > NSMinX(visibleRect))
                        rect.origin.x = fmax(NSMinX(visibleRect), NSMaxX(rect) - NSWidth(visibleRect));
                } else if (lineAngle == 90) {
                    rect.origin.x = NSMaxX(rect) - NSWidth(visibleRect);
                }
                rect.size.width = NSWidth(visibleRect);
            }
        } else {
            rect = NSInsetRect(rect, -20.0, 0.0) ;
            if (([self displayMode] & kPDFDisplaySinglePageContinuous)) {
                NSRect visibleRect = [self convertRect:[self unobscuredContentRect] toPage:newPage];
                rect = NSInsetRect(rect, - floor( ( NSWidth(visibleRect) - NSWidth(rect) ) / 2.0 ), 0.0 );
                if (NSHeight(rect) <= NSHeight(visibleRect)) {
                    if (NSMinY(rect) > NSMinY(visibleRect))
                        rect.origin.y = fmax(NSMinY(visibleRect), NSMaxY(rect) - NSHeight(visibleRect));
                } else if (lineAngle == 180) {
                    rect.origin.y = NSMaxY(rect) - NSHeight(visibleRect);
                }
                rect.size.height = NSHeight(visibleRect);
            }
        }
        [self goToRect:rect onPage:newPage];
    }
    
    if (oldPage)
        [self setNeedsDisplay:NO forReadingBarBounds:oldBounds onPage:oldPage notify:YES];
    if (newPage)
        [self setNeedsDisplay:NO forReadingBarBounds:newBounds onPage:newPage notify:newPage != oldPage];
}

#pragma mark Pacer

- (void)setPacerSpeed:(CGFloat)speed {
    if (speed > 0.0) {
        pacerSpeed = speed;
        [self updatePacer];
        [[NSUserDefaults standardUserDefaults] setDouble:speed forKey:SKPacerSpeedKey];
    }
}

- (BOOL)hasPacer {
    return pacerTimer != nil;
}

- (void)stopPacer {
    if (pacerTimer) {
        [pacerTimer invalidate];
        pacerTimer = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewPacerStartedOrStoppedNotification object:self];
    }
}

- (void)doPacerScroll {
    NSScrollView *scrollView = [self embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    if (NSHeight(docRect) + [scrollView contentInsets].top <= NSHeight(bounds))
        return;
    NSPoint currentOrigin = bounds.origin;
    CGFloat offset = [clipView convertSizeFromBacking:NSMakeSize(0.0, 1.0)].height;
    if ([clipView isFlipped]) {
        bounds.origin.y += offset;
        if (NSMaxY(docRect) < NSMaxY(bounds))
            bounds.origin.y = NSMaxY(docRect) - NSHeight(bounds);
    } else {
        bounds.origin.y -= offset;
        if (NSMinY(docRect) > NSMinY(bounds))
            bounds.origin.y = NSMinY(docRect);
    }
    if (NSEqualPoints(bounds.origin, currentOrigin) == NO) {
        [clipView scrollToPoint:bounds.origin];
        [scrollView reflectScrolledClipView:clipView];
    }
}

- (void)doPacerMoveReadingBar {
    if ([readingBar numberOfLines] > 1 && [readingBar currentLine] >= [readingBar maxLine] && pacerCounter + 1 < (NSInteger)[readingBar countOfLines]) {
        ++pacerCounter;
    } else {
        pacerCounter = 0;
        [readingBar goToNextLine];
    }
}

- (void)togglePacer {
    if (pacerTimer) {
        [self stopPacer];
    } else if (pacerSpeed > 0.0 && [[self document] isLocked] == NO) {
        CGFloat interval;
        __weak typeof(self) weakSelf = self;
        void (^block)(NSTimer *) = nil;
        if ([self hasReadingBar]) {
            pacerCounter = 0;
            interval = PACER_LINE_HEIGHT / pacerSpeed;
            block = ^(NSTimer *timer){ [weakSelf doPacerMoveReadingBar]; };
        } else {
            interval = 1.0 / (pacerSpeed * [([self window] ?: (NSWindow *)[NSScreen mainScreen]) backingScaleFactor] * [self scaleFactor]);
            block = ^(NSTimer *timer){ [weakSelf doPacerScroll]; };
        }
        pacerTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:block];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewPacerStartedOrStoppedNotification object:self];
    }
}

- (void)updatePacer {
    if (pacerTimer) {
        [self stopPacer];
        [self togglePacer];
    }
}

#pragma mark Actions

- (IBAction)delete:(id)sender
{
	if ([currentAnnotation isSkimNote])
        [self removeCurrentAnnotation:self];
    else
        NSBeep();
}

- (IBAction)copy:(id)sender
{
    NSAttributedString *attrString = [[self currentSelection] attributedString];
    NSPasteboardItem *imageItem = nil;
    PDFAnnotation *note = nil;
    
    if ([self hideNotes] == NO && [currentAnnotation isSkimNote]) {
        if ([currentAnnotation isMovable])
            note = currentAnnotation;
        else if (attrString == nil && [currentAnnotation isMarkup])
            attrString = [[currentAnnotation selection] attributedString];
    }
    
    if (toolMode == SKToolModeSelect && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound) {
        NSRect selRect = NSIntegralRect(selectionRect);
        PDFPage *page = [self selectToolPage];
        NSData *pdfData = nil;
        NSData *tiffData = nil;
        
        imageItem = [[NSPasteboardItem alloc] init];
        
        if ([[self document] allowsSaving] && (pdfData = [page PDFDataForRect:selRect]))
            [imageItem setData:pdfData forType:NSPasteboardTypePDF];
        if ((tiffData = [page TIFFDataForRect:selRect]))
            [imageItem setData:tiffData forType:NSPasteboardTypeTIFF];
        
        /*
         Possible hidden default?  Alternate way of getting a bitmap rep; this varies resolution with zoom level, which is very useful if you want to copy a single figure or equation for a non-PDF-capable program.  The first copy: action has some odd behavior, though (view moves).  Preview produces a fixed resolution bitmap for a given selection area regardless of zoom.
         
        sourceRect = [self convertRect:selectionRect fromPage:[self currentPage]];
        NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:sourceRect];
        [self cacheDisplayInRect:sourceRect toBitmapImageRep:imageRep];
        tiffData = [imageRep TIFFRepresentation];
         */
    }
    
    if ([attrString length] > 0 || imageItem || note) {
    
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        
        [pboard clearContents];
        
        if ([attrString length] > 0)
            [pboard writeObjects:@[attrString]];
        if (imageItem)
            [pboard writeObjects:@[imageItem]];
        if (note)
            [pboard writeObjects:@[note]];
        
    } else {
        [super copy:sender];
    }
}

- (void)pasteNote:(BOOL)preferNote plainText:(BOOL)isPlainText {
    if ([self canAddNotes] == NO) {
        NSBeep();
        return;
    }
    
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSDictionary *options = @{};
    NSArray *newAnnotations = nil;
    PDFPage *page;
    
    if (isPlainText == NO)
        newAnnotations = [pboard readObjectsForClasses:@[[PDFAnnotation class]] options:options];
    
    if ([newAnnotations count] == 1) {
        
        PDFAnnotation *newAnnotation = [newAnnotations firstObject];
        page = [self currentPage];
        [newAnnotation setBounds:SKConstrainRect([newAnnotation bounds], [page boundsForBox:[self displayBox]])];
        [self addAnnotation:newAnnotation toPage:page select:YES];
        
    } else if ([newAnnotations count] > 0) {
        
        NSMutableArray *newAnnotationsAndPages = [NSMutableArray array];
        page = [self currentPage];
        for (PDFAnnotation *newAnnotation in newAnnotations) {
            [newAnnotation setBounds:SKConstrainRect([newAnnotation bounds], [page boundsForBox:[self displayBox]])];
            [newAnnotationsAndPages addObject:@[newAnnotation, page]];
        }
        [self addAnnotations:newAnnotationsAndPages];
        
    } else {
        
        id str = nil;
        
        if (isPlainText || preferNote)
            str = [[pboard readObjectsForClasses:@[[NSAttributedString class], [NSString class]] options:options] firstObject];
        else
            str = [[pboard readObjectsForClasses:@[[NSString class]] options:options] firstObject];
        
        
        if (str) {
            
            // First try the current mouse position
            NSPoint center = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
            
            // if the mouse was in the toolbar and there is a page below the toolbar, we get a point outside of the visible rect
            page = NSMouseInRect(center, [self unobscuredContentRect], [self isFlipped]) ? [self pageForPoint:center nearest:NO] : nil;
            
            if (page == nil) {
                // Get center of the PDFView.
                NSRect viewFrame = [self frame];
                center = SKCenterPoint(viewFrame);
                page = [self pageForPoint: center nearest: YES];
            }
            
            // Convert to "page space".
            center = [self convertPoint: center toPage: page];
            
            NSSize defaultSize = SKNPDFAnnotationNoteSize;
            if (preferNote == NO) {
                if ([str isKindOfClass:[NSAttributedString class]])
                    str = [str string];
                NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKFreeTextNoteFontNameKey sizeKey:SKFreeTextNoteFontSizeKey];
                CGFloat width = [[NSUserDefaults standardUserDefaults] floatForKey:SKDefaultNoteWidthKey];
                defaultSize = SKFitTextNoteSize(str, font, width);
                if (([page rotation] % 180))
                    defaultSize = NSMakeSize(defaultSize.height, defaultSize.width);
            }
            
            NSRect bounds = SKRectFromCenterAndSize(center, defaultSize);
            bounds.origin = SKIntegralPoint(bounds.origin);
            bounds = SKConstrainRect(bounds, [page boundsForBox:[self displayBox]]);
            
            PDFAnnotation *newAnnotation = nil;
            
            if (preferNote) {
                newAnnotation = [PDFAnnotation newSkimNoteWithBounds:bounds forType:SKNNoteString];
                NSMutableAttributedString *attrString = nil;
                if ([str isKindOfClass:[NSString class]])
                    attrString = [[NSMutableAttributedString alloc] initWithString:str];
                else if ([str isKindOfClass:[NSAttributedString class]])
                    attrString = [[NSMutableAttributedString alloc] initWithAttributedString:str];
                if (isPlainText || [str isKindOfClass:[NSString class]]) {
                    NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKAnchoredNoteFontNameKey sizeKey:SKAnchoredNoteFontSizeKey];
                    if (font)
                        [attrString setAttributes:@{NSFontAttributeName:font} range:NSMakeRange(0, [attrString length])];
                }
                [(SKNPDFAnnotationNote *)newAnnotation setText:attrString];
            } else {
                newAnnotation = [PDFAnnotation newSkimNoteWithBounds:bounds forType:SKNFreeTextString];
                [newAnnotation setString:str];
            }
            
            [self addAnnotation:newAnnotation toPage:page select:YES];
            
        } else if (isPlainText == NO) {
            
            NSImage *image = [[pboard readObjectsForClasses:@[[NSImage class]] options:@{}] firstObject];
            
            if (image) {
                
                // First try the current mouse position
                NSPoint center = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
                
                // if the mouse was in the toolbar and there is a page below the toolbar, we get a point outside of the visible rect
                page = NSMouseInRect(center, [self unobscuredContentRect], [self isFlipped]) ? [self pageForPoint:center nearest:NO] : nil;
                
                if (page == nil) {
                    // Get center of the PDFView.
                    NSRect viewFrame = [self frame];
                    center = SKCenterPoint(viewFrame);
                    page = [self pageForPoint: center nearest: YES];
                }
                
                // Convert to "page space".
                center = [self convertPoint: center toPage: page];
                
                NSRect bounds = SKRectFromCenterAndSize(center, [image size]);
                bounds.origin = SKIntegralPoint(bounds.origin);
                bounds = SKConstrainRect(bounds, [page boundsForBox:[self displayBox]]);
                
                NSString *text = nil;
                if ([[NSUserDefaults standardUserDefaults] integerForKey:SKDisableUpdateContentsFromEnclosedTextKey] < 2)
                    text = [[self currentSelection] cleanedString];
                
                PDFAnnotation *newAnnotation = [PDFAnnotation newSkimNoteWithBounds:bounds forType:SKNNoteString];
                [(SKNPDFAnnotationNote *)newAnnotation setImage:image];
                [(SKNPDFAnnotationNote *)newAnnotation setExtendedIconType:kSKNPDFTextAnnotationIconImage];
                if ([text length] > 0)
                    [newAnnotation setString:text];
                
                [self addAnnotation:newAnnotation toPage:page select:YES];
                
            } else {
                
                NSBeep();
                
            }
        }
    }
}

- (IBAction)paste:(id)sender {
    [self pasteNote:NO plainText:NO];
}

- (IBAction)alternatePaste:(id)sender {
    [self pasteNote:YES plainText:NO];
}

- (IBAction)pasteAsPlainText:(id)sender {
    [self pasteNote:YES plainText:YES];
}

- (IBAction)cut:(id)sender
{
	if ([self canAddNotes] && [currentAnnotation isSkimNote]) {
        [self copy:sender];
        [self delete:sender];
    } else
        NSBeep();
}

- (IBAction)selectAll:(id)sender {
    [self setTemporaryToolMode:SKToolModeNone];
    if (toolMode == SKToolModeText)
        [super selectAll:sender];
}

- (IBAction)deselectAll:(id)sender {
    [self setCurrentSelection:nil];
}

- (IBAction)autoSelectContent:(id)sender {
    if (toolMode == SKToolModeSelect) {
        PDFPage *page = [self currentPage];
        @synchronized (self) {
            selectionRect = NSIntersectionRect(NSUnionRect([page autoCropBox], selectionRect), [page boundsForBox:[self displayBox]]);
            selectionPageIndex = [page pageIndex];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
        [self setNeedsDisplay:YES];
    }
}

- (IBAction)changeToolMode:(id)sender {
    [self setToolMode:[sender tag]];
}

- (IBAction)changeAnnotationMode:(id)sender {
    [self setToolMode:SKToolModeNote];
    [self setAnnotationMode:[sender tag]];
}

- (void)_setSinglePageScrolling:(id)sender {
    [self setExtendedDisplayModeAndRewind:kPDFDisplaySinglePageContinuous];
}

- (void)_setSinglePage:(id)sender {
    [self setExtendedDisplayMode:kPDFDisplaySinglePage];
}

- (void)_setDoublePageScrolling:(id)sender {
    [self setExtendedDisplayModeAndRewind:kPDFDisplayTwoUpContinuous];
}

- (void)_setDoublePage:(id)sender {
    [self setExtendedDisplayModeAndRewind:kPDFDisplayTwoUp];
}

- (void)setHorizontalScrolling:(id)sender {
    [self setExtendedDisplayModeAndRewind:kPDFDisplayHorizontalContinuous];
}

- (void)showColorsForThisAnnotation:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    if (annotation)
        [self setCurrentAnnotation:annotation];
    [[NSColorPanel sharedColorPanel] orderFront:sender];
}

- (void)showLinesForThisAnnotation:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    if (annotation)
        [self setCurrentAnnotation:annotation];
    [[[SKLineInspector sharedLineInspector] window] orderFront:sender];
}

- (void)showFontsForThisAnnotation:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    if (annotation)
        [self setCurrentAnnotation:annotation];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:sender];
}

- (void)zoomIn:(id)sender {
    zooming = YES;
    [super zoomIn:sender];
    zooming = NO;
}

- (void)zoomOut:(id)sender {
    zooming = YES;
    [super zoomOut:sender];
    zooming = NO;
}

- (void)setScaleFactor:(CGFloat)scale {
    zooming = YES;
    [super setScaleFactor:scale];
    zooming = NO;
}

- (void)zoomToPhysicalSize:(id)sender {
    [self setPhysicalScaleFactor:1.0];
}

- (BOOL)canZoomIn {
    return [[self document] isLocked] == NO && [super canZoomIn];
}

- (BOOL)canZoomOut {
    return [[self document] isLocked] == NO && [super canZoomOut];
}

- (BOOL)canGoToNextPage {
    return [[self document] isLocked] == NO && [super canGoToNextPage];
}

- (BOOL)canGoToPreviousPage {
    return [[self document] isLocked] == NO && [super canGoToPreviousPage];
}

- (BOOL)canGoToFirstPage {
    return [[self document] isLocked] == NO && [super canGoToFirstPage];
}

- (BOOL)canGoToLastPage {
    return [[self document] isLocked] == NO && [super canGoToLastPage];
}

- (BOOL)canGoBack {
    return [[self document] isLocked] == NO && [super canGoBack];
}

- (BOOL)canGoForward {
    return [[self document] isLocked] == NO && [super canGoForward];
}

- (void)checkSpelling:(id)sender {
    PDFSelection *selection = [self currentSelection];
    PDFPage *page;
    NSUInteger idx, i, first, iMax = [[self document] pageCount];
    BOOL didWrap = NO;
    NSRange range;
    
    if ([selection hasCharacters]) {
        page = [selection safeLastPage];
        idx = [selection safeIndexOfLastCharacterOnPage:page];
        if (idx == NSNotFound)
            idx = 0;
    } else {
        page = [self currentPage];
        idx = 0;
    }
    
    i = first = [page pageIndex];
    while (YES) {
        range = [[NSSpellChecker sharedSpellChecker] checkSpellingOfString:[page string] startingAt:idx language:nil wrap:NO inSpellDocumentWithTag:spellingTag wordCount:NULL];
        if (range.location != NSNotFound) break;
        if (didWrap && i == first) break;
        if (++i >= iMax) {
            i = 0;
            didWrap = YES;
        }
        page = [[self document] pageAtIndex:i];
        idx = 0;
    }
    
    [self setTemporaryToolMode:SKToolModeNone];
    
    if (range.location != NSNotFound) {
        selection = [page selectionForRange:range];
        [self setCurrentSelection:selection];
        [self goToRect:[selection boundsForPage:page] onPage:page];
        [[NSSpellChecker sharedSpellChecker] updateSpellingPanelWithMisspelledWord:[selection string]];
    } else NSBeep();
}

- (void)showGuessPanel:(id)sender {
    [self checkSpelling:sender];
    [[[NSSpellChecker sharedSpellChecker] spellingPanel] orderFront:self];
}

- (void)ignoreSpelling:(id)sender {
    [[NSSpellChecker sharedSpellChecker] ignoreWord:[[sender selectedCell] stringValue] inSpellDocumentWithTag:spellingTag];
}

- (void)nextToolMode:(id)sender {
    [self setToolMode:(toolMode + 1) % TOOL_MODE_COUNT];
}

- (void)moveCurrentAnnotation:(id)sender {
    [self doMoveCurrentAnnotationForKey:NSRightArrowFunctionKey byAmount:[sender tag] ? 10.0 : 1.0];
}

- (void)resizeCurrentAnnotation:(id)sender {
    [self doResizeCurrentAnnotationForKey:NSRightArrowFunctionKey byAmount:[sender tag] ? 10.0 : 1.0];
}

- (void)autoSizeCurrentAnnotation:(id)sender {
    [self doAutoSizeActiveNoteIgnoringWidth:[sender tag]];
}

- (void)changeOnlyAnnotationMode:(id)sender {
    [self setAnnotationMode:[sender tag]];
}

- (void)moveReadingBar:(id)sender {
    [self doMoveReadingBarForKey:NSDownArrowFunctionKey];
}

- (void)resizeReadingBar:(id)sender {
    [self doResizeReadingBarForKey:NSDownArrowFunctionKey];
}

#pragma mark Rewind

- (void)doRewind {
    if ([self isPageAtIndexDisplayed:[rewindPage pageIndex]] == NO) {
        [self goToPage:rewindPage];
        return;
    }
    PDFDisplayMode mode = [self extendedDisplayMode];
    if (mode != kPDFDisplaySinglePage) {
        NSScrollView *scrollView = [self embeddedScrollView];
        NSClipView *clipView = [scrollView contentView];
        NSRect bounds = [clipView bounds];
        CGFloat inset = [clipView contentInsets].top;
        CGFloat leadingInset = [clipView contentInsets].left;
        CGFloat margin = 0.0;
        NSRect docRect = [[scrollView documentView] frame];
        NSRect pageRect = [self convertRect:[self convertRect:[rewindPage boundsForBox:[self displayBox]] fromPage:rewindPage] toView:clipView];
        if ((mode & (kPDFDisplayHorizontalContinuous | kPDFDisplayTwoUp)) && NSWidth(docRect) > NSWidth(bounds)) {
            if ([self displaysPageBreaks])
                margin = [self pageBreakMargins].left;
            bounds.origin.x = fmin(fmax(fmin(NSMidX(pageRect) - 0.5 * NSWidth(bounds), NSMinX(pageRect) - margin - leadingInset), NSMinX(docRect) - leadingInset), NSMaxX(docRect) - NSWidth(bounds));
        }
        if ((mode & kPDFDisplaySinglePageContinuous) && NSHeight(docRect) > NSHeight(bounds) - inset) {
            if ([self displaysPageBreaks])
                margin = [self pageBreakMargins].top;
            if ([clipView isFlipped])
                bounds.origin.y = fmin(fmax(fmin(NSMidY(pageRect) - 0.5 * (NSHeight(bounds) + inset), NSMinY(pageRect) - margin - inset), NSMinY(docRect) - inset), NSMaxY(docRect) - NSHeight(bounds));
            else
                bounds.origin.y = fmax(fmin(fmax(NSMidY(pageRect) - 0.5 * (NSHeight(bounds) - inset), NSMaxY(pageRect) + margin - NSHeight(bounds) + inset), NSMaxY(docRect) - NSHeight(bounds) + inset), NSMinY(docRect));
        }
        [clipView scrollToPoint:bounds.origin];
        [scrollView reflectScrolledClipView:clipView];
    }
}

- (void)doInitialRewind {
    if (rewindPage && [self pageForPoint:SKCenterPoint([self bounds]) nearest:NO] != rewindPage)
        [self doRewind];
}

- (void)doFinalRewind {
    if (rewindPage && [[self currentPage] isEqual:rewindPage] == NO)
        [self doRewind];
    rewindPage = nil;
}

- (BOOL)needsRewind {
    return rewindPage != nil;
}

- (void)setNeedsRewind:(BOOL)flag {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(doInitialRewind) object:nil];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(doFinalRewind) object:nil];
    if (flag) {
        rewindPage = [self currentPage];
        [self performSelector:@selector(doInitialRewind) withObject:nil afterDelay:0.0];
        [self performSelector:@selector(doFinalRewind) withObject:nil afterDelay:0.25];
    } else {
        rewindPage = nil;
    }
}

- (void)goAndScrollToPage:(PDFPage *)page {
    [self setNeedsRewind:NO];
    [super goAndScrollToPage:page];
}

- (void)goToSKDestination:(SKDestination)destination {
    [self setNeedsRewind:NO];
    [super goToSKDestination:destination];
}

#pragma mark Event Handling

#define IS_LEFT_RIGHT_ARROW(eventChar) (eventChar == NSRightArrowFunctionKey || eventChar == NSLeftArrowFunctionKey)
#define IS_UP_DOWN_ARROW(eventChar) (eventChar == NSUpArrowFunctionKey || eventChar == NSDownArrowFunctionKey)
#define IS_ARROW(eventChar) (eventChar == NSRightArrowFunctionKey || eventChar == NSLeftArrowFunctionKey || eventChar == NSUpArrowFunctionKey || eventChar == NSDownArrowFunctionKey)
#define IS_ENTER(eventChar) (eventChar == NSEnterCharacter || eventChar == NSFormFeedCharacter || eventChar == NSNewlineCharacter || eventChar == NSCarriageReturnCharacter)

static inline NSInteger indexOfCharInString(char ch, char *str) {
    char *c = strchr(str, ch);
    return c == NULL ? -1 : (NSInteger)(c - str);
}

- (void)keyDown:(NSEvent *)theEvent
{
    unichar eventChar = [theEvent firstCharacter];
    NSEventModifierFlags modifiers = [theEvent deviceIndependentModifierFlags] & ~NSEventModifierFlagCapsLock;
    NSEventModifierFlags standardModifiers = modifiers & ~NSEventModifierFlagNumericPad & ~NSEventModifierFlagFunction;

    // Normal or fullscreen mode
    if ((eventChar == NSDeleteCharacter || eventChar == NSDeleteFunctionKey) &&
        (standardModifiers == 0)) {
        [self delete:self];
    } else if (([self toolMode] == SKToolModeText || [self toolMode] == SKToolModeNote) && currentAnnotation && editor == nil && IS_ENTER(eventChar) && ((standardModifiers & ~NSEventModifierFlagShift) == 0)) {
        [self editCurrentAnnotation:self];
    } else if (([self toolMode] == SKToolModeText || [self toolMode] == SKToolModeNote) &&
               (eventChar == SKEscapeCharacter) && (standardModifiers == NSEventModifierFlagOption)) {
        [self setCurrentAnnotation:nil];
    } else if (([self toolMode] == SKToolModeText || [self toolMode] == SKToolModeNote) &&
               (eventChar == NSTabCharacter) && (standardModifiers == NSEventModifierFlagOption)) {
        [self selectNextCurrentAnnotation:self];
    // backtab is a bit inconsistent, it seems Shift+Tab gives a Shift-BackTab key event, I would have expected either Shift-Tab (as for the raw event) or BackTab (as for most shift-modified keys)
    } else if (([self toolMode] == SKToolModeText || [self toolMode] == SKToolModeNote) &&
               (((eventChar == NSBackTabCharacter) && ((standardModifiers & ~NSEventModifierFlagShift) == NSEventModifierFlagOption)) ||
                ((eventChar == NSTabCharacter) && (standardModifiers == (NSEventModifierFlagOption | NSEventModifierFlagShift))))) {
        [self selectPreviousCurrentAnnotation:self];
    } else if ([self hasReadingBar] && IS_ARROW(eventChar) && (standardModifiers == moveReadingBarModifiers)) {
        [self doMoveReadingBarForKey:eventChar];
    } else if ([self hasReadingBar] && IS_UP_DOWN_ARROW(eventChar) && (standardModifiers == resizeReadingBarModifiers)) {
        [self doResizeReadingBarForKey:eventChar];
    } else if (IS_LEFT_RIGHT_ARROW(eventChar) && (standardModifiers == (NSEventModifierFlagOption | NSEventModifierFlagCommand))) {
        [self setToolMode:(toolMode + (eventChar == NSRightArrowFunctionKey ? 1 : TOOL_MODE_COUNT - 1)) % TOOL_MODE_COUNT];
    } else if (IS_UP_DOWN_ARROW(eventChar) && (standardModifiers == (NSEventModifierFlagOption | NSEventModifierFlagCommand))) {
        [self setAnnotationMode:(annotationMode + (eventChar == NSDownArrowFunctionKey ? 1 : ANNOTATION_MODE_COUNT - 1)) % ANNOTATION_MODE_COUNT];
    } else if ([currentAnnotation isMovable] && IS_ARROW(eventChar) && ((standardModifiers & ~NSEventModifierFlagShift) == 0)) {
        [self doMoveCurrentAnnotationForKey:eventChar byAmount:(modifiers & NSEventModifierFlagShift) ? 10.0 : 1.0];
    } else if ([currentAnnotation isResizable] && IS_ARROW(eventChar) && (standardModifiers == (NSEventModifierFlagOption | NSEventModifierFlagControl) || standardModifiers == (NSEventModifierFlagShift | NSEventModifierFlagControl))) {
        [self doResizeCurrentAnnotationForKey:eventChar byAmount:(modifiers & NSEventModifierFlagShift) ? 10.0 : 1.0];
    // with some keyboard layouts, e.g. Japanese, the '=' character requires Shift
    } else if ([currentAnnotation isResizable] && [currentAnnotation isLine] == NO && [currentAnnotation isInk] == NO && (eventChar == '=') && ((modifiers & ~(NSEventModifierFlagOption | NSEventModifierFlagShift)) == NSEventModifierFlagControl)) {
        [self doAutoSizeActiveNoteIgnoringWidth:(modifiers & NSEventModifierFlagOption) != 0];
    } else if ([self toolMode] == SKToolModeNote && (modifiers == 0) && (eventChar >= 'b' && eventChar <= 'u' && indexOfCharInString(eventChar, "tncbhuslf") != -1)) {
        [self setAnnotationMode:indexOfCharInString(eventChar, "tncbhuslf")];
    } else if ((eventChar == '?') && ((modifiers & ~NSEventModifierFlagShift) == 0)) {
        [self showHelpMenu];
    } else if ((eventChar == NSLeftArrowFunctionKey) && (standardModifiers == NSEventModifierFlagOption) && [self canGoToFirstPage]) {
        [self goToFirstPage:nil];
    } else if ((eventChar == NSRightArrowFunctionKey) && (standardModifiers == NSEventModifierFlagOption) && [self canGoToLastPage]) {
        [self goToLastPage:nil];
    } else if ((eventChar == NSLeftArrowFunctionKey) && (standardModifiers == NSEventModifierFlagCommand) && [self canGoToPreviousPage]) {
        [self goToPreviousPage:nil];
    } else if ((eventChar == NSRightArrowFunctionKey) && (standardModifiers == NSEventModifierFlagCommand) && [self canGoToNextPage]) {
        [self goToNextPage:nil];
    } else if ([typeSelectHelper handleEvent:theEvent] == NO) {
        [super keyDown:theEvent];
    }
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent {
    if ([self hasReadingBar]) {
        unichar eventChar = [theEvent firstCharacter];
        if (IS_UP_DOWN_ARROW(eventChar)) {
            NSEventModifierFlags modifiers = [theEvent deviceIndependentModifierFlags] & ~NSEventModifierFlagNumericPad & ~NSEventModifierFlagFunction;
            if (modifiers == moveReadingBarModifiers) {
                [self doMoveReadingBarForKey:eventChar];
                return YES;
            }
        }
    }
    return [super performKeyEquivalent:theEvent];
}

- (void)performMarkupToolMode {
    if (toolMode == SKToolModeNote && IS_MARKUP(annotationMode) && [[self currentSelection] hasCharacters])
        [self addMarkupAnnotationWithType:annotationMode selection:nil];
}

#define IS_TABLET_EVENT(theEvent, deviceType) (([theEvent subtype] == NSEventSubtypeTabletProximity || [theEvent subtype] == NSEventSubtypeTabletPoint) && [NSEvent currentPointingDeviceType] == deviceType)

- (void)mouseDown:(NSEvent *)theEvent{
    if ([currentAnnotation isLink])
        [self setCurrentAnnotation:nil];
    
    // 10.6 does not automatichally make us firstResponder, that's annoying
    // but we don't want an edited text note to stop editing when we're resizing it
    if ([[self window] firstResponderIsDescendantOf:self] == NO)
        [[self window] makeFirstResponder:self];
    
    NSEventModifierFlags modifiers = [theEvent deviceIndependentModifierFlags] & ~NSEventModifierFlagCapsLock;
    PDFAreaOfInterest area = [self areaOfInterestForMouse:theEvent];
    PDFAnnotation *wasCurrentAnnotation = currentAnnotation;
    
    if ((modifiers & NSEventModifierFlagCommand) != 0)
        [self setTemporaryToolMode:SKToolModeNone];
    
    if ([[self document] isLocked]) {
        [self setTemporaryToolMode:SKToolModeNone];
        [super mouseDown:theEvent];
    } else if (modifiers == NSEventModifierFlagCommand) {
        BOOL wantsLoupe = [loupeController hide];
        [self doSelectSnapshotWithEvent:theEvent];
        if (wantsLoupe)
            [loupeController update];
    } else if (modifiers == (NSEventModifierFlagCommand | NSEventModifierFlagShift)) {
        BOOL wantsLoupe = [loupeController hide];
        [self doPdfsyncWithEvent:theEvent];
        if (wantsLoupe)
            [loupeController update];
    } else if (modifiers == (NSEventModifierFlagCommand | NSEventModifierFlagOption)) {
        BOOL wantsLoupe = [loupeController hide];
        [self doMarqueeZoomWithEvent:theEvent];
        if (wantsLoupe)
            [loupeController update];
    } else if ((area & SKReadingBarArea) && (area & kPDFLinkArea) == 0) {
        [self setTemporaryToolMode:SKToolModeNone];
        BOOL wantsLoupe = [loupeController hide];
        if ((area & (SKResizeUpDownArea | SKResizeLeftRightArea | SKResizeRightArea | SKResizeUpArea | SKResizeLeftArea | SKResizeDownArea)))
            [self doResizeReadingBarWithEvent:theEvent];
        else
            [self doDragReadingBarWithEvent:theEvent];
        if (wantsLoupe)
            [loupeController update];
    } else if ((area & kPDFPageArea) == 0) {
        [self doDragContentWithEvent:theEvent];
    } else if (temporaryToolMode != SKToolModeNone) {
        BOOL wantsLoupe = [loupeController hide];
        BOOL delayTempToolMode = NO;
        if (temporaryToolMode == SKToolModeZoom) {
            [self doMarqueeZoomWithEvent:theEvent];
        } else if (temporaryToolMode == SKToolModeSnapshot) {
            [self doSelectSnapshotWithEvent:theEvent];
        } else if (temporaryToolMode == SKToolModeInk) {
            [self doDrawFreehandNoteWithEvent:theEvent];
        } else if (IS_MARKUP_TOOL(temporaryToolMode) == NO) {
            [self setCurrentAnnotation:nil];
            [self doDragAnnotationWithEvent:theEvent];
        } else {
            [self setCurrentAnnotation:nil];
            [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(performTemporaryMarkupToolMode) object:nil];
            delayTempToolMode = [theEvent clickCount] < 3 && [NSApp willDragMouse] == NO;
            [super mouseDown:theEvent];
            if (delayTempToolMode)
                [self performSelector:@selector(performTemporaryMarkupToolMode) withObject:nil afterDelay:[NSEvent doubleClickInterval]];
            else if ([[self currentSelection] hasCharacters])
                [self addMarkupAnnotationWithType:NOTE_TYPE_FROM_TEMP_TOOL_MODE(temporaryToolMode) selection:nil];
        }
        if (delayTempToolMode == NO)
            [self setTemporaryToolMode:SKToolModeNone];
        if (wantsLoupe)
            [loupeController update];
    } else if (toolMode == SKToolModeMove) {
        [self setCurrentSelection:nil];
        if ((area & kPDFLinkArea))
            [super mouseDown:theEvent];
        else
            [self doDragContentWithEvent:theEvent];
    } else if (toolMode == SKToolModeSelect) {
        [self setCurrentSelection:nil];                
        [self doSelectWithEvent:theEvent];
    } else if (toolMode == SKToolModeMagnify) {
        [self setCurrentSelection:nil];
        [self doMagnifyWithEvent:theEvent];
    } else if ([self canAddNotes] && IS_TABLET_EVENT(theEvent, NSPointingDeviceTypeEraser)) {
        [self doEraseAnnotationsWithEvent:theEvent];
    } else if ([self doSelectAnnotationWithEvent:theEvent]) {
        if ([currentAnnotation isLink]) {
            [self doClickLinkWithEvent:theEvent];
        } else if ([theEvent clickCount] == 1 && [currentAnnotation isText] && currentAnnotation == wasCurrentAnnotation && [NSApp willDragMouse] == NO) {
            [self editTextNoteWithEvent:theEvent];
        } else if ([theEvent clickCount] == 2 && [currentAnnotation isEditable]) {
            if ([self doDragMouseWithEvent:theEvent] == NO)
                [self editCurrentAnnotation:nil];
        } else if ([currentAnnotation isMovable]) {
            [self doDragAnnotationWithEvent:theEvent];
        } else {
            [self doDragMouseWithEvent:theEvent];
        }
    } else if (toolMode == SKToolModeNote && [self canAddNotes] && IS_MARKUP(annotationMode) == NO) {
        if ((area & kPDFLinkArea) != 0 && [NSApp willDragMouse] == NO) {
            [super mouseDown:theEvent];
        } else if (annotationMode == SKNoteTypeInk) {
            [self doDrawFreehandNoteWithEvent:theEvent];
        } else {
            [self setCurrentAnnotation:nil];
            [self doDragAnnotationWithEvent:theEvent];
        }
    } else if ((area & SKDragArea)) {
        [self setCurrentAnnotation:nil];
        [self doDragContentWithEvent:theEvent];
    } else if ([self doDragSelectedTextWithEvent:theEvent] == NO) {
        [self setCurrentAnnotation:nil];
        if (toolMode == SKToolModeNote && IS_MARKUP(annotationMode) && [self canAddNotes]) {
            [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(performMarkupToolMode) object:nil];
            BOOL mayMultiClick = [theEvent clickCount] == 2 && [NSApp willDragMouse] == NO;
            [super mouseDown:theEvent];
            if ([[self currentSelection] hasCharacters]) {
                if (mayMultiClick)
                    [self performSelector:@selector(performMarkupToolMode) withObject:nil afterDelay:[NSEvent doubleClickInterval]];
                else
                    [self addMarkupAnnotationWithType:annotationMode selection:nil];
            }
        } else {
            [super mouseDown:theEvent];
        }
    }
}

- (void)mouseMoved:(NSEvent *)theEvent {
    [super mouseMoved:theEvent];
    
    if (toolMode == SKToolModeMagnify && loupeController) {
        [loupeController update];
    } else if ([currentAnnotation isLink]) {
        [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
        [self setCurrentAnnotation:nil];
    }
}

- (void)otherMouseDown:(NSEvent *)theEvent {
    [super otherMouseDown:theEvent];
    NSInteger button = [theEvent buttonNumber];
    if (button == 3 && [self canGoBack])
        [self goBack:nil];
    else if (button == 4 && [self canGoForward])
        [self goForward:nil];
}

- (void)flagsChanged:(NSEvent *)theEvent {
    [super flagsChanged:theEvent];
    [self setCursorForMouse:nil];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *menu = [super menuForEvent:theEvent];
    NSMenu *submenu;
    NSMenuItem *item;
    NSInteger i = 0;
    
    if ([[menu itemAtIndex:0] view] != nil) {
        [menu removeItemAtIndex:0];
        if ([[menu itemAtIndex:0] isSeparatorItem])
            [menu removeItemAtIndex:0];
    }
    
    static NSSet *annotationActions = nil;
    if (annotationActions == nil)
        annotationActions = [[NSSet alloc] initWithObjects:@"_removeNote:", @"_removeMarkup:", nil];
    while ([menu numberOfItems] > 0) {
        item = [menu itemAtIndex:0];
        if ([item isSeparatorItem] || [annotationActions containsObject:NSStringFromSelector([item action])])
            [menu removeItemAtIndex:0];
        else
            break;
    }
    
    // On Leopard the selection is automatically set. In some cases we never want a selection though.
    if (toolMode != SKToolModeText && [[self currentSelection] hasCharacters]) {
        static NSSet *selectionActions = nil;
        if (selectionActions == nil)
            selectionActions = [[NSSet alloc] initWithObjects:@"_searchInSpotlight:", @"_searchInGoogle:", @"_searchInDictionary:", @"_revealSelection:", nil];
        [self setCurrentSelection:nil];
        BOOL allowsSeparator = NO;
        while ([menu numberOfItems] > i) {
            item = [menu itemAtIndex:i];
            if ([item isSeparatorItem]) {
                if (allowsSeparator) {
                    i++;
                    allowsSeparator = NO;
                } else {
                    [menu removeItemAtIndex:i];
                }
            } else if ([self validateMenuItem:item] == NO || [selectionActions containsObject:NSStringFromSelector([item action])]) {
                [menu removeItemAtIndex:i];
            } else {
                i++;
                allowsSeparator = YES;
            }
        }
    }
    
    NSValue *pointValue = [NSValue valueWithPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];
    
    i = [menu indexOfItemWithTarget:self andAction:@selector(copy:)];
    if (i != -1) {
        [menu removeItemAtIndex:i];
        if ([menu numberOfItems] > i && [[menu itemAtIndex:i] isSeparatorItem] && (i == 0 || [[menu itemAtIndex:i - 1] isSeparatorItem]))
            [menu removeItemAtIndex:i];
        if (i > 0 && i == [menu numberOfItems] && [[menu itemAtIndex:i - 1] isSeparatorItem])
            [menu removeItemAtIndex:i - 1];
    }
    
    i = [menu indexOfItemWithTarget:self andAction:NSSelectorFromString(@"_setActualSize:")];
    if (i != -1) {
        item = [menu insertItemWithTitle:NSLocalizedString(@"Physical Size", @"Menu item title") action:@selector(zoomToPhysicalSize:) target:self atIndex:i + 1];
        [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
        [item setAlternate:YES];
    }
    
    i = [menu indexOfItemWithTarget:self andAction:NSSelectorFromString(@"_setDoublePageScrolling:")];
    if (i != -1) {
        [menu insertItem:[NSMenuItem separatorItem] atIndex:i + 1];
        item = [menu insertItemWithTitle:NSLocalizedString(@"Horizontal Continuous", @"Menu item title") action:@selector(setHorizontalScrolling:) target:self atIndex:i + 1];
    }
    
    [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
    
    item = [menu insertItemWithSubmenuAndTitle:NSLocalizedString(@"Tools", @"Menu item title") atIndex:0];
    submenu = [item submenu];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Text", @"Menu item title") action:@selector(changeToolMode:) target:self tag:SKToolModeText];

    [submenu addItemWithTitle:NSLocalizedString(@"Scroll", @"Menu item title") action:@selector(changeToolMode:) target:self tag:SKToolModeMove];

    [submenu addItemWithTitle:NSLocalizedString(@"Magnify", @"Menu item title") action:@selector(changeToolMode:) target:self tag:SKToolModeMagnify];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Select", @"Menu item title") action:@selector(changeToolMode:) target:self tag:SKToolModeSelect];
    
    [submenu addItem:[NSMenuItem separatorItem]];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeFreeText];

    [submenu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeAnchored];

    [submenu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeCircle];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeSquare];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeHighlight];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeUnderline];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeStrikeOut];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeLine];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKNoteTypeInk];
    
    [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
    
    item = [menu insertItemWithTitle:NSLocalizedString(@"Take Snapshot", @"Menu item title") action:@selector(takeSnapshot:) target:self atIndex:0];
    [item setRepresentedObject:pointValue];
    
    if ([self canSelectNote]) {
        
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        
        item = [menu insertItemWithSubmenuAndTitle:NSLocalizedString(@"New Note or Highlight", @"Menu item title") atIndex:0];
        submenu = [item submenu];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") action:@selector(addAnnotationForPoint:) target:self tag:SKNoteTypeFreeText];
        [item setRepresentedObject:pointValue];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") action:@selector(addAnnotationForPoint:) target:self tag:SKNoteTypeAnchored];
        [item setRepresentedObject:pointValue];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") action:@selector(addAnnotationForPoint:) target:self tag:SKNoteTypeCircle];
        [item setRepresentedObject:pointValue];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") action:@selector(addAnnotationForPoint:) target:self tag:SKNoteTypeSquare];
        [item setRepresentedObject:pointValue];
        
        if ([[self currentSelection] hasCharacters]) {
            item = [submenu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") action:@selector(addAnnotationForPoint:) target:self tag:SKNoteTypeHighlight];
            [item setRepresentedObject:pointValue];
            
            item = [submenu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") action:@selector(addAnnotationForPoint:) target:self tag:SKNoteTypeUnderline];
            [item setRepresentedObject:pointValue];
            
            item = [submenu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") action:@selector(addAnnotationForPoint:) target:self tag:SKNoteTypeStrikeOut];
            [item setRepresentedObject:pointValue];
        }
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") action:@selector(addAnnotationForPoint:) target:self tag:SKNoteTypeLine];
        [item setRepresentedObject:pointValue];
        
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        
        NSPoint point = NSZeroPoint;
        PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:YES];
        PDFAnnotation *annotation = nil;
        
        if (page) {
            annotation = [page annotationAtPoint:point];
            if ([annotation isSkimNote] == NO)
                annotation = nil;
        }
        
        if (annotation) {
            SKColorMenuView *menuView = [[SKColorMenuView alloc] initWithAnnotation:annotation];
            item = [menu insertItemWithTitle:@"" action:NULL target:nil atIndex:0];
            [item setView:menuView];
            
            [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
            
            if ((annotation != currentAnnotation || [NSFontPanel sharedFontPanelExists] == NO || [[NSFontPanel sharedFontPanel] isVisible] == NO) &&
                [annotation isText]) {
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Note Font", @"Menu item title") stringByAppendingEllipsis] action:@selector(showFontsForThisAnnotation:) target:self atIndex:0];
                [item setRepresentedObject:annotation];
            }
            
            if ((annotation != currentAnnotation || [SKLineInspector sharedLineInspectorExists] == NO || [[[SKLineInspector sharedLineInspector] window] isVisible] == NO) &&
                [annotation isMarkup] == NO && [annotation isNote] == NO) {
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Note Line", @"Menu item title") stringByAppendingEllipsis] action:@selector(showLinesForThisAnnotation:) target:self atIndex:0];
                [item setRepresentedObject:annotation];
            }
            
            if (annotation != currentAnnotation || [NSColorPanel sharedColorPanelExists] == NO || [[NSColorPanel sharedColorPanel] isVisible] == NO) {
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Note Color", @"Menu item title") stringByAppendingEllipsis] action:@selector(showColorsForThisAnnotation:) target:self atIndex:0];
                [item setRepresentedObject:annotation];
            }
            
            if ([self isEditingAnnotation:annotation] == NO && [annotation isEditable]) {
                item = [menu insertItemWithTitle:NSLocalizedString(@"Edit Note", @"Menu item title") action:@selector(editThisAnnotation:) target:self atIndex:0];
                [item setRepresentedObject:annotation];
            }
            
            item = [menu insertItemWithTitle:NSLocalizedString(@"Remove Note", @"Menu item title") action:@selector(removeThisAnnotation:) target:self atIndex:0];
            [item setRepresentedObject:annotation];
        } else if ([currentAnnotation isSkimNote]) {
            SKColorMenuView *menuView = [[SKColorMenuView alloc] initWithAnnotation:currentAnnotation];
            item = [menu insertItemWithTitle:@"" action:NULL target:nil atIndex:0];
            [item setView:menuView];
            
            [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
            
            if (([NSFontPanel sharedFontPanelExists] == NO || [[NSFontPanel sharedFontPanel] isVisible] == NO) &&
                [currentAnnotation isText]) {
                [menu insertItemWithTitle:[NSLocalizedString(@"Note Font", @"Menu item title") stringByAppendingEllipsis] action:@selector(showFontsForThisAnnotation:) target:self atIndex:0];
            }
            
            if (([SKLineInspector sharedLineInspectorExists] == NO || [[[SKLineInspector sharedLineInspector] window] isVisible] == NO) &&
                [currentAnnotation isMarkup] == NO && [currentAnnotation isNote] == NO) {
                [menu insertItemWithTitle:[NSLocalizedString(@"Current Note Line", @"Menu item title") stringByAppendingEllipsis] action:@selector(showLinesForThisAnnotation:) target:self atIndex:0];
            }
            
            if ([NSColorPanel sharedColorPanelExists] == NO || [[NSColorPanel sharedColorPanel] isVisible] == NO) {
                [menu insertItemWithTitle:[NSLocalizedString(@"Current Note Color", @"Menu item title") stringByAppendingEllipsis] action:@selector(showColorsForThisAnnotation:) target:self atIndex:0];
            }
            
            if (editor == nil && [currentAnnotation isEditable]) {
                [menu insertItemWithTitle:NSLocalizedString(@"Edit Current Note", @"Menu item title") action:@selector(editCurrentAnnotation:) target:self atIndex:0];
            }
            
            [menu insertItemWithTitle:NSLocalizedString(@"Remove Current Note", @"Menu item title") action:@selector(removeCurrentAnnotation:) target:self atIndex:0];
        }
        
        if ([[NSPasteboard generalPasteboard] canReadObjectForClasses:@[[PDFAnnotation class], [NSString class], [NSImage class]] options:@{}]) {
            [menu insertItemWithTitle:NSLocalizedString(@"Paste", @"Menu item title") action:@selector(paste:) keyEquivalent:@"" atIndex:0];
            item = [menu insertItemWithTitle:NSLocalizedString(@"Paste", @"Menu item title") action:@selector(alternatePaste:) keyEquivalent:@"" atIndex:1];
            [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
            [item setAlternate:YES];
        }
        
        if ([currentAnnotation isMovable])
            [menu insertItemWithTitle:NSLocalizedString(@"Cut", @"Menu item title") action:@selector(cut:) keyEquivalent:@"" atIndex:0];
        if (([currentAnnotation isMovable]) || [[self currentSelection] hasCharacters])
            [menu insertItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copy:) keyEquivalent:@"" atIndex:0];
        
        if ([[menu itemAtIndex:0] isSeparatorItem])
            [menu removeItemAtIndex:0];
        
    } else if ((toolMode == SKToolModeSelect && NSIsEmptyRect(selectionRect) == NO) || ([self toolMode] == SKToolModeText && [[self currentSelection] hasCharacters])) {
        
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        
        [menu insertItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copy:) keyEquivalent:@"" atIndex:0];
        
    }
    
    return menu;
}

- (void)magnifyWheel:(NSEvent *)theEvent {
    CGFloat dy = [theEvent deltaY];
    dy = dy > 0 ? fmin(0.2, dy) : fmax(-0.2, dy);
    [self setScaleFactor:[self scaleFactor] * exp(0.5 * dy)];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    NSTrackingArea *eventArea = [theEvent trackingArea];
    PDFAnnotation *annotation;
    if ([eventArea owner] == self && (annotation = [[eventArea userInfo] objectForKey:SKAnnotationKey])) {
        [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:annotation scale:[self scaleFactor] atPoint:NSZeroPoint];
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        [super mouseEntered:theEvent];
    }
}
 
- (void)mouseExited:(NSEvent *)theEvent {
    NSTrackingArea *eventArea = [theEvent trackingArea];
    PDFAnnotation *annotation;
    if ([eventArea owner] == self && (annotation = [[eventArea userInfo] objectForKey:SKAnnotationKey])) {
        if ([annotation isEqual:[[SKImageToolTipWindow sharedToolTipWindow] currentImageContext]])
            [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
    } else {
        if (([eventArea options] & NSTrackingInVisibleRect)) {
            [[NSCursor arrowCursor] set];
            if (toolMode == SKToolModeMagnify)
                [loupeController hide];
        }
        if ([[SKPDFView superclass] instancesRespondToSelector:_cmd])
            [super mouseExited:theEvent];
    }
}

- (void)rotateWithEvent:(NSEvent *)theEvent {
    NSEventPhase phase = [theEvent phase];
    if (phase == NSEventPhaseBegan) {
        PDFPage *page = [self pageAndPoint:NULL forEvent:theEvent nearest:YES];
        gestureRotation = 0.0;
        gesturePageIndex = [(page ?: [self currentPage]) pageIndex];
    } else if (phase == NSEventPhaseMayBegin) {
        gestureRotation = 0.0;
        gesturePageIndex = NSNotFound;
        return;
    } else if (phase == NSEventPhaseNone || gesturePageIndex == NSNotFound) {
        return;
    }
    NSInteger prevRotation = 90 * (NSInteger)round(gestureRotation / 90.0);
    gestureRotation -= [theEvent rotation];
    NSInteger rotation = 90 * (NSInteger)round(gestureRotation / 90.0);
    if (((rotation - prevRotation) % 360)) {
        PDFPage *page = [[self document] pageAtIndex:gesturePageIndex];
        [page setRotation:[page rotation] + rotation - prevRotation];
    }
    if (phase == NSEventPhaseEnded) {
        if ((rotation % 360) && [[self delegate] respondsToSelector:@selector(PDFView:didRotatePageAtIndex:by:)])
            [[self delegate] PDFView:self didRotatePageAtIndex:gesturePageIndex by:rotation % 360];
        gestureRotation = 0.0;
        gesturePageIndex = NSNotFound;
    } else if (phase == NSEventPhaseCancelled) {
        if (gesturePageIndex != NSNotFound) {
            PDFPage *page = [[self document] pageAtIndex:gesturePageIndex];
            [page setRotation:[page rotation] - rotation];
        }
        gestureRotation = 0.0;
        gesturePageIndex = NSNotFound;
    }
}

- (void)performAction:(PDFAction *)action {
    if ([[self delegate] respondsToSelector:@selector(PDFView:performAction:)] == NO || [[self delegate] PDFView:self performAction:action] == NO)
        [super performAction:action];
}

#pragma mark NSDraggingDestination protocol

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSDragOperation dragOp = NSDragOperationNone;
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([self canAddNotes]&& ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]] || [pboard canReadObjectForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES, NSPasteboardURLReadingContentsConformToTypesKey:[NSImage imageTypes]}])) {
        return [self draggingUpdated:sender];
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        dragOp = [super draggingEntered:sender];
    }
    return dragOp;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSDragOperation dragOp = NSDragOperationNone;
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([self canAddNotes] && [pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]]) {
        NSPoint location = [self convertPoint:[sender draggingLocation] fromView:nil];
        PDFPage *page = [self pageForPoint:location nearest:NO];
        if (page) {
            location = [self convertPoint:location toPage:page];
            for (PDFAnnotation *annotation in [[page annotations] reverseObjectEnumerator]) {
                if ([annotation hitTest:location] &&
                    ([annotation hasBorder] || [pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor]])) {
                    if (annotation != [highlightLayerController annotation]) {
                        if (highlightLayerController == nil)
                            [self makeHighlightLayerForType:SKLayerTypeRect];
                        [highlightLayerController setAnnotation:annotation];
                        [highlightLayerController setRect:NSInsetRect([self convertRect:[annotation bounds] fromPage:[annotation page]], -1.0, -1.0)];
                    }
                    dragOp = NSDragOperationGeneric;
                    break;
                }
            }
        }
        if (dragOp == NSDragOperationNone)
            [self removeHighlightLayer];
    } else if ([self canAddNotes] && [pboard canReadObjectForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES, NSPasteboardURLReadingContentsConformToTypesKey:[NSImage imageTypes]}]) {
        if (([[sender draggingSource] respondsToSelector:@selector(window)] == NO || [[sender draggingSource] window] != [self window]) && [self pageForPoint:[self convertPoint:[sender draggingLocation] fromView:nil] nearest:NO])
            dragOp = NSDragOperationGeneric;
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        dragOp = [super draggingUpdated:sender];
    }
    return dragOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([self canAddNotes] && ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]] || [pboard canReadObjectForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES, NSPasteboardURLReadingContentsConformToTypesKey:[NSImage imageTypes]}])) {
        [self removeHighlightLayer];
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        [super draggingExited:sender];
    }
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    BOOL performedDrag = NO;
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([self canAddNotes] && [pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]]) {
        PDFAnnotation *annotation = [highlightLayerController annotation];
        if (annotation) {
            if ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor]]) {
                BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
                BOOL isAlt = ([NSEvent modifierFlags] & NSEventModifierFlagOption) != 0;
                [annotation setColor:[NSColor colorFromPasteboard:pboard] alternate:isAlt updateDefaults:isShift];
                performedDrag = YES;
            } else if ([annotation hasBorder]) {
                [pboard types];
                NSDictionary *dict = [pboard propertyListForType:SKPasteboardTypeLineStyle];
                NSNumber *number;
                if ((number = [dict objectForKey:SKLineWellLineWidthKey]))
                    [annotation setLineWidth:[number doubleValue]];
                [annotation setDashPattern:[dict objectForKey:SKLineWellDashPatternKey]];
                if ((number = [dict objectForKey:SKLineWellStyleKey]))
                    [annotation setBorderStyle:[number integerValue]];
                if ([annotation isLine]) {
                    if ((number = [dict objectForKey:SKLineWellStartLineStyleKey]))
                        [annotation setStartLineStyle:[number integerValue]];
                    if ((number = [dict objectForKey:SKLineWellEndLineStyleKey]))
                        [annotation setEndLineStyle:[number integerValue]];
                }
                performedDrag = YES;
            }
            [self removeHighlightLayer];
        }
    } else if ([self canAddNotes] && [pboard canReadObjectForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES, NSPasteboardURLReadingContentsConformToTypesKey:[NSImage imageTypes]}]) {
        NSPoint location = [self convertPoint:[sender draggingLocation] fromView:nil];
        PDFPage *page = [self pageForPoint:location nearest:NO];
        if (page) {
            location = [self convertPoint:location toPage:page];
            NSURL *fileURL =  [[pboard readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey:@YES, NSPasteboardURLReadingContentsConformToTypesKey:[NSImage imageTypes]}] firstObject];
            NSImage *image = fileURL ? [[NSImage alloc] initWithContentsOfURL:fileURL] : nil;
            if (image) {
                NSRect bounds = SKRectFromCenterAndSize(location, [image size]);
                bounds.origin = SKIntegralPoint(bounds.origin);
                bounds = SKConstrainRect(bounds, [page boundsForBox:[self displayBox]]);
                
                PDFAnnotation *newAnnotation = [PDFAnnotation newSkimNoteWithBounds:bounds forType:SKNNoteString];
                [(SKNPDFAnnotationNote *)newAnnotation setImage:image];
                [(SKNPDFAnnotationNote *)newAnnotation setExtendedIconType:kSKNPDFTextAnnotationIconImage];
                
                [self addAnnotation:newAnnotation toPage:page select:YES];
                
                performedDrag = YES;
            }
        }
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        performedDrag = [super performDragOperation:sender];
    }
    return performedDrag;
}

#pragma mark Services

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types {
    if ([self toolMode] == SKToolModeSelect && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound) {
        NSMutableArray *writeTypes = [NSMutableArray array];
        NSString *pdfType = nil;
        NSData *pdfData = nil;
        NSString *tiffType = nil;
        NSData *tiffData = nil;
        NSRect selRect = NSIntegralRect(selectionRect);
        
        // Unfortunately only old PboardTypes are requested rather than preferred UTIs, even if we only validate and the Service only requests UTIs, so we need to support both
        if ([[self document] allowsSaving] && [[self document] isLocked] == NO) {
            if ([types containsObject:NSPasteboardTypePDF])
                pdfType = NSPasteboardTypePDF;
            else if ([types containsObject:NSPDFPboardType])
                pdfType = NSPDFPboardType;
            if (pdfType && (pdfData = [[self selectToolPage] PDFDataForRect:selRect]))
                [writeTypes addObject:pdfType];
        }
        if ([types containsObject:NSPasteboardTypeTIFF])
            tiffType = NSPasteboardTypeTIFF;
        else if ([types containsObject:NSTIFFPboardType])
            tiffType = NSTIFFPboardType;
        if (tiffType && (tiffData = [[self selectToolPage] TIFFDataForRect:selRect]))
            [writeTypes addObject:tiffType];
        if ([writeTypes count] > 0) {
            [pboard declareTypes:writeTypes owner:nil];
            if (pdfData)
                [pboard setData:pdfData forType:pdfType];
            if (tiffData)
                [pboard setData:tiffData forType:tiffType];
            return YES;
        }
    }
    if ([[self currentSelection] hasCharacters]) {
        if ([types containsObject:NSPasteboardTypeRTF] || [types containsObject:NSRTFPboardType]) {
            [pboard clearContents];
            [pboard writeObjects:@[[[self currentSelection] attributedString]]];
            return YES;
        } else if ([types containsObject:NSPasteboardTypeString] || [types containsObject:NSStringPboardType]) {
            [pboard clearContents];
            [pboard writeObjects:@[[[self currentSelection] string]]];
            return YES;
        }
    }
    if ([[SKPDFView superclass] instancesRespondToSelector:_cmd])
        return [super writeSelectionToPasteboard:pboard types:types];
    return NO;
}

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType {
    if ([self toolMode] == SKToolModeSelect && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound && returnType == nil && 
        (([[self document] allowsSaving] && [[self document] isLocked] == NO && [sendType isEqualToString:NSPasteboardTypePDF]) || [sendType isEqualToString:NSPasteboardTypeTIFF])) {
        return self;
    }
    if ([[self currentSelection] hasCharacters] && returnType == nil && ([sendType isEqualToString:NSPasteboardTypeString] || [sendType isEqualToString:NSPasteboardTypeRTF])) {
        return self;
    }
    return [super validRequestorForSendType:sendType returnType:returnType];
}

#pragma mark Annotation management

- (void)addAnnotation:(PDFAnnotation *)annotation toPage:(PDFPage *)page select:(BOOL)shouldSelect {
    [annotation registerUserName];
    [self commitEditing];
    [self beginNewUndoGroupIfNeeded];
    [[self document] addAnnotation:annotation toPage:page];
    [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];
    if (shouldSelect && IS_TEXT_OR_NOTE_TOOL)
        [self setCurrentAnnotation:annotation];
}

- (void)addAnnotations:(NSArray *)annotationsAndPages {
    PDFAnnotation *annotation = nil;
    [self commitEditing];
    [self beginNewUndoGroupIfNeeded];
    for (NSArray *annotationAndPage in annotationsAndPages) {
        annotation = [annotationAndPage firstObject];
        [annotation registerUserName];
        [[self document] addAnnotation:annotation toPage:[annotationAndPage lastObject]];
    }
    [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];
    if (IS_TEXT_OR_NOTE_TOOL)
        [self setCurrentAnnotation:annotation];
}

- (void)removeAnnotation:(PDFAnnotation *)annotation {
    [[self document] removeAnnotation:annotation];
    [[self undoManager] setActionName:NSLocalizedString(@"Remove Note", @"Undo action name")];
}

- (PDFAnnotation *)joinAnnotationToCurrentAnnotation:(PDFAnnotation *)annotation {
    PDFAnnotation *newAnnotation = nil;
    PDFPage *page = [currentAnnotation page];
    if ([currentAnnotation isMarkup]) {
        NSString *type = [currentAnnotation type];
        PDFSelection *sel = [currentAnnotation selection];
        PDFSelection *newSel = [annotation selection];
        BOOL copyText = [[NSUserDefaults standardUserDefaults] integerForKey:SKDisableUpdateContentsFromEnclosedTextKey] < 2;
        NSString *string1 = [currentAnnotation string];
        NSString *string2 = [annotation string];
        NSString *string = nil;
        if ([string1 length] > 0 && [string2 length] > 0) {
            if ([sel safeIndexOfFirstCharacterOnPage:page] > (copyText ? [newSel safeIndexOfLastCharacterOnPage:page] : [newSel safeIndexOfFirstCharacterOnPage:page]))
               string = [NSString stringWithFormat:@"%@ %@", string2, string1];
            else if (copyText == NO || [newSel safeIndexOfFirstCharacterOnPage:page] > [sel safeIndexOfLastCharacterOnPage:page])
                string = [NSString stringWithFormat:@"%@ %@", string1, string2];
        }
        [sel addSelection:newSel];
        if (string == nil) {
            if (copyText)
                string = [sel cleanedString];
            else if ([string1 length])
                string = string1;
            else if ([string2 length])
                string = string2;
        }
        
        newAnnotation = [PDFAnnotation newSkimNoteWithSelection:sel onPage:page forType:type];
        if ([string length] > 0)
            [newAnnotation setString:string];
    } else if ([currentAnnotation isInk]) {
        NSArray *paths = [[currentAnnotation pagePaths] arrayByAddingObjectsFromArray:[annotation pagePaths]];
        NSString *string1 = [currentAnnotation string];
        NSString *string2 = [annotation string];
        
        newAnnotation = [PDFAnnotation newSkimNoteWithPaths:paths];
        if ([string1 length] > 0 || [string2 length] > 0)
            [newAnnotation setString:[string2 length] == 0 ? string1 : [string1 length] == 0 ? string2 : [NSString stringWithFormat:@"%@ %@", string1, string2]];
        [newAnnotation setBorder:[[currentAnnotation border] copy]];
    } else {
        return nil;
    }
    [newAnnotation setColor:[currentAnnotation color]];
    [newAnnotation registerUserName];
    [[self document] removeAnnotation:currentAnnotation];
    [[self document] removeAnnotation:annotation];
    [[self document] addAnnotation:newAnnotation toPage:page];
    [[self undoManager] setActionName:NSLocalizedString(@"Join Notes", @"Undo action name")];
    return newAnnotation;
}

// y=primaryOutset(x) approximately solves x*secondaryOutset(y)=y
// y=cubrt(1/2x^2)+..., x->0; y=sqrt(2)-1+1/2(sqrt(2)-1)(x-1)+..., x->1
// 0.436947024419157 = 4/3cbrt(1/2)-3/2(sqrt(2)-1)
// 0.057460060808152 = 1/3cbrt(1/2)-1/2(sqrt(2)-1)
static inline CGFloat primaryOutset(CGFloat x) {
    return cbrt(0.5 * x * x) - 0.436947024419157 * x + 0.057460060808152 * x * x;
}

// an ellipse outset by 1/2*w*x and 1/2*h*secondaryOutset(x) circumscribes a rect with size {w,h} for any x
static inline CGFloat secondaryOutset(CGFloat x) {
    return (x + 1.0) / sqrt(x * (x + 2.0)) - 1.0;
}

- (void)addMarkupAnnotationWithType:(SKNoteType)annotationType selection:(PDFSelection *)selection {
    BOOL noSelection = selection == nil;
    if (noSelection)
        selection = [self currentSelection];
    PDFPage *page = [selection safeFirstPage];
    
    if (page == nil) {
        NSBeep();
        return;
    }
    
    NSString *type = SKTypeForNoteType(annotationType);
    NSColor *color = nil;
    
    // add new markup to the active markup if it's the same type on the same page, unless we add a specific selection
    if (noSelection && [[currentAnnotation page] isEqual:page] &&
        [[currentAnnotation type] isEqualToString:type]) {
        selection = [selection copy];
        [selection addSelection:[currentAnnotation selection]];
        color = [currentAnnotation color];
        [self removeCurrentAnnotation:nil];
    }
    
    NSInteger disableUpdateString = [[NSUserDefaults standardUserDefaults] integerForKey:SKDisableUpdateContentsFromEnclosedTextKey];
    NSString *text = disableUpdateString < 2 ? [selection cleanedString] : nil;
    NSMutableArray *newAnnotations = [NSMutableArray array];
    for (PDFPage *aPage in [selection pages]) {
        PDFAnnotation *newAnnotation = [PDFAnnotation newSkimNoteWithSelection:selection onPage:aPage forType:type];
        if (newAnnotation) {
            if (text)
                [newAnnotation setString:text];
            if (color)
                [newAnnotation setColor:color];
            [newAnnotations addObject:@[newAnnotation, aPage]];
        }
    }
    if ([newAnnotations count] == 0) {
        NSBeep();
        return;
    }
    [self addAnnotations:newAnnotations];
    if (noSelection)
        [self setCurrentSelection:nil];
}

- (void)addOtherAnnotationWithType:(SKNoteType)annotationType selection:(PDFSelection *)selection point:(NSPoint)point {
    if (selection == nil)
        selection = [self currentSelection];
    
    PDFPage *page = [selection safeFirstPage];
    NSRect bounds = NSZeroRect;
    
    if (page) {
        
        // Get bounds (page space) for selection (first page in case selection spans multiple pages)
        bounds = [selection boundsForPage:page];
        if (annotationType == SKNoteTypeCircle) {
            CGFloat dw, dh, w = NSWidth(bounds), h = NSHeight(bounds);
            if (h < w) {
                dw = primaryOutset(h / w);
                dh = secondaryOutset(dw);
            } else if (w < h) {
                dh = primaryOutset(w / h);
                dw = secondaryOutset(dh);
            } else {
                dw = dh = M_SQRT2 - 1.0;
            }
            CGFloat lw = [[NSUserDefaults standardUserDefaults] doubleForKey:SKCircleNoteLineWidthKey];
            bounds = NSInsetRect(bounds, -0.5 * w * dw - lw, -0.5 * h * dh - lw);
        } else if (annotationType == SKNoteTypeSquare) {
            CGFloat lw = [[NSUserDefaults standardUserDefaults] doubleForKey:SKSquareNoteLineWidthKey];
            bounds = NSInsetRect(bounds, -lw, -lw);
        } else if (annotationType == SKNoteTypeLine) {
            NSSize defaultSize = [[NSUserDefaults standardUserDefaults] sizeForWidthKey:SKDefaultNoteWidthKey heightKey:SKDefaultNoteHeightKey];
            NSRect pageBounds = [page boundsForBox:[self displayBox]];
            NSPoint p1, p2;
            switch ([page intrinsicRotation]) {
                case 0:
                    p2.x = floor(NSMinX(bounds));
                    p2.y = ceil(NSMidY(bounds));
                    p1.x = fmax(NSMinX(pageBounds), p2.x - defaultSize.width);
                    p1.y = fmax(NSMinY(pageBounds), p2.y - defaultSize.height);
                    break;
                case 90:
                    p2.x = floor(NSMidX(bounds));
                    p2.y = floor(NSMinY(bounds));
                    p1.x = fmin(NSMaxX(pageBounds), p2.x + defaultSize.height);
                    p1.y = fmax(NSMinY(pageBounds), p2.y - defaultSize.width);
                    break;
                case 180:
                    p2.x = ceil(NSMaxX(bounds));
                    p2.y = floor(NSMidY(bounds));
                    p1.x = fmin(NSMaxX(pageBounds), p2.x + defaultSize.width);
                    p1.y = fmin(NSMaxY(pageBounds), p2.y + defaultSize.height);
                    break;
                case 270:
                    p2.x = ceil(NSMidX(bounds));
                    p2.y = ceil(NSMaxY(bounds));
                    p1.x = fmax(NSMinX(pageBounds), p2.x - defaultSize.height);
                    p1.y = fmin(NSMaxY(pageBounds), p2.y + defaultSize.width);
                    break;
                default:
                    p2.x = floor(NSMinX(bounds));
                    p2.y = ceil(NSMidY(bounds));
                    p1.x = fmax(NSMinX(pageBounds), p2.x - defaultSize.width);
                    p1.y = fmax(NSMinY(pageBounds), p2.y - defaultSize.height);
                    break;
            }
            bounds = SKRectFromPoints(p1, p2);
        } else if (annotationType == SKNoteTypeAnchored) {
            NSRect pageBounds = [page boundsForBox:[self displayBox]];
            switch ([page intrinsicRotation]) {
                case 0:
                    bounds = [[page selectionForRect:NSMakeRect(NSMinX(pageBounds), NSMinY(bounds), NSWidth(pageBounds), NSHeight(bounds))] boundsForPage:page];
                    bounds.origin.x = fmax(floor(NSMinX(bounds)) - SKNPDFAnnotationNoteSize.width, NSMinX(pageBounds));
                    bounds.origin.y = floor(NSMaxY(bounds)) - SKNPDFAnnotationNoteSize.height;
                    break;
                case 90:
                    bounds = [[page selectionForRect:NSMakeRect(NSMinX(bounds), NSMinY(pageBounds), NSWidth(bounds), NSWidth(pageBounds))] boundsForPage:page];
                    bounds.origin.x = ceil(NSMinX(bounds));
                    bounds.origin.y = fmax(floor(NSMinY(bounds)) - SKNPDFAnnotationNoteSize.height, NSMinY(pageBounds));
                    break;
                case 180:
                    bounds = [[page selectionForRect:NSMakeRect(NSMinX(pageBounds), NSMinY(bounds), NSWidth(pageBounds), NSHeight(bounds))] boundsForPage:page];
                    bounds.origin.x = fmin(ceil(NSMaxX(bounds)), NSMaxX(pageBounds) - SKNPDFAnnotationNoteSize.width);
                    bounds.origin.y = ceil(NSMinY(bounds));
                    break;
                case 270:
                    bounds = [[page selectionForRect:NSMakeRect(NSMinX(bounds), NSMinY(pageBounds), NSWidth(bounds), NSWidth(pageBounds))] boundsForPage:page];
                    bounds.origin.x = floor(NSMaxX(bounds)) - SKNPDFAnnotationNoteSize.height;
                    bounds.origin.y = fmin(ceil(NSMaxY(bounds)), NSMaxY(pageBounds) - SKNPDFAnnotationNoteSize.width);
                    break;
                default:
                    break;
            }
            bounds.size = SKNPDFAnnotationNoteSize;
            // Make sure it fits in the page
            bounds = SKConstrainRect(bounds, pageBounds);
        }
        bounds = NSIntegralRect(bounds);
        
    } else {
        
        // First try the current mouse position
        if (NSEqualPoints(point, SKUnspecifiedPoint))
            point = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
        
        // if the mouse was in the toolbar and there is a page below the toolbar, we get a point outside of the visible rect
        if (NSMouseInRect(point, [self unobscuredContentRect], [self isFlipped]))
            page = [self pageForPoint:point nearest:NO];
        
        if (page == nil) {
            // Get center of the PDFView.
            NSRect viewFrame = [self frame];
            point = SKCenterPoint(viewFrame);
            page = [self pageForPoint:point nearest:YES];
            if (page == nil) {
                // Get center of the current page
                page = [self currentPage];
                point = [self convertPoint:SKCenterPoint([page boundsForBox:[self displayBox]]) fromPage:page];
            }
        }
        
        NSSize defaultSize;
        if (annotationType == SKNoteTypeAnchored) {
            defaultSize = SKNPDFAnnotationNoteSize;
        } else {
            defaultSize = [[NSUserDefaults standardUserDefaults] sizeForWidthKey:SKDefaultNoteWidthKey heightKey:SKDefaultNoteHeightKey];
            if (([page rotation] % 180))
                defaultSize = NSMakeSize(defaultSize.height, defaultSize.width);
        }
        
        // Convert to "page space".
        point = SKIntegralPoint([self convertPoint:point toPage:page]);
        bounds = SKRectFromCenterAndSize(point, defaultSize);
        
        // Make sure it fits in the page
        bounds = SKConstrainRect(bounds, [page boundsForBox:[self displayBox]]);
        
    }
    
    PDFAnnotation *newAnnotation = [PDFAnnotation newSkimNoteWithBounds:bounds forType:SKTypeForNoteType(annotationType)];
    // should never happen
    if (newAnnotation == nil) {
        NSBeep();
        return;
    }
    
    if (annotationType == SKNoteTypeLine) {
        switch ([page intrinsicRotation]) {
            case 90:
                [newAnnotation setStartPoint:NSMakePoint(0.0, NSWidth(bounds))];
                [newAnnotation setEndPoint:NSMakePoint(NSHeight(bounds), 0.0)];
                break;
            case 180:
                [newAnnotation setStartPoint:NSMakePoint(NSWidth(bounds), NSHeight(bounds))];
                [newAnnotation setEndPoint:NSZeroPoint];
                break;
            case 270:
                [newAnnotation setStartPoint:NSMakePoint(NSHeight(bounds), 0.0)];
                [newAnnotation setEndPoint:NSMakePoint(0.0, NSWidth(bounds))];
                break;
            default:
                break;
        }
    } else {
        NSInteger disableUpdateString = [[NSUserDefaults standardUserDefaults] integerForKey:SKDisableUpdateContentsFromEnclosedTextKey];
        NSString *text = disableUpdateString < 2 ? [selection cleanedString] : nil;
        if ([text length] > 0)
            [newAnnotation setString:text];
        else if (disableUpdateString == 0)
            [newAnnotation autoUpdateStringWithPage:page];
    }
    
    [self addAnnotation:newAnnotation toPage:page select:YES];
    
    if (annotationType == SKNoteTypeAnchored || annotationType == SKNoteTypeFreeText)
        [self editCurrentAnnotation:self];
}

- (void)addAnnotationWithType:(SKNoteType)annotationType selection:(PDFSelection *)selection point:(NSPoint)point {
    if (IS_MARKUP(annotationType))
        [self addMarkupAnnotationWithType:annotationType selection:selection];
    else if (annotationType != SKNoteTypeInk)
        // should never reach this for Ink
        [self addOtherAnnotationWithType:annotationType selection:selection point:point];
}

- (void)addAnnotationWithType:(SKNoteType)annotationType {
    if ([self canSelectNote] == NO) {
        // should never happen
        NSBeep();
    } else if (annotationType == SKNoteTypeInk || ((IS_MARKUP(annotationType) || [[NSUserDefaults standardUserDefaults] boolForKey:SKNewNoteRequiresSelectionKey]) && [[self currentSelection] hasCharacters] == NO)) {
        [self setTemporaryToolMode:TEMP_TOOL_MODE_FROM_NOTE_TYPE(annotationType)];
    } else {
        [self addAnnotationWithType:annotationType selection:nil point:SKUnspecifiedPoint];
    }
}

- (void)addAnnotationsForSelections:(id)sender {
    SKNoteType type = [sender tag];
    NSArray *selections = [sender representedObject];
    for (PDFSelection *selection in selections)
        [self addAnnotationWithType:type selection:selection point:SKUnspecifiedPoint];
}

- (void)addAnnotationForPoint:(id)sender {
    [self addAnnotationWithType:[sender tag] selection:nil point:[[sender representedObject] pointValue]];
}

- (void)removeCurrentAnnotation:(id)sender{
    if ([currentAnnotation isSkimNote])
        [self removeAnnotation:currentAnnotation];
}

- (void)removeThisAnnotation:(id)sender{
    PDFAnnotation *annotation = [sender representedObject];
    if (annotation)
        [self removeAnnotation:annotation];
}

- (void)editThisAnnotation:(id)sender {
    [self editAnnotation:[sender representedObject]];
}

- (void)editAnnotation:(PDFAnnotation *)annotation {
    if (annotation == nil || [self isEditingAnnotation:annotation])
        return;
    
    if ([self canSelectNote] && [self window] && [self isHiddenOrHasHiddenAncestor] == NO) {
        if (currentAnnotation != annotation)
            [self setCurrentAnnotation:annotation];
        [self editCurrentAnnotation:nil];
    } else if ([annotation isEditable] && [[self delegate] respondsToSelector:@selector(PDFView:editAnnotation:)]) {
        [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
        
        [[self delegate] PDFView:self editAnnotation:annotation];
    }
}

- (void)editCurrentAnnotation:(id)sender {
    if (nil == currentAnnotation || editor)
        return;
    
    [self commitEditing];
    
    if ([currentAnnotation isLink]) {
        
        [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
        PDFAction *action = [currentAnnotation action];
        PDFDestination *dest;
        NSURL *url;
        if (action)
            [self performAction:action];
        else if ((dest = [currentAnnotation destination]))
            [self goToDestination:dest];
        else if ((url = [currentAnnotation URL]))
            [[NSWorkspace sharedWorkspace] openURL:url];
        [self setCurrentAnnotation:nil];
        
    } else if (hideNotes == NO && [currentAnnotation isEditable]) {
        
        if ([currentAnnotation isText] == NO) {
            
            [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
            
            if ([[self delegate] respondsToSelector:@selector(PDFView:editAnnotation:)])
                [[self delegate] PDFView:self editAnnotation:currentAnnotation];
            
        } else if ([self window] && [self isHiddenOrHasHiddenAncestor] == NO) {
            
            [self scrollAnnotationToVisible:currentAnnotation];
            [self editTextNoteWithEvent:nil];
            
        }
        
    }
    
}

- (void)editTextNoteWithEvent:(NSEvent *)theEvent {
    if (editor == nil) {
        editor = [[SKTextNoteEditor alloc] initWithAnnotation:currentAnnotation delegate:self];
        [self textNoteEditorSetFrame:editor];
        [[self documentView] addSubview:editor];
        [editor startEditingWithEvent:theEvent];
        
        [self updatedAnnotation:currentAnnotation];
    }
}

- (void)textNoteEditorSetFrame:(SKTextNoteEditor *)textNoteEditor {
    NSRect frame = [self convertRect:[currentAnnotation bounds] fromPage:[currentAnnotation page]];
    frame = [self backingAlignedRect:frame options:NSAlignAllEdgesNearest];
    frame = [self convertRect:frame toView:[self documentView]];
    [editor setFrame:frame];
}

- (void)textNoteEditorDidBeginEditing:(SKTextNoteEditor *)textNoteEditor {
    if ([[self delegate] respondsToSelector:@selector(PDFViewDidBeginEditing:)])
        [[self delegate] PDFViewDidBeginEditing:self];
}

- (void)textNoteEditorDidEndEditing:(SKTextNoteEditor *)textNoteEditor {
    editor = nil;
    
    [self updatedAnnotation:currentAnnotation];
    
    if ([[self delegate] respondsToSelector:@selector(PDFViewDidEndEditing:)])
        [[self delegate] PDFViewDidEndEditing:self];
}

- (void)discardEditing {
    [editor endEditingWithCommit:NO];
}

- (BOOL)commitEditing {
    if (editor) {
        NSUndoManager *undoManager = [self undoManager];
        NSInteger level = [undoManager groupingLevel];
        [editor endEditingWithCommit:YES];
        if ([undoManager groupingLevel] > level)
            wantsNewUndoGroup = YES;
    }
    return YES;
}

- (void)beginNewUndoGroupIfNeeded {
    if (wantsNewUndoGroup) {
        NSUndoManager *undoManger = [self undoManager];
        if ([undoManger groupingLevel] > 0) {
            [undoManger endUndoGrouping];
            [undoManger beginUndoGrouping];
        }
        wantsNewUndoGroup = NO;
    }
}

- (void)selectNextCurrentAnnotation:(id)sender {
    PDFDocument *pdfDoc = [self document];
    NSInteger numberOfPages = [pdfDoc pageCount];
    NSInteger i = -1;
    NSInteger pageIndex, startPageIndex = -1;
    PDFAnnotation *annotation = nil;
    
    if (currentAnnotation) {
        [self commitEditing];
        pageIndex = [[currentAnnotation page] pageIndex];
        i = [[[currentAnnotation page] annotations] indexOfObject:currentAnnotation];
    } else {
        pageIndex = [[self currentPage] pageIndex];
    }
    while (annotation == nil) {
        NSArray *annotations = [[pdfDoc pageAtIndex:pageIndex] annotations];
        while (++i < (NSInteger)[annotations count] && annotation == nil) {
            annotation = [annotations objectAtIndex:i];
            if (([self hideNotes] || [annotation isSkimNote] == NO) && [annotation isLink] == NO)
                annotation = nil;
        }
        if (startPageIndex == -1)
            startPageIndex = pageIndex;
        else if (pageIndex == startPageIndex)
            break;
        if (++pageIndex == numberOfPages)
            pageIndex = 0;
        i = -1;
    }
    if (annotation) {
        [self scrollAnnotationToVisible:annotation];
        [self setCurrentAnnotation:annotation];
        if ([annotation isLink] || [annotation text]) {
            NSRect bounds = [annotation bounds]; 
            NSPoint point = NSMakePoint(NSMinX(bounds) + TOOLTIP_OFFSET_FRACTION * NSWidth(bounds), NSMinY(bounds) + TOOLTIP_OFFSET_FRACTION * NSHeight(bounds));
            point = [self convertPoint:point fromPage:[annotation page]];
            point = [[self window] convertPointToScreen:[self convertPoint:NSMakePoint(round(point.x), round(point.y)) toView:nil]];
            [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:annotation scale:[self scaleFactor] atPoint:point];
        } else {
            [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
        }
    }
}

- (void)selectPreviousCurrentAnnotation:(id)sender {
    PDFDocument *pdfDoc = [self document];
    NSInteger numberOfPages = [pdfDoc pageCount];
    NSInteger i = -1;
    NSInteger pageIndex, startPageIndex = -1;
    PDFAnnotation *annotation = nil;
    NSArray *annotations = nil;
    
    if (currentAnnotation) {
        [self commitEditing];
        pageIndex = [[currentAnnotation page] pageIndex];
        annotations = [[currentAnnotation page] annotations];
        i = [annotations indexOfObject:currentAnnotation];
    } else {
        pageIndex = [[self currentPage] pageIndex];
        annotations = [[self currentPage] annotations];
        i = [annotations count];
    }
    while (annotation == nil) {
        while (--i >= 0 && annotation == nil) {
            annotation = [annotations objectAtIndex:i];
            if (([self hideNotes] || [annotation isSkimNote] == NO) && [annotation isLink] == NO)
                annotation = nil;
        }
        if (startPageIndex == -1)
            startPageIndex = pageIndex;
        else if (pageIndex == startPageIndex)
            break;
        if (--pageIndex == -1)
            pageIndex = numberOfPages - 1;
        annotations = [[pdfDoc pageAtIndex:pageIndex] annotations];
        i = [annotations count];
    }
    if (annotation) {
        [self scrollAnnotationToVisible:annotation];
        [self setCurrentAnnotation:annotation];
        if ([annotation isLink] || [annotation text]) {
            NSRect bounds = [annotation bounds]; 
            NSPoint point = NSMakePoint(NSMinX(bounds) + TOOLTIP_OFFSET_FRACTION * NSWidth(bounds), NSMinY(bounds) + TOOLTIP_OFFSET_FRACTION * NSHeight(bounds));
            point = [self convertPoint:point fromPage:[annotation page]] ;
            point = [[self window] convertPointToScreen:[self convertPoint:NSMakePoint(round(point.x), round(point.y)) toView:nil]];
            [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:annotation scale:[self scaleFactor] atPoint:point];
        } else {
            [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
        }
    }
}

- (BOOL)isEditingAnnotation:(PDFAnnotation *)annotation {
    return editor && currentAnnotation == annotation;
}

- (void)scrollAnnotationToVisible:(PDFAnnotation *)annotation {
    [self goToRect:[annotation bounds] onPage:[annotation page]];
}

- (void)updatedAnnotation:(PDFAnnotation *)annotation forKey:(NSString *)key fromValue:(id)oldValue {
    if ([self isPageAtIndexDisplayed:[annotation pageIndex]] == NO)
        return;
    if ([annotation isNote] && key) {
        // image does not notify automatically because it does not use the annotationKeyValues
        if ([key isEqualToString:SKNPDFAnnotationImageKey]) {
            [super updatedAnnotation:annotation];
        } else if ([key isEqualToString:SKNPDFAnnotationBoundsKey]) {
            [self annotationsChangedOnPage:[annotation page]];
            [self resetPDFToolTipRects];
        }
    }
    if (annotation == currentAnnotation && (key == nil || [key isEqualToString:SKNPDFAnnotationBoundsKey] || [key isEqualToString:SKNPDFAnnotationDrawsImageKey]) && atomic_load(&highlightLayerState) != SKLayerUse) {
        CGFloat margin = (([annotation isResizable] || [annotation isNote]) ? HANDLE_SIZE  : 1.0) / [self scaleFactor];
        NSRect rect = [annotation bounds];
        if ([key isEqualToString:SKNPDFAnnotationBoundsKey] && [oldValue isKindOfClass:[NSValue class]])
            rect = NSUnionRect(rect, [oldValue rectValue]);
        [self setNeedsDisplayInRect:NSInsetRect(rect, -margin, -margin) ofPage:[annotation page]];
    } else {
        [loupeController updateContents];
    }
}

- (void)updatedAnnotation:(PDFAnnotation *)annotation {
    [self updatedAnnotation:annotation forKey:nil fromValue:nil];
}

- (void)setNeedsDisplay:(BOOL)needsDisplay forReadingBarBounds:(NSRect)rect onPage:(PDFPage *)page notify:(BOOL)notify {
    if (needsDisplay) {
        [self setNeedsDisplay:YES];
        [loupeController updateContents];
    } else {
        [self setNeedsDisplayInRect:[SKReadingBar bounds:rect forBox:[self displayBox] onPage:page] ofPage:page];
    }
    if (notify && page)
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewReadingBarDidChangeNotification object:self userInfo:@{SKPDFViewPageKey: page}];

}

- (void)setNeedsDisplayInRect:(NSRect)rect ofPage:(PDFPage *)page {
    if ([self isPageAtIndexDisplayed:[page pageIndex]]) {
        rect = NSIntegralRect([self convertRect:NSInsetRect(rect, -1.0, -1.0) fromPage:page]);
        rect = NSIntersectionRect([self bounds], [self convertRect:rect toView:self]);
        if (NSIsEmptyRect(rect) == NO)
            [self setNeedsDisplayInRect:rect];
        [loupeController updateContents];
    }
}

#pragma mark Sync

- (void)displayLineAtPoint:(NSPoint)point inPageAtIndex:(NSUInteger)pageIndex select:(BOOL)select showReadingBar:(BOOL)showBar {
    if (pageIndex < [[self document] pageCount]) {
        PDFPage *page = [[self document] pageAtIndex:pageIndex];
        PDFSelection *sel = [page selectionForLineAtPoint:point];
        NSRect lineRect = [sel hasCharacters] ? [sel boundsForPage:page] : SKRectFromCenterAndSquareSize(point, 10.0);
        NSRect rect = lineRect;
        NSRect visibleRect;
        BOOL wasPageDisplayed = [self isPageAtIndexDisplayed:pageIndex];
        BOOL shouldHideReadingBar = NO;
        
        [self setNeedsRewind:NO];
        
        if (wasPageDisplayed == NO)
            [self goAndScrollToPage:page];
        
        if (showBar) {
            if ([self hasReadingBar] == NO || [syncDot shouldHideReadingBar])
                shouldHideReadingBar = YES;
            [self stopPacer];

            NSInteger line = [page indexOfLineRectAtPoint:point lower:YES];
            if ([self hasReadingBar] == NO) {
                SKReadingBar *aReadingBar = [[SKReadingBar alloc] initWithPage:page line:line delegate:self];
                [self setReadingBar:aReadingBar];
                [self setNeedsDisplay:[[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey] forReadingBarBounds:[readingBar currentBounds] onPage:[readingBar page] notify:YES];
            } else {
                [readingBar goToLine:line onPage:page];
            }
        }
        if (select && [sel hasCharacters] && [self toolMode] == SKToolModeText) {
            [self setCurrentSelection:sel];
        }
        
        visibleRect = [self convertRect:[self unobscuredContentRect] toPage:page];
        
        if (wasPageDisplayed == NO || NSContainsRect(visibleRect, lineRect) == NO) {
            if (wasPageDisplayed && [self currentPage] != page)
                [self goAndScrollToPage:page];
            if ([self displayMode] == kPDFDisplaySinglePageContinuous || [self displayMode] == kPDFDisplayTwoUpContinuous)
                rect = NSInsetRect(lineRect, 0.0, - floor( ( NSHeight(visibleRect) - NSHeight(rect) ) / 2.0 ) );
            if (NSWidth(rect) > NSWidth(visibleRect)) {
                if (NSMaxX(rect) < point.x + 0.5 * NSWidth(visibleRect))
                    rect.origin.x = NSMaxX(rect) - NSWidth(visibleRect);
                else if (NSMinX(rect) < point.x - 0.5 * NSWidth(visibleRect))
                    rect.origin.x = floor( point.x - 0.5 * NSWidth(visibleRect) );
                rect.size.width = NSWidth(visibleRect);
            }
            rect = [self convertRect:[self convertRect:rect fromPage:page] toView:[self documentView]];
            [[self documentView] scrollRectToVisible:rect];
        }
        
        __weak __typeof__(self) weakSelf = self;
        [syncDot invalidate];
        [self setSyncDot:[[SKSyncDot alloc] initWithPoint:point page:page updateHandler:^(BOOL finished){
                [weakSelf setNeedsDisplayInRect:[[weakSelf syncDot] bounds] ofPage:[[weakSelf syncDot] page]];
                if (finished) {
                    if ([[weakSelf syncDot] shouldHideReadingBar] && [weakSelf hasReadingBar])
                        [weakSelf toggleReadingBar];
                    [weakSelf setSyncDot:nil];
                }
            }]];
        [syncDot setShouldHideReadingBar:shouldHideReadingBar];
    }
}

#pragma mark Snapshots

- (void)takeSnapshot:(id)sender {
    NSPoint point;
    PDFPage *page = nil;
    NSRect rect = NSZeroRect;
    BOOL autoFits = NO;
    
    if (toolMode == SKToolModeSelect && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound) {
        page = [self selectToolPage];
        rect = NSIntersectionRect(selectionRect, [page boundsForBox:kPDFDisplayBoxCropBox]);
        autoFits = YES;
	}
    if (NSIsEmptyRect(rect)) {
        
        if ([sender representedObject] == nil) {
            [self setTemporaryToolMode:SKToolModeSnapshot];
            return;
        }
        
        // the represented object should be the location for the menu event
        point = [[sender representedObject] pointValue];
        page = [self pageForPoint:point nearest:NO];
        if (page == nil) {
            // Get the center
            NSRect viewFrame = [self frame];
            point = SKCenterPoint(viewFrame);
            page = [self pageForPoint:point nearest:YES];
        }
        
        point = [self convertPoint:point toPage:page];
        
        rect = [self convertRect:[page boundsForBox:kPDFDisplayBoxCropBox] fromPage:page];
        rect.origin.y = point.y - 0.5 * DEFAULT_SNAPSHOT_HEIGHT;
        rect.size.height = DEFAULT_SNAPSHOT_HEIGHT;
        
        rect = [self convertRect:rect toPage:page];
    }
    
    if ([[self delegate] respondsToSelector:@selector(PDFView:showSnapshotAtPage:forRect:scaleFactor:autoFits:)])
        [[self delegate] PDFView:self showSnapshotAtPage:page forRect:rect scaleFactor:[self scaleFactor] autoFits:autoFits];
}

#pragma mark Zooming

- (void)zoomToRect:(NSRect)rect onPage:(PDFPage *)page {
    if (NSIsEmptyRect(rect) == NO) {
        NSScrollView *scrollView = [self embeddedScrollView];
        CGFloat scrollerWidth = [NSScroller effectiveScrollerWidth];
        NSSize size = [self bounds].size;
        CGFloat scale = 1.0;
        CGFloat width = NSWidth(rect);
        CGFloat height = NSHeight(rect);
        if (([page rotation] % 180)) {
            width = NSHeight(rect);
            height = NSWidth(rect);
        }
        size.width -= scrollerWidth;
        size.height -= scrollerWidth + [scrollView contentInsets].top;
        if (size.width * height > width * size.height)
            scale = size.height / height;
        else
            scale = size.width / width;
        [self setScaleFactor:scale];
        
        if (scrollerWidth > 0.0 && ([scrollView hasHorizontalScroller] == NO || [scrollView hasVerticalScroller] == NO)) {
            if ([scrollView hasVerticalScroller] == NO)
                size.width += scrollerWidth;
            if ([scrollView hasHorizontalScroller] == NO)
                size.height += scrollerWidth;
            if (size.width * height > width * size.height)
                scale = size.height / height;
            else
                scale = size.width / width;
            [self setScaleFactor:scale];
        }
        [self goToRect:rect onPage:page];
    }
}

#pragma mark Notification handling

- (void)handleDidAddRemoveAnnotationNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    PDFPage *page = [userInfo objectForKey:SKPDFDocumentPageKey];
    
    if ([self isPageAtIndexDisplayed:[page pageIndex]]) {
        PDFAnnotation *annotation = [userInfo objectForKey:SKPDFDocumentAnnotationKey];
        [loupeController updateContents];
        if ([annotation isNote])
            [self resetPDFToolTipRects];
    }
}

- (void)handleWillRemoveAnnotationNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [[notification userInfo] objectForKey:SKPDFDocumentAnnotationKey];
    
    if (currentAnnotation == annotation) {
        [self setCurrentAnnotation:nil];
        [self beginNewUndoGroupIfNeeded];
    }
}

- (void)handleWillMoveAnnotationNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    PDFAnnotation *annotation = [userInfo objectForKey:SKPDFDocumentAnnotationKey];
    
    if ([self isEditingAnnotation:annotation] && [self isPageAtIndexDisplayed:[[userInfo objectForKey:SKPDFDocumentPageKey] pageIndex]] == NO) {
        [self commitEditing];
        [self beginNewUndoGroupIfNeeded];
    } else {
        [self updatedAnnotation:annotation];
    }
}

- (void)handleDidMoveAnnotationNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [[notification userInfo] objectForKey:SKPDFDocumentAnnotationKey];
    
    [self updatedAnnotation:annotation];
    if ([annotation isNote]) {
        [self resetPDFToolTipRects];
    } else if ([self isEditingAnnotation:annotation]) {
        if ([self isPageAtIndexDisplayed:[annotation pageIndex]])
            [self textNoteEditorSetFrame:editor];
        else
            [self commitEditing];
    }
}

- (void)handleDocumentDidUnlockNotification:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewCanSelectNoteDidChangeNotification object:self];
}

- (void)registerForDocumentNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    PDFDocument *pdfDoc = [self document];
    [nc addObserver:self selector:@selector(handleDidAddRemoveAnnotationNotification:)
                             name:SKPDFDocumentDidAddAnnotationNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleWillRemoveAnnotationNotification:)
                             name:SKPDFDocumentWillRemoveAnnotationNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDidAddRemoveAnnotationNotification:)
                             name:SKPDFDocumentDidRemoveAnnotationNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleWillMoveAnnotationNotification:)
                             name:SKPDFDocumentWillMoveAnnotationNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDidMoveAnnotationNotification:)
                             name:SKPDFDocumentDidMoveAnnotationNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDocumentDidUnlockNotification:)
                             name:PDFDocumentDidUnlockNotification object:pdfDoc];
}

- (void)unregisterForDocumentNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    PDFDocument *pdfDoc = [self document];
    [nc removeObserver:self name:SKPDFDocumentDidAddAnnotationNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFDocumentWillRemoveAnnotationNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFDocumentDidRemoveAnnotationNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFDocumentWillMoveAnnotationNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFDocumentDidMoveAnnotationNotification object:pdfDoc];
    [nc removeObserver:self name:PDFDocumentDidUnlockNotification object:pdfDoc];
}

- (void)handlePageChangedNotification:(NSNotification *)notification {
    if (([self displayMode] & kPDFDisplaySinglePageContinuous) == 0 && toolMode == SKToolModeMagnify)
        [loupeController updateContents];
}

// PDFKit positions the document view at fractional device-pixel offsets at most zoom levels. A page edge that
// falls between device pixels makes the white page background antialias into a 1px light seam at the page edges
// (most visible on dark art pages). Rounding the visible scroll origin to the device-pixel grid keeps page rects
// on integral device pixels, so the page background and the page content clip identically and no seam is drawn.
- (void)alignScrollOriginToDevicePixels {
    NSScrollView *scrollView = [self embeddedScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSView *documentView = [scrollView documentView];
    if (clipView == nil || documentView == nil)
        return;

    NSWindow *window = [self window];
    CGFloat backingScaleFactor = [window respondsToSelector:@selector(backingScaleFactor)] ? [window backingScaleFactor] : [[NSScreen mainScreen] backingScaleFactor];
    if (backingScaleFactor <= 0.0)
        return;
    CGFloat pixel = 1.0 / backingScaleFactor;

    NSRect bounds = [clipView bounds];
    CGFloat alignedX = round(bounds.origin.x / pixel) * pixel;
    CGFloat alignedY = round(bounds.origin.y / pixel) * pixel;
    if (alignedX == bounds.origin.x && alignedY == bounds.origin.y)
        return;

    // only shift while the document is larger than the clip view in that axis; a centered page that fits must not move
    NSRect docRect = [documentView frame];
    if (NSWidth(docRect) > NSWidth(bounds))
        bounds.origin.x = alignedX;
    if (NSHeight(docRect) > NSHeight(bounds))
        bounds.origin.y = alignedY;
    if (NSEqualPoints(bounds.origin, [clipView bounds].origin))
        return;

    [clipView scrollToPoint:bounds.origin];
    [scrollView reflectScrolledClipView:clipView];
}

- (void)handleScrollBoundsDidChangeNotification:(NSNotification *)notification {
    [self alignScrollOriginToDevicePixels];
}

- (void)handleScaleChangedNotification:(NSNotification *)notification {
    [self resetPDFToolTipRects];
    [self updatePacer];
    if (editor)
        [self textNoteEditorSetFrame:editor];
}

- (void)handleUpdateTrackingAreasNotification:(NSNotification *)notification {
    [self resetPDFToolTipRects];
}

- (void)handleKeyStateChangedNotification:(NSNotification *)notification {
    if (@available(macOS 10.15, *)) {
        atomic_store(&drawsActiveSelection, [[self window] isKeyWindow]);
        if (selectionPageIndex != NSNotFound) {
            CGFloat margin = HANDLE_SIZE / [self scaleFactor];
            for (PDFPage *page in [self displayedPages])
                [self setNeedsDisplayInRect:NSInsetRect(selectionRect, -margin, -margin) ofPage:page];
        }
        if (currentAnnotation)
            [self updatedAnnotation:currentAnnotation];
    }
    if ([[notification name] isEqualToString:NSWindowDidResignKeyNotification]) {
        [self setTemporaryToolMode:SKToolModeNone];
        if (toolMode == SKToolModeMagnify)
            [loupeController hide];
    }
}

- (void)handleMainStateChangedNotification:(NSNotification *)notification {
    [self setTemporaryToolMode:SKToolModeNone];
}

- (void)handleOpenOrCloseUndoGroupNotification:(NSNotification *)notification {
    wantsNewUndoGroup = NO;
}

#pragma mark Key and window changes

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSWindow *oldWindow = [self window];
    if (oldWindow) {
        [self commitEditing];
        
        [self removeLoupeWindow];
        
        [self stopPacer];
        
        [self setTemporaryToolMode:SKToolModeNone];
        
        [nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidResignKeyNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidResignMainNotification object:oldWindow];
    }
    if (newWindow) {
        if (@available(macOS 15.0, *))
            atomic_store(&drawsActiveSelection, [newWindow isKeyWindow]);
        [nc addObserver:self selector:@selector(handleKeyStateChangedNotification:) name:NSWindowDidBecomeKeyNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleKeyStateChangedNotification:) name:NSWindowDidResignKeyNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleMainStateChangedNotification:) name:NSWindowDidResignMainNotification object:newWindow];
    }
    
    [super viewWillMoveToWindow:newWindow];
}

- (void)viewDidHide {
    [self commitEditing];
    
    [self removeLoupeWindow];
    
    [self stopPacer];
    
    [self setTemporaryToolMode:SKToolModeNone];
    
    [super viewDidHide];
}

#pragma mark Dark mode

- (void)updateSwipeGestures {
    // without this private option,
    // page navigation by swiping in single page mode is broken
    // however the filters are not applied to the animation
    if ([self respondsToSelector:@selector(enableSwipeGestures:)])
        [self enableSwipeGestures:[[[self embeddedScrollView] contentFilters] count] == 0];
}

- (void)viewDidChangeEffectiveAppearance {
    if (@available(macOS 10.14, *))
        [super viewDidChangeEffectiveAppearance];
    [loupeController updateColorFilters];
    [self updateSwipeGestures];
}

- (void)colorFiltersDidChange {
    [super colorFiltersDidChange];
    [loupeController updateColorFilters];
    [self updateSwipeGestures];
}

#pragma mark Menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(changeToolMode:)) {
        [menuItem setState:[self toolMode] == (SKToolMode)[menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(changeAnnotationMode:)) {
        if ([[menuItem menu] numberOfItems] > ANNOTATION_MODE_COUNT)
            [menuItem setState:[self toolMode] == SKToolModeNote && [self annotationMode] == (SKNoteType)[menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        else
            [menuItem setState:[self annotationMode] == (SKNoteType)[menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(copy:)) {
        return ([[self currentSelection] hasCharacters] || [currentAnnotation isSkimNote] ||
            (toolMode == SKToolModeSelect && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound && [[self document] isLocked] == NO));
    } else if (action == @selector(cut:)) {
        return [currentAnnotation isMovable];
    } else if (action == @selector(paste:)) {
        return [self canSelectNote] && [[NSPasteboard generalPasteboard] canReadObjectForClasses:@[[PDFAnnotation class], [NSString class], [NSImage class]] options:@{}];
    } else if (action == @selector(alternatePaste:)) {
        return [self canSelectNote] && [[NSPasteboard generalPasteboard] canReadObjectForClasses:@[[PDFAnnotation class], [NSAttributedString class], [NSString class], [NSImage class]] options:@{}];
    } else if (action == @selector(pasteAsPlainText:)) {
        return [self canSelectNote] && [[NSPasteboard generalPasteboard] canReadObjectForClasses:@[[NSAttributedString class], [NSString class]] options:@{}];
    } else if (action == @selector(delete:)) {
        return [currentAnnotation isSkimNote];
    } else if (action == @selector(selectAll:)) {
        return toolMode == SKToolModeText;
    } else if (action == @selector(deselectAll:)) {
        return [[self currentSelection] hasCharacters] != 0;
    } else if (action == @selector(autoSelectContent:)) {
        return toolMode == SKToolModeSelect;
    } else if (action == @selector(takeSnapshot:)) {
        return [[self document] isLocked] == NO;
    } else if (action == @selector(_setSinglePageScrolling:)) {
        [menuItem setState:[self extendedDisplayMode] == kPDFDisplaySinglePageContinuous ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(_setDoublePageScrolling:)) {
        [menuItem setState:[self extendedDisplayMode] == kPDFDisplayTwoUpContinuous ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(_setDoublePage:)) {
        [menuItem setState:[self extendedDisplayMode] == kPDFDisplayTwoUp ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(setHorizontalScrolling:)) {
        [menuItem setState:[self extendedDisplayMode] == kPDFDisplayHorizontalContinuous ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(zoomToPhysicalSize:)) {
        [menuItem setState:([self autoScales] || fabs([self physicalScaleFactor] - 1.0) > 0.001) ? NSControlStateValueOff : NSControlStateValueOn];
        return YES;
    } else if (action == @selector(editCurrentAnnotation:)) {
        return [[self currentAnnotation] isEditable];
    } else if (action == @selector(moveCurrentAnnotation:)) {
        return [[self currentAnnotation] isMovable];
    } else if (action == @selector(resizeCurrentAnnotation:)) {
        return [[self currentAnnotation] isResizable];
    } else if (action == @selector(autoSizeCurrentAnnotation:)) {
        return [[self currentAnnotation] isResizable] && [[self currentAnnotation] isLine] == NO && [currentAnnotation isInk] == NO;
    } else if (action == @selector(changeOnlyAnnotationMode:)) {
        return toolMode == SKToolModeNote;
    } else if (action == @selector(moveReadingBar:) || action == @selector(resizeReadingBar:)) {
        return [self hasReadingBar];
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        return [super validateMenuItem:menuItem];
    } else {
        return YES;
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKPDFViewScrollBoundsObservationContext) {
        if (([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) == NO)
            [self alignScrollOriginToDevicePixels];
    } else if (context == &SKPDFViewDefaultsObservationContext) {
        if (readingBar) {
            PDFPage *page = [readingBar page];
            [self setNeedsDisplay:([keyPath isEqualToString:SKReadingBarInvertKey] || [[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey]) forReadingBarBounds:[readingBar currentBounds] onPage:page notify:YES];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Event handling

- (void)doMoveCurrentAnnotationForKey:(unichar)eventChar byAmount:(CGFloat)delta {
    NSRect bounds = [currentAnnotation bounds];
    NSRect newBounds = bounds;
    PDFPage *page = [currentAnnotation page];
    NSRect pageBounds = [page boundsForBox:[self displayBox]];
    
    switch ([page rotation]) {
        case 0:
            if (eventChar == NSRightArrowFunctionKey) {
                if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
                    newBounds.origin.x += delta;
                else if (NSMaxX(bounds) < NSMaxX(pageBounds))
                    newBounds.origin.x += NSMaxX(pageBounds) - NSMaxX(bounds);
            } else if (eventChar == NSLeftArrowFunctionKey) {
                if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
                    newBounds.origin.x -= delta;
                else if (NSMinX(bounds) > NSMinX(pageBounds))
                    newBounds.origin.x -= NSMinX(bounds) - NSMinX(pageBounds);
            } else if (eventChar == NSUpArrowFunctionKey) {
                if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
                    newBounds.origin.y += delta;
                else if (NSMaxY(bounds) < NSMaxY(pageBounds))
                    newBounds.origin.y += NSMaxY(pageBounds) - NSMaxY(bounds);
            } else if (eventChar == NSDownArrowFunctionKey) {
                if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
                    newBounds.origin.y -= delta;
                else if (NSMinY(bounds) > NSMinY(pageBounds))
                    newBounds.origin.y -= NSMinY(bounds) - NSMinY(pageBounds);
            }
            break;
        case 90:
            if (eventChar == NSRightArrowFunctionKey) {
                if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
                    newBounds.origin.y += delta;
            } else if (eventChar == NSLeftArrowFunctionKey) {
                if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
                    newBounds.origin.y -= delta;
            } else if (eventChar == NSUpArrowFunctionKey) {
                if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
                    newBounds.origin.x -= delta;
            } else if (eventChar == NSDownArrowFunctionKey) {
                if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
                    newBounds.origin.x += delta;
            }
            break;
        case 180:
            if (eventChar == NSRightArrowFunctionKey) {
                if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
                    newBounds.origin.x -= delta;
            } else if (eventChar == NSLeftArrowFunctionKey) {
                if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
                    newBounds.origin.x += delta;
            } else if (eventChar == NSUpArrowFunctionKey) {
                if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
                    newBounds.origin.y -= delta;
            } else if (eventChar == NSDownArrowFunctionKey) {
                if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
                    newBounds.origin.y += delta;
            }
            break;
        case 270:
            if (eventChar == NSRightArrowFunctionKey) {
                if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
                    newBounds.origin.y -= delta;
            } else if (eventChar == NSLeftArrowFunctionKey) {
                if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
                    newBounds.origin.y += delta;
            } else if (eventChar == NSUpArrowFunctionKey) {
                if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
                    newBounds.origin.x += delta;
            } else if (eventChar == NSDownArrowFunctionKey) {
                if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
                    newBounds.origin.x -= delta;
            }
            break;
    }
    
    if (NSEqualRects(bounds, newBounds) == NO) {
        [currentAnnotation setBounds:newBounds];
        if ([currentAnnotation isShape] && NO == [[NSUserDefaults standardUserDefaults] boolForKey:SKDisableUpdateContentsFromEnclosedTextKey])
            [currentAnnotation autoUpdateStringWithPage:page];
    }
}

- (void)doResizeCurrentAnnotationForKey:(unichar)eventChar byAmount:(CGFloat)delta {
    NSRect bounds = [currentAnnotation bounds];
    NSRect newBounds = bounds;
    PDFPage *page = [currentAnnotation page];
    NSRect pageBounds = [page boundsForBox:[self displayBox]];
    
    if ([currentAnnotation isLine]) {
        
        PDFAnnotation *annotation = currentAnnotation;
        NSPoint startPoint = SKIntegralPoint(SKAddPoints([annotation startPoint], bounds.origin));
        NSPoint endPoint = SKIntegralPoint(SKAddPoints([annotation endPoint], bounds.origin));
        NSPoint oldEndPoint = endPoint;
        
        // Resize the annotation.
        switch ([page rotation]) {
            case 0:
                if (eventChar == NSRightArrowFunctionKey) {
                    endPoint.x += delta;
                    if (endPoint.x > NSMaxX(pageBounds))
                        endPoint.x = NSMaxX(pageBounds);
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    endPoint.x -= delta;
                    if (endPoint.x < NSMinX(pageBounds))
                        endPoint.x = NSMinX(pageBounds);
                } else if (eventChar == NSUpArrowFunctionKey) {
                    endPoint.y += delta;
                    if (endPoint.y > NSMaxY(pageBounds))
                        endPoint.y = NSMaxY(pageBounds);
                } else if (eventChar == NSDownArrowFunctionKey) {
                    endPoint.y -= delta;
                    if (endPoint.y < NSMinY(pageBounds))
                        endPoint.y = NSMinY(pageBounds);
                }
                break;
            case 90:
                if (eventChar == NSRightArrowFunctionKey) {
                    endPoint.y += delta;
                    if (endPoint.y > NSMaxY(pageBounds))
                        endPoint.y = NSMaxY(pageBounds);
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    endPoint.y -= delta;
                    if (endPoint.y < NSMinY(pageBounds))
                        endPoint.y = NSMinY(pageBounds);
                } else if (eventChar == NSUpArrowFunctionKey) {
                    endPoint.x -= delta;
                    if (endPoint.x < NSMinX(pageBounds))
                        endPoint.x = NSMinX(pageBounds);
                } else if (eventChar == NSDownArrowFunctionKey) {
                    endPoint.x += delta;
                    if (endPoint.x > NSMaxX(pageBounds))
                        endPoint.x = NSMaxX(pageBounds);
                }
                break;
            case 180:
                if (eventChar == NSRightArrowFunctionKey) {
                    endPoint.x -= delta;
                    if (endPoint.x < NSMinX(pageBounds))
                        endPoint.x = NSMinX(pageBounds);
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    endPoint.x += delta;
                    if (endPoint.x > NSMaxX(pageBounds))
                        endPoint.x = NSMaxX(pageBounds);
                } else if (eventChar == NSUpArrowFunctionKey) {
                    endPoint.y -= delta;
                    if (endPoint.y < NSMinY(pageBounds))
                        endPoint.y = NSMinY(pageBounds);
                } else if (eventChar == NSDownArrowFunctionKey) {
                    endPoint.y += delta;
                    if (endPoint.y > NSMaxY(pageBounds))
                        endPoint.y = NSMaxY(pageBounds);
                }
                break;
            case 270:
                if (eventChar == NSRightArrowFunctionKey) {
                    endPoint.y -= delta;
                    if (endPoint.y < NSMinY(pageBounds))
                        endPoint.y = NSMinY(pageBounds);
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    endPoint.y += delta;
                    if (endPoint.y > NSMaxY(pageBounds))
                        endPoint.y = NSMaxY(pageBounds);
                } else if (eventChar == NSUpArrowFunctionKey) {
                    endPoint.x += delta;
                    if (endPoint.x > NSMaxX(pageBounds))
                        endPoint.x = NSMaxX(pageBounds);
                } else if (eventChar == NSDownArrowFunctionKey) {
                    endPoint.x -= delta;
                    if (endPoint.x < NSMinX(pageBounds))
                        endPoint.x = NSMinX(pageBounds);
                }
                break;
        }
        
        endPoint.x = floor(endPoint.x);
        endPoint.y = floor(endPoint.y);
        
        if (NSEqualPoints(endPoint, oldEndPoint) == NO) {
            newBounds = SKIntegralRectFromPoints(startPoint, endPoint);
            
            if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                newBounds.size.width = MIN_NOTE_SIZE;
                newBounds.origin.x = floor(0.5 * ((startPoint.x + endPoint.x) - MIN_NOTE_SIZE));
            }
            if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                newBounds.size.height = MIN_NOTE_SIZE;
                newBounds.origin.y = floor(0.5 * ((startPoint.y + endPoint.y) - MIN_NOTE_SIZE));
            }
            
            startPoint = SKSubstractPoints(startPoint, newBounds.origin);
            endPoint = SKSubstractPoints(endPoint, newBounds.origin);
            
            [annotation setBounds:newBounds];
            [annotation setStartPoint:startPoint];
            [annotation setEndPoint:endPoint];
        }
        
    } else {
        
        switch ([page rotation]) {
            case 0:
                if (eventChar == NSRightArrowFunctionKey) {
                    if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds)) {
                        newBounds.size.width += delta;
                    } else if (NSMaxX(bounds) < NSMaxX(pageBounds)) {
                        newBounds.size.width += NSMaxX(pageBounds) - NSMaxX(bounds);
                    }
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    newBounds.size.width -= delta;
                    if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.size.width = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSUpArrowFunctionKey) {
                    newBounds.origin.y += delta;
                    newBounds.size.height -= delta;
                    if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.origin.y += NSHeight(newBounds) - MIN_NOTE_SIZE;
                        newBounds.size.height = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSDownArrowFunctionKey) {
                    if (NSMinY(bounds) - delta >= NSMinY(pageBounds)) {
                        newBounds.origin.y -= delta;
                        newBounds.size.height += delta;
                    } else if (NSMinY(bounds) > NSMinY(pageBounds)) {
                        newBounds.origin.y -= NSMinY(bounds) - NSMinY(pageBounds);
                        newBounds.size.height += NSMinY(bounds) - NSMinY(pageBounds);
                    }
                }
                break;
            case 90:
                if (eventChar == NSRightArrowFunctionKey) {
                    if (NSMinY(bounds) + delta <= NSMaxY(pageBounds)) {
                        newBounds.size.height += delta;
                    } else if (NSMinY(bounds) < NSMaxY(pageBounds)) {
                        newBounds.size.height += NSMaxY(pageBounds) - NSMinY(bounds);
                    }
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    newBounds.size.height -= delta;
                    if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.size.height = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSUpArrowFunctionKey) {
                    newBounds.size.width -= delta;
                    if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.size.width = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSDownArrowFunctionKey) {
                    if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds)) {
                        newBounds.size.width += delta;
                    } else if (NSMaxX(bounds) < NSMaxX(pageBounds)) {
                        newBounds.size.width += NSMaxX(pageBounds) - NSMaxX(bounds);
                    }
                }
                break;
            case 180:
                if (eventChar == NSRightArrowFunctionKey) {
                    if (NSMinX(bounds) - delta >= NSMinX(pageBounds)) {
                        newBounds.origin.x -= delta;
                        newBounds.size.width += delta;
                    } else if (NSMinX(bounds) > NSMinX(pageBounds)) {
                        newBounds.origin.x -= NSMinX(bounds) - NSMinX(pageBounds);
                        newBounds.size.width += NSMinX(bounds) - NSMinX(pageBounds);
                    }
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    newBounds.origin.x += delta;
                    newBounds.size.width -= delta;
                    if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.origin.x += NSWidth(newBounds) - MIN_NOTE_SIZE;
                        newBounds.size.width = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSUpArrowFunctionKey) {
                    newBounds.size.height -= delta;
                    if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.size.height = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSDownArrowFunctionKey) {
                    if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds)) {
                        newBounds.size.height += delta;
                    } else if (NSMaxY(bounds) < NSMaxY(pageBounds)) {
                        newBounds.size.height += NSMaxY(pageBounds) - NSMaxY(bounds);
                    }
                }
                break;
            case 270:
                if (eventChar == NSRightArrowFunctionKey) {
                    if (NSMinY(bounds) - delta >= NSMinY(pageBounds)) {
                        newBounds.origin.y -= delta;
                        newBounds.size.height += delta;
                    } else if (NSMinY(bounds) > NSMinY(pageBounds)) {
                        newBounds.origin.y -= NSMinY(bounds) - NSMinY(pageBounds);
                        newBounds.size.height += NSMinY(bounds) - NSMinY(pageBounds);
                    }
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    newBounds.origin.y += delta;
                    newBounds.size.height -= delta;
                    if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.origin.y += NSHeight(newBounds) - MIN_NOTE_SIZE;
                        newBounds.size.height = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSUpArrowFunctionKey) {
                    newBounds.origin.x += delta;
                    newBounds.size.width -= delta;
                    if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.origin.x += NSWidth(newBounds) - MIN_NOTE_SIZE;
                        newBounds.size.width = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSDownArrowFunctionKey) {
                    if (NSMinX(bounds) - delta >= NSMinX(pageBounds)) {
                        newBounds.origin.x -= delta;
                        newBounds.size.width += delta;
                    } else if (NSMinX(bounds) > NSMinX(pageBounds)) {
                        newBounds.origin.x -= NSMinX(bounds) - NSMinX(pageBounds);
                        newBounds.size.width += NSMinX(bounds) - NSMinX(pageBounds);
                    }
                }
                break;
        }
        
        if (NSEqualRects(bounds, newBounds) == NO) {
            if ([currentAnnotation isInk]) {
                CGFloat margin = [currentAnnotation pathInset];
                NSMutableArray *paths = [NSMutableArray array];
                NSAffineTransform *transform = [NSAffineTransform transform];
                [transform translateXBy:margin yBy:margin];
                [transform scaleXBy:fmax(1.0, NSWidth(newBounds) - 2.0 * margin) / fmax(1.0, NSWidth(bounds) - 2.0 * margin) yBy:fmax(1.0, NSHeight(newBounds) - 2.0 * margin) / fmax(1.0, NSHeight(bounds) - 2.0 * margin)];
                [transform translateXBy:-margin yBy:-margin];
                
                for (NSBezierPath *path in [currentAnnotation paths])
                    [paths addObject:[transform transformBezierPath:path]];
                
                [currentAnnotation setBezierPaths:paths];
            }
            
            [currentAnnotation setBounds:newBounds];
            if ([currentAnnotation isShape] && NO == [[NSUserDefaults standardUserDefaults] boolForKey:SKDisableUpdateContentsFromEnclosedTextKey])
                [currentAnnotation autoUpdateStringWithPage:page];
        }
    }
}

- (void)doAutoSizeActiveNoteIgnoringWidth:(BOOL)ignoreWidth {
    if ([currentAnnotation isResizable] == NO || [currentAnnotation isLine] || [currentAnnotation isInk]) {
        NSBeep();
    } else if ([currentAnnotation isText]) {
        
        NSString *string = [editor currentString] ?: [currentAnnotation string];
        if ([string length] == 0) {
            NSBeep();
            return;
        }
        
        PDFPage *page = [currentAnnotation page];
        NSRect pageBounds = [page boundsForBox:[self displayBox]];
        NSRect bounds = [currentAnnotation bounds];
        CGFloat width = ignoreWidth == NO ? NSWidth(bounds) : ([page rotation] % 180) ? NSHeight(pageBounds) : NSWidth(pageBounds);
        NSSize size = SKFitTextNoteSize(string, [currentAnnotation font], width);
        switch ([page rotation]) {
            case 0:
                bounds = NSMakeRect(NSMinX(bounds), NSMaxY(bounds) - size.height, size.width, size.height);
                break;
            case 90:
                bounds = NSMakeRect(NSMinX(bounds), NSMinY(bounds), size.height, size.width);
                break;
            case 180:
                bounds = NSMakeRect(NSMaxX(bounds) - size.width, NSMinY(bounds), size.width, size.height);
                break;
            case 270:
                bounds = NSMakeRect(NSMaxX(bounds) - size.height, NSMaxY(bounds) - size.width, size.height, size.width);
                break;
        }
        bounds = SKConstrainRect(bounds, pageBounds);
        if (NSEqualRects(bounds, [currentAnnotation bounds]) == NO)
            [currentAnnotation setBounds:bounds];
        
    } else if ([currentAnnotation isNote]) {
        
        PDFPage *page = [currentAnnotation page];
        NSRect pageBounds = [page boundsForBox:[self displayBox]];
        NSRect bounds = [currentAnnotation bounds];
        NSSize size = [currentAnnotation image] ? [[currentAnnotation image] size] : SKNPDFAnnotationNoteSize;
        
        if (NSWidth(pageBounds) < size.width) {
            size.width *= size.width / NSWidth(pageBounds);
            size.height *= size.width / NSWidth(pageBounds);
        }
        if (NSHeight(pageBounds) < size.height) {
            size.width *= size.width / NSHeight(pageBounds);
            size.height *= size.height / NSHeight(pageBounds);
        }
        size.width = round(size.width);
        size.height = round(size.height);
        bounds.size = size;
        
        bounds = SKConstrainRect(bounds, pageBounds);
        if (NSEqualRects(bounds, [currentAnnotation bounds]) == NO)
            [currentAnnotation setBounds:bounds];
        
    } else if ([[[self currentSelection] pages] containsObject:[currentAnnotation page]]) {
        
        NSRect bounds = [[self currentSelection] boundsForPage:[currentAnnotation page]];
        CGFloat lw = [currentAnnotation lineWidth];
        if ([[currentAnnotation type] isEqualToString:SKNCircleString]) {
            CGFloat dw, dh, w = NSWidth(bounds), h = NSHeight(bounds);
            if (h < w) {
                dw = primaryOutset(h / w);
                dh = secondaryOutset(dw);
            } else {
                dh = primaryOutset(w / h);
                dw = secondaryOutset(dh);
            }
            bounds = NSInsetRect(bounds, -0.5 * w * dw - lw, -0.5 * h * dh - lw);
        } else if ([[currentAnnotation type] isEqualToString:SKNSquareString]) {
            bounds = NSInsetRect(bounds, -lw, -lw);
        } else {
            NSBeep();
            return;
        }
        [currentAnnotation setBounds:bounds];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableUpdateContentsFromEnclosedTextKey] == NO)
            [currentAnnotation setString:[[self currentSelection] cleanedString]];
        
    } else {
        NSBeep();
    }
}

- (void)doMoveReadingBarForKey:(unichar)eventChar {
    BOOL moved = NO;
    if (eventChar == NSDownArrowFunctionKey)
        moved = [readingBar goToNextLine];
    else if (eventChar == NSUpArrowFunctionKey)
        moved = [readingBar goToPreviousLine];
    else if (eventChar == NSRightArrowFunctionKey)
        moved = [readingBar goToNextPage];
    else if (eventChar == NSLeftArrowFunctionKey)
        moved = [readingBar goToPreviousPage];
    if (moved)
        [self updatePacer];
}

- (void)doResizeReadingBarForKey:(unichar)eventChar {
    NSInteger numberOfLines = [readingBar numberOfLines];
    if (eventChar == NSDownArrowFunctionKey)
        numberOfLines++;
    else if (eventChar == NSUpArrowFunctionKey)
        numberOfLines--;
    if (numberOfLines > 0) {
        [readingBar setNumberOfLines:numberOfLines];
        [self updatePacer];
    }
}

- (void)moveAnnotationToPoint:(NSPoint)point onPage:(PDFPage *)page {
    // Move annotation.
    if (page) { // page should never be nil, but just to be sure
        if (page != [currentAnnotation page])
            // move the annotation to the new page
            [[self document] moveAnnotation:currentAnnotation toPage:page];
        
        NSRect newBounds = [currentAnnotation bounds];
        newBounds.origin = SKIntegralPoint(point);
        // constrain bounds inside page bounds
        newBounds = SKConstrainRect(newBounds, [page  boundsForBox:[self displayBox]]);
        
        // Change annotation's location.
        [currentAnnotation setBounds:newBounds];
    }
}

- (void)dragLineAnnotationStartPoint:(BOOL)dragStartPoint by:(NSPoint)relPoint originalStartPoint:(NSPoint)originalStartPoint originalEndPoint:(NSPoint)originalEndPoint shiftDown:(BOOL)shiftDown {
    PDFPage *page = [currentAnnotation page];
    NSRect pageBounds = [page  boundsForBox:[self displayBox]];
    NSPoint endPoint = originalEndPoint;
    NSPoint startPoint = originalStartPoint;
    NSPoint *draggedPoint = dragStartPoint ? &startPoint : &endPoint;
    
    *draggedPoint = SKConstrainPointInRect(SKAddPoints(*draggedPoint, relPoint), pageBounds);
    draggedPoint->x = floor(draggedPoint->x);
    draggedPoint->y = floor(draggedPoint->y);
    
    if (shiftDown) {
        NSPoint *fixedPoint = dragStartPoint ? &endPoint : &startPoint;
        NSPoint diffPoint = SKSubstractPoints(*draggedPoint, *fixedPoint);
        CGFloat dx = fabs(diffPoint.x), dy = fabs(diffPoint.y);
        
        if (dx < 0.4 * dy) {
            diffPoint.x = 0.0;
        } else if (dy < 0.4 * dx) {
            diffPoint.y = 0.0;
        } else {
            dx = fmin(dx, dy);
            diffPoint.x = diffPoint.x < 0.0 ? -dx : dx;
            diffPoint.y = diffPoint.y < 0.0 ? -dx : dx;
        }
        *draggedPoint = SKAddPoints(*fixedPoint, diffPoint);
    }
    
    if (NSEqualPoints(startPoint, endPoint) == NO) {
        NSRect newBounds = SKIntegralRectFromPoints(startPoint, endPoint);
        
        if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
            newBounds.size.width = MIN_NOTE_SIZE;
            newBounds.origin.x = floor(0.5 * ((startPoint.x + endPoint.x) - MIN_NOTE_SIZE));
        }
        if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
            newBounds.size.height = MIN_NOTE_SIZE;
            newBounds.origin.y = floor(0.5 * ((startPoint.y + endPoint.y) - MIN_NOTE_SIZE));
        }
        
        [currentAnnotation setStartPoint:SKSubstractPoints(startPoint, newBounds.origin)];
        [currentAnnotation setEndPoint:SKSubstractPoints(endPoint, newBounds.origin)];
        [currentAnnotation setBounds:newBounds];
    }
}

- (void)dragAnnotationResizeHandle:(SKRectEdges)resizeHandle by:(NSPoint)relPoint originalBounds:(NSRect)originalBounds originalPaths:(NSArray *)originalPaths margin:(CGFloat)margin sizeRatio:(CGFloat)ratio {
    PDFPage *page = [currentAnnotation page];
    NSRect newBounds = originalBounds;
    NSRect pageBounds = [page  boundsForBox:[self displayBox]];
    CGFloat minSize = fmax(MIN_NOTE_SIZE, 2.0 * margin + 2.0);
    BOOL isInk = [currentAnnotation isInk];
    
    if (ratio <= 0.0) {
        
        if ((resizeHandle & SKRectEdgesMaxX)) {
            newBounds.size.width += relPoint.x;
            if (NSMaxX(newBounds) > NSMaxX(pageBounds))
                newBounds.size.width = NSMaxX(pageBounds) - NSMinX(newBounds);
            if (NSWidth(newBounds) < minSize)
                newBounds.size.width = minSize;
        } else if ((resizeHandle & SKRectEdgesMinX)) {
            newBounds.origin.x += relPoint.x;
            newBounds.size.width -= relPoint.x;
            if (NSMinX(newBounds) < NSMinX(pageBounds)) {
                newBounds.size.width = NSMaxX(newBounds) - NSMinX(pageBounds);
                newBounds.origin.x = NSMinX(pageBounds);
            }
            if (NSWidth(newBounds) < minSize) {
                newBounds.origin.x = NSMaxX(newBounds) - minSize;
                newBounds.size.width = minSize;
            }
        }
        if ((resizeHandle & SKRectEdgesMaxY)) {
            newBounds.size.height += relPoint.y;
            if (NSMaxY(newBounds) > NSMaxY(pageBounds))
                newBounds.size.height = NSMaxY(pageBounds) - NSMinY(newBounds);
            if (NSHeight(newBounds) < minSize)
                newBounds.size.height = minSize;
        } else if ((resizeHandle & SKRectEdgesMinY)) {
            newBounds.origin.y += relPoint.y;
            newBounds.size.height -= relPoint.y;
            if (NSMinY(newBounds) < NSMinY(pageBounds)) {
                newBounds.size.height = NSMaxY(newBounds) - NSMinY(pageBounds);
                newBounds.origin.y = NSMinY(pageBounds);
            }
            if (NSHeight(newBounds) < minSize) {
                newBounds.origin.y = NSMaxY(newBounds) - minSize;
                newBounds.size.height = minSize;
            }
        }
        
    } else {
        
        CGFloat width = NSWidth(newBounds);
        CGFloat height = NSHeight(newBounds);
        CGFloat ds = 2.0 * margin;
        
        if ((resizeHandle & SKRectEdgesMaxX))
            width = fmax(minSize, width + relPoint.x);
        else if ((resizeHandle & SKRectEdgesMinX))
            width = fmax(minSize, width - relPoint.x);
        if ((resizeHandle & SKRectEdgesMaxY))
            height = fmax(minSize, height + relPoint.y);
        else if ((resizeHandle & SKRectEdgesMinY))
            height = fmax(minSize, height - relPoint.y);
        
        if ((resizeHandle & (SKRectEdgesMinX | SKRectEdgesMaxX)) == 0) {
            width = ds + (height - ds) * ratio;
            if (width < minSize) {
                width = minSize;
                height = ds + (width - ds) / ratio;
            }
        } else if ((resizeHandle & (SKRectEdgesMinY | SKRectEdgesMaxY)) == 0) {
            height = ds + (width - ds) / ratio;
            if (height < minSize) {
                height = minSize;
                width = ds + (height - ds) * ratio;
            }
        } else {
            width = fmax(width, ds + (height - ds) * ratio);
            height = ds + (width - ds) / ratio;
        }
        
        if ((resizeHandle & SKRectEdgesMinX)) {
            if (NSMaxX(newBounds) - width < NSMinX(pageBounds)) {
                width = fmax(minSize, NSMaxX(newBounds) - NSMinX(pageBounds));
                height = ds + (width - ds) / ratio;
            }
        } else {
            if (NSMinX(newBounds) + width > NSMaxX(pageBounds)) {
                width = fmax(minSize, NSMaxX(pageBounds) - NSMinX(newBounds));
                height = ds + (width - ds) / ratio;
            }
        }
        if ((resizeHandle & SKRectEdgesMinY)) {
            if (NSMaxY(newBounds) - height < NSMinY(pageBounds)) {
                height = fmax(minSize, NSMaxY(newBounds) - NSMinY(pageBounds));
                width = ds + (height - ds) * ratio;
            }
        } else {
            if (NSMinY(newBounds) + height > NSMaxY(pageBounds)) {
                height = fmax(minSize, NSMaxY(pageBounds) - NSMinY(newBounds));
                width = ds + (height - ds) * ratio;
            }
        }
        
        if ((resizeHandle & SKRectEdgesMinX))
            newBounds.origin.x = NSMaxX(newBounds) - width;
        if ((resizeHandle & SKRectEdgesMinY))
            newBounds.origin.y = NSMaxY(newBounds) - height;
        newBounds.size.width = width;
        newBounds.size.height = height;
        
    }
    
    newBounds = NSIntegralRect(newBounds);
    
    if (isInk) {
        NSMutableArray *paths = [NSMutableArray array];
        NSAffineTransform *transform = [NSAffineTransform transform];
        CGFloat sx = fmax(1.0, NSWidth(newBounds) - 2.0 * margin) / fmax(1.0, NSWidth(originalBounds) - 2.0 * margin);
        CGFloat sy = fmax(1.0, NSHeight(newBounds) - 2.0 * margin) / fmax(1.0, NSHeight(originalBounds) - 2.0 * margin);
        
        [transform translateXBy:margin yBy:margin];
        if (ratio > 0.0)
            [transform scaleBy:fmin(sx, sy)];
        else
            [transform scaleXBy:sx yBy:sy];
        [transform translateXBy:-margin yBy:-margin];
        
        for (NSBezierPath *path in originalPaths)
            [paths addObject:[transform transformBezierPath:path]];
        
        [currentAnnotation setBezierPaths:paths];
    }
    
    [currentAnnotation setBounds:newBounds];
}

- (void)doDragAnnotationWithEvent:(NSEvent *)theEvent {
    // currentAnnotation should be movable, or nil to be added in an appropriate note tool mode
    
    // Old (current) annotation location and click point relative to it
    NSRect originalBounds = [currentAnnotation bounds];
    BOOL isLine = [currentAnnotation isLine];
    NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    PDFPage *page = [self pageForPoint:mousePoint nearest:YES];
    NSPoint initialPoint = [self convertPoint:mousePoint toPage:page];
    SKNoteType noteType = annotationMode;
    BOOL shouldAddAnnotation = currentAnnotation == nil;
    NSPoint originalStartPoint = NSZeroPoint;
    NSPoint originalEndPoint = NSZeroPoint;
    NSArray *originalPaths = nil;
    CGFloat margin = 0.0;
    CGFloat ratio = 0.0;
    // Hit-test for resize box.
    SKRectEdges resizeHandle = [currentAnnotation resizeHandleForPoint:initialPoint scaleFactor:[self scaleFactor]];
    
    atomic_store(&highlightLayerState, SKLayerAdd);
    if (shouldAddAnnotation == NO)
        [self updatedAnnotation:currentAnnotation];
    
    if (shouldAddAnnotation) {
        if (temporaryToolMode >= SKToolModeFreeText)
            noteType = NOTE_TYPE_FROM_TEMP_TOOL_MODE(temporaryToolMode);
        originalBounds = SKRectFromCenterAndSquareSize(SKIntegralPoint(initialPoint), 0.0);
        if (noteType == SKNoteTypeAnchored) {
            PDFAnnotation *newAnnotation = [PDFAnnotation newSkimNoteWithBounds:SKRectFromCenterAndSize(initialPoint, SKNPDFAnnotationNoteSize) forType:SKNNoteString];
            [self addAnnotation:newAnnotation toPage:page select:YES];
            resizeHandle = SKRectEdgesNone;
            originalBounds = [[self currentAnnotation] bounds];
        } else if (noteType == SKNoteTypeLine) {
            isLine = YES;
            resizeHandle = SKRectEdgesMaxX;
            originalStartPoint = originalEndPoint = originalBounds.origin;
        } else {
            resizeHandle = SKRectEdgesMaxX | SKRectEdgesMinY;
        }
    } else if (isLine) {
        originalStartPoint = SKIntegralPoint(SKAddPoints([currentAnnotation startPoint], originalBounds.origin));
        originalEndPoint = SKIntegralPoint(SKAddPoints([currentAnnotation endPoint], originalBounds.origin));
    } else if ([currentAnnotation isInk]) {
        originalPaths = [[currentAnnotation paths] copy];
        margin = [currentAnnotation pathInset];
    }
    
    // we move or resize the annotation in an event loop, which ensures it's enclosed in a single undo group
    BOOL draggedAnnotation = NO;
    NSEvent *lastMouseEvent = theEvent;
    NSUInteger eventMask = NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged;
    NSView *docView = [self documentView];
    
    [self setCursorForAreaOfInterest:SKAreaOfInterestForResizeHandle(resizeHandle, page)];
    if (resizeHandle == SKRectEdgesNone) {
        [[NSCursor closedHandCursor] push];
        [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.1];
        eventMask |= NSEventMaskPeriodic;
        
        initialPoint = SKSubstractPoints(initialPoint, originalBounds.origin);
    }
    
    while (YES) {
        theEvent = [[self window] nextEventMatchingMask:eventMask];
        if ([theEvent type] == NSEventTypeLeftMouseUp) {
            break;
        } else if ([theEvent type] == NSEventTypeLeftMouseDragged) {
            if (draggedAnnotation == NO) {
                if (currentAnnotation == nil) {
                    PDFAnnotation *newAnnotation = [PDFAnnotation newSkimNoteWithBounds:SKRectFromCenterAndSquareSize(initialPoint, MIN_NOTE_SIZE) forType:SKTypeForNoteType(noteType)];
                    [self addAnnotation:newAnnotation toPage:page select:YES];
                } else if (shouldAddAnnotation == NO) {
                    [self beginNewUndoGroupIfNeeded];
                }
                draggedAnnotation = YES;
            }
            mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
            if (resizeHandle == SKRectEdgesNone) {
                lastMouseEvent = theEvent;
                [docView autoscroll:lastMouseEvent];
            }
        } else if ([theEvent type] == NSEventTypePeriodic) {
            if (draggedAnnotation == NO || [docView autoscroll:lastMouseEvent] == NO)
                continue;
        }
        BOOL shiftDown = ([theEvent modifierFlags] & NSEventModifierFlagShift) != 0;
        if (resizeHandle == SKRectEdgesNone)
            page = [self pageForPoint:mousePoint nearest:YES];
        NSPoint draggedPoint = SKSubstractPoints([self convertPoint:mousePoint toPage:page], initialPoint);
        if (resizeHandle == SKRectEdgesNone) {
            [self moveAnnotationToPoint:draggedPoint onPage:page];
        } else if (isLine) {
            [self dragLineAnnotationStartPoint:(resizeHandle & SKRectEdgesMinX) != 0 by:draggedPoint originalStartPoint:originalStartPoint originalEndPoint:originalEndPoint shiftDown:shiftDown];
        } else {
            if (shouldAddAnnotation) {
                SKRectEdges currentResizeHandle = (draggedPoint.x < 0.0 ? SKRectEdgesMinX : SKRectEdgesMaxX) | (draggedPoint.y <= 0.0 ? SKRectEdgesMinY : SKRectEdgesMaxY);
                if (currentResizeHandle != resizeHandle) {
                    resizeHandle = currentResizeHandle;
                    [self setCursorForAreaOfInterest:SKAreaOfInterestForResizeHandle(resizeHandle, page)];
                }
            }
            if (shiftDown && ratio <= 0.0) {
                if ([currentAnnotation isInk]) {
                    ratio = fmax(1.0, NSWidth(originalBounds) - 2.0 * margin) / fmax(1.0, NSHeight(originalBounds) - 2.0 * margin);
                } else if ([currentAnnotation isNote] && [currentAnnotation image]) {
                    NSSize size = [[currentAnnotation image] size];
                    ratio = size.width / size.height;
                } else {
                    ratio = 1.0;
                }
            }
            [self dragAnnotationResizeHandle:resizeHandle by:draggedPoint originalBounds:originalBounds originalPaths:originalPaths margin:margin sizeRatio:shiftDown ? ratio : 0.0];
        }
        [[highlightLayerController layer] setNeedsDisplay];
    }
    
    if (resizeHandle == SKRectEdgesNone) {
        [NSEvent stopPeriodicEvents];
        [NSCursor pop];
    }
    
    if (currentAnnotation) {
        if (draggedAnnotation && [currentAnnotation isShape] && NO == [[NSUserDefaults standardUserDefaults] boolForKey:SKDisableUpdateContentsFromEnclosedTextKey])
            [currentAnnotation autoUpdateStringWithPage:page];
        
        if (shouldAddAnnotation && (noteType == SKNoteTypeAnchored || noteType == SKNoteTypeFreeText))
            [self editCurrentAnnotation:self]; 	 
        
        atomic_store(&highlightLayerState, SKLayerRemove);
        [self updatedAnnotation:currentAnnotation];
    } else {
        atomic_store(&highlightLayerState, SKLayerNone);
        [self removeHighlightLayer];
    }
    
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
}

- (void)doClickLinkWithEvent:(NSEvent *)theEvent {
	PDFAnnotation *annotation = currentAnnotation;
    PDFPage *annotationPage = [annotation page];
    NSRect bounds = [annotation bounds];
    
    while (YES) {
		theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
        
        if ([theEvent type] == NSEventTypeLeftMouseUp)
            break;
        
        NSPoint point = NSZeroPoint;
        PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:NO];
        if (page == annotationPage && NSPointInRect(point, bounds))
            [self setCurrentAnnotation:annotation];
        else
            [self setCurrentAnnotation:nil];
	}
    
    if (currentAnnotation)
        [self editCurrentAnnotation:nil];
}

- (BOOL)doSelectAnnotationWithEvent:(NSEvent *)theEvent {
    PDFAnnotation *newCurrentAnnotation = nil;
    NSPoint point = NSZeroPoint;
    PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:NO];
    
    if (page == nil)
        return NO;
    
    if ([currentAnnotation page] == page && [currentAnnotation isResizable] && [currentAnnotation resizeHandleForPoint:point scaleFactor:[self scaleFactor]] != 0) {
        newCurrentAnnotation = currentAnnotation;
    } else {
        
        PDFAnnotation *linkAnnotation = nil;
        BOOL foundCoveringAnnotation = NO;
        id annotations = [[page annotations] reverseObjectEnumerator];
        
        // Hit test for annotation.
        for (PDFAnnotation *annotation in annotations) {
            if ([annotation shouldDisplay] == NO) {
                continue;
            } else if ([annotation hitTest:point]) {
                newCurrentAnnotation = annotation;
                break;
            } else if (NSPointInRect(point, [annotation bounds]) && (toolMode == SKToolModeText || IS_MARKUP(annotationMode)) && linkAnnotation == nil) {
                if ([annotation isLink])
                    linkAnnotation = annotation;
                else
                    foundCoveringAnnotation = YES;
            }
        }
        
        // if we did not find a Skim note, get the first link covered by another annotation to click
        if (newCurrentAnnotation == nil && linkAnnotation && foundCoveringAnnotation)
            newCurrentAnnotation = linkAnnotation;
    }
    
    if (newCurrentAnnotation == nil)
        return NO;
    
    if ([self canAddNotes]) {
        NSEventModifierFlags modifiers = [theEvent modifierFlags];
        if ((modifiers & NSEventModifierFlagOption) && [newCurrentAnnotation isMovable] &&
            [newCurrentAnnotation resizeHandleForPoint:point scaleFactor:[self scaleFactor]] == 0 &&
            [NSApp willDragMouse]) {
            // select a new copy of the annotation
            newCurrentAnnotation = [PDFAnnotation newSkimNoteWithProperties:[newCurrentAnnotation SkimNoteProperties]];
            [self addAnnotation:newCurrentAnnotation toPage:page select:NO];
        } else if (([newCurrentAnnotation isMarkup] ||
                    (toolMode == SKToolModeNote && annotationMode == SKNoteTypeInk && (newCurrentAnnotation != currentAnnotation || (modifiers & (NSEventModifierFlagShift | NSEventModifierFlagCapsLock))))) &&
                   [NSApp willDragMouse]) {
            // don't drag markup notes or in freehand tool mode, unless the note was previously selected, so we can select text or draw freehand strokes
            return NO;
        } else if ((modifiers & NSEventModifierFlagShift) && currentAnnotation != newCurrentAnnotation && [currentAnnotation page] == page && [[currentAnnotation type] isEqualToString:[newCurrentAnnotation type]] && ([currentAnnotation isMarkup] || [currentAnnotation isInk])) {
            newCurrentAnnotation = [self joinAnnotationToCurrentAnnotation:newCurrentAnnotation] ?: newCurrentAnnotation;
        }
    }
    
    if (newCurrentAnnotation != currentAnnotation)
        [self setCurrentAnnotation:newCurrentAnnotation];
    
    return YES;
}

static NSArray *scaledDashPattern(NSArray *dashPattern, CGFloat scale) {
    if ([dashPattern count] == 0)
        return nil;
    NSMutableArray *array = [NSMutableArray array];
    for (NSNumber *dash in dashPattern)
        [array addObject:[NSNumber numberWithDouble:scale * [dash doubleValue]]];
    return array;
}

- (void)doDrawFreehandNoteWithEvent:(NSEvent *)theEvent {
    NSPoint point = NSZeroPoint;
    PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:YES];
    NSPoint prevPoint = point;
    NSWindow *window = [self window];
    BOOL wasMouseCoalescingEnabled = [NSEvent isMouseCoalescingEnabled];
    BOOL addLine = ([theEvent modifierFlags] & NSEventModifierFlagOption) != 0;
    BOOL addedLine = NO;
    BOOL wantsBreak = addLine;
    NSBezierPath *bezierPath = nil;
    CGFloat scale = [self scaleFactor];
    CAShapeLayer *layer = nil;
    NSRect boxBounds = NSIntersectionRect([page boundsForBox:[self displayBox]], [self convertRect:[self unobscuredContentRect] toPage:page]);
    CGAffineTransform t = CGAffineTransformMakeRotation(-M_PI_2 * [page rotation] / 90.0);
    layer = [CAShapeLayer layer];
    // transform and place so that the path is in scaled page coordinates
    [layer setBounds:CGRectMake(scale * NSMinX(boxBounds), scale * NSMinY(boxBounds), scale * NSWidth(boxBounds), scale * NSHeight(boxBounds))];
    [layer setAnchorPoint:CGPointZero];
    [layer setPosition:NSPointToCGPoint([self convertPoint:boxBounds.origin fromPage:page])];
    [layer setAffineTransform:t];
    [layer setZPosition:1.0];
    [layer setMasksToBounds:YES];
    [layer setFillColor:NULL];
    [layer setLineJoin:kCALineJoinRound];
    [layer setLineCap:kCALineCapRound];
    if (([theEvent modifierFlags] & (NSEventModifierFlagShift | NSEventModifierFlagCapsLock)) && [currentAnnotation isInk] && [[currentAnnotation page] isEqual:page]) {
        [layer setStrokeColor:[[currentAnnotation color] CGColor]];
        [layer setLineWidth:[currentAnnotation lineWidth] * scale];
        if ([currentAnnotation borderStyle] == kPDFBorderStyleDashed) {
            [layer setLineDashPattern:scaledDashPattern([currentAnnotation dashPattern], scale)];
            [layer setLineCap:kCALineCapButt];
        }
        CGFloat r = fmin(2.0, 2.0 * scale);
        [layer setShadowRadius:r];
        [layer setShadowOffset:CGSizeApplyAffineTransform(CGSizeMake(0.0, -r), CGAffineTransformInvert(t))];
        [layer setShadowOpacity:0.33333];
    } else {
        [self setCurrentAnnotation:nil];
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        [layer setStrokeColor:[[sud colorForKey:SKInkNoteColorKey] CGColor]];
        [layer setLineWidth:[sud floatForKey:SKInkNoteLineWidthKey] * scale];
        if ((PDFBorderStyle)[sud integerForKey:SKInkNoteLineStyleKey] == kPDFBorderStyleDashed) {
            [layer setLineDashPattern:scaledDashPattern([sud arrayForKey:SKInkNoteDashPatternKey], scale)];
            [layer setLineCap:kCALineCapButt];
        }
    }
    
    [layer setContentsScale:[[self layer] contentsScale]];
    [[self layer] addSublayer:layer];
    [layer setFilters:SKColorEffectFilters()];
    
    t = CGAffineTransformMakeScale(scale, scale);
    
    // don't coalesce mouse event from mouse while drawing,
    // but not from tablets because those fire very rapidly and lead to serious delays
    if ([NSEvent currentPointingDeviceType] == NSPointingDeviceTypeUnknown)
        [NSEvent setMouseCoalescingEnabled:NO];
    
    while (YES) {
        theEvent = [window nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged | NSEventMaskFlagsChanged];
        
        if ([theEvent type] == NSEventTypeLeftMouseUp) {
            
            break;
            
        } else if ([theEvent type] == NSEventTypeLeftMouseDragged) {
            
            NSPoint oldPrevPoint = prevPoint;
            prevPoint = point;
            point = [self convertPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil] toPage:page];
            
            if (NSEqualPoints(point, prevPoint)) {
                prevPoint = oldPrevPoint;
                continue;
            } else if (addLine && wantsBreak == NO) {
                NSInteger eltCount = [bezierPath elementCount];
                NSPoint points[3] = {point, point, point};
                prevPoint = oldPrevPoint;
                if (NSCurveToBezierPathElement == [bezierPath elementAtIndex:eltCount - 1])
                    points[0] = prevPoint;
                [bezierPath setAssociatedPoints:points atIndex:eltCount - 1];
            } else if (bezierPath == nil) {
                bezierPath = [NSBezierPath bezierPath];
                [bezierPath moveToPoint:prevPoint];
                [bezierPath lineToPoint:point];
            } else {
                if (wantsBreak && NO == NSEqualPoints(prevPoint, oldPrevPoint))
                    [bezierPath lineToPoint:prevPoint];
                if (addLine)
                    [bezierPath lineToPoint:point];
                else
                    [PDFAnnotation addPoint:point toSkimNotesPath:bezierPath];
            }
            
            addedLine = addLine;
            wantsBreak = NO;
            
            CGMutablePathRef cgPath = CGPathCreateMutable();
            [bezierPath addToCGPath:cgPath transform:&t];
            [layer setPath:cgPath];
            CGPathRelease(cgPath);
            
        } else if ((([theEvent modifierFlags] & NSEventModifierFlagOption) != 0) != addLine) {
            
            addLine = addLine == NO;
            wantsBreak = addLine || addedLine;
            
        }
    }
    
    [layer removeFromSuperlayer];
    
    [NSEvent setMouseCoalescingEnabled:wasMouseCoalescingEnabled];
    
    if (bezierPath) {
        PDFAnnotation *annotation = nil;
        BOOL select = YES;
        if (currentAnnotation) {
            annotation = [PDFAnnotation newSkimNoteWithPaths:[[currentAnnotation pagePaths] arrayByAddingObject:bezierPath]];
            [annotation setColor:[currentAnnotation color]];
            [annotation setBorder:[[currentAnnotation border] copy]];
            [annotation setString:[currentAnnotation string]];
            [[self document] removeAnnotation:currentAnnotation];
        } else {
            annotation = [PDFAnnotation newSkimNoteWithPaths:@[bezierPath]];
            select = ([theEvent modifierFlags] & (NSEventModifierFlagShift | NSEventModifierFlagCapsLock)) != 0;
        }
        [self addAnnotation:annotation toPage:page select:select];
    } else if (([theEvent modifierFlags] & NSEventModifierFlagCapsLock)) {
        [self setCurrentAnnotation:nil];
    }
    
}

- (void)doEraseAnnotationsWithEvent:(NSEvent *)theEvent {
    while (YES) {
        theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
        if ([theEvent type] == NSEventTypeLeftMouseUp)
            break;
        
        NSPoint point = NSZeroPoint;
        PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:YES];
        id annotations = [[page annotations] reverseObjectEnumerator];
        
        for (PDFAnnotation *annotation in annotations) {
            if ([annotation hitTest:point]) {
                [self removeAnnotation:annotation];
                break;
            }
        }
    }
}

- (void)doSelectWithEvent:(NSEvent *)theEvent {
    NSPoint initialPoint = NSZeroPoint;
    PDFPage *page = [self pageAndPoint:&initialPoint forEvent:theEvent nearest:NO];
    if (page == nil) {
        // should never get here, see mouseDown:
        [self doDragMouseWithEvent:theEvent];
        return;
    }
    
    CGFloat margin = HANDLE_SIZE / [self scaleFactor];
    NSUInteger pageIndex = [page pageIndex];
    BOOL didSelect = selectionPageIndex != NSNotFound;
    SKRectEdges resizeHandle = didSelect ? SKResizeHandleForPointFromRect(initialPoint, selectionRect, margin) : SKRectEdgesNone;
    
    initialPoint = SKIntegralPoint(initialPoint);
    
    if (resizeHandle == SKRectEdgesNone && (didSelect == NO || NSPointInRect(initialPoint, selectionRect) == NO)) {
        @synchronized (self) {
            selectionRect.origin = initialPoint;
            selectionRect.size = NSZeroSize;
            selectionPageIndex = pageIndex;
        }
        resizeHandle = SKRectEdgesMaxX | SKRectEdgesMinY;
        if (didSelect)
            [self setNeedsDisplay:YES];
    } else if (pageIndex != selectionPageIndex) {
        if (didSelect) {
            [self setNeedsDisplayInRect:NSInsetRect(selectionRect, -margin, -margin) ofPage:[self selectToolPage]];
            [self setNeedsDisplayInRect:NSInsetRect(selectionRect, -margin, -margin) ofPage:page];
        }
        @synchronized (self) {
            selectionPageIndex = pageIndex;
        }
    }
    
	NSRect initialRect = selectionRect;
    NSRect pageBounds = [page boundsForBox:[self displayBox]];
    SKRectEdges effectiveResizeHandle = resizeHandle;
    
    [self setCursorForAreaOfInterest:SKAreaOfInterestForResizeHandle(resizeHandle, page)];
    
	while (YES) {
        
		theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
        if ([theEvent type] == NSEventTypeLeftMouseUp)
            break;
		
        // we must be dragging
        NSPoint	newPoint;
        NSRect	newRect = initialRect;
        NSPoint delta;
        
        newPoint = SKIntegralPoint([self convertPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil] toPage:page]);
        delta = SKSubstractPoints(newPoint, initialPoint);
        
        if (resizeHandle) {
            SKRectEdges newEffectiveResizeHandle = SKRectEdgesNone;
            if ((resizeHandle & SKRectEdgesMaxX))
                newEffectiveResizeHandle |= newPoint.x < NSMinX(initialRect) ? SKRectEdgesMinX : SKRectEdgesMaxX;
            else if ((resizeHandle & SKRectEdgesMinX))
                newEffectiveResizeHandle |= newPoint.x > NSMaxX(initialRect) ? SKRectEdgesMaxX : SKRectEdgesMinX;
            if ((resizeHandle & SKRectEdgesMaxY))
                newEffectiveResizeHandle |= newPoint.y < NSMinY(initialRect) ? SKRectEdgesMinY : SKRectEdgesMaxY;
            else if ((resizeHandle & SKRectEdgesMinY))
                newEffectiveResizeHandle |= newPoint.y > NSMaxY(initialRect) ? SKRectEdgesMaxY : SKRectEdgesMinY;
            if (newEffectiveResizeHandle != effectiveResizeHandle) {
                effectiveResizeHandle = newEffectiveResizeHandle;
                [self setCursorForAreaOfInterest:SKAreaOfInterestForResizeHandle(effectiveResizeHandle, page)];
            }
        }
        
        if (resizeHandle == SKRectEdgesNone) {
            newRect.origin = SKAddPoints(newRect.origin, delta);
        } else if (([theEvent modifierFlags] & NSEventModifierFlagShift)) {
            CGFloat width = NSWidth(newRect);
            CGFloat height = NSHeight(newRect);
            CGFloat square;
            
            if ((resizeHandle & SKRectEdgesMaxX))
                width += delta.x;
            else if ((resizeHandle & SKRectEdgesMinX))
                width -= delta.x;
            if ((resizeHandle & SKRectEdgesMaxY))
                height += delta.y;
            else if ((resizeHandle & SKRectEdgesMinY))
                height -= delta.y;
            
            if (0 == (resizeHandle & (SKRectEdgesMinX | SKRectEdgesMaxX)))
                square = fabs(height);
            else if (0 == (resizeHandle & (SKRectEdgesMinY | SKRectEdgesMaxY)))
                square = fabs(width);
            else
                square = fmax(fabs(width), fabs(height));
            
            if ((resizeHandle & SKRectEdgesMinX)) {
                if (width >= 0.0 && NSMaxX(newRect) - square < NSMinX(pageBounds))
                    square = NSMaxX(newRect) - NSMinX(pageBounds);
                else if (width < 0.0 && NSMaxX(newRect) + square > NSMaxX(pageBounds))
                    square =  NSMaxX(pageBounds) - NSMaxX(newRect);
            } else {
                if (width >= 0.0 && NSMinX(newRect) + square > NSMaxX(pageBounds))
                    square = NSMaxX(pageBounds) - NSMinX(newRect);
                else if (width < 0.0 && NSMinX(newRect) - square < NSMinX(pageBounds))
                    square = NSMinX(newRect) - NSMinX(pageBounds);
            }
            if ((resizeHandle & SKRectEdgesMinY)) {
                if (height >= 0.0 && NSMaxY(newRect) - square < NSMinY(pageBounds))
                    square = NSMaxY(newRect) - NSMinY(pageBounds);
                else if (height < 0.0 && NSMaxY(newRect) + square > NSMaxY(pageBounds))
                    square = NSMaxY(pageBounds) - NSMaxY(newRect);
            } else {
                if (height >= 0.0 && NSMinY(newRect) + square > NSMaxY(pageBounds))
                    square = NSMaxY(pageBounds) - NSMinY(newRect);
                if (height < 0.0 && NSMinY(newRect) - square < NSMinY(pageBounds))
                    square = NSMinY(newRect) - NSMinY(pageBounds);
            }
            
            if ((resizeHandle & SKRectEdgesMinX))
                newRect.origin.x = width < 0.0 ? NSMaxX(newRect) : NSMaxX(newRect) - square;
            else if (width < 0.0 && (resizeHandle & SKRectEdgesMaxX))
                newRect.origin.x = NSMinX(newRect) - square;
            if ((resizeHandle & SKRectEdgesMinY))
                newRect.origin.y = height < 0.0 ? NSMaxY(newRect) : NSMaxY(newRect) - square;
            else if (height < 0.0 && (resizeHandle & SKRectEdgesMaxY))
                newRect.origin.y = NSMinY(newRect) - square;
            newRect.size.width = newRect.size.height = square;
        } else {
            if ((resizeHandle & SKRectEdgesMaxX)) {
                newRect.size.width += delta.x;
                if (NSWidth(newRect) < 0.0) {
                    newRect.size.width *= -1.0;
                    newRect.origin.x -= NSWidth(newRect);
                }
            } else if ((resizeHandle & SKRectEdgesMinX)) {
                newRect.origin.x += delta.x;
                newRect.size.width -= delta.x;
                if (NSWidth(newRect) < 0.0) {
                    newRect.size.width *= -1.0;
                    newRect.origin.x -= NSWidth(newRect);
                }
            }
            
            if ((resizeHandle & SKRectEdgesMaxY)) {
                newRect.size.height += delta.y;
                if (NSHeight(newRect) < 0.0) {
                    newRect.size.height *= -1.0;
                    newRect.origin.y -= NSHeight(newRect);
                }
            } else if ((resizeHandle & SKRectEdgesMinY)) {
                newRect.origin.y += delta.y;
                newRect.size.height -= delta.y;
                if (NSHeight(newRect) < 0.0) {
                    newRect.size.height *= -1.0;
                    newRect.origin.y -= NSHeight(newRect);
                }
            }
        }
        
        // don't use NSIntersectionRect, because we want to keep empty rects
        newRect = SKIntersectionRect(newRect, pageBounds);
        if (didSelect) {
            NSRect dirtyRect = NSUnionRect(NSInsetRect(selectionRect, -margin, -margin), NSInsetRect(newRect, -margin, -margin));
            for (PDFPage *p in [self displayedPages])
                [self setNeedsDisplayInRect:dirtyRect ofPage:p];
        } else {
            [self setNeedsDisplay:YES];
            didSelect = YES;
        }
        @synchronized (self) {
            selectionRect = newRect;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
	}
    
    if (NSIsEmptyRect(selectionRect)) {
        @synchronized (self) {
            selectionRect = NSZeroRect;
            selectionPageIndex = NSNotFound;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
        [self setNeedsDisplay:YES];
    } else if (resizeHandle) {
        [self setNeedsDisplayInRect:NSInsetRect(selectionRect, -margin, -margin) ofPage:page];
    }
    
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
}

- (void)doDragReadingBarWithEvent:(NSEvent *)theEvent {
    PDFPage *readingBarPage = [readingBar page];
    PDFPage *page = readingBarPage;
    NSInteger numberOfLines = [[page lineRects] count];
    NSView *docView = [self documentView];
    NSEvent *lastMouseEvent = theEvent;
    NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSPoint mouseLocInPage = [self convertPoint:mouseLoc toPage:page];
    NSInteger lineOffset = [page indexOfLineRectAtPoint:mouseLocInPage lower:YES] - [readingBar currentLine];
    CGFloat lastY = [self convertPoint:mouseLoc toView:docView].y;
    NSDate *lastPageChangeDate = [NSDate distantPast];
    BOOL isDoubleClick = [theEvent clickCount] == 2;
    
    [[NSCursor closedHandBarCursor] push];
    
    [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.1];
    
	while (YES) {
		
        theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged | NSEventMaskPeriodic];
		
        if ([theEvent type] == NSEventTypeLeftMouseUp)
            break;
        if ([theEvent type] == NSEventTypeLeftMouseDragged) {
            lastMouseEvent = theEvent;
            isDoubleClick = NO;
        }
        
        // dragging
        mouseLoc = [self convertPoint:[lastMouseEvent locationInWindow] fromView:nil];
        if ([docView autoscroll:lastMouseEvent] == NO &&
            ([self displayMode] & kPDFDisplaySinglePageContinuous) == 0 &&
            [[NSDate date] timeIntervalSinceDate:lastPageChangeDate] > 0.7) {
            if (mouseLoc.y < NSMinY([self bounds])) {
                if ([self canGoToNextPage]) {
                    [self goToNextPage:self];
                    lastY = NSMaxY([docView bounds]);
                    lastPageChangeDate = [NSDate date];
                }
            } else if (mouseLoc.y > NSMaxY([self bounds])) {
                if ([self canGoToPreviousPage]) {
                    [self goToPreviousPage:self];
                    lastY = NSMinY([docView bounds]);
                    lastPageChangeDate = [NSDate date];
                }
            }
        }
        
        PDFPage *mousePage = [self pageForPoint:mouseLoc nearest:YES];
        if ([mousePage isEqual:page] == NO) {
            page = mousePage;
            numberOfLines = [[page lineRects] count];
        }
        
        if (numberOfLines > 0) {
            mouseLocInPage = [self convertPoint:mouseLoc toPage:mousePage];
            CGFloat y = [self convertPoint:mouseLoc toView:docView].y;
            NSInteger currentLine = [page indexOfLineRectAtPoint:mouseLocInPage lower:y < lastY] - lineOffset;
            currentLine = MAX(0, MIN(numberOfLines - (NSInteger)[readingBar numberOfLines], currentLine));
            
            if ([page isEqual:readingBarPage] == NO || currentLine != [readingBar currentLine]) {
                [readingBar goToLine:currentLine onPage:page];
                readingBarPage = page;
                lastY = y;
            }
        }
    }
    
    [NSEvent stopPeriodicEvents];
    
    if (isDoubleClick) {
        if (([lastMouseEvent modifierFlags] & NSEventModifierFlagShift) != 0)
            [readingBar goToPreviousLine];
        else
            [readingBar goToNextLine];
    }
    
    [self updatePacer];
    
    [NSCursor pop];
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:lastMouseEvent afterDelay:0];
}

static inline NSCursor *resizeCursor(NSInteger angle, BOOL single) {
    if (single) {
        switch (angle) {
            case 0:
                return [NSCursor resizeRightCursor];
            case 90:
                return [NSCursor resizeUpCursor];
            case 180:
                return [NSCursor resizeLeftCursor];
            case 270:
            default:
                return [NSCursor resizeDownCursor];
        }
    } else if ((angle % 180)) {
        return [NSCursor resizeUpDownCursor];
    } else {
        return [NSCursor resizeLeftRightCursor];
    }
}

- (void)doResizeReadingBarWithEvent:(NSEvent *)theEvent {
    PDFPage *page = [readingBar page];
    NSInteger firstLine = [readingBar currentLine];
    NSInteger angle = (360 - [page rotation] + [page lineDirectionAngle]) % 360;
    
    [resizeCursor(angle, [readingBar numberOfLines] == 1) push];
    
	while (YES) {
		
        theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
		if ([theEvent type] == NSEventTypeLeftMouseUp)
            break;
        
        // dragging
        NSPoint point = NSZeroPoint;
        if ([[self pageAndPoint:&point forEvent:theEvent nearest:YES] isEqual:page] == NO)
            continue;
        
        NSInteger numberOfLines = MAX(0, [page indexOfLineRectAtPoint:point lower:YES]) - firstLine + 1;
        
        if (numberOfLines > 0 && numberOfLines != (NSInteger)[readingBar numberOfLines]) {
            [readingBar setNumberOfLines:numberOfLines];
            [resizeCursor(angle, numberOfLines == 1) set];
        }
    }
    
    [NSCursor pop];
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
}


- (NSRect)doSelectRectWithEvent:(NSEvent *)theEvent didDrag:(BOOL *)didDrag {
    NSView *docView = [self documentView];
    NSPoint startPoint = [docView convertPoint:[theEvent locationInWindow] fromView:nil];
    NSPoint currentPoint = startPoint;
    NSRect selRect = {startPoint, NSZeroSize};
    BOOL dragged = NO;
    NSWindow *window = [self window];
    
    [self makeHighlightLayerForType:SKLayerTypeRect];
    
    while (YES) {
        theEvent = [window nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged | NSEventMaskFlagsChanged];
        
        if ([theEvent type] == NSEventTypeLeftMouseUp)
            break;
        
        // dragging or flags changed
        
        if ([theEvent type] == NSEventTypeLeftMouseDragged) {
            // change mouseLoc
            [docView autoscroll:theEvent];
            currentPoint = [docView convertPoint:[theEvent locationInWindow] fromView:nil];
            dragged = YES;
        }
        
        // center around startPoint when holding down the Shift key
        if (([theEvent modifierFlags] & NSEventModifierFlagShift))
            selRect = SKRectFromCenterAndPoint(startPoint, currentPoint);
        else
            selRect = SKRectFromPoints(startPoint, currentPoint);
        
        // intersect with the bounds, project on the bounds if necessary and allow zero width or height
        selRect = SKIntersectionRect(selRect, [docView bounds]);
        
        [highlightLayerController setRect:[self convertRect:selRect fromView:docView]];
        [[highlightLayerController layer] setNeedsDisplay];
    }
    
    [self removeHighlightLayer];

    [self setCursorForMouse:theEvent];
    
    *didDrag = dragged;
    return selRect;
}

- (void)doSelectSnapshotWithEvent:(NSEvent *)theEvent {
    [[NSCursor cameraCursor] set];
    
    BOOL dragged = NO;
    NSRect selRect = [self doSelectRectWithEvent:theEvent didDrag:&dragged];
    NSView *docView = [self documentView];
    
    NSPoint point = [self convertPoint:SKCenterPoint(selRect) fromView:docView];
    PDFPage *page = [self pageForPoint:point nearest:YES];
    NSRect rect = [self convertRect:selRect fromView:docView];
    NSRect bounds;
    NSInteger factor = 1;
    BOOL autoFits = YES;
    
    if (dragged) {
    
        bounds = [self convertRect:[docView bounds] fromView:docView];
        
        if (NSWidth(rect) < 40.0 && NSHeight(rect) < 40.0)
            factor = 3;
        else if (NSWidth(rect) < 60.0 && NSHeight(rect) < 60.0)
            factor = 2;
        
        if (factor * NSWidth(rect) < 60.0) {
            rect = NSInsetRect(rect, 0.5 * (NSWidth(rect) - 60.0 / factor), 0.0);
            if (NSMinX(rect) < NSMinX(bounds))
                rect.origin.x = NSMinX(bounds);
            if (NSMaxX(rect) > NSMaxX(bounds))
                rect.origin.x = NSMaxX(bounds) - NSWidth(rect);
        }
        if (factor * NSHeight(rect) < 60.0) {
            rect = NSInsetRect(rect, 0.0, 0.5 * (NSHeight(rect) - 60.0 / factor));
            if (NSMinY(rect) < NSMinY(bounds))
                rect.origin.y = NSMinY(bounds);
            if (NSMaxX(rect) > NSMaxY(bounds))
                rect.origin.y = NSMaxY(bounds) - NSHeight(rect);
        }
        rect = [self convertRect:rect toPage:page];
        
    } else if (toolMode == SKToolModeSelect && NSIsEmptyRect(selectionRect) == NO) {
        
        rect = NSIntersectionRect(selectionRect, [page boundsForBox:kPDFDisplayBoxCropBox]);
        
    } else {
        
        PDFAnnotation *annotation = [page annotationAtPoint:[self convertPoint:point toPage:page]];
        if ([annotation isLink]) {
            PDFDestination *destination = [annotation destination];
            if ([destination page]) {
                page = [destination page];
                point = [[destination effectiveDestinationForView:nil] point];
                point = [self convertPoint:point fromPage:page];
                point.y -= 0.5 * DEFAULT_SNAPSHOT_HEIGHT;
            }
        }
        
        rect = [self convertRect:[page boundsForBox:kPDFDisplayBoxCropBox] fromPage:page];
        rect.origin.y = point.y - 0.5 * DEFAULT_SNAPSHOT_HEIGHT;
        rect.size.height = DEFAULT_SNAPSHOT_HEIGHT;
        rect = [self convertRect:rect toPage:page];
        
        autoFits = NO;
        
    }
    
    if ([[self delegate] respondsToSelector:@selector(PDFView:showSnapshotAtPage:forRect:scaleFactor:autoFits:)])
        [[self delegate] PDFView:self showSnapshotAtPage:page forRect:rect scaleFactor:[self scaleFactor] * factor autoFits:autoFits];
}

- (void)removeLoupeWindow {
    if (loupeController) {
        [loupeController hide];
        loupeController = nil;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewMagnificationChangedNotification object:self];
    }
}

- (void)doMagnifyWithEvent:(NSEvent *)theEvent {
    if (loupeController && [theEvent clickCount] == 1) {
        
        [self removeLoupeWindow];
        
        // ??? PDFView's delayed layout seems to reset the cursor to an arrow
        [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
        
        // eat up mouse moved and mouse up events
        [self doDragMouseWithEvent:theEvent];
        
    } else {
        
        NSWindow *window = [self window];
        
        if (window == nil)
            return;
        
        if (loupeController == nil)
            loupeController = [[SKLoupeController alloc] initWithPDFView:self];
        
        NSInteger startLevel = MAX(1, [theEvent clickCount]);
        
        while ([theEvent type] != NSEventTypeLeftMouseUp) {
            @autoreleasepool{
                
                if ([theEvent type] != NSEventTypeLeftMouseUp && [theEvent type] != NSEventTypeLeftMouseDragged) {
                    // set up the currentLevel and magnification
                    NSEventModifierFlags modifierFlags = [theEvent modifierFlags];
                    CGFloat newMagnification = (modifierFlags & NSEventModifierFlagOption) ? LARGE_MAGNIFICATION : (modifierFlags & NSEventModifierFlagControl) ? SMALL_MAGNIFICATION : DEFAULT_MAGNIFICATION;
                    if ((modifierFlags & NSEventModifierFlagShift))
                        newMagnification = 1.0 / newMagnification;
                    if (fabs([loupeController magnification] - newMagnification) > 0.0001) {
                        [loupeController setMagnification:newMagnification];
                        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewMagnificationChangedNotification object:self];
                    }
                    [loupeController setLevel:(modifierFlags & NSEventModifierFlagCommand) ? startLevel + 1 : startLevel];
                }
                
                [loupeController update];
                
            }

            if (theEvent == nil)
                break;
            
            theEvent = [window nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged | NSEventMaskFlagsChanged];
        }
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKMagnifyWithMousePressedKey])
            [self removeLoupeWindow];
    }
}

- (void)doMarqueeZoomWithEvent:(NSEvent *)theEvent {
    [[NSCursor zoomInCursor] set];
    
    BOOL dragged = NO;
    NSRect selRect = [self doSelectRectWithEvent:theEvent didDrag:&dragged];
    
    if (dragged && NSIsEmptyRect(selRect) == NO) {
        NSPoint point = [self convertPoint:SKCenterPoint(selRect) fromView:[self documentView]];
        PDFPage *page = [self pageForPoint:point nearest:YES];
        NSRect rect = [self convertRect:[self convertRect:selRect fromView:[self documentView]] toPage:page];
        
        [self zoomToRect:rect onPage:page];
    } else if (dragged == NO && [self autoScales] == NO) {
        [self setAutoScales:YES];
        [self setAutoScales:NO];
    }
}

- (BOOL)doDragMouseWithEvent:(NSEvent *)theEvent {
    BOOL didDrag = NO;;
    // eat up mouseDragged/mouseUp events, so we won't get their event handlers
    while (YES) {
        if ([[[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged] type] == NSEventTypeLeftMouseUp)
            break;
        didDrag = YES;
    }
    return didDrag;
}

- (void)showHelpMenu {
    NSMenu *menu = nil;
    NSMenuItem *item;
    menu = [NSMenu menu];
    item = [menu addItemWithTitle:NSLocalizedString(@"First", @"Menu item title") action:@selector(goToFirstPage:) keyEquivalent:@"\uF700"];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    item = [menu addItemWithTitle:NSLocalizedString(@"Last", @"Menu item title") action:@selector(goToLastPage:) keyEquivalent:@"\uF701"];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    [menu addItem:[NSMenuItem separatorItem]];
    item = [menu addItemWithTitle:NSLocalizedString(@"Move Current Note", @"Menu item title") action:@selector(moveCurrentAnnotation:) keyEquivalent:@"\uF703"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Move Current Note", @"Menu item title") action:@selector(moveCurrentAnnotation:) keyEquivalent:@"\uF703"];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagShift];
    [item setTag:1];
    item = [menu addItemWithTitle:NSLocalizedString(@"Resize Current Note", @"Menu item title") action:@selector(resizeCurrentAnnotation:) keyEquivalent:@"\uF703"];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagControl];
    item = [menu addItemWithTitle:NSLocalizedString(@"Resize Current Note", @"Menu item title") action:@selector(resizeCurrentAnnotation:) keyEquivalent:@"\uF703"];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagShift | NSEventModifierFlagControl];
    [item setTag:1];
    item = [menu addItemWithTitle:NSLocalizedString(@"Auto Size Current Note", @"Menu item title") action:@selector(autoSizeCurrentAnnotation:) keyEquivalent:@"="];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagControl];
    item = [menu addItemWithTitle:NSLocalizedString(@"Auto Size Current Note", @"Menu item title") action:@selector(autoSizeCurrentAnnotation:) keyEquivalent:@"="];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagControl | NSEventModifierFlagOption];
    [item setTag:1];
    item = [menu addItemWithTitle:NSLocalizedString(@"Edit Current Note", @"Menu item title") action:@selector(editCurrentAnnotation:) keyEquivalent:@"\r"];
    [item setKeyEquivalentModifierMask:0];
    item = [menu addItemWithTitle:NSLocalizedString(@"Select Next Note", @"Menu item title") action:@selector(selectNextCurrentAnnotation:) keyEquivalent:@"\t"];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
    item = [menu addItemWithTitle:NSLocalizedString(@"Select Previous Note", @"Menu item title") action:@selector(selectPreviousCurrentAnnotation:) keyEquivalent:@"\t"];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagShift | NSEventModifierFlagOption];
    [menu addItem:[NSMenuItem separatorItem]];
    item = [menu addItemWithTitle:NSLocalizedString(@"Move Reading Bar", @"Menu item title") action:@selector(moveReadingBar:) keyEquivalent:@"\uF701"];
    [item setKeyEquivalentModifierMask:moveReadingBarModifiers];
    item = [menu addItemWithTitle:NSLocalizedString(@"Resize Reading Bar", @"Menu item title") action:@selector(resizeReadingBar:) keyEquivalent:@"\uF701"];
    [item setKeyEquivalentModifierMask:resizeReadingBarModifiers];
    [menu addItem:[NSMenuItem separatorItem]];
    item = [menu addItemWithTitle:NSLocalizedString(@"Tool Mode", @"Menu item title") action:@selector(nextToolMode:) keyEquivalent:@"\uF703"];
    [item setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagOption];
    item = [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"t"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeFreeText];
    item = [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"n"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeAnchored];
    item = [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"c"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeCircle];
    item = [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"b"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeSquare];
    item = [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"h"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeHighlight];
    item = [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"u"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeUnderline];
    item = [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"s"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeStrikeOut];
    item = [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"l"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeLine];
    item = [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"f"];
    [item setKeyEquivalentModifierMask:0];
    [item setTag:SKNoteTypeInk];
    
    NSPoint point = SKTopLeftPoint(SKRectFromCenterAndSize(SKCenterPoint([self bounds]), [menu size]));
    [menu popUpMenuPositioningItem:nil atLocation:point inView:self];
}

- (NSCursor *)cursorForNoteType:(SKNoteType)noteType {
    if (useToolModeCursors) {
        switch (noteType) {
            case SKNoteTypeFreeText:  return [NSCursor textNoteCursor];
            case SKNoteTypeAnchored:  return [NSCursor anchoredNoteCursor];
            case SKNoteTypeCircle:    return [NSCursor circleNoteCursor];
            case SKNoteTypeSquare:    return [NSCursor squareNoteCursor];
            case SKNoteTypeHighlight: return [NSCursor highlightNoteCursor];
            case SKNoteTypeUnderline: return [NSCursor underlineNoteCursor];
            case SKNoteTypeStrikeOut: return [NSCursor strikeOutNoteCursor];
            case SKNoteTypeLine:      return [NSCursor lineNoteCursor];
            case SKNoteTypeInk:       return [NSCursor inkNoteCursor];
            default:              return [NSCursor arrowCursor];
        }
    } else if (IS_MARKUP(noteType)) {
        return [NSCursor IBeamCursor];
    } else {
        return [NSCursor arrowCursor];
    }
}

- (NSCursor *)cursorForTemporaryToolMode {
    switch (temporaryToolMode) {
        case SKToolModeNone:       return [NSCursor arrowCursor];
        case SKToolModeZoom:     return [NSCursor zoomInCursor];
        case SKToolModeSnapshot: return [NSCursor cameraCursor];
        default:                 return [self cursorForNoteType:NOTE_TYPE_FROM_TEMP_TOOL_MODE(temporaryToolMode)];
    }
    return [NSCursor arrowCursor];
}

- (PDFAreaOfInterest)areaOfInterestForMouse:(NSEvent *)theEvent {
    PDFAreaOfInterest area = [super areaOfInterestForMouse:theEvent];
    NSPoint p = [theEvent locationInWindow];
    NSEventModifierFlags modifiers = [theEvent deviceIndependentModifierFlags] & ~NSEventModifierFlagCapsLock;
    
    if ([[self document] isLocked]) {
    } else if (NSPointInRect(p, [self convertRect:[self unobscuredContentRect] toView:nil]) == NO) {
        area = kPDFNoArea;
    } else if ((modifiers == NSEventModifierFlagCommand || modifiers == (NSEventModifierFlagCommand | NSEventModifierFlagShift) || modifiers == (NSEventModifierFlagCommand | NSEventModifierFlagOption))) {
        area = (area & kPDFPageArea) | SKSpecialToolArea;
    } else if ((modifiers & NSEventModifierFlagCommand) == 0 && temporaryToolMode != SKToolModeNone) {
        if ((area & kPDFPageArea))
            area = kPDFPageArea | SKTemporaryToolArea;
        else
            area = SKDragArea;
    } else {

        SKRectEdges resizeHandle = SKRectEdgesNone;
        PDFPage *page = [self pageAndPoint:&p forEvent:theEvent nearest:YES];
        
        if (readingBar && [[readingBar page] isEqual:page]) {
            NSRect bounds = [readingBar currentBounds];
            NSInteger lineAngle = [page lineDirectionAngle];
            if ((lineAngle % 180)) {
                if (p.y >= NSMinY(bounds) && p.y <= NSMaxY(bounds)) {
                    area |= SKReadingBarArea;
                    if ((lineAngle == 270 && p.y < NSMinY(bounds) + READINGBAR_RESIZE_EDGE_HEIGHT) || (lineAngle == 90 && p.y > NSMaxY(bounds) - READINGBAR_RESIZE_EDGE_HEIGHT)) {
                        if ([readingBar numberOfLines] == 1)
                            area |= SKResizeRightArea << (((360 - [page rotation] + lineAngle) % 360) / 90);
                        else
                            area |= ([page rotation] % 180) ? SKResizeLeftRightArea : SKResizeUpDownArea;
                    }
                }
            } else {
                if (p.x >= NSMinX(bounds) && p.x <= NSMaxX(bounds)) {
                    area |= SKReadingBarArea;
                    if ((lineAngle == 0 && p.x > NSMaxX(bounds) - READINGBAR_RESIZE_EDGE_HEIGHT) || (lineAngle == 180 && p.x < NSMinX(bounds) + READINGBAR_RESIZE_EDGE_HEIGHT)) {
                        if ([readingBar numberOfLines] == 1)
                            area |= SKResizeRightArea << (((360 - [page rotation] + lineAngle) % 360) / 90);
                        else
                            area |= ([page rotation] % 180) ? SKResizeUpDownArea : SKResizeLeftRightArea;
                    }
                }
            }
        }
        
        if ((area & kPDFPageArea) == 0 || toolMode == SKToolModeMove) {
            if ((area & SKReadingBarArea) == 0)
                area |= SKDragArea;
        } else if (IS_TEXT_OR_NOTE_TOOL) {
            if (editor && [[currentAnnotation page] isEqual:page] && NSPointInRect(p, [currentAnnotation bounds])) {
                area = kPDFTextFieldArea;
            } else if ((area & SKReadingBarArea) == 0) {
                if ([[currentAnnotation page] isEqual:page] && [currentAnnotation isMovable] &&
                    ((resizeHandle = [currentAnnotation resizeHandleForPoint:p scaleFactor:[self scaleFactor]]) || [currentAnnotation hitTest:p]))
                    area |= SKAreaOfInterestForResizeHandle(resizeHandle, page);
                else if ((toolMode == SKToolModeText || hideNotes || IS_MARKUP(annotationMode)) && area == kPDFPageArea && modifiers == 0 &&
                         [[page selectionForRect:SKRectFromCenterAndSize(p, TEXT_SELECT_MARGIN_SIZE)] hasCharacters] == NO)
                    area |= SKDragArea;
            }
        } else {
            area = kPDFPageArea;
            if (toolMode == SKToolModeSelect && NSIsEmptyRect(selectionRect) == NO &&
                ((resizeHandle = SKResizeHandleForPointFromRect(p, selectionRect, HANDLE_SIZE / [self scaleFactor])) || NSPointInRect(p, selectionRect)))
                area |= SKAreaOfInterestForResizeHandle(resizeHandle, page);
        }
    }
    
    return area;
}

- (void)setCursorForAreaOfInterest:(PDFAreaOfInterest)area {
    if ((area & kPDFLinkArea))
        [[NSCursor pointingHandCursor] set];
    else if ((area & SKSpecialToolArea))
        [[NSCursor arrowCursor] set];
    else if ((area & SKTemporaryToolArea))
        [[self cursorForTemporaryToolMode] set];
    else if ((area & SKDragArea))
        [[NSCursor openHandCursor] set];
    else if ((area & SKResizeUpDownArea))
        [[NSCursor resizeUpDownCursor] set];
    else if ((area & SKResizeLeftRightArea))
        [[NSCursor resizeLeftRightCursor] set];
    else if ((area & SKResizeDiagonal45Area))
        [[NSCursor resizeDiagonal45Cursor] set];
    else if ((area & SKResizeDiagonal135Area))
        [[NSCursor resizeDiagonal135Cursor] set];
    else if ((area & SKResizeRightArea))
        [[NSCursor resizeRightCursor] set];
    else if ((area & SKResizeUpArea))
        [[NSCursor resizeUpCursor] set];
    else if ((area & SKResizeLeftArea))
        [[NSCursor resizeLeftCursor] set];
    else if ((area & SKResizeDownArea))
        [[NSCursor resizeDownCursor] set];
    else if ((area & SKReadingBarArea))
        [[NSCursor openHandBarCursor] set];
    else if (area == kPDFTextFieldArea)
        [[NSCursor IBeamCursor] set];
    else if (toolMode == SKToolModeNote && (area & kPDFPageArea))
        [[self cursorForNoteType:annotationMode] set];
    else if (toolMode == SKToolModeSelect && (area & kPDFPageArea))
        [[NSCursor crosshairCursor] set];
    else if (toolMode == SKToolModeMagnify && (area & kPDFPageArea))
        [(([NSEvent modifierFlags] & NSEventModifierFlagShift) ? [NSCursor zoomOutCursor] : [NSCursor zoomInCursor]) set];
    else
        [super setCursorForAreaOfInterest:area & ~kPDFIconArea];
}

- (void)setDelegate:(id <SKPDFViewDelegate>)newDelegate {
    if (newDelegate == nil)
        [self cleanup];
    [super setDelegate:newDelegate];
    if (newDelegate) {
        NSUndoManager *undoManager = [self undoManager];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOpenOrCloseUndoGroupNotification:) name:NSUndoManagerDidOpenUndoGroupNotification object:undoManager];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOpenOrCloseUndoGroupNotification:) name:NSUndoManagerDidCloseUndoGroupNotification object:undoManager];
    }
}

- (NSString *)currentColorDefaultKeyForAlternate:(BOOL)isAlt {
    if ([self toolMode] != SKToolModeNote)
        return nil;
    switch ([self annotationMode]) {
        case SKNoteTypeFreeText:  return isAlt ? SKFreeTextNoteFontColorKey : SKFreeTextNoteColorKey;
        case SKNoteTypeAnchored:  return SKAnchoredNoteColorKey;
        case SKNoteTypeCircle:    return isAlt ? SKCircleNoteInteriorColorKey : SKCircleNoteColorKey;
        case SKNoteTypeSquare:    return isAlt ? SKSquareNoteInteriorColorKey : SKSquareNoteColorKey;
        case SKNoteTypeHighlight: return SKHighlightNoteColorKey;
        case SKNoteTypeUnderline: return SKUnderlineNoteColorKey;
        case SKNoteTypeStrikeOut: return SKStrikeOutNoteColorKey;
        case SKNoteTypeLine:      return isAlt ? SKLineNoteInteriorColorKey : SKLineNoteColorKey;
        case SKNoteTypeInk:       return SKInkNoteColorKey;
        default: return nil;
    }
}

@end

static inline PDFAreaOfInterest SKAreaOfInterestForResizeHandle(SKRectEdges mask, PDFPage *page) {
    BOOL rotated = ([page rotation] % 180 != 0);
    if (mask == 0)
        return SKDragArea;
    else if (mask == SKRectEdgesMaxX || mask == SKRectEdgesMinX)
        return rotated ? SKResizeUpDownArea : SKResizeLeftRightArea;
    else if (mask == (SKRectEdgesMaxX | SKRectEdgesMaxY) || mask == (SKRectEdgesMinX | SKRectEdgesMinY))
        return rotated ? SKResizeDiagonal135Area : SKResizeDiagonal45Area;
    else if (mask == SKRectEdgesMaxY || mask == SKRectEdgesMinY)
        return rotated ? SKResizeLeftRightArea : SKResizeUpDownArea;
    else if (mask == (SKRectEdgesMaxX | SKRectEdgesMinY) || mask == (SKRectEdgesMinX | SKRectEdgesMaxY))
        return rotated ? SKResizeDiagonal45Area : SKResizeDiagonal135Area;
    else
        return kPDFNoArea;
}

static inline NSSize SKFitTextNoteSize(NSString *string, NSFont *font, CGFloat width) {
    NSMutableParagraphStyle *parStyle = [[NSMutableParagraphStyle alloc] init];
    CGFloat descent = -[font descender];
    CGFloat lineHeight = ceil([font ascender]) + ceil(descent);
    [parStyle setLineBreakMode:NSLineBreakByWordWrapping];
    [parStyle setLineSpacing:-[font leading]];
    [parStyle setMinimumLineHeight:lineHeight];
    [parStyle setMaximumLineHeight:lineHeight];
    NSDictionary *attrs = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, parStyle, NSParagraphStyleAttributeName, nil];
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:string attributes:attrs];
    NSSize size = [attrString boundingRectWithSize:NSMakeSize(width - 4.0, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin].size;
    size.width = ceil(size.width + 4.0);
    if (@available(macOS 10.14, *))
        size.height = ceil(size.height + 6.0);
    else
        size.height = ceil(size.height + 2.0);
    return size;
}

static NSString *SKTypeForNoteType(SKNoteType annotationType) {
    static NSArray *types = nil;
    if (types == nil)
        types = @[SKNFreeTextString, SKNNoteString, SKNCircleString, SKNSquareString, SKNHighlightString, SKNUnderlineString, SKNStrikeOutString, SKNLineString, SKNInkString];
    return [types objectAtIndex:annotationType];
}

#pragma mark -

@implementation SKLayerController

@synthesize layer, delegate, rect, type, annotation;

- (void)drawLayer:(CALayer *)aLayer inContext:(CGContextRef)context {
    [delegate drawLayerControllerInContext:context];
}

@end

