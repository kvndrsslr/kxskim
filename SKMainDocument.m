//
//  SKMainDocument.m
//  Skim
//
//  Created by Michael McCracken on 12/5/06.
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

#import "SKMainDocument.h"
#import <Quartz/Quartz.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SkimNotes/SkimNotes.h>
#import "SKMainWindowController.h"
#import "SKMainWindowController_Actions.h"
#import "SKMainWindowController_FullScreen.h"
#import "SKPDFDocument.h"
#import "PDFAnnotation_SKExtensions.h"
#import "SKConversionProgressController.h"
#import "SKFindController.h"
#import "NSUserDefaultsController_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKPDFView.h"
#import "SKTransitionInfo.h"
#import "SKTransitionController.h"
#import "SKNoteWindowController.h"
#import "SKPDFSynchronizer.h"
#import "NSString_SKExtensions.h"
#import "SKDocumentController.h"
#import "SKTemplateParser.h"
#import "PDFSelection_SKExtensions.h"
#import "NSFileManager_SKExtensions.h"
#import "SKFDFParser.h"
#import "NSData_SKExtensions.h"
#import "SKProgressController.h"
#import "NSView_SKExtensions.h"
#import "SKKeychain.h"
#import "SKBookmarkController.h"
#import "PDFPage_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "SKSnapshotWindowController.h"
#import "NSDocument_SKExtensions.h"
#import "SKApplication.h"
#import "SKTextFieldSheetController.h"
#import "NSWindowController_SKExtensions.h"
#import "SKSyncPreferences.h"
#import "NSScreen_SKExtensions.h"
#import "NSURL_SKExtensions.h"
#import "SKFileUpdateChecker.h"
#import "NSError_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import "SKPrintAccessoryController.h"
#import "SKTemporaryData.h"
#import "SKTemplateManager.h"
#import "SKExportAccessoryController.h"
#import "SKFileShare.h"
#import "SKAnimatedBorderlessWindow.h"
#import "PDFOutline_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "SKLine.h"
#import "NSPasteboard_SKExtensions.h"
#import "NSPointerFunctions_SKExtensions.h"

#define BUNDLE_DATA_FILENAME @"data"
#define PRESENTATION_OPTIONS_KEY @"net_sourceforge_skim-app_presentation_options"
#define OPEN_META_TAGS_KEY @"com.apple.metadata:kMDItemOMUserTags"
#define OPEN_META_RATING_KEY @"com.apple.metadata:kMDItemStarRating"

#define SKIM_NOTES_PREFIX @"net_sourceforge_skim-app"

NSNotificationName const SKSkimFileDidSaveNotification = @"SKSkimFileDidSaveNotification";

#define SKLastExportedTypeKey @"SKLastExportedType"
#define SKLastExportedOptionKey @"SKLastExportedOption"

#define PAGETRANSITIONS_KEY @"pageTransitions"

#define NOTIFYPATH_KEY       @"notifyPath"
#define WANTSUPDATECHECK_KEY @"wantsUpdateCheck"
#define CALLBACK_KEY         @"callback"

#define SOURCEURL_KEY   @"sourceURL"
#define TARGETURL_KEY   @"targetURL"
#define EMAIL_KEY       @"email"

#define SKPresentationOptionsKey    @"PresentationOptions"
#define SKTagsKey                   @"Tags"
#define SKRatingKey                 @"Rating"

static NSString *SKPDFPasswordServiceName = @"Skim PDF password";

enum {
    SKExportOptionDefault,
    SKExportOptionWithoutNotes,
    SKExportOptionWithEmbeddedNotes,
};

enum {
   SKArchiveDiskImageMask = 1,
   SKArchiveEmailMask = 2,
};

enum {
    SKOptionAsk = -1,
    SKOptionNever = 0,
    SKOptionAlways = 1
};

@interface PDFAnnotation (SKPrivateDeclarations)
- (void)setPage:(PDFPage *)newPage;
@end

@interface PDFDocument (SKPrivateDeclarations)
- (NSString *)passwordUsedForUnlocking;
@end

@interface SKMainDocument ()

- (void)tryToUnlockDocument:(PDFDocument *)document;

@end

#pragma mark -

@implementation SKMainDocument

@synthesize primaryWindowController;
@dynamic pdfDocument, pdfView, synchronizer, snapshots, presentationOptions, tags, rating, notes, currentPage, activeNote, richText, selectionSpecifier, selectionQDRect, selectionPage, pdfViewSettings;

+ (BOOL)isPDFDocument { return YES; }

- (void)dealloc {
    // shouldn't need this here, but better be safe
    if (fileUpdateChecker) {
        SKENSURE_MAIN_THREAD(
            [fileUpdateChecker terminate];
            [synchronizer terminate];
        );
        fileUpdateChecker = nil;
    }
}

- (void)makeWindowControllers{
    if (primaryWindowController == nil) {
        primaryWindowController = [[SKMainWindowController alloc] init];
        [primaryWindowController setShouldCloseDocument:YES];
        [self addWindowController:primaryWindowController];
    }
}

- (void)updateChangeCount:(NSDocumentChangeType)change {
    if ((change & NSChangeDiscardable) == 0)
        [super updateChangeCount:change];
}

- (void)setDataFromTmpData {
    PDFDocument *pdfDoc = [tmpData pdfDocument];
    
    mdFlags.needsPasswordToConvert = [pdfDoc allowsSaving] == NO || [pdfDoc allowsNotes] == NO;
    
    [self tryToUnlockDocument:pdfDoc];
    
    [[self undoManager] disableUndoRegistration];
    
    [[self primaryWindowController] setPdfDocument:pdfDoc addAnnotationsWithProperties:[tmpData noteDicts]];
    
    [self setPresentationOptions:[tmpData presentationOptions]];
    
    [[self primaryWindowController] setTags:[tmpData openMetaTags]];
    
    [[self primaryWindowController] setRating:[tmpData openMetaRating]];
    
    [[self undoManager] enableUndoRegistration];
    
    tmpData = nil;
}

// this is called by the window controller even though we are not te owner
- (void)windowControllerDidLoadNib:(NSWindowController *)aController{
    [self setDataFromTmpData];
    
    fileUpdateChecker = [[SKFileUpdateChecker alloc] initForDocument:self];
    // the file update checker starts disabled, setting enabled will start checking if it should
    [fileUpdateChecker setEnabled:YES];
    
    [self setRecentInfoNeedsUpdate:YES];
}

- (void)showWindows{
    if ([[self primaryWindowController] isWindowLoaded] && [[[self primaryWindowController] window] isVisible]) {
        for (NSWindowController *wc in [self windowControllers]) {
            if ([[wc window] isVisible])
                [wc showWindow:nil];
        }
    } else {
        [super showWindows];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKDocumentDidShowNotification object:self];
    }
}

- (void)removeWindowController:(NSWindowController *)windowController {
    if ([windowController isEqual:primaryWindowController])
        primaryWindowController = nil;
    [super removeWindowController:windowController];
}

- (void)saveRecentDocumentInfo {
    if ([[primaryWindowController window] delegate] == nil)
        return;
    NSURL *fileURL = [self fileURL];
    NSUInteger pageIndex = [[[self pdfView] currentPage] pageIndex];
    NSArray *snapshots = [[[self primaryWindowController] snapshots] valueForKey:SKSnapshotCurrentSetupKey];
    if ([[SKBookmarkController sharedBookmarkController] addRecentDocumentForURL:fileURL pageIndex:pageIndex snapshots:[snapshots count] > 0 ? snapshots : nil])
        [self setRecentInfoNeedsUpdate:NO];
}

- (void)applySetup:(NSDictionary *)setup {
    if ([self primaryWindowController] == nil)
        [self makeWindowControllers];
    [[self primaryWindowController] setCurrentSetup:setup];
}

- (void)applyOptions:(NSDictionary *)options {
    NSInteger page = [[options objectForKey:@"page"] integerValue];
    NSString *searchString = [options objectForKey:@"search"];
    NSMutableDictionary *settings = [options mutableCopy];
    [settings removeObjectsForKeys:@[@"page", @"point", @"search"]];
    if ([settings count]) {
        SKPDFView *pdfView = [self pdfView];
        if (page == 0 && [[pdfView currentPage] pageIndex] > 0)
            [pdfView setDisplaySettingsAndRewind:settings];
        else
            [pdfView setDisplaySettings:settings];
    }
    if (page > 0) {
        SKPDFView *pdfView = [self pdfView];
        page = MIN(page, (NSInteger)[[pdfView document] pageCount]);
        NSString *pointString = [options objectForKey:@"point"];
        if ([pointString length] > 0) {
            SKDestination dest;
            if ([pointString hasPrefix:@"{"] == NO)
                pointString = [NSString stringWithFormat:@"{%@}", pointString];
            dest.pageIndex = page - 1;
            dest.point = NSPointFromString(pointString);
            [pdfView goToSKDestination:dest];
        } else if ((NSInteger)[[pdfView currentPage] pageIndex] != page) {
            [pdfView goAndScrollToPage:[[pdfView document] pageAtIndex:page - 1]];
        }
    }
    if ([searchString length] > 0) {
        [[self primaryWindowController] setSearchString:searchString];
    }
}

- (NSInteger)definitiveOption:(NSInteger)option usingMessageText:(NSString *)messageText informativeText:(NSString *)informativeText {
    if (option == SKOptionAsk) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:messageText];
        [alert setInformativeText:informativeText];
        [[alert addButtonWithTitle:NSLocalizedString(@"Yes", @"Button title")] setTag:SKOptionAlways];
        [[alert addButtonWithTitle:NSLocalizedString(@"No", @"Button title")] setTag:SKOptionNever];
        option = [alert runModal];
    }
    return option;
}

- (BOOL)shouldDiscontinueAfterReadNotesError:(NSError *)error fromURL:(NSURL *)aURL {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"Unable to Read Notes", @"Message in alert dialog")];
    [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Skim was not able to read the notes at %@. %@ Do you want to continue to open the PDF document anyway?", @"Informative text in alert dialog"), [[aURL path] stringByAbbreviatingWithTildeInPath], [error localizedDescription]]];
    [alert addButtonWithTitle:NSLocalizedString(@"No", @"Button title")];
    [alert addButtonWithTitle:NSLocalizedString(@"Yes", @"Button title")];
    return [alert runModal] == NSAlertFirstButtonReturn;
}

- (SKInteractionMode)interactionMode {
    return [[self primaryWindowController] interactionMode];
}

- (void)setInteractionMode:(SKInteractionMode)mode {
    if (mode == SKNormalMode) {
        if ([[self primaryWindowController] canExitFullscreen])
            [[self primaryWindowController] exitFullscreen];
        else if ([[self primaryWindowController] canExitPresentation])
            [[self primaryWindowController] exitPresentation];
    } else if (mode == SKFullScreenMode) {
        if ([[self primaryWindowController] canEnterFullscreen])
            [[self primaryWindowController] enterFullscreen];
    } else if (mode == SKPresentationMode) {
        if ([[self primaryWindowController] canEnterPresentation])
            [[self primaryWindowController] enterPresentation];
    }
}

- (BOOL)canExitPresentation {
    return [[self primaryWindowController] canExitPresentation];
}

#pragma mark Writing

- (NSString *)fileType {
    mdFlags.gettingFileType = YES;
    NSString *fileType = [super fileType];
    mdFlags.gettingFileType = NO;
    return fileType;
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation {
    if (mdFlags.gettingFileType)
        return [super writableTypesForSaveOperation:saveOperation];
    NSMutableArray *writableTypes = [[super writableTypesForSaveOperation:saveOperation] mutableCopy];
    NSString *type = [self fileType];
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    if ([ws type:type conformsToType:SKDocumentTypeEncapsulatedPostScript] == NO)
        [writableTypes removeObject:SKDocumentTypeEncapsulatedPostScript];
    else
        [writableTypes removeObject:SKDocumentTypePostScript];
    if ([ws type:type conformsToType:SKDocumentTypePostScript] == NO)
        [writableTypes removeObject:SKDocumentTypePostScript];
    if ([ws type:type conformsToType:SKDocumentTypeDVI] == NO)
        [writableTypes removeObject:SKDocumentTypeDVI];
    if ([ws type:type conformsToType:SKDocumentTypeXDV] == NO)
        [writableTypes removeObject:SKDocumentTypeXDV];
    if (saveOperation == NSSaveToOperation) {
        [writableTypes addObjectsFromArray:[[SKTemplateManager sharedManager] customTemplateTypes]];
    }
    return writableTypes;
}

- (NSString *)fileNameExtensionForType:(NSString *)typeName saveOperation:(NSSaveOperationType)saveOperation {
    return [super fileNameExtensionForType:typeName saveOperation:saveOperation] ?: [[SKTemplateManager sharedManager] fileNameExtensionForTemplateType:typeName];
}

- (BOOL)canAttachNotesForType:(NSString *)typeName {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    return ([ws type:typeName conformsToType:SKDocumentTypePDF] || 
            [ws type:typeName conformsToType:SKDocumentTypePostScript] || 
            [ws type:typeName conformsToType:SKDocumentTypeDVI] || 
            [ws type:typeName conformsToType:SKDocumentTypeXDV]);
}

- (NSInteger)exportOption {
    return mdFlags.exportOption;
}

- (void)setExportOption:(NSInteger)option {
    mdFlags.exportOption = option;
}

- (NSString *)fileTypeFromLastRunSavePanel {
    return [exportAccessoryController selectedFileType] ?: [super fileTypeFromLastRunSavePanel];
}

- (void)changeExportType:(id)sender {
    NSString *type = [exportAccessoryController selectedFileType];
    if (@available(macOS 11.0, *))
        [exportAccessoryController setAllowedFileType:type];
    else
        [exportAccessoryController setAllowedFileType:[self fileNameExtensionForType:type saveOperation:NSSaveToOperation]];
    if ([self canAttachNotesForType:type] == NO) {
        [exportAccessoryController setHasExportOptions:NO];
    } else {
        [exportAccessoryController setHasExportOptions:YES];
        if ([[NSWorkspace sharedWorkspace] type:type conformsToType:SKDocumentTypePDF] && ([[self pdfDocument] isLocked] == NO && [[self pdfDocument] allowsSaving])) {
            [exportAccessoryController setAllowsEmbeddedOption:YES];
        } else {
            [exportAccessoryController setAllowsEmbeddedOption:NO];
            if (mdFlags.exportOption == SKExportOptionWithEmbeddedNotes)
                [self setExportOption:SKExportOptionDefault];
        }
    }
}

- (BOOL)shouldRunSavePanelWithAccessoryView {
    return [super shouldRunSavePanelWithAccessoryView] && mdFlags.exportUsingPanel == 0;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel {
    BOOL success = [super prepareSavePanel:savePanel];
    if (success && mdFlags.exportUsingPanel) {
        NSString *lastExportedType = [[NSUserDefaults standardUserDefaults] stringForKey:SKLastExportedTypeKey];
        NSInteger lastExportedOption = [[NSUserDefaults standardUserDefaults] integerForKey:SKLastExportedOptionKey];
        
        mdFlags.exportOption = lastExportedOption;
        
        exportAccessoryController = [[SKExportAccessoryController alloc] init];
        [exportAccessoryController setRepresentedObject:self];
        [exportAccessoryController setSavePanel:savePanel];
        NSView *accessoryView = [exportAccessoryController view];
        
        NSPopUpButton *formatPopUpButton = [exportAccessoryController formatPopUpButton];
        NSDocumentController *controller = [NSDocumentController sharedDocumentController];
        for (NSString *type in [self writableTypesForSaveOperation:NSSaveToOperation]) {
            [formatPopUpButton addItemWithTitle:[controller displayNameForType:type]];
            [[formatPopUpButton lastItem] setRepresentedObject:type];
        }
        [formatPopUpButton setAction:@selector(changeExportType:)];
        [formatPopUpButton setTarget:self];
        [savePanel setAccessoryView:accessoryView];
        
        NSInteger idx = lastExportedType ? [formatPopUpButton indexOfItemWithRepresentedObject:lastExportedType] : -1;
        if (idx == -1) {
            idx = [formatPopUpButton indexOfItemWithRepresentedObject:[self fileType]];
            [self setExportOption:SKExportOptionDefault];
        }
        [formatPopUpButton selectItemAtIndex:MAX(idx, 0)];
        // update the last selected type and option view
        [self changeExportType:formatPopUpButton];
    }
    return success;
}

- (void)document:(NSDocument *)doc didSaveUsingPanel:(BOOL)didSave contextInfo:(void *)contextInfo {
    // we should reset this for the next save
    mdFlags.exportUsingPanel = NO;
    // just reset this as well, in case the panel was canceled
    mdFlags.exportOption = SKExportOptionDefault;
    
    [exportAccessoryController setRepresentedObject:nil];
    exportAccessoryController = nil;
    
    if (contextInfo) {
        NSInvocation *invocation = (NSInvocation *)CFBridgingRelease(contextInfo);
        __unsafe_unretained NSDocument *theDoc = doc;
        [invocation setArgument:&theDoc atIndex:2];
        [invocation setArgument:&didSave atIndex:3];
        [invocation invoke];
    }
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    // Override so we can determine if this is a save, saveAs or export operation, so we can prepare the correct accessory view
    mdFlags.exportUsingPanel = (saveOperation == NSSaveToOperation);
    // Should already be reset long ago, just to be sure
    mdFlags.exportOption = SKExportOptionDefault;
    NSInvocation *invocation = nil;
    if (delegate && didSaveSelector) {
        invocation = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:didSaveSelector]];
        [invocation setTarget:delegate];
        [invocation setSelector:didSaveSelector];
        [invocation setArgument:&contextInfo atIndex:4];
    }
    [super runModalSavePanelForSaveOperation:saveOperation delegate:self didSaveSelector:@selector(document:didSaveUsingPanel:contextInfo:) contextInfo:(void *)CFBridgingRetain(invocation)];
}

- (NSArray *)SkimNoteProperties {
    NSArray *array = [super SkimNoteProperties];
    NSArray *widgetProperties = [[self primaryWindowController] widgetProperties];
    if ([widgetProperties count])
        array = [array arrayByAddingObjectsFromArray:widgetProperties];
    if (pageOffsets != nil) {
        NSMutableArray *mutableArray = [NSMutableArray array];
        for (NSDictionary *dict in array) {
            NSUInteger pageIndex = [[dict objectForKey:SKNPDFAnnotationPageIndexKey] unsignedIntegerValue];
            NSPointPointer offsetPtr = (NSPointPointer)NSMapGet(pageOffsets, (const void *)pageIndex);
            if (offsetPtr != NULL) {
                NSMutableDictionary *mutableDict = [dict mutableCopy];
                NSRect bounds = NSRectFromString([dict objectForKey:SKNPDFAnnotationBoundsKey]);
                bounds.origin.x -= offsetPtr->x;
                bounds.origin.y -= offsetPtr->y;
                [mutableDict setObject:NSStringFromRect(bounds) forKey:SKNPDFAnnotationBoundsKey];
                [mutableArray addObject:mutableDict];
            } else {
                [mutableArray addObject:dict];
            }
        }
        array = mutableArray;
    }
    return  array;
}

- (BOOL)attachNotesAtURL:(NSURL *)absoluteURL {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSNumber *permissions = [[fm attributesOfItemAtPath:[absoluteURL path] error:NULL] objectForKey:NSFilePosixPermissions];
    NSNumber *isLocked = nil;
    [absoluteURL getResourceValue:&isLocked forKey:NSURLIsUserImmutableKey error:NULL];
    
    if (permissions && ([permissions shortValue] & S_IWUSR) == 0)
        [fm setAttributes:@{NSFilePosixPermissions:[NSNumber numberWithUnsignedInteger:[permissions shortValue] | S_IWUSR]} ofItemAtPath:[absoluteURL path] error:NULL];
    else
        permissions = nil;
    if ([isLocked boolValue])
        [absoluteURL setResourceValue:@NO forKey:NSURLIsUserImmutableKey error:NULL];
    else
        isLocked = nil;
    
    SKNSkimNotesWritingOptions writeOptions = 0;
    SKNXattrFlags flags = SKNXattrDefault;
    NSError *error = nil;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKWriteLegacySkimNotesKey] == NO) {
        writeOptions = SKNSkimNotesWritingSyncable;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKWriteSkimNotesAsArchiveKey] == NO)
            writeOptions |= SKNSkimNotesWritingPlist;
        flags = SKNXattrSyncable;
    }
    
    BOOL success = [fm writeSkimNotes:[self SkimNoteProperties] textNotes:[self notesString] richTextNotes:[self notesRTFData] toExtendedAttributesAtURL:absoluteURL options:writeOptions error:&error];
    
    if (success == NO)
        NSLog(@"Error attaching notes: %@", error);
    
    NSDictionary *options = [self presentationOptions];
    SKNExtendedAttributeManager *eam = [SKNExtendedAttributeManager sharedNoSplitManager];
    [eam removeExtendedAttributeNamed:PRESENTATION_OPTIONS_KEY atPath:[absoluteURL path] traverseLink:YES error:NULL];
    if (options)
        [eam setExtendedAttributeNamed:PRESENTATION_OPTIONS_KEY toPropertyListValue:options atPath:[absoluteURL path] options:flags error:NULL];
    
    if (permissions)
        [fm setAttributes:@{NSFilePosixPermissions:permissions} ofItemAtPath:[absoluteURL path] error:NULL];
    if (isLocked)
        [absoluteURL setResourceValue:isLocked forKey:NSURLIsUserImmutableKey error:NULL];
    
    return success;
}

- (BOOL)writeBackupNotesToURL:(NSURL *)absoluteURL forSaveOperation:(NSSaveOperationType)saveOperation {
    BOOL writeNotesOK = NO;
    BOOL fileExists = [absoluteURL checkResourceIsReachableAndReturnError:NULL];
    
    if (fileExists && (saveOperation == NSSaveAsOperation || saveOperation == NSSaveToOperation)) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"\"%@\" already exists. Do you want to replace it?", @"Message in alert dialog"), [absoluteURL lastPathComponent]]];
        [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"A file or folder with the same name already exists in %@. Replacing it will overwrite its current contents.", @"Informative text in alert dialog"), [[absoluteURL URLByDeletingLastPathComponent] lastPathComponent]]];
        [alert addButtonWithTitle:NSLocalizedString(@"Save", @"Button title")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Button title")];
        
        writeNotesOK = NSAlertFirstButtonReturn == [alert runModal];
    } else {
        writeNotesOK = YES;
    }
    
    if (writeNotesOK) {
        if ([self hasNotes])
            writeNotesOK = [super writeSafelyToURL:absoluteURL ofType:SKDocumentTypeNotes forSaveOperation:NSSaveToOperation error:NULL];
        else if (fileExists)
            writeNotesOK = [[NSFileManager defaultManager] removeItemAtURL:absoluteURL error:NULL];
    }
    
    return writeNotesOK;
}

// Prepare for saving and use callback to save notes and cleanup
// On 10.7+ all save operations go through this method, so we use this
- (void)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError *))completionHandler {
    
    BOOL wantsUpdateCheck = NO;
    NSString *notifyPath = nil;
    
    if (saveOperation != NSAutosaveElsewhereOperation) {
        if (saveOperation != NSSaveToOperation) {
            [fileUpdateChecker setEnabled:NO];
            wantsUpdateCheck = YES;
        } else if (mdFlags.exportUsingPanel) {
            [[NSUserDefaults standardUserDefaults] setObject:typeName forKey:SKLastExportedTypeKey];
            [[NSUserDefaults standardUserDefaults] setInteger:[self canAttachNotesForType:typeName] ? mdFlags.exportOption : SKExportOptionDefault forKey:SKLastExportedOptionKey];
        }
        if (saveOperation != NSAutosaveAsOperation && [[self class] isNativeType:typeName])
            notifyPath = [absoluteURL path];
    }
    
    // just to make sure
    if (saveOperation != NSSaveToOperation)
        mdFlags.exportOption = SKExportOptionDefault;

    [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError *errorOrNil){
        
        if (wantsUpdateCheck) {
            if (errorOrNil == nil)
                [fileUpdateChecker didUpdateFromURL:[self fileURL]];
            [fileUpdateChecker setEnabled:YES];
        }
        
        // reset this for the next save, in case this was set in the save script command
        mdFlags.exportOption = SKExportOptionDefault;
        
        if (completionHandler)
            completionHandler(errorOrNil);
        
        if (errorOrNil == nil && notifyPath)
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SKSkimFileDidSaveNotification object:notifyPath];
    }];
}

- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSURL *tmpURL = nil;
    NSMutableDictionary *attributes = nil;
    SKNExtendedAttributeManager *eam = nil;
    NSString *path = nil;
    BOOL attachNotes = [self canAttachNotesForType:typeName] && mdFlags.exportOption == SKExportOptionDefault;
    
    if ([ws type:typeName conformsToType:SKDocumentTypePDFBundle] &&
        [ws type:[self fileType] conformsToType:SKDocumentTypePDFBundle] &&
        [self fileURL] &&
        (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation || saveOperation == NSAutosaveInPlaceOperation)) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *fileURL = [self fileURL];
        // we move everything that's not ours out of the way, so we can preserve version control info
        NSSet *ourExtensions = [NSSet setWithObjects:@"pdf", @"skim", @"fdf", @"txt", @"text", @"rtf", @"plist", nil];
        for (NSURL *url in [fm contentsOfDirectoryAtURL:fileURL includingPropertiesForKeys:@[] options:0 error:NULL]) {
            if ([ourExtensions containsObject:[[url pathExtension] lowercaseString]] == NO) {
                if (tmpURL == nil)
                    tmpURL = [fm URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:fileURL create:YES error:NULL];
                [fm copyItemAtURL:url toURL:[tmpURL URLByAppendingPathComponent:[url lastPathComponent] isDirectory:[[url absoluteString] hasSuffix:@"/"]] error:NULL];
            }
        }
    }
    
    // There seems to be a bug on 10.9 when saving to an existing file that has a lot of extended attributes
    if (attachNotes && [self fileURL] && (saveOperation == NSSaveOperation || saveOperation == NSAutosaveInPlaceOperation)) {
        path = [[self fileURL] path];
        eam = [SKNExtendedAttributeManager sharedNoSplitManager];
        attributes = [NSMutableDictionary dictionary];
        [[eam allExtendedAttributesAtPath:path traverseLink:YES error:NULL] enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop){
            if ([key hasPrefix:SKIM_NOTES_PREFIX]) {
                [attributes setObject:value forKey:key];
                [eam removeExtendedAttributeNamed:key atPath:path traverseLink:YES error:NULL];
            }
        }];
    }
    
    BOOL didSave = [super writeSafelyToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    
    if (didSave) {
        if (attachNotes) {
            BOOL didWriteBackupNotes = NO;
            // we check for notes and may save a .skim as well:
            if ([[NSUserDefaults standardUserDefaults] boolForKey:SKAutoSaveSkimNotesKey] &&
                (saveOperation != NSAutosaveElsewhereOperation && saveOperation != NSAutosaveAsOperation))
                didWriteBackupNotes = [self writeBackupNotesToURL:[absoluteURL URLReplacingPathExtension:@"skim"] forSaveOperation:saveOperation];
            if (NO == [self attachNotesAtURL:absoluteURL]) {
                NSString *message = didWriteBackupNotes ? NSLocalizedString(@"The notes could not be saved with the PDF at \"%@\". However a companion .skim file was successfully updated.", @"Informative text in alert dialog") :
                NSLocalizedString(@"The notes could not be saved with the PDF at \"%@\"", @"Informative text in alert dialog");
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:NSLocalizedString(@"Unable to save notes", @"Message in alert dialog")];
                [alert setInformativeText:[NSString stringWithFormat:message, [absoluteURL lastPathComponent]]];
                [alert runModal];
            }
        } else if (tmpURL) {
            // move extra package content like version info to the new location
            NSFileManager *fm = [NSFileManager defaultManager];
            for (NSURL *url in [fm contentsOfDirectoryAtURL:tmpURL includingPropertiesForKeys:@[] options:0 error:NULL])
                [fm moveItemAtURL:url toURL:[absoluteURL URLByAppendingPathComponent:[url lastPathComponent] isDirectory:[[url absoluteString] hasSuffix:@"/"]] error:NULL];
        }
    } else if ([attributes count]) {
        [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            [eam setExtendedAttributeNamed:key toValue:obj atPath:path options:0 error:NULL];
        }];
    }
    
    if (tmpURL)
        [[NSFileManager defaultManager] removeItemAtURL:tmpURL error:NULL];

    return didSave;
}

- (NSFileWrapper *)PDFBundleFileWrapperForName:(NSString *)name {
    if ([name isCaseInsensitiveEqual:BUNDLE_DATA_FILENAME])
        name = [name stringByAppendingString:@"1"];
    NSData *data;
    NSFileWrapper *fileWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{}];
    NSDictionary *info = [self documentAttributes];
    NSDictionary *options = [self presentationOptions];
    if (options) {
        info = [info mutableCopy];
        [(NSMutableDictionary *)info setObject:options forKey:SKPresentationOptionsKey];
    }
    [fileWrapper addRegularFileWithContents:pdfData preferredFilename:[name stringByAppendingPathExtension:@"pdf"]];
    if ((data = [[[self pdfDocument] string] dataUsingEncoding:NSUTF8StringEncoding]))
        [fileWrapper addRegularFileWithContents:data preferredFilename:[BUNDLE_DATA_FILENAME stringByAppendingPathExtension:@"txt"]];
    if ((data = [NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL]))
        [fileWrapper addRegularFileWithContents:data preferredFilename:[BUNDLE_DATA_FILENAME stringByAppendingPathExtension:@"plist"]];
    if ([self hasNotes]) {
        if ((data = [self notesData]))
            [fileWrapper addRegularFileWithContents:data preferredFilename:[name stringByAppendingPathExtension:@"skim"]];
        if ((data = [[self notesString] dataUsingEncoding:NSUTF8StringEncoding]))
            [fileWrapper addRegularFileWithContents:data preferredFilename:[name stringByAppendingPathExtension:@"txt"]];
        if ((data = [self notesRTFData]))
            [fileWrapper addRegularFileWithContents:data preferredFilename:[name stringByAppendingPathExtension:@"rtf"]];
        if ((data = [self notesFDFDataForFile:[name stringByAppendingPathExtension:@"pdf"] fileIDStrings:[[self pdfDocument] fileIDStrings]]))
            [fileWrapper addRegularFileWithContents:data preferredFilename:[name stringByAppendingPathExtension:@"fdf"]];
    }
    return fileWrapper;
}

- (NSTask *)taskForWritingArchiveAtURL:(NSURL *)targetURL fromURL:(NSURL *)sourceURL {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/tar"];
    [task setArguments:@[@"-czf", [targetURL path], [sourceURL lastPathComponent]]];
    [task setCurrentDirectoryPath:[[sourceURL URLByDeletingLastPathComponent] path]];
    [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    return task;
}

- (BOOL)writeArchiveToURL:(NSURL *)absoluteURL error:(NSError **)outError {
    NSString *typeName = [self fileType];
    NSURL *tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:absoluteURL create:YES error:NULL];
    NSString *ext = [self fileNameExtensionForType:typeName saveOperation:NSSaveToOperation];
    NSURL *tmpFileURL = [tmpURL URLByAppendingPathComponent:[[absoluteURL URLReplacingPathExtension:ext] lastPathComponent] isDirectory:NO];
    BOOL didWrite = [self writeToURL:tmpFileURL ofType:typeName error:outError];
    if (didWrite) {
        if ([self canAttachNotesForType:typeName])
            didWrite = [self attachNotesAtURL:tmpFileURL];
        if (didWrite) {
            NSTask *task = [self taskForWritingArchiveAtURL:absoluteURL fromURL:tmpFileURL];
            @try { [task launch]; }
            @catch (id exception) { didWrite = NO; }
            if (didWrite) {
                [task waitUntilExit];
                didWrite = [task terminationStatus] == 0;
            }
        }
    }
    [[NSFileManager defaultManager] removeItemAtURL:tmpURL error:NULL];
    return didWrite;
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError{
    BOOL didWrite = NO;
    NSError *error = nil;
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    if ([ws type:SKDocumentTypeNotesText conformsToType:typeName]) {
        NSString *string = [self notesString];
        if (string)
            didWrite = [string writeToURL:absoluteURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
        else
            error = [NSError documentErrorWithCode:SKWriteFileError localizedDescription:NSLocalizedString(@"Unable to write notes as text", @"Error description")];
    } else if ([ws type:SKDocumentTypePDF conformsToType:typeName]) {
        if (mdFlags.exportOption == SKExportOptionWithEmbeddedNotes)
            didWrite = [[self pdfDocument] writeToURL:absoluteURL];
        else
            didWrite = [pdfData writeToURL:absoluteURL options:0 error:&error];
    } else if ([ws type:SKDocumentTypeEncapsulatedPostScript conformsToType:typeName] || 
               [ws type:SKDocumentTypeDVI conformsToType:typeName] || 
               [ws type:SKDocumentTypeXDV conformsToType:typeName]) {
        if ([ws type:[self fileType] conformsToType:typeName])
            didWrite = [originalData writeToURL:absoluteURL options:0 error:&error];
    } else if ([ws type:SKDocumentTypePDFBundle conformsToType:typeName]) {
        NSFileWrapper *fileWrapper = [self PDFBundleFileWrapperForName:[[absoluteURL lastPathComponent] stringByDeletingPathExtension]];
        if (fileWrapper)
            didWrite = [fileWrapper writeToURL:absoluteURL options:0 originalContentsURL:nil error:&error];
        else
            error = [NSError documentErrorWithCode:SKWriteFileError localizedDescription:NSLocalizedString(@"Unable to write file", @"Error description")];
    } else if ([ws type:SKDocumentTypeArchive conformsToType:typeName]) {
        didWrite = [self writeArchiveToURL:absoluteURL error:&error];
    } else if ([ws type:SKDocumentTypeNotes conformsToType:typeName]) {
        SKNSkimNotesWritingOptions options = [[NSUserDefaults standardUserDefaults] boolForKey:SKWriteLegacySkimNotesKey] || [[NSUserDefaults standardUserDefaults] boolForKey:SKWriteSkimNotesAsArchiveKey] ? 0 : SKNSkimNotesWritingPlist;
        didWrite = [[NSFileManager defaultManager] writeSkimNotes:[self SkimNoteProperties] toSkimFileAtURL:absoluteURL options:options error:&error];
    } else if ([ws type:SKDocumentTypeNotesRTF conformsToType:typeName]) {
        NSData *data = [self notesRTFData];
        if (data)
            didWrite = [data writeToURL:absoluteURL options:0 error:&error];
        else
            error = [NSError documentErrorWithCode:SKWriteFileError localizedDescription:NSLocalizedString(@"Unable to write notes as RTF", @"Error description")];
    } else if ([ws type:SKDocumentTypeNotesRTFD conformsToType:typeName]) {
        NSFileWrapper *fileWrapper = [self notesFileWrapperForTemplateType:typeName];
        if (fileWrapper)
            didWrite = [fileWrapper writeToURL:absoluteURL options:0 originalContentsURL:nil error:&error];
        else
            error = [NSError documentErrorWithCode:SKWriteFileError localizedDescription:NSLocalizedString(@"Unable to write notes as RTFD", @"Error description")];
    } else if ([ws type:SKDocumentTypeNotesFDF conformsToType:typeName]) {
        NSURL *fileURL = [self fileURL];
        if (fileURL && [ws type:[self fileType] conformsToType:SKDocumentTypePDFBundle])
            fileURL = [[NSFileManager defaultManager] bundledFileURLWithExtension:@"pdf" inPDFBundleAtURL:fileURL error:NULL];
        NSData *data = [self notesFDFDataForFile:[fileURL lastPathComponent] fileIDStrings:[[self pdfDocument] fileIDStrings]];
        if (data)
            didWrite = [data writeToURL:absoluteURL options:0 error:&error];
        else 
            error = [NSError documentErrorWithCode:SKWriteFileError localizedDescription:NSLocalizedString(@"Unable to write notes as FDF", @"Error description")];
    } else if ([[SKTemplateManager sharedManager] isRichTextBundleTemplateType:typeName]) {
        NSFileWrapper *fileWrapper = [self notesFileWrapperForTemplateType:typeName];
        if (fileWrapper)
            didWrite = [fileWrapper writeToURL:absoluteURL options:0 originalContentsURL:nil error:&error];
        else
            error = [NSError documentErrorWithCode:SKWriteFileError localizedDescription:NSLocalizedString(@"Unable to write notes using template", @"Error description")];
    } else {
        NSData *data = [self notesDataForTemplateType:typeName];
        if (data)
            didWrite = [data writeToURL:absoluteURL options:0 error:&error];
        else
            error = [NSError documentErrorWithCode:SKWriteFileError localizedDescription:NSLocalizedString(@"Unable to write notes using template", @"Error description")];
    }
    
    if (didWrite == NO && outError != NULL)
        *outError = error ?: [NSError documentErrorWithCode:SKWriteFileError localizedDescription:NSLocalizedString(@"Unable to write file", @"Error description")];
    
    return didWrite;
}

- (NSDictionary *)fileAttributesToWriteToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)outError {
    NSMutableDictionary *dict = [[super fileAttributesToWriteToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation originalContentsURL:absoluteOriginalContentsURL error:outError] mutableCopy];
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
    // only set the creator code for our native types
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKShouldSetCreatorCodeKey] && 
        ([[self class] isNativeType:typeName] || [typeName isEqualToString:SKDocumentTypeNotes]))
        [dict setObject:[NSNumber numberWithUnsignedInt:'SKim'] forKey:NSFileHFSCreatorCode];
    
    if ([ws type:typeName conformsToType:SKDocumentTypePDF])
        [dict setObject:[NSNumber numberWithUnsignedInt:'PDF '] forKey:NSFileHFSTypeCode];
    else if ([ws type:typeName conformsToType:SKDocumentTypePDFBundle])
        [dict setObject:[NSNumber numberWithUnsignedInt:'PDFD'] forKey:NSFileHFSTypeCode];
    else if ([ws type:typeName conformsToType:SKDocumentTypeNotes])
        [dict setObject:[NSNumber numberWithUnsignedInt:'SKNT'] forKey:NSFileHFSTypeCode];
    else if ([ws type:typeName conformsToType:SKDocumentTypeNotesFDF])
        [dict setObject:[NSNumber numberWithUnsignedInt:'FDF '] forKey:NSFileHFSTypeCode];
    else if ([[absoluteURL pathExtension] isEqualToString:@"rtf"] || [ws type:typeName conformsToType:SKDocumentTypeNotesRTF])
        [dict setObject:[NSNumber numberWithUnsignedInt:'RTF '] forKey:NSFileHFSTypeCode];
    else if ([[absoluteURL pathExtension] isEqualToString:@"txt"] || [ws type:typeName conformsToType:SKDocumentTypeNotesText])
        [dict setObject:[NSNumber numberWithUnsignedInt:'TEXT'] forKey:NSFileHFSTypeCode];
    
    return dict;
}

#pragma mark Reading

+ (NSArray *)readableTypes {
    static NSArray *readableTypes = nil;
    if (readableTypes == nil) {
        NSMutableArray *tmpTypes = [[super readableTypes] mutableCopy];
        if ([SKConversionProgressController toolPathForType:SKDocumentTypeDVI] == nil)
            [tmpTypes removeObject:SKDocumentTypeDVI];
        if ([SKConversionProgressController toolPathForType:SKDocumentTypeXDV] == nil)
            [tmpTypes removeObject:SKDocumentTypeXDV];
        if (@available(macOS 14.0, *)) {
            if ([SKConversionProgressController toolPathForType:SKDocumentTypePostScript] == nil) {
                [tmpTypes removeObject:SKDocumentTypePostScript];
                [tmpTypes removeObject:SKDocumentTypeEncapsulatedPostScript];
            }
        }
        readableTypes = tmpTypes;
    }
    return readableTypes;
}

- (void)setPDFData:(NSData *)data {
    if (pdfData != data) {
        pdfData = data;
    }
    pageOffsets = nil;
}

- (void)setOriginalData:(NSData *)data {
    if (originalData != data) {
        originalData = data;
    }
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)docType error:(NSError **)outError {
    NSData *inData = nil;
    PDFDocument *pdfDoc = nil;
    NSError *error = nil;
    
    if ([[NSWorkspace sharedWorkspace] type:docType conformsToType:SKDocumentTypePostScript]) {
        inData = data;
        data = [SKConversionProgressController newPDFDataWithPostScriptData:data error:&error];
    }
    
    if (data)
        pdfDoc = [[SKPDFDocument alloc] initWithData:data];
    
    if (pdfDoc) {
        tmpData = [[SKTemporaryData alloc] init];
        [tmpData setPdfDocument:pdfDoc];
        [self setPDFData:data];
        [self setOriginalData:inData];
        [self updateChangeCount:NSChangeReadOtherContents];
        return YES;
    } else {
        if (outError != NULL)
            *outError = error ?: [NSError documentErrorWithCode:SKReadFileError localizedDescription:NSLocalizedString(@"Unable to load file", @"Error description")];
        return NO;
    }
}

static BOOL isIgnorablePOSIXError(NSError *error) {
    if ([[error domain] isEqualToString:NSPOSIXErrorDomain])
        return [error code] == ENOATTR || [error code] == ENOTSUP || [error code] == EINVAL || [error code] == EPERM || [error code] == EACCES || [error code] == ENOENT;
    else
        return NO;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)docType error:(NSError **)outError{
    NSData *fileData = nil;
    NSData *data = nil;
    PDFDocument *pdfDoc = nil;
    NSArray *notes = nil;
    NSError *error = nil;
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
    if ([ws type:docType conformsToType:SKDocumentTypePDFBundle]) {
        NSURL *pdfURL = [[NSFileManager defaultManager] bundledFileURLWithExtension:@"pdf" inPDFBundleAtURL:absoluteURL error:&error];
        if (pdfURL) {
            if ((data = [[NSData alloc] initWithContentsOfURL:pdfURL options:NSDataReadingUncached error:&error]) &&
                (pdfDoc = [[SKPDFDocument alloc] initWithURL:pdfURL])) {
                NSArray *array = [[NSFileManager defaultManager] readSkimNotesFromPDFBundleAtURL:absoluteURL error:&error];
                if ([array count]) {
                    notes = array;
                } else if (array == nil && [self shouldDiscontinueAfterReadNotesError:error fromURL:absoluteURL]) {
                    data = nil;
                    pdfDoc = nil;
                    error = [NSError userCancelledErrorWithUnderlyingError:error];
                }
            }
        }
    } else if ((data = [[NSData alloc] initWithContentsOfURL:absoluteURL options:NSDataReadingUncached error:&error])) {
        if ([ws type:docType conformsToType:SKDocumentTypePDF]) {
            pdfDoc = [[SKPDFDocument alloc] initWithURL:absoluteURL];
        } else {
            fileData = data;
            if ((data = [SKConversionProgressController newPDFDataFromURL:absoluteURL ofType:docType error:&error]))
                pdfDoc = [[SKPDFDocument alloc] initWithData:data];
        }
        if (pdfDoc) {
            NSArray *array = [[NSFileManager defaultManager] readSkimNotesFromExtendedAttributesAtURL:absoluteURL error:&error];
            BOOL foundEANotes = [array count] > 0;
            // if we found no notes, see if we had an error finding notes. If EAs were not supported we ignore the error, as we may assume there won't be any notes
            if (foundEANotes) {
                notes = array;
            } else if (array == nil && isIgnorablePOSIXError(error) == NO && [self shouldDiscontinueAfterReadNotesError:error fromURL:absoluteURL]) {
                fileData = nil;
                data = nil;
                pdfDoc = nil;
                error = [NSError userCancelledErrorWithUnderlyingError:error];
            }
            if (pdfDoc) {
                NSInteger readOption = [[NSUserDefaults standardUserDefaults] integerForKey:foundEANotes ? SKReadNonMissingNotesFromSkimFileOptionKey : SKReadMissingNotesFromSkimFileOptionKey];
                if (readOption != SKOptionNever) {
                    NSURL *notesURL = [absoluteURL URLReplacingPathExtension:@"skim"];
                    if ([notesURL checkResourceIsReachableAndReturnError:NULL]) {
                        readOption = [self definitiveOption:readOption usingMessageText:NSLocalizedString(@"Found Separate Notes", @"Message in alert dialog") informativeText:foundEANotes ? NSLocalizedString(@"A Skim notes file with the same name was found.  Do you want Skim to read the notes from this file?", @"Informative text in alert dialog") : [NSString stringWithFormat:NSLocalizedString(@"Unable to read notes for %@, but a Skim notes file with the same name was found.  Do you want Skim to read the notes from this file?", @"Informative text in alert dialog"), [[absoluteURL path] stringByAbbreviatingWithTildeInPath]]];
                        if (readOption == SKOptionAlways) {
                            array = [[NSFileManager defaultManager] readSkimNotesFromSkimFileAtURL:notesURL error:NULL];
                            if ([array count] && [array isEqualToArray:notes] == NO) {
                                notes = array;
                                [self updateChangeCount:NSChangeReadOtherContents];
                            }
                        }
                    }
                }
            }
        }
    }
    
    if (data && pdfDoc) {
        tmpData = [[SKTemporaryData alloc] init];
        [tmpData setPdfDocument:pdfDoc];
        [tmpData setNoteDicts:notes];
        [self setPDFData:data];
        [self setOriginalData:fileData];
        [fileUpdateChecker didUpdateFromURL:absoluteURL];
        
        NSDictionary *dictionary = nil;
        NSArray *array = nil;
        NSNumber *number = nil;
        if ([docType isEqualToString:SKDocumentTypePDFBundle]) {
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfURL:[[absoluteURL URLByAppendingPathComponent:BUNDLE_DATA_FILENAME isDirectory:NO] URLByAppendingPathExtension:@"plist"] error:NULL];
            if ([info isKindOfClass:[NSDictionary class]]) {
                dictionary = [info objectForKey:SKPresentationOptionsKey];
                array = [info objectForKey:SKTagsKey];
                number = [info objectForKey:SKRatingKey];
            }
        } else {
            SKNExtendedAttributeManager *eam = [SKNExtendedAttributeManager sharedNoSplitManager];
            NSError *err = nil;
            dictionary = [eam propertyListFromExtendedAttributeNamed:PRESENTATION_OPTIONS_KEY atPath:[absoluteURL path] traverseLink:YES error:&err];
            array = [eam propertyListFromExtendedAttributeNamed:OPEN_META_TAGS_KEY atPath:[absoluteURL path] traverseLink:YES error:NULL];
            number = [eam propertyListFromExtendedAttributeNamed:OPEN_META_RATING_KEY atPath:[absoluteURL path] traverseLink:YES error:NULL];
        }
        if ([dictionary isKindOfClass:[NSDictionary class]] && [dictionary count])
            [tmpData setPresentationOptions:dictionary];
        if ([array isKindOfClass:[NSArray class]] && [array count])
            [tmpData setOpenMetaTags:array];
        if ([number respondsToSelector:@selector(doubleValue)] && [number doubleValue] > 0.0)
            [tmpData setOpenMetaRating:[number doubleValue]];
        
        return YES;
    } else {
        if (outError)
            *outError = error ?: [NSError documentErrorWithCode:SKReadFileError localizedDescription:NSLocalizedString(@"Unable to load file", @"Error description")];
        return NO;
    }
}

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError{
    
    if (NO == [super revertToContentsOfURL:absoluteURL ofType:typeName error:outError])
        return NO;
    
    NSWindow *primaryWindow = [[self primaryWindowController] window];
    NSWindow *modalwindow = nil;
    NSModalSession session = nil;
    
    if ([primaryWindow attachedSheet] == nil && [primaryWindow isMainWindow]) {
        modalwindow = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:NSZeroRect];
        [(SKApplication *)NSApp setUserAttentionDisabled:YES];
        session = [NSApp beginModalSessionForWindow:modalwindow];
        [(SKApplication *)NSApp setUserAttentionDisabled:NO];
    }
    
    [self setDataFromTmpData];
    [[self undoManager] removeAllActions];
    [fileUpdateChecker reset];
    
    if (modalwindow) {
        [NSApp endModalSession:session];
        [modalwindow orderOut:nil];
    }
    
    return YES;
}

#pragma mark Printing

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    NSPrintInfo *printInfo = [[self printInfo] copy];
    PDFDocument *pdfDoc = [self pdfDocument];
    
    // this can happen when the document is printed without display from the app delegate
    if (pdfDoc == nil && tmpData) {
        pdfDoc = [tmpData pdfDocument];
        if ([tmpData noteDicts]) {
            pdfDoc = [pdfDoc copy];
            [pdfDoc addSkimNotesWithProperties:[tmpData noteDicts]];
        }
    }
    
    [[printInfo dictionary] addEntriesFromDictionary:printSettings];

    NSPrintOperation *printOperation = [pdfDoc printOperationForPrintInfo:printInfo scalingMode:kPDFPrintPageScaleNone autoRotate:YES];
    
    // NSPrintProtected is a private key that disables the items in the PDF popup of the Print panel, and is set for encrypted documents
    if ([pdfDoc isEncrypted])
        [[[printOperation printInfo] dictionary] setValue:@NO forKey:@"NSPrintProtected"];
    
    NSPrintPanel *printPanel = [printOperation printPanel];
    [printPanel setOptions:NSPrintPanelShowsCopies | NSPrintPanelShowsPageRange | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation | NSPrintPanelShowsScaling | NSPrintPanelShowsPreview];
    [printPanel addAccessoryController:[[SKPrintAccessoryController alloc] init]];
    
    [printOperation setJobTitle:[self displayName]];
    
    if (printOperation == nil && outError)
        *outError = [NSError documentErrorWithCode:SKPrintDocumentError localizedDescription:NSLocalizedString(@"Unable to print", @"Error description")];
    
    return printOperation;
}

#pragma mark Actions

- (IBAction)copyURL:(id)sender {
    NSURL *skimURL = [[[self pdfView] currentPage] skimURL];
    if (skimURL) {
        NSString *searchString = [primaryWindowController searchString];
        if ([searchString length] > 0) {
            searchString = [searchString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            NSURLComponents *components = [[NSURLComponents alloc] initWithURL:skimURL resolvingAgainstBaseURL:NO];
            NSString *fragment = [components fragment];
            [components setFragment:[fragment length] ? [fragment stringByAppendingFormat:@"&search=%@", searchString] : [@"search=" stringByAppendingString:searchString]];
            skimURL = [components URL];
        }
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard writeURLs:@[skimURL] names:@[[self displayName]]];
    } else {
        NSBeep();
    }
}

- (void)readNotesFromURL:(NSURL *)notesURL replace:(BOOL)replace {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *type = [ws typeOfFile:[notesURL path] error:NULL];
    NSArray *array = nil;
    
    if ([ws type:type conformsToType:SKDocumentTypeNotes]) {
        array = [[NSFileManager defaultManager] readSkimNotesFromSkimFileAtURL:notesURL error:NULL];
    } else if ([ws type:type conformsToType:SKDocumentTypeNotesFDF]) {
        NSData *fdfData = [NSData dataWithContentsOfURL:notesURL];
        if (fdfData)
            array = [SKFDFParser noteDictionariesFromFDFData:fdfData];
    }
    
    if (array) {
        [[self primaryWindowController] addAnnotationsWithProperties:array replacing:replace];
        [[self undoManager] setActionName:replace ? NSLocalizedString(@"Replace Notes", @"Undo action name") : NSLocalizedString(@"Add Notes", @"Undo action name")];
    } else
        NSBeep();
}

#define CHECK_BUTTON_OFFSET_X 16.0
#define CHECK_BUTTON_OFFSET_Y 8.0

- (IBAction)readNotes:(id)sender{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    NSURL *fileURL = [self fileURL];
    NSButton *replaceNotesCheckButton = nil;
    
    if ([self hasNotes]) {
        replaceNotesCheckButton = [[NSButton alloc] init];
        [replaceNotesCheckButton setButtonType:NSSwitchButton];
        [replaceNotesCheckButton setTitle:NSLocalizedString(@"Replace existing notes", @"Check button title")];
        [replaceNotesCheckButton sizeToFit];
        [replaceNotesCheckButton setFrameOrigin:NSMakePoint(CHECK_BUTTON_OFFSET_X, CHECK_BUTTON_OFFSET_Y)];
        NSView *readNotesAccessoryView = [[NSView alloc] initWithFrame:NSInsetRect([replaceNotesCheckButton frame], -CHECK_BUTTON_OFFSET_X, -CHECK_BUTTON_OFFSET_Y)];
        [readNotesAccessoryView addSubview:replaceNotesCheckButton];
        [oPanel setAccessoryView:readNotesAccessoryView];
        [replaceNotesCheckButton setState:NSControlStateValueOn];
        [oPanel setAccessoryViewDisclosed:YES];
    }
    
    [oPanel setDirectoryURL:[fileURL URLByDeletingLastPathComponent]];
    [oPanel setAllowedFileTypes:@[SKDocumentTypeNotes]];
    [oPanel beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse result){
            if (result == NSModalResponseOK)
                [self readNotesFromURL:[[oPanel URLs] firstObject] replace:[replaceNotesCheckButton state] == NSControlStateValueOn];
        }];
}

- (void)setPDFData:(NSData *)data pageOffsets:(NSMapTable *)newPageOffsets {
    [[[self undoManager] prepareWithInvocationTarget:self] setPDFData:pdfData pageOffsets:pageOffsets];
    [self setPDFData:data];
    if (newPageOffsets != pageOffsets) {
        pageOffsets = newPageOffsets;
    }
}

- (void)convertNotesUsingPDFDocument:(PDFDocument *)pdfDocWithoutNotes completionHandler:(void (^)(void))completionHandler {
    [[self primaryWindowController] beginProgressSheetWithMessage:[NSLocalizedString(@"Converting notes", @"Message for progress sheet") stringByAppendingEllipsis] maxValue:0];
    
    NSMapTable *offsets = nil;
    NSMutableArray *annotations = nil;
    NSMutableArray *noteDicts = nil;

    for (PDFPage *page in [self pdfDocument]) {
        NSPoint pageOrigin = [page boundsForBox:kPDFDisplayBoxMediaBox].origin;
        
        for (PDFAnnotation *annotation in [[page annotations] copy]) {
            if ([annotation isSkimNote] == NO && [annotation isConvertibleAnnotation]) {
                if (annotations == nil)
                    annotations = [[NSMutableArray alloc] init];
                [annotations addObject:annotation];
                NSDictionary *properties = [PDFAnnotation normalizedSkimNoteProperties:[annotation SkimNoteProperties]];
                if (noteDicts == nil)
                    noteDicts = [[NSMutableArray alloc] init];
                [noteDicts addObject:properties];
            }
        }
        
        if (NSEqualPoints(pageOrigin, NSZeroPoint) == NO) {
            if (offsets == nil)
                offsets = [[NSMapTable alloc] initWithKeyPointerFunctions:[NSPointerFunctions integerPointerFunctions] valuePointerFunctions:[NSPointerFunctions pointPointerFunctions] capacity:0];
            NSMapInsert(offsets, (const void *)[page pageIndex], &pageOrigin);
        }
    }
    
    if (annotations) {
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            // if pdfDocWithoutNotes was nil, the document was not encrypted, so no need to try to unlock
            PDFDocument *pdfDoc = pdfDocWithoutNotes ?: [[PDFDocument alloc] initWithData:pdfData];
            
            for (PDFPage *page in pdfDoc) {
                for (PDFAnnotation *annotation in [[page annotations] copy]) {
                    if ([annotation isSkimNote] == NO && [annotation isConvertibleAnnotation]) {
                        PDFAnnotation *popup = [annotation popup];
                        if ([popup page])
                            [page removeAnnotation:popup];
                        [page removeAnnotation:annotation];
                    }
                }
            }
            
            NSData *data = [pdfDoc dataRepresentation];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [[self primaryWindowController] addConvertedAnnotationsWithProperties:noteDicts removeAnnotations:annotations];
                
                [self setPDFData:data pageOffsets:offsets];
                
                [[self undoManager] setActionName:NSLocalizedString(@"Convert Notes", @"Undo action name")];
                
                [[self primaryWindowController] dismissProgressSheet];
                
                if (completionHandler)
                    completionHandler();
                
                mdFlags.convertingNotes = 0;
            });
        });
        
    } else {
        
        [[self primaryWindowController] dismissProgressSheet];
        
        if (completionHandler)
            completionHandler();
        
        mdFlags.convertingNotes = 0;
    }
}

- (void)beginConvertNotesPasswordSheetForPDFDocument:(PDFDocument *)pdfDoc completionHandler:(void (^)(void))completionHandler {
    SKTextFieldSheetController *passwordSheetController = [[SKTextFieldSheetController alloc] initWithWindowNibName:@"PasswordSheet"];
    [passwordSheetController setInformativeText:NSLocalizedString(@"The document requires a password to be converted", @"Informative text")];
    
    [passwordSheetController beginSheetModalForWindow:[[self primaryWindowController] window] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                [[passwordSheetController window] orderOut:nil];
                
                if (pdfDoc && ([pdfDoc allowsNotes] == NO || [pdfDoc allowsSaving] == NO) &&
                    ([pdfDoc unlockWithPassword:[passwordSheetController stringValue]] == NO || [pdfDoc allowsNotes] == NO || [pdfDoc allowsSaving] == NO)) {
                    [self beginConvertNotesPasswordSheetForPDFDocument:pdfDoc completionHandler:completionHandler];
                } else {
                    [self convertNotesUsingPDFDocument:pdfDoc completionHandler:completionHandler];
                }
            } else {
                if (completionHandler)
                    completionHandler();
                
                mdFlags.convertingNotes = 0;
            }
        }];
}

- (void)convertNotesWithCompletionHandler:(void (^)(void))completionHandler {
    mdFlags.convertingNotes = 1;
    
    PDFDocument *pdfDocWithoutNotes = nil;
    
    if (mdFlags.needsPasswordToConvert) {
        pdfDocWithoutNotes = [[PDFDocument alloc] initWithData:pdfData];
        [self tryToUnlockDocument:pdfDocWithoutNotes];
        if ([pdfDocWithoutNotes allowsNotes] == NO || [pdfDocWithoutNotes allowsSaving] == NO) {
            [self beginConvertNotesPasswordSheetForPDFDocument:pdfDocWithoutNotes completionHandler:completionHandler];
            return;
        }
    }
    [self convertNotesUsingPDFDocument:pdfDocWithoutNotes completionHandler:completionHandler];
}

- (BOOL)hasConvertibleAnnotations {
    for (PDFPage *page in [self pdfDocument]) {
        for (PDFAnnotation *annotation in [page annotations]) {
            if ([annotation isSkimNote] == NO && [annotation isConvertibleAnnotation])
                return YES;
        }
    }
    return NO;
}

- (IBAction)convertNotes:(id)sender {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    if (([ws type:[self fileType] conformsToType:SKDocumentTypePDF] == NO && [ws type:[self fileType] conformsToType:SKDocumentTypePDFBundle] == NO) ||
        [self hasConvertibleAnnotations] == NO) {
        NSBeep();
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"Convert Notes", @"Alert text when trying to convert notes")];
    [alert setInformativeText:NSLocalizedString(@"This will convert PDF annotations to Skim notes. Do you want to proceed?", @"Informative text in alert dialog")];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"Button title")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Button title")];
    [alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode){
        if (returnCode == NSAlertFirstButtonReturn) {
            // remove the sheet, to make place for either the password or progress sheet
            [[alert window] orderOut:nil];
            [self convertNotesWithCompletionHandler:nil];
        }
    }];
}

- (IBAction)share:(id)sender {
    BOOL shouldArchive = ([self hasNotes] || [[self presentationOptions] count] > 0);
    
    NSString *typeName = [self fileType];
    if (shouldArchive == NO && [typeName isEqualToString:SKDocumentTypePDFBundle])
        typeName = SKDocumentTypePDF;
    
    NSString *typeExt = [self fileNameExtensionForType:typeName saveOperation:NSAutosaveElsewhereOperation];
    NSString *targetExt = shouldArchive ? @"tgz" : typeExt;
    NSString *targetFileName = [[self fileURL] lastPathComponentReplacingPathExtension:targetExt];
    if (targetFileName == nil)
        targetFileName = [[self displayName] stringByAppendingPathExtension:targetExt];
    
    NSURL *targetDirURL = [[NSFileManager defaultManager] uniqueChewableItemsDirectoryURL];
    NSURL *targetFileURL = [targetDirURL URLByAppendingPathComponent:targetFileName isDirectory:NO];
    NSURL *tmpURL = nil;
    NSURL *fileURL = targetFileURL;
    
    if (shouldArchive) {
        tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:targetFileURL create:YES error:NULL];
        fileURL = [[tmpURL URLByAppendingPathComponent:targetFileName isDirectory:NO] URLReplacingPathExtension:typeExt];
    }
    
    if ([self writeSafelyToURL:fileURL ofType:typeName forSaveOperation:NSAutosaveElsewhereOperation error:NULL] == NO) {
        NSBeep();
        return;
    }
    
    if (shouldArchive) {
        NSTask *task = [self taskForWritingArchiveAtURL:targetFileURL fromURL:fileURL];
        NSSharingService *service = [sender representedObject];
        [service setSubject:[self displayName]];
        
        [SKFileShare shareURL:targetFileURL
               preparedByTask:task
                 usingService:service
            completionHandler:^(BOOL success){
                NSFileManager *fm = [NSFileManager defaultManager];
                [fm removeItemAtURL:tmpURL error:NULL];
                if (success == NO) {
                    [fm removeItemAtURL:targetDirURL error:NULL];
                    NSBeep();
                }
            }];
    } else {
        NSArray *items = @[targetFileURL];
        NSSharingService *service = [sender representedObject];
        if ([service canPerformWithItems:items]) {
            [service setSubject:[self displayName]];
            [service performWithItems:items];
        } else {
            [[NSFileManager defaultManager] removeItemAtURL:targetDirURL error:NULL];
        }
    }
}

static NSDate *fileModificationDate(NSURL *fileURL) {
    NSDate *modDate = nil;
    [fileURL getResourceValue:&modDate forKey:NSURLContentModificationDateKey error:NULL];
    return modDate;
}

- (void)revertDocumentToSaved:(id)sender { 	 
     if ([self fileURL]) {
         if ([self isDocumentEdited]) {
             [super revertDocumentToSaved:sender]; 	 
         } else if ([fileUpdateChecker fileChangedOnDisk] || 
                    NSOrderedAscending == [[self fileModificationDate] compare:fileModificationDate([self fileURL])]) {
             NSAlert *alert = [[NSAlert alloc] init];
             [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Do you want to revert to the version of the document \"%@\" on disk?", @"Message in alert dialog"), [[self fileURL] lastPathComponent]]];
             [alert setInformativeText:NSLocalizedString(@"Your current changes will be lost.", @"Informative text in alert dialog")];
             [alert addButtonWithTitle:NSLocalizedString(@"Revert", @"Button title")];
             [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Button title")];
             [alert beginSheetModalForWindow:[[self primaryWindowController] window] completionHandler:^(NSModalResponse returnCode){
                 if (returnCode == NSAlertFirstButtonReturn) {
                     NSError *error = nil;
                     if (NO == [self revertToContentsOfURL:[self fileURL] ofType:[self fileType] error:&error] && [error isUserCancelledError] == NO) {
                         [[alert window] orderOut:nil];
                         [self presentError:error modalForWindow:[self windowForSheet] delegate:nil didPresentSelector:NULL contextInfo:NULL];
                     }
                 }
             }];
         } else {
             [super revertDocumentToSaved:sender];
         }
    }
}

- (void)performFindPanelAction:(id)sender {
    [[self primaryWindowController] performFindPanelAction:sender];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
	if ([anItem action] == @selector(revertDocumentToSaved:)) {
        if ([self fileURL] == nil || [[self fileURL] checkResourceIsReachableAndReturnError:NULL] == NO || [[self primaryWindowController] interactionMode] == SKPresentationMode)
            return NO;
        if ([self isDocumentEdited] || [fileUpdateChecker fileChangedOnDisk] ||
               NSOrderedAscending == [[self fileModificationDate] compare:fileModificationDate([self fileURL])])
            return YES;
        return [super validateUserInterfaceItem:anItem];
    } else if ([anItem action] == @selector(convertNotes:)) {
        return [[NSWorkspace sharedWorkspace] type:[self fileType] conformsToType:SKDocumentTypePDF] && [[self pdfDocument] allowsNotes];
    } else if ([anItem action] == @selector(readNotes:)) {
        return [[self pdfDocument] allowsNotes];
    } else if ([anItem action] == @selector(performFindPanelAction:)) {
        if ([[self primaryWindowController] interactionMode] == SKPresentationMode)
            return NO;
        switch ([anItem tag]) {
            case NSFindPanelActionShowFindPanel:
                return YES;
            case NSFindPanelActionNext:
            case NSFindPanelActionPrevious:
                return YES;
            case NSFindPanelActionSetFindString:
                return [[[self pdfView] currentSelection] hasCharacters];
            default:
                return NO;
        }
    } else if ([anItem action] == @selector(copyURL:)) {
        return [self fileURL] != nil;
    }
    return [super validateUserInterfaceItem:anItem];
}

- (void)remoteButtonPressed:(NSEvent *)theEvent {
    [[self primaryWindowController] remoteButtonPressed:theEvent];
}

- (void)printDocument:(id)sender {
    PDFDocument *pdfDoc = [self pdfDocument];
    if ([pdfDoc allowsPrinting]) {
        [super printDocument:sender];
    } else {
        SKTextFieldSheetController *passwordSheetController = [[SKTextFieldSheetController alloc] initWithWindowNibName:@"PasswordSheet"];
        [passwordSheetController setInformativeText:NSLocalizedString(@"The document requires a password to be printed", @"Informative text")];
        
        [passwordSheetController beginSheetModalForWindow:[[self primaryWindowController] window] completionHandler:^(NSModalResponse result) {
                if (result == NSModalResponseOK) {
                    [[passwordSheetController window] orderOut:nil];
                    [pdfDoc unlockWithPassword:[passwordSheetController stringValue]];
                    [self printDocument:nil];
                }
            }];
    }
}

#pragma mark Notification handlers

// this is forwarded by the window controller
- (void)windowWillClose:(NSNotification *)notification {
    [self saveRecentDocumentInfo];
    
    [fileUpdateChecker terminate];
    fileUpdateChecker = nil;
    
    [synchronizer terminate];
}

#pragma mark Pdfsync support

- (void)setFileURL:(NSURL *)absoluteURL {
    [super setFileURL:absoluteURL];
    
    if ([absoluteURL isFileURL])
        [synchronizer setFileName:[absoluteURL path]];
    else
        [synchronizer setFileName:nil];
    
    [self setRecentInfoNeedsUpdate:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKDocumentFileURLDidChangeNotification object:self];
}

- (SKPDFSynchronizer *)synchronizer {
    if (synchronizer == nil) {
        synchronizer = [[SKPDFSynchronizer alloc] init];
        [synchronizer setDelegate:self];
        [synchronizer setFileName:[[self fileURL] path]];
    }
    return synchronizer;
}

static void replaceInShellCommand(NSMutableString *cmdString, NSString *find, NSString *replace) {
    NSRange range = NSMakeRange(0, 0);
    unichar prevChar, nextChar;
    while (NSMaxRange(range) < [cmdString length]) {
        range = [cmdString rangeOfString:find options:NSLiteralSearch range:NSMakeRange(NSMaxRange(range), [cmdString length] - NSMaxRange(range))];
        if (range.location == NSNotFound)
            break;
        prevChar = range.location > 0 ? [cmdString characterAtIndex:range.location - 1] : 0;
        nextChar = NSMaxRange(range) < [cmdString length] ? [cmdString characterAtIndex:NSMaxRange(range)] : 0;
        if ([[NSCharacterSet letterCharacterSet] characterIsMember:nextChar] == NO) {
            if (prevChar != '\'' || nextChar != '\'')
                replace = [replace stringByEscapingShellChars];
            [cmdString replaceCharactersInRange:range withString:replace];
            range.length = [replace length];
        }
    }
}

- (void)synchronizerFoundLine:(NSInteger)line inFile:(NSString *)file {
    if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
        
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        NSString *editorPreset = [sud stringForKey:SKTeXEditorPresetKey];
        NSDictionary *editor = [SKSyncPreferences TeXEditorForPreset:editorPreset];
        NSString *editorCmd = [editor objectForKey:SKSyncTeXEditorCommandKey] ?: [sud stringForKey:SKTeXEditorCommandKey];
        NSString *editorArgs = [editor objectForKey:SKSyncTeXEditorArgumentsKey] ?: [sud stringForKey:SKTeXEditorArgumentsKey];
        NSMutableString *cmdString = [editorArgs mutableCopy];
        
        if ([editorCmd isAbsolutePath] == NO) {
            NSMutableArray *searchPaths = [NSMutableArray arrayWithObjects:@"/usr/bin", @"/usr/local/bin", nil];
            NSString *toolPath;
            NSBundle *appBundle;
            NSFileManager *fm = [NSFileManager defaultManager];
            
            if ([editorPreset isEqualToString:@""] == NO) {
                NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication:editorPreset];
                if (path && (appBundle = [NSBundle bundleWithPath:path])) {
                    if ((path = [[appBundle bundlePath] stringByDeletingLastPathComponent]))
                        [searchPaths insertObject:path atIndex:0];
                    if ((path = [[appBundle bundlePath] stringByAppendingPathComponent:@"Contents"]))
                        [searchPaths insertObject:path atIndex:0];
                    if ((path = [[[appBundle bundlePath] stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"Helpers"]))
                        [searchPaths insertObject:path atIndex:0];
                    if ([editorPreset isEqualToString:@"BBEdit"] == NO &&
                        (path = [[appBundle executablePath] stringByDeletingLastPathComponent]))
                        [searchPaths insertObject:path atIndex:0];
                    if ((path = [appBundle resourcePath]))
                        [searchPaths insertObject:path atIndex:0];
                    if ((path = [appBundle sharedSupportPath]))
                        [searchPaths insertObject:path atIndex:0];
                }
            } else {
                [searchPaths addObjectsFromArray:[[fm applicationSupportDirectoryURLs] valueForKey:@"path"]];
            }
            
            for (NSString *path in searchPaths) {
                toolPath = [path stringByAppendingPathComponent:editorCmd];
                if ([fm isExecutableFileAtPath:toolPath]) {
                    editorCmd = toolPath;
                    break;
                }
                toolPath = [[path stringByAppendingPathComponent:@"bin"] stringByAppendingPathComponent:editorCmd];
                if ([fm isExecutableFileAtPath:toolPath]) {
                    editorCmd = toolPath;
                    break;
                }
            }
        }
        
        replaceInShellCommand(cmdString, @"%line", [NSString stringWithFormat:@"%ld", (long)(line + 1)]);
        replaceInShellCommand(cmdString, @"%zline", [NSString stringWithFormat:@"%ld", (long)line]);
        replaceInShellCommand(cmdString, @"%file", file);
        replaceInShellCommand(cmdString, @"%urlfile", [file stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]);
        replaceInShellCommand(cmdString, @"%output", [[self fileURL] path]);
        
        [cmdString insertString:@"\" " atIndex:0];
        [cmdString insertString:editorCmd atIndex:0];
        [cmdString insertString:@"\"" atIndex:0];
        
        NSWorkspace *ws = [NSWorkspace sharedWorkspace];
        NSString *theUTI = [ws typeOfFile:[[editorCmd stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL];
        if ([ws type:theUTI conformsToType:@"com.apple.applescript.script"] || [ws type:theUTI conformsToType:@"com.apple.applescript.text"])
            [cmdString insertString:@"/usr/bin/osascript " atIndex:0];
        
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/sh"];
        [task setCurrentDirectoryPath:[file stringByDeletingLastPathComponent]];
        [task setArguments:@[@"-c", cmdString]];
        [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
        [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        @try {
            [task launch];
        }
        @catch(id exception) {
            NSLog(@"command failed: %@: %@", cmdString, exception);
        }
    }
}

- (void)synchronizerFoundLocation:(NSPoint)point atPageIndex:(NSUInteger)pageIndex options:(SKPDFSynchronizerOptions)options {
    PDFDocument *pdfDoc = [self pdfDocument];
    if (pageIndex < [pdfDoc pageCount]) {
        if ((options & SKPDFSynchronizerFlipped))
            point.y = NSMaxY([[pdfDoc pageAtIndex:pageIndex] boundsForBox:kPDFDisplayBoxMediaBox]) - point.y;
        [[self pdfView] displayLineAtPoint:point inPageAtIndex:pageIndex select:(options & SKPDFSynchronizerSelect) != 0 showReadingBar:(options & SKPDFSynchronizerShowReadingBar) != 0];
    }
}


#pragma mark Accessors

- (NSWindow *)primaryWindow {
    return [primaryWindowController window];
}

- (PDFDocument *)pdfDocument{
    return [[self primaryWindowController] pdfDocument];
}

- (PDFDocument *)placeholderPdfDocument{
    return [[self primaryWindowController] placeholderPdfDocument];
}

- (NSDictionary *)currentDocumentSetup {
    NSMutableDictionary *setup = [[super currentDocumentSetup] mutableCopy];
    if ([setup count])
        [setup addEntriesFromDictionary:[[self primaryWindowController] currentSetup]];
    return setup;
}

- (SKPDFView *)pdfView {
    return [[self primaryWindowController] pdfView];
}

- (BOOL)recentInfoNeedsUpdate {
    return mdFlags.recentInfoNeedsUpdate && [self fileURL] != nil;
}

- (void)setRecentInfoNeedsUpdate:(BOOL)flag {
    mdFlags.recentInfoNeedsUpdate = flag;
}

- (NSDictionary *)presentationOptions {
    SKTransitionController *transitions = [[self primaryWindowController] transitionControllerCreating:NO];
    SKTransitionInfo *transition = [transitions transition];
    NSArray *pageTransitions = [transitions pageTransitions];
    NSMutableDictionary *options = nil;
    if ([transition style] != SKNoTransition || [pageTransitions count]) {
        options = [NSMutableDictionary dictionaryWithDictionary:[transition properties]];
        [options setValue:pageTransitions forKey:PAGETRANSITIONS_KEY];
    }
    return options;
}

- (void)setPresentationOptions:(NSDictionary *)dictionary {
    SKTransitionController *transitions = [[self primaryWindowController] transitionControllerCreating:dictionary != nil];
    if (dictionary) {
        [transitions setTransition:[[SKTransitionInfo alloc] initWithProperties:dictionary]];
        [transitions setPageTransitions:[dictionary objectForKey:PAGETRANSITIONS_KEY]];
    } else if (transitions) {
        NSUInteger count = [[transitions pageTransitions] count];
        if (count > 0 && count + 1 != [[self pdfDocument] pageCount]) {
            [transitions setTransition:[[SKTransitionInfo alloc] init]];
            [transitions setPageTransitions:nil];
        }
    }
}

- (NSArray *)snapshots {
    return [[self primaryWindowController] snapshots];
}

- (NSArray *)tags {
    return [[self primaryWindowController] tags] ?: @[];
}

- (double)rating {
    return [[self primaryWindowController] rating];
}

- (NSMenu *)notesMenu {
    return [[self primaryWindowController] notesMenu];
}

#pragma mark Passwords

- (void)savePasswordInKeychain:(NSString *)password {
    NSInteger saveOption = [[NSUserDefaults standardUserDefaults] integerForKey:SKSavePasswordOptionKey];
    saveOption = [self definitiveOption:saveOption usingMessageText:NSLocalizedString(@"Remember Password?", @"Message in alert dialog") informativeText:NSLocalizedString(@"Do you want to save this password in your Keychain?", @"Informative text in alert dialog")];
    if (saveOption == SKOptionAlways) {
        NSString *fileID = [[[self pdfDocument] fileIDStrings] lastObject] ?: [pdfData md5String];
        if (fileID) {
            NSString *label = [@"Skim: " stringByAppendingString:[self displayName]];
            NSString *comment = [[self fileURL] path];
            // try to update the password in an existing item
            SKPasswordStatus status = [SKKeychain updatePassword:password service:nil account:nil label:label comment:comment forService:SKPDFPasswordServiceName account:fileID];
            if (status == SKPasswordStatusNotFound) {
                // try to update an item in the old format
                status = [SKKeychain updatePassword:password service:SKPDFPasswordServiceName account:fileID label:label comment:comment forService:[@"Skim - " stringByAppendingString:fileID] account:nil];
                if (status == SKPasswordStatusNotFound) {
                    // add a new password item if no existing item was found
                    [SKKeychain setPassword:password forService:SKPDFPasswordServiceName account:fileID label:label comment:comment];
                }
            }
        }
    }
}

- (void)tryToUnlockDocument:(PDFDocument *)document {
    if ([document permissionsStatus] != kPDFDocumentPermissionsOwner) {
        NSString *password = nil;
        if  (SKOptionNever != [[NSUserDefaults standardUserDefaults] integerForKey:SKSavePasswordOptionKey]) {
            NSString *fileID = [[document fileIDStrings] lastObject] ?: [pdfData md5String];
            if (fileID) {
                SKPasswordStatus status = SKPasswordStatusError;
                password = [SKKeychain passwordForService:SKPDFPasswordServiceName account:fileID status:&status];
                if (status == SKPasswordStatusNotFound) {
                    // try to find an item in the old format
                    NSString *oldService = [@"Skim - " stringByAppendingString:fileID];
                    password = [SKKeychain passwordForService:oldService account:nil status:&status];
                    if (status == SKPasswordStatusFound) {
                        // update to new format
                        [SKKeychain updatePassword:nil service:SKPDFPasswordServiceName account:fileID label:[@"Skim: " stringByAppendingString:[self displayName]] comment:[[self fileURL] path] forService:oldService account:nil];
                    }
                }
            }
        }
        if (password == nil && [[self pdfDocument] respondsToSelector:@selector(passwordUsedForUnlocking)] && [[self pdfDocument] permissionsStatus] > [document permissionsStatus])
            password = [[self pdfDocument] passwordUsedForUnlocking];
        if (password)
            [document unlockWithPassword:password];
    }
}

#pragma mark Scripting support

- (BOOL)hasNotes {
    return [[self primaryWindowController] hasNotes];
}

- (NSArray *)notes {
    return [[self primaryWindowController] notes];
}

- (PDFAnnotation *)valueInNotesWithUniqueID:(NSString *)aUniqueID {
    for (PDFAnnotation *annotation in [[self primaryWindowController] notes]) {
        if ([[annotation uniqueID] isEqualToString:aUniqueID])
            return annotation;
    }
    return nil;
}

- (void)insertObject:(PDFAnnotation *)newNote inNotesAtIndex:(NSUInteger)anIndex {
    if ([[self pdfDocument] allowsNotes]) {
        PDFPage *page = [newNote page];
        if (page == nil) {
            [[NSScriptCommand currentCommand] setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
            [[NSScriptCommand currentCommand] setScriptErrorString:@"New note needs to be added to a page."];
        } else if ([[page annotations] containsObject:newNote] == NO) {
            [[self pdfDocument] addAnnotation:newNote toPage:page];
            [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];
        }
    }
}

- (void)removeObjectFromNotesAtIndex:(NSUInteger)anIndex {
    if ([[self pdfDocument] allowsNotes]) {
        PDFAnnotation *note = [[self notes] objectAtIndex:anIndex];
        
        [[self pdfDocument] removeAnnotation:note];
        [[self undoManager] setActionName:NSLocalizedString(@"Remove Note", @"Undo action name")];
    }
}

- (NSUInteger)countOfOutlines {
    return [[[self pdfDocument] outlineRoot] numberOfChildren];
}

- (PDFOutline *)objectInOutlinesAtIndex:(NSUInteger)idx {
    return [[[self pdfDocument] outlineRoot] childAtIndex:idx];
}

- (BOOL)isOutlineExpanded:(PDFOutline *)outline {
    return [[self primaryWindowController] isOutlineExpanded:outline];
}

- (void)setExpanded:(BOOL)flag forOutline:(PDFOutline *)outline {
    [[self primaryWindowController] setExpanded:flag forOutline:outline];
}

- (PDFPage *)currentPage {
    return [primaryWindowController currentPage];
}

- (void)setCurrentPage:(PDFPage *)page {
    [primaryWindowController setCurrentPage:page];
}

- (NSData *)currentQDPoint {
    SKDestination dest = [[self pdfView] currentSKDestination:NO];
    Point qdPoint = SKQDPointFromNSPoint(dest.point);
    return [NSData dataWithBytes:&qdPoint length:sizeof(Point)];
}

- (PDFAnnotation *)activeNote {
    return [[self pdfView] currentAnnotation];
}

- (void)setActiveNote:(PDFAnnotation *)note {
    if ([note isEqual:[NSNull null]] == NO && [note isSkimNote])
        [[self pdfView] setCurrentAnnotation:note];
}

- (NSTextStorage *)richText {
    PDFDocument *doc = [self pdfDocument];
    NSUInteger i, count = [doc pageCount];
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NSAttributedString *attrString;
    [textStorage beginEditing];
    for (i = 0; i < count; i++) {
        if (i > 0)
            [[textStorage mutableString] appendString:@"\n"];
        if ((attrString = [[doc pageAtIndex:i] attributedString]))
            [textStorage appendAttributedString:attrString];
    }
    [textStorage endEditing];
    return textStorage;
}

- (id)selectionSpecifier {
    PDFSelection *sel = [[self pdfView] currentSelection];
    return [sel hasCharacters] ? [sel objectSpecifiers] : @[];
}

- (void)setSelectionSpecifier:(id)specifier {
    SKToolMode toolMode = [[self pdfView] toolMode];
    if (toolMode != SKToolModeText && toolMode != SKToolModeNote)
        return;
    PDFSelection *selection = [PDFSelection selectionWithSpecifiers:specifier];
    [[self pdfView] setCurrentSelection:selection];
}

- (NSData *)selectionQDRect {
    Rect qdRect = SKQDRectFromNSRect([[self pdfView] selectToolRect]);
    return [NSData dataWithBytes:&qdRect length:sizeof(Rect)];
}

- (void)setSelectionQDRect:(NSData *)inQDRectAsData {
    if ([inQDRectAsData length] == sizeof(Rect)) {
        const Rect *qdBounds = (const Rect *)[inQDRectAsData bytes];
        NSRect newBounds = SKNSRectFromQDRect(*qdBounds);
        [[self pdfView] setSelectToolRect:newBounds];
    }
}

- (id)selectionPage {
    return [[self pdfView] selectToolPage];
}

- (void)setSelectionPage:(PDFPage *)page {
    [[self pdfView] setSelectToolPage:[page isKindOfClass:[PDFPage class]] ? page : nil];
}

- (NSArray *)noteSelection {
    return [[self primaryWindowController] selectedNotes];
}

- (void)setNoteSelection:(NSArray *)newNoteSelection {
    return [[self primaryWindowController] setSelectedNotes:newNoteSelection];
}

- (NSDictionary *)pdfViewSettings {
    return [[self pdfView] displaySettings];
}

- (void)setPdfViewSettings:(NSDictionary *)pdfViewSettings {
    [[self pdfView] setDisplaySettings:pdfViewSettings];
}

- (NSInteger)toolMode {
    NSInteger toolMode = [[self pdfView] toolMode];
    if (toolMode == SKToolModeNote)
        toolMode += [[self pdfView] annotationMode];
    return toolMode;
}

- (void)setToolMode:(NSInteger)newToolMode {
    if (newToolMode >= SKToolModeNote) {
        [[self pdfView] setAnnotationMode:newToolMode - SKToolModeNote];
        newToolMode = SKToolModeNote;
    }
    [[self pdfView] setToolMode:newToolMode];
}

- (NSDocument *)presentationNotesDocument {
    return [[self primaryWindowController] presentationNotesDocument];
}

- (void)setPresentationNotesDocument:(NSDocument *)document {
    if ([document isPDFDocument] && [document countOfPages] == [self countOfPages]) {
        [[self primaryWindowController] setPresentationNotesDocument:document];
        if (document != self)
            [[self primaryWindowController] setPresentationNotesOffset:0];
    }
}

- (NSInteger)presentationNotesOffset {
    return [[self primaryWindowController] presentationNotesOffset];
}

- (void)setPresentationNotesOffset:(NSInteger)offset {
    [[self primaryWindowController] setPresentationNotesOffset:offset];
}

- (BOOL)isPDFDocument {
    return YES;
}

- (id)readingBar {
    return [[self pdfView] readingBar];
}

- (BOOL)hasReadingBar {
    return [[self pdfView] hasReadingBar];
}

- (void)setHasReadingBar:(BOOL)flag {
    if ([[self pdfView] hasReadingBar] != flag)
        [[self pdfView] toggleReadingBar];
}

- (id)newScriptingObjectOfClass:(Class)class forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([key isEqualToString:@"notes"]) {
        PDFAnnotation *annotation = nil;
        id selSpec = contentsValue ?: [[[[NSScriptCommand currentCommand] arguments] objectForKey:@"KeyDictionary"] objectForKey:SKPDFAnnotationSelectionSpecifierKey];
        PDFSelection *sel = selSpec ? [PDFSelection selectionWithSpecifiers:selSpec] : nil;
        PDFPage *page = [sel safeFirstPage];
        if (page == nil || [page document] != [self pdfDocument]) {
            [[NSScriptCommand currentCommand] setScriptErrorNumber:NSReceiversCantHandleCommandScriptError]; 
            [[NSScriptCommand currentCommand] setScriptErrorString:@"No page or wrong document for new note."];
        } else {
            annotation = [page newScriptingObjectOfClass:class forValueForKey:key withContentsValue:sel ?: contentsValue properties:properties];
            if ([annotation respondsToSelector:@selector(setPage:)])
                [annotation performSelector:@selector(setPage:) withObject:page];
        }
        return annotation;
    }
    return [super newScriptingObjectOfClass:class forValueForKey:key withContentsValue:contentsValue properties:properties];
}

- (id)copyScriptingValue:(id)value forKey:(NSString *)key withProperties:(NSDictionary *)properties {
    if ([key isEqualToString:@"notes"]) {
        NSMutableArray *copiedValue = [[NSMutableArray alloc] init];
        for (PDFAnnotation *annotation in value) {
            if ([annotation isMovable] && [[annotation page] document] == [self pdfDocument]) {
                PDFAnnotation *copiedAnnotation = [PDFAnnotation newSkimNoteWithProperties:[annotation SkimNoteProperties]];
                [copiedAnnotation registerUserName];
                if ([copiedAnnotation respondsToSelector:@selector(setPage:)])
                    [copiedAnnotation performSelector:@selector(setPage:) withObject:[annotation page]];
                if ([properties count])
                    [copiedAnnotation setScriptingProperties:[copiedAnnotation coerceValue:properties forKey:@"scriptingProperties"]];
                [copiedValue addObject:copiedAnnotation];
            } else {
                // we don't want to duplicate markup
                NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
                [cmd setScriptErrorString:@"Cannot duplicate markup note."];
                copiedValue = nil;
            }
        }
        return copiedValue;
    }
    return [super copyScriptingValue:value forKey:key withProperties:properties];
}

- (id)handleSaveScriptCommand:(NSScriptCommand *)command {
	NSDictionary *args = [command arguments];
    id fileType = [args objectForKey:@"FileType"];
    id file = [args objectForKey:@"File"];
    // we don't want to expose the UTI types to the user, and we allow template file names without extension
    if (fileType && file) {
        NSString *normalizedType = nil;
        NSInteger option = SKExportOptionDefault;
        NSArray *writableTypes = [self writableTypesForSaveOperation:NSSaveToOperation];
        SKTemplateManager *tm = [SKTemplateManager sharedManager];
        if ([fileType isEqualToString:@"PDF"]) {
            normalizedType = SKDocumentTypePDF;
        } else if ([fileType isEqualToString:@"PDF With Embedded Notes"]) {
            normalizedType = SKDocumentTypePDF;
            option = SKExportOptionWithEmbeddedNotes;
        } else if ([fileType isEqualToString:@"PDF Without Notes"]) {
            normalizedType = SKDocumentTypePDF;
            option = SKExportOptionWithoutNotes;
        } else if ([fileType isEqualToString:@"PostScript"]) {
            normalizedType = [[NSWorkspace sharedWorkspace] type:[self fileType] conformsToType:SKDocumentTypeEncapsulatedPostScript] ? SKDocumentTypeEncapsulatedPostScript : SKDocumentTypePostScript;
        } else if ([fileType isEqualToString:@"PostScript Without Notes"]) {
            normalizedType = [[NSWorkspace sharedWorkspace] type:[self fileType] conformsToType:SKDocumentTypeEncapsulatedPostScript] ? SKDocumentTypeEncapsulatedPostScript : SKDocumentTypePostScript;
            option = SKExportOptionWithoutNotes;
        } else if ([fileType isEqualToString:@"Encapsulated PostScript"]) {
            normalizedType = SKDocumentTypeEncapsulatedPostScript;
        } else if ([fileType isEqualToString:@"Encapsulated PostScript Without Notes"]) {
            normalizedType = SKDocumentTypeEncapsulatedPostScript;
            option = SKExportOptionWithoutNotes;
        } else if ([fileType isEqualToString:@"DVI"]) {
            normalizedType = SKDocumentTypeDVI;
        } else if ([fileType isEqualToString:@"DVI Without Notes"]) {
            normalizedType = SKDocumentTypeDVI;
            option = SKExportOptionWithoutNotes;
        } else if ([fileType isEqualToString:@"XDV"]) {
            normalizedType = SKDocumentTypeXDV;
        } else if ([fileType isEqualToString:@"XDV Without Notes"]) {
            normalizedType = SKDocumentTypeXDV;
            option = SKExportOptionWithoutNotes;
        } else if ([fileType isEqualToString:@"PDF Bundle"]) {
            normalizedType = SKDocumentTypePDFBundle;
        } else if ([fileType isEqualToString:@"Skim Notes"]) {
            normalizedType = SKDocumentTypeNotes;
        } else if ([fileType isEqualToString:@"Notes as Text"]) {
            normalizedType = SKDocumentTypeNotesText;
        } else if ([fileType isEqualToString:@"Notes as RTF"]) {
            normalizedType = SKDocumentTypeNotesRTF;
        } else if ([fileType isEqualToString:@"Notes as RTFD"]) {
            normalizedType = SKDocumentTypeNotesRTFD;
        } else if ([fileType isEqualToString:@"Notes as FDF"]) {
            normalizedType = SKDocumentTypeNotesFDF;
        } else if ([writableTypes containsObject:fileType] == NO) {
            normalizedType = [tm templateTypeForDisplayName:fileType];
        }
        if ((normalizedType && [writableTypes containsObject:normalizedType]) || [tm fileNameExtensionForTemplateType:fileType]) {
            mdFlags.exportOption = option;
            NSMutableDictionary *arguments = [args mutableCopy];
            if (normalizedType) {
                fileType = normalizedType;
                [arguments setObject:fileType forKey:@"FileType"];
            }
            // for some reason the default implementation adds the extension twice for template types
            if ([[file pathExtension] isCaseInsensitiveEqual:[tm fileNameExtensionForTemplateType:fileType]])
                [arguments setObject:[file URLByDeletingPathExtension] forKey:@"File"];
            [command setArguments:arguments];
        }
    }
    return [super handleSaveScriptCommand:command];
}

- (void)handleRevertScriptCommand:(NSScriptCommand *)command {
    if ([self fileURL] && [[self fileURL] checkResourceIsReachableAndReturnError:NULL]) {
        if ([fileUpdateChecker isUpdatingFile] == NO && [self revertToContentsOfURL:[self fileURL] ofType:[self fileType] error:NULL] == NO) {
            [command setScriptErrorNumber:NSInternalScriptError];
            [command setScriptErrorString:@"Revert failed."];
        }
    } else {
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
        [command setScriptErrorString:@"File does not exist."];
    }
}

- (void)handleGoToScriptCommand:(NSScriptCommand *)command {
	NSDictionary *args = [command evaluatedArguments];
    id location = [args objectForKey:@"To"];
    
    if ([location isKindOfClass:[PDFPage class]]) {
        id pointData = [args objectForKey:@"At"];
        if ([primaryWindowController interactionMode] == SKPresentationMode) {
            [primaryWindowController setCurrentPage:(PDFPage *)location];
        } else if ([pointData isKindOfClass:[NSData class]]) {
            NSPoint point = [(NSData *)pointData pointValueAsQDPoint];
            [[self pdfView] goToDestination:[[PDFDestination alloc] initWithPage:(PDFPage *)location atPoint:point]];
        } else {
            [[self pdfView] goAndScrollToPage:(PDFPage *)location];
        }
    } else if ([primaryWindowController interactionMode] == SKPresentationMode) {
    } else if ([location isKindOfClass:[PDFAnnotation class]]) {
        [[self pdfView] scrollAnnotationToVisible:(PDFAnnotation *)location];
    } else if ([location isKindOfClass:[PDFOutline class]]) {
        PDFDestination *dest = [(PDFOutline *)location destination];
        if (dest) {
            [[self pdfView] goToDestination:dest];
        } else {
            PDFAction *action = [(PDFOutline *)location action];
            if (action)
                 [[self pdfView] performAction:action];
        }
    } else if ([location isKindOfClass:[SKLine class]]) {
        PDFPage *page = [(SKLine *)location page];
        NSRect bounds = [(SKLine *)location bounds];
        [[self pdfView] goToRect:bounds onPage:page];
    } else if ([location isKindOfClass:[NSNumber class]]) {
        id source = [args objectForKey:@"Source"];
        NSInteger options = SKPDFSynchronizerDefault;
        BOOL showBar = [[args objectForKey:@"ShowReadingBar"] boolValue];
        if (showBar)
            options |= SKPDFSynchronizerShowReadingBar;
        if ([[args objectForKey:@"Selecting"] boolValue] || (showBar == NO && [args objectForKey:@"Selecting"] == nil))
            options |= SKPDFSynchronizerSelect;
        if ([source isKindOfClass:[NSString class]])
            source = [NSURL fileURLWithPath:source isDirectory:NO];
        else if ([source isKindOfClass:[NSURL class]] == NO)
            source = nil;
        [[self synchronizer] findPageAndLocationForLine:[location integerValue] inFile:[source path] fromPageIndex:[[[self pdfView] currentPage] pageIndex] options:options];
    } else {
        PDFSelection *selection = [PDFSelection selectionWithSpecifiers:[[command arguments] objectForKey:@"To"]];
        if ([selection hasCharacters]) {
            PDFPage *page = [selection safeFirstPage];
            NSRect bounds = [selection boundsForPage:page];
            [[self pdfView] goToRect:bounds onPage:page];
        }
    }
}

- (id)handleFindScriptCommand:(NSScriptCommand *)command {
	NSDictionary *args = [command evaluatedArguments];
    id text = [args objectForKey:@"Text"];
    id specifier = nil;
    
    if ([text isKindOfClass:[NSString class]] == NO) {
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
        [command setScriptErrorString:@"The text to find is missing or is not a string."];
        return nil;
    } else {
        id from = [[command arguments] objectForKey:@"From"];
        id backward = [args objectForKey:@"Backward"];
        id caseSensitive = [args objectForKey:@"CaseSensitive"];
        PDFSelection *selection = nil;
        NSInteger options = 0;
        
        if (from)
            selection = [PDFSelection selectionWithSpecifiers:from];
        
        if ([backward isKindOfClass:[NSNumber class]] && [backward boolValue])
            options |= NSBackwardsSearch;
        if ([caseSensitive isKindOfClass:[NSNumber class]] == NO || [caseSensitive boolValue] == NO)
            options |= NSCaseInsensitiveSearch;
        
        if ((selection = [[self pdfDocument] findString:text fromSelection:selection withOptions:options]))
            specifier = [selection objectSpecifiers];
    }
    
    return specifier ?: @[];
}

- (void)handleEditScriptCommand:(NSScriptCommand *)command {
	NSDictionary *args = [command evaluatedArguments];
    id page = [args objectForKey:@"Page"];
    id pointData = [args objectForKey:@"Point"];
    NSPoint point = NSZeroPoint;
    
    if ([page isKindOfClass:[PDFPage class]] == NO)
        page = [[self pdfView] currentPage];
    if ([pointData isKindOfClass:[NSDate class]]) {
        point = [pointData pointValueAsQDPoint];
    } else {
        NSRect bounds = [page boundsForBox:[[self pdfView] displayBox]];
        point = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    }
    if (page) {
        NSUInteger pageIndex = [page pageIndex];
        PDFSelection *sel = [page selectionForLineAtPoint:point];
        NSRect rect = [sel hasCharacters] ? [sel boundsForPage:page] : NSMakeRect(point.x - 20.0, point.y - 5.0, 40.0, 10.0);
        
        [[self synchronizer] findFileAndLineForLocation:point inRect:rect pageBounds:[page boundsForBox:kPDFDisplayBoxMediaBox] atPageIndex:pageIndex];
    }
}

- (void)handleConvertNotesScriptCommand:(NSScriptCommand *)command {
    if ([[NSWorkspace sharedWorkspace] type:[self fileType] conformsToType:SKDocumentTypePDF] == NO && [[NSWorkspace sharedWorkspace] type:[self fileType] conformsToType:SKDocumentTypePDFBundle] == NO) {
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
    } else if (mdFlags.convertingNotes || [[self pdfDocument] isLocked]) {
        [command setScriptErrorNumber:NSInternalScriptError];
    } else if ([self hasConvertibleAnnotations]) {
        NSDictionary *args = [command evaluatedArguments];
        NSNumber *wait = [args objectForKey:@"Wait"];
        if (wait == nil || [wait boolValue]) {
            __block BOOL finished = NO;
            __block BOOL suspended = NO;
            [self convertNotesWithCompletionHandler:^{
                if (suspended)
                    [command resumeExecutionWithResult:nil];
                finished = YES;
            }];
            if (finished == NO) {
                [command suspendExecution];
                suspended = YES;
            }
        } else {
            [self convertNotesWithCompletionHandler:nil];
        }
    }
}

- (void)handleReadNotesScriptCommand:(NSScriptCommand *)command {
    NSDictionary *args = [command evaluatedArguments];
    NSURL *notesURL = [args objectForKey:@"File"];
    if (notesURL == nil) {
        [command setScriptErrorNumber:NSRequiredArgumentsMissingScriptError];
    } else if ([[self pdfDocument] isLocked]) {
        [command setScriptErrorNumber:NSInternalScriptError];
    } else {
        NSNumber *replaceNumber = [args objectForKey:@"Replace"];
        NSString *fileType = [[NSDocumentController sharedDocumentController] typeForContentsOfURL:notesURL error:NULL];
        if ([[NSWorkspace sharedWorkspace] type:fileType conformsToType:SKDocumentTypeNotes])
            [self readNotesFromURL:notesURL replace:(replaceNumber ? [replaceNumber boolValue] : YES)];
        else
            [command setScriptErrorNumber:NSArgumentsWrongScriptError];
    }
}

- (void)handleShareScriptCommand:(NSScriptCommand *)command {
    NSURL *fileURL = [self fileURL];
    if (fileURL == nil) {
        NSBeep();
        return;
    }
    
    NSSharingService *service = nil;
    NSString *name = [[command evaluatedArguments] objectForKey:@"Service"];
    if (name == nil) {
        service = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];
    } else {
        NSArray *services = [NSSharingService sharingServicesForItems:@[fileURL]];
        NSUInteger i = [[services valueForKey:@"title"] indexOfObject:name];
        if (i == NSNotFound) {
            NSBeep();
            return;
        }
        service = [services objectAtIndex:i];
    }
    
    BOOL shouldArchive = ([self hasNotes] || [[self presentationOptions] count] > 0);
    NSString *typeName = [self fileType];
    if (shouldArchive == NO && [typeName isEqualToString:SKDocumentTypePDFBundle])
        typeName = SKDocumentTypePDF;
    
    NSString *typeExt = [self fileNameExtensionForType:typeName saveOperation:NSAutosaveElsewhereOperation];
    NSString *targetExt = shouldArchive ? @"tgz" : typeExt;
    NSString *targetFileName = [fileURL lastPathComponentReplacingPathExtension:targetExt];
    if (targetFileName == nil)
        targetFileName = [[self displayName] stringByAppendingPathExtension:targetExt];
    
    NSURL *targetDirURL = [[NSFileManager defaultManager] uniqueChewableItemsDirectoryURL];
    NSURL *targetFileURL = [targetDirURL URLByAppendingPathComponent:targetFileName isDirectory:NO];
    NSURL *tmpURL = nil;
    fileURL = targetFileURL;
    
    if (shouldArchive) {
        tmpURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:targetFileURL create:YES error:NULL];
        fileURL = [[tmpURL URLByAppendingPathComponent:targetFileName isDirectory:NO] URLReplacingPathExtension:typeExt];
    }
    
    if ([self writeSafelyToURL:fileURL ofType:typeName forSaveOperation:NSAutosaveElsewhereOperation error:NULL] == NO) {
        NSBeep();
        return;
    }
    
    if (shouldArchive) {
        NSTask *task = [self taskForWritingArchiveAtURL:targetFileURL fromURL:fileURL];
        [service setSubject:[self displayName]];
        
        [SKFileShare shareURL:targetFileURL
               preparedByTask:task
                 usingService:service
            completionHandler:^(BOOL success){
                NSFileManager *fm = [NSFileManager defaultManager];
                [fm removeItemAtURL:tmpURL error:NULL];
                if (success == NO) {
                    [fm removeItemAtURL:targetDirURL error:NULL];
                    NSBeep();
                }
            }];
    } else {
        NSArray *items = @[targetFileURL];
        if ([service canPerformWithItems:items]) {
            [service setSubject:[self displayName]];
            [service performWithItems:items];
        } else {
            [[NSFileManager defaultManager] removeItemAtURL:targetDirURL error:NULL];
        }
    }
}

@end
