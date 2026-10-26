//
//  SKPDFView.h
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

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "SKBasePDFView.h"
#import "NSDocument_SKExtensions.h"
#import <stdatomic.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const SKPDFViewDisplaysAsBookChangedNotification;
extern NSNotificationName const SKPDFViewDisplaysPageBreaksChangedNotification;
extern NSNotificationName const SKPDFViewDisplayDirectionChangedNotification;
extern NSNotificationName const SKPDFViewDisplaysRTLChangedNotification;
extern NSNotificationName const SKPDFViewAutoScalesChangedNotification;
extern NSNotificationName const SKPDFViewToolModeChangedNotification;
extern NSNotificationName const SKPDFViewToolModeChangedNotification;
extern NSNotificationName const SKPDFViewAnnotationModeChangedNotification;
extern NSNotificationName const SKPDFViewTemporaryToolModeChangedNotification;
extern NSNotificationName const SKPDFViewCurrentAnnotationChangedNotification;
extern NSNotificationName const SKPDFViewReadingBarDidChangeNotification;
extern NSNotificationName const SKPDFViewSelectionChangedNotification;
extern NSNotificationName const SKPDFViewMagnificationChangedNotification;
extern NSNotificationName const SKPDFViewPacerStartedOrStoppedNotification;
extern NSNotificationName const SKPDFViewCanSelectNoteDidChangeNotification;

extern NSString * const SKPDFViewAnnotationKey;
extern NSString * const SKPDFViewPageKey;

typedef NS_ENUM(NSInteger, SKToolMode) {
    SKToolModeText,
    SKToolModeMove,
    SKToolModeMagnify,
    SKToolModeSelect,
    SKToolModeNote
};

typedef NS_ENUM(NSInteger, SKNoteType) {
    SKNoteTypeFreeText,
    SKNoteTypeAnchored,
    SKNoteTypeCircle,
    SKNoteTypeSquare,
    SKNoteTypeHighlight,
    SKNoteTypeUnderline,
    SKNoteTypeStrikeOut,
    SKNoteTypeLine,
    SKNoteTypeInk
};

typedef NS_ENUM(NSInteger, SKTemporaryToolMode) {
    SKToolModeNone,
    SKToolModeZoom,
    SKToolModeSnapshot,
    SKToolModeFreeText,
    SKToolModeAnchored,
    SKToolModeCircle,
    SKToolModeSquare,
    SKToolModeHighlight,
    SKToolModeUnderline,
    SKToolModeStrikeOut,
    SKToolModeLine,
    SKToolModeInk
};

enum {
    SKDragArea = 1 << 16,
    SKResizeUpDownArea = 1 << 17,
    SKResizeLeftRightArea = 1 << 18,
    SKResizeDiagonal45Area = 1 << 19,
    SKResizeDiagonal135Area = 1 << 20,
    SKResizeRightArea = 1 << 21,
    SKResizeUpArea = 1 << 22,
    SKResizeLeftArea = 1 << 23,
    SKResizeDownArea = 1 << 24,
    SKReadingBarArea = 1 << 25,
    SKSpecialToolArea = 1 << 26,
    SKTemporaryToolArea = 1 << 27
};

enum {
     kPDFDisplayHorizontalContinuous = 4
};

@protocol SKPDFViewDelegate <PDFViewDelegate>
@optional
- (void)PDFViewDidBeginEditing:(PDFView *)pdfView;
- (void)PDFViewDidEndEditing:(PDFView *)pdfView;
- (void)PDFView:(PDFView *)pdfView editAnnotation:(PDFAnnotation *)annotation;
- (void)PDFView:(PDFView *)pdfView showSnapshotAtPage:(PDFPage *)page forRect:(NSRect)rect scaleFactor:(CGFloat)scaleFactor autoFits:(BOOL)autoFits;
- (void)PDFViewPerformHideFind:(PDFView *)pdfView;
- (BOOL)PDFView:(PDFView *)pdfView performAction:(PDFAction *)action;
- (void)PDFView:(PDFView *)pdfView didRotatePageAtIndex:(NSUInteger)idx by:(NSInteger)rotation;
- (nullable NSUndoManager *)undoManagerForPDFView:(PDFView *)pdfView;
@end

@class SKReadingBar, SKTypeSelectHelper, SKNavigationWindow, SKCursorStyleWindow, SKTextNoteEditor, SKSyncDot, SKLoupeController, SKLayerController;

@interface SKPDFView : SKBasePDFView {
    SKToolMode toolMode;
    SKTemporaryToolMode temporaryToolMode;
    SKNoteType annotationMode;
    
    SKReadingBar *readingBar;
    
    NSTimer *pacerTimer;
    CGFloat pacerSpeed;
    CGFloat pacerWaitTime;
    NSInteger pacerCounter;
    
    SKTypeSelectHelper *typeSelectHelper;
    
	PDFAnnotation *currentAnnotation;
    
    SKTextNoteEditor *editor;
    
    NSRect selectionRect;
    NSUInteger selectionPageIndex;
    
    PDFPage *rewindPage;
    
    SKSyncDot *syncDot;
    
    SKLayerController *highlightLayerController;
    _Atomic(NSInteger) highlightLayerState;
    
    SKLoupeController *loupeController;
    
    CGFloat gestureRotation;
    NSUInteger gesturePageIndex;
    
    NSInteger spellingTag;
    
    _Atomic(BOOL) drawsActiveSelection;
    
    BOOL hideNotes;
    BOOL wantsNewUndoGroup;
    BOOL zooming;
}

@property (nonatomic) PDFDisplayMode extendedDisplayMode;
@property (nonatomic) SKToolMode toolMode;
@property (nonatomic) SKNoteType annotationMode;
@property (nonatomic) SKTemporaryToolMode temporaryToolMode;
@property (nonatomic, nullable, strong) PDFAnnotation *currentAnnotation;
@property (nonatomic, readonly, getter=isEditing) BOOL editing;
@property (nonatomic, readonly, getter=isZooming) BOOL zooming;
@property (nonatomic) NSRect selectToolRect;
@property (nonatomic, nullable, strong) PDFPage *selectToolPage;
@property (nonatomic, readonly) CGFloat magnifyToolMagnification;
@property (nonatomic) BOOL hideNotes;
@property (nonatomic, readonly) BOOL canAddNotes;
@property (nonatomic, readonly) BOOL canSelectNote;
@property (nonatomic, readonly) BOOL hasReadingBar;
@property (nullable, readonly) SKReadingBar *readingBar;
@property (nonatomic) CGFloat pacerSpeed;
@property (nonatomic, readonly) BOOL hasPacer;
@property (nonatomic, nullable, strong) SKTypeSelectHelper *typeSelectHelper;

@property (nonatomic) BOOL needsRewind;

- (void)toggleReadingBar;

- (void)togglePacer;

- (IBAction)delete:(nullable id)sender;
- (IBAction)paste:(nullable id)sender;
- (IBAction)alternatePaste:(nullable id)sender;
- (IBAction)pasteAsPlainText:(nullable id)sender;
- (IBAction)copy:(nullable id)sender;
- (IBAction)cut:(nullable id)sender;
- (IBAction)deselectAll:(nullable id)sender;
- (IBAction)autoSelectContent:(nullable id)sender;
- (IBAction)changeToolMode:(nullable id)sender;
- (IBAction)changeAnnotationMode:(nullable id)sender;

- (void)setExtendedDisplayModeAndRewind:(PDFDisplayMode)mode;
- (void)setDisplayDirectionAndRewind:(PDFDisplayDirection)displayDirection;
- (void)setDisplaysRTLAndRewind:(BOOL)flag;
- (void)setDisplayBoxAndRewind:(PDFDisplayBox)box;
- (void)setDisplaysAsBookAndRewind:(BOOL)asBook;

@property (nonatomic, copy) NSDictionary<NSString *, id> *displaySettings;
- (void)setDisplaySettingsAndRewind:(NSDictionary<NSString *, id> *)settings;

- (void)addAnnotationsForSelections:(nullable id)sender;
- (void)addAnnotationWithType:(SKNoteType)annotationType;
- (void)removeCurrentAnnotation:(nullable id)sender;
- (void)removeThisAnnotation:(nullable id)sender;

- (void)editCurrentAnnotation:(nullable id)sender;
- (void)editThisAnnotation:(nullable id)sender;
- (void)editAnnotation:(PDFAnnotation *)annotation;

- (void)autoSizeCurrentAnnotation:(PDFAnnotation *)annotation;

- (void)selectNextCurrentAnnotation:(nullable id)sender;
- (void)selectPreviousCurrentAnnotation:(nullable id)sender;

- (void)scrollAnnotationToVisible:(PDFAnnotation *)annotation;
- (void)displayLineAtPoint:(NSPoint)point inPageAtIndex:(NSUInteger)pageIndex select:(BOOL)select showReadingBar:(BOOL)showBar;
- (void)zoomToRect:(NSRect)rect onPage:(PDFPage *)page;

- (void)takeSnapshot:(nullable id)sender;

- (void)resetPDFToolTipRects;
- (void)removePDFToolTipRects;

@property (nonatomic, nullable, weak) id<SKPDFViewDelegate> delegate;

- (nullable NSString *)currentColorDefaultKeyForAlternate:(BOOL)isAlt;

- (void)updatedAnnotation:(PDFAnnotation *)annotation forKey:(nullable NSString *)key fromValue:(nullable id)oldValue;

- (void)setNeedsDisplayInRect:(NSRect)rect ofPage:(PDFPage *)page;

@end

NS_ASSUME_NONNULL_END
