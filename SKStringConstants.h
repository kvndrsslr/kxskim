//
//  SKStringConstants.h
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

NS_ASSUME_NONNULL_BEGIN

extern NSString * const SKAutoCheckFileUpdateKey;
extern NSString * const SKAutoReloadFileUpdateKey;
extern NSString * const SKTeXEditorPresetKey;
extern NSString * const SKTeXEditorArgumentsKey;
extern NSString * const SKTeXEditorCommandKey;
extern NSString * const SKBackgroundColorKey;
extern NSString * const SKFullScreenBackgroundColorKey;
extern NSString * const SKDarkBackgroundColorKey;
extern NSString * const SKDarkFullScreenBackgroundColorKey;
extern NSString * const SKLastOpenFileNamesKey;
extern NSString * const SKOpenContentsPaneOnlyForTOCKey;
extern NSString * const SKOpenNotesPaneOnlyForNotesKey;
extern NSString * const SKLeftSidePaneWidthKey;
extern NSString * const SKRightSidePaneWidthKey;
extern NSString * const SKInitialWindowSizeOptionKey;
extern NSString * const SKReopenLastOpenFilesKey;
extern NSString * const SKRememberLastPageViewedKey;
extern NSString * const SKRememberSnapshotsKey;
extern NSString * const SKWriteLegacySkimNotesKey;
extern NSString * const SKWriteSkimNotesAsArchiveKey;
extern NSString * const SKAutoSaveSkimNotesKey;
extern NSString * const SKSnapshotsOnTopKey;
extern NSString * const SKSnapshotThumbnailSizeKey;
extern NSString * const SKThumbnailSizeKey;
extern NSString * const SKLastToolModeKey;
extern NSString * const SKLastAnnotationModeKey;
extern NSString * const SKLastSecondarySelectsTextKey;
extern NSString * const SKInterpolationQualityKey;
extern NSString * const SKReadingBarColorKey;
extern NSString * const SKReadingBarInvertKey;
extern NSString * const SKFreeTextNoteFontNameKey;
extern NSString * const SKFreeTextNoteFontSizeKey;
extern NSString * const SKAnchoredNoteFontNameKey;
extern NSString * const SKAnchoredNoteFontSizeKey;
extern NSString * const SKFreeTextNoteColorKey;
extern NSString * const SKAnchoredNoteColorKey;
extern NSString * const SKCircleNoteColorKey;
extern NSString * const SKSquareNoteColorKey;
extern NSString * const SKHighlightNoteColorKey;
extern NSString * const SKUnderlineNoteColorKey;
extern NSString * const SKStrikeOutNoteColorKey;
extern NSString * const SKLineNoteColorKey;
extern NSString * const SKInkNoteColorKey;
extern NSString * const SKCircleNoteInteriorColorKey;
extern NSString * const SKSquareNoteInteriorColorKey;
extern NSString * const SKLineNoteInteriorColorKey;
extern NSString * const SKFreeTextNoteFontColorKey;
extern NSString * const SKFreeTextNoteAlignmentKey;
extern NSString * const SKAnchoredNoteIconTypeKey;
extern NSString * const SKFreeTextNoteLineWidthKey;
extern NSString * const SKFreeTextNoteLineStyleKey;
extern NSString * const SKFreeTextNoteDashPatternKey;
extern NSString * const SKCircleNoteLineWidthKey;
extern NSString * const SKCircleNoteLineStyleKey;
extern NSString * const SKCircleNoteDashPatternKey;
extern NSString * const SKSquareNoteLineWidthKey;
extern NSString * const SKSquareNoteLineStyleKey;
extern NSString * const SKSquareNoteDashPatternKey;
extern NSString * const SKLineNoteLineWidthKey;
extern NSString * const SKLineNoteLineStyleKey;
extern NSString * const SKLineNoteDashPatternKey;
extern NSString * const SKLineNoteStartLineStyleKey;
extern NSString * const SKLineNoteEndLineStyleKey;
extern NSString * const SKInkNoteLineWidthKey;
extern NSString * const SKInkNoteLineStyleKey;
extern NSString * const SKInkNoteDashPatternKey;
extern NSString * const SKDefaultNoteWidthKey;
extern NSString * const SKDefaultNoteHeightKey;
extern NSString * const SKSwatchColorsKey;
extern NSString * const SKDefaultPDFDisplaySettingsKey;
extern NSString * const SKDefaultFullScreenPDFDisplaySettingsKey;
extern NSString * const SKUseSettingsFromPDFKey;
extern NSString * const SKHideWindowTitleBarKey;
extern NSString * const SKShowStatusBarKey;
extern NSString * const SKShowBookmarkStatusBarKey;
extern NSString * const SKShowNotesStatusBarKey;
extern NSString * const SKEnableAppleRemoteKey;
extern NSString * const SKAppleRemoteSwitchIndicationTimeoutKey;
extern NSString * const SKReadMissingNotesFromSkimFileOptionKey;
extern NSString * const SKReadNonMissingNotesFromSkimFileOptionKey;
extern NSString * const SKSavePasswordOptionKey;
extern NSString * const SKPresentationNavigationOptionKey;
extern NSString * const SKAutoHidePresentationContentsKey;
extern NSString * const SKUseNormalLevelForPresentationKey;
extern NSString * const SKPreferExternalDisplayForPresentationKey;
extern NSString * const SKAutoOpenDownloadsWindowKey;
extern NSString * const SKAutoRemoveFinishedDownloadsKey;
extern NSString * const SKAutoCloseDownloadsWindowKey;
extern NSString * const SKShouldSetCreatorCodeKey;
extern NSString * const SKTableFontSizeKey;
extern NSString * const SKSequentialPageNumberingKey;
extern NSString * const SKUseUserNameKey;
extern NSString * const SKUserNameKey;
extern NSString * const SKDisableModificationDateKey;
extern NSString * const SKDisableAnimationsKey;
extern NSString * const SKDisableUpdateContentsFromEnclosedTextKey;
extern NSString * const SKNewNoteRequiresSelectionKey;
extern NSString * const SKCaseInsensitiveSearchKey;
extern NSString * const SKWholeWordSearchKey;
extern NSString * const SKCaseInsensitiveNoteSearchKey;
extern NSString * const SKCaseInsensitiveFilterKey;
extern NSString * const SKCaseInsensitiveFindKey;
extern NSString * const SKHighlightAllSearchResultsKey;
extern NSString * const SKSpellCheckingEnabledKey;
extern NSString * const SKGrammarCheckingEnabledKey;
extern NSString * const SKDownloadsDirectoryKey;
extern NSString * const SKDisableSearchAfterSpotlighKey;
extern NSString * const SKDisplayNoteBoundsKey;
extern NSString * const SKDisplayPageBoundsKey;
extern NSString * const SKDisableHistoryHighlightsKey;
extern NSString * const SKInvertColorsInDarkModeKey;
extern NSString * const SKSepiaToneKey;
extern NSString * const SKWhitePointKey;
extern NSString * const SKPresentationInkNoteColorKey;

NS_ASSUME_NONNULL_END
