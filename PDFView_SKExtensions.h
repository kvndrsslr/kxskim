//
//  PDFView_SKExtensions.h
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSPoint SKUnspecifiedPoint;

typedef struct _SKDestination {
    NSUInteger pageIndex;
    NSPoint point;
} SKDestination;

@interface PDFView (SKExtensions) <NSDraggingSource>

@property (nonatomic) CGFloat physicalScaleFactor;
@property (nonatomic, readonly) NSScrollView *embeddedScrollView;
@property (nonatomic, readonly) NSArray<PDFPage *> *displayedPages;
@property (nonatomic, readonly) NSRect unobscuredContentRect;

- (BOOL)isPageAtIndexDisplayed:(NSUInteger)pageIndex;
- (BOOL)isPageAtIndexesDisplayed:(NSIndexSet *)pageIndexes;

- (void)doPdfsyncWithEvent:(NSEvent *)theEvent;
- (void)doDragContentWithEvent:(NSEvent *)theEvent;
- (BOOL)doDragSelectedTextWithEvent:(NSEvent *)theEvent;

- (nullable PDFPage *)pageAndPoint:(NSPoint * _Nullable)point forEvent:(NSEvent *)event nearest:(BOOL)nearest;

- (SKDestination)currentSKDestination:(BOOL)invalidatePointWhenRotated;
- (void)goToSKDestination:(SKDestination)destination;

- (void)goAndScrollToPage:(PDFPage *)page;

- (CGFloat)horizontalScrollOriginForPage:(PDFPage *)page;

- (NSRect)boundsIncludingMarginsForPage:(PDFPage *)page;

- (void)setCursorForMouse:(nullable NSEvent *)event;

@property (class, nonatomic, readonly) NSColor *defaultBackgroundColor;
@property (class, nonatomic, readonly) NSColor *defaultFullScreenBackgroundColor;

@end

NS_ASSUME_NONNULL_END
