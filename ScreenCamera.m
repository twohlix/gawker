//
//  ScreenCamera.m
//  Gawker
//
//  Created by phil piwonka on 3/7/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "ScreenCamera.h"
#import "ScreenCameraController.h"
#import "ImageTransitionView.h"

@implementation ScreenCamera

- (id)init
{
    self = [super initWithWindowNibName:@"ScreenCamera"];
	
	screenNumber = 0;
    if (self) {
        if (camController){ [camController release]; }
		camController = [[ScreenCameraController alloc] initWithDelegate:self andScreenNumber:screenNumber];
        if (camController) {
            [[self window] setTitle:[NSString stringWithFormat:@"%d", screenNumber]];
			[(ScreenCameraController *)camController setScreenToGrab:screenNumber];
            icon = [[NSImage imageNamed:@"NSApplicationIcon"] retain];
            recentImage = [[NSImage imageNamed:@"window_nib.tiff"] retain];
        }
    }
	
    return self;
}

- (id)initWithScreenNumber:(int)screenNum
{
    self = [super initWithWindowNibName:@"ScreenCamera"];
	
	screenNumber = screenNum;
    if (self) {
		if (camController){ [camController release]; }
        camController = [[ScreenCameraController alloc] initWithDelegate:self andScreenNumber:screenNumber];
        if (camController) {
            [[self window] setTitle:[NSString stringWithFormat:@"%d", screenNumber]];
			[(ScreenCameraController *)camController setScreenToGrab:screenNumber];
            icon = [[NSImage imageNamed:@"NSApplicationIcon"] retain];
            recentImage = [[NSImage imageNamed:@"window_nib.tiff"] retain];
        }
    }
	
    return self;
}



- (void)awakeFromNib
{
    [super awakeFromNib];
    [imageTransitionView setAnimate:NO];
    [imageTransitionView setImage:[NSImage imageNamed:@"desktop.png"]];
}

- (void)setSourceEnabled:(BOOL)enable openWindow:(BOOL)open
{
    [super setSourceEnabled:enable openWindow:open];
    [imageTransitionView setImage:[NSImage imageNamed:@"desktop.png"]];
}
- (void)showEnableError
{
    NSBeep();
    NSRunAlertPanel(@"Error Enabling Screen Capture",
                    @"Something must be really wrong!",
                    @"OK", nil, nil);
}

- (NSImage *)recentImage
{
    NSImage *image = icon;

    if ([self isSourceEnabled]) {
        image = recentImage;
    }

    return image;
}

//
// Record panel handlers
//
- (void)recordDidEnd:(NSSavePanel *)sheet
          returnCode:(int)code
         contextInfo:(void *)contextInfo
{
    [super recordDidEnd:sheet
           returnCode:code
           contextInfo:contextInfo];

    if ([camController isRecording]) {
        double interval = [saveFrameInterval floatValue];
        [(ScreenCameraController *)camController captureFrameAtInterval:interval];
    }
}

- (void)windowDidLoad
{
    [[self window] setFrameAutosaveName:@"ScreenCamera"];
}

- (void)windowDidMove:(NSNotification *)note
{
    [[self window] saveFrameUsingName:@"ScreenCamera"];
    //int screenNum = [[NSScreen screens] indexOfObject:[[self window] screen]];
    [(ScreenCameraController *)camController setScreenToGrab:screenNumber];
    [super windowDidMove:note];
}

- (IBAction)showWindow:(id)sender
{
    [super showWindow:sender];
    //int screenNum = [[NSScreen screens] indexOfObject:[[self window] screen]];
    [(ScreenCameraController *)camController setScreenToGrab:screenNumber];
}

@end
