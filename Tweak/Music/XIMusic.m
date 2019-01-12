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
#import <MediaPlayer/MediaPlayer.h>

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

-(NSString*)convertToTime:(double) doubleValue{
    NSNumber *time = [NSNumber numberWithDouble:(doubleValue)];
    NSTimeInterval interval = [time doubleValue];    
    NSDate *online = [NSDate date];
    online = [NSDate dateWithTimeIntervalSince1970:interval];    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"m:ss"];
    return [dateFormatter stringFromDate:online];
}

- (NSString *) secondsToMinute:(NSInteger)seconds {
    if (seconds < 60) {
        return [NSString stringWithFormat:@"0:%02d", (int)seconds];
    }
    if (seconds >= 60) {
        int minutes = floor(seconds/60);
        int remainSeconds = trunc(seconds - minutes * 60);
        return [NSString stringWithFormat:@"%d:%02d", minutes, remainSeconds];
    }
    return @"";
}

// different is iOS11 where a different shuffle/repeat type is received
// value is the suffle/repeat value

-(NSString*) shuffleStringWithValue:(long)value isDifferent:(bool)different{
    NSString* state = @"";
    switch(value){
        case MPMusicShuffleModeDefault:
            state = (different) ? @"disabled" : @"default";
        break;
        case MPMusicShuffleModeOff:
            state = (different) ? @"album" : @"disabled";
        break;
        case MPMusicShuffleModeSongs:
            state = @"song";
        break;
        case MPMusicShuffleModeAlbums:
            state = @"album";
        break;
    }
    return state;
}

-(NSString*) repeatStringWithValue:(long)value isDifferent:(bool)different{
    NSString* state = @"";
    switch(value){
        case MPMusicRepeatModeDefault:
            state = (different) ? @"disabled" : @"default";
        break;
        case MPMusicRepeatModeNone:
            state = (different) ? @"one" : @"disabled";
        break;
        case MPMusicRepeatModeOne:
            state = (different) ? @"all" : @"one";
        break;
        case MPMusicRepeatModeAll:
            state = @"all";
        break;
    }
    return state;
}

-(void) setShuffleAndRepeat{
    if([UIDevice currentDevice].systemVersion.floatValue < 11.0){

        MPUNowPlayingController* player = [objc_getClass("MPUNowPlayingController") _xeninfo_MPUNowPlayingController];
        NSDictionary *info = [player currentNowPlayingInfo];

        long shuffle = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoShuffleMode"] longValue];
        long repeat = [[info objectForKey:@"kMRMediaRemoteNowPlayingInfoRepeatMode"] longValue];

        self.cachedRepeatEnabled = [self repeatStringWithValue: repeat isDifferent:NO];
        self.cachedShuffleEnabled = [self shuffleStringWithValue: shuffle isDifferent:NO];

    }else if ([UIDevice currentDevice].systemVersion.floatValue >= 11.0 && [UIDevice currentDevice].systemVersion.floatValue < 11.3){
        
        long shuffle = [objc_getClass("MPCPlaybackEngineMiddleware") getShuffle];
        long repeat = [objc_getClass("MPCPlaybackEngineMiddleware") getRepeat];

        self.cachedRepeatEnabled = [self repeatStringWithValue: repeat isDifferent:YES];
        self.cachedShuffleEnabled = [self shuffleStringWithValue: shuffle isDifferent:YES];

    }else if ([UIDevice currentDevice].systemVersion.floatValue >= 11.3){
       
        MPMusicPlayerController* controller = [MPMusicPlayerController systemMusicPlayer];
        
        long shuffle = [controller shuffleMode];
        long repeat = [controller repeatMode];

        self.cachedRepeatEnabled = [self repeatStringWithValue: repeat isDifferent:NO];
        self.cachedShuffleEnabled = [self shuffleStringWithValue: shuffle isDifferent:NO];
    }
}

// Called to refresh the data in the provider.
- (void)requestRefresh {
    MPUNowPlayingController* player = [objc_getClass("MPUNowPlayingController") _xeninfo_MPUNowPlayingController];
    NSDictionary *info = [player currentNowPlayingInfo];

    // if no track duration no need to update
    // stops a few unnecessary updates
    if([player currentDuration] <= 0){
        return;
    }

    /* 
        iOS 11.1.2 has issue with getting shuffle and repeat guessing iOS 11.0 as well
        this triggers updates even when a (stock) music player isn't shown.
    */

    if ([UIDevice currentDevice].systemVersion.floatValue >= 11.0 && [UIDevice currentDevice].systemVersion.floatValue < 11.3){
        MediaControlsPanelViewController* MCRef = [objc_getClass("MediaControlsPanelViewController") panelViewControllerForCoverSheet];
        MPRequestResponseController* rc = [MCRef requestController];
        [rc beginAutomaticResponseLoading];
    }

    [self setShuffleAndRepeat];

    // Update cached variables
    self.cachedArtist = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoArtist"]];
    self.cachedAlbum = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoAlbum"]];
    self.cachedTitle = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoTitle"]];
    self.cachedBundleID = [player nowPlayingAppDisplayID];
    self.cachedDuration = [self convertToTime:[player currentDuration]];
    self.cachedElapsedTime = [self secondsToMinute:[player currentElapsed]];

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
    return [NSString stringWithFormat:@"var artist = '%@', album = '%@', title = '%@', isplaying = %d, musicBundle = '%@', currentDuration = '%@', currentElapsedTime = '%@', shuffleEnabled = '%@', repeatEnabled = '%@';", self.cachedArtist,
            self.cachedAlbum, self.cachedTitle, self.cachedIsPlaying, self.cachedBundleID, self.cachedDuration, self.cachedElapsedTime, self.cachedShuffleEnabled, self.cachedRepeatEnabled];
}

- (NSString*)_escapeString:(NSString*)input {
    if (!input)
        return @"";
    
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    
    return input;
}

#pragma mark Actions callable by widgets


/* 
    11.1.2 bug after device resprings and spotify was the last player it will not get all
    info. When you get the next track it will get this info.
*/
-(void)iOS11Hack{
    if(![self.cachedBundleID isEqualToString:@"com.apple.Music"]){
        [self advanceTrack];
        [self retreatTrack];
    }
}

/*
    Triggering _sendMediaCommand:0 (play) instead of toggling play removes the issue
    with having to tap play twice when playing from spotify.

    Leave fallbacks just for any oddities in other firmwares.
*/
- (void)togglePlayState {
    SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];

    if(![mediaController isPlaying]){
        if([mediaController respondsToSelector:@selector(_sendMediaCommand:options:)]){ //11.3 11.1.2
            [mediaController _sendMediaCommand:0 options:nil];
            //Hack
            if ([UIDevice currentDevice].systemVersion.floatValue >= 11.0 && [UIDevice currentDevice].systemVersion.floatValue < 11.3){
                if(!self.cachedBundleID){ //empty after respring
                    [self performSelector:@selector(iOS11Hack) withObject:nil afterDelay:2.5];
                }
            }
        }else{
            if([mediaController respondsToSelector:@selector(_sendMediaCommand:)]){ //10.2 9.3.3
                [mediaController _sendMediaCommand:0];
            }else if ([mediaController respondsToSelector:@selector(togglePlayPause)]){
                [mediaController togglePlayPause];
            }else if ([mediaController respondsToSelector:@selector(togglePlayPauseForEventSource:)]){
                [mediaController togglePlayPauseForEventSource:1];   
            }
        }
    }else{
        if([mediaController respondsToSelector:@selector(_sendMediaCommand:options:)]){
            [mediaController _sendMediaCommand:1 options:nil];
        }else{
            if([mediaController respondsToSelector:@selector(_sendMediaCommand:)]){
                [mediaController _sendMediaCommand:1];
            }else if ([mediaController respondsToSelector:@selector(togglePlayPause)]){
                [mediaController togglePlayPause];
            }else if ([mediaController respondsToSelector:@selector(togglePlayPauseForEventSource:)]){
                [mediaController togglePlayPauseForEventSource:1];   
            }
        }
    }
}

- (void)advanceTrack {
    SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
    if ([mediaController respondsToSelector:@selector(changeTrack:)])
        [mediaController changeTrack:1];
    else if ([mediaController respondsToSelector:@selector(changeTrack:eventSource:)])
        [mediaController changeTrack:1 eventSource:1];
}

- (void)retreatTrack {
    SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
    if ([mediaController respondsToSelector:@selector(changeTrack:)])
        [mediaController changeTrack:-1];
    else if ([mediaController respondsToSelector:@selector(changeTrack:eventSource:)])
        [mediaController changeTrack:-1 eventSource:1];
}

// 0: MPMusicShuffleModeDefault
// 1: MPMusicShuffleModeOff
// 2: MPMusicShuffleModeSongs
// 3: MPMusicShuffleModeAlbums
-(void)triggerShuffle {
    if(self.cachedIsPlaying){
        if ([UIDevice currentDevice].systemVersion.floatValue >= 11.3){
            dispatch_async(dispatch_get_main_queue(), ^{
                MPMusicPlayerController* controller = [MPMusicPlayerController systemMusicPlayer];
                if([controller shuffleMode] == MPMusicShuffleModeDefault || [controller shuffleMode] == MPMusicShuffleModeOff){
                    [controller setShuffleMode: MPMusicShuffleModeSongs];
                }else if ([controller shuffleMode] == MPMusicShuffleModeSongs){
                    [controller setShuffleMode: MPMusicShuffleModeAlbums];
                }else if ([controller shuffleMode] == MPMusicShuffleModeAlbums){
                   [controller setShuffleMode: MPMusicShuffleModeOff]; 
                }
            });
        }else{
            [[objc_getClass("SBMediaController") sharedInstance] toggleShuffle];
        }
    }   
}
// 1:MPMusicRepeatModeDefault
// 2:MPMusicRepeatModeNone
// 3:MPMusicRepeatModeOne
// 4:MPMusicRepeatModeAll
-(void)triggerRepeat {
    if(self.cachedIsPlaying){
        if ([UIDevice currentDevice].systemVersion.floatValue >= 11.3){
            dispatch_async(dispatch_get_main_queue(), ^{
                MPMusicPlayerController* controller = [MPMusicPlayerController systemMusicPlayer];
                if([controller repeatMode] == MPMusicRepeatModeDefault || [controller repeatMode] == MPMusicRepeatModeNone){
                    [controller setRepeatMode: MPMusicRepeatModeOne];
                }else if ([controller repeatMode] == MPMusicRepeatModeOne){
                    [controller setRepeatMode: MPMusicRepeatModeAll];
                }else if ([controller repeatMode] == MPMusicRepeatModeAll){
                   [controller setRepeatMode: MPMusicRepeatModeNone]; 
                   [self requestRefresh]; //doesn't trigger so manually trigger
                }
            });
        }else{
            [[objc_getClass("SBMediaController") sharedInstance] toggleRepeat];
        }
    }   
}

#pragma mark Provider specific methods

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.cachedShuffleEnabled = @"";
        self.cachedRepeatEnabled = @"";
    }
    
    return self;
}

@end
