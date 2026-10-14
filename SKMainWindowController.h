//
//  SKMainWindowController.h
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
#import "SKSnapshotWindowController.h"
#import "SKThumbnail.h"
#import "SKFindController.h"
#import "SKPDFView.h"
#import "PDFView_SKExtensions.h"
#import "SKPDFDocument.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SKLeftSidePaneState) {
    SKSidePaneStateThumbnail,
    SKSidePaneStateOutline
};

typedef NS_ENUM(NSInteger, SKRightSidePaneState) {
    SKSidePaneStateNote,
    SKSidePaneStateSnapshot
};

typedef NS_ENUM(NSInteger, SKFindPaneState) {
    SKFindPaneStateSingular,
    SKFindPaneStateGrouped
};

enum {
    SKWindowOptionDefault,
    SKWindowOptionMaximize,
    SKWindowOptionFit
};

extern NSNotificationName const SKMainWindowControllerDidShowOrHideOverviewNotification;

@class PDFAnnotation, PDFSelection, SKGroupedSearchResult;
@class SKSecondaryPDFView, SKPresentationView, SKStatusBar, SKFindController, SKFieldEditor, SKOverviewView, SKSideWindow;
@class SKLeftSideViewController, SKRightSideViewController, SKMainToolbarController, SKMainTouchBarController, SKNoteToolbarController, SKProgressController, SKNoteTypeSheetController, SKSnapshotWindowController, SKTransitionController;
@class SKPresentationNotesAuxiliary;

@interface SKMainWindowController : NSWindowController <SKSnapshotWindowControllerDelegate, SKThumbnailDelegate, SKFindControllerDelegate, SKPDFViewDelegate, SKPDFDocumentDelegate, NSTouchBarDelegate, NSCollectionViewDataSource> {
    NSSplitViewController               *splitViewController;
    
    NSSplitViewController               *pdfSplitViewController;
    
    NSView                              *centerContentView;
    
    SKPDFView                           *pdfView;
    
    SKSecondaryPDFView                  *secondaryPdfView;
    
    SKPresentationView                  *presentationView;
    
    SKLeftSideViewController            *leftSideController;
    SKRightSideViewController           *rightSideController;
    
    SKMainToolbarController             *toolbarController;
    
    SKMainTouchBarController            *touchBarController;
    
    SKNoteToolbarController             *noteToolbarController;
    
    SKOverviewView                      *overviewView;
    NSView                              *overviewContentView;
    
    SKStatusBar                         *statusBar;
    
    SKFindController                    *findController;
    NSLayoutConstraint                  *findBarTopConstraint;
    NSLayoutConstraint                  *pdfPaneTopConstraint;
    NSLayoutConstraint                  *pdfPaneLeftConstraint;
    NSLayoutConstraint                  *pdfPaneBottomConstraint;
    NSLayoutConstraint                  *pdfPaneRightConstraint;
    
    SKFieldEditor                       *fieldEditor;
    
    NSArray<SKThumbnail *>              *thumbnails;
    CGFloat                             thumbnailSize;
    
    NSMutableArray<PDFSelection *>      *searchResults;
    NSInteger                           searchResultIndex;
    
    NSMutableArray<SKGroupedSearchResult *> *groupedSearchResults;
    
    SKNoteTypeSheetController           *noteTypeSheetController;
    NSMutableArray<PDFAnnotation *>     *notes;
    
    NSMutableArray<PDFAnnotation *>     *widgets;
    NSMapTable<PDFAnnotation *, id>     *widgetValues;
    
    NSMutableArray<SKSnapshotWindowController *> *snapshots;
    CGFloat                             snapshotThumbnailSize;
    
    NSArray<NSString *>                 *tags;
    double                              rating;
    
    NSWindow                            *savedNormalWindow;
    SKSideWindow                        *sideWindow;
    
    SKInteractionMode                   interactionMode;
    
    SKProgressController                *progressController;
    
    __weak NSDocument                   *presentationNotesDocument;
    NSInteger                           presentationNotesOffset;
    
    SKPresentationNotesAuxiliary        *presentationNotesAuxiliary;
    
    NSButton                            *colorAccessoryView;
    NSButton                            *textColorAccessoryView;
    
    NSArray<NSString *>                 *pageLabels;
    
    NSString                            *pageLabel;
    
    SKDestination                       markedPage;
    SKDestination                       beforeMarkedPage;
    
    NSPointerArray                      *lastViewedPages;
    
    id                                  activity;
    
    NSMutableDictionary<NSString *, id> *savedNormalSetup;
    
    CGFloat                             titleBarHeight;
    
    CGFloat                             thumbnailCacheSize;
    CGFloat                             snapshotCacheSize;
    
    NSMapTable<PDFAnnotation *, NSMutableDictionary *> *undoGroupOldPropertiesPerNote;
    
    PDFDocument                         *placeholderPdfDocument;
    NSArray<NSDictionary<NSString *, id> *> *placeholderWidgetProperties;

    struct _mwcFlags {
        unsigned int leftSidePaneState:1;
        unsigned int rightSidePaneState:1;
        unsigned int savedLeftSidePaneState:1;
        unsigned int findPaneState:1;
        unsigned int caseInsensitiveSearch:1;
        unsigned int wholeWordSearch:1;
        unsigned int caseInsensitiveFilter:1;
        unsigned int highlightAllSearchResults:1;
        unsigned int autoResizeNoteRows:1;
        unsigned int noteRowHeightsNeedUpdate:1;
        unsigned int findRowHeightsNeedUpdate:1;
        unsigned int addOrRemoveNotesInBulk:1;
        unsigned int updatingOutlineSelection:1;
        unsigned int updatingThumbnailSelection:1;
        unsigned int updatingFindResults:1;
        unsigned int updatingColor:1;
        unsigned int updatingFont:1;
        unsigned int updatingFontAttributes:1;
        unsigned int updatingLine:1;
        unsigned int isEditingPDF:1;
        unsigned int isEditingTable:1;
        unsigned int isSwitchingFullScreen:1;
        unsigned int isAnimatingFindBar:1;
        unsigned int isAnimatingSplitPDF:1;
        unsigned int wantsPresentationOrFullScreen:1;
        unsigned int hasCropped:1;
        unsigned int fullSizeContent:1;
        unsigned int hidesTitleBar:1;
        unsigned int needsCleanup:1;
        unsigned int thumbnailsNeedUpdateAfterPresentaton:1;
        unsigned int thumbnailsUpdatedDuringPresentaton:1;
    } mwcFlags;
}

@property (nonatomic, nullable, strong) IBOutlet SKStatusBar *statusBar;

@property (nonatomic, nullable, strong) NSString *searchString;

- (SKTransitionController *)transitionControllerCreating:(BOOL)create;

- (SKSnapshotWindowController *)makeSnapshot;
- (void)showSnapshotsWithSetups:(NSArray<NSDictionary<NSString *, id> *> *)setups;
- (void)showNote:(PDFAnnotation *)annotation;

- (nullable NSWindowController *)windowControllerForNote:(PDFAnnotation *)annotation;

- (CGFloat)titleBarInset;

@property (nonatomic, nullable, readonly) SKPDFView *pdfView;
@property (nonatomic, nullable, readonly) PDFDocument *pdfDocument;
@property (nonatomic, nullable, readonly) PDFView *secondaryPdfView;

@property (nonatomic, nullable, readonly) PDFDocument *placeholderPdfDocument;

@property (nonatomic, nullable, readonly) NSArray<NSDictionary<NSString *, id> *> *widgetProperties;

@property (nonatomic, readonly) BOOL hasNotes;

@property (nonatomic, readonly) NSArray<PDFAnnotation *> *notes;
- (void)insertObject:(PDFAnnotation *)note inNotesAtIndex:(NSUInteger)theIndex;
- (void)insertNotes:(NSArray<PDFAnnotation *> *)newNotes atIndexes:(NSIndexSet *)theIndexes;
- (void)removeObjectFromNotesAtIndex:(NSUInteger)theIndex;
- (void)removeNotesAtIndexes:(NSIndexSet *)theIndexes;
- (void)removeAllObjectsFromNotes;

@property (nonatomic, copy) NSArray<SKThumbnail *> *thumbnails;

@property (nonatomic, readonly) NSArray<SKSnapshotWindowController *> *snapshots;
- (void)insertObject:(SKSnapshotWindowController *)snapshot inSnapshotsAtIndex:(NSUInteger)theIndex;
- (void)removeObjectFromSnapshotsAtIndex:(NSUInteger)theIndex;
- (void)removeAllObjectsFromSnapshots;

@property (nonatomic, nullable, copy) NSArray<PDFSelection *> *searchResults;

@property (nonatomic, nullable, copy) NSArray<SKGroupedSearchResult *> *groupedSearchResults;

@property (nonatomic, nullable, weak) NSDocument *presentationNotesDocument;
@property (nonatomic) NSInteger presentationNotesOffset;

@property (nonatomic, copy) NSArray<NSString *> *tags;
@property (nonatomic) double rating;

@property (nonatomic, nullable, copy) NSArray<PDFAnnotation *> *selectedNotes;

@property (nonatomic, nullable, copy) NSString *pageLabel;

@property (nonatomic, nullable, strong) PDFPage *currentPage;

@property (nonatomic, readonly) SKInteractionMode interactionMode;

@property (nonatomic) SKLeftSidePaneState leftSidePaneState;
@property (nonatomic) SKRightSidePaneState rightSidePaneState;
@property (nonatomic) SKFindPaneState findPaneState;

@property (nonatomic, readonly) BOOL displaysFindPane;
@property (nonatomic, readonly) BOOL leftSidePaneIsOpen, rightSidePaneIsOpen;
@property (nonatomic) CGFloat leftSideWidth, rightSideWidth;

@property (nonatomic, nullable, readonly) NSMenu *notesMenu;

@property (nonatomic, readonly) BOOL hasNoteToolbar;

@property (nonatomic, readonly) BOOL hasOverview;

- (void)showOverviewAnimating:(BOOL)animate;
- (void)hideOverviewAnimating:(BOOL)animate;
- (void)hideOverviewWithCompletionHandler:(void (^)(void))completionHandler;

- (void)showFindBar;

- (void)updateSearchResultHighlights;

- (BOOL)isOutlineExpanded:(PDFOutline *)outline;
- (void)setExpanded:(BOOL)flag forOutline:(PDFOutline *)outline;

- (void)resetThumbnails;
- (void)resetThumbnailSizeIfNeeded;
- (void)updateThumbnailAtPageIndex:(NSUInteger)index;
- (void)updateThumbnailsAtPageIndexes:(NSIndexSet *)indexSet;
- (void)allThumbnailsNeedUpdate;

- (void)resetSnapshotSizeIfNeeded;
- (void)snapshotNeedsUpdate:(SKSnapshotWindowController *)dirstySnapshot lowPriority:(BOOL)lowPriority;
- (void)snapshotNeedsUpdate:(SKSnapshotWindowController *)dirstySnapshot;
- (void)allSnapshotsNeedUpdate;

- (void)setPdfDocument:(nullable PDFDocument *)pdfDocument addAnnotationsWithProperties:(nullable NSArray<NSDictionary<NSString *, id> *> *)noteDicts;
- (void)addAnnotationsWithProperties:(NSArray<NSDictionary<NSString *, id> *> *)noteDicts replacing:(BOOL)replacing;
- (void)addConvertedAnnotationsWithProperties:(NSArray<NSDictionary<NSString *, id> *> *)noteDicts removeAnnotations:(nullable NSArray<PDFAnnotation *> *)notesToRemove;

@property (nonatomic, copy) NSDictionary<NSString *, id> *currentSetup;

- (void)updateSubtitle;
- (void)updateLeftStatus;
- (void)updateRightStatus;

- (void)beginProgressSheetWithMessage:(NSString *)message maxValue:(NSUInteger)maxValue;
- (void)incrementProgressSheet;
- (void)dismissProgressSheet;

@end

NS_ASSUME_NONNULL_END
