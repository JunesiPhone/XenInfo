//
//  XIMusic.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIMusic.h"
#import "XIMusicHeaders.h"

#import <objc/runtime.h>

@implementation XIMusic

+ (NSString*)topic {
    return @"music";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    // Not needed for the music provider
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    // Not needed for the music provider
}

// Register a delegate object to call upon when new data becomes available.
- (void)registerDelegate:(id<XIWidgetManagerDelegate>)delegate {
     self.delegate = delegate;
}

// Called when a new widget is added, and it needs to be provided new data on load.
- (NSString*)requestCachedData {
    return [self _variablesToJSString];
}

// Called to refresh the data in the provider.
- (void)requestRefresh {
    NSDictionary *info = [objc_getClass("MPUNowPlayingController") _xeninfo_currentNowPlayingInfo];
    
    // Update cached variables
    self.cachedArtist = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoArtist"]];
    self.cachedAlbum = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoAlbum"]];
    self.cachedTitle = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoTitle"]];
    self.cachedIsPlaying = [[objc_getClass("SBMediaController") sharedInstance] isPlaying];
    
    if ([self.cachedAlbum containsString:@"Listening on"]) {
        NSArray* arArray = [self.cachedTitle componentsSeparatedByString:@"•"];
        if ([arArray count] > 1){
            self.cachedArtist = arArray[1];
            self.cachedTitle = arArray[0];
        }
    }
    
    // If we have null values, then don't worry about sending them to the widget.
    if (!self.cachedArtist && !self.cachedAlbum && !self.cachedTitle)
        return;
    
    // Escape strings for JS.
    self.cachedArtist = [self _escapeString:self.cachedArtist];
    self.cachedAlbum = [self _escapeString:self.cachedAlbum];
    self.cachedTitle = [self _escapeString:self.cachedTitle];
    
    // Also handle artwork, by saving it to disk for the widget to read from.
    UIImage *uiimage = nil;
    
    if ([objc_getClass("MPUNowPlayingController") _xeninfo_albumArt]){
        uiimage = [objc_getClass("MPUNowPlayingController") _xeninfo_albumArt];
        [UIImagePNGRepresentation(uiimage) writeToFile:@"var/mobile/Documents/Artwork.jpg" atomically:YES];
    }
    
    // And then send the data through to the widgets
    [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIMusic topic]];
}

- (NSString*)_variablesToJSString {
    return [NSString stringWithFormat:@"var artist = '%@', album = '%@', title = '%@', isplaying = %d;", self.cachedArtist,
            self.cachedAlbum, self.cachedTitle, self.cachedIsPlaying];
}

- (NSString*)_escapeString:(NSString*)input {
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    
    return input;
}

#pragma mark Actions callable by widgets

- (void)togglePlayState {
    [[objc_getClass("SBMediaController") sharedInstance] togglePlayPause];
}

- (void)advanceTrack {
    [[objc_getClass("SBMediaController") sharedInstance] changeTrack:1];
}

- (void)retreatTrack {
    [[objc_getClass("SBMediaController") sharedInstance] changeTrack:-1];
}

#pragma mark Provider specific methods

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Not needed for the music provider
    }
    
    return self;
}

@end
