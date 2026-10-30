//
//  SKAlias.m
//  Skim
//
//  Created by Christiaan Hofman on 1/21/13.
/*
 This software is Copyright (c) 2013
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

#import "SKAlias.h"
#import "NSString_SKExtensions.h"

#define NSURLFileIDKey @"_NSURLFileIDKey"

@implementation SKAlias

@dynamic data, bookmark, fileURL, fileURLNoUI, name;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline AliasHandle createAliasHandleFromData(NSData *data) {
    NSUInteger len = [data length];
    Handle handle = NewHandle(len);
    if (handle != NULL && len > 0) {
        HLock(handle);
        memmove((void *)*handle, (const void *)[data bytes], len);
        HUnlock(handle);
    }
    return (AliasHandle)handle;
}

static inline NSData *dataFromAliasHandle(AliasHandle aliasHandle) {
    NSData *data = nil;
    Handle handle = (Handle)aliasHandle;
    NSUInteger len = GetHandleSize(handle);
    SInt8 handleState = HGetState(handle);
    HLock(handle);
    data = [NSData dataWithBytes:(const void *)*handle length:len];
    HSetState(handle, handleState);
    return data;
}

static inline NSURL *fileURLFromAliasHandle(AliasHandle aliasHandle, NSUInteger mountFlags) {
    FSRef fileRef;
    Boolean wasChanged;
    if (noErr == FSResolveAliasWithMountFlags(NULL, aliasHandle, &fileRef, &wasChanged, mountFlags))
        return (NSURL *)CFBridgingRelease(CFURLCreateFromFSRef(kCFAllocatorDefault, &fileRef));
    return nil;
}

static inline void disposeAliasHandle(AliasHandle aliasHandle) {
    if (aliasHandle) DisposeHandle((Handle)aliasHandle);
}
#pragma clang diagnostic pop

- (instancetype)initWithAliasData:(NSData *)aliasData {
    if (aliasData == nil) {
        self = nil;
    } else {
        self = [super init];
        if (self) {
            data = (NSData *)CFBridgingRelease(CFURLCreateBookmarkDataFromAliasRecord(NULL, (__bridge CFDataRef)aliasData));
            if (data == nil) {
                aliasHandle = createAliasHandleFromData(aliasData);
                if (aliasHandle == NULL) {
                    self = nil;
                }
            }
        }
    }
    return self;
}

- (instancetype)initWithBookmarkData:(NSData *)bookmarkData {
    if (bookmarkData == nil) {
        self = nil;
    } else {
        self = [super init];
        if (self) {
            data = bookmarkData;
        }
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)fileURL {
    return [self initWithBookmarkData:[fileURL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:NULL]];
}

- (void)dealloc {
    disposeAliasHandle(aliasHandle);
    aliasHandle = NULL;
}

- (NSData *)data {
    if (aliasHandle)
        // try to convert alias to bookmark data
        [self fileURLNoUI];
    if (aliasHandle)
        // we could return data if present when fileURLNoUI is nil
        return dataFromAliasHandle(aliasHandle) ?: data;
    else
        return data;
}

- (BOOL)isBookmark {
    return aliasHandle == nil && data != nil;
}

- (void)updateWithURL:(NSURL *)fileURL {
    NSData *bmData = [fileURL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];
    if (bmData) {
        if (aliasHandle)
            disposeAliasHandle(aliasHandle);
        data = bmData;
    }
}

- (NSURL *)fileURL {
    NSURL *fileURL = nil;
    BOOL shouldUpdate = NO;
    if (aliasHandle) {
        fileURL = fileURLFromAliasHandle(aliasHandle, 0);
        shouldUpdate = YES;
    } else if (data) {
        fileURL = [NSURL URLByResolvingBookmarkData:data options:0 relativeToURL:nil bookmarkDataIsStale:&shouldUpdate error:NULL];
    }
    if (shouldUpdate && fileURL)
        [self updateWithURL:fileURL];
    return fileURL;
}

- (NSURL *)fileURLNoUI {
    NSURL *fileURL = nil;
    BOOL shouldUpdate = NO;
    if (aliasHandle) {
        fileURL = fileURLFromAliasHandle(aliasHandle, kResolveAliasFileNoUI);
        shouldUpdate = YES;
    } else if (data) {
        NSString *path = [[[NSURL resourceValuesForKeys:@[NSURLPathKey] fromBookmarkData:data] objectForKey:NSURLPathKey] stringByStandardizingPath];
        if (path) {
            fileURL = [NSURL fileURLWithPath:path isDirectory:[[path pathExtension] isCaseInsensitiveEqual:@"pdfd"]];
            if ([fileURL checkResourceIsReachableAndReturnError:NULL]) {
                NSNumber *fileID = nil;
                NSNumber *myFileID = [[NSURL resourceValuesForKeys:@[NSURLFileIDKey] fromBookmarkData:data] objectForKey:NSURLFileIDKey];
                if (myFileID && [fileURL getResourceValue:&fileID forKey:NSURLFileIDKey error:NULL] && [fileID isEqual:myFileID] == NO)
                    shouldUpdate = YES;
            } else {
                fileURL = nil;
            }
        }
        if (fileURL == nil)
            fileURL = [NSURL URLByResolvingBookmarkData:data options:NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting relativeToURL:nil bookmarkDataIsStale:&shouldUpdate error:NULL];
    }
    if (shouldUpdate && fileURL)
        [self updateWithURL:fileURL];
    return fileURL;
}

- (BOOL)resolvesToFileURL:(NSURL *)fileURL {
    NSURL *myFileURL = nil;
    BOOL shouldUpdate = NO;
    if (aliasHandle) {
        myFileURL = fileURLFromAliasHandle(aliasHandle, kResolveAliasFileNoUI);
        shouldUpdate = YES;
    } else if (data) {
        NSArray *keys = @[NSURLPathKey, NSURLFileIDKey, NSURLVolumeUUIDStringKey];
        NSDictionary *rsrcValues = [fileURL resourceValuesForKeys:keys error:NULL];
        NSDictionary *myRsrcValues = [NSURL resourceValuesForKeys:keys fromBookmarkData:data];
        NSString *path = [[rsrcValues objectForKey:NSURLPathKey] stringByStandardizingPath];
        NSString *myPath = [[myRsrcValues objectForKey:NSURLPathKey] stringByStandardizingPath];
        if (path && myPath) {
            NSNumber *fileID = [rsrcValues objectForKey:NSURLFileIDKey];
            NSNumber *myFileID = [myRsrcValues objectForKey:NSURLFileIDKey];
            if ([path isCaseInsensitiveEqual:myPath]) {
                if (fileID && myFileID && [fileID isEqual:myFileID] == NO)
                    [self updateWithURL:fileURL];
                return YES;
            }
            myFileURL = [NSURL fileURLWithPath:myPath isDirectory:[[myPath pathExtension] isCaseInsensitiveEqual:@"pdfd"]];
            if ([myFileURL checkResourceIsReachableAndReturnError:NULL]) {
                if (fileID && myFileID && [fileID isEqual:myFileID] == NO)
                    [self updateWithURL:myFileURL];
                return NO;
            }
            if (fileID && myFileID) {
                if ([fileID isEqual:myFileID] == NO)
                    return NO;
                NSString *volumeUUID = [rsrcValues objectForKey:NSURLVolumeUUIDStringKey];
                NSString *myVolumeUUID = [myRsrcValues objectForKey:NSURLVolumeUUIDStringKey];
                if (volumeUUID && myVolumeUUID) {
                    if ([volumeUUID isEqualToString:myVolumeUUID] == NO)
                        return NO;
                    [self updateWithURL:fileURL];
                    return YES;
                }
            }
        }
        NSURLBookmarkResolutionOptions options = NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting;
        myFileURL = [NSURL URLByResolvingBookmarkData:data options:options relativeToURL:nil bookmarkDataIsStale:&shouldUpdate error:NULL];
    }
    if (myFileURL == nil)
        return NO;
    if (shouldUpdate)
        [self updateWithURL:myFileURL];
    return [[myFileURL path] isCaseInsensitiveEqual:[fileURL path]];
}

- (NSString *)name {
    NSString *name = nil;
    NSURL *fileURL = [self fileURLNoUI];
    if ((fileURL == nil || NO == [fileURL getResourceValue:&name forKey:NSURLLocalizedNameKey error:NULL]) && aliasHandle == nil)
        name = [[NSURL resourceValuesForKeys:@[NSURLNameKey] fromBookmarkData:data] objectForKey:NSURLNameKey] ?: [[[NSURL resourceValuesForKeys:@[NSURLPathKey] fromBookmarkData:data] objectForKey:NSURLPathKey] lastPathComponent];
    return name;
}

- (NSString *)fileType {
    NSString *type = nil;
    NSURL *fileURL = [self fileURLNoUI];
    if (fileURL) {
        type = [[NSWorkspace sharedWorkspace] typeOfFile:[fileURL path] error:NULL];
    } else if (aliasHandle == nil) {
        NSString *ext = [[[NSURL resourceValuesForKeys:@[NSURLPathKey] fromBookmarkData:data] objectForKey:NSURLPathKey] pathExtension];
        if (ext)
            type = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL));
    }
    return type;
}

@end
