//
//  XIMusicHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//
@interface MPUNowPlayingMetadata : NSObject 
-(double)duration;
-(NSString *)title;
-(double)elapsedTime;
-(BOOL)isMusicApp;
-(NSString *)radioStationIdentifier;
-(NSString *)artist;
-(BOOL)isExplicitContent;
-(float)playbackRate;
-(NSDictionary *)nowPlayingInfo;
-(NSString *)radioStationName;
-(NSString *)album;
-(unsigned long long)persistentID;
-(BOOL)isAlwaysLive;
-(id)initWithMediaRemoteNowPlayingInfo:(id)arg1 ;
@end

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
+(id)_xeninfo_MPUNowPlayingController;
+(id)_xeninfo_nowPlayingAppDisplayID;
+(id)_xeninfo_albumArt;
@end


@interface MPCPlayerRequest
-(id)playingItemProperties;
-(id)queueSectionProperties;
@end

@interface MPRequestResponseController
-(void)beginAutomaticResponseLoading;
@end

@interface MPCPlaybackEngineMiddleware
+(long)getRepeat;
+(long)getShuffle;
@end

@interface MPCPlayerResponseTracklist
-(long long)repeatType;
-(long long)shuffleType;
@end

@interface MPCPlayerResponse
@property (nonatomic,readonly) MPCPlayerResponseTracklist * tracklist; 
-(MPCPlayerResponseTracklist *)tracklist;
@end

@interface MediaControlsPanelViewController
+(id)panelViewControllerForCoverSheet;
-(id)requestController;
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
-(BOOL)toggleShuffle;
-(BOOL)toggleRepeat;
-(BOOL)_sendMediaCommand:(unsigned)arg1 options:(id)arg2;
-(BOOL)_sendMediaCommand:(unsigned)arg1 ;
-(id)nowPlayingApplication;
@end
