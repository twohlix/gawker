//
//  CameraController.m
//  Gawker
//
//  Created by Phil Piwonka on 10/9/05.
//  Copyright 2005 Phil Piwonka. All rights reserved.
//

#import "CameraController.h"
#import "LapseMovie.h"
#import "ImageText.h"

@interface CameraController (PrivateMethods)
- (void)registerForNotifications;
- (void)receivedImageNotification:(NSNotification *)note;
- (void)sourceConnected:(NSNotification *)note;
- (void)sourceDisconnected:(NSNotification *)note;
@end

@implementation CameraController

- (id)initWithDelegate:(id)newDelegate
{
    if (self = [super init]) {
        isRecording = NO;
        delegate = newDelegate;
		
		if(timeTextAttributes != nil)[timeTextAttributes release];
        timeTextAttributes = [[NSMutableDictionary alloc] init];
		NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowOffset:NSMakeSize(1.1, -1.1)];
        [shadow setShadowBlurRadius:0.3];
        [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0
                                        alpha:0.8]];
        
		[timeTextAttributes setObject:[NSColor whiteColor]
                            forKey:NSForegroundColorAttributeName];        
        [timeTextAttributes setObject:shadow
                            forKey:NSShadowAttributeName];        
		[shadow release];
		
        putTimeOnImage = NO;
        scaleFactor = 1.0;
    }
    return self;
}

- (id)init
{
    return [self initWithDelegate:nil];
}

- (void)dealloc
{
    NSLog(@"in CameraController -dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRecording];
    [imageSource release];
    [timeTextAttributes release];
    [super dealloc];
}

- (BOOL)isRecording
{
    return isRecording;
}

//return a random alphanumeric ascii character
char randomAlphanumericChar(){
	int router = randomIntegerBetween(0, 2);
	
	if( router == 0 ){
		return randomIntegerBetween(48, 57);
	}
	
	if( router == 1 ){
		return randomIntegerBetween(65, 90);
	}
	
	return randomIntegerBetween(97, 122);
}

NSInteger randomIntegerBetween(NSInteger min, NSInteger max) {
    return (random() % (max - min + 1)) + min;
}

- (BOOL)startRecordingToFilename:(NSString *)file
                         quality:(NSString *)quality
                     scaleFactor:(double)scale
                             FPS:(double)fps
                  putTimeOnImage:(BOOL)applyTime
                   timestampFont:(NSFont *)timestampFont
{
    [timeTextAttributes setObject:timestampFont
                        forKey:NSFontAttributeName];

    if (isRecording) {
        NSLog(@"Already recording, stopping current movie");
        [self stopRecording];
    }

    putTimeOnImage = applyTime;
    scaleFactor = scale;
    
	//create an output folder to store the images in
	NSFileManager *fileMan = [NSFileManager defaultManager];
	if(tmpOutputFolder){ [tmpOutputFolder release]; }
	tmpOutputFolder = [[NSMutableString alloc] initWithString:NSHomeDirectory()];
	[tmpOutputFolder appendString:@"/Gawker/"];
	if([fileMan fileExistsAtPath:tmpOutputFolder] == NO){
		[fileMan createDirectoryAtPath:tmpOutputFolder attributes:nil];
	}
	
	//reset what image num we're on
	imgCount = 0;
	
	//create a random name for the folder
	srand(time( NULL ));
	srandom(time(NULL));
	int i;
	for(i=0;i<8;++i){
		[tmpOutputFolder appendFormat:@"%c", randomAlphanumericChar()];
	}
	[tmpOutputFolder appendFormat:@"%c", '/'];
	if([fileMan fileExistsAtPath:tmpOutputFolder] == NO){
		[fileMan createDirectoryAtPath:tmpOutputFolder attributes:nil];
	}
	NSLog(@"Starting Recording to %@",tmpOutputFolder);
	
	if(outputMovie) [outputMovie release];
    outputMovie = [[LapseMovie alloc] initWithFilename:file
                                      quality:quality
                                      FPS:fps];
    if (!outputMovie) {
        NSLog(@"Error creating LapseMovie!");
    }
    else {
        isRecording = YES;
        [self recordCurrentImage];
    }
    
    return isRecording;
}

int finderSortWithLocale(id string1, id string2, void *locale)
{
    static NSStringCompareOptions comparisonOptions =
	NSCaseInsensitiveSearch | NSNumericSearch |
	NSWidthInsensitiveSearch | NSForcedOrderingSearch;
	
    NSRange string1Range = NSMakeRange(0, [string1 length]);
	
    return [string1 compare:string2
                    options:comparisonOptions
					  range:string1Range
					 locale:(NSLocale *)locale];
}


- (void)constructMovieFromFolder:(NSString *)folderPath
{
	if(!outputMovie){ 
		//create a movie OR error
	}
		
	//collect the images and create a mov and write to disk.
	NSFileManager *fileMan = [NSFileManager defaultManager];
	if([fileMan fileExistsAtPath:folderPath] == NO){
		//error and return
	}
	
	NSError **error;
	NSMutableArray *dirCont = [fileMan contentsOfDirectoryAtPath:folderPath error:error];
	[dirCont sortUsingFunction:finderSortWithLocale context:[NSLocale currentLocale]];
	NSEnumerator *dirEnum = [dirCont objectEnumerator];
	
	NSLog(@"Constructing Movie");
	NSString *file;
	NSImage *image;
	while( file = [dirEnum nextObject] ){ //this doenst do things in the order we need. 1 10 11 12 2 3 4 5 etc...
		if([[file pathExtension] isEqualToString:@"png"]){
			//read image from tmpOutputFolder appended with filename
			image = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@%@",folderPath,file]];
			
			//append image to movie
			[outputMovie addImage:image];
			[image release];
		}
	}
}

- (BOOL)destroyTempFolder
{
	if(!tmpOutputFolder){
		return NO;
	}
	
	NSFileManager *fileMan = [NSFileManager defaultManager];
	if([fileMan fileExistsAtPath:tmpOutputFolder] == NO ){
		return NO;
	}
	
	NSLog(@"Destroying Temporary Folder: %@",tmpOutputFolder);
	return [fileMan removeItemAtPath:tmpOutputFolder error:nil];
	
}

- (BOOL)stopRecording
{
    BOOL success = YES;
    if (isRecording) {
        //collect the images and create a mov and write to disk.
		NSFileManager *fileMan = [NSFileManager defaultManager];
		NSMutableArray *dirCont = [fileMan contentsOfDirectoryAtPath:tmpOutputFolder error:nil];
		//NSMutableArray *dirCont = [fileMan contentsOfDirectoryAtPath:@"/Users/csmith/Gawker/5K5RR1YF/" error:nil];
		[dirCont sortUsingFunction:finderSortWithLocale context:[NSLocale currentLocale]];
		NSEnumerator *dirEnum = [dirCont objectEnumerator];
		
		NSLog(@"Constructing Movie");
		NSString *file;
		NSImage *image;	
		NSAutoreleasePool *thePool = [[NSAutoreleasePool alloc] init];	//need this to keep QTMovie Memory in our control
		int i=0; //this should be spawned into a new thread and the interface should be locked?
		while( file = [dirEnum nextObject] ){ 
			i++;
			if([[file pathExtension] isEqualToString:@"png"]){
				
				
				//read image from tmpOutputFolder appended with filename
				image = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@%@",tmpOutputFolder,file]];
				//image = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@%@",@"/Users/csmith/Gawker/5K5RR1YF/",file]];

				//append image to movie
				[outputMovie addImage:image];
				[image release];
				
				//release QT stuff we dont need
				if(i%50==0){
					[thePool release];
					thePool = [[NSAutoreleasePool alloc] init];
				}
			}
		}
		
		success = [outputMovie writeToDisk];
		if(success == NO) NSLog(@"Movie incorrectly written");
		if(success == YES){
		//	[self destroyTempFolder];
		}
        [outputMovie release];
		[thePool release];
        outputMovie = nil;
        isRecording = NO;
    }
    return success;
}

- (void)storeImage:(NSImage *)theImage
{
	if(!theImage){
		NSLog(@"Image is nil, won't record");
		return;
	}
	
	imgCount++;
	NSString *toWrite = [NSString stringWithFormat:@"%@%d.png",tmpOutputFolder,imgCount];
	NSLog(@"Writing %@",toWrite);
	
	//write file to disk
	NSData *imageData = nil;
	NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[theImage TIFFRepresentation]];
	imageData = [imageRep representationUsingType:NSPNGFileType properties:nil];
	[imageData writeToFile:toWrite atomically:NO];
	
	
}

- (void)recordCurrentImage
{
    if (isRecording) {
        NSLog(@"Recording Current Image");
				
        NSImage *image = [imageSource recentImage]; //possible leak?

        if (!image) {
            NSLog(@"Image is nil, won't record");
			return;
        }

        if (putTimeOnImage) {
            NSImage *timeImage =
                [ImageText imageWithImage:image
                           stringAtBottom:[imageSource recentTime]
                           attributes:timeTextAttributes
                           scaleFactor:scaleFactor];
            image = timeImage;
        }
        else if (scaleFactor != 1.0) {
            NSArray *images = [NSArray arrayWithObjects:image, nil];
            NSSize imgSize = 
                NSMakeSize(640 * scaleFactor, 480 * scaleFactor);
            image = [ImageText compositeImages:images
                               sizeOfEach:imgSize];
        }
		
		[self storeImage:image];
		
        //[outputMovie addImage:image];
    }
}

- (BOOL)isSourceEnabled
{
    return [imageSource isEnabled];
}

- (BOOL)setSourceEnabled:(BOOL)state
{
    if (!state) {
        [self stopRecording];
    }
    
    return [imageSource setEnabled:state];
}

- (id <ImageSource>)imageSource
{
    return imageSource;
}

- (QTMovie *)movie
{
    return [outputMovie movie];
}

- (NSImage *)recentImage
{
    return [imageSource recentImage];
}

- (NSString *)sourceDescription
{
    return [imageSource sourceDescription];
}

- (void)setSourceDescription:(NSString *)newDesc
{
    [imageSource setSourceDescription:newDesc];
}

- (NSString *)sourceSubDescription
{
    return [imageSource sourceSubDescription];
}

- (void)setSourceSubDescription:(NSString *)newDesc
{
    [imageSource setSourceSubDescription:newDesc];
}

- (NSDate *)nextFrameTime
{
    return nil;
}

@end

@implementation CameraController (PrivateMethods)

- (void)registerForNotifications
{
    //
    // Register for notifications
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
        selector:@selector(receivedImageNotification:)
        name:@"ImageFromSource"
        object:imageSource];

    [nc addObserver:self
        selector:@selector(sourceDisconnected:)
        name:@"SourceDisconnect"
        object:imageSource];

    [nc addObserver:self
        selector:@selector(sourceConnected:)
        name:@"SourceConnect"
        object:imageSource];
}
    
- (void)receivedImageNotification:(NSNotification *)note
{
    if ([delegate respondsToSelector:@selector(cameraController:hasNewImage:)]) {
        [delegate cameraController:self hasNewImage:[[note object] recentImage]];
    }
}

- (void)sourceConnected:(NSNotification *)note
{
    if ([delegate respondsToSelector:@selector(cameraControllerConnected:)]) {
        [delegate cameraControllerConnected:self];
    }
    
    if ([self isRecording]) {
        NSLog(@"First image, needs to record");
        [self recordCurrentImage];
    }
}

- (void)sourceDisconnected:(NSNotification *)note
{
    [self setSourceEnabled:NO];

    if ([delegate respondsToSelector:@selector(cameraControllerDisconnected:)]) {
        [delegate cameraControllerDisconnected:self];
    }
}

@end
