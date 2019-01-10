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

// Called to refresh the data in the provider.
- (void)requestRefresh {
    MPUNowPlayingController* player = [objc_getClass("MPUNowPlayingController") _xeninfo_MPUNowPlayingController];

    NSDictionary *info = [player currentNowPlayingInfo];

    // if no track duration no need to update
    // stops a few unnecessary updates
    if([player currentDuration] <= 0){
        return;
    }

    // Update cached variables
    self.cachedArtist = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoArtist"]];
    self.cachedAlbum = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoAlbum"]];
    self.cachedTitle = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoTitle"]];
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

    /*
        Make sure music is playing.
        Delay needed otherwise device will freeze (sometimes). Still looking into it.
    */
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.5);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        if(self.cachedIsPlaying){
            MPMusicPlayerController* controller = [MPMusicPlayerController systemMusicPlayer];

            if([controller repeatMode] == MPMusicRepeatModeNone){
                self.cachedRepeatEnabled = @"disabled";
            }else{
                self.cachedRepeatEnabled = @"enabled";
            }

            if([controller shuffleMode] == MPMusicShuffleModeOff){
                self.cachedShuffleEnabled = @"disabled";
            }else{
                self.cachedShuffleEnabled = @"enabled";
            }
            
            //update with new info
            [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIMusic topic]];
        }
    });
        
    // And then send the data through to the widgets
    [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIMusic topic]];
        
}

- (NSString*)_variablesToJSString {
    return [NSString stringWithFormat:@"var artist = '%@', album = '%@', title = '%@', isplaying = %d, currentDuration = '%@', currentElapsedTime = '%@', shuffleEnabled = '%@', repeatEnabled = '%@';", self.cachedArtist,
            self.cachedAlbum, self.cachedTitle, self.cachedIsPlaying, self.cachedDuration, self.cachedElapsedTime, self.cachedShuffleEnabled, self.cachedRepeatEnabled];
}

- (NSString*)_escapeString:(NSString*)input {
    if (!input)
        return @"";
    
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    
    return input;
}

#pragma mark Actions callable by widgets

- (void)togglePlayState {
    SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
    if ([mediaController respondsToSelector:@selector(togglePlayPause)])
        [mediaController togglePlayPause];
    else if ([mediaController respondsToSelector:@selector(togglePlayPauseForEventSource:)])
        [mediaController togglePlayPauseForEventSource:1];
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

-(void)toggleShuffle {
    if(self.cachedIsPlaying){
        MPMusicPlayerController* controller = [MPMusicPlayerController systemMusicPlayer];
        bool shuffleOn = NO;
        switch([controller shuffleMode]){
            case MPMusicShuffleModeDefault:
                shuffleOn = YES;
            break;
            case MPMusicShuffleModeOff:
                shuffleOn = NO;
            break;
            case MPMusicShuffleModeSongs:
                shuffleOn = YES;
            break;
            case MPMusicShuffleModeAlbums:
                shuffleOn = YES;
            break;
        }

        //change shuffle mode
        if(!shuffleOn){
            [controller setShuffleMode: MPMusicShuffleModeSongs];
        }else{
            [controller setShuffleMode: MPMusicShuffleModeOff]; 
        }

    }   
}
-(void)toggleRepeat {
    if(self.cachedIsPlaying){
        MPMusicPlayerController* controller = [MPMusicPlayerController systemMusicPlayer];
        bool repeatOn = NO;
        switch([controller repeatMode]){
            case MPMusicRepeatModeDefault:
                repeatOn = YES;
            break;
            case MPMusicRepeatModeNone:
                repeatOn = NO;
            break;
            case MPMusicRepeatModeOne:
                repeatOn = YES;
            break;
            case MPMusicRepeatModeAll:
                repeatOn = YES;
            break;
        }

        //change repeat mode
        if(!repeatOn){
            [controller setRepeatMode: MPMusicRepeatModeOne];
        }else{
            [controller setRepeatMode: MPMusicRepeatModeNone]; 
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
