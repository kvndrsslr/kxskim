//
//  SKStringConstants.m
//  Skim
//
//  Created by Michael McCracken on 1/5/07.
/*
 This software is Copyright (c) 2007
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

#import "SKStringConstants.h"

NSString * const SKAutoCheckFileUpdateKey = @"SKAutoCheckFileUpdate";
NSString * const SKAutoReloadFileUpdateKey = @"SKAutoReloadFileUpdate";
NSString * const SKTeXEditorPresetKey = @"SKTeXEditorPreset";
NSString * const SKTeXEditorArgumentsKey = @"SKTeXEditorArguments";
NSString * const SKTeXEditorCommandKey = @"SKTeXEditorCommand";
NSString * const SKBackgroundColorKey = @"SKBackgroundColor";
NSString * const SKFullScreenBackgroundColorKey = @"SKFullScreenBackgroundColor";
NSString * const SKDarkBackgroundColorKey = @"SKDarkBackgroundColor";
NSString * const SKDarkFullScreenBackgroundColorKey = @"SKDarkFullScreenBackgroundColor";
NSString * const SKLastOpenFileNamesKey = @"SKLastOpenFileNames";
NSString * const SKOpenContentsPaneOnlyForTOCKey = @"SKOpenContentsPaneOnlyForTOC";
NSString * const SKOpenNotesPaneOnlyForNotesKey = @"SKOpenNotesPaneOnlyForNotes";
NSString * const SKLeftSidePaneWidthKey = @"SKLeftSidePaneWidth";
NSString * const SKRightSidePaneWidthKey = @"SKRightSidePaneWidth";
NSString * const SKInitialWindowSizeOptionKey = @"SKInitialWindowSizeOption";
NSString * const SKReopenLastOpenFilesKey = @"SKReopenLastOpenFiles";
NSString * const SKRememberLastPageViewedKey = @"SKRememberLastPageViewed";
NSString * const SKRememberSnapshotsKey = @"SKRememberSnapshots";
NSString * const SKWriteLegacySkimNotesKey = @"SKWriteLegacySkimNotes";
NSString * const SKWriteSkimNotesAsArchiveKey = @"SKWriteSkimNotesAsArchive";
NSString * const SKAutoSaveSkimNotesKey = @"SKAutoSaveSkimNotes";
NSString * const SKSnapshotsOnTopKey = @"SKSnapshotsOnTop";
NSString * const SKSnapshotThumbnailSizeKey = @"SKSnapshotThumbnailSize";
NSString * const SKThumbnailSizeKey = @"SKThumbnailSize";
NSString * const SKLastToolModeKey = @"SKLastToolMode";
NSString * const SKLastAnnotationModeKey = @"SKLastAnnotationMode";
NSString * const SKLastSecondarySelectsTextKey = @"SKLastSecondarySelectsText";
NSString * const SKInterpolationQualityKey = @"SKInterpolationQuality";
NSString * const SKReadingBarColorKey = @"SKReadingBarColor";
NSString * const SKReadingBarInvertKey = @"SKReadingBarInvert";
NSString * const SKFreeTextNoteFontNameKey = @"SKFreeTextNoteFontName";
NSString * const SKFreeTextNoteFontSizeKey = @"SKFreeTextNoteFontSize";
NSString * const SKAnchoredNoteFontNameKey = @"SKAnchoredNoteFontName";
NSString * const SKAnchoredNoteFontSizeKey = @"SKAnchoredNoteFontSize";
NSString * const SKFreeTextNoteColorKey = @"SKFreeTextNoteColor";
NSString * const SKAnchoredNoteColorKey = @"SKAnchoredNoteColor";
NSString * const SKCircleNoteColorKey = @"SKCircleNoteColor";
NSString * const SKSquareNoteColorKey = @"SKSquareNoteColor";
NSString * const SKHighlightNoteColorKey = @"SKHighlightNoteColor";
NSString * const SKUnderlineNoteColorKey = @"SKUnderlineNoteColor";
NSString * const SKStrikeOutNoteColorKey = @"SKStrikeOutNoteColor";
NSString * const SKLineNoteColorKey = @"SKLineNoteColor";
NSString * const SKInkNoteColorKey = @"SKInkNoteColor";
NSString * const SKCircleNoteInteriorColorKey = @"SKCircleNoteInteriorColor";
NSString * const SKSquareNoteInteriorColorKey = @"SKSquareNoteInteriorColor";
NSString * const SKLineNoteInteriorColorKey = @"SKLineNoteInteriorColor";
NSString * const SKFreeTextNoteFontColorKey = @"SKFreeTextNoteFontColor";
NSString * const SKFreeTextNoteAlignmentKey = @"SKFreeTextNoteAlignment";
NSString * const SKFreeTextNoteLineWidthKey = @"SKFreeTextNoteLineWidth";
NSString * const SKAnchoredNoteIconTypeKey = @"SKAnchoredNoteIconType";
NSString * const SKFreeTextNoteLineStyleKey = @"SKFreeTextNoteLineStyle";
NSString * const SKFreeTextNoteDashPatternKey = @"SKFreeTextNoteDashPattern";
NSString * const SKCircleNoteLineWidthKey = @"SKCircleNoteLineWidth";
NSString * const SKCircleNoteLineStyleKey = @"SKCircleNoteLineStyle";
NSString * const SKCircleNoteDashPatternKey = @"SKCircleNoteDashPattern";
NSString * const SKSquareNoteLineWidthKey = @"SKSquareNoteLineWidth";
NSString * const SKSquareNoteLineStyleKey = @"SKSquareNoteLineStyle";
NSString * const SKSquareNoteDashPatternKey = @"SKSquareNoteDashPattern";
NSString * const SKLineNoteLineWidthKey = @"SKLineNoteLineWidth";
NSString * const SKLineNoteDashPatternKey = @"SKLineNoteDashPattern";
NSString * const SKLineNoteLineStyleKey = @"SKLineNoteLineStyle";
NSString * const SKLineNoteStartLineStyleKey = @"SKLineNoteStartLineStyle";
NSString * const SKLineNoteEndLineStyleKey = @"SKLineNoteEndLineStyle";
NSString * const SKInkNoteLineWidthKey = @"SKInkNoteLineWidth";
NSString * const SKInkNoteDashPatternKey = @"SKInkNoteDashPattern";
NSString * const SKInkNoteLineStyleKey = @"SKInkNoteLineStyle";
NSString * const SKDefaultNoteWidthKey = @"SKDefaultNoteWidth";
NSString * const SKDefaultNoteHeightKey = @"SKDefaultNoteHeight";
NSString * const SKSwatchColorsKey = @"SKSwatchColors";
NSString * const SKDefaultPDFDisplaySettingsKey = @"SKDefaultPDFDisplaySettings";
NSString * const SKDefaultFullScreenPDFDisplaySettingsKey = @"SKDefaultFullScreenPDFDisplaySettings";
NSString * const SKUseSettingsFromPDFKey = @"SKUseSettingsFromPDF";
NSString * const SKHideWindowTitleBarKey = @"SKHideWindowTitleBar";
NSString * const SKShowStatusBarKey = @"SKShowStatusBar";
NSString * const SKShowBookmarkStatusBarKey = @"SKShowBookmarkStatusBar";
NSString * const SKShowNotesStatusBarKey = @"SKShowNotesStatusBar";
NSString * const SKEnableAppleRemoteKey = @"SKEnableAppleRemote";
NSString * const SKAppleRemoteSwitchIndicationTimeoutKey = @"SKAppleRemoteSwitchIndicationTimeout";
NSString * const SKReadMissingNotesFromSkimFileOptionKey = @"SKReadMissingNotesFromSkimFileOption";
NSString * const SKReadNonMissingNotesFromSkimFileOptionKey = @"SKReadNonMissingNotesFromSkimFileOption";
NSString * const SKSavePasswordOptionKey = @"SKSavePasswordOption";
NSString * const SKPresentationNavigationOptionKey = @"SKPresentationNavigationOption";
NSString * const SKAutoHidePresentationContentsKey = @"SKAutoHidePresentationContents";
NSString * const SKUseNormalLevelForPresentationKey = @"SKUseNormalLevelForPresentation";
NSString * const SKPreferExternalDisplayForPresentationKey = @"SKPreferExternalDisplayForPresentation";
NSString * const SKAutoOpenDownloadsWindowKey = @"SKAutoOpenDownloadsWindow";
NSString * const SKAutoRemoveFinishedDownloadsKey = @"SKAutoRemoveFinishedDownloads";
NSString * const SKAutoCloseDownloadsWindowKey = @"SKAutoCloseDownloadsWindow";
NSString * const SKShouldSetCreatorCodeKey = @"SKShouldSetCreatorCode";
NSString * const SKTableFontSizeKey = @"SKTableFontSize";
NSString * const SKSequentialPageNumberingKey = @"SKSequentialPageNumbering";
NSString * const SKUseUserNameKey = @"SKUseUserName";
NSString * const SKUserNameKey = @"SKUserName";
NSString * const SKDisableModificationDateKey = @"SKDisableModificationDate";
NSString * const SKDisableAnimationsKey = @"SKDisableAnimations";
NSString * const SKDisableUpdateContentsFromEnclosedTextKey = @"SKDisableUpdateContentsFromEnclosedText";
NSString * const SKNewNoteRequiresSelectionKey = @"SKNewNoteRequiresSelection";
NSString * const SKCaseInsensitiveSearchKey = @"SKCaseInsensitiveSearch";
NSString * const SKWholeWordSearchKey = @"SKWholeWordSearch";
NSString * const SKCaseInsensitiveNoteSearchKey = @"SKCaseInsensitiveNoteSearch";
NSString * const SKCaseInsensitiveFilterKey = @"SKCaseInsensitiveFilter";
NSString * const SKCaseInsensitiveFindKey = @"SKCaseInsensitiveFind";
NSString * const SKHighlightAllSearchResultsKey = @"SKHighlightAllSearchResults";
NSString * const SKSpellCheckingEnabledKey = @"SKSpellCheckingEnabled";
NSString * const SKGrammarCheckingEnabledKey = @"SKGrammarCheckingEnabled";
NSString * const SKDownloadsDirectoryKey = @"SKDownloadsDirectory";
NSString * const SKDisableSearchAfterSpotlighKey = @"SKDisableSearchAfterSpotligh";
NSString * const SKDisplayNoteBoundsKey = @"SKDisplayNoteBounds";
NSString * const SKDisplayPageBoundsKey = @"SKDisplayPageBounds";
NSString * const SKDisableHistoryHighlightsKey = @"SKDisableHistoryHighlights";
NSString * const SKInvertColorsInDarkModeKey = @"SKInvertColorsInDarkMode";
NSString * const SKSepiaToneKey = @"SKSepiaTone";
NSString * const SKWhitePointKey = @"SKWhitePoint";
NSString * const SKPresentationInkNoteColorKey = @"SKPresentationInkNoteColor";
