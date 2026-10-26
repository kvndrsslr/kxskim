//
//  SKMainWindowController.m
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

#import "SKMainWindowController.h"
#import "SKMainToolbarController.h"
#import "SKMainWindowController_UI.h"
#import "SKMainWindowController_FullScreen.h"
#import "SKMainWindowController_Actions.h"
#import "SKLeftSideViewController.h"
#import "SKRightSideViewController.h"
#import <Quartz/Quartz.h>
#import "SKStringConstants.h"
#import "SKNoteWindowController.h"
#import "SKInfoWindowController.h"
#import "SKBookmarkController.h"
#import "SKSideWindow.h"
#import "PDFPage_SKExtensions.h"
#import "SKMainDocument.h"
#import "SKThumbnail.h"
#import "SKPDFView.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKNoteText.h"
#import "NSBezierPath_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKOutlineView.h"
#import "SKNoteOutlineView.h"
#import "SKTableView.h"
#import "SKNoteTypeSheetController.h"
#import "NSWindowController_SKExtensions.h"
#import "SKImageToolTipWindow.h"
#import "PDFSelection_SKExtensions.h"
#import "NSValue_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "SKReadingBar.h"
#import "SKLineInspector.h"
#import "SKStatusBar.h"
#import "SKTransitionController.h"
#import "SKTypeSelectHelper.h"
#import "NSGeometry_SKExtensions.h"
#import "SKProgressController.h"
#import "SKSecondaryPDFView.h"
#import "SKColorSwatch.h"
#import "NSSegmentedControl_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "SKGroupedSearchResult.h"
#import "HIDRemote.h"
#import "NSView_SKExtensions.h"
#import "PDFOutline_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "SKColorCell.h"
#import "PDFDocument_SKExtensions.h"
#import "SKPDFPage.h"
#import "PDFView_SKExtensions.h"
#import "SKMainWindow.h"
#import "PDFOutline_SKExtensions.h"
#import "NSWindow_SKExtensions.h"
#import "SKMainTouchBarController.h"
#import "SKOverviewView.h"
#import "SKThumbnailItem.h"
#import "SKThumbnailView.h"
#import "SKSnapshotConfiguration.h"
#import "SKDocumentController.h"
#import "NSColor_SKExtensions.h"
#import "NSObject_SKExtensions.h"
#import "SKChainedUndoManager.h"
#import "SKThumbnailStamp.h"
#import "SKPresentationView.h"
#import "SKNoteToolbarController.h"
#import "SKPresentationNotesAuxiliary.h"
#import "NSCharacterSet_SKExtensions.h"
#import "SKBookmark.h"
#import "SKApplication.h"

#define MULTIPLICATION_SIGN_CHARACTER (unichar)0x00d7

#define TINY_SIZE  32.0
#define SMALL_SIZE 64.0
#define LARGE_SIZE 128.0
#define HUGE_SIZE  256.0
#define FUDGE_SIZE 0.1
#define CACHE_SIZE_FOR_SIZE(size) (size < TINY_SIZE + FUDGE_SIZE) ? TINY_SIZE : (size < SMALL_SIZE + FUDGE_SIZE) ? SMALL_SIZE : (size < LARGE_SIZE + FUDGE_SIZE) ? LARGE_SIZE : HUGE_SIZE

#define MAX_PAGE_COLUMN_WIDTH   80.0
#define MAX_PAGE_COLUMN_WIDTH_1 50.0
#define MAX_MIN_COLUMN_WIDTH    100.0

#define MIN_SIDE_PANE_WIDTH 100.0
#define MIN_PDF_PANE_WIDTH 100.0
#define MIN_PDF_PANE_HEIGHT 50.0

#define FIND_RESULT_MARGIN 50.0

#define OVERVIEW_DURATION 0.5

#define SEARCHRESULTS_KEY           @"searchResults"
#define GROUPEDSEARCHRESULTS_KEY    @"groupedSearchResults"
#define NOTES_KEY                   @"notes"
#define SNAPSHOTS_KEY               @"snapshots"

#define PAGE_COLUMNID   @"page"
#define COLOR_COLUMNID  @"color"
#define AUTHOR_COLUMNID @"author"
#define DATE_COLUMNID   @"date"

#define LABEL_COLUMNID  @"label"

#define PAGELABEL_KEY   @"pageLabel"

#define MAINWINDOWFRAME_KEY         @"windowFrame"
#define LEFTSIDEPANEWIDTH_KEY       @"leftSidePaneWidth"
#define RIGHTSIDEPANEWIDTH_KEY      @"rightSidePaneWidth"
#define DISPLAYMODE_KEY             @"displayMode"
#define DISPLAYDIRECTION_KEY        @"displayDirection"
#define TABGROUP_KEY                @"tabGroup"
#define TABINDEX_KEY                @"tabIndex"
#define PAGEINDEX_KEY               @"pageIndex"
#define SCROLLPOINT_KEY             @"scrollPoint"
#define LOCKED_KEY                  @"locked"
#define CROPBOXES_KEY               @"cropBoxes"

#define LABEL_KEY       @"label"
#define EXPANDED_KEY    @"expanded"
#define CHILDREN_KEY    @"children"

#define TRANSITION_KEY      @"transition"
#define PAGETRANSITIONS_KEY @"pageTransitions"

#define WINDOW_KEY @"window"

#define SKMainWindowFrameAutosaveName @"SKMainWindow"

static char SKPDFAnnotationPropertiesObservationContext;

static char SKMainWindowDefaultsObservationContext;

static char SKMainWindowAppObservationContext;

static char SKMainWindowThumbnailSelectionObservationContext;

static char SKMainWindowContentLayoutObservationContext;

static char SKMainWindowTransitionsObservationContext;

static char SKMainWindowSplitViewItemObservationContext;

#define SKCollapseTOCSublevelsKey @"SKCollapseTOCSublevels"

#define SKDisableSearchBarBlurringKey @"SKDisableSearchBarBlurring"

#define SKTitleAndToolbarStyleKey @"SKTitleAndToolbarStyle"

NSNotificationName const SKMainWindowControllerDidShowOrHideOverviewNotification = @"SKMainWindowControllerDidShowOrHideOverviewNotification";

#pragma mark -    

static SKDestination destinationFromSetup(NSDictionary *setup);
static void setDestinationInSetup(SKDestination dest, NSMutableDictionary *setup);
static NSArray *mergedSnapshotSetups(NSArray *setups1, NSArray *setups2);

@interface NSSplitViewItem (SKPrivateDeclarations)
@property (nonatomic) BOOL revealsOnEdgeHoverInFullscreen;
@end

@interface SKMainWindowController ()

- (void)cleanup;

- (void)updateTableFont;

- (void)updatePageLabel;

- (void)registerForDocumentNotifications;
- (void)unregisterForDocumentNotifications;

- (void)registerAsObserver;
- (void)unregisterAsObserver;

- (void)startObservingNotes:(NSArray *)newNotes;
- (void)stopObservingNotes:(NSArray *)oldNotes;

- (void)clearWidgets;

- (void)documentDidUnlockDelayed;

@end

#pragma mark -

@implementation SKMainWindowController

@synthesize statusBar, pdfView, secondaryPdfView, presentationNotesDocument, presentationNotesOffset, notes, thumbnails, snapshots, searchResults, groupedSearchResults, tags, rating, pageLabel, interactionMode, placeholderPdfDocument;
@dynamic pdfDocument, selectedNotes, hasNotes, widgetProperties, currentPage, currentSetup, leftSidePaneState, rightSidePaneState, findPaneState, displaysFindPane, leftSidePaneIsOpen, rightSidePaneIsOpen, leftSideWidth, rightSideWidth, searchString, hasNoteToolbar, hasOverview, notesMenu;

+ (BOOL)automaticallyNotifiesObserversOfPageLabel { return NO; }

- (instancetype)init {
    self = [super initWithWindowNibName:@"MainWindow"];
    if (self) {
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        
        memset(&mwcFlags, 0, sizeof(mwcFlags));
        mwcFlags.fullSizeContent = NO == [sud boolForKey:SKDisableSearchBarBlurringKey];
        mwcFlags.caseInsensitiveSearch = [sud boolForKey:SKCaseInsensitiveSearchKey];
        mwcFlags.wholeWordSearch = [sud boolForKey:SKWholeWordSearchKey];
        mwcFlags.caseInsensitiveFilter = [sud boolForKey:SKCaseInsensitiveFilterKey];
        mwcFlags.highlightAllSearchResults = [sud boolForKey:SKHighlightAllSearchResultsKey];
        mwcFlags.leftSidePaneState = SKSidePaneStateThumbnail;
        mwcFlags.rightSidePaneState = SKSidePaneStateNote;
        mwcFlags.findPaneState = SKFindPaneStateSingular;
        
        interactionMode = SKNormalMode;
        
        searchResults = nil;
        searchResultIndex = 0;
        groupedSearchResults = nil;
        thumbnails = [[NSArray alloc] init];
        notes = [[NSMutableArray alloc] init];
        widgets = nil;
        widgetValues = nil;
        tags = [[NSArray alloc] init];
        rating = 0.0;
        snapshots = [[NSMutableArray alloc] init];
        pageLabels = [[NSArray alloc] init];
        
        lastViewedPages = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality];
        titleBarHeight = 0.0;
        thumbnailCacheSize = 0.0;
        snapshotCacheSize = 0.0;
        
        savedNormalSetup = [[NSMutableDictionary alloc] init];
        placeholderPdfDocument = nil;
        placeholderWidgetProperties = nil;
        pageLabel = nil;
        markedPage = (SKDestination){NSNotFound, SKUnspecifiedPoint};
        beforeMarkedPage = (SKDestination){NSNotFound, SKUnspecifiedPoint};
        presentationNotesDocument = nil;
        presentationNotesOffset = 0;
        presentationNotesAuxiliary = nil;
        activity = nil;
        
        undoGroupOldPropertiesPerNote = nil;
    }
    return self;
}

- (void)dealloc {
    if (mwcFlags.needsCleanup)
        SKENSURE_MAIN_THREAD( [self cleanup]; );
}

// this is called from windowWillClose:
- (void)cleanup {
    mwcFlags.needsCleanup = NO;
    if (activity) {
        [[NSProcessInfo processInfo] endActivity:activity];
        activity = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopObservingNotes:[self notes]];
    [self clearWidgets];
    [self unregisterAsObserver];
    [[self window] setDelegate:nil];
    [leftSideController setMainController:nil];
    [rightSideController setMainController:nil];
    [toolbarController setMainController:nil];
    [noteToolbarController setMainController:nil];
    [touchBarController setMainController:nil];
    [findController setDelegate:nil];
    [pdfView setDelegate:nil]; // this cleans up the pdfview
    [[pdfView document] setDelegate:nil];
    [noteTypeSheetController setDelegate:nil];
    [[pdfView document] setContainingDocument:nil];
    [self setPresentationNotesDocument:nil];
}

- (void)windowDidLoad{
    // savedNormalSetup can contain pageIndex and snapshots from non-setup bookmarks
    BOOL hasWindowSetup = [savedNormalSetup count] > 2;
    NSWindow *window = [self window];
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    BOOL leftCollapsed = NO, rightCollapsed = YES;
    NSView *view;
    NSNumber *width;
    NSRect frame = [[window contentView] bounds];
    
    mwcFlags.needsCleanup = YES;
    
    // Set up the panes and subviews, needs to be done before we resize them
    
    leftSideController = [[SKLeftSideViewController alloc] init];
    [leftSideController setMainController:self];
    view = [leftSideController view];
    width = [savedNormalSetup objectForKey:LEFTSIDEPANEWIDTH_KEY] ?: [sud objectForKey:SKLeftSidePaneWidthKey];
    if (width == nil) {
        frame.size.width -= NSWidth([view frame]) + 1.0;
    } else if ([width doubleValue] > 0.0) {
        NSSize size = [view frame].size;
        size.width = MAX(MIN_SIDE_PANE_WIDTH, [width doubleValue]);
        [view setFrameSize:size];
        frame.size.width -= size.width + 1.0;
    } else {
        leftCollapsed = YES;
    }
    
    rightSideController = [[SKRightSideViewController alloc] init];
    [rightSideController setMainController:self];
    view = [rightSideController view];
    width = [savedNormalSetup objectForKey:RIGHTSIDEPANEWIDTH_KEY] ?: [sud objectForKey:SKRightSidePaneWidthKey];
    if (width && [width doubleValue] > 0.0) {
        NSSize size = [view frame].size;
        size.width = MAX(MIN_SIDE_PANE_WIDTH, [width doubleValue]);
        [view setFrameSize:size];
        rightCollapsed = NO;
        frame.size.width -= size.width + 1.0;
    }
    
    splitViewController = [[NSSplitViewController alloc] init];
    
    NSSplitViewItem *item = [NSSplitViewItem sidebarWithViewController:leftSideController];
    [item setMinimumThickness:MIN_SIDE_PANE_WIDTH];
    [item setCanCollapse:YES];
    [item setCollapsed:leftCollapsed];
    [item setHoldingPriority:260.0];
    [item setSpringLoaded:NO];
    if (@available(macOS 11.0, *))
        [item setAllowsFullHeightLayout:NO];
    [splitViewController addSplitViewItem:item];
    NSViewController *viewController = [[NSViewController alloc] init];
    centerContentView = [[NSView alloc] initWithFrame:frame];
    [viewController setView:centerContentView];
    item = [NSSplitViewItem splitViewItemWithViewController:viewController];
    [item setMinimumThickness:MIN_PDF_PANE_WIDTH];
    [item setHoldingPriority:250.0];
    [splitViewController addSplitViewItem:item];
    item = [NSSplitViewItem splitViewItemWithViewController:rightSideController];
    [item setMinimumThickness:MIN_SIDE_PANE_WIDTH];
    [item setCanCollapse:YES];
    [item setCollapsed:rightCollapsed];
    [item setHoldingPriority:255.0];
    if ([item respondsToSelector:@selector(setRevealsOnEdgeHoverInFullscreen:)])
        [item setRevealsOnEdgeHoverInFullscreen:YES];
    [splitViewController addSplitViewItem:item];
    
    view = [splitViewController view];
    NSView *contentView = [window contentView];
    NSArray *constraints = @[[[view leadingAnchor] constraintEqualToAnchor:[contentView leadingAnchor]],
        [[contentView trailingAnchor] constraintEqualToAnchor:[view trailingAnchor]],
        [[view topAnchor] constraintEqualToAnchor:[(mwcFlags.fullSizeContent ? contentView : [window contentLayoutGuide]) topAnchor]],
        [[statusBar topAnchor] constraintEqualToAnchor:[view bottomAnchor]]];
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:view];
    [NSLayoutConstraint activateConstraints:constraints];
    
    if (mwcFlags.fullSizeContent) {
        [leftSideController setCurrentView:[[leftSideController currentView] superview]];
        [rightSideController setCurrentView:[[rightSideController currentView] superview]];
    }
    
    [self updateTableFont];
    
    [leftSideController displayTableAtIndex:mwcFlags.leftSidePaneState];
    [rightSideController displayTableAtIndex:mwcFlags.rightSidePaneState];

    // we need to create the PDFView before setting the toolbar
    pdfView = [[SKPDFView alloc] initWithFrame:[centerContentView bounds]];
    
    // Set up the window
    
    enum { SKTBCompact = 1<<0, SKTBBesideTitle = 1<<1, SKTBReplacingTitle = 1<<2};
    // hidden pref for toolbar position relative to title, 0-7
    // SKTBBesideTitle | SKTBReplacingTitle = tab bar replacing title
    NSInteger placement = [[NSUserDefaults standardUserDefaults] integerForKey:SKTitleAndToolbarStyleKey];
    if (@available(macOS 11.0, *))
        [window setToolbarStyle:placement <= SKTBCompact ? NSWindowToolbarStyleExpanded : (placement & SKTBCompact) ? NSWindowToolbarStyleUnifiedCompact : NSWindowToolbarStyleUnified];
    
    // Set up the tool bar
    toolbarController = [[SKMainToolbarController alloc] init];
    [toolbarController setMainController:self];
    [toolbarController setupToolbar];
    
    if (@available(macOS 11.0, *)) {
        if (placement == SKTBCompact)
            [[window toolbar] setDisplayMode:NSToolbarDisplayModeIconOnly];
    } else if ((placement & SKTBCompact)) {
        [[window toolbar] setDisplayMode:NSToolbarDisplayModeIconOnly];
    }
    if ((placement & SKTBReplacingTitle))
        [(SKMainWindow *)window setAutoTitleVisibility:(placement & SKTBBesideTitle) ? SKWindowTitleHiddenForTabBar : SKWindowTitleHiddenForToolbar];
    
    // for animations
    [[window contentView] setWantsLayer:YES];
    
    if (mwcFlags.fullSizeContent) {
        titleBarHeight = NSHeight([window frame]) - NSHeight([window contentLayoutRect]);
        [leftSideController setTopInset:titleBarHeight];
        [rightSideController setTopInset:titleBarHeight];
        // temporarily force the contentInsets we will get, otherwise initial layout will use zero insets
        NSScrollView *scrollView = [pdfView embeddedScrollView];
        [scrollView setAutomaticallyAdjustsContentInsets:NO];
        [scrollView setContentInsets:NSEdgeInsetsMake(titleBarHeight, 0.0, 0.0, 0.0)];
    }
    
    [self setWindowFrameAutosaveNameOrCascade:SKMainWindowFrameAutosaveName];
    
    [[statusBar rightField] setAction:@selector(statusBarClicked:)];
    [[statusBar rightField] setTarget:self];

    if ([sud boolForKey:SKShowStatusBarKey] == NO)
        [statusBar toggleBelowView:[splitViewController view] animate:NO];

    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:NSLocalizedString(@"Display note size", @"Menu item title") action:@selector(toggleDisplayNoteBounds:) target:self];
    [menu addItemWithTitle:NSLocalizedString(@"Display page size", @"Menu item title") action:@selector(toggleDisplayPageBounds:) target:self];
    
    [statusBar setMenu:menu];

    if (hasWindowSetup) {
        NSString *rectString = [savedNormalSetup objectForKey:MAINWINDOWFRAME_KEY];
        if (rectString)
            [window setFrame:NSRectFromString(rectString) display:NO];
    }
    
    // Set up the PDF
    [pdfView setInterpolationQuality:[sud integerForKey:SKInterpolationQualityKey]];
    [pdfView setBackgroundColor:[PDFView defaultBackgroundColor]];
    
    [pdfView setDisplaySettings:hasWindowSetup ? savedNormalSetup : [sud dictionaryForKey:SKDefaultPDFDisplaySettingsKey]];
    
    [pdfView setDelegate:self];
    
    // this needs to be done before loading the PDFDocument
    [self resetThumbnailSizeIfNeeded];
    [self resetSnapshotSizeIfNeeded];
    
    // NB: the next line will load the PDF document and annotations, so necessary setup must be finished first!
    // windowControllerDidLoadNib: is not called automatically because the document overrides makeWindowControllers
    NSDocument *doc = [self document];
    [doc windowControllerDidLoadNib:self];
    
    // Show/hide left side pane if necessary
    BOOL hasOutline = ([[pdfView document] outlineRoot] != nil);
    if ([sud boolForKey:SKOpenContentsPaneOnlyForTOCKey] && hasOutline == leftCollapsed) {
        [[[splitViewController splitViewItems] firstObject] setCollapsed:hasOutline == NO];
        [toolbarController leftSidePaneDidShowOrHide:hasOutline];
    }
    if (hasOutline)
        [self setLeftSidePaneState:SKSidePaneStateOutline];
    else
        [leftSideController.button setEnabled:NO forSegment:SKSidePaneStateOutline];
    
    // Show/hide right side pane if necessary
    if ([sud boolForKey:SKOpenNotesPaneOnlyForNotesKey] && ([notes count] > 0) == rightCollapsed) {
        [[[splitViewController splitViewItems] lastObject] setCollapsed:rightCollapsed == NO];
        [toolbarController rightSidePaneDidShowOrHide:rightCollapsed];
    }
    
    // Due to a bug in Leopard we should only resize and swap in the PDFView after loading the PDFDocument
    
    // Make sure we already get the correct size for the pdfView,
    // so performFit: and going to a destination will calculate correctly
    [[window contentView] layoutSubtreeIfNeeded];
    
    [pdfView setFrame:[centerContentView bounds]];
    
    pdfSplitViewController = [[NSSplitViewController alloc] init];
    
    viewController = [[NSViewController alloc] init];
    [viewController setView:pdfView];
    item = [NSSplitViewItem splitViewItemWithViewController:viewController];
    [item setMinimumThickness:MIN_PDF_PANE_HEIGHT + titleBarHeight];
    [pdfSplitViewController addSplitViewItem:item];
    
    [[pdfSplitViewController splitView] setVertical:NO];
    
    view = [pdfSplitViewController view];
    [view setFrame:[centerContentView bounds]];
    constraints = @[[[view leadingAnchor] constraintEqualToAnchor:[centerContentView leadingAnchor]],
        [[centerContentView trailingAnchor] constraintEqualToAnchor:[view trailingAnchor]],
        [[view topAnchor] constraintEqualToAnchor:[centerContentView topAnchor]],
        [[centerContentView bottomAnchor] constraintEqualToAnchor:[view bottomAnchor]]];
    if (mwcFlags.fullSizeContent == NO)
        findBarTopConstraint = [constraints objectAtIndex:2];
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [centerContentView addSubview:view];
    [NSLayoutConstraint activateConstraints:constraints];
    
    // revert to automatic contentInsets
    if (mwcFlags.fullSizeContent)
        [[pdfView embeddedScrollView] setAutomaticallyAdjustsContentInsets:YES];
    
    if (hasWindowSetup == NO) {
        NSInteger windowSizeOption = [sud integerForKey:SKInitialWindowSizeOptionKey];
        
        // get the initial display mode from the PDF if present and not overridden by an explicit setup
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKUseSettingsFromPDFKey]) {
            NSDictionary *initialSettings = [[self pdfDocument] initialSettings];
            if (initialSettings) {
                [pdfView setDisplaySettings:initialSettings];
                if ([[initialSettings objectForKey:@"fitWindow"] boolValue])
                    windowSizeOption = SKWindowOptionFit;
            }
        }
        
        // We can fit only after the PDF has been loaded
        if (windowSizeOption == SKWindowOptionMaximize)
            [window zoom:nil];
        else if (windowSizeOption == SKWindowOptionFit && [[pdfView document] isLocked] == NO)
            [self performFit:nil];
    }
    
    // Go to page?
    SKDestination dest = destinationFromSetup(savedNormalSetup);
    BOOL rememberPage = dest.pageIndex == NSNotFound && [sud boolForKey:SKRememberLastPageViewedKey];
    BOOL rememberSnapshots = [sud boolForKey:SKRememberSnapshotsKey];
    SKBookmark *recentDoc = nil;
    if ((rememberPage || rememberSnapshots) && [doc fileURL])
        recentDoc = [[SKBookmarkController sharedBookmarkController] recentDocumentAtURL:[doc fileURL]];
    
    if (rememberPage && recentDoc)
        dest.pageIndex = [recentDoc pageIndex];
    if (dest.pageIndex != NSNotFound && [[pdfView document] pageCount] > dest.pageIndex) {
        if ([[pdfView document] isLocked]) {
            setDestinationInSetup(dest, savedNormalSetup);
        } else if ([[pdfView currentPage] pageIndex] != dest.pageIndex || NSEqualPoints(dest.point, SKUnspecifiedPoint) == NO) {
            [pdfView goToSKDestination:dest];
            [lastViewedPages setCount:0];
            [lastViewedPages addPointer:(void *)dest.pageIndex];
            [pdfView resetHistory];
            if (@available(macOS 12.0, *)) {
                if (([pdfView displayMode] & kPDFDisplaySinglePageContinuous)) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [pdfView scrollToSKDestination:dest];
                    });
                }
            }
        }
    }
    
    // Open snapshots?
    NSArray *snapshotSetups = [savedNormalSetup objectForKey:SNAPSHOTS_KEY];
    if (rememberSnapshots && recentDoc)
        snapshotSetups = mergedSnapshotSetups(snapshotSetups, [recentDoc snapshots]);
    if ([snapshotSetups count]) {
        if ([[pdfView document] isLocked] == NO)
            [self showSnapshotsWithSetups:snapshotSetups];
        else if (rememberSnapshots && recentDoc)
            [savedNormalSetup setObject:snapshotSetups forKey:SNAPSHOTS_KEY];
    }
    
    noteTypeSheetController = [[SKNoteTypeSheetController alloc] init];
    [noteTypeSheetController setDelegate:self];
    
    menu = [[rightSideController.noteOutlineView headerView] menu];
    [menu addItem:[NSMenuItem separatorItem]];
    [[menu addItemWithTitle:NSLocalizedString(@"Note Type", @"Menu item title") action:NULL keyEquivalent:@""] setSubmenu:[noteTypeSheetController noteTypeMenu]];
    
    [pdfView setTypeSelectHelper:[leftSideController.thumbnailTableView typeSelectHelper]];
    
    [window recalculateKeyViewLoop];
    [window makeFirstResponder:pdfView];
    
    // Update page states
    [self handlePageChangedNotification:nil];
    [toolbarController handlePageChangedNotification:nil];
    
    // Observe notifications and KVO
    [self registerForNotifications];
    [self registerAsObserver];
    
    if ([[pdfView document] isLocked]) {
        [window makeFirstResponder:[pdfView descendantOfClass:[NSSecureTextField class]]];
        [savedNormalSetup setObject:@YES forKey:LOCKED_KEY];
        [savedNormalSetup removeObjectsForKeys:@[LEFTSIDEPANEWIDTH_KEY, RIGHTSIDEPANEWIDTH_KEY, MAINWINDOWFRAME_KEY]];
    } else {
        [savedNormalSetup removeAllObjects];
    }
}

- (void)setCurrentSetup:(NSDictionary *)setup{
    if ([self isWindowLoaded] == NO) {
        [savedNormalSetup setDictionary:setup];
    } else {
        
        NSString *rectString = [setup objectForKey:MAINWINDOWFRAME_KEY];
        if (rectString) {
            if ([self interactionMode] == SKNormalMode)
                [[self window] setFrame:NSRectFromString(rectString) display:YES];
            else if ([self interactionMode] == SKFullScreenMode)
                [savedNormalSetup setObject:rectString forKey:MAINWINDOWFRAME_KEY];
            else
                [savedNormalWindow setFrame:NSRectFromString(rectString) display:NO];
        }
        
        BOOL applySidePaneWidths = ([self interactionMode] != SKFullScreenMode || [savedNormalSetup objectForKey:LEFTSIDEPANEWIDTH_KEY] == nil) && [setup objectForKey:LEFTSIDEPANEWIDTH_KEY];
        if (applySidePaneWidths) {
            [self setLeftSideWidth:[[setup objectForKey:LEFTSIDEPANEWIDTH_KEY] doubleValue]];
            [self setRightSideWidth:[[setup objectForKey:RIGHTSIDEPANEWIDTH_KEY] doubleValue]];
        }
        
        if ([[pdfView document] isLocked]) {
            NSArray *snapshotSetups = [savedNormalSetup objectForKey:SNAPSHOTS_KEY];
            [savedNormalSetup addEntriesFromDictionary:setup];
            if ([setup objectForKey:SCROLLPOINT_KEY] == nil)
                [savedNormalSetup removeObjectForKey:SCROLLPOINT_KEY];
            if (applySidePaneWidths)
                [savedNormalSetup removeObjectsForKeys:@[LEFTSIDEPANEWIDTH_KEY, RIGHTSIDEPANEWIDTH_KEY]];
            if ([self interactionMode] != SKFullScreenMode)
                [savedNormalSetup removeObjectForKey:MAINWINDOWFRAME_KEY];
            if ([snapshotSetups count])
                [savedNormalSetup setObject:mergedSnapshotSetups(snapshotSetups, [setup objectForKey:SNAPSHOTS_KEY]) forKey:SNAPSHOTS_KEY];
        } else {
            if ([self interactionMode] != SKNormalMode) {
                [savedNormalSetup addEntriesFromDictionary:setup];
                [savedNormalSetup removeObjectsForKeys:@[CROPBOXES_KEY, SNAPSHOTS_KEY, PAGEINDEX_KEY, SCROLLPOINT_KEY]];
                if (applySidePaneWidths)
                    [savedNormalSetup removeObjectsForKeys:@[LEFTSIDEPANEWIDTH_KEY, RIGHTSIDEPANEWIDTH_KEY]];
            }
            if ([setup objectForKey:DISPLAYMODE_KEY]) {
                if ([self interactionMode] == SKPresentationMode) {
                    if ([[setup objectForKey:DISPLAYMODE_KEY] integerValue] != kPDFDisplaySinglePage) {
                        NSMutableDictionary *mutableSetup = [setup mutableCopy];
                        [mutableSetup setObject:@0 forKey:DISPLAYMODE_KEY];
                        [mutableSetup setObject:@0 forKey:DISPLAYDIRECTION_KEY];
                        [pdfView setDisplaySettings:mutableSetup];
                    } else {
                        [pdfView setDisplaySettings:setup];
                    }
                    [savedNormalSetup removeObjectForKey:MAINWINDOWFRAME_KEY];
                } else if ([self interactionMode] == SKNormalMode || [[[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey] count] == 0) {
                    if ([setup objectForKey:PAGEINDEX_KEY])
                        [pdfView setDisplaySettings:setup];
                    else
                        [pdfView setDisplaySettingsAndRewind:setup];
                }
            }
            
            NSArray *cropBoxes = [setup objectForKey:CROPBOXES_KEY];
            if ([cropBoxes count] && [cropBoxes count] == [[self pdfDocument] pageCount]) {
                [[self pdfDocument] setChangedCropBoxes:cropBoxes];
                mwcFlags.hasCropped = 1;
            }
            
            NSArray *snapshotSetups = [setup objectForKey:SNAPSHOTS_KEY];
            if ([snapshotSetups count])
                [self showSnapshotsWithSetups:snapshotSetups];
            
            SKDestination dest = destinationFromSetup(setup);
            if (dest.pageIndex != NSNotFound && dest.pageIndex != [[pdfView currentPage] pageIndex])
                [pdfView goToSKDestination:dest];
        }
    }
}

- (NSDictionary *)currentSetup {
    NSMutableDictionary *setup = [NSMutableDictionary dictionary];
    SKDestination dest = [pdfView currentSKDestination:YES];
    NSArray *cropBoxes = [[self pdfDocument] changedCropBoxes];
    
    if ([self interactionMode] == SKPresentationMode)
        [setup setObject:NSStringFromRect([savedNormalWindow frame]) forKey:MAINWINDOWFRAME_KEY];
    else
        [setup setObject:NSStringFromRect([[self window] frame]) forKey:MAINWINDOWFRAME_KEY];
    [setup setObject:[NSNumber numberWithDouble:[self leftSideWidth]] forKey:LEFTSIDEPANEWIDTH_KEY];
    [setup setObject:[NSNumber numberWithDouble:[self rightSideWidth]] forKey:RIGHTSIDEPANEWIDTH_KEY];
    setDestinationInSetup(dest, setup);
    if (cropBoxes)
        [setup setObject:cropBoxes forKey:CROPBOXES_KEY];
    if ([snapshots count])
        [setup setObject:[snapshots valueForKey:SKSnapshotCurrentSetupKey] forKey:SNAPSHOTS_KEY];
    if ([self interactionMode] != SKPresentationMode)
        [setup addEntriesFromDictionary:[pdfView displaySettings]];
    if ([self interactionMode] != SKNormalMode || [[pdfView document] isLocked]) {
        [setup addEntriesFromDictionary:savedNormalSetup];
        [setup removeObjectsForKeys:@[TABGROUP_KEY, TABINDEX_KEY, LOCKED_KEY]];
    }
    
    return setup;
}

#pragma mark UI updating

- (NSString *)pageStatus {
    if ([pdfView document])
        return [NSString stringWithFormat:NSLocalizedString(@"Page %ld of %ld", @"Status message"), (long)([[[self pdfView] currentPage] pageIndex] + 1), (long)[[pdfView document] pageCount]];
    return @"";
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
    if (@available(macOS 11.0, *)) {} else if ([pdfView document])
        return [displayName stringByAppendingFormat:@" (%@)", [self pageStatus]];
    return displayName;
}

- (void)updateSubtitle {
    if (@available(macOS 11.0, *))
        [([self interactionMode] == SKPresentationMode ? savedNormalWindow : [self window]) setSubtitle:[self pageStatus]];
    else
        [self synchronizeWindowTitleWithDocumentName];
}

- (void)updateLeftStatus {
    [[statusBar leftField] setStringValue:[self pageStatus]];
}

#define CM_PER_POINT 0.035277778
#define INCH_PER_POINT 0.013888889

- (void)updateRightStatus {
    NSRect rect = [pdfView selectToolRect];
    CGFloat magnification = [pdfView magnifyToolMagnification];
    NSString *message;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayNoteBoundsKey] && NSEqualRects(rect, NSZeroRect) && [pdfView currentAnnotation])
        rect = [[pdfView currentAnnotation] bounds];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayPageBoundsKey] && NSEqualRects(rect, NSZeroRect))
        rect = [[pdfView currentPage] boundsForBox:[pdfView displayBox]];

    if (NSEqualRects(rect, NSZeroRect) == NO) {
        if ([[[statusBar rightField] cell] state] == NSControlStateValueOn) {
            BOOL useMetric = [[[NSLocale currentLocale] objectForKey:NSLocaleUsesMetricSystem] boolValue];
            NSString *units = useMetric ? NSLocalizedString(@"cm", @"size unit") : NSLocalizedString(@"in", @"size unit");
            CGFloat factor = useMetric ? CM_PER_POINT : INCH_PER_POINT;
            message = [NSString stringWithFormat:@"%.2f %C %.2f @ (%.2f, %.2f) %@", NSWidth(rect) * factor, MULTIPLICATION_SIGN_CHARACTER, NSHeight(rect) * factor, NSMinX(rect) * factor, NSMinY(rect) * factor, units];
        } else if (floor(NSMinX(rect)) >= NSMinX(rect) && floor(NSMinY(rect)) >= NSMinY(rect) && floor(NSWidth(rect)) >= NSWidth(rect) && floor(NSHeight(rect)) >= NSHeight(rect)) {
            message = [NSString stringWithFormat:@"%.0f %C %.0f @ (%.0f, %.0f) %@", NSWidth(rect), MULTIPLICATION_SIGN_CHARACTER, NSHeight(rect), NSMinX(rect), NSMinY(rect), NSLocalizedString(@"pt", @"size unit")];
        } else {
            message = [NSString stringWithFormat:@"%.1f %C %.1f @ (%.1f, %.1f) %@", NSWidth(rect), MULTIPLICATION_SIGN_CHARACTER, NSHeight(rect), NSMinX(rect), NSMinY(rect), NSLocalizedString(@"pt", @"size unit")];
        }
    } else if (magnification > 0.001) {
        if (floor(magnification) >= magnification)
            message = [NSString stringWithFormat:@"%.0f %C", magnification, MULTIPLICATION_SIGN_CHARACTER];
        else if (floor(10.0 * magnification) >= 10.0 * magnification)
            message = [NSString stringWithFormat:@"%.1f %C", magnification, MULTIPLICATION_SIGN_CHARACTER];
        else
            message = [NSString stringWithFormat:@"%.2f %C", magnification, MULTIPLICATION_SIGN_CHARACTER];
    } else {
        message = @"";
    }
    [[statusBar rightField] setStringValue:message];
}

- (void)updatePageColumnWidthForTableViews:(NSArray *)tvs {
    // this may happen for locked PDFs, nothing to do in this case
    if ([pageLabels count] == 0)
        return;
    
    NSTableColumn *tableColumn = [[tvs firstObject] tableColumnWithIdentifier:PAGE_COLUMNID];
    id cell = [tableColumn dataCell];
    CGFloat labelWidth = 0.0;
    NSString *label = nil;
    NSString *firstLabel = nil;
    CGFloat firstLabelWidth = 0.0;
    
    for (NSString *aLabel in pageLabels) {
        [cell setStringValue:aLabel];
        CGFloat aLabelWidth = [cell cellSize].width;
        if (firstLabel == nil) {
            firstLabel = aLabel;
            firstLabelWidth = aLabelWidth;
        } else if (aLabelWidth > labelWidth) {
            labelWidth = aLabelWidth;
            label = aLabel;
        }
    }
    
    if (firstLabelWidth <= labelWidth)
        firstLabel = nil;
    
    for (NSTableView *tv in tvs) {
        tableColumn = [tv tableColumnWithIdentifier:PAGE_COLUMNID];
        cell = [tableColumn dataCell];
        labelWidth = 0.0;
        if (firstLabel) {
            [cell setStringValue:firstLabel];
            labelWidth = fmin(ceil([cell cellSize].width), MAX_PAGE_COLUMN_WIDTH_1);
        }
        if (label) {
            [cell setStringValue:label];
            labelWidth = fmax(labelWidth, fmin(ceil([cell cellSize].width), MAX_PAGE_COLUMN_WIDTH));
        }
        if ([tv headerView])
            labelWidth = fmax(labelWidth, fmin(ceil([[tableColumn headerCell] cellSize].width), MAX_PAGE_COLUMN_WIDTH));
        [tableColumn setMinWidth:labelWidth];
        [tableColumn setMaxWidth:labelWidth];
        [tableColumn setWidth:labelWidth];
        [tableColumn setResizingMask:NSTableColumnNoResizing];
        [tv sizeToFit];
        NSRect frame = [tv frame];
        CGFloat width = NSWidth([[[tv enclosingScrollView] contentView] visibleRect]);
        if (NSWidth(frame) < width) {
            frame.size.width = width;
            [tv setFrame:frame];
        }
    }
}

- (NSDictionary *)expansionStateForOutline:(PDFOutline *)anOutline {
    if (anOutline == nil)
        return nil;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[anOutline label] forKey:LABEL_KEY];
    BOOL isExpanded = ([anOutline parent] == nil || [leftSideController.tocOutlineView isItemExpanded:anOutline]);
    [dict setValue:[NSNumber numberWithBool:isExpanded] forKey:EXPANDED_KEY];
    if (isExpanded) {
        NSUInteger i, iMax = [anOutline numberOfChildren];
        if (iMax > 0) {
            NSMutableArray *array = [[NSMutableArray alloc] init];
            for (i = 0; i < iMax; i++)
                [array addObject:[self expansionStateForOutline:[anOutline childAtIndex:i]]];
            [dict setValue:array forKey:CHILDREN_KEY];
        }
    }
    return dict;
}

- (void)expandOutline:(PDFOutline *)anOutline forExpansionState:(NSDictionary *)info level:(NSInteger)level {
    BOOL isExpanded = info ? [[info valueForKey:EXPANDED_KEY] boolValue] : level < 0 ? [anOutline isOpen] : level < 2;
    if (isExpanded && anOutline) {
        NSUInteger i, iMax = [anOutline numberOfChildren];
        if (iMax > 0) {
            NSMutableArray *children = [[NSMutableArray alloc] init];
            for (i = 0; i < iMax; i++)
                [children addObject:[anOutline childAtIndex:i]];
            if ([anOutline parent])
                [leftSideController.tocOutlineView expandItem:anOutline];
            if (level >= 0) ++level;
            NSArray *childrenStates = [info valueForKey:CHILDREN_KEY];
            NSEnumerator *infoEnum = nil;
            if (childrenStates && [[children valueForKey:LABEL_KEY] isEqualToArray:[childrenStates valueForKey:LABEL_KEY]])
                infoEnum = [childrenStates objectEnumerator];
            for (PDFOutline *child in children)
                [self expandOutline:child forExpansionState:[infoEnum nextObject] level:level];
        }
    }
}

- (void)updateTableFont {
    NSFont *font = [NSFont systemFontOfSize:[[NSUserDefaults standardUserDefaults] floatForKey:SKTableFontSizeKey]];
    [leftSideController.tocOutlineView setFont:font];
    [rightSideController.noteOutlineView setFont:font];
    [leftSideController.findTableView setFont:font];
    [leftSideController.groupedFindTableView setFont:font];
}

- (void)updatePageLabelsAndOutlineForExpansionState:(NSDictionary *)info {
    // update page labels, also update the size of the table columns displaying the labels
    NSArray *newPageLabels = [[pdfView document] pageLabels];
    BOOL changed = NO == [newPageLabels isEqualToArray:pageLabels];
    pageLabels = [newPageLabels copy];
    
    [self updatePageLabel];
    
    // these carry a label
    [rightSideController.noteOutlineView reloadData];
    
    // when this is called the thumbnails will also be invalid
    if (changed)
        [self updatePageColumnWidthForTableViews:[[leftSideController tableViews] arrayByAddingObjectsFromArray:[rightSideController tableViews]]];
    
    // sizeToFit sometimes crashes with certain thumbnails (?), so reload after resizing the columns
    [self resetThumbnails];
    if (changed)
        [leftSideController.thumbnailTableView reloadTypeSelectStrings];
    
    PDFOutline *outlineRoot = [[pdfView document] outlineRoot];
    
    // layout of cellview in column: |-(18+(level-1)*indentation)-[label]-(10 or 2)-|
    // layout of textfield in cellview (leading/trailing!): |-(2)-[NSTextField]-(2)-|
    // column width = width of column - intercellspacing (??)
    NSOutlineView *ov = leftSideController.tocOutlineView;
    CGFloat minWidth = fmin(MAX_MIN_COLUMN_WIDTH, 7.0 + [ov indentationPerLevel] * [outlineRoot deepestLevel]);
    [[ov tableColumnWithIdentifier:LABEL_COLUMNID] setMinWidth:minWidth];
    
    // If this is a reload following a TeX run and the user just killed the outline for some reason, we get a crash if the outlineView isn't reloaded, so no longer make it conditional on pdfOutline != nil
    if (outlineRoot) {
        mwcFlags.updatingOutlineSelection = 1;
        [ov reloadData];
        NSInteger level = [[NSUserDefaults standardUserDefaults] boolForKey:SKCollapseTOCSublevelsKey] ? ([outlineRoot numberOfChildren] > 1) : -1;
        [self expandOutline:outlineRoot forExpansionState:info level:level];
        mwcFlags.updatingOutlineSelection = 0;
        [self updateTocSelectionHighlights];
    } else {
        [ov reloadData];
    }
    
    // handle the case as above where the outline has disappeared in a reload situation
    if (nil == outlineRoot)
        [self setLeftSidePaneState:SKSidePaneStateThumbnail];

    [leftSideController.button setEnabled:outlineRoot != nil forSegment:SKSidePaneStateOutline];
}

- (void)updatePageLabels {
    // called when changing between sequential or logical page numbering
    // update page labels, also update the size of the table columns displaying the labels
    
    NSArray *newPageLabels = [[pdfView document] pageLabels];
    if ([newPageLabels isEqualToArray:pageLabels])
        return;
    
    pageLabels = [newPageLabels copy];
    
    [self updatePageLabel];
    
    [leftSideController.thumbnailTableView reloadTypeSelectStrings];
    
    NSEnumerator *thumbnailEnum = [thumbnails objectEnumerator];
    for (NSString *label in pageLabels)
        [[thumbnailEnum nextObject] setLabel:label];
    
    PDFDocument *pdfDoc = [self pdfDocument];
    for (PDFPage *page in pdfDoc) {
        [page willChangeValueForKey:@"displayLabel"];
        [page didChangeValueForKey:@"displayLabel"];
    }
    
    [[pdfDoc outlineRoot] pageLabelDidUpdate];
    
    [[self snapshots] makeObjectsPerformSelector:@selector(updatePageLabel)];
    
    [self updatePageColumnWidthForTableViews:[[leftSideController tableViews] arrayByAddingObjectsFromArray:[rightSideController tableViews]]];
}

- (void)updateBackgroundColor {
    NSColor *backgroundColor = nil;
    if (interactionMode == SKNormalMode)
        backgroundColor = [PDFView defaultBackgroundColor];
    else if (interactionMode == SKFullScreenMode)
        backgroundColor = [PDFView defaultFullScreenBackgroundColor];
    if (backgroundColor) {
        [pdfView setBackgroundColor:backgroundColor];
        [secondaryPdfView setBackgroundColor:backgroundColor];
    }
}

#pragma mark Notes and Widgets

- (void)registerWidgets:(NSArray *)array {
    [widgets addObjectsFromArray:array];
    [self startObservingNotes:array];
    for (PDFAnnotation *annotation in array)
        [widgetValues setObject:[annotation objectValue] forKey:annotation];
}

- (void)document:(PDFDocument *)document didDetectWidgets:(NSArray *)newWidgets onPage:(PDFPage *)page {
    if ([newWidgets count] && widgets && [widgets containsObject:[newWidgets firstObject]] == NO)
        [self registerWidgets:newWidgets];
}

- (void)clearWidgets {
    if ([widgets count])
        [self stopObservingNotes:widgets];
    widgets = nil;
    widgetValues = nil;
    placeholderWidgetProperties = nil;
}

- (void)updateWidgetsWithProperties:(NSArray *)widgetDicts reset:(BOOL)reset {
    NSMutableSet *unsetWidgets = reset && [widgets count] ? [NSMutableSet setWithArray:widgets] : nil;
    if (widgets == nil) {
        widgets = [[NSMutableArray alloc] init];
        widgetValues = [NSMapTable strongToStrongObjectsMapTable];
        NSArray *array = [[self pdfDocument] detectedWidgets];
        if ([array count])
            [self registerWidgets:array];
    }
    if ([widgetDicts count]) {
        PDFDocument *pdfDoc = [pdfView document];
        for (NSDictionary *dict in widgetDicts) {
            NSRect bounds = NSIntegralRect(NSRectFromString([dict objectForKey:SKNPDFAnnotationBoundsKey]));
            NSUInteger pageIndex = [[dict objectForKey:SKNPDFAnnotationPageIndexKey] unsignedIntegerValue];
            SKNPDFWidgetType widgetType = [[dict objectForKey:SKNPDFAnnotationWidgetTypeKey] integerValue];
            NSString *fieldName = [dict objectForKey:SKNPDFAnnotationFieldNameKey] ?: @"";
            for (PDFAnnotation *annotation in [[pdfDoc pageAtIndex:pageIndex] annotations]) {
                if ([annotation isWidget] &&
                    [annotation widgetType] == widgetType &&
                    [([annotation fieldName] ?: @"") isEqualToString:fieldName] &&
                    NSEqualRects(NSIntegralRect([annotation bounds]), bounds)) {
                    id value = [dict objectForKey:widgetType == kSKNPDFWidgetTypeButton ? SKNPDFAnnotationStateKey : SKNPDFAnnotationStringValueKey];
                    if ([([annotation objectValue] ?: @"") isEqual:(value ?: @"")] == NO)
                        [annotation setObjectValue:value];
                    [unsetWidgets removeObject:annotation];
                    break;
                }
            }
        }
    }
    if ([unsetWidgets count]) {
        for (PDFAnnotation *widget in unsetWidgets) {
            id origValue = [widgetValues objectForKey:widget];
            if ([([widget objectValue] ?: @"") isEqual:(origValue ?: @"")] == NO)
                [widget setObjectValue:origValue];
        }
    }
}

- (NSArray *)widgetProperties {
    if ([widgets count] == 0)
        return placeholderWidgetProperties ?: @[];
    NSMutableArray *properties = [NSMutableArray array];
    for (PDFAnnotation *widget in widgets) {
        if ([([widget objectValue] ?: @"") isEqual:([widgetValues objectForKey:widget] ?: @"")] == NO)
            [properties addObject:[widget SkimNoteProperties]];
    }
    return properties;
}

- (void)addAnnotations:(NSArray *)notesAndPagesToAdd removeAnnotations:(NSArray *)notesToRemove {
    if ([notesAndPagesToAdd count] == 0 && [notesToRemove count] == 0)
        return;
    
    PDFDocument *pdfDoc = [pdfView document];
    NSMutableIndexSet *pageIndexes = [NSMutableIndexSet indexSet];
    NSMutableArray *addedNotes = nil;
    NSMutableArray *removedNotesAndPages = nil;
    NSMutableIndexSet *removedIndexes = nil;
    
    mwcFlags.addOrRemoveNotesInBulk = 1;
    
    if ([notesToRemove count]) {
        removedNotesAndPages = [NSMutableArray array];
        if ([[notesToRemove firstObject] isSkimNote])
            removedIndexes = [NSMutableIndexSet indexSet];
        for (PDFAnnotation *annotation in notesToRemove) {
            PDFPage *page = [annotation page];
            [removedNotesAndPages addObject:@[annotation, page]];
            if (removedIndexes)
                [removedIndexes addIndex:[notes indexOfObjectIdenticalTo:annotation]];
            [pageIndexes addIndex:[page pageIndex]];
            [pdfDoc removeAnnotation:annotation];
        }
    }
    
    if ([notesAndPagesToAdd count]) {
        BOOL shouldDisplay = [pdfView hideNotes] == NO;
        addedNotes = [NSMutableArray array];
        for (NSArray *annotationAndPage in notesAndPagesToAdd) {
            PDFAnnotation *annotation = [annotationAndPage firstObject];
            PDFPage *page = [annotationAndPage lastObject];
            if ([annotation isSkimNote]) {
                [annotation setShouldDisplay:shouldDisplay];
                [annotation setShouldPrint:shouldDisplay];
            }
            [addedNotes addObject:annotation];
            [pageIndexes addIndex:[page pageIndex]];
            [pdfDoc addAnnotation:annotation toPage:page];
        }
    }
    
    mwcFlags.addOrRemoveNotesInBulk = 0;
    
    [[[[self document] undoManager] prepareWithInvocationTarget:self] addAnnotations:removedNotesAndPages removeAnnotations:addedNotes];
    
    [removedIndexes removeIndex:NSNotFound];
    
    if ([removedIndexes count])
        [self removeNotesAtIndexes:removedIndexes];
    if ([[addedNotes firstObject] isSkimNote])
        [self insertNotes:addedNotes atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange([notes count], [addedNotes count])]];
    
    // make sure we clear the undo handling
    undoGroupOldPropertiesPerNote = nil;
    [rightSideController.noteOutlineView reloadData];
    [self updateThumbnailsAtPageIndexes:pageIndexes];
    for (SKSnapshotWindowController *wc in snapshots) {
        if ([wc isPageInIndexesVisible:pageIndexes])
            [self performSelectorOnce:@selector(snapshotNeedsUpdate:) withObject:wc afterDelay:0.0];
    }
    [pdfView resetPDFToolTipRects];
}

- (NSArray *)annotationsAndPagesWithProperties:(NSArray *)noteDicts forDocument:(PDFDocument *)pdfDoc autoUpdate:(BOOL)autoUpdate widgetProperties:(NSMutableArray *)widgetDicts {
    NSMutableArray *notesAndPagesToAdd = [NSMutableArray array];
    
    // create new annotations from the dictionary and get the page to add to
    for (NSDictionary *dict in noteDicts) {
        if ([[dict objectForKey:SKNPDFAnnotationTypeKey] isEqualToString:SKNWidgetString]) {
            [widgetDicts addObject:dict];
        } else {
            PDFAnnotation *annotation = [PDFAnnotation newSkimNoteWithProperties:dict];
            if (annotation) {
                NSUInteger pageIndex = [[dict objectForKey:SKNPDFAnnotationPageIndexKey] unsignedIntegerValue];
                if (pageIndex == NSNotFound)
                    pageIndex = 0;
                else if (pageIndex >= [pdfDoc pageCount])
                    pageIndex = [pdfDoc pageCount] - 1;
                PDFPage *page = [pdfDoc pageAtIndex:pageIndex];
                if (autoUpdate && [[annotation string] length] == 0)
                    [annotation autoUpdateStringWithPage:page];
                [notesAndPagesToAdd addObject:@[annotation, page]];
            }
        }
    }
    
    return notesAndPagesToAdd;
}

- (void)addAnnotationsWithProperties:(NSArray *)noteDicts replacing:(BOOL)replacing {
    NSMutableArray *widgetDicts = [NSMutableArray array];
    NSArray *notesAndPagesToAdd = [self annotationsAndPagesWithProperties:noteDicts forDocument:[pdfView document] autoUpdate:NO widgetProperties:widgetDicts];
    
    if (replacing && [notes count]) {
        NSUndoManager *undoManager = [[self document] undoManager];
        NSInteger level = [undoManager groupingLevel];
        [pdfView removePDFToolTipRects];
        // remove the current annotations
        [pdfView setCurrentAnnotation:nil];
        [self commitEditing];
        for (NSWindowController *wc in [[[self document] windowControllers] copy]) {
            if ([wc isKindOfClass:[SKNoteWindowController class]])
                [wc close];
        }
        if ([undoManager groupingLevel] > level) {
            [undoManager endUndoGrouping];
            [undoManager beginUndoGrouping];
        }
    }
    
    [self updateWidgetsWithProperties:widgetDicts reset:replacing];
    
    [self addAnnotations:notesAndPagesToAdd removeAnnotations:replacing ? [self notes] : nil];
}

- (void)addConvertedAnnotationsWithProperties:(NSArray *)noteDicts removeAnnotations:(NSArray *)notesToRemove {
    BOOL autoUpdate = NO == [[NSUserDefaults standardUserDefaults] boolForKey:SKDisableUpdateContentsFromEnclosedTextKey];
    NSArray *notesAndPagesToAdd = [self annotationsAndPagesWithProperties:noteDicts forDocument:[pdfView document] autoUpdate:autoUpdate widgetProperties:nil];
    
    [self addAnnotations:notesAndPagesToAdd removeAnnotations:notesToRemove];
}

- (void)setPdfDocument:(PDFDocument *)pdfDocument addAnnotationsWithProperties:(NSArray *)noteDicts {
    NSMutableArray *widgetProperties = nil;
    PDFDocument *oldPdfDoc = [pdfView document];
    SKDestination dest = {NSNotFound, NSZeroPoint}, secondaryDest = {NSNotFound, NSZeroPoint};
    NSArray *snapshotDicts = nil;
    NSDictionary *openState = nil;
    BOOL unlocked = NO == [pdfDocument isLocked];
    NSUInteger pageCount = [pdfDocument pageCount];
    
    if (oldPdfDoc) {
        // this is a revert
        // need to clean up data and actions, and remember settings to restore
        if (pageCount) {
            dest = [pdfView currentSKDestination:YES];
            if (dest.pageIndex >= pageCount && dest.pageIndex != NSNotFound)
                dest = (SKDestination){pageCount - 1, SKUnspecifiedPoint};
            if (secondaryPdfView) {
                secondaryDest = [secondaryPdfView currentSKDestination:YES];
                if (secondaryDest.pageIndex >= pageCount && secondaryDest.pageIndex != NSNotFound)
                    secondaryDest = (SKDestination){pageCount - 1, SKUnspecifiedPoint};
            }
        }
        openState = [self expansionStateForOutline:[[pdfView document] outlineRoot]];
        
        if (markedPage.pageIndex >= pageCount)
            markedPage.pageIndex = beforeMarkedPage.pageIndex = NSNotFound;
        else if (beforeMarkedPage.pageIndex >= pageCount)
            beforeMarkedPage.pageIndex = NSNotFound;
        
        mwcFlags.hasCropped = 0;
        
        [oldPdfDoc cancelFindString];
        
        [self discardEditing];
        
        // make sure these will not be activated, or they can lead to a crash
        [pdfView removePDFToolTipRects];
        [pdfView setCurrentAnnotation:nil];
        
        // these will be invalid. If needed, they will be restored for the new document
        [self setSearchResults:nil];
        [self setGroupedSearchResults:nil];
        [self removeAllObjectsFromNotes];
        [self setThumbnails:@[]];
        [self clearWidgets];
        placeholderPdfDocument = nil;
        
        // remember snapshots and close them, without animation
        if ([snapshots count]) {
            snapshotDicts = [snapshots valueForKey:SKSnapshotCurrentSetupKey];
            [snapshots setValue:nil forKey:@"delegate"];
            [snapshots makeObjectsPerformSelector:@selector(close)];
            [self removeAllObjectsFromSnapshots];
            [rightSideController.snapshotTableView reloadData];
        }
        
        [lastViewedPages setCount:0];
        
        [self unregisterForDocumentNotifications];
        
        [oldPdfDoc setDelegate:nil];
        
        [oldPdfDoc setContainingDocument:nil];
        
        if (unlocked == [oldPdfDoc isLocked]) {
            if (unlocked) {
                [self performSelector:@selector(documentDidUnlockDelayed) withObject:nil afterDelay:0.0];
            } else {
                if ([self interactionMode] == SKNormalMode)
                     [savedNormalSetup setDictionary:[pdfView displaySettings]];
                 [savedNormalSetup setObject:@YES forKey:LOCKED_KEY];
                 setDestinationInSetup(dest, savedNormalSetup);
                 if ([snapshotDicts count])
                     [savedNormalSetup setObject:snapshotDicts forKey:SNAPSHOTS_KEY];
            }
        }
    }
    
    if (unlocked && pageCount) {
        NSArray *cropBoxes = [savedNormalSetup objectForKey:CROPBOXES_KEY];
        if ([cropBoxes count] == pageCount) {
            [pdfDocument setChangedCropBoxes:cropBoxes];
            mwcFlags.hasCropped = 1;
        }
        [savedNormalSetup removeObjectForKey:CROPBOXES_KEY];
    }
    
    if ([noteDicts count]) {
        PDFDocument *pdfDoc = pdfDocument;
        if ([pdfDoc allowsNotes] == NO) {
            NSUInteger i, iMax = MIN(pageCount, [[noteDicts valueForKeyPath:@"@max.pageIndex"] unsignedIntegerValue] + 1);
            pdfDoc = placeholderPdfDocument = [[SKPDFDocument alloc] init];
            [placeholderPdfDocument setContainingDocument:[self document]];
            for (i = 0; i < iMax; i++)
                [placeholderPdfDocument insertPage:[[SKPDFPage alloc] init] atIndex:i];
        }
        
        widgetProperties = [NSMutableArray array];
        
        NSArray *notesAndPagesToAdd = [self annotationsAndPagesWithProperties:noteDicts forDocument:pdfDoc autoUpdate:NO widgetProperties:widgetProperties];
        
        if ([notesAndPagesToAdd count]) {
            NSMutableArray *addedNotes = [NSMutableArray array];
            BOOL shouldDisplay = [pdfView hideNotes] == NO;
            
            for (NSArray *annotationAndPage in notesAndPagesToAdd) {
                PDFAnnotation *annotation = [annotationAndPage firstObject];
                PDFPage *page = [annotationAndPage lastObject];
                [annotation setShouldDisplay:shouldDisplay];
                [annotation setShouldPrint:shouldDisplay];
                // there is nothing to observe PDFDocument notifications at this point
                [page addAnnotation:annotation];
                if ([annotation popup]) {
                    [page removeAnnotation:[annotation popup]];
                    [annotation setPopup:nil];
                }
                [addedNotes addObject:annotation];
            }
            
            [self insertNotes:addedNotes atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [addedNotes count])]];
        } else {
            placeholderPdfDocument = nil;
        }
    }
    
    [pdfView setDocument:pdfDocument];
    [pdfDocument setDelegate:self];
    
    [secondaryPdfView setDocument:pdfDocument];
    
    [pdfDocument setContainingDocument:[self document]];

    [self registerForDocumentNotifications];
    
    if (unlocked)
        [self updateWidgetsWithProperties:widgetProperties reset:NO];
    else if ([widgetProperties count])
        placeholderWidgetProperties = [widgetProperties copy];
    
    [self updatePageLabelsAndOutlineForExpansionState:openState];
    
    if (unlocked && [snapshotDicts count])
        [self showSnapshotsWithSetups:snapshotDicts];
    
    if (unlocked && dest.pageIndex != NSNotFound) {
        [pdfView goToSKDestination:dest];
        if (secondaryDest.pageIndex != NSNotFound)
            [secondaryPdfView goToSKDestination:secondaryDest];
        [pdfView resetHistory];
    }
    
    // the number of pages may have changed
    [toolbarController handleChangedHistoryNotification:nil];
    [toolbarController handlePageChangedNotification:nil];
    [self handlePageChangedNotification:nil];
    
    // make sure we clear the undo handling
    undoGroupOldPropertiesPerNote = nil;
}

#pragma mark Accessors

- (PDFDocument *)pdfDocument{
    return [pdfView document];
}

- (void)updatePageLabel {
    NSString *label = [[pdfView currentPage] displayLabel];
    if ([label isEqualToString:pageLabel] == NO) {
        [self willChangeValueForKey:PAGELABEL_KEY];
        pageLabel = label;
        [self didChangeValueForKey:PAGELABEL_KEY];
    }
}

- (void)setPageLabel:(NSString *)label {
    if (label != pageLabel) {
        pageLabel = label;
    }
    NSUInteger idx = [pageLabels indexOfObject:label];
    if (idx != NSNotFound && [[pdfView currentPage] pageIndex] != idx)
        [pdfView goAndScrollToPage:[[pdfView document] pageAtIndex:idx]];
}

- (BOOL)validatePageLabel:(id *)value error:(NSError **)error {
    if ([pageLabels indexOfObject:*value] == NSNotFound) {
        if ([PDFPage usesSequentialPageNumbering] == NO && [*value rangeOfCharacterFromSet:[NSCharacterSet nonDecimalDigitCharacterSet]].location == NSNotFound) {
            NSUInteger idx = [*value integerValue];
            if (idx < [pageLabels count])
                *value = [pageLabels objectAtIndex:idx];
            else
                *value = [self pageLabel];
        } else {
            *value = [self pageLabel];
        }
    }
    return YES;
}

- (PDFPage *)currentPage {
    if ([self interactionMode] == SKPresentationMode)
        return [presentationView page];
    else
        return [[self pdfView] currentPage];
}

- (void)setCurrentPage:(PDFPage *)page {
    if ([self interactionMode] == SKPresentationMode)
        return [presentationView setPage:page];
    else
        [[self pdfView] goAndScrollToPage:page];
}

- (SKLeftSidePaneState)leftSidePaneState {
    return mwcFlags.leftSidePaneState;
}

- (void)setLeftSidePaneState:(SKLeftSidePaneState)newLeftSidePaneState {
    if (mwcFlags.leftSidePaneState != newLeftSidePaneState || [self displaysFindPane]) {
        mwcFlags.leftSidePaneState = newLeftSidePaneState;
        
        [leftSideController displayTableAtIndex:mwcFlags.leftSidePaneState];
    }
}

- (SKRightSidePaneState)rightSidePaneState {
    return mwcFlags.rightSidePaneState;
}

- (void)setRightSidePaneState:(SKRightSidePaneState)newRightSidePaneState {
    if (mwcFlags.rightSidePaneState != newRightSidePaneState) {
        
        if ([[rightSideController.searchField stringValue] length] > 0) {
            [rightSideController.searchField setStringValue:@""];
            [self searchNotes:rightSideController.searchField];
        }
        
        mwcFlags.rightSidePaneState = newRightSidePaneState;
        
        [rightSideController displayTableAtIndex:mwcFlags.rightSidePaneState];
    }
}

- (SKFindPaneState)findPaneState {
    return mwcFlags.findPaneState;
}

- (void)setFindPaneState:(SKFindPaneState)newFindPaneState {
    if (mwcFlags.findPaneState != newFindPaneState) {
        mwcFlags.findPaneState = newFindPaneState;
        
        [leftSideController displayTableAtIndex:2 + mwcFlags.findPaneState];
        searchResultIndex = 0;
        [self updateSearchResultHighlights];
        
    } else if ([self displaysFindPane] == NO) {
        
        [leftSideController displayTableAtIndex:2 + mwcFlags.findPaneState];
    }
}

- (BOOL)displaysFindPane {
    return leftSideController.findTableView.enclosingScrollView == leftSideController.currentView || leftSideController.groupedFindTableView.enclosingScrollView == leftSideController.currentView;
}

- (BOOL)leftSidePaneIsOpen {
    if ([self interactionMode] == SKPresentationMode)
        return [sideWindow isVisible];
    else
        return NO == [[[splitViewController splitViewItems] firstObject] isCollapsed];
}

- (BOOL)rightSidePaneIsOpen {
    if ([self interactionMode] == SKPresentationMode)
        return NO;
    else
        return NO == [[[splitViewController splitViewItems] lastObject] isCollapsed];
}

- (CGFloat)leftSideWidth {
    NSSplitViewItem *item = [[splitViewController splitViewItems] firstObject];
    return [item isCollapsed] ? 0.0 : NSWidth([[[item viewController] view] frame]);
}

- (void)setLeftSideWidth:(CGFloat)width {
    [[[splitViewController splitViewItems] firstObject] setCollapsed:width <= 0.0];
    if (width > 0.0)
        [[splitViewController splitView] setPosition:width ofDividerAtIndex:0];
}

- (CGFloat)rightSideWidth {
    NSSplitViewItem *item = [[splitViewController splitViewItems] lastObject];
    return [item isCollapsed] ? 0.0 : NSWidth([[[item viewController] view] frame]);
}

- (void)setRightSideWidth:(CGFloat)width {
    [[[splitViewController splitViewItems] lastObject] setCollapsed:width <= 0.0];
    if (width > 0.0) {
        NSSplitView *sv = [splitViewController splitView];
        [sv setPosition:[sv maxPossiblePositionOfDividerAtIndex:1] - [sv dividerThickness] - width ofDividerAtIndex:1];
    }
}

- (BOOL)hasNotes {
    if ([notes count] > 0 || [placeholderWidgetProperties count] > 0)
        return YES;
    for (PDFAnnotation *widget in widgets) {
        if ([([widget objectValue] ?: @"") isEqual:([widgetValues objectForKey:widget] ?: @"")] == NO)
            return YES;
    }
    return NO;
}

- (void)insertObject:(PDFAnnotation *)note inNotesAtIndex:(NSUInteger)theIndex {
    [notes insertObject:note atIndex:theIndex];

    // Start observing the just-inserted notes so that, when they're changed, we can record undo operations.
    [self startObservingNotes:@[note]];
}

- (void)insertNotes:(NSArray *)newNotes atIndexes:(NSIndexSet *)theIndexes {
    [notes insertObjects:newNotes atIndexes:theIndexes];

    // Start observing the just-inserted notes so that, when they're changed, we can record undo operations.
    [self startObservingNotes:newNotes];
}

- (void)removeObjectFromNotesAtIndex:(NSUInteger)theIndex {
    PDFAnnotation *note = [notes objectAtIndex:theIndex];
    
    [[self windowControllerForNote:note] close];
    
    if ([note hasNoteText])
        [rightSideController.noteOutlineView setRowHeight:0.0 forItem:[note noteText]];
    [rightSideController.noteOutlineView setRowHeight:0.0 forItem:note];
    
    // Stop observing the removed notes
    [self stopObservingNotes:@[note]];
    
    [notes removeObjectAtIndex:theIndex];
}

- (void)removeNotesAtIndexes:(NSIndexSet *)theIndexes {
    NSArray *removedNotes = [notes objectsAtIndexes:theIndexes];
    
    for (PDFAnnotation *note in removedNotes) {
        [[self windowControllerForNote:note] close];
        
        if ([note hasNoteText])
            [rightSideController.noteOutlineView setRowHeight:0.0 forItem:[note noteText]];
        [rightSideController.noteOutlineView setRowHeight:0.0 forItem:note];
    }
    
    // Stop observing the removed notes
    [self stopObservingNotes:removedNotes];
    
    [notes removeObjectsAtIndexes:theIndexes];
}

- (void)removeAllObjectsFromNotes {
    if ([notes count]) {
        for (NSWindowController *wc in [[[self document] windowControllers] copy]) {
            if ([wc isKindOfClass:[SKNoteWindowController class]]) {
                [wc discardEditing];
                [wc close];
            }
        }
        
        [rightSideController.noteOutlineView resetRowHeights];
        
        [self stopObservingNotes:notes];

        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [notes count])];
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:NOTES_KEY];
        [notes removeAllObjects];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:NOTES_KEY];
        
        [rightSideController.noteOutlineView reloadData];
    }
}

- (void)setThumbnails:(NSArray *)newThumbnails {
    [thumbnails setValue:nil forKey:@"delegate"];
    thumbnails = [newThumbnails copy];
    [thumbnails setValue:self forKey:@"delegate"];
}

- (void)insertObject:(SKSnapshotWindowController *)snapshot inSnapshotsAtIndex:(NSUInteger)theIndex {
    [snapshots insertObject:snapshot atIndex:theIndex];
}

- (void)removeObjectFromSnapshotsAtIndex:(NSUInteger)theIndex {
    [snapshots removeObjectAtIndex:theIndex];
}

- (void)removeAllObjectsFromSnapshots {
    if ([snapshots count]) {
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [snapshots count])];
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:SNAPSHOTS_KEY];
        
        [snapshots removeAllObjects];
        
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:SNAPSHOTS_KEY];
    }
}

- (NSArray *)selectedNotes {
    NSMutableArray *selectedNotes = [NSMutableArray array];
    NSIndexSet *rowIndexes = [rightSideController.noteOutlineView selectedRowIndexes];
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        id item = [rightSideController.noteOutlineView itemAtRow:row];
        if ([(PDFAnnotation *)item type] == nil)
            item = [(SKNoteText *)item note];
        if ([selectedNotes containsObject:item] == NO)
            [selectedNotes addObject:item];
    }];
    return selectedNotes;
}

- (void)setSelectedNotes:(NSArray *)newSelectedNotes {
    NSMutableIndexSet *rowIndexes = [NSMutableIndexSet indexSet];
    for (PDFAnnotation *note in newSelectedNotes) {
        NSInteger row = [rightSideController.noteOutlineView rowForItem:note];
        if (row != -1)
            [rowIndexes addIndex:row];
    }
    [rightSideController.noteOutlineView selectRowIndexes:rowIndexes byExtendingSelection:NO];
}

- (void)setSearchResults:(NSArray *)newSearchResults {
    searchResults = [newSearchResults mutableCopy];
}

- (void)setGroupedSearchResults:(NSArray *)newGroupedSearchResults {
    groupedSearchResults = [newGroupedSearchResults mutableCopy];
}

- (SKTransitionController *)transitionControllerCreating:(BOOL)create {
    SKTransitionController *transitionController = [presentationView transitionController];
    if (transitionController == nil && create) {
        transitionController = [[SKTransitionController alloc] init];
        [transitionController addObserver:self forKeyPath:TRANSITION_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKMainWindowTransitionsObservationContext];
        [transitionController addObserver:self forKeyPath:PAGETRANSITIONS_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKMainWindowTransitionsObservationContext];
        if (presentationView == nil)
            presentationView = [[SKPresentationView alloc] init];
        [presentationView setTransitionController:transitionController];
    }
    return transitionController;
}

- (void)setPresentationNotesDocument:(NSDocument *)newDocument {
    [self removePresentationNotesNavigation];
    if (presentationNotesDocument != newDocument) {
        presentationNotesDocument = newDocument;
    }
}

- (NSUndoManager *)presentationUndoManager {
    NSUndoManager *undoManager = [presentationNotesAuxiliary undoManager];
    if (undoManager == nil) {
        if (presentationNotesAuxiliary == nil)
            presentationNotesAuxiliary = [[SKPresentationNotesAuxiliary alloc] init];
        undoManager = [[SKChainedUndoManager alloc] initWithNextUndoManager:[[self document] undoManager]];
        [presentationNotesAuxiliary setUndoManager:undoManager];
    }
    return undoManager;
}

- (NSMenu *)notesMenu {
    return [[rightSideController.noteOutlineView headerView] menu];
}

- (BOOL)hasNoteToolbar {
    return [noteToolbarController isVisible];
}

#pragma mark Overview

- (BOOL)hasOverview {
    return [overviewView window] != nil;
}

- (void)hideOverview:(id)sender {
    [self hideOverviewAnimating:YES];
}

- (void)updateOverviewItemSize {
    NSSize size;
    CGFloat width = 0.0;
    CGFloat height = 0.0;
    for (SKThumbnail *thumbnail in [self thumbnails]) {
        size = [thumbnail size];
        if (size.width < size.height) {
            height = 1.0;
            if (width >= 1.0)
                break;
            width = fmax(width, size.width / size.height);
        } else if (size.height < size.width) {
            width = 1.0;
            if (height >= 1.0)
                break;
            height = fmax(height, size.height / size.width);
        } else {
            width = height = 1.0;
            break;
        }
    }
    size = [SKThumbnailView sizeForImageSize:NSMakeSize(ceil(width * thumbnailSize), ceil(height * thumbnailSize))];
    NSCollectionViewFlowLayout *layout = [overviewView collectionViewLayout];
    if (NSEqualSizes(size, [layout itemSize]) == NO) {
        [layout setItemSize:size];
        [layout invalidateLayout];
    }
}

- (void)showOverviewAnimating:(BOOL)animate {
    if ([overviewView window])
        return;
    
    if (overviewView == nil) {
        overviewView  = [[SKOverviewView alloc] init];
        NSScrollView *scrollView = [[NSScrollView alloc] init];
        [scrollView setHasVerticalScroller:YES];
        [scrollView setAutohidesScrollers:YES];
        [scrollView setDocumentView:overviewView];
        [scrollView setDrawsBackground:NO];
        NSVisualEffectView *bgView = [[NSVisualEffectView alloc] init];
        [overviewView setSelectable:YES];
        [overviewView setAllowsMultipleSelection:YES];
        [overviewView setBackgroundColors:@[[NSColor clearColor]]];
        overviewContentView = scrollView;
        [overviewView setBackgroundView:bgView];
        NSCollectionViewFlowLayout *layout = [[NSCollectionViewFlowLayout alloc] init];
        [layout setMinimumLineSpacing:8.0];
        [layout setMinimumInteritemSpacing:0.0];
        [layout setSectionInset:NSEdgeInsetsMake(8.0, 8.0, 8.0, 8.0)];
        [overviewView setCollectionViewLayout:layout];
        [self updateOverviewItemSize];
        [overviewView registerClass:[SKThumbnailItem class] forItemWithIdentifier:@"thumbnail"];
        [overviewView setDataSource:self];
        [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:[[pdfView currentPage] pageIndex]]];
        [overviewView setTypeSelectHelper:[leftSideController.thumbnailTableView typeSelectHelper]];
        [overviewView setAction:@selector(hideOverview:)];
        [overviewView addObserver:self forKeyPath:@"selectionIndexPaths" options:0 context:&SKMainWindowThumbnailSelectionObservationContext];
        [overviewContentView setTranslatesAutoresizingMaskIntoConstraints:NO];
    }
    
    BOOL isPresentation = [self interactionMode] == SKPresentationMode;
    NSView *oldView = isPresentation ? presentationView : [splitViewController view];
    NSView *contentView = [oldView superview];
    NSUInteger pageIndex = [[pdfView currentPage] pageIndex];
    NSArray *constraints = @[
        [[overviewContentView leadingAnchor] constraintEqualToAnchor:[oldView leadingAnchor]],
        [[oldView trailingAnchor] constraintEqualToAnchor:[overviewContentView trailingAnchor]],
        [[overviewContentView topAnchor] constraintEqualToAnchor:[oldView topAnchor]],
        [[oldView bottomAnchor] constraintEqualToAnchor:[overviewContentView bottomAnchor]]];
    
    [overviewContentView setFrame:[oldView frame]];
    [overviewView scrollRectToVisible:[overviewView frameForItemAtIndex:pageIndex]];
    [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:pageIndex]];
    [overviewView setAllowsMultipleSelection:isPresentation == NO && [[self pdfDocument] allowsSaving]];
    
    if (@available(macOS 10.14, *)) {
        if (isPresentation) {
            [overviewContentView setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
            [(NSVisualEffectView *)[overviewView backgroundView] setMaterial:NSVisualEffectMaterialUnderPageBackground];
        } else {
            [overviewContentView setAppearance:nil];
            [(NSVisualEffectView *)[overviewView backgroundView] setMaterial:NSVisualEffectMaterialSidebar];
        }
    } else {
        [(NSVisualEffectView *)[overviewView backgroundView] setMaterial:isPresentation ? NSVisualEffectMaterialDark : NSVisualEffectMaterialSidebar];
        [[overviewView visibleItems] setValue:[NSNumber numberWithInteger:isPresentation ? NSBackgroundStyleEmphasized : NSBackgroundStyleNormal] forKey:@"backgroundStyle"];
    }
    [overviewView setSendActionOnSingleClick:isPresentation];
    
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
    
    if (isPresentation && mwcFlags.thumbnailsUpdatedDuringPresentaton == 0 && fabs([[self window] backingScaleFactor] - [savedNormalWindow backingScaleFactor]) > 0.0) {
        [self allThumbnailsNeedUpdate];
        mwcFlags.thumbnailsUpdatedDuringPresentaton = 1;
    }
    
    if (animate && [NSView shouldShowFadeAnimation]) {
        CAAnimation *animation = [CATransition animation];
        [animation setDuration:OVERVIEW_DURATION];
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
        [[contentView layer] addAnimation:animation forKey:@"animation"];
    }
    
    [contentView addSubview:overviewContentView];
    [oldView setHidden:YES];
    [NSLayoutConstraint activateConstraints:constraints];
    dispatch_async(dispatch_get_main_queue(), ^{ [overviewView scrollRectToVisible:[overviewView frameForItemAtIndex:[[pdfView currentPage] pageIndex]]]; });
    [[self window] makeFirstResponder:overviewView];
    [[self window] recalculateKeyViewLoop];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKMainWindowControllerDidShowOrHideOverviewNotification object:self];
}

- (void)hideOverviewAnimating:(BOOL)animate {
    NSWindow *window = [overviewContentView window];
    if (window == nil)
        return;
    
    if (animate && [NSView shouldShowFadeAnimation]) {
        CAAnimation *animation = [CATransition animation];
        [animation setDuration:OVERVIEW_DURATION];
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
        [[[overviewContentView superview] layer] addAnimation:animation forKey:@"animation"];
    }
    
    // don't check interactionMode as this can be called from enterPresentation/exitPresentation
    BOOL isPresentation = (window == [presentationView window]);
    
    [overviewContentView removeFromSuperview];
    [(isPresentation ? presentationView : [splitViewController view]) setHidden:NO];
    [window makeFirstResponder:isPresentation ? presentationView : pdfView];
    [window recalculateKeyViewLoop];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKMainWindowControllerDidShowOrHideOverviewNotification object:self];
}

- (void)hideOverviewWithCompletionHandler:(void (^)(void))completionHandler {
    if ([NSView shouldShowFadeAnimation]) {
        [CATransaction begin];
        [CATransaction setCompletionBlock:completionHandler];
        [self hideOverviewAnimating:YES];
        [CATransaction commit];
    } else {
        [self hideOverviewAnimating:NO];
        completionHandler();
    }
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return section == 0 ? [[self thumbnails] count] : 0;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    SKThumbnailItem *item = [collectionView makeItemWithIdentifier:@"thumbnail" forIndexPath:indexPath];
    NSUInteger i = [indexPath item];
    [item setRepresentedObject:[[self thumbnails] objectAtIndex:i]];
    [item setHighlightLevel:[self thumbnailHighlightLevelForRow:i]];
    if (markedPage.pageIndex == i)
        [item setMarked:YES];
    if (@available(macOS 10.14, *)) {} else if ([self interactionMode] == SKPresentationMode)
        [item setBackgroundStyle:NSBackgroundStyleEmphasized];
    return item;
}

#pragma mark Searching

- (BOOL)findString:(NSString *)string forward:(BOOL)forward {
    PDFDocument *pdfDoc = [pdfView document];
    if ([pdfDoc isFinding]) {
        NSBeep();
        return NO;
    }
    
    // this should never happen at this point
    if ([self hasOverview]) {
        [self hideOverviewWithCompletionHandler:^{
            [self findString:string forward:forward];
        }];
        return YES;
    }
    
    PDFSelection *sel = [pdfView currentSelection];
    NSUInteger pageIndex = [[pdfView currentPage] pageIndex];
    NSInteger options = 0;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKCaseInsensitiveFindKey])
        options |= NSCaseInsensitiveSearch;
    if (forward == NO)
        options |= NSBackwardsSearch;
    while ([sel hasCharacters] == NO && (forward ? pageIndex-- > 0 : ++pageIndex < [pdfDoc pageCount])) {
        PDFPage *page = [pdfDoc pageAtIndex:pageIndex];
        NSUInteger length = [[page string] length];
        if (length > 0)
            sel = [page selectionForRange:NSMakeRange(0, length)];
    }
    PDFSelection *selection = [pdfDoc findString:string fromSelection:sel withOptions:options];
    if ([selection hasCharacters] == NO && [sel hasCharacters])
        selection = [pdfDoc findString:string fromSelection:nil withOptions:options];
    PDFPage *page = [selection safeFirstPage];
    if (page) {
        NSRect rect = [selection safeBoundsForPage:page];
        rect = NSIntersectionRect(NSInsetRect(rect, -FIND_RESULT_MARGIN, -FIND_RESULT_MARGIN), [page boundsForBox:kPDFDisplayBoxCropBox]);
        [pdfView goToRect:rect onPage:page];
        [leftSideController.findTableView deselectAll:self];
        [leftSideController.groupedFindTableView deselectAll:self];
        [pdfView setCurrentSelection:selection animate:YES];
        return YES;
	} else {
		NSBeep();
        return NO;
	}
}

- (BOOL)removeFindController {
    if (mwcFlags.isAnimatingFindBar)
        return NO;
    
    BOOL animate = [NSView shouldShowSlideAnimation];
    NSView *findBar = [findController view];
    NSView *contentView = [findBar superview];
    NSLayoutConstraint *barTopConstraint = [findController topConstraint];
    CGFloat barHeight = [findController height];
    NSWindow *window = [self window];
    
    if ([window firstResponderIsDescendantOf:findBar])
        [window makeFirstResponder:pdfView];
    
    if (mwcFlags.fullSizeContent) {
        findBarTopConstraint = nil;
        [[pdfView embeddedScrollView] setAutomaticallyAdjustsContentInsets:YES];
        if ([pdfView autoScales] && ([pdfView extendedDisplayMode] & kPDFDisplaySinglePageContinuous) == 0) {
            [pdfView setAutoScales:NO];
            [pdfView setAutoScales:YES];
        }
    } else {
        findBarTopConstraint = [[[pdfSplitViewController view] topAnchor] constraintEqualToAnchor:[contentView topAnchor]];
    }
    
    if (animate) {
        mwcFlags.isAnimatingFindBar = YES;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [context setDuration:0.5 * [context duration]];
                [[barTopConstraint animator] setConstant:-barHeight];
            }
            completionHandler:^{
                [findBar removeFromSuperview];
                [findBarTopConstraint setActive:YES];
                [window recalculateKeyViewLoop];
                
                mwcFlags.isAnimatingFindBar = NO;
            }];
    } else {
        [findBar removeFromSuperview];
        [findBarTopConstraint setActive:YES];
        [contentView layoutSubtreeIfNeeded];
        [window recalculateKeyViewLoop];
    }
    
    return YES;
}

- (void)showFindBar {
    if (findController == nil) {
        findController = [[SKFindController alloc] init];
        [findController setDelegate:self];
        if ([[pdfView document] isFinding]) {
            [findController view];
            [[findController navigationButton] setEnabled:NO];
            [[findController findField] setEnabled:NO];
        }
    }
    
    NSView *findBar = [findController view];
    NSTextField *findField = [findController findField];
    
    if ([findBar window]) {
        [findField selectText:nil];
    } else if (mwcFlags.isAnimatingFindBar == 0) {
        
        BOOL animate = [NSView shouldShowSlideAnimation];
        CGFloat barHeight = [findController height];
        NSLayoutConstraint *barTopConstraint = [findController topConstraint];
        NSArray *constraints = nil;
        
        [barTopConstraint setConstant:animate ? -barHeight : 0.0];
        [centerContentView addSubview:findBar];
        constraints = @[
            [[findBar leadingAnchor] constraintEqualToAnchor:[centerContentView leadingAnchor]],
            [[centerContentView trailingAnchor] constraintEqualToAnchor:[findBar trailingAnchor]],
            [[findBar topAnchor] constraintEqualToAnchor:[centerContentView topAnchor] constant:titleBarHeight]];
        [NSLayoutConstraint activateConstraints:constraints];
        if (mwcFlags.fullSizeContent == NO) {
            [findBarTopConstraint setActive:NO];
            [[[[pdfSplitViewController view] topAnchor] constraintEqualToAnchor:[findBar bottomAnchor]] setActive:YES];
        }
        findBarTopConstraint = [constraints objectAtIndex:2];
        [centerContentView layoutSubtreeIfNeeded];
        
        [findController didAddFindBar];
        
        if (mwcFlags.fullSizeContent) {
            NSScrollView *scrollView = [pdfView embeddedScrollView];
            [scrollView setAutomaticallyAdjustsContentInsets:NO];
            [scrollView setContentInsets:NSEdgeInsetsMake(barHeight + titleBarHeight, 0.0, 0.0, 0.0)];
            if ([pdfView autoScales] && ([pdfView extendedDisplayMode] & kPDFDisplaySinglePageContinuous) == 0) {
                [pdfView setAutoScales:NO];
                [pdfView setAutoScales:YES];
            }
        }
        
        if (animate) {
            mwcFlags.isAnimatingFindBar = YES;
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                    [context setDuration:0.5 * [context duration]];
                    [[barTopConstraint animator] setConstant:0.0];
                }
                completionHandler:^{
                    [[self window] recalculateKeyViewLoop];
                    [findField selectText:nil];
                    
                    mwcFlags.isAnimatingFindBar = NO;
                }];
        } else {
            [centerContentView layoutSubtreeIfNeeded];
            [[self window] recalculateKeyViewLoop];
            [findField selectText:nil];
        }
    }
}

- (NSString *)searchString {
    return [leftSideController.searchField stringValue];
}

- (void)setSearchString:(NSString *)searchString {
    if ([searchString length] > 0) {
        if ([self hasOverview])
            [self hideOverviewAnimating:NO];
        [[[splitViewController splitViewItems] firstObject] setCollapsed:NO];
        [leftSideController.searchField setStringValue:searchString];
        [self performSelector:@selector(search:) withObject:leftSideController.searchField afterDelay:0.0];
    } else {
        [leftSideController.searchField setStringValue:@""];
        [self search:leftSideController.searchField];
    }
}

- (void)updateSearchResultHighlights {
    NSArray *findResults = nil;
    
    if (mwcFlags.findPaneState == SKFindPaneStateSingular && [leftSideController.findTableView window])
        findResults = [leftSideController.findArrayController selectedObjects];
    else if (mwcFlags.findPaneState == SKFindPaneStateGrouped && [leftSideController.groupedFindTableView window])
        findResults = [[leftSideController.groupedFindArrayController selectedObjects] valueForKeyPath:@"@unionOfArrays.matches"];
    
    if ([findResults count] == 0) {
        
        if (mwcFlags.highlightAllSearchResults == 0)
            [pdfView setHighlightedSelections:nil];
        [self updateRightStatus];
        
    } else {
        
        if (searchResultIndex >= (NSInteger)[findResults count])
            searchResultIndex = 0;
        else if (searchResultIndex < 0)
            searchResultIndex = [findResults count] - 1;
    
        PDFSelection *currentSel = [findResults objectAtIndex:searchResultIndex];
        PDFPage *page = [currentSel safeFirstPage];
        
        if (page) {
            if ([self interactionMode] == SKPresentationMode) {
                [presentationView setPage:page];
            } else {
                NSRect rect = NSZeroRect;
                for (PDFSelection *sel in findResults) {
                    if ([[sel pages] containsObject:page])
                        rect = NSUnionRect(rect, [sel safeBoundsForPage:page]);
                }
                rect = NSIntersectionRect(NSInsetRect(rect, -FIND_RESULT_MARGIN, -FIND_RESULT_MARGIN), [page boundsForBox:kPDFDisplayBoxCropBox]);
                [pdfView goAndScrollToPage:page];
                [pdfView goToRect:rect onPage:page];
            }
        }
        
        if (mwcFlags.highlightAllSearchResults == 0) {
            NSArray *highlights = [[NSArray alloc] initWithArray:findResults copyItems:YES];
            [highlights setValue:[NSColor findHighlightColor] forKey:@"color"];
            [pdfView setHighlightedSelections:highlights];
        }
        
        if ([currentSel hasCharacters]) {
            [pdfView setCurrentSelection:currentSel animate:YES];
            if ([pdfView toolMode] != SKToolModeText && [pdfView toolMode] != SKToolModeNote)
                [pdfView setCurrentSelection:nil];
            [[statusBar rightField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Match %lu of %lu", @"Status message"), (unsigned long)[searchResults indexOfObject:currentSel], (unsigned long)[searchResults count] - 1]];
        } else {
            [self updateRightStatus];
        }
    }
}

#pragma mark PDFDocument delegate

- (void)didMatchString:(PDFSelection *)instance {
    PDFPage *page = [instance safeFirstPage];
    // this should never happen, but apparently PDFKit sometimes does return empty matches
    if (page == nil)
        return;
    
    if (mwcFlags.wholeWordSearch) {
        NSString *string = [page string];
        NSUInteger i = [instance safeIndexOfFirstCharacterOnPage:page];
        if (i != NSNotFound && i > 0 && [[NSCharacterSet letterCharacterSet] characterIsMember:[string characterAtIndex:i - 1]])
            return;
        i = [instance safeIndexOfLastCharacterOnPage:page];
        if (i != NSNotFound && i + 1 < [string length] && [[NSCharacterSet letterCharacterSet] characterIsMember:[string characterAtIndex:i + 1]])
            return;
    }
    
    NSUInteger pageIndex = [page pageIndex];
    CGFloat order = [instance boundsOrderForPage:page];
    NSInteger i = [searchResults count];
    while (i-- > 1) {
        PDFSelection *prevResult = [searchResults objectAtIndex:i];
        PDFPage *prevPage = [prevResult safeFirstPage];
        NSUInteger prevIndex = [prevPage pageIndex];
        if (pageIndex > prevIndex || (pageIndex == prevIndex && order >= [prevResult boundsOrderForPage:prevPage]))
            break;
    }
    [searchResults insertObject:instance atIndex:i + 1];
    
    SKGroupedSearchResult *result = nil;
    NSUInteger maxCount = [groupedSearchResults count] > 1 ? [[groupedSearchResults lastObject] maxCount] : 0;
    i = [groupedSearchResults count];
    while (i-- > 1) {
        SKGroupedSearchResult *prevResult = [groupedSearchResults objectAtIndex:i];
        NSUInteger prevIndex = [prevResult pageIndex];
        if (pageIndex >= prevIndex) {
            if (pageIndex == prevIndex)
                result = prevResult;
            break;
        }
    }
    if (result == nil) {
        result = [[SKGroupedSearchResult alloc] initWithPage:page maxCount:maxCount];
        [groupedSearchResults insertObject:result atIndex:i + 1];
    }
    [result addMatch:instance];
    
    if ([result count] > maxCount)
        [groupedSearchResults setValue:[NSNumber numberWithUnsignedInteger:[result count]] forKey:@"maxCount"];
    
    if (mwcFlags.highlightAllSearchResults) {
        NSMutableArray *highlights = [NSMutableArray arrayWithArray:[pdfView highlightedSelections]];
        instance = [instance copy];
        [instance setColor:[NSColor findHighlightColor]];
        [highlights addObject:instance];
        [pdfView setHighlightedSelections:highlights];
    }
}

- (void)documentDidBeginDocumentFind:(NSNotification *)note {
    [[findController navigationButton] setEnabled:NO];
    [[findController findField] setEnabled:NO];
    NSArray *results = @[[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSLocalizedString(@"Searching", @"Message in search table header") stringByAppendingEllipsis], LABEL_KEY, @(NSNotFound), SKGroupedSearchResultCountKey, @-1, SKGroupedSearchResultPageIndexKey, nil]];
    [self setSearchResults:results];
    [self setGroupedSearchResults:results];
    if ([statusBar isVisible]) {
        [statusBar setProgressIndicatorStyle:SKProgressIndicatorStyleDeterminate];
        [[statusBar progressIndicator] setMaxValue:[[note object] pageCount]];
        [[statusBar progressIndicator] setDoubleValue:0.0];
        [[statusBar progressIndicator] startAnimation:self];
    }
    [self willChangeValueForKey:SEARCHRESULTS_KEY];
    [self willChangeValueForKey:GROUPEDSEARCHRESULTS_KEY];
}

- (void)documentDidEndDocumentFind:(NSNotification *)note {
    [[findController navigationButton] setEnabled:YES];
    [[findController findField] setEnabled:YES];
    NSString *header = nil;
    if ([searchResults count] == 2)
        header = NSLocalizedString(@"1 Result", @"Message in search table header");
    else
        header = [NSString stringWithFormat:NSLocalizedString(@"%ld Results", @"Message in search table header"), (long)[searchResults count] - 1];
    [[searchResults firstObject] setValue:header forKey:LABEL_KEY];
    mwcFlags.updatingFindResults = 1;
    [self didChangeValueForKey:GROUPEDSEARCHRESULTS_KEY];
    [self didChangeValueForKey:SEARCHRESULTS_KEY];
    mwcFlags.updatingFindResults = 0;
    if ([statusBar progressIndicatorStyle] == SKProgressIndicatorStyleDeterminate) {
        [[statusBar progressIndicator] stopAnimation:self];
        [statusBar setProgressIndicatorStyle:SKProgressIndicatorStyleNone];
    }
}

- (void)documentDidEndPageFind:(NSNotification *)note {
    NSUInteger pageIndex = [[[note userInfo] objectForKey:@"PDFDocumentPageIndex"] unsignedIntValue];
    
    if ([statusBar progressIndicatorStyle] == SKProgressIndicatorStyleDeterminate)
        [[statusBar progressIndicator] setDoubleValue:pageIndex + 1.0];
    if (pageIndex % 50 == 49) {
        NSString *key = mwcFlags.findPaneState == SKFindPaneStateSingular ? SEARCHRESULTS_KEY : GROUPEDSEARCHRESULTS_KEY;
        mwcFlags.updatingFindResults = 1;
        [self didChangeValueForKey:key];
        mwcFlags.updatingFindResults = 0;
        [self willChangeValueForKey:key];
    }
}

- (void)documentDidUnlockDelayed {
    NSDictionary *settings = [self interactionMode] == SKFullScreenMode ? [[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey] : nil;
    if ([settings count] == 0)
        settings = [savedNormalSetup objectForKey:DISPLAYMODE_KEY] ? savedNormalSetup : [[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultPDFDisplaySettingsKey];
    [pdfView setDisplaySettings:settings];
    
    NSArray *cropBoxes = [savedNormalSetup objectForKey:CROPBOXES_KEY];
    if ([cropBoxes count] && [cropBoxes count] == [[self pdfDocument] pageCount]) {
        [[self pdfDocument] setChangedCropBoxes:cropBoxes];
        mwcFlags.hasCropped = 1;
    }
    
    SKDestination dest = destinationFromSetup(savedNormalSetup);
    if (dest.pageIndex != NSNotFound) {
        [pdfView goToSKDestination:dest];
        [lastViewedPages setCount:0];
        [lastViewedPages addPointer:(void *)dest.pageIndex];
        [pdfView resetHistory];
    }
    
    NSArray *snapshotSetups = [savedNormalSetup objectForKey:SNAPSHOTS_KEY];
    if ([snapshotSetups count])
        [self showSnapshotsWithSetups:snapshotSetups];
    
    if ([self interactionMode] == SKNormalMode)
        [savedNormalSetup removeAllObjects];
    else
        [savedNormalSetup removeObjectsForKeys:@[LOCKED_KEY, SNAPSHOTS_KEY, CROPBOXES_KEY, PAGEINDEX_KEY, SCROLLPOINT_KEY]];
    
    // somehow the password field remains first responder after it has been removed
    if ([[[self window] firstResponder] isKindOfClass:[NSTextView class]] && [[(NSTextView *)[[self window] firstResponder] delegate] isKindOfClass:[NSSecureTextField class]] )
        [[self window] makeFirstResponder:[self pdfView]];
}

- (void)documentDidUnlock:(NSNotification *)notification {
    BOOL wasLocked = [[savedNormalSetup objectForKey:LOCKED_KEY] boolValue];
    PDFDocument *pdfDoc = [pdfView document];
    
    if (placeholderPdfDocument && [pdfDoc allowsNotes]) {
        NSMutableIndexSet *pageIndexes = wasLocked ? nil : [NSMutableIndexSet indexSet];
        for (PDFAnnotation *note in [self notes]) {
            PDFPage *page = [note page];
            if ([page document] != pdfDoc) {
                NSUInteger pageIndex = [page pageIndex];
                [page removeAnnotation:note];
                [[pdfDoc pageAtIndex:pageIndex] addAnnotation:note];
                [pageIndexes addIndex:pageIndex];
            }
        }
        placeholderPdfDocument = nil;
        [rightSideController.noteArrayController rearrangeObjects];
        if (wasLocked == NO) {
            [rightSideController.noteOutlineView reloadData];
            [self updateThumbnailsAtPageIndexes:pageIndexes];
        }
    }
    
    if (wasLocked) {
        if (placeholderWidgetProperties)
            [[[self document] undoManager] disableUndoRegistration];
        [self updateWidgetsWithProperties:placeholderWidgetProperties reset:NO];
        if (placeholderWidgetProperties)
            [[[self document] undoManager] enableUndoRegistration];
        placeholderWidgetProperties = nil;
    
        [self updatePageLabelsAndOutlineForExpansionState:nil];
        
        // when the PDF was locked, PDFView resets the display settings, so we need to reapply them, however if we don't delay it's reset again immediately
        [self performSelector:@selector(documentDidUnlockDelayed) withObject:nil afterDelay:0.0];
    }
}

- (void)document:(PDFDocument *)aDocument didUnlockWithPassword:(NSString *)password {
    [[self document] savePasswordInKeychain:password];
}

#pragma mark PDFDocument notifications

- (void)handlePageBoundsDidChangeNotification:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    PDFPage *page = [info objectForKey:SKPDFPagePageKey];
    BOOL isCrop = [[info objectForKey:SKPDFPageActionKey] isEqualToString:SKPDFPageActionCrop];
    BOOL displayChanged = isCrop == NO || [pdfView displayBox] == kPDFDisplayBoxCropBox;
        
    if (displayChanged)
        [pdfView layoutDocumentView];
    if (page) {
        NSUInteger idx = [page pageIndex];
        for (SKSnapshotWindowController *wc in snapshots) {
            if ([wc isPageVisible:page]) {
                [self snapshotNeedsUpdate:wc];
                [[wc pdfView] setNeedsDisplay:YES];
            }
        }
        if (displayChanged)
            [self updateThumbnailAtPageIndex:idx];
    } else {
        for (SKSnapshotWindowController *wc in snapshots)
            [[wc pdfView] setNeedsDisplay:YES];
        [self allSnapshotsNeedUpdate];
        if (displayChanged)
            [self allThumbnailsNeedUpdate];
    }
    
    [secondaryPdfView setNeedsDisplay:YES];
    
    if ([self interactionMode] == SKPresentationMode)
        [presentationView setNeedsDisplayForPage:page];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayPageBoundsKey])
        [self updateRightStatus];
    
    if (isCrop)
        mwcFlags.hasCropped = 1;
}

- (void)handleDocumentBeginWrite:(NSNotification *)notification {
    [self beginProgressSheetWithMessage:[NSLocalizedString(@"Exporting PDF", @"Message for progress sheet") stringByAppendingEllipsis] maxValue:[[pdfView document] pageCount]];
}

- (void)handleDocumentEndWrite:(NSNotification *)notification {
    [self dismissProgressSheet];
}

- (void)handleDocumentEndPageWrite:(NSNotification *)notification {
    [self incrementProgressSheet];
}

- (void)handleDidAddAnnotationNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    PDFAnnotation *annotation = [userInfo objectForKey:SKPDFDocumentAnnotationKey];
    PDFPage *page = [userInfo objectForKey:SKPDFDocumentPageKey];
    NSUndoManager *undoManager = [[self document] undoManager];
    
    if ([self interactionMode] == SKPresentationMode && [undoManager isUndoing] == NO && [undoManager isRedoing] == NO) {
        [[[self presentationUndoManager] prepareWithInvocationTarget:[notification object]] removeAnnotation:annotation];
        
        [annotation setShouldDisplay:YES];
        [annotation setShouldPrint:NO];
        [presentationNotesAuxiliary addNote:annotation];
        [self updateThumbnailAtPageIndex:[page pageIndex]];
        [presentationView setNeedsDisplayForPage:page];
    } else {
        if (mwcFlags.addOrRemoveNotesInBulk == 0) {
            [[undoManager prepareWithInvocationTarget:[notification object]] removeAnnotation:annotation];
            
            if ([annotation isSkimNote]) {
                [annotation setShouldDisplay:[pdfView hideNotes] == NO];
                [annotation setShouldPrint:[pdfView hideNotes] == NO];
                [self insertObject:annotation inNotesAtIndex:[notes count]];
                [rightSideController.noteOutlineView reloadData];
            }
            
            [self updateThumbnailAtPageIndex:[page pageIndex]];
            for (SKSnapshotWindowController *wc in snapshots) {
                if ([wc isPageVisible:page])
                    [self performSelectorOnce:@selector(snapshotNeedsUpdate:) withObject:wc afterDelay:0.0];
            }
        }
        
        [secondaryPdfView addedAnnotation:annotation onPage:page];
        if ([self interactionMode] == SKPresentationMode)
            [presentationView setNeedsDisplayForPage:page];
    }
}

- (void)handleDidRemoveAnnotationNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    PDFAnnotation *annotation = [userInfo objectForKey:SKPDFDocumentAnnotationKey];
    PDFPage *page = [userInfo objectForKey:SKPDFDocumentPageKey];
    NSUndoManager *undoManager = [[self document] undoManager];
    
    if ([self interactionMode] == SKPresentationMode && [undoManager isUndoing] == NO && [undoManager isRedoing] == NO) {
        if (mwcFlags.isSwitchingFullScreen == 0) {
            [[[self presentationUndoManager] prepareWithInvocationTarget:[notification object]] addAnnotation:annotation toPage:page];
            
            [presentationNotesAuxiliary removeNote:annotation];
            [self updateThumbnailAtPageIndex:[page pageIndex]];
            [presentationView setNeedsDisplayForPage:page];
        } else {
            [self updateThumbnailAtPageIndex:[page pageIndex]];
        }
    } else {
        if (mwcFlags.addOrRemoveNotesInBulk == 0) {
            [[undoManager prepareWithInvocationTarget:[notification object]] addAnnotation:annotation toPage:page];
            
            if ([annotation isSkimNote]) {
                if ([[self selectedNotes] containsObject:annotation])
                    [rightSideController.noteOutlineView deselectAll:self];
                
                NSUInteger i = [notes indexOfObject:annotation];
                if (i != NSNotFound)
                    [self removeObjectFromNotesAtIndex:i];
                [rightSideController.noteOutlineView reloadData];
            }
            
            [self updateThumbnailAtPageIndex:[page pageIndex]];
            for (SKSnapshotWindowController *wc in snapshots) {
                if ([wc isPageVisible:page])
                    [self performSelectorOnce:@selector(snapshotNeedsUpdate:) withObject:wc afterDelay:0.0];
            }
        }
        
        [secondaryPdfView removedAnnotation:annotation onPage:page];
        if ([self interactionMode] == SKPresentationMode)
            [presentationView setNeedsDisplayForPage:page];
    }
}

- (void)handleDidMoveAnnotationNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    PDFAnnotation *annotation = [userInfo objectForKey:SKPDFDocumentAnnotationKey];
    PDFPage *oldPage = [userInfo objectForKey:SKPDFDocumentOldPageKey];
    PDFPage *newPage = [userInfo objectForKey:SKPDFDocumentPageKey];
    
    [[[[self document] undoManager] prepareWithInvocationTarget:[notification object]] moveAnnotation:annotation toPage:oldPage];
    
    [self updateThumbnailAtPageIndex:[oldPage pageIndex]];
    [self updateThumbnailAtPageIndex:[newPage pageIndex]];
    for (SKSnapshotWindowController *wc in snapshots) {
        if ([wc isPageVisible:oldPage] || [wc isPageVisible:newPage])
            [self performSelectorOnce:@selector(snapshotNeedsUpdate:) withObject:wc afterDelay:0.0];
    }
    
    [secondaryPdfView removedAnnotation:annotation onPage:oldPage];
    [secondaryPdfView addedAnnotation:annotation onPage:newPage];
    if ([self interactionMode] == SKPresentationMode) {
        [presentationView setNeedsDisplayForPage:oldPage];
        [presentationView setNeedsDisplayForPage:newPage];
    }
    
    [rightSideController.noteArrayController rearrangeObjects];
    [rightSideController.noteOutlineView reloadData];
}

- (void)registerForDocumentNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    PDFDocument *pdfDoc = [pdfView document];
    [nc addObserver:self selector:@selector(handleDocumentBeginWrite:) 
                             name:PDFDocumentDidBeginWriteNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDocumentEndWrite:) 
                             name:PDFDocumentDidEndWriteNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDocumentEndPageWrite:) 
                             name:PDFDocumentDidEndPageWriteNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handlePageBoundsDidChangeNotification:) 
                             name:SKPDFPageBoundsDidChangeNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDidAddAnnotationNotification:)
                             name:SKPDFDocumentDidAddAnnotationNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDidRemoveAnnotationNotification:)
                             name:SKPDFDocumentDidRemoveAnnotationNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDidMoveAnnotationNotification:)
                             name:SKPDFDocumentDidMoveAnnotationNotification object:pdfDoc];
}

- (void)unregisterForDocumentNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    PDFDocument *pdfDoc = [pdfView document];
    [nc removeObserver:self name:PDFDocumentDidBeginWriteNotification object:pdfDoc];
    [nc removeObserver:self name:PDFDocumentDidEndWriteNotification object:pdfDoc];
    [nc removeObserver:self name:PDFDocumentDidEndPageWriteNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFPageBoundsDidChangeNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFDocumentDidAddAnnotationNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFDocumentDidRemoveAnnotationNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFDocumentDidMoveAnnotationNotification object:pdfDoc];
}

#pragma mark Subwindows

- (void)showSnapshotAtPage:(PDFPage *)page forRect:(NSRect)rect scaleFactor:(CGFloat)scaleFactor autoFits:(BOOL)autoFits {
    SKSnapshotWindowController *swc = [[SKSnapshotWindowController alloc] init];
    
    [swc setDelegate:self];
    
    [swc loadPdfDocument:[pdfView document]];
    [swc displayPage:page rect:rect scaleFactor:scaleFactor autoFits:autoFits];
    
    [swc setForceOnTop:[self interactionMode] == SKFullScreenMode];
    
    [[self document] addWindowController:swc];
}

- (void)showSnapshotsWithSetups:(NSArray *)setups {
    [setups enumerateObjectsUsingBlock:^(NSDictionary *setup, NSUInteger i, BOOL *stop){
        SKSnapshotWindowController *swc = [[SKSnapshotWindowController alloc] init];
        
        [swc setDelegate:self];
        
        [swc loadPdfDocument:[pdfView document]];
        [swc displaySetup:setup];

        [swc setForceOnTop:[self interactionMode] == SKFullScreenMode];
        
        [[self document] addWindowController:swc];
    }];
}

- (void)showSnapshotAtPage:(PDFPage *)page previewOnScreen:(nullable NSScreen *)screen {
    SKSnapshotWindowController *swc = [[SKSnapshotWindowController alloc] init];
    
    [presentationNotesAuxiliary setPreviewController:swc];
    
    [swc setDelegate:self];
    
    [swc loadPdfDocument:[pdfView document]];
    [swc previewPage:page displayOnScreen:screen];
    
    [[self document] addWindowController:swc];
}

- (void)snapshotController:(SKSnapshotWindowController *)controller didFinishSetup:(SKSnapshotOpenType)openType {
    if (openType == SKSnapshotOpenPreview)
        return;
    
    [self snapshotNeedsUpdate:controller lowPriority:openType == SKSnapshotOpenFromSetup];
    
    if (openType == SKSnapshotOpenFromSetup) {
        [self insertObject:controller inSnapshotsAtIndex:[snapshots count]];
        [rightSideController.snapshotTableView reloadData];
    } else {
        [rightSideController.snapshotTableView beginUpdates];
        [self insertObject:controller inSnapshotsAtIndex:[snapshots count]];
        NSUInteger row = [[rightSideController.snapshotArrayController arrangedObjects] indexOfObject:controller];
        if (row != NSNotFound) {
            NSTableViewAnimationOptions options = NSTableViewAnimationEffectNone;
            if ([self rightSidePaneIsOpen] && [self rightSidePaneState] == SKSidePaneStateSnapshot && [NSView shouldShowSlideAnimation])
                options = NSTableViewAnimationEffectGap | NSTableViewAnimationSlideDown;
            [rightSideController.snapshotTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:options];
        }
        [rightSideController.snapshotTableView endUpdates];
        [[self document] setRecentInfoNeedsUpdate:YES];
    }
}

- (void)snapshotControllerWillClose:(SKSnapshotWindowController *)controller {
    if (controller == [presentationNotesAuxiliary previewController]) {
        [presentationNotesAuxiliary setPreviewController:nil];
    } else {
        [rightSideController.snapshotTableView beginUpdates];
        NSUInteger row = [[rightSideController.snapshotArrayController arrangedObjects] indexOfObject:controller];
        if (row != NSNotFound) {
            NSTableViewAnimationOptions options = NSTableViewAnimationEffectGap | NSTableViewAnimationSlideUp;
            if ([self rightSidePaneIsOpen] == NO || [self rightSidePaneState] != SKSidePaneStateSnapshot || [NSView shouldShowSlideAnimation] == NO)
                options = NSTableViewAnimationEffectNone;
            [rightSideController.snapshotTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:options];
        }
        NSUInteger i = [snapshots indexOfObject:controller];
        if (i != NSNotFound)
            [self removeObjectFromSnapshotsAtIndex:i];
        [rightSideController.snapshotTableView endUpdates];
        [[self document] setRecentInfoNeedsUpdate:YES];
    }
}

- (void)snapshotControllerDidChange:(SKSnapshotWindowController *)controller {
    if (controller != [presentationNotesAuxiliary previewController]) {
        [self snapshotNeedsUpdate:controller];
        [rightSideController.snapshotArrayController rearrangeObjects];
        [rightSideController.snapshotTableView reloadData];
        [[self document] setRecentInfoNeedsUpdate:YES];
    }
}

- (void)snapshotControllerDidMove:(SKSnapshotWindowController *)controller {
    if (controller != [presentationNotesAuxiliary previewController]) {
        [[self document] setRecentInfoNeedsUpdate:YES];
    }
}

- (NSRect)snapshotController:(SKSnapshotWindowController *)controller miniaturizedRect:(BOOL)isMiniaturize {
    if (controller == [presentationNotesAuxiliary previewController])
        return NSZeroRect;
    NSRect rect = NSZeroRect;
    if ([self hasOverview]) {
        rect = [[self window] frame];
        rect.origin.x = NSMaxX(rect) - 1.0;
        rect.origin.y = floor(NSMidY(rect));
        rect.size.width = rect.size.height = 1.0;
    } else {
        NSUInteger row = [[rightSideController.snapshotArrayController arrangedObjects] indexOfObject:controller];
        NSSplitViewItem *item = nil;
        if (isMiniaturize && [self interactionMode] != SKPresentationMode) {
            item = [[splitViewController splitViewItems] lastObject];
            [self setRightSidePaneState:SKSidePaneStateSnapshot];
            if ([item isCollapsed]) {
                [item setCollapsed:NO];
                [[splitViewController splitView] layoutSubtreeIfNeeded];
            } else {
                item = nil;
            }
            if (row != NSNotFound)
                [rightSideController.snapshotTableView scrollRowToVisible:row];
        }
        if (row != NSNotFound) {
            rect = [rightSideController.snapshotTableView frameOfCellAtColumn:0 row:row];
        } else {
            rect.origin = SKBottomLeftPoint([rightSideController.snapshotTableView visibleRect]);
            rect.size.width = rect.size.height = 1.0;
        }
        rect = [[self window] convertRectToScreen:[rightSideController.snapshotTableView convertRect:rect toView:nil]];
        if (item) {
            if ([NSView shouldShowSlideAnimation]) {
                [item setCollapsed:YES];
                [[item animator] setCollapsed:NO];
                DISPATCH_MAIN_AFTER_SEC(1.25, ^{ [[item animator] setCollapsed:YES]; });
            } else {
                DISPATCH_MAIN_AFTER_SEC(1.5, ^{ [item setCollapsed:YES]; });
            }
        }
    }
    [[self document] setRecentInfoNeedsUpdate:YES];
    return rect;
}

- (void)snapshotController:(SKSnapshotWindowController *)controller goToDestination:(PDFDestination *)destination {
    [pdfView goToDestination:destination];
}

- (void)showNote:(PDFAnnotation *)annotation {
    NSWindowController *wc = [self windowControllerForNote:annotation];
    if (wc == nil) {
        wc = [[SKNoteWindowController alloc] initWithNote:annotation];
        [(SKNoteWindowController *)wc setForceOnTop:[self interactionMode] == SKFullScreenMode];
        [[self document] addWindowController:wc];
    }
    [wc showWindow:self];
}

- (NSWindowController *)windowControllerForNote:(PDFAnnotation *)annotation {
    for (id wc in [[self document] windowControllers]) {
        if ([wc isKindOfClass:[SKNoteWindowController class]] && [[wc note] isEqual:annotation])
            return wc;
    }
    return nil;
}

#pragma mark Observer registration

- (void)registerAsObserver {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    for (NSString *key in @[SKBackgroundColorKey, SKFullScreenBackgroundColorKey,
                            SKDarkBackgroundColorKey, SKDarkFullScreenBackgroundColorKey,
                            SKThumbnailSizeKey, SKSnapshotThumbnailSizeKey,
                            SKInterpolationQualityKey,
                            SKTableFontSizeKey])
        [sud addObserver:self forKeyPath:key options:0 context:&SKMainWindowDefaultsObservationContext];
    if (@available(macOS 10.14, *))
        [NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:&SKMainWindowAppObservationContext];
    if (mwcFlags.fullSizeContent)
        [[self window] addObserver:self forKeyPath:@"contentLayoutRect" options:0 context:&SKMainWindowContentLayoutObservationContext];
    [[[splitViewController splitViewItems] firstObject] addObserver:self forKeyPath:@"collapsed" options:NSKeyValueObservingOptionPrior context:&SKMainWindowSplitViewItemObservationContext];
    [[[splitViewController splitViewItems] lastObject] addObserver:self forKeyPath:@"collapsed" options:NSKeyValueObservingOptionPrior context:&SKMainWindowSplitViewItemObservationContext];
}

- (void)unregisterAsObserver {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    for (NSString *key in @[SKBackgroundColorKey, SKFullScreenBackgroundColorKey,
                            SKDarkBackgroundColorKey, SKDarkFullScreenBackgroundColorKey,
                            SKThumbnailSizeKey, SKSnapshotThumbnailSizeKey,
                            SKInterpolationQualityKey,
                            SKTableFontSizeKey]) {
        @try { [sud removeObserver:self forKeyPath:key context:&SKMainWindowDefaultsObservationContext]; }
        @catch (id e) {}
    }
    if (@available(macOS 10.14, *)) {
        @try { [NSApp removeObserver:self forKeyPath:@"effectiveAppearance" context:&SKMainWindowAppObservationContext]; }
        @catch (id e) {}
    }
    if (mwcFlags.fullSizeContent) {
        @try { [[self window] removeObserver:self forKeyPath:@"contentLayoutRect" context:&SKMainWindowContentLayoutObservationContext]; }
        @catch (id e) {}
    }
    if (overviewView) {
        @try { [overviewView removeObserver:self forKeyPath:@"selectionIndexPaths" context:&SKMainWindowThumbnailSelectionObservationContext]; }
        @catch (id e) {}
    }
    if ([presentationView transitionController]) {
        @try { [[presentationView transitionController] removeObserver:self forKeyPath:TRANSITION_KEY context:&SKMainWindowTransitionsObservationContext]; }
        @catch (id e) {}
        @try { [[presentationView transitionController] removeObserver:self forKeyPath:PAGETRANSITIONS_KEY context:&SKMainWindowTransitionsObservationContext]; }
        @catch (id e) {}
    }
    @try { [[[splitViewController splitViewItems] firstObject] removeObserver:self forKeyPath:@"collapsed" context:&SKMainWindowSplitViewItemObservationContext]; }
    @catch (id e) {}
    @try { [[[splitViewController splitViewItems] lastObject] removeObserver:self forKeyPath:@"collapsed" context:&SKMainWindowSplitViewItemObservationContext]; }
    @catch (id e) {}
}

#pragma mark Undo

- (void)startObservingNotes:(NSArray *)newNotes {
    // Each note can have a different set of properties that need to be observed.
    for (PDFAnnotation *note in newNotes) {
        for (NSString *key in [note keysForValuesToObserveForUndo]) {
            // We use NSKeyValueObservingOptionOld because when something changes we want to record the old value, which is what has to be set in the undo operation. We use NSKeyValueObservingOptionNew because we compare the new value against the old value in an attempt to ignore changes that aren't really changes.
            [note addObserver:self forKeyPath:key options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKPDFAnnotationPropertiesObservationContext];
        }
    }
}

- (void)stopObservingNotes:(NSArray *)oldNotes {
    // Do the opposite of what's done in -startObservingNotes:.
    for (PDFAnnotation *note in oldNotes) {
        for (NSString *key in [note keysForValuesToObserveForUndo])
            [note removeObserver:self forKeyPath:key context:&SKPDFAnnotationPropertiesObservationContext];
    }
}

- (void)setNoteProperties:(NSMapTable *)propertiesPerNote {
    // The passed-in dictionary is keyed by note...
    for (PDFAnnotation *note in propertiesPerNote) {
        // ...with values that are dictionaries of properties, keyed by key-value coding key.
        NSDictionary *noteProperties = [propertiesPerNote objectForKey:note];
        // Use a relatively unpopular method. Here we're effectively "casting" a key path to a key (see how these dictionaries get built in -observeValueForKeyPath:ofObject:change:context:). It had better really be a key or things will get confused. For example, this is one of the things that would need updating if -[SKTNote keysForValuesToObserveForUndo] someday becomes -[SKTNote keyPathsForValuesToObserveForUndo].
        [note setValuesForKeysWithDictionary:noteProperties];
    }
}

#pragma mark KVO

- (BOOL)notesNeedReloadForKey:(NSString *)key {
    if ([key isEqualToString:SKNPDFAnnotationBoundsKey] ||
        [key isEqualToString:[[[rightSideController.noteArrayController sortDescriptors] firstObject] key]])
        return YES;
    if ([[rightSideController.searchField stringValue] length])
        return [key isEqualToString:SKNPDFAnnotationStringKey] || [key isEqualToString:SKNPDFAnnotationTextKey];
    return NO;
}

- (void)reloadNotesTable {
    [rightSideController.noteArrayController rearrangeObjects];
    [rightSideController.noteOutlineView reloadData];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKMainWindowDefaultsObservationContext) {
        
        // A default value that we are observing has changed
        if ([keyPath isEqualToString:SKBackgroundColorKey] || [keyPath isEqualToString:SKDarkBackgroundColorKey]) {
            [self updateBackgroundColor];
        } else if ([keyPath isEqualToString:SKFullScreenBackgroundColorKey] || [keyPath isEqualToString:SKDarkFullScreenBackgroundColorKey]) {
            if ([self interactionMode] == SKFullScreenMode)
                [self updateBackgroundColor];
        } else if ([keyPath isEqualToString:SKThumbnailSizeKey]) {
            [self resetThumbnailSizeIfNeeded];
            [leftSideController.thumbnailTableView noteHeightOfRowsChanged];
        } else if ([keyPath isEqualToString:SKSnapshotThumbnailSizeKey]) {
            [self resetSnapshotSizeIfNeeded];
            [rightSideController.snapshotTableView noteHeightOfRowsChanged];
        } else if ([keyPath isEqualToString:SKInterpolationQualityKey]) {
            PDFInterpolationQuality interpolation = [[NSUserDefaults standardUserDefaults] integerForKey:SKInterpolationQualityKey];
            [pdfView setInterpolationQuality:interpolation];
            [secondaryPdfView setInterpolationQuality:interpolation];
            [pdfView setNeedsDisplay:YES];
            [secondaryPdfView setNeedsDisplay:YES];
            [self allThumbnailsNeedUpdate];
        } else if ([keyPath isEqualToString:SKTableFontSizeKey]) {
            if ([searchResults count] > 1)
                [[searchResults subarrayWithRange:NSMakeRange(1, [searchResults count] - 1)] makeObjectsPerformSelector:@selector(invalidateContextString)];
            [self updateTableFont];
            [self updatePageColumnWidthForTableViews:[NSArray arrayWithObjects:leftSideController.tocOutlineView, rightSideController.noteOutlineView, leftSideController.findTableView, leftSideController.groupedFindTableView, nil]];
        }
        
    } else if (context == &SKMainWindowAppObservationContext) {
        
        [self updateBackgroundColor];
        
    } else if (context == &SKMainWindowContentLayoutObservationContext) {
        
        CGFloat titleHeight = NSHeight([object frame]) - NSHeight([object contentLayoutRect]);
        if (fabs(titleHeight - titleBarHeight) > 0.0) {
            titleBarHeight = titleHeight;
            [rightSideController setTopInset:titleBarHeight];
            if ([sideWindow isVisible] == NO)
                [leftSideController setTopInset:titleBarHeight];
            if ([[findController view] window]) {
                [findBarTopConstraint setConstant:titleBarHeight];
                [[pdfView embeddedScrollView] setContentInsets:NSEdgeInsetsMake([findController height] + titleBarHeight, 0.0, 0.0, 0.0)];
            }
            [[[pdfSplitViewController splitViewItems] firstObject] setMinimumThickness:MIN_PDF_PANE_HEIGHT + titleBarHeight];
        }
        
    } else if (context == &SKMainWindowTransitionsObservationContext) {
        
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        if (oldValue == [NSNull null])
            oldValue = nil;
        
        if ([keyPath isEqualToString:TRANSITION_KEY])
            [[[self document] undoManager] registerUndoWithTarget:object selector:@selector(setTransition:) object:oldValue];
        else if ([keyPath isEqualToString:PAGETRANSITIONS_KEY])
            [[[self document] undoManager] registerUndoWithTarget:object selector:@selector(setPageTransitions:) object:oldValue];

    } else if (context == &SKMainWindowThumbnailSelectionObservationContext) {
        
        NSIndexSet *indexes = [overviewView selectionIndexes];
        if ([indexes count] == 1 && mwcFlags.updatingThumbnailSelection == 0) {
            NSUInteger pageIndex = [indexes firstIndex];
            if ([self interactionMode] == SKPresentationMode) {
                if ([[presentationView page] pageIndex] != pageIndex)
                    [presentationView setPage:[[pdfView document] pageAtIndex:pageIndex]];
            } else {
                if ([[pdfView currentPage] pageIndex] != pageIndex)
                    [pdfView goAndScrollToPage:[[pdfView document] pageAtIndex:pageIndex]];
            }
        } else if ([indexes count] == 0) {
            mwcFlags.updatingThumbnailSelection = 1;
            [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:[[pdfView currentPage] pageIndex]]];
            mwcFlags.updatingThumbnailSelection = 0;
        }
        
    } else if (context == &SKMainWindowSplitViewItemObservationContext) {
        
        NSSplitViewItem *item = object;
        if ([[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
            if ([item isCollapsed] == NO && [[self window] firstResponderIsDescendantOf:[[item viewController] view]])
                [[self window] makeFirstResponder:pdfView];
        } else if ([item viewController] == leftSideController) {
            [toolbarController leftSidePaneDidShowOrHide:[item isCollapsed] == NO];
        } else if ([item viewController] == rightSideController) {
            [toolbarController rightSidePaneDidShowOrHide:[item isCollapsed] == NO];
        }
        
    } else if (context == &SKPDFAnnotationPropertiesObservationContext) {

        // The value of some note's property has changed
        PDFAnnotation *note = (PDFAnnotation *)object;
        // Ignore changes that aren't really changes.
        // How much processor time does this memory optimization cost? We don't know, because we haven't measured it. The use of NSKeyValueObservingOptionNew in -startObservingNotes:, which makes NSKeyValueChangeNewKey entries appear in change dictionaries, definitely costs something when KVO notifications are sent (it costs virtually nothing at observer registration time). Regardless, it's probably a good idea to do simple memory optimizations like this as they're discovered and debug just enough to confirm that they're saving the expected memory (and not introducing bugs). Later on it will be easier to test for good responsiveness and sample to hunt down processor time problems than it will be to figure out where all the darn memory went when your app turns out to be notably RAM-hungry (and therefore slowing down _other_ apps on your user's computers too, if the problem is bad enough to cause paging).
        // Is this a premature optimization? No. Leaving out this very simple check, because we're worried about the processor time cost of using NSKeyValueChangeNewKey, would be a premature optimization.
        // We should be adding undo for nil values also. I'm not sure if KVO does this automatically. Note that -setValuesForKeysWithDictionary: converts NSNull back to nil.
        id newValue = [change objectForKey:NSKeyValueChangeNewKey] ?: [NSNull null];
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey] ?: [NSNull null];
        // All values are suppsed to be true value objects that should be compared with isEqual:
        if ([newValue isEqual:oldValue] == NO) {
            
            // Is this the first observed note change in the current undo group?
            NSUndoManager *undoManager = [[self document] undoManager];
            
            if ([undoManager isUndoRegistrationEnabled] == NO)
                return;
            
            if (undoGroupOldPropertiesPerNote == nil) {
                // We haven't recorded changes for any notes at all since the last undo manager checkpoint. Get ready to start collecting them. We don't want to copy the PDFAnnotations though.
                undoGroupOldPropertiesPerNote = [NSMapTable weakToStrongObjectsMapTable];
                // Register an undo operation for any note property changes that are going to be coalesced between now and the next invocation of -observeUndoManagerCheckpoint:.
                [undoManager registerUndoWithTarget:self selector:@selector(setNoteProperties:) object:undoGroupOldPropertiesPerNote];
                // Don't set the undo action name during undoing and redoing
                if ([undoManager isUndoing] == NO && [undoManager isRedoing] == NO)
                    [undoManager setActionName:NSLocalizedString(@"Edit Note", @"Undo action name")];
            }

            // Find the dictionary in which we're recording the old values of properties for the changed note
            NSMutableDictionary *oldNoteProperties = [undoGroupOldPropertiesPerNote objectForKey:note];
            if (oldNoteProperties == nil) {
                // We have to create a dictionary to hold old values for the changed note
                oldNoteProperties = [[NSMutableDictionary alloc] init];
                [undoGroupOldPropertiesPerNote setObject:oldNoteProperties forKey:note];
                // set the mod date here, need to do that only once for each note for a real user action
                if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableModificationDateKey] == NO && [undoManager isUndoing] == NO && [undoManager isRedoing] == NO && [keyPath isEqualToString:SKNPDFAnnotationModificationDateKey] == NO && [note isSkimNote])
                    [note setModificationDate:[NSDate date]];
            }
            
            // Record the old value for the changed property, unless an older value has already been recorded for the current undo group. Here we're "casting" a KVC key path to a dictionary key, but that should be OK. -[NSMutableDictionary setObject:forKey:] doesn't know the difference.
            if ([oldNoteProperties objectForKey:keyPath] == nil)
                [oldNoteProperties setObject:oldValue forKey:keyPath];
            
            static NSSet *invisibleKeys = nil;
            if (invisibleKeys == nil)
                invisibleKeys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, SKNPDFAnnotationTextKey, nil];
            
            // Update the UI, we should always do that unless the value did not really change or we're just changing the mod date or user name
            if ([invisibleKeys containsObject:keyPath] == NO && ([note isText] || [keyPath isEqualToString:SKNPDFAnnotationStringKey] == NO) && ([note isNote] == NO || [(SKNPDFAnnotationNote *)note drawsImage] || [keyPath isEqualToString:SKNPDFAnnotationImageKey] == NO)) {
                PDFPage *page = [note page];
                
                [self updateThumbnailAtPageIndex:[note pageIndex]];
                
                for (SKSnapshotWindowController *wc in snapshots) {
                    if ([wc isPageVisible:page]) {
                        [self performSelectorOnce:@selector(snapshotNeedsUpdate:) withObject:wc afterDelay:0.0];
                        [[wc pdfView] updatedAnnotation:note];
                    }
                }
                
                [pdfView updatedAnnotation:note forKey:keyPath fromValue:oldValue];
                [secondaryPdfView updatedAnnotation:note];
                
                if ([self interactionMode] == SKPresentationMode)
                    [presentationView setNeedsDisplayForPage:page];

                if ([keyPath isEqualToString:SKNPDFAnnotationBoundsKey] && note == [pdfView currentAnnotation] && [[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayNoteBoundsKey])
                    [self updateRightStatus];
            }
            
            if ([note isSkimNote] == NO)
                return;
            
            if ([keyPath isEqualToString:SKNPDFAnnotationStringKey] && ([note isText] || [note isMarkup])) {
                PDFAnnotation *popup = [note popup];
                if (popup) {
                    [[note page] removeAnnotation:popup];
                    [note setPopup:nil];
                }
            }
            
            if (mwcFlags.autoResizeNoteRows) {
                if ([keyPath isEqualToString:SKNPDFAnnotationStringKey])
                    [rightSideController.noteOutlineView setRowHeight:0.0 forItem:note];
                else if ([keyPath isEqualToString:SKNPDFAnnotationTextKey])
                    [rightSideController.noteOutlineView setRowHeight:0.0 forItem:[note noteText]];
            }
            if ([self notesNeedReloadForKey:keyPath]) {
                [self performSelectorOnce:@selector(reloadNotesTable) afterDelay:0.0];
            } else if ([keyPath isEqualToString:SKNPDFAnnotationStringKey] ||
                       [keyPath isEqualToString:SKNPDFAnnotationTextKey]) {
                [rightSideController.noteOutlineView reloadTypeSelectStrings];
                if (mwcFlags.autoResizeNoteRows) {
                    NSInteger row = [rightSideController.noteOutlineView rowForItem:[keyPath isEqualToString:SKNPDFAnnotationStringKey] ? note : [note noteText]];
                    if (row != -1)
                        [rightSideController.noteOutlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:row]];
                }
            }
            
            // update the various panels if necessary
            if ([[self window] isMainWindow] && [note isEqual:[pdfView currentAnnotation]]) {
                if (mwcFlags.updatingColor == 0) {
                    NSColor *color = nil;
                    if ([keyPath isEqualToString:SKNPDFAnnotationColorKey] && ([note hasInteriorColor] == NO || [colorAccessoryView state] == NSControlStateValueOff) && ([note isText] == NO || [textColorAccessoryView state] == NSControlStateValueOff))
                        color = [note color] ?: [NSColor clearColor];
                    else if ([keyPath isEqualToString:SKNPDFAnnotationInteriorColorKey] && [colorAccessoryView state] == NSControlStateValueOn)
                        color = [note interiorColor] ?: [NSColor clearColor];
                    else if ([keyPath isEqualToString:SKNPDFAnnotationFontColorKey] && [textColorAccessoryView state] == NSControlStateValueOn)
                        color = [note fontColor] ?: [NSColor blackColor];
                    if (color) {
                        mwcFlags.updatingColor = 1;
                        [[NSColorPanel sharedColorPanel] setColor:color];
                        mwcFlags.updatingColor = 0;
                    }
                }
                if (mwcFlags.updatingFont == 0 && ([keyPath isEqualToString:SKNPDFAnnotationFontKey])) {
                    mwcFlags.updatingFont = 1;
                    [[NSFontManager sharedFontManager] setSelectedFont:[note font] isMultiple:NO];
                    mwcFlags.updatingFont = 0;
                }
                if (mwcFlags.updatingFontAttributes == 0 && ([keyPath isEqualToString:SKNPDFAnnotationFontColorKey])) {
                    mwcFlags.updatingFontAttributes = 1;
                    [[NSFontManager sharedFontManager] setSelectedAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[note fontColor], NSForegroundColorAttributeName, nil] isMultiple:NO];
                    mwcFlags.updatingFontAttributes = 0;
                }
                if (mwcFlags.updatingLine == 0 && ([keyPath isEqualToString:SKNPDFAnnotationBorderKey] || [keyPath isEqualToString:SKNPDFAnnotationStartLineStyleKey] || [keyPath isEqualToString:SKNPDFAnnotationEndLineStyleKey])) {
                    mwcFlags.updatingLine = 1;
                    [[SKLineInspector sharedLineInspector] setAnnotationStyle:note];
                    mwcFlags.updatingLine = 0;
                }
            }
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Outline

- (BOOL)isOutlineExpanded:(PDFOutline *)outline {
    if (-1 == [leftSideController.tocOutlineView rowForItem:outline])
        return NO;
    return [leftSideController.tocOutlineView isItemExpanded:outline];
}

- (void)setExpanded:(BOOL)flag forOutline:(PDFOutline *)outline {
    if ([self isOutlineExpanded:outline] == flag)
        return;
    if (flag) {
        PDFOutline *parent = [outline parent];
        if ([parent parent])
            [self setExpanded:YES forOutline:parent];
        [leftSideController.tocOutlineView expandItem:outline];
    } else {
        [leftSideController.tocOutlineView collapseItem:outline];
    }
}

#pragma mark Thumbnails

+ (dispatch_queue_t)thumbnailQueue {
    static dispatch_queue_t thumbnailQueue = nil;
    if (thumbnailQueue == nil) {
        dispatch_queue_attr_t queuePriority = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_DEFAULT, 0);
        thumbnailQueue = dispatch_queue_create("net.sourceforge.skim-app.skim.thumbnails.default", queuePriority);
    }
    return thumbnailQueue;
}

+ (dispatch_queue_t)utilityThumbnailQueue {
    static dispatch_queue_t thumbnailQueue = nil;
    if (thumbnailQueue == nil) {
        dispatch_queue_attr_t queuePriority = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0);
        thumbnailQueue = dispatch_queue_create("net.sourceforge.skim-app.skim.thumbnails.utility", queuePriority);
    }
    return thumbnailQueue;
}

+ (dispatch_queue_t)backgroundThumbnailQueue {
    static dispatch_queue_t thumbnailQueue = nil;
    if (thumbnailQueue == nil) {
        dispatch_queue_attr_t queuePriority = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_BACKGROUND, 0);
        thumbnailQueue = dispatch_queue_create("net.sourceforge.skim-app.skim.thumbnails.background", queuePriority);
    }
    return thumbnailQueue;
}

- (PDFPage *)pageForThumbnail:(SKThumbnail *)thumbnail {
    return [[pdfView document] pageAtIndex:[thumbnail pageIndex]];
}

- (BOOL)generateImageForThumbnail:(SKThumbnail *)thumbnail {
    if ([[pdfView document] isLocked])
        return NO;
    
    PDFPage *page = [self pageForThumbnail:thumbnail];
    NSArray *highlights = page && [[[pdfView readingBar] page] isEqual:page] ? @[[pdfView readingBar]] : nil;
    PDFDisplayBox box = [pdfView displayBox];
    CGFloat scale = [[self window] backingScaleFactor];
    dispatch_queue_t queue = [thumbnail isPlaceholder] ? [[self class] thumbnailQueue] : [[self class] utilityThumbnailQueue];
    
    if ([self interactionMode] == SKPresentationMode && mwcFlags.thumbnailsNeedUpdateAfterPresentaton == 0 && fabs([savedNormalWindow backingScaleFactor] - scale) > 0.0)
        mwcFlags.thumbnailsNeedUpdateAfterPresentaton = 1;
    
    dispatch_async(queue, ^{
        NSImage *image = [page thumbnailWithSize:thumbnailCacheSize scale:scale forBox:box hasShadow:YES highlights:highlights];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameSize = NSEqualSizes([image size], [thumbnail size]);
            
            [thumbnail setImage:image];
            
            if (sameSize == NO) {
                [leftSideController.thumbnailTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:[thumbnail pageIndex]]];
                [self updateOverviewItemSize];
            }
        });
    });
    
    return YES;
}

- (NSImage *)placeholderThumbnailImage {
    PDFPage *page = [[pdfView document] pageAtIndex:0];
    NSSize size = [page boundsForBox:[pdfView displayBox]].size;
    if (([page rotation] % 180) == 90)
        size = NSMakeSize(size.height, size.width);
    NSArray *stamps = nil;
    
    page = [[PDFPage alloc] init];
    [page setBounds:(NSRect){NSZeroPoint, size} forBox:kPDFDisplayBoxMediaBox];
    
    if ([[pdfView document] isLocked]) {
        CGFloat width = ceil(0.8 * fmin(size.width, size.height));
        NSRect rect = NSMakeRect(0.5 * (size.width - width), 0.5 * (size.height - width), width, width);
        NSString *type = [[self document] fileType];
        if ([type isEqualToString:SKDocumentTypePostScript])
            type = @"PS";
        else if ([type isEqualToString:SKDocumentTypeEncapsulatedPostScript])
            type = @"EPS";
        else if ([type isEqualToString:SKDocumentTypeDVI])
            type = @"DVI";
        else if ([type isEqualToString:SKDocumentTypeXDV])
            type = @"XDV";
        else
            type = @"PDF";

        stamps = @[[[SKThumbnailStamp alloc] initWithImage:[NSImage stampForType:type] rect:rect fraction:1.0],
            [[SKThumbnailStamp alloc] initWithImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kLockedBadgeIcon)] rect:rect fraction:0.5]];
    }
    
    return [page thumbnailWithSize:thumbnailCacheSize scale:[[self window] backingScaleFactor] forBox:kPDFDisplayBoxMediaBox hasShadow:YES highlights:stamps];
}

- (void)resetThumbnails {
    NSMutableArray *newThumbnails = [NSMutableArray array];
    if ([pageLabels count] > 0) {
        NSImage *pageImage = [self placeholderThumbnailImage];
        [pageLabels enumerateObjectsUsingBlock:^(NSString *label, NSUInteger i, BOOL *stop) {
            [newThumbnails addObject:[[SKThumbnail alloc] initWithImage:pageImage label:label pageIndex:i]];
        }];
        if ([[pdfView document] isLocked])
            [newThumbnails setValue:@NO forKey:@"needsUpdate"];
    }
    // reloadData resets the selection, so we have to ignore its notification and reset it
    mwcFlags.updatingThumbnailSelection = 1;
    [self setThumbnails:newThumbnails];
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[[pdfView currentPage] pageIndex]];
    [leftSideController.thumbnailTableView selectRowIndexes:indexes byExtendingSelection:NO];
    [leftSideController.thumbnailTableView scrollRowToVisible:[indexes firstIndex]];
    if (overviewView) {
        [overviewView reloadData];
        [overviewView setSelectionIndexes:indexes];
        [self updateOverviewItemSize];
    }
    mwcFlags.updatingThumbnailSelection = 0;
}

- (void)resetThumbnailSizeIfNeeded {
    thumbnailSize = round([[NSUserDefaults standardUserDefaults] floatForKey:SKThumbnailSizeKey]);

    CGFloat cacheSize = CACHE_SIZE_FOR_SIZE(thumbnailSize);
    
    if (fabs(cacheSize - thumbnailCacheSize) > FUDGE_SIZE) {
        thumbnailCacheSize = cacheSize;
        
        if ([[self thumbnails] count])
            [self allThumbnailsNeedUpdate];
    }
    
    if (overviewView)
        [self updateOverviewItemSize];
}

- (void)updateThumbnailAtPageIndex:(NSUInteger)anIndex {
    [[thumbnails objectAtIndex:anIndex] setNeedsUpdate:YES];
}

- (void)updateThumbnailsAtPageIndexes:(NSIndexSet *)indexSet {
    [[thumbnails objectsAtIndexes:indexSet] setValue:@YES forKey:@"needsUpdate"];
}

- (void)allThumbnailsNeedUpdate {
    [thumbnails setValue:@YES forKey:@"needsUpdate"];
}

#pragma mark Notes

- (void)updateNoteFilterPredicate {
    [rightSideController.noteArrayController setFilterPredicate:[noteTypeSheetController filterPredicateForSearchString:[rightSideController.searchField stringValue] caseInsensitive:mwcFlags.caseInsensitiveFilter]];
    [rightSideController.noteOutlineView reloadData];
}

#pragma mark Snapshots

- (void)resetSnapshotSizeIfNeeded {
    snapshotThumbnailSize = round([[NSUserDefaults standardUserDefaults] floatForKey:SKSnapshotThumbnailSizeKey]);
    CGFloat snapshotSize = CACHE_SIZE_FOR_SIZE(snapshotThumbnailSize);
    
    if (fabs(snapshotSize - snapshotCacheSize) > FUDGE_SIZE) {
        snapshotCacheSize = snapshotSize;
        
        if ([[self snapshots] count])
            [self allSnapshotsNeedUpdate];
    }
}

- (void)snapshotNeedsUpdate:(SKSnapshotWindowController *)controller lowPriority:(BOOL)lowPriority {
    CGFloat backingScale = [[self window] backingScaleFactor];
    SKSnapshotConfiguration *configuration = [controller currentConfiguration];
    NSDate *date = [NSDate date];
    dispatch_queue_t queue;
    
    if ([controller thumbnail] == nil)
        [controller setThumbnail:[configuration placeholderThumbnailWithSize:snapshotCacheSize scale:backingScale]];
    
    if ([rightSideController.snapshotTableView window] == nil || [self rightSidePaneIsOpen] == NO)
        queue = [[self class] backgroundThumbnailQueue];
    else if (lowPriority)
        queue = [[self class] thumbnailQueue];
    else
        queue = [[self class] utilityThumbnailQueue];
    
    dispatch_async(queue, ^{
        
        NSImage *image = [configuration thumbnailWithSize:snapshotCacheSize scale:backingScale];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // ignore this thumbnail when a later update was set earlier, e.g. from a higher priority
            if ([[controller updateDate] compare:date] == NSOrderedDescending)
                return;
            
            NSSize newSize = [image size];
            NSSize oldSize = [[controller thumbnail] size];
            
            [controller setThumbnail:image];
            [controller setUpdateDate:date];
            
            if (fabs(newSize.width - oldSize.width) > 1.0 || fabs(newSize.height - oldSize.height) > 1.0) {
                NSUInteger idx = [[rightSideController.snapshotArrayController arrangedObjects] indexOfObject:controller];
                if (idx != NSNotFound)
                    [rightSideController.snapshotTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:idx]];
            }
        });
    });
}

- (void)snapshotNeedsUpdate:(SKSnapshotWindowController *)controller {
    [self snapshotNeedsUpdate:controller lowPriority:NO];
}

- (void)allSnapshotsNeedUpdate {
    for (SKSnapshotWindowController *controller in [self snapshots])
        [self snapshotNeedsUpdate:controller];
    
}

- (void)updateSnapshotFilterPredicate {
    NSString *searchString = [rightSideController.searchField stringValue];
    NSPredicate *filterPredicate = nil;
    if (mwcFlags.rightSidePaneState == SKSidePaneStateSnapshot && [searchString length] > 0) {
        NSExpression *lhs = [NSExpression expressionForConstantValue:searchString];
        NSExpression *rhs = [NSExpression expressionForKeyPath:@"string"];
        NSUInteger options = NSDiacriticInsensitivePredicateOption;
        if (mwcFlags.caseInsensitiveFilter)
            options |= NSCaseInsensitivePredicateOption;
        filterPredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs modifier:NSDirectPredicateModifier type:NSInPredicateOperatorType options:options];
    }
    [rightSideController.snapshotArrayController setFilterPredicate:filterPredicate];
    [rightSideController.snapshotArrayController rearrangeObjects];
    [rightSideController.snapshotTableView reloadData];
}

#pragma mark Progress sheet

- (void)beginProgressSheetWithMessage:(NSString *)message maxValue:(NSUInteger)maxValue {
    if (progressController == nil)
        progressController = [[SKProgressController alloc] init];
    
    [progressController setMessage:message];
    if (maxValue > 0) {
        [progressController setIndeterminate:NO];
        [progressController setMaxValue:(double)maxValue];
    } else {
        [progressController setIndeterminate:YES];
    }
    [progressController beginSheetModalForWindow:[self window] completionHandler:NULL];
}

- (void)incrementProgressSheet {
    [progressController incrementBy:1.0];
}

- (void)dismissProgressSheet {
    [progressController dismissSheet:nil];
    progressController = nil;
}

#pragma mark Remote Control

- (void)remoteButtonPressed:(NSEvent *)theEvent {
    HIDRemoteButtonCode remoteButton = (HIDRemoteButtonCode)[theEvent data1];
    BOOL remoteScrolling = (BOOL)[theEvent data2];
    
    switch (remoteButton) {
        case kHIDRemoteButtonCodeUp:
            if ([self interactionMode] == SKPresentationMode)
                [self doAutoScale:nil];
            else if (remoteScrolling)
                [self doScrollUp:nil];
            else
                [self doZoomIn:nil];
            break;
        case kHIDRemoteButtonCodeDown:
            if ([self interactionMode] == SKPresentationMode)
                [self doZoomToActualSize:nil];
            else if (remoteScrolling)
                [self doScrollDown:nil];
            else
                [self doZoomOut:nil];
            break;
        case kHIDRemoteButtonCodeRightHold:
        case kHIDRemoteButtonCodeRight:
            if (remoteScrolling && [self interactionMode] != SKPresentationMode)
                [self doScrollRight:nil];
            else 
                [self doGoToNextPage:nil];
            break;
        case kHIDRemoteButtonCodeLeftHold:
        case kHIDRemoteButtonCodeLeft:
            if (remoteScrolling && [self interactionMode] != SKPresentationMode)
                [self doScrollLeft:nil];
            else 
                [self doGoToPreviousPage:nil];
            break;
        case kHIDRemoteButtonCodeCenter:        
            [self togglePresentation:nil];
            break;
        default:
            break;
    }
}

#pragma mark Touch bar

- (NSTouchBar *)makeTouchBar {
    if (touchBarController == nil) {
        touchBarController = [[SKMainTouchBarController alloc] init];
        [touchBarController setMainController:self];
    }
    return [touchBarController makeTouchBar];
}

@end


static SKDestination destinationFromSetup(NSDictionary *setup) {
    SKDestination dest = {NSNotFound, SKUnspecifiedPoint};
    NSNumber *pageNumber = [setup objectForKey:PAGEINDEX_KEY];
    if (pageNumber) {
        dest.pageIndex = [pageNumber unsignedIntegerValue];
        if (dest.pageIndex != NSNotFound) {
            NSString *pointString = [setup objectForKey:SCROLLPOINT_KEY];
            if (pointString)
                dest.point = NSPointFromString(pointString);
        }
    }
    return dest;
}

static void setDestinationInSetup(SKDestination dest, NSMutableDictionary *setup) {
    if (dest.pageIndex != NSNotFound) {
        [setup setObject:[NSNumber numberWithUnsignedInteger:dest.pageIndex] forKey:PAGEINDEX_KEY];
        if (NSEqualPoints(dest.point, SKUnspecifiedPoint) == NO)
            [setup setObject:NSStringFromPoint(dest.point) forKey:SCROLLPOINT_KEY];
        else
            [setup removeObjectForKey:SCROLLPOINT_KEY];
    }
}

static NSArray *mergedSnapshotSetups(NSArray *setups1, NSArray *setups2) {
    if ([setups1 count] == 0)
        return [setups2 count] ? setups2 : nil;
    else if ([setups2 count] == 0)
        return setups1;
    NSArray *keys = @[@"page", @"rect"];
    NSMutableSet *set = [NSMutableSet set];
    NSMutableArray *setups = [NSMutableArray arrayWithArray:setups1];
    for (NSDictionary *setup in setups1)
        [set addObject:[setup dictionaryWithValuesForKeys:keys]];
    for (NSDictionary *setup in setups2) {
        if ([set containsObject:[setup dictionaryWithValuesForKeys:keys]] == NO)
            [setups addObject:setup];
    }
    return setups;
}
