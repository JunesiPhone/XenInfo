@class WebScriptObject;

@interface UIApplication (iOS10)
- (void)openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options completionHandler:(void (^)(BOOL success))completion;
@end

@interface WebFrame : NSObject
-(id)dataSource;
@end

@interface WebView : NSObject
@end

@interface UIWebBrowserView : UIView
@end

@interface IWWidgetsView : UIView
+(id)sharedInstance;
@end;

@interface IWWidget : UIView
@end;


@interface SBFolderView : UIView
@end

@interface SBFolderView (edited)
@end

@interface SBFolderController : NSObject
@property (nonatomic,retain,readonly) SBFolderView* contentView;
@end

@interface SBIconController : UIViewController
-(SBFolderController*)_rootFolderController;
+(instancetype)sharedInstance;
- (id)rootIconListAtIndex:(long long)arg1;
- (id)dockListView;
- (id)contentView;
- (id)model;
@property (nonatomic, retain) UIView* contentView;
@end

@interface UIWebView (Stock)
- (void)webView:(WebView *)webview didClearWindowObject:(WebScriptObject *)window forFrame:(WebFrame *)frame;
@end

/*Signal*/
@interface SBTelephonyManager : NSObject
+ (id)sharedTelephonyManager;
- (int)signalStrengthBars;
- (int)signalStrength;
- (id)operatorName;
- (id)currentNetworkName;
@end

/* Wifi*/
@interface SBWiFiManager : NSObject
+(id)sharedInstance;
- (int)signalStrengthRSSI;
- (int)signalStrengthBars;
- (id)currentNetworkName;
- (void)setWiFiEnabled:(BOOL)arg1;
@end

/*BlueTooth*/
@interface BluetoothManager : NSObject
+ (id)sharedInstance;
- (BOOL)setEnabled:(BOOL)arg1;
- (BOOL)enabled;
@end

/* App stuff and SBMedia uses*/
@interface SBApplication
- (id)applicationWithBundleIdentifier:(id)arg1;
@end

/* Open Apps*/
@interface UIApplication (Undocumented)
- (BOOL)_openURL:(id)arg1;
- (void) launchApplicationWithIdentifier: (NSString*)identifier suspended: (BOOL)suspended;
-(void)_runControlCenterBringupTest;
-(void)_runNotificationCenterBringupTest;
@end

/* Battery */
@interface SBUIController : NSObject
+(SBUIController *)sharedInstanceIfExists;
-(BOOL)isOnAC;
-(int)batteryCapacityAsPercentage;
-(void)openAppDrawer;
@end

/*Music*/
@interface SBMediaController : NSObject
@property(readonly, nonatomic) __weak SBApplication *nowPlayingApplication;
+ (id)sharedInstance;
- (BOOL)stop;
- (BOOL)togglePlayPause;
- (BOOL)pause;
- (BOOL)play;
- (BOOL)isPaused;
- (BOOL)isPlaying;
- (BOOL)changeTrack:(int)arg1;
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
+(id)_xeninfo_currentNowPlayingInfo;
+(id)_xeninfo_nowPlayingAppDisplayID;
+(id)_xeninfo_albumArt;
@end

@interface NSUserDefaults (XenInfo)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (id)allApplications;
- (id)applicationWithBundleIdentifier:(id)arg1;
+(id)sharedInstanceIfExists;
@end

@interface NSConcreteNotification : NSNotification {
    BOOL  dyingObject;
    NSString * name;
    id  object;
    NSDictionary * userInfo;
}
@end

@interface FBApplicationProvisioningProfile : NSObject {
    NSString * _UUID;
    NSDate * _expirationDate;
}

@property (nonatomic, readonly, copy) NSString *UUID;
@property (getter=isAppleInternalProfile, nonatomic, readonly) BOOL appleInternalProfile;
@property (getter=isBeta, nonatomic, readonly) BOOL beta;
@property (nonatomic, readonly, retain) NSDate *expirationDate;
@end

//alarms
@interface ClockManager
    + (id)sharedManager;
    -(NSArray *)scheduledLocalNotificationsCache;
    -(void)refreshScheduledLocalNotificationsCache;
    -(void)resetUpdatesToLocalNotificationsCache;
@end

@interface UIConcreteLocalNotification{
    NSTimeZone * timeZone;
}
- (id)timeZone;
-(id)nextFireDateAfterDate:(id)arg1 localTimeZone:(id)arg2;
- (id)fireDate;
-(id)userInfo;
@end
