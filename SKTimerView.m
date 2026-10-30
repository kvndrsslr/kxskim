//
//  SKTimerView.m
//  Skim
//
//  Created by Christiaan Hofmanon 20/10/2026.
/*
 This software is Copyright (c) 2026
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

#import "SKTimerView.h"

#define DEFAULT_WIDTH 40.0
#define DEFAULT_HEIGHT 40.0
#define DEFAULT_OUTSET 30.0
#define FONT_SIZE 36.0
#define TEXT_OFFSET 2.0

@implementation SKTimerView

@synthesize showsTime;

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, DEFAULT_WIDTH, DEFAULT_HEIGHT)];
    if (self) {
        imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0.0, 0.0, DEFAULT_WIDTH, DEFAULT_HEIGHT)];
        [imageView setImage:[NSImage imageWithSize:NSMakeSize(DEFAULT_WIDTH, DEFAULT_HEIGHT) flipped:NO drawingHandler:^(NSRect rect){
            NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(rect, 4.0, 4.0)];
            [path moveToPoint:NSMakePoint(NSMidX(rect), NSMidY(rect) + 10.0)];
            [path relativeLineToPoint:NSMakePoint(0.0, -10.0)];
            [path relativeLineToPoint:NSMakePoint(5.0, -3.0)];
            [path setLineCapStyle:NSRoundLineCapStyle];
            [path setLineWidth:4.0];
            [[NSColor whiteColor] setStroke];
            [path stroke];
            [path setLineWidth:2.0];
            [[NSColor blackColor] setStroke];
            [path stroke];
            return YES;
        }]];
        [imageView setToolTip:NSLocalizedString(@"Start timer", @"Tool tip message")];
        [imageView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:imageView];
        [self setTranslatesAutoresizingMaskIntoConstraints:NO];
        widthConstraint = [[self widthAnchor] constraintEqualToConstant:DEFAULT_WIDTH];
        [NSLayoutConstraint activateConstraints:@[
            widthConstraint,
            [[self heightAnchor] constraintEqualToConstant:DEFAULT_HEIGHT],
            [[imageView centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[self centerYAnchor] constraintEqualToAnchor:[imageView centerYAnchor]]
        ]];
        [self setWantsLayer:YES];
        [[self layer] setCornerRadius:0.5 * DEFAULT_HEIGHT];
        [[self layer] setMasksToBounds:YES];
    }
    return self;
}

- (void)dealloc {
    [timer invalidate];
    timer = nil;
}

- (void)updateTime {
    NSUInteger time = round(-[startDate timeIntervalSinceNow]);
    NSUInteger sec = time % 60;
    NSUInteger min = time / 60;
    NSUInteger hour = min / 60;
    min = min % 60;
    BOOL shouldResize = NO;
    if (hour > 0) {
        if (showsTime && sec < 2 && min == 0 && (hour == 1 || hour == 10))
            shouldResize = [[textField stringValue] length] < (hour == 10 ? 8 : 7);
        [textField setStringValue:[NSString stringWithFormat:@"%lu:%.2lu:%.2lu", hour, min, sec]];
    } else {
        if (showsTime && sec < 2 && min == 10)
            shouldResize = [[textField stringValue] length] < 5;
        [textField setStringValue:[NSString stringWithFormat:@"%lu:%.2lu", min, sec]];
    }
    if (shouldResize)
        [[widthConstraint animator] setConstant:[textField intrinsicContentSize].width + DEFAULT_OUTSET];
}

- (void)mouseDown:(NSEvent *)event {
    if (showsTime == NO) {
        if (timer == nil) {
            startDate = [NSDate date];
            __weak typeof(self) weakSelf = self;
            timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *aTimer){
                [weakSelf updateTime];
            }];
        }
        if (bgView == nil) {
            bgView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0.0, 0.0, DEFAULT_WIDTH, DEFAULT_HEIGHT)];
            if (@available(macOS 10.14, *))
                [bgView setMaterial:NSVisualEffectMaterialHUDWindow];
            else
                [bgView setMaterial:NSVisualEffectMaterialDark];
            [bgView setState:NSVisualEffectStateActive];
            [bgView setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
            if (@available(macOS 10.14, *))
                [bgView setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
            [bgView setTranslatesAutoresizingMaskIntoConstraints:NO];
        }
        if (textField == nil) {
            textField = [[NSTextField alloc] init];
            [textField setBezeled:NO];
            [textField setBordered:NO];
            [textField setDrawsBackground:NO];
            [textField setEditable:NO];
            [textField setSelectable:NO];
            [textField setTextColor:[NSColor whiteColor]];
            [textField setFont:[NSFont monospacedDigitSystemFontOfSize:FONT_SIZE weight:NSFontWeightMedium]];
            [textField setAlignment:NSTextAlignmentCenter];
            [textField setTranslatesAutoresizingMaskIntoConstraints:NO];
            [textField setStringValue:@"0:00"];
            [textField setToolTip:NSLocalizedString(@"Hide timer", @"Tool tip message")];
            [imageView setToolTip:NSLocalizedString(@"Show timer", @"Tool tip message")];
        }
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [[self animator] replaceSubview:imageView with:textField];
            [NSLayoutConstraint activateConstraints:@[
                [[textField centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
                [[self centerYAnchor] constraintEqualToAnchor:[textField centerYAnchor] constant:TEXT_OFFSET]
            ]];
            [[self animator] addSubview:bgView positioned:NSWindowBelow relativeTo:nil];
            [NSLayoutConstraint activateConstraints:@[
                [[bgView leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
                [[self trailingAnchor] constraintEqualToAnchor:[bgView trailingAnchor]],
                [[bgView topAnchor] constraintEqualToAnchor:[self topAnchor]],
                [[self bottomAnchor] constraintEqualToAnchor:[bgView bottomAnchor]]
            ]];
            [[widthConstraint animator] setConstant:[textField intrinsicContentSize].width + DEFAULT_OUTSET];
        }];
        showsTime = YES;
    } else {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [[bgView animator] removeFromSuperview];
            [[self animator] replaceSubview:textField with:imageView];
            [NSLayoutConstraint activateConstraints:@[
                [[imageView centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
                [[self centerYAnchor] constraintEqualToAnchor:[imageView centerYAnchor]]
            ]];
            [[widthConstraint animator] setConstant:DEFAULT_WIDTH];
        }];
        showsTime = NO;
    }
}

@end
