//
//  XIMusic.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Internal/XIWidgetDataProvider-Protocol.h"

@interface XIMusic : NSObject <XIWidgetDataProvider>

// Delegate is stored to communicate data back to widgets
@property (nonatomic, weak) id<XIWidgetManagerDelegate> delegate;

// Each is called as an action from XIWidgetManager.
- (void)togglePlayState;
- (void)advanceTrack;
- (void)retreatTrack;
- (void)triggerShuffle;
- (void)triggerRepeat;

// Cached variables between refreshes.
@property (nonatomic, strong) NSString *cachedArtist;
@property (nonatomic, strong) NSString *cachedAlbum;
@property (nonatomic, strong) NSString *cachedTitle;
@property (nonatomic, strong) NSString *cachedDuration;
@property (nonatomic, strong) NSString *cachedElapsedTime;
@property (nonatomic, strong) NSString *cachedBundleID;
@property (nonatomic, readwrite) BOOL cachedIsPlaying;
@property (nonatomic, readwrite) BOOL stoppedPlaying;
@property (nonatomic, strong) NSString *cachedShuffleEnabled;
@property (nonatomic, strong) NSString *cachedRepeatEnabled;
@property (nonatomic, readwrite) NSData* cachedArtwork;

@end
