//
//  XIMusicHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

@interface MPUNowPlayingController : NSObject
- (void)_updateCurrentNowPlaying;
- (void)_updateNowPlayingAppDisplayID;
- (void)_updatePlaybackState;
- (void)_updateTimeInformationAndCallDelegate:(BOOL)arg1;
- (BOOL)currentNowPlayingAppIsRunning;
- (id)nowPlayingAppDisplayID;
- (double)currentDuration;
- (double)currentElapsed;
- (id)currentNowPlayingArtwork;
- (id)currentNowPlayingArtworkDigest;
- (id)currentNowPlayingInfo;
- (id)currentNowPlayingMetadata;
-(void)startUpdating;
//added
+(double)_xeninfo_elapsedTime;
+(double)_xeninfo_currentDuration;
+(id)_xeninfo_currentNowPlayingInfo;
+(id)_xeninfo_nowPlayingAppDisplayID;
+(id)_xeninfo_albumArt;
@end

@interface SBMediaController : NSObject
+ (id)sharedInstance;
- (BOOL)stop;
- (BOOL)togglePlayPause;
- (BOOL)togglePlayPauseForEventSource:(long long)arg1;
- (BOOL)changeTrack:(int)arg1 eventSource:(long long)arg2;
- (BOOL)pause;
- (BOOL)play;
- (BOOL)isPaused;
- (BOOL)isPlaying;
- (BOOL)changeTrack:(int)arg1;
@end
