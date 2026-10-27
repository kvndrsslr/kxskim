//
//  SKMainWindowController_UI.m
//  Skim
//
//  Created by Christiaan Hofman on 5/2/08.
/*
 This software is Copyright (c) 2008
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

#import "SKMainWindowController_UI.h"
#import "SKMainWindowController_FullScreen.h"
#import "SKMainWindowController_Actions.h"
#import "SKLeftSideViewController.h"
#import "SKRightSideViewController.h"
#import "SKMainToolbarController.h"
#import "SKPDFView.h"
#import "SKStatusBar.h"
#import "SKSnapshotWindowController.h"
#import "SKNoteWindowController.h"
#import "SKNoteTextView.h"
#import "NSWindowController_SKExtensions.h"
#import "SKSideWindow.h"
#import "SKAnnotationTypeImageView.h"
#import "SKStringConstants.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKNoteText.h"
#import "SKImageToolTipWindow.h"
#import "SKMainDocument.h"
#import "PDFPage_SKExtensions.h"
#import "SKGroupedSearchResult.h"
#import "PDFSelection_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "SKLineInspector.h"
#import "SKFieldEditor.h"
#import "PDFOutline_SKExtensions.h"
#import "SKDocumentController.h"
#import "SKFindController.h"
#import "NSColor_SKExtensions.h"
#import "SKScrollView.h"
#import "SKDocumentController.h"
#import "NSError_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSURL_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import "NSArray_SKExtensions.h"
#import "SKNoteTableRowView.h"
#import "SKHighlightingTableRowView.h"
#import "SKSecondaryPDFView.h"
#import "SKControlTableCellView.h"
#import "SKThumbnailItem.h"
#import "SKOverviewView.h"
#import "NSView_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSObject_SKExtensions.h"
#import "NSPasteboard_SKExtensions.h"
#import "SKPresentationView.h"
#import "SKBookmarkController.h"
#import "SKNoteToolbarController.h"
#import "SKPresentationNotesAuxiliary.h"

#define NOTES_KEY       @"notes"
#define SNAPSHOTS_KEY   @"snapshots"

#define PAGE_COLUMNID       @"page"
#define LABEL_COLUMNID      @"label"
#define NOTE_COLUMNID       @"note"
#define TYPE_COLUMNID       @"type"
#define COLOR_COLUMNID      @"color"
#define AUTHOR_COLUMNID     @"author"
#define DATE_COLUMNID       @"date"
#define IMAGE_COLUMNID      @"image"
#define RESULTS_COLUMNID    @"results"
#define RELEVANCE_COLUMNID  @"relevance"

#define HEADER_IDENTIFIER @"header"

#define SNAPSHOT_HEIGHT 200.0

#define EXTRA_ROW_HEIGHT 2.0
#define DEFAULT_TEXT_ROW_HEIGHT 85.0
#define DEFAULT_MARKUP_ROW_HEIGHT 50.0

#define EXTRA_FIND_ROW_HEIGHT 8.0
#define FIND_HEADER_ROW_HEIGHT 16.0
#define MAX_FIND_LINES 5

@interface SKMainWindowController (SKPrivateMain)

- (void)cleanup;

- (void)updatePageLabels;
- (void)updatePageLabel;

- (void)updateNoteFilterPredicate;

- (void)rotatePageAtIndex:(NSUInteger)idx by:(NSInteger)rotation;

@end

@interface SKMainWindowController (UIPrivate)
- (void)handleNoteViewFrameDidChangeNotification:(NSNotification *)notification;
- (void)handleNoteViewDidEndLiveResizeNotification:(NSNotification *)notification;
@end

#pragma mark -

@implementation SKMainWindowController (UI)

#pragma mark Utility panel updating

- (void)updateColorPanel:(id)sender{
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    NSColor *color = nil;
    
    if ([annotation hasInteriorColor] && [colorAccessoryView state] == NSControlStateValueOn)
        color = [(id)annotation interiorColor] ?: [NSColor clearColor];
    else if ([annotation isText] && [textColorAccessoryView state] == NSControlStateValueOn)
        color = [(id)annotation fontColor] ?: [NSColor blackColor];
    else
        color = [annotation color];
    
    if (color) {
        mwcFlags.updatingColor = 1;
        [[NSColorPanel sharedColorPanel] setColor:color];
        mwcFlags.updatingColor = 0;
    }
}

- (NSButton *)newColorAccessoryButtonWithTitle:(NSString *)title {
    NSButton *button = [[NSButton alloc] init];
    [button setButtonType:NSSwitchButton];
    [button setTitle:title];
    [[button cell] setControlSize:NSControlSizeSmall];
    [button setTarget:self];
    [button setAction:@selector(updateColorPanel:)];
    [button sizeToFit];
    return button;
}

- (void)updateUtilityPanels {
    if ([[self window] isMainWindow]) {
        PDFAnnotation *annotation = [pdfView currentAnnotation];
        NSView *accessoryView = nil;
        
        if ([annotation isSkimNote]) {
            
            if ([annotation isText]) {
                mwcFlags.updatingFont = 1;
                [[NSFontManager sharedFontManager] setSelectedFont:[annotation font] isMultiple:NO];
                mwcFlags.updatingFont = 0;
                mwcFlags.updatingFontAttributes = 1;
                [[NSFontManager sharedFontManager] setSelectedAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[annotation fontColor], NSForegroundColorAttributeName, nil] isMultiple:NO];
                mwcFlags.updatingFontAttributes = 0;
                
                if (textColorAccessoryView == nil)
                    textColorAccessoryView = [self newColorAccessoryButtonWithTitle:NSLocalizedString(@"Text color", @"Check button title")];
                accessoryView = textColorAccessoryView;
                
            } else if ([annotation hasBorder]) {
                
                mwcFlags.updatingLine = 1;
                [[SKLineInspector sharedLineInspector] setAnnotationStyle:annotation];
                mwcFlags.updatingLine = 0;
                
                if ([annotation hasInteriorColor]) {
                    if (colorAccessoryView == nil)
                        colorAccessoryView = [self newColorAccessoryButtonWithTitle:NSLocalizedString(@"Fill color", @"Check button title")];
                    accessoryView = colorAccessoryView;
                }
            }
            
            [self updateColorPanel:nil];
            
        }
        
        if ([[NSColorPanel sharedColorPanel] accessoryView] != accessoryView) {
            [[NSColorPanel sharedColorPanel] setAccessoryView:nil];
            [[NSColorPanel sharedColorPanel] setAccessoryView:accessoryView];
        }
    }
}

#pragma mark NSWindow delegate protocol

- (void)windowDidBecomeMain:(NSNotification *)notification {
    if ([self interactionMode] != SKPresentationMode) {
        [self updateUtilityPanels];
    } else if ([NSApp isActive] && [[NSUserDefaults standardUserDefaults] boolForKey:SKUseNormalLevelForPresentationKey] == NO) {
        [[self window] setLevel:NSPopUpMenuWindowLevel];
    }
}

- (void)windowDidResignMain:(NSNotification *)notification {
    if ([self interactionMode] != SKPresentationMode) {
        [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
        if ([[[NSColorPanel sharedColorPanel] accessoryView] isEqual:colorAccessoryView] || [[[NSColorPanel sharedColorPanel] accessoryView] isEqual:textColorAccessoryView])
            [[NSColorPanel sharedColorPanel] setAccessoryView:nil];
    } else if ([[NSUserDefaults standardUserDefaults] boolForKey:SKUseNormalLevelForPresentationKey] == NO) {
        [[self window] setLevel:NSNormalWindowLevel];
    }
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    if ([self interactionMode] == SKPresentationMode && [[self window] firstResponder] != presentationView && [self window] == [presentationView window]) {
        [[self window] makeFirstResponder:presentationView];
    }
}


- (void)windowDidResignKey:(NSNotification *)notification {
    if ([self interactionMode] != SKPresentationMode) {
        [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
    }
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
    if ([self interactionMode] == SKPresentationMode) {
        NSScreen *screen = [[self window] screen];
        [[self window] setFrame:[screen frame] display:NO];
        if (sideWindow) {
            NSRect screenFrame = [[[self window] screen] frame];
            NSRect frame = [sideWindow frame];
            frame.origin.x = NSMinX(screenFrame);
            frame.origin.y = NSMidY(screenFrame) - floor(0.5 * NSHeight(frame));
            [sideWindow setFrame:frame display:YES];
        }
    }
}

- (void)windowDidMove:(NSNotification *)notification {
    if ([self interactionMode] == SKPresentationMode) {
        if ([[self window] styleMask] == NSWindowStyleMaskBorderless) {
            NSScreen *screen = [[self window] screen];
            NSRect screenFrame = [screen frame];
            if (NSEqualRects(screenFrame, [[self window] frame]) == NO)
                [[self window] setFrame:screenFrame display:NO];
        }
        if (sideWindow) {
            NSRect screenFrame = [[[self window] screen] frame];
            NSRect frame = [sideWindow frame];
            frame.origin.x = NSMinX(screenFrame);
            frame.origin.y = NSMidY(screenFrame) - floor(0.5 * NSHeight(frame));
            [sideWindow setFrame:frame display:YES];
        }
    }
}

- (void)windowDidChangeBackingProperties:(NSNotification *)notification {
    if ([self interactionMode] != SKPresentationMode) {
        CGFloat oldScale = [[[notification userInfo] objectForKey:@"NSBackingPropertyOldScaleFactorKey"] doubleValue];
        if (fabs(oldScale - [[self window] backingScaleFactor]) > 0.0) {
            [self allThumbnailsNeedUpdate];
            [self allSnapshotsNeedUpdate];
        }
    }
}

- (BOOL)windowShouldClose:(NSWindow *)window {
    if (mwcFlags.isSwitchingFullScreen)
        return NO;
    if ([self interactionMode] == SKPresentationMode)
        return [self canExitPresentation];
    if (mwcFlags.isEditingTable || [pdfView isEditing])
        return [self commitEditing];
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    [(id)[self document] windowWillClose:notification];
    
    if ([[pdfView document] isFinding])
        [[pdfView document] cancelFindString];
    
    if ((mwcFlags.isEditingTable || [pdfView isEditing]) && [self commitEditing] == NO)
        [self discardEditing];
    
    [self cleanup]; // clean up everything
}

- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)anObject {
    if (fieldEditor == nil) {
        fieldEditor = [[SKFieldEditor alloc] init];
        [fieldEditor setFieldEditor:YES];
    }
    return fieldEditor;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    NSUndoManager *undoManager = nil;
    if ([self interactionMode] == SKPresentationMode)
        undoManager = [presentationNotesAuxiliary undoManager];
    return undoManager ?: [[self document] undoManager];
}

- (void)window:(NSWindow *)window willSendEvent:(NSEvent *)event {
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
    
    if ([pdfView temporaryToolMode] != SKToolModeNone && [pdfView window] == window) {
        if ([event type] == NSEventTypeLeftMouseDown) {
            NSView *view = [pdfView hitTest:[pdfView convertPoint:[event locationInWindow] fromView:nil]];
            if ([view isDescendantOf:[pdfView documentView]] == NO || [view isKindOfClass:[NSTextView class]])
                [pdfView setTemporaryToolMode:SKToolModeNone];
        } else {
            [pdfView setTemporaryToolMode:SKToolModeNone];
        }
    }
}

#pragma mark Selection and Page and history highlights

#define MAX_HIGHLIGHTS 5

- (NSInteger)thumbnailHighlightLevelForRow:(NSInteger)row {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableHistoryHighlightsKey] == NO) {
        NSInteger i, iMax = MIN([lastViewedPages count], MAX_HIGHLIGHTS);
        for (i = 0; i < iMax; i++) {
            if (row == (NSInteger)[lastViewedPages pointerAtIndex:i])
                return MAX_HIGHLIGHTS - i;
        }
    }
    return 0;
}

- (NSInteger)tocHighlightLevelForRow:(NSInteger)row {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableHistoryHighlightsKey] == NO) {
        NSOutlineView *ov = leftSideController.tocOutlineView;
        NSInteger numRows = [ov numberOfRows];
        NSInteger firstPage = [[[ov itemAtRow:row] page] pageIndex];
        NSInteger lastPage = row + 1 < numRows ? [[[ov itemAtRow:row + 1] page] pageIndex] : [[self pdfDocument] pageCount];
        NSRange range = NSMakeRange(firstPage, MAX(1L, lastPage - firstPage));
        NSInteger i, iMax = MIN([lastViewedPages count], MAX_HIGHLIGHTS);
        for (i = 0; i < iMax; i++) {
            if (NSLocationInRange((NSUInteger)[lastViewedPages pointerAtIndex:i], range))
                return MAX_HIGHLIGHTS - i;
        }
    }
    return 0;
}

- (void)updateThumbnailSelectionHighlights {
    // Get index of current page.
    NSUInteger pageIndex = [[pdfView currentPage] pageIndex];
    mwcFlags.updatingThumbnailSelection = 1;
    [leftSideController.thumbnailTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:pageIndex] byExtendingSelection:NO];
    [leftSideController.thumbnailTableView scrollRowToVisible:pageIndex];
    
    if (overviewView) {
        [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:pageIndex]];
        if ([self hasOverview])
            [overviewView scrollRectToVisible:[overviewView frameForItemAtIndex:pageIndex]];
    }
    mwcFlags.updatingThumbnailSelection = 0;
    
    [leftSideController.thumbnailTableView enumerateAvailableRowViewsUsingBlock:^(SKHighlightingTableRowView *rowView, NSInteger row){
        [rowView setHighlightLevel:[self thumbnailHighlightLevelForRow:row]];
    }];
    
    if (overviewView) {
        for (NSIndexPath *indexPath in [overviewView indexPathsForVisibleItems])
            [(SKThumbnailItem *)[overviewView itemAtIndexPath:indexPath] setHighlightLevel:[self thumbnailHighlightLevelForRow:[indexPath item]]];
    }
}

- (void)updateTocSelectionHighlights {
    // Skip out if this PDF has no outline.
    if ([[pdfView document] outlineRoot] == nil)
        return;
    
    if (mwcFlags.updatingOutlineSelection == 0) {
        // Get index of current page.
        NSUInteger pageIndex = [[pdfView currentPage] pageIndex];
        
        // Test that the current selection is still valid.
        NSInteger row = [leftSideController.tocOutlineView selectedRow];
        if (row == -1 || [[[leftSideController.tocOutlineView itemAtRow:row] page] pageIndex] != pageIndex) {
            // Get the outline row that contains the current page
            NSInteger numRows = [leftSideController.tocOutlineView numberOfRows];
            for (row = 0; row < numRows; row++) {
                // Get the page for the given row....
                PDFPage *page = [[leftSideController.tocOutlineView itemAtRow:row] page];
                if (page == nil) {
                    continue;
                } else if ([page pageIndex] == pageIndex) {
                    break;
                } else if ([page pageIndex] > pageIndex) {
                    if (row > 0) --row;
                    break;
                }
            }
            if (row == numRows)
                row--;
            if (row != -1) {
                mwcFlags.updatingOutlineSelection = 1;
                [leftSideController.tocOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                mwcFlags.updatingOutlineSelection = 0;
            }
        }
    }
    
    if (@available(macOS 11.0, *)) {
        [leftSideController.tocOutlineView enumerateAvailableRowViewsUsingBlock:^(SKHighlightingTableRowView *rowView, NSInteger row){
            [rowView setHighlightLevel:[self tocHighlightLevelForRow:row]];
        }];
    }
}

#pragma mark NSTableView datasource protocol

// AppKit bug: need a dummy NSTableDataSource implementation, otherwise some NSTableView delegate methods are ignored
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        return [[rightSideController.snapshotArrayController arrangedObjects] count];
    }
    return 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        return [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
    }
    return nil;
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tv pasteboardWriterForRow:(NSInteger)row {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        if ([[pdfView document] isLocked] == NO) {
            PDFPage *page = [[pdfView document] pageAtIndex:row];
            return [page filePromiseForPageIndexes:nil];
        }
    } else if ([tv isEqual:rightSideController.snapshotTableView]) {
        SKSnapshotWindowController *snapshot = [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
        return [[NSFilePromiseProvider alloc] initWithFileType:NSPasteboardTypeTIFF delegate:snapshot];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
    if (([tv isEqual:leftSideController.thumbnailTableView] || [tv isEqual:rightSideController.snapshotTableView]) &&
        [rowIndexes count] == 1) {
        NSTableCellView *view = [tv viewAtColumn:0 row:[rowIndexes firstIndex] makeIfNecessary:NO];
        if (view) {
            // The docs say it uses screen coordinates when we pass a nil view.
            // In reality the coodinates are offset by the mouse postion relative to the top-left of the screen, it seems. Huh?
            NSRect frame = [[view window] convertRectToScreen:[view convertRect:[view bounds] toView:nil]];
            frame.origin.x -= screenPoint.x - [session draggingLocation].x;
            frame.origin.y -= screenPoint.y - [session draggingLocation].y;
            NSArray *classes = @[[NSPasteboardItem class]];
            [session enumerateDraggingItemsWithOptions:0 forView:nil classes:classes searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop){
                [draggingItem setImageComponentsProvider:^{
                    return [view draggingImageComponents];
                }];
                [draggingItem setDraggingFrame:frame];
            }];
        }
    }
}

#pragma mark NSTableView delegate protocol


// This makes the thumbnail tableview view based on 10.7+
// on 10.6 this is ignored, and the cell based tableview uses the datasource methods
- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        NSTableCellView *view = [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
        if ([[tableColumn identifier] isEqualToString:PAGE_COLUMNID])
            [[view imageView] setObjectValue:(NSUInteger)row == markedPage.pageIndex ? [NSImage markImage] : nil];
        return view;
    } else if ([tv isEqual:rightSideController.snapshotTableView]) {
        return [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
    } else if ([tv isEqual:leftSideController.findTableView] || [tv isEqual:leftSideController.groupedFindTableView]) {
        return [tv makeViewWithIdentifier:([tableColumn identifier] ?: HEADER_IDENTIFIER) owner:self];
    }
    return nil;
}

- (NSView *)tableView:(NSTableView *)tv rowViewForRow:(NSInteger)row {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        SKHighlightingTableRowView *rowView = [tv makeViewWithIdentifier:NSTableViewRowViewKey owner:self];
        [rowView setHighlightLevel:[self thumbnailHighlightLevelForRow:row]];
        return rowView;
    }
    return nil;
}

- (BOOL)tableView:(NSTableView *)tv isGroupRow:(NSInteger)row {
    if ([tv isEqual:leftSideController.findTableView] || [tv isEqual:leftSideController.groupedFindTableView]) {
        return row == 0;
    }
    return NO;
}

- (NSIndexSet *)tableView:(NSTableView *)tv selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes {
    if ([tv isEqual:leftSideController.findTableView] || [tv isEqual:leftSideController.groupedFindTableView]) {
        if ([proposedSelectionIndexes containsIndex:0]) {
            NSMutableIndexSet *indexes = [proposedSelectionIndexes mutableCopy];
            [indexes removeIndex:0];
            return indexes;
        }
    }
    return proposedSelectionIndexes;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSTableView *tv = [aNotification object];
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        if (mwcFlags.updatingThumbnailSelection == 0) {
            NSInteger row = [leftSideController.thumbnailTableView selectedRow];
            if ([self interactionMode] == SKPresentationMode) {
                if (row != -1)
                    [presentationView setPage:[[pdfView document] pageAtIndex:row]];

                if ([[NSUserDefaults standardUserDefaults] boolForKey:SKAutoHidePresentationContentsKey])
                    [self hideSideWindow];
            } else {
                if (row != -1)
                    [pdfView goAndScrollToPage:[[pdfView document] pageAtIndex:row]];
            }
        }
    } else if ([tv isEqual:rightSideController.snapshotTableView]) {
        NSInteger row = [[aNotification object] selectedRow];
        if (row != -1) {
            SKSnapshotWindowController *controller = [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
            if ([[controller window] isVisible])
                [[controller window] orderFront:self];
        }
    } else if ([tv isEqual:leftSideController.findTableView] ||
               [tv isEqual:leftSideController.groupedFindTableView]) {
        if (mwcFlags.updatingFindResults == 0) {
            searchResultIndex = 0;
            [self updateSearchResultHighlights];
            
            if ([self interactionMode] == SKPresentationMode && [[NSUserDefaults standardUserDefaults] boolForKey:SKAutoHidePresentationContentsKey])
                [self hideSideWindow];
        }
    }
}

- (BOOL)tableView:(NSTableView *)tv commandSelectRow:(NSInteger)row {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        NSRect rect = [[[pdfView document] pageAtIndex:row] boundsForBox:kPDFDisplayBoxCropBox];
        
        rect.origin.y = NSMidY(rect) - 0.5 * SNAPSHOT_HEIGHT;
        rect.size.height = SNAPSHOT_HEIGHT;
        SKSnapshotWindowController *swc = [self makeSnapshot];
        [swc displayPage:[[pdfView document] pageAtIndex:row] rect:rect scaleFactor:[pdfView scaleFactor] autoFits:NO];
        return YES;
    }
    return NO;
}
   
- (void)tableViewColumnDidResize:(NSNotification *)aNotification {
    NSString *tcID = [[[aNotification userInfo] objectForKey:@"NSTableColumn"] identifier];
    if ([tcID isEqualToString:IMAGE_COLUMNID]) {
        SKTableView *tv = [aNotification object];
        if ([tv isEqual:leftSideController.thumbnailTableView] || [tv isEqual:rightSideController.snapshotTableView]) {
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:0.0];
            [tv noteHeightOfRowsChanged];
            [NSAnimationContext endGrouping];
        }
    } else if ([tcID isEqualToString:RESULTS_COLUMNID]) {
        SKTableView *tv = [aNotification object];
        if ([tv isEqual:leftSideController.findTableView] && [tv numberOfRows] > 1) {
            if ([tv inLiveResize]) {
                mwcFlags.findRowHeightsNeedUpdate = YES;
            } else {
                [NSAnimationContext beginGrouping];
                [[NSAnimationContext currentContext] setDuration:0.0];
                [tv noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [tv numberOfRows] - 1)]];
                [NSAnimationContext endGrouping];
            }
        }
    }
}

- (void)tableViewDidEndLiveResize:(NSTableView *)tv {
    if (mwcFlags.findRowHeightsNeedUpdate && [tv isEqual:leftSideController.findTableView]) {
        if ([searchResults count] > 1)
            [leftSideController.findTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [searchResults count] - 1)]];
        mwcFlags.findRowHeightsNeedUpdate = NO;
    }
}

- (CGFloat)tableView:(NSTableView *)tv heightOfRow:(NSInteger)row {
    NSSize thumbSize = NSZeroSize;
    CGFloat thumbHeight = 0.0, rowHeight = [tv rowHeight];
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        thumbSize = [[thumbnails objectAtIndex:row] size];
        thumbHeight = thumbnailSize;
    } else if ([tv isEqual:rightSideController.snapshotTableView]) {
        thumbSize = [[(SKSnapshotWindowController *)[[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row] thumbnail] size];
        thumbHeight = snapshotThumbnailSize;
    } else if ([tv isEqual:leftSideController.findTableView]) {
        if (row == 0)
            return FIND_HEADER_ROW_HEIGHT;
        NSTableColumn *tc = [tv tableColumnWithIdentifier:RESULTS_COLUMNID];
        NSTextFieldCell *cell = [tc dataCell];
        [cell setObjectValue:[[[leftSideController.findArrayController arrangedObjects] objectAtIndex:row] contextString]];
        CGFloat height = [cell cellSizeForBounds:NSMakeRect(0.0, 0.0, [tc width], CGFLOAT_MAX)].height;
        if (height > MAX_FIND_LINES * (rowHeight - 5.0))
            height = fmin(height, MAX_FIND_LINES * [cell cellSizeForBounds:NSMakeRect(0.0, 0.0, CGFLOAT_MAX, CGFLOAT_MAX)].height);
        return fmax(rowHeight, height + EXTRA_FIND_ROW_HEIGHT);
    } else if ([tv isEqual:leftSideController.groupedFindTableView]) {
        return row == 0 ? FIND_HEADER_ROW_HEIGHT : rowHeight;
    } else {
        return rowHeight;
    }
    if (thumbSize.height <= rowHeight)
        return rowHeight;
    return fmax(rowHeight, fmin(thumbHeight, fmin(thumbSize.height, ceil([[tv tableColumnWithIdentifier:IMAGE_COLUMNID] width] * thumbSize.height / thumbSize.width))));
}

- (NSArray *)tableView:(NSTableView *)tv rowActionsForRow:(NSInteger)row edge:(NSTableRowActionEdge)edge {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        SKSnapshotWindowController *controller = [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
        NSTableViewRowAction *action = nil;
        if (edge == NSTableRowActionEdgeTrailing) {
            action = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleDestructive title:NSLocalizedString(@"Delete", @"") handler:^(NSTableViewRowAction *anAction, NSInteger aRow){
                [[controller window] close];
            }];
        } else if ([[controller window] isVisible]) {
            action = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleRegular title:NSLocalizedString(@"Hide", @"") handler:^(NSTableViewRowAction *anAction, NSInteger aRow){
                [controller miniaturize];
                [tv setRowActionsVisible:NO];
            }];
        } else {
            action = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleRegular title:NSLocalizedString(@"Show", @"") handler:^(NSTableViewRowAction *anAction, NSInteger aRow){
                [controller deminiaturize];
                [tv setRowActionsVisible:NO];
            }];
        }
        if (action)
            return @[action];
    }
    return @[];
}

- (void)tableView:(NSTableView *)tv copyRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        NSUInteger idx = [rowIndexes firstIndex];
        if (idx != NSNotFound && [[pdfView document] isLocked] == NO) {
            PDFPage *page = [[pdfView document] pageAtIndex:idx];
            [page writeToClipboardForPageIndexes:nil];
        }
    } else if ([tv isEqual:leftSideController.findTableView]) {
        NSMutableString *string = [NSMutableString string];
        NSArray *results = [leftSideController.findArrayController arrangedObjects];
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            if (idx > 0) {
                PDFSelection *match = [results objectAtIndex:idx];
                [string appendString:@"* "];
                [string appendFormat:NSLocalizedString(@"Page %@", @""), [[match safeFirstPage] displayLabel]];
                [string appendFormat:@": %@\n", [[match contextString] string]];
            }
        }];
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard writeObjects:@[string]];
    } else if ([tv isEqual:leftSideController.groupedFindTableView]) {
        NSMutableString *string = [NSMutableString string];
        NSArray *results = [leftSideController.groupedFindArrayController arrangedObjects];
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            if (idx > 0) {
                SKGroupedSearchResult *result = [results objectAtIndex:idx];
                NSArray *matches = [result matches];
                [string appendString:@"* "];
                [string appendFormat:NSLocalizedString(@"Page %@", @""), [[result page] displayLabel]];
                [string appendString:@": "];
                [string appendFormat:NSLocalizedString(@"%ld Results", @""), (long)[matches count]];
                [string appendFormat:@":\n\t%@\n", [[matches valueForKeyPath:@"contextString.string"] componentsJoinedByString:@"\n\t"]];
            }
        }];
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard writeObjects:@[string]];
    }
}

- (BOOL)tableView:(NSTableView *)tv canCopyRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        return [rowIndexes count] > 0 && [[self pdfDocument] isLocked] == NO;
    } else if ([tv isEqual:leftSideController.findTableView] ||
         [tv isEqual:leftSideController.groupedFindTableView]) {
         return [rowIndexes count] > 0;
     }
    return NO;
}

- (void)tableView:(NSTableView *)tv deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        NSArray *controllers = [[rightSideController.snapshotArrayController arrangedObjects] objectsAtIndexes:rowIndexes];
        [controllers makeObjectsPerformSelector:@selector(close)];
    }
}

- (BOOL)tableView:(NSTableView *)tv canDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        return [rowIndexes count] > 0;
    }
    return NO;
}

- (void)tableViewMoveLeft:(NSTableView *)tv {
    if (([tv isEqual:leftSideController.findTableView] || [tv isEqual:leftSideController.groupedFindTableView])) {
        if ([tv numberOfSelectedRows]) {
            --searchResultIndex;
            [self updateSearchResultHighlights];
        }
    }
}

- (void)tableViewMoveRight:(NSTableView *)tv {
    if (([tv isEqual:leftSideController.findTableView] || [tv isEqual:leftSideController.groupedFindTableView])) {
        if ([tv numberOfSelectedRows]) {
            ++searchResultIndex;
            [self updateSearchResultHighlights];
        }
    }
}

- (id <SKImageToolTipContext>)tableView:(NSTableView *)tv imageContextForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row scale:(CGFloat *)scale {
    if (tableColumn) {
        return nil;
    } else if ([tv isEqual:leftSideController.findTableView]) {
        *scale = [[self pdfView] scaleFactor];
        return row == 0 ? nil : [[leftSideController.findArrayController arrangedObjects] objectAtIndex:row];
    } else if ([tv isEqual:leftSideController.groupedFindTableView]) {
        *scale = [[self pdfView] scaleFactor];
        return row == 0 ? nil : [[leftSideController.groupedFindArrayController arrangedObjects] objectAtIndex:row];
    }
    return nil;
}

- (NSArray *)tableViewTypeSelectHelperSelectionStrings:(NSTableView *)tv {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        return pageLabels;
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv typeSelectHelperDidFailToFindMatchForSearchString:(NSString *)searchString {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        [[statusBar leftField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"No match: \"%@\"", @"Status message"), searchString]];
    }
}

- (void)tableView:(NSTableView *)tv typeSelectHelperUpdateSearchString:(NSString *)searchString {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        if (searchString)
            [[statusBar leftField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Go to page: %@", @"Status message"), searchString]];
        else
            [self updateLeftStatus];
    }
}

#pragma mark NSOutlineView datasource protocol

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item{
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        if (item == nil && [[pdfView document] isLocked] == NO)
            item = [[pdfView document] outlineRoot];
        return [(PDFOutline *)item numberOfChildren];
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        if (item == nil)
            return [[rightSideController.noteArrayController arrangedObjects] count];
        else
            return [item hasNoteText];
    }
    return 0;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)anIndex ofItem:(id)item{
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        if (item == nil && [[pdfView document] isLocked] == NO)
            item = [[pdfView document] outlineRoot];
        id obj = [(PDFOutline *)item childAtIndex:anIndex];
        return obj;
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        if (item == nil)
            return [[rightSideController.noteArrayController arrangedObjects] objectAtIndex:anIndex];
        else
            return [item noteText];
    }
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item{
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        if (item == nil && [[pdfView document] isLocked] == NO)
            item = [[pdfView document] outlineRoot];
        return ([(PDFOutline *)item numberOfChildren] > 0);
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        return [item hasNoteText];
    }
    return NO;
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    if ([ov isEqual:leftSideController.tocOutlineView] || [ov isEqual:rightSideController.noteOutlineView]) {
        return item;
    }
    return nil;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)anIndex {
    NSDragOperation dragOp = NSDragOperationNone;
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        NSPasteboard *pboard = [info draggingPasteboard];
        if ([pboard canReadObjectForClasses:@[[NSColor class]] options:@{}]) {
            if (anIndex == NSOutlineViewDropOnItemIndex && [(PDFAnnotation *)item type] != nil) {
                dragOp = NSDragOperationEvery;
            } else if ([ov selectedRow] != -1) {
                [ov setDropItem:nil dropChildIndex:NSOutlineViewDropOnItemIndex];
                dragOp = NSDragOperationEvery;
            }
        }
    }
    return dragOp;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)anIndex {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        NSPasteboard *pboard = [info draggingPasteboard];
        if ([pboard canReadObjectForClasses:@[[NSColor class]] options:@{}]) {
            BOOL isShift = ([NSEvent modifierFlags] & NSEventModifierFlagShift) != 0;
            BOOL isAlt = ([NSEvent modifierFlags] & NSEventModifierFlagOption) != 0;
            NSColor *color = [NSColor colorFromPasteboard:pboard];
            if (item) {
                [item setColor:color alternate:isAlt updateDefaults:isShift];
            } else {
                for (PDFAnnotation *note in [self selectedNotes])
                    [note setColor:color alternate:isAlt updateDefaults:isShift];
            }
            return YES;
        }
    }
    return NO;
}

#pragma mark NSOutlineView delegate protocol

- (NSView *)outlineView:(NSOutlineView *)ov viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        return [ov makeViewWithIdentifier:[tableColumn identifier] owner:self];
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        if ([(PDFAnnotation *)item type] || tableColumn == [ov outlineTableColumn]) {
            NSString *columnID = [tableColumn identifier];
            NSTableCellView *view = [ov makeViewWithIdentifier:columnID owner:self];
            if ([columnID isEqualToString:TYPE_COLUMNID])
                [(SKAnnotationTypeImageView *)[view imageView] setHasOutline:[pdfView currentAnnotation] == item];
            else if ([(PDFAnnotation *)item type] && ([columnID isEqualToString:NOTE_COLUMNID] || [columnID isEqualToString:AUTHOR_COLUMNID]))
                [[view textField] setDelegate:self];
            return view;
        }
    }
    return nil;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)ov rowViewForItem:(id)item {
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        if (@available(macOS 11.0, *)) {
            SKHighlightingTableRowView *rowView = [ov makeViewWithIdentifier:NSTableViewRowViewKey owner:self];
            [rowView setHighlightLevel:[self tocHighlightLevelForRow:[ov rowForItem:item]]];
            return rowView;
        }
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)ov didClickTableColumn:(NSTableColumn *)tableColumn {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        NSTableColumn *oldTableColumn = [ov highlightedTableColumn];
        NSTableColumn *newTableColumn = ([NSEvent modifierFlags] & NSEventModifierFlagCommand) ? nil : tableColumn;
        NSMutableArray *sortDescriptors = nil;
        BOOL ascending = YES;
        if ([oldTableColumn isEqual:newTableColumn]) {
            sortDescriptors = [[rightSideController.noteArrayController sortDescriptors] mutableCopy];
            [sortDescriptors replaceObjectAtIndex:0 withObject:[[sortDescriptors firstObject] reversedSortDescriptor]];
            ascending = [[sortDescriptors firstObject] ascending];
        } else {
            NSString *tcID = [newTableColumn identifier];
            NSSortDescriptor *pageIndexSortDescriptor = [[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationPageIndexKey ascending:ascending];
            NSSortDescriptor *boundsSortDescriptor = [[NSSortDescriptor alloc] initWithKey:SKPDFAnnotationBoundsOrderKey ascending:ascending selector:@selector(compare:)];
            sortDescriptors = [NSMutableArray arrayWithObjects:pageIndexSortDescriptor, boundsSortDescriptor, nil];
            if ([tcID isEqualToString:TYPE_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationTypeKey ascending:YES selector:@selector(noteTypeCompare:)] atIndex:0];
            } else if ([tcID isEqualToString:COLOR_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationColorKey ascending:YES selector:@selector(colorCompare:)] atIndex:0];
            } else if ([tcID isEqualToString:NOTE_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationStringKey ascending:YES selector:@selector(localizedCaseInsensitiveNumericCompare:)] atIndex:0];
            } else if ([tcID isEqualToString:AUTHOR_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationUserNameKey ascending:YES selector:@selector(localizedCaseInsensitiveNumericCompare:)] atIndex:0];
            } else if ([tcID isEqualToString:DATE_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationModificationDateKey ascending:YES] atIndex:0];
            }
            if (oldTableColumn)
                [ov setIndicatorImage:nil inTableColumn:oldTableColumn];
            [ov setHighlightedTableColumn:newTableColumn]; 
        }
        [rightSideController.noteArrayController setSortDescriptors:sortDescriptors];
        if (newTableColumn)
            [ov setIndicatorImage:[NSImage imageNamed:ascending ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator"]
                    inTableColumn:newTableColumn];
        [ov reloadData];
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification{
	// Get the destination associated with the search result list. Tell the PDFView to go there.
	if ([[notification object] isEqual:leftSideController.tocOutlineView] && (mwcFlags.updatingOutlineSelection == 0)){
        [self goToSelectedOutlineItem:nil];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldExpandItem:(id)item{
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        return [rightSideController.noteOutlineView isDropping] == NO;
    }
    return YES;
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification{
    if ([[notification object] isEqual:leftSideController.tocOutlineView] && mwcFlags.updatingOutlineSelection == 0) {
        [self updateTocSelectionHighlights];
    }
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification{
    if ([[notification object] isEqual:leftSideController.tocOutlineView] && mwcFlags.updatingOutlineSelection == 0) {
        [self updateTocSelectionHighlights];
    }
}

- (void)outlineViewColumnDidResize:(NSNotification *)notification{
    
    if (mwcFlags.autoResizeNoteRows && [[notification object] isEqual:rightSideController.noteOutlineView] &&
        [(SKScrollView *)[rightSideController.noteOutlineView enclosingScrollView] isResizingSubviews] == NO)
        [rightSideController.noteOutlineView performSelectorOnce:@selector(noteHeightOfRowsChanged) afterDelay:0.0];
}

- (void)outlineViewColumnDidMove:(NSNotification *)notification {
    if (mwcFlags.autoResizeNoteRows && [[notification object] isEqual:rightSideController.noteOutlineView]) {
        NSInteger oldColumn = [[[notification userInfo] objectForKey:@"NSOldColumn"] integerValue];
        NSInteger newColumn = [[[notification userInfo] objectForKey:@"NSNewColumn"] integerValue];
        NSInteger firstColumn = 0;
        for (NSTableColumn *tc in [rightSideController.noteOutlineView tableColumns]) {
            if ([tc isHidden])
                ++firstColumn;
            else
                break;
        }
        if (oldColumn == firstColumn || newColumn == firstColumn)
            [rightSideController.noteOutlineView performSelectorOnce:@selector(noteHeightOfRowsChanged) afterDelay:0.0];
    }
}

- (CGFloat)outlineView:(NSOutlineView *)ov heightOfRowByItem:(id)item {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        CGFloat rowHeight = [rightSideController.noteOutlineView rowHeightForItem:item];
        if (rowHeight <= 0.0) {
            if (mwcFlags.autoResizeNoteRows) {
                NSTableColumn *tableColumn = [ov outlineTableColumn];
                CGFloat width = 0.0;
                id cell = [tableColumn dataCell];
                [cell setObjectValue:[item objectValue]];
                // don't use cellFrameAtRow:column: as this needs the row height which we are calculating
                if ([(PDFAnnotation *)item type] == nil)
                    width = fmax(10.0, [(SKNoteOutlineView *)ov fullWidthCellWidth]);
                else if ([tableColumn isHidden] == NO)
                    width = [tableColumn width] - [(SKNoteOutlineView *)ov outlineIndentation];
                if (width > 0.0)
                    rowHeight = [cell cellSizeForBounds:NSMakeRect(0.0, 0.0, width, CGFLOAT_MAX)].height;
                rowHeight = round(fmax(rowHeight, [ov rowHeight]) + EXTRA_ROW_HEIGHT);
                [rightSideController.noteOutlineView setRowHeight:rowHeight forItem:item];
            } else {
                rowHeight = [(PDFAnnotation *)item type] ? [ov rowHeight] + EXTRA_ROW_HEIGHT : ([[(SKNoteText *)item note] isNote] ? DEFAULT_TEXT_ROW_HEIGHT : DEFAULT_MARKUP_ROW_HEIGHT);
            }
        }
        return rowHeight;
    }
    return [ov rowHeight];
}

- (NSArray *)noteItems:(NSArray *)items {
    NSMutableArray *noteItems = [NSMutableArray array];
    
    for (id item in items) {
        PDFAnnotation *note = [(PDFAnnotation *)item type] == nil ? [item note] : item;
        if ([noteItems containsObject:note] == NO)
            [noteItems addObject:note];
    }
    return noteItems;
}

- (void)outlineView:(NSOutlineView *)ov deleteItems:(NSArray *)items  {
    if ([ov isEqual:rightSideController.noteOutlineView] && [items count]) {
        for (PDFAnnotation *item in [self noteItems:items])
            [[self pdfDocument] removeAnnotation:item];
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Remove Note", @"Undo action name")];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov canDeleteItems:(NSArray *)items  {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        return [[self pdfDocument] allowsNotes] && [items count] > 0;
    }
    return NO;
}

- (void)outlineView:(NSOutlineView *)ov copyItems:(NSArray *)items  {
    if ([ov isEqual:rightSideController.noteOutlineView] && [items count]) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        NSMutableArray *copiedItems = [NSMutableArray array];
        NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] init];
        BOOL isAttributed = NO;
        
        for (id item in [self noteItems:items]) {
            if ([item isMovable])
                [copiedItems addObject:item];
        }
        for (id item in items) {
            if ([attrString length])
                [attrString replaceCharactersInRange:NSMakeRange([attrString length], 0) withString:@"\n\n"];
            if ([(PDFAnnotation *)item type] == nil && [[(SKNoteText *)item note] isNote]) {
                [attrString appendAttributedString:[(SKNoteText *)item text]];
                isAttributed = YES;
            } else {
                [attrString replaceCharactersInRange:NSMakeRange([attrString length], 0) withString:[item string] ?: @""];
            }
        }
        
        [pboard clearContents];
        if (isAttributed)
            [pboard writeObjects:@[attrString]];
        else
            [pboard writeObjects:@[[attrString string]]];
        if ([copiedItems count] > 0)
            [pboard writeObjects:copiedItems];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov canCopyItems:(NSArray *)items  {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        return [items count] > 0;
    }
    return NO;
}

- (id <SKImageToolTipContext>)outlineView:(NSOutlineView *)ov imageContextForItem:(id)item scale:(CGFloat *)scale {
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        *scale = [[self pdfView] scaleFactor];
        return [item destination];
    }
    return nil;
}

- (NSArray *)outlineViewTypeSelectHelperSelectionStrings:(NSOutlineView *)ov {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        NSInteger i, count = [rightSideController.noteOutlineView numberOfRows];
        NSMutableArray *texts = [NSMutableArray arrayWithCapacity:count];
        for (i = 0; i < count; i++) {
            id item = [rightSideController.noteOutlineView itemAtRow:i];
            NSString *string = [item string];
            [texts addObject:string ?: @""];
        }
        return texts;
    } else if ([ov isEqual:leftSideController.tocOutlineView]) {
        NSInteger i, count = [leftSideController.tocOutlineView numberOfRows];
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
        for (i = 0; i < count; i++) 
            [array addObject:[[(PDFOutline *)[leftSideController.tocOutlineView itemAtRow:i] label] lossyStringUsingEncoding:NSASCIIStringEncoding]];
        return array;
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)ov typeSelectHelperDidFailToFindMatchForSearchString:(NSString *)searchString {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        [[statusBar rightField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"No match: \"%@\"", @"Status message"), searchString]];
    } else if ([ov isEqual:leftSideController.tocOutlineView]) {
        [[statusBar leftField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"No match: \"%@\"", @"Status message"), searchString]];
    }
}

- (void)outlineView:(NSOutlineView *)ov typeSelectHelperUpdateSearchString:(NSString *)searchString {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        if (searchString)
            [[statusBar rightField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Finding note: \"%@\"", @"Status message"), searchString]];
        else
            [self updateRightStatus];
    } else if ([ov isEqual:leftSideController.tocOutlineView]) {
        if (searchString)
            [[statusBar leftField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Finding: \"%@\"", @"Status message"), searchString]];
        else
            [self updateLeftStatus];
    }
}

#pragma mark Contextual menus

- (void)copyPage:(id)sender {
    [self tableView:leftSideController.thumbnailTableView copyRowsWithIndexes:[sender representedObject]];
}

- (void)copyPageURL:(id)sender {
    NSUInteger idx = [[sender representedObject] firstIndex];
    if (idx != NSNotFound) {
        PDFPage *page = [[pdfView document] pageAtIndex:idx];
        NSURL *skimURL = [page skimURL];
        if (skimURL != nil) {
            NSPasteboard *pboard = [NSPasteboard generalPasteboard];
            [pboard clearContents];
            [pboard writeURLs:@[skimURL] names:@[[[self document] displayName]]];
        }
    }
}

- (void)selectSelections:(id)sender {
    NSArray *selections = [sender representedObject];
    PDFSelection *selection = [[selections firstObject] copy];
    NSUInteger count = [selections count];
    if (count > 1)
        [selection addSelections:[selections subarrayWithRange:NSMakeRange(1, count - 1)]];
    [pdfView setCurrentSelection:selection];
}

- (void)changeSearchResultsHighlighting:(id)sender {
    if ([sender tag] == mwcFlags.highlightAllSearchResults)
        return;
    mwcFlags.highlightAllSearchResults = [sender tag];
    [[NSUserDefaults standardUserDefaults] setBool:mwcFlags.highlightAllSearchResults forKey:SKHighlightAllSearchResultsKey];
    NSArray *results = nil;
    if (mwcFlags.highlightAllSearchResults) {
        results = [searchResults count] ? [searchResults subarrayWithRange:NSMakeRange(1, [searchResults count] - 1)] : nil;
    } else if (mwcFlags.findPaneState == SKFindPaneStateSingular && [leftSideController.findTableView window]) {
        results = [leftSideController.findArrayController selectedObjects];
    } else if (mwcFlags.findPaneState == SKFindPaneStateGrouped && [leftSideController.groupedFindTableView window]) {
        results = [[leftSideController.groupedFindArrayController selectedObjects] valueForKeyPath:@"@unionOfArrays.matches"];
    }
    if ([results count]) {
        results = [[NSArray alloc] initWithArray:results copyItems:YES];
        [results setValue:[NSColor findHighlightColor] forKey:@"color"];
    } else {
        results = nil;
    }
    [pdfView setHighlightedSelections:results];
}

- (void)changeSearchResultsSort:(id)sender {
    BOOL currentIsPage = [[[[leftSideController.groupedFindArrayController sortDescriptors] firstObject] key] isEqualToString:SKGroupedSearchResultPageIndexKey];
    BOOL isPage = [sender tag];
    if (currentIsPage == isPage)
        return;
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:isPage ? SKGroupedSearchResultPageIndexKey : SKGroupedSearchResultCountKey ascending:isPage];
    [leftSideController.groupedFindArrayController setSortDescriptors:@[sortDescriptor]];
}

- (void)deleteSnapshot:(id)sender {
    [[sender representedObject] close];
}

- (void)showSnapshot:(id)sender {
    SKSnapshotWindowController *controller = [sender representedObject];
    if ([[controller window] isVisible])
        [[controller window] orderFront:self];
    else
        [controller deminiaturize];
}

- (void)hideSnapshot:(id)sender {
    SKSnapshotWindowController *controller = [sender representedObject];
    if ([[controller window] isVisible])
        [controller miniaturize];
}

- (void)goToSnapshot:(id)sender {
    SKSnapshotWindowController *controller = [sender representedObject];
    NSUInteger pageIndex = [controller pageIndex];
    PDFPage *page = [[pdfView document] pageAtIndex:pageIndex];
    NSRect rect = [controller bounds];
    [pdfView goToRect:rect onPage:page];
}

- (void)deleteNotes:(id)sender {
    [self outlineView:rightSideController.noteOutlineView deleteItems:[sender representedObject]];
}

- (void)copyNotes:(id)sender {
    [self outlineView:rightSideController.noteOutlineView copyItems:[sender representedObject]];
}

- (void)editNoteFromTable:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    SKNoteOutlineView *ov = rightSideController.noteOutlineView;
    NSInteger row = [ov rowForItem:annotation];
    NSInteger column = [ov columnWithIdentifier:NOTE_COLUMNID];
    if (row != -1 && column != -1) {
        [ov selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [ov editColumn:column row:row withEvent:nil select:YES];
    }
}

- (void)editNoteTextFromTable:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    [pdfView scrollAnnotationToVisible:annotation];
    if ([pdfView canSelectNote])
        [pdfView setCurrentAnnotation:annotation];
    [self showNote:annotation];
    SKNoteWindowController *noteController = (SKNoteWindowController *)[self windowControllerForNote:annotation];
    [[noteController window] makeFirstResponder:[noteController textView]];
    [[noteController textView] selectAll:nil];
}

- (void)deselectNote:(id)sender {
    [pdfView setCurrentAnnotation:nil];
}

- (void)selectNote:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    [pdfView scrollAnnotationToVisible:annotation];
    [pdfView setCurrentAnnotation:annotation];
}

- (void)revealNote:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    [pdfView scrollAnnotationToVisible:annotation];
}

- (void)bringNoteToFront:(id)sender {
    PDFAnnotation *note = [sender representedObject];
    PDFPage *page = [note page];
    PDFAnnotation *lastNote = [[page annotations] lastObject];
    
    if (lastNote == note)
        return;
    
    
    NSUInteger i = [[self notes] indexOfObject:note];
    NSUInteger j = [[self notes] indexOfObject:lastNote];
    if (i < j && j != NSNotFound) {
        [self removeObjectFromNotesAtIndex:i];
        [self insertObject:note inNotesAtIndex:j];
    }
    
    [page removeAnnotation:note];
    [page addAnnotation:note];
}

- (void)resetHeightOfNoteRows:(id)sender {
    NSArray *items = [sender representedObject];
    if (items == nil) {
        [rightSideController.noteOutlineView noteHeightOfRowsChanged];
    } else {
        SKNoteOutlineView *ov = rightSideController.noteOutlineView;
        NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
        for (id item in items) {
            [rightSideController.noteOutlineView setRowHeight:0.0 forItem:item];
            NSInteger row = [ov rowForItem:item];
            if (row != -1)
                [indexes addIndex:row];
        }
        [ov noteHeightOfRowsWithIndexesChanged:indexes];
    }
}

- (void)autoSizeNoteRows:(id)sender {
    if (mwcFlags.autoResizeNoteRows) {
        [self resetHeightOfNoteRows:sender];
        return;
    }
    
    NSOutlineView *ov = rightSideController.noteOutlineView;
    CGFloat height = 0.0, rowHeight = [ov rowHeight];
    NSTableColumn *tableColumn = [ov outlineTableColumn];
    id cell = [tableColumn dataCell];
    NSUInteger column = [[ov tableColumns] indexOfObject:tableColumn];
    NSRect rect = NSMakeRect(0.0, 0.0, NSWidth([ov frameOfCellAtColumn:column row:0]), CGFLOAT_MAX);
    NSRect fullRect = NSMakeRect(0.0, 0.0,  NSWidth([ov frameOfCellAtColumn:-1 row:0]), CGFLOAT_MAX);
    NSMutableIndexSet *rowIndexes = nil;
    NSArray *items = [sender representedObject];
    NSInteger row;
    
    if (items == nil) {
        NSMutableArray *tmpItems = [NSMutableArray array];
        for (PDFAnnotation *note in [self notes]) {
            [tmpItems addObject:note];
            if ([note hasNoteText])
                [tmpItems addObject:[note noteText]];
        }
        items = tmpItems;
    } else {
        rowIndexes = [NSMutableIndexSet indexSet];
    }
    
    for (id item in items) {
        [cell setObjectValue:[item objectValue]];
        if ([(PDFAnnotation *)item type] == nil)
            height = [cell cellSizeForBounds:fullRect].height;
        else if ([tableColumn isHidden] == NO)
            height = [cell cellSizeForBounds:rect].height;
        else
            height = 0.0;
        [rightSideController.noteOutlineView setRowHeight:round(fmax(height, rowHeight) + EXTRA_ROW_HEIGHT) forItem:item];
        if (rowIndexes) {
            row = [ov rowForItem:item];
            if (row != -1)
                [rowIndexes addIndex:row];
        }
    }
    [ov noteHeightOfRowsWithIndexesChanged:rowIndexes ?: [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [ov numberOfRows])]];
}

- (void)toggleAutoResizeNoteRows:(id)sender {
    mwcFlags.autoResizeNoteRows = (0 == mwcFlags.autoResizeNoteRows);
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSView *view = [rightSideController.noteOutlineView enclosingScrollView];
    if (mwcFlags.autoResizeNoteRows) {
        [rightSideController.noteOutlineView noteHeightOfRowsChanged];
        [nc addObserver:self selector:@selector(handleNoteViewFrameDidChangeNotification:)
 name:NSViewFrameDidChangeNotification object:view];
        [nc addObserver:self selector:@selector(handleNoteViewDidEndLiveResizeNotification:)
 name:SKScrollViewDidEndLiveResizeNotification object:view];
    } else {
        [self autoSizeNoteRows:nil];
        [nc removeObserver:self
 name:NSViewFrameDidChangeNotification object:view];
        [nc removeObserver:self
 name:SKScrollViewDidEndLiveResizeNotification object:view];
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    NSMenuItem *item = nil;
    [menu removeAllItems];
    if ([self interactionMode] == SKPresentationMode)
        return;
    if ([menu isEqual:[leftSideController.thumbnailTableView menu]]) {
        NSInteger row = [leftSideController.thumbnailTableView clickedRow];
        if (row != -1) {
            item = [menu addItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copyPage:) target:self];
            [item setRepresentedObject:[NSIndexSet indexSetWithIndex:row]];
            item = [menu addItemWithTitle:NSLocalizedString(@"Copy URL", @"Menu item title") action:@selector(copyPageURL:) target:self];
            [item setRepresentedObject:[NSIndexSet indexSetWithIndex:row]];
        }
    } else if ([menu isEqual:[leftSideController.findTableView menu]]) {
        NSInteger row = [leftSideController.findTableView clickedRow];
        if (row > 0 && ([pdfView toolMode] == SKToolModeText || [pdfView canAddNotes])) {
            NSIndexSet *rowIndexes = [leftSideController.findTableView selectedRowIndexes];
            if ([rowIndexes containsIndex:row] == NO)
                rowIndexes = [NSIndexSet indexSetWithIndex:row];
            NSArray *selections = [[leftSideController.findArrayController arrangedObjects] objectsAtIndexes:rowIndexes];
            if ([pdfView toolMode] == SKToolModeText) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Select", @"Menu item title") action:@selector(selectSelections:) target:self];
                [item setRepresentedObject:selections];
            }
            if ([pdfView canAddNotes]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"New Circle", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeCircle];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Box", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeSquare];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Highlight", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeHighlight];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Underline", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeUnderline];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Strike Out", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeStrikeOut];
                [item setRepresentedObject:selections];
            }
            [menu addItem:[NSMenuItem separatorItem]];
        }
        item = [menu addItemWithTitle:NSLocalizedString(@"Highlight Selected", @"Menu item title") action:@selector(changeSearchResultsHighlighting:) target:self tag:0];
        if (mwcFlags.highlightAllSearchResults == 0)
            [item setState:NSControlStateValueOn];
        item = [menu addItemWithTitle:NSLocalizedString(@"Highlight All", @"Menu item title") action:@selector(changeSearchResultsHighlighting:) target:self tag:1];
        if (mwcFlags.highlightAllSearchResults)
            [item setState:NSControlStateValueOn];
    } else if ([menu isEqual:[leftSideController.groupedFindTableView menu]]) {
        NSInteger row = [leftSideController.groupedFindTableView clickedRow];
        if (row > 0 && ([pdfView toolMode] == SKToolModeText || [pdfView canAddNotes])) {
            NSIndexSet *rowIndexes = [leftSideController.groupedFindTableView selectedRowIndexes];
            if ([rowIndexes containsIndex:row] == NO)
                rowIndexes = [NSIndexSet indexSetWithIndex:row];
            NSArray *selections = [[[leftSideController.groupedFindArrayController arrangedObjects] objectsAtIndexes:rowIndexes] valueForKeyPath:@"@unionOfArrays.matches"];
            if ([pdfView toolMode] == SKToolModeText) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Select", @"Menu item title") action:@selector(selectSelections:) target:self];
                [item setRepresentedObject:selections];
            }
            if ([pdfView canAddNotes]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"New Circle", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeCircle];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Box", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeSquare];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Highlight", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeHighlight];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Underline", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeUnderline];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Strike Out", @"Menu item title") action:@selector(addAnnotationsForSelections:) target:pdfView tag:SKNoteTypeStrikeOut];
                [item setRepresentedObject:selections];
            }
            [menu addItem:[NSMenuItem separatorItem]];
        }
        item = [menu addItemWithTitle:NSLocalizedString(@"Highlight Selected", @"Menu item title") action:@selector(changeSearchResultsHighlighting:) target:self tag:0];
        if (mwcFlags.highlightAllSearchResults == 0)
            [item setState:NSControlStateValueOn];
        item = [menu addItemWithTitle:NSLocalizedString(@"Highlight All", @"Menu item title") action:@selector(changeSearchResultsHighlighting:) target:self tag:1];
        if (mwcFlags.highlightAllSearchResults)
            [item setState:NSControlStateValueOn];
        [menu addItem:[NSMenuItem separatorItem]];
        BOOL isPage = [[[[leftSideController.groupedFindArrayController sortDescriptors] firstObject] key] isEqualToString:SKGroupedSearchResultPageIndexKey];
        item = [menu addItemWithTitle:NSLocalizedString(@"Sort By Page", @"Menu item title") action:@selector(changeSearchResultsSort:) target:self tag:1];
        if (isPage)
            [item setState:NSControlStateValueOn];
        item = [menu addItemWithTitle:NSLocalizedString(@"Sort By Results", @"Menu item title") action:@selector(changeSearchResultsSort:) target:self tag:0];
        if (isPage == NO)
            [item setState:NSControlStateValueOn];
    } else if ([menu isEqual:[rightSideController.snapshotTableView menu]]) {
        NSInteger row = [rightSideController.snapshotTableView clickedRow];
        if (row != -1) {
            SKSnapshotWindowController *controller = [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
            item = [menu addItemWithTitle:NSLocalizedString(@"Delete", @"Menu item title") action:@selector(deleteSnapshot:) target:self];
            [item setRepresentedObject:controller];
            item = [menu addItemWithTitle:NSLocalizedString(@"Show", @"Menu item title") action:@selector(showSnapshot:) target:self];
            [item setRepresentedObject:controller];
            if ([[controller window] isVisible]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Hide", @"Menu item title") action:@selector(hideSnapshot:) target:self];
                [item setRepresentedObject:controller];
            }
            item = [menu addItemWithTitle:NSLocalizedString(@"Go", @"Menu item title") action:@selector(goToSnapshot:) target:self];
            [item setRepresentedObject:controller];
        }
    } else if ([menu isEqual:[rightSideController.noteOutlineView menu]]) {
        NSArray *items;
        NSInteger row = [rightSideController.noteOutlineView clickedRow];
        if (row != -1) {
            NSIndexSet *rowIndexes = [rightSideController.noteOutlineView selectedRowIndexes];
            if ([rowIndexes containsIndex:row] == NO)
                rowIndexes = [NSIndexSet indexSetWithIndex:row];
            items = [rightSideController.noteOutlineView itemsAtRowIndexes:rowIndexes];
            
            if ([self outlineView:rightSideController.noteOutlineView canDeleteItems:items]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Delete", @"Menu item title") action:@selector(deleteNotes:) target:self];
                [item setRepresentedObject:items];
            }
            if ([self outlineView:rightSideController.noteOutlineView canCopyItems:items]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copyNotes:) target:self];
                [item setRepresentedObject:items];
            }
            if ([items count] == 1) {
                PDFAnnotation *annotation = [[self noteItems:items] lastObject];
                if ([annotation isEditable]) {
                    if ([(PDFAnnotation *)[items lastObject] type] == nil) {
                        if ([[(SKNoteText *)[items lastObject] note] isNote]) {
                            item = [menu addItemWithTitle:[NSLocalizedString(@"Edit", @"Menu item title") stringByAppendingEllipsis] action:@selector(editNoteTextFromTable:) target:self];
                            [item setRepresentedObject:annotation];
                        }
                    } else if ([[rightSideController.noteOutlineView tableColumnWithIdentifier:NOTE_COLUMNID] isHidden] == NO) {
                        item = [menu addItemWithTitle:NSLocalizedString(@"Edit", @"Menu item title") action:@selector(editNoteFromTable:) target:self];
                        [item setRepresentedObject:annotation];
                        if ([annotation isText] == NO || [pdfView canSelectNote]) {
                            item = [menu addItemWithTitle:[NSLocalizedString(@"Edit", @"Menu item title") stringByAppendingEllipsis] action:@selector(editThisAnnotation:) target:pdfView];
                            [item setRepresentedObject:annotation];
                            [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
                            [item setAlternate:YES];
                        }
                    } else if ([annotation isText] == NO || [pdfView canSelectNote]) {
                        item = [menu addItemWithTitle:[NSLocalizedString(@"Edit", @"Menu item title") stringByAppendingEllipsis] action:@selector(editThisAnnotation:) target:pdfView];
                        [item setRepresentedObject:annotation];
                    }
                }
                if ([pdfView canAddNotes]) {
                    if ([pdfView currentAnnotation] == annotation) {
                        item = [menu addItemWithTitle:NSLocalizedString(@"Deselect", @"Menu item title") action:@selector(deselectNote:) target:self];
                        [item setRepresentedObject:annotation];
                    } else if ([pdfView canSelectNote]) {
                        item = [menu addItemWithTitle:NSLocalizedString(@"Select", @"Menu item title") action:@selector(selectNote:) target:self];
                        [item setRepresentedObject:annotation];
                    }
                    item = [menu addItemWithTitle:NSLocalizedString(@"Show", @"Menu item title") action:@selector(revealNote:) target:self];
                    [item setRepresentedObject:annotation];
                    if ([[[annotation page] annotations] lastObject] != annotation) {
                        item = [menu addItemWithTitle:NSLocalizedString(@"Bring to Front", @"Menu item title") action:@selector(bringNoteToFront:) target:self];
                        [item setRepresentedObject:annotation];
                    }
                }
            }
            if ([menu numberOfItems] > 0)
                [menu addItem:[NSMenuItem separatorItem]];
            item = [menu addItemWithTitle:[items count] == 1 ? NSLocalizedString(@"Auto Size Row", @"Menu item title") : NSLocalizedString(@"Auto Size Rows", @"Menu item title") action:@selector(autoSizeNoteRows:) target:self];
            [item setRepresentedObject:items];
            if (mwcFlags.autoResizeNoteRows == NO) {
                item = [menu addItemWithTitle:[items count] == 1 ? NSLocalizedString(@"Undo Auto Size Row", @"Menu item title") : NSLocalizedString(@"Undo Auto Size Rows", @"Menu item title") action:@selector(resetHeightOfNoteRows:) target:self];
                [item setRepresentedObject:items];
                [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
                [item setAlternate:YES];
            }
            [menu addItemWithTitle:NSLocalizedString(@"Auto Size All", @"Menu item title") action:@selector(autoSizeNoteRows:) target:self];
            if (mwcFlags.autoResizeNoteRows == NO) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Undo Auto Size All", @"Menu item title") action:@selector(resetHeightOfNoteRows:) target:self];
                [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
                [item setAlternate:YES];
            }
            [menu addItemWithTitle:NSLocalizedString(@"Automatically Resize", @"Menu item title") action:@selector(toggleAutoResizeNoteRows:) target:self];
        }
    }
}

#pragma mark NSControl delegate protocol

- (void)controlTextDidBeginEditing:(NSNotification *)note {
    if ([[note object] isDescendantOf:rightSideController.noteOutlineView]) {
        if (mwcFlags.isEditingTable == NO && mwcFlags.isEditingPDF == NO)
            [[self document] objectDidBeginEditing:(id)self];
        mwcFlags.isEditingTable = YES;
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)note {
    if ([[note object] isDescendantOf:rightSideController.noteOutlineView]) {
        if (mwcFlags.isEditingTable && mwcFlags.isEditingPDF == NO)
            [[self document] objectDidEndEditing:(id)self];
        mwcFlags.isEditingTable = NO;
    }
}

- (void)setDocument:(NSDocument *)document {
    if ([self document] && document == nil && (mwcFlags.isEditingTable || [pdfView isEditing])) {
        if ([self commitEditing] == NO)
            [self discardEditing];
        if (mwcFlags.isEditingPDF || mwcFlags.isEditingTable)
            [[self document] objectDidEndEditing:(id)self];
        mwcFlags.isEditingPDF = mwcFlags.isEditingTable = NO;
    }
    [super setDocument:document];
}

#pragma mark NSEditor protocol

- (void)discardEditing {
    if (mwcFlags.isEditingTable || mwcFlags.isEditingPDF) {
        id firstResponder = [[self window] firstResponder];
        if ([firstResponder isKindOfClass:[NSText class]] && [firstResponder isDescendantOf:rightSideController.noteOutlineView])
            [[firstResponder delegate] abortEditing];
        [pdfView discardEditing];
        // when using abortEditing the control does not call the controlTextDidEndEditing: delegate method
        [[self document] objectDidEndEditing:(id)self];
        mwcFlags.isEditingTable = NO;
        mwcFlags.isEditingPDF = NO;
    }
}

- (BOOL)commitEditing {
    return [self commitEditingAndReturnError:NULL];
}

- (BOOL)commitEditingAndReturnError:(NSError **)error {
    // there are no validations of the edited value, so we will always succeed
    BOOL rv = [pdfView commitEditing];
    id firstResponder = [[self window] firstResponder];
    if ([firstResponder isKindOfClass:[NSText class]] && [firstResponder isDescendantOf:rightSideController.noteOutlineView])
        rv = [[rightSideController.noteOutlineView window] makeFirstResponder:rightSideController.noteOutlineView] && rv;
    if (rv == NO && error)
        *error = [NSError documentErrorWithCode:SKFailedToCommitError localizedDescription:NSLocalizedString(@"Failed to commit edits", @"Error description")];
    return rv;
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo {
    BOOL didCommit = [self commitEditingAndReturnError:NULL];
    if (delegate && didCommitSelector) {
        // - (void)editor:(id)editor didCommit:(BOOL)didCommit contextInfo:(void *)contextInfo
        dispatch_async(dispatch_get_main_queue(), ^{
            void (*didCommitImp)(id, SEL, id, BOOL, void *) = (void (*)(id, SEL, id, BOOL, void *))[delegate methodForSelector:didCommitSelector];
            if (didCommitImp)
                didCommitImp(delegate, didCommitSelector, self, didCommit, contextInfo);
        });
    }
}

#pragma mark SKNoteTypeSheetController delegate protocol

- (void)noteTypeSheetControllerNoteTypesDidChange {
    [self updateNoteFilterPredicate];
}

- (NSWindow *)windowForNoteTypeSheetController {
    return [self window];
}

#pragma mark SKPDFView delegate protocol

- (NSURL *)redirectRelativeLinkURL:(NSURL *)url {
    if (url && [url scheme] == nil && [[self document] fileURL])
        url = [[NSURL URLWithString:[url absoluteString] relativeToURL:[[self document] fileURL]] absoluteURL] ?: url;
    if ([url isFileURL] && [[[self document] fileType] isEqualToString:SKDocumentTypePDFBundle] && [url checkResourceIsReachableAndReturnError:NULL] == NO) {
        NSString *path = [url path];
        NSURL *docURL = [[self document] fileURL];
        NSString *docPath = [docURL path];
        NSURL *replaceURL = nil;
        if ([docPath hasSuffix:@"/"] == NO)
            docPath = [docPath stringByAppendingString:@"/"];
        if ([path hasPrefix:docPath]) {
            replaceURL = [[docURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:[path substringFromIndex:[docPath length]]];
            if ([replaceURL checkResourceIsReachableAndReturnError:NULL]) {
                url = replaceURL;
            } else if ([[url pathExtension] isCaseInsensitiveEqual:@"pdf"]) {
                replaceURL = [replaceURL URLReplacingPathExtension:@"pdfd"];
                if ([replaceURL checkResourceIsReachableAndReturnError:NULL])
                    url = replaceURL;
            }
        }
    }
    return url;
}

- (void)PDFViewOpenPDF:(PDFView *)aPDFView forRemoteGoToAction:(PDFActionRemoteGoTo *)action {
    NSURL *fileURL = [self redirectRelativeLinkURL:[action URL]];
    SKDocumentController *sdc = [NSDocumentController sharedDocumentController];
    Class docClass = [sdc documentClassForContentsOfURL:fileURL];
    if (docClass) {
        [sdc openDocumentWithContentsOfURL:fileURL display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
            if ([document isPDFDocument]) {
                NSUInteger pageIndex = [action pageIndex];
                if (pageIndex < [[document pdfDocument] pageCount]) {
                    PDFPage *page = [[document pdfDocument] pageAtIndex:pageIndex];
                    PDFDestination *dest = [[PDFDestination alloc] initWithPage:page atPoint:[action point]];
                    [[(SKMainDocument *)document pdfView] goToDestination:dest];
                }
            } else if (document == nil && error && [error isUserCancelledError] == NO) {
                [self presentError:error];
            }
        }];
    } else if (fileURL) {
        // fall back to just opening the file and ignore the destination
        [[NSWorkspace sharedWorkspace] openURL:fileURL];
    }
}

- (void)PDFViewWillClickOnLink:(PDFView *)aPDFView withURL:(NSURL *)url {
    SKDocumentController *sdc = [NSDocumentController sharedDocumentController];
    url = [self redirectRelativeLinkURL:url];
    if ([url isFileURL] && [sdc documentClassForContentsOfURL:url]) {
        [sdc openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){
            if (document == nil && error && [error isUserCancelledError] == NO)
                [self presentError:error];
        }];
    } else if ([url isSkimFileURL]) {
        [sdc openDocumentWithContentsOfURL:[url associatedFileURL] display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){
            if (document == nil && error && [error isUserCancelledError] == NO)
                [self presentError:error];
        }];
    } else if ([[url scheme] isCaseInsensitiveEqual:@"tel"]) {
        NSBeep();
    } else {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)PDFViewPerformFind:(PDFView *)aPDFView {
    [self showFindBar];
}

- (void)PDFViewPerformHideFind:(PDFView *)aPDFView {
    if ([[findController view] window])
        [findController remove:nil];
}

- (void)PDFViewPerformGoToPage:(PDFView *)aPDFView {
    [self doGoToPage:aPDFView];
}

- (void)PDFViewPerformPrint:(PDFView *)aPDFView {
    [[self document] printDocument:aPDFView];
}

- (BOOL)PDFView:(PDFView *)aPDFView performAction:(PDFAction *)action {
    if ([action isKindOfClass:[PDFActionGoTo class]] && ([NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagShift) {
        BOOL animating = NO;
        if ([secondaryPdfView superview] == nil) {
            animating = [NSView shouldShowSlideAnimation];
            [self toggleSplitPDF:nil];
        }
        if (animating) {
            [secondaryPdfView performSelector:@selector(performAction:) withObject:action afterDelay:0.25];
        } else {
            [secondaryPdfView performAction:action];
        }
        return YES;
    } else {
        return NO;
    }
}

- (void)PDFViewDidBeginEditing:(PDFView *)aPDFView {
    if (mwcFlags.isEditingPDF == NO && mwcFlags.isEditingTable == NO)
        [[self document] objectDidBeginEditing:(id)self];
    mwcFlags.isEditingPDF = YES;
}

- (void)PDFViewDidEndEditing:(PDFView *)aPDFView {
    if (mwcFlags.isEditingPDF && mwcFlags.isEditingTable == NO)
        [[self document] objectDidEndEditing:(id)self];
    mwcFlags.isEditingPDF = NO;
}

- (void)PDFView:(PDFView *)aPDFView editAnnotation:(PDFAnnotation *)annotation {
    [self showNote:annotation];
}

- (void)PDFView:(PDFView *)aPDFView showSnapshotAtPage:(PDFPage *)page forRect:(NSRect)rect scaleFactor:(CGFloat)scaleFactor autoFits:(BOOL)autoFits {
    SKSnapshotWindowController *swc = [self makeSnapshot];
    [swc displayPage:page rect:rect scaleFactor:scaleFactor autoFits:autoFits];
}

- (void)PDFView:(PDFView *)aPDFView didRotatePageAtIndex:(NSUInteger)idx by:(NSInteger)rotation {
    NSUndoManager *undoManager = [[self document] undoManager];
    [[undoManager prepareWithInvocationTarget:self] rotatePageAtIndex:idx by:-rotation];
    [undoManager setActionName:NSLocalizedString(@"Rotate Page", @"Undo action name")];
    [undoManager setActionIsDiscardable:YES];
    
    PDFPage *page = [[pdfView document] pageAtIndex:idx];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFPageBoundsDidChangeNotification
                                                        object:[pdfView document] userInfo:@{SKPDFPageActionKey:SKPDFPageActionRotate, SKPDFPagePageKey:page}];
}

- (NSUndoManager *)undoManagerForPDFView:(PDFView *)aPDFView {
    return [[self document] undoManager];
}

#pragma mark UI validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(createNewNote:)) {
        return [pdfView canSelectNote];
    } else if (action == @selector(editNote:)) {
        PDFAnnotation *annotation = [pdfView currentAnnotation];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [annotation isSkimNote] && [annotation isEditable];
    } else if (action == @selector(autoSizeNote:)) {
        PDFAnnotation *annotation = [pdfView currentAnnotation];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [annotation isResizable] && ([annotation isText] || [annotation isNote] || ([annotation isShape] && [[pdfView currentSelection] hasCharacters]));
    } else if (action == @selector(alignLeft:) || action == @selector(alignRight:) || action == @selector(alignCenter:)) {
        PDFAnnotation *annotation = [pdfView currentAnnotation];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [annotation isSkimNote] && [annotation isEditable] && [annotation isText];
    } else if (action == @selector(toggleHideNotes:)) {
        if ([pdfView hideNotes])
            [menuItem setTitle:NSLocalizedString(@"Show Notes", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Hide Notes", @"Menu item title")];
        return YES;
    } else if (action == @selector(changeDisplayTwoUp:)) {
        [menuItem setState:([pdfView displayMode] & kPDFDisplayTwoUp) == (PDFDisplayMode)[menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changeDisplayContinuous:)) {
        [menuItem setState:([pdfView displayMode] & kPDFDisplaySinglePageContinuous) == (PDFDisplayMode)[menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changeDisplayMode:)) {
        [menuItem setState: [pdfView extendedDisplayMode] == [menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changeDisplayDirection:)) {
        [menuItem setState:[pdfView displayDirection] == [menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(toggleDisplaysRTL:)) {
        [menuItem setState:[pdfView displaysRTL] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(toggleDisplaysAsBook:)) {
        [menuItem setState:[pdfView displaysAsBook] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(toggleDisplayPageBreaks:)) {
        [menuItem setState:[pdfView displaysPageBreaks] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changeDisplayBox:)) {
        [menuItem setState:[pdfView displayBox] == (PDFDisplayBox)[menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(delete:) || action == @selector(copy:) || action == @selector(cut:) || action == @selector(paste:) || action == @selector(alternatePaste:) || action == @selector(pasteAsPlainText:) || action == @selector(deselectAll:) || action == @selector(changeAnnotationMode:) || action == @selector(changeToolMode:)) {
        return [self hasOverview] == NO && [pdfView validateMenuItem:menuItem];
    } else if (action == @selector(doGoToNextPage:)) {
        return [pdfView canGoToNextPage];
    } else if (action == @selector(doGoToPreviousPage:) ) {
        return [pdfView canGoToPreviousPage];
    } else if (action == @selector(doGoToFirstPage:)) {
        return [pdfView canGoToFirstPage];
    } else if (action == @selector(doGoToLastPage:)) {
        return [pdfView canGoToLastPage];
    } else if (action == @selector(doGoToPage:)) {
        return [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(doGoBack:)) {
        return [pdfView canGoBack];
    } else if (action == @selector(doGoForward:)) {
        return [pdfView canGoForward];
    } else if (action == @selector(goToMarkedPage:)) {
        if (beforeMarkedPage.pageIndex != NSNotFound) {
            [menuItem setTitle:NSLocalizedString(@"Jump Back From Marked Page", @"Menu item title")];
            return YES;
        } else {
            [menuItem setTitle:NSLocalizedString(@"Go To Marked Page", @"Menu item title")];
            return markedPage.pageIndex != NSNotFound && markedPage.pageIndex != [[pdfView currentPage] pageIndex];
        }
    } else if (action == @selector(markPage:)) {
        return [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(doZoomIn:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [pdfView canZoomIn];
    } else if (action == @selector(doZoomOut:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [pdfView canZoomOut];
    } else if (action == @selector(doZoomToActualSize:)) {
        return [[self pdfDocument] isLocked] == NO && ([self interactionMode] == SKPresentationMode ? [presentationView autoScales] : ([pdfView autoScales] || fabs([pdfView scaleFactor] - 1.0) > 0.0));
    } else if (action == @selector(doZoomToPhysicalSize:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && ([pdfView autoScales] || fabs([pdfView physicalScaleFactor] - 1.0 ) > 0.001);
    } else if (action == @selector(doZoomToSelection:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && (NSIsEmptyRect([pdfView selectToolRect]) == NO || [pdfView toolMode] != SKToolModeSelect);
    } else if (action == @selector(doZoomToFit:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && [pdfView autoScales] == NO;
    } else if (action == @selector(alternateZoomToFit:)) {
        PDFDisplayMode displayMode = [pdfView extendedDisplayMode];
        if ((displayMode & kPDFDisplaySinglePageContinuous) != 0) {
            [menuItem setTitle:NSLocalizedString(@"Zoom To Height", @"Menu item title")];
        } else {
            [menuItem setTitle:NSLocalizedString(@"Zoom To Width", @"Menu item title")];
        }
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(doAutoScale:)) {
        return [[self pdfDocument] isLocked] == NO && ([self interactionMode] == SKPresentationMode ? [presentationView autoScales] == NO : [pdfView autoScales] == NO) && [self hasOverview] == NO;
    } else if (action == @selector(toggleAutoScale:)) {
        [menuItem setState:([self interactionMode] == SKPresentationMode ? [presentationView autoScales] : [pdfView autoScales]) ? NSControlStateValueOn : NSControlStateValueOff];
        return [[self pdfDocument] isLocked] == NO && [self hasOverview] == NO;
    } else if (action == @selector(rotateRight:) || action == @selector(rotateLeft:) || action == @selector(rotateAllRight:) || action == @selector(rotateAllLeft:)) {
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(cropAll:) || action == @selector(crop:) || action == @selector(autoCropAll:) || action == @selector(smartAutoCropAll:)) {
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(cropHalf:)) {
        PDFPage *page = [pdfView selectToolPage] ?: [pdfView currentPage];
        if (([page pageIndex] % 2))
            [menuItem setTitle:NSLocalizedString(@"Crop Even Pages", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Crop Odd Pages", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO && [[self pdfDocument] pageCount] > 1;
    } else if (action == @selector(resetCrop:)) {
        return mwcFlags.hasCropped && [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(autoSelectContent:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && [pdfView toolMode] == SKToolModeSelect;
    } else if (action == @selector(takeSnapshot:)) {
        return [[self pdfDocument] isLocked] == NO && [self hasOverview] == NO;
    } else if (action == @selector(toggleLeftSidePane:)) {
        if ([self leftSidePaneIsOpen])
            [menuItem setTitle:NSLocalizedString(@"Hide Contents Pane", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Contents Pane", @"Menu item title")];
        return YES;
    } else if (action == @selector(toggleRightSidePane:)) {
        if ([self rightSidePaneIsOpen])
            [menuItem setTitle:NSLocalizedString(@"Hide Notes Pane", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Notes Pane", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(changeLeftSidePaneState:)) {
        [menuItem setState:(SKLeftSidePaneState)mwcFlags.leftSidePaneState != (SKLeftSidePaneState)[menuItem tag] ? NSControlStateValueOff : [self displaysFindPane] == NO ? NSControlStateValueOn : NSControlStateValueMixed];
        return (SKLeftSidePaneState)[menuItem tag] == SKSidePaneStateThumbnail || [[pdfView document] outlineRoot];
    } else if (action == @selector(changeRightSidePaneState:)) {
        [menuItem setState:mwcFlags.rightSidePaneState == (SKRightSidePaneState)[menuItem tag] ? NSControlStateValueOn : NSControlStateValueOff];
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(changeFindPaneState:)) {
        [menuItem setState:(SKFindPaneState)mwcFlags.findPaneState != (SKFindPaneState)[menuItem tag] ? NSControlStateValueOff : [self displaysFindPane] ? NSControlStateValueOn : NSControlStateValueMixed];
        [menuItem setHidden:[[self searchString] length] == 0];
        return  [[self searchString] length] > 0;
    } else if (action == @selector(toggleNoteToolbar:)) {
        if ([noteToolbarController isVisible])
            [menuItem setTitle:NSLocalizedString(@"Hide Note Toolbar", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Note Toolbar", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(toggleOverview:)) {
        if ([self hasOverview])
            [menuItem setTitle:NSLocalizedString(@"Hide Overview", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Overview", @"Menu item title")];
        return YES;
    } else if (action == @selector(toggleSplitPDF:)) {
        if ([(NSView *)secondaryPdfView superview])
            [menuItem setTitle:NSLocalizedString(@"Hide Split PDF", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Split PDF", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(toggleStatusBar:)) {
        if ([statusBar isVisible])
            [menuItem setTitle:NSLocalizedString(@"Hide Status Bar", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Status Bar", @"Menu item title")];
        return [self interactionMode] == SKNormalMode || [self interactionMode] == SKFullScreenMode;
    } else if (action == @selector(searchPDF:)) {
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(toggleFullscreen:)) {
        if ([self interactionMode] == SKFullScreenMode)
            [menuItem setTitle:NSLocalizedString(@"Remove Full Screen", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Full Screen", @"Menu item title")];
        return [self canEnterFullscreen] || [self canExitFullscreen];
    } else if (action == @selector(togglePresentation:)) {
        if ([self interactionMode] == SKPresentationMode)
            [menuItem setTitle:NSLocalizedString(@"Remove Presentation", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Presentation", @"Menu item title")];
        return [self canEnterPresentation] || [self canExitPresentation];
    } else if (action == @selector(performFit:)) {
        return [self interactionMode] == SKNormalMode && [[self pdfDocument] isLocked] == NO && [self hasOverview] == NO;
    } else if (action == @selector(password:)) {
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] permissionsStatus] != kPDFDocumentPermissionsOwner;
    } else if (action == @selector(toggleReadingBar:)) {
        if ([[self pdfView] hasReadingBar])
            [menuItem setTitle:NSLocalizedString(@"Hide Reading Bar", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Reading Bar", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(togglePacer:)) {
        if ([[self pdfView] hasPacer])
            [menuItem setTitle:NSLocalizedString(@"Stop Pacer", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Start Pacer", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changePacerSpeed:)) {
        if ([menuItem tag] > 0) {
            CGFloat speed = [pdfView pacerSpeed];
            NSInteger s = 5 * MAX(0, (NSInteger)round(0.2 * speed) - 1) + [menuItem tag];
            [menuItem setTitle:[NSString stringWithFormat:@"%ld",(long)s]];
            [menuItem setState:(NSInteger)round(speed) == s ? NSControlStateValueOn : NSControlStateValueOff];
        }
        return YES;
    } else if (action == @selector(chooseTransition:)) {
        return [[self pdfDocument] pageCount] > 1;
    } else if (action == @selector(toggleCaseInsensitiveSearch:)) {
        [menuItem setState:mwcFlags.caseInsensitiveSearch ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(toggleWholeWordSearch:)) {
        [menuItem setState:mwcFlags.wholeWordSearch ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(toggleCaseInsensitiveFilter:)) {
        [menuItem setState:mwcFlags.caseInsensitiveFilter ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(toggleAutoResizeNoteRows:)) {
        [menuItem setState:mwcFlags.autoResizeNoteRows ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(toggleNewNoteRequiresSelection:)) {
        [menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:SKNewNoteRequiresSelectionKey] ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(toggleUpdateContentsFromEnclosedText:)) {
        NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:SKDisableUpdateContentsFromEnclosedTextKey];
        NSInteger option = [menuItem tag];
        [menuItem setState:value < option ? NSControlStateValueOn : NSControlStateValueOff];
        return option == 2 || value < 2;
    } else if (action == @selector(performFindPanelAction:)) {
        if ([self interactionMode] == SKPresentationMode)
            return NO;
        switch ([menuItem tag]) {
            case NSFindPanelActionShowFindPanel:
                return YES;
            case NSFindPanelActionNext:
            case NSFindPanelActionPrevious:
                return [[pdfView document] isFinding] == NO;
            case NSFindPanelActionSetFindString:
                return [[[self pdfView] currentSelection] hasCharacters];
            default:
                return NO;
        }
    } else if (action == @selector(centerSelectionInVisibleArea:)) {
        return [self interactionMode] != SKPresentationMode &&
               [[pdfView currentSelection] hasCharacters];
    } else if (action == @selector(toggleDisplayNoteBounds:)) {
        [menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayNoteBoundsKey] ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    } else if (action == @selector(toggleDisplayPageBounds:)) {
        [menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayPageBoundsKey] ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    }
    return YES;
}

#pragma mark Notification handlers

#define MAX_HIGHLIGHTS 5

- (void)handlePageChangedNotification:(NSNotification *)notification {
    // When the PDFView is changing scale, or when view settings change when switching fullscreen modes, 
    // a lot of wrong page change notifications may be send, which we better ignore. 
    // Full screen switching and zooming should not change the current page anyway.
    if ([pdfView isZooming] || mwcFlags.isSwitchingFullScreen || [pdfView needsRewind])
        return;
    
    PDFPage *page = [pdfView currentPage];
    NSUInteger pageIndex = [page pageIndex];
    
    if ([lastViewedPages count] == 0) {
        [lastViewedPages addPointer:(void *)pageIndex];
    } else if ((NSUInteger)[lastViewedPages pointerAtIndex:0] != pageIndex) {
        [lastViewedPages insertPointer:(void *)pageIndex atIndex:0];
        if ([lastViewedPages count] > MAX_HIGHLIGHTS)
            [lastViewedPages setCount:MAX_HIGHLIGHTS];
    }
    [self updatePageLabel];
    
    [self updateThumbnailSelectionHighlights];
    [self updateTocSelectionHighlights];
    
    if (beforeMarkedPage.pageIndex != NSNotFound && pageIndex != markedPage.pageIndex)
        beforeMarkedPage.pageIndex = NSNotFound;
    
    [self updateSubtitle];
    [self updateLeftStatus];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayPageBoundsKey])
        [self updateRightStatus];
    
    [[self document] setRecentInfoNeedsUpdate:YES];
}

- (void)handleDisplayBoxChangedNotification:(NSNotification *)notification {
    [self allThumbnailsNeedUpdate];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayPageBoundsKey])
        [self updateRightStatus];
}

- (void)handleSelectionOrMagnificationChangedNotification:(NSNotification *)notification {
    [self updateRightStatus];
}

- (void)setHasOutline:(BOOL)hasOutline forAnnotation:(PDFAnnotation *)annotation {
    SKNoteOutlineView *ov = rightSideController.noteOutlineView;
    NSInteger row = [ov rowForItem:annotation];
    NSUInteger column = [ov columnWithIdentifier:TYPE_COLUMNID];
    if (row != -1 && column != NSNotFound) {
        NSTableCellView *view = [ov viewAtColumn:column row:row makeIfNecessary:NO];
        if (view)
            [(SKAnnotationTypeImageView *)[view imageView] setHasOutline:hasOutline];
    }
}

- (void)handleCurrentAnnotationChangedNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [[notification userInfo] objectForKey:SKPDFViewAnnotationKey];
    SKNoteOutlineView *ov = rightSideController.noteOutlineView;
    
    if ([annotation isSkimNote])
        [self setHasOutline:NO forAnnotation:annotation];
    
    annotation = [pdfView currentAnnotation];
    if ([[self window] isMainWindow])
        [self updateUtilityPanels];
    if ([annotation isSkimNote]) {
        if ([[self selectedNotes] containsObject:annotation] == NO) {
            [ov selectRowIndexes:[NSIndexSet indexSetWithIndex:[ov rowForItem:annotation]] byExtendingSelection:NO];
        }
        [self setHasOutline:YES forAnnotation:annotation];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayNoteBoundsKey])
        [self updateRightStatus];
}

- (void)handleReadingBarDidChangeNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    PDFPage *page = [userInfo objectForKey:SKPDFViewPageKey];
    if (page)
        [self updateThumbnailAtPageIndex:[page pageIndex]];
}

- (void)handleWillRemoveDocumentNotification:(NSNotification *)notification {
    if ([[notification userInfo] objectForKey:SKDocumentControllerDocumentKey] == presentationNotesDocument)
        [self setPresentationNotesDocument:nil];
}

- (void)handleNoteViewFrameDidChangeNotification:(NSNotification *)notification {
    if (mwcFlags.autoResizeNoteRows) {
        if ([[notification object] inLiveResize]) {
            mwcFlags.noteRowHeightsNeedUpdate = YES;
        } else {
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:0.0];
            [rightSideController.noteOutlineView noteHeightOfRowsChanged];
            [NSAnimationContext beginGrouping];
        }
    }
}

- (void)handleNoteViewDidEndLiveResizeNotification:(NSNotification *)notification {
    if (mwcFlags.noteRowHeightsNeedUpdate && mwcFlags.autoResizeNoteRows) {
        [rightSideController.noteOutlineView noteHeightOfRowsChanged];
    }
}

- (void)handlePageLabelsChangedNotification:(NSNotification *)notification {
    [self updatePageLabels];
}

- (void)observeUndoManagerCheckpoint:(NSNotification *)notification {
    // Start the coalescing of note property changes over.
    undoGroupOldPropertiesPerNote = nil;
}

- (void)saveSidePaneWidths {
    if ([self interactionMode] == SKNormalMode && mwcFlags.isSwitchingFullScreen == NO) {
        [[NSUserDefaults standardUserDefaults] setFloat:[self leftSideWidth] forKey:SKLeftSidePaneWidthKey];
        [[NSUserDefaults standardUserDefaults] setFloat:[self rightSideWidth] forKey:SKRightSidePaneWidthKey];
    }
}

- (void)handleSplitviewDidResizeSubviewsNotification:(NSNotification *)notification {
    if ([self interactionMode] == SKNormalMode && mwcFlags.isSwitchingFullScreen == NO)
        [self performSelectorOnce:@selector(saveSidePaneWidths) afterDelay:0.0];
}

#pragma mark Observer registration

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    // PDFView
    [nc addObserver:self selector:@selector(handlePageChangedNotification:) 
                             name:PDFViewPageChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleSelectionOrMagnificationChangedNotification:) 
                             name:SKPDFViewSelectionChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleSelectionOrMagnificationChangedNotification:) 
                             name:SKPDFViewMagnificationChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleDisplayBoxChangedNotification:) 
                             name:PDFViewDisplayBoxChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleCurrentAnnotationChangedNotification:)
                             name:SKPDFViewCurrentAnnotationChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleReadingBarDidChangeNotification:) 
                             name:SKPDFViewReadingBarDidChangeNotification object:pdfView];
    //  UndoManager
    [nc addObserver:self selector:@selector(observeUndoManagerCheckpoint:)
                             name:NSUndoManagerCheckpointNotification object:[[self document] undoManager]];
    //  SKDocumentController
    [nc addObserver:self selector:@selector(handleWillRemoveDocumentNotification:)
                             name:SKDocumentControllerWillRemoveDocumentNotification object:nil];
    // PDFPage
    [nc addObserver:self selector:@selector(handlePageLabelsChangedNotification:)
                             name:SKPDFPageLabelsChangedNotification object:nil];
    // NSSplitView
    if ([[[self window] frameAutosaveName] length])
        [nc addObserver:self selector:@selector(handleSplitviewDidResizeSubviewsNotification:)
                   name:NSSplitViewDidResizeSubviewsNotification object:[splitViewController splitView]];
}

@end
