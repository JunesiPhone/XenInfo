//
//  XIWAWeather.m
//  XenInfo
//
//  Created by Matt Clarke on 03/11/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

/*
 * General notes:
 * WATodayModel (and its autoupdating subclass) is available from iOS 10 onwards, and is used in both the
 * Today widget for Weather, and the iPad weather UI on the Lockscreen.
 *
 * Here, an update timer is ran every X minutes to request an instance of WATodayModel to update its data,
 * including current location for iOS 11+ users. This class is registered as an observer of this WATodayModel
 * instance to be notified when the user toggles the value of Location Services in Settings. Then, new data can
 * then be grabbed as needed to handle this change.
 *
 * Testing has shown though that Location Services run fairly continuously in the background when using an instance
 * of WATodayAutoupdatingLocationModel. To combat this, location services are disabled until updates occur. Then,
 * this sequence is followed:
 * 1. Enable location services for the model
 * 2. Wait a couple of seconds to get a new location fix if needed
 * 3. Get new data
 * 4. Start a timeout for location services to improve its fix
 *    This is reset if new updates are notified by the model in -todayModel:forecastWasUpdated:
 * 5. On timeout firing, a new data request is made
 * 6. Location services is disabled for the model
 *
 * This seems to work well with an update interval of 15 minutes.
 *
 * Additionally, if the device is asleep or no network connectivity is available, the update is queued until
 * the device is awake and connected to the internet.
 */

#import "XIWAWeather.h"
#import "../Internal/XIWidgetManager.h"
#import <objc/runtime.h>

#define UPDATE_INTERVAL 15 // minutes
#define LOCATION_TIMEOUT_INTERVAL 5 // seconds

@interface XIWAWeather ()

@property (nonatomic, retain) WATodayAutoupdatingLocationModel *todayModel;
@property (nonatomic, retain) NSTimer *updateTimer;
@property (nonatomic, retain) NSTimer *locationTrackingTimeoutTimer;
@property (nonatomic, retain) NSDate *lastUpdateTime;
@property (nonatomic, retain) NSDate *nextUpdateTime;
@property (nonatomic, readwrite) BOOL deviceIsAsleep;
@property (nonatomic, readwrite) int userAuthorizationStatus;
//@property (nonatomic, readwrite) BOOL refreshQueuedDuringDeviceSleep;
@property (nonatomic, readwrite) BOOL networkIsDisconnected;
@property (nonatomic, readwrite) BOOL refreshQueuedDuringNetworkDisconnected;

@end

@implementation XIWAWeather

- (instancetype)init {
    self = [super init];
    
    if (self) {
        Xlog(@"Init XIWAWeather");

        // Set default values
        _ignoreUpdateFlag = NO;
        self.lastUpdateTime = nil;
        self.userAuthorizationStatus = 99;
        [self setWeatherLocationType:3]; //iOS13 doesn't show the user this but it's still there.
        [self _restartTimerWithInterval:UPDATE_INTERVAL * 60];
        [self _setupTodayModels];
    }
    
    return self;
}

- (void)noteDeviceDidEnterSleep {
    self.deviceIsAsleep = YES;
    
    // Stopping timer. If it fires when off, well, likely nothing happens due to be being in deep sleep
    NSLog(@"*** [XenInfo] :: DEBUG :: Stopping weather update timer due to sleep");
    [self.updateTimer invalidate];
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    self.deviceIsAsleep = NO;
    
    // Restarting timer as needed.
    {
        NSTimeInterval nextFireInterval = [self.nextUpdateTime timeIntervalSinceDate:[NSDate date]];
        
        if (nextFireInterval <= 5) { // seconds
            NSLog(@"*** [XenInfo] :: DEBUG :: Timer would have (or is about to) expire, so requesting signing checks");
            [self requestRefresh];
        } else {
            // Restart the timer for this remaining interval
            NSLog(@"*** [XenInfo] :: DEBUG :: Restarting signing timer due to wake, with interval: %f minutes", (float)nextFireInterval / 60.0);
            [self _restartTimerWithInterval:nextFireInterval];
        }
    }
}

- (void)networkWasDisconnected {
    self.networkIsDisconnected = YES;
}

- (void)networkWasConnected {
    self.networkIsDisconnected = NO;
    
    // Undertake a refresh if one was queued
    if (self.refreshQueuedDuringNetworkDisconnected) {
        [self requestRefresh];
        self.refreshQueuedDuringNetworkDisconnected = NO;
    }
}

- (void)requestRefresh {
    // Queue if asleep
    /*if (self.deviceIsAsleep) {
        self.refreshQueuedDuringDeviceSleep = YES;
        return;
    }*/
    
    // Queue if no network
    if (self.networkIsDisconnected) {
        self.refreshQueuedDuringNetworkDisconnected = YES;
        return;
    }
    
    // Otherwise, update now!
    [self _updateModel:self.todayModel];
    
    // And restart the update timer with the full interval
    [self _restartTimerWithInterval:UPDATE_INTERVAL * 60];
}

- (void)_restartTimerWithInterval:(NSTimeInterval)interval {
    if (self.updateTimer)
        [self.updateTimer invalidate];
    
    NSLog(@"*** [XenInfo] :: Restarting weather update timer with interval: %f minutes", (float)interval / 60.0);
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(_updateTimerFired:)
                                                      userInfo:nil
                                                       repeats:NO];
    
    self.nextUpdateTime = [[NSDate date] dateByAddingTimeInterval:interval];
}

- (void)_setupTodayModels {
    self.todayModel = [self _loadLocationModel];
    
    // Get initial data
    [self requestRefresh];
    
    // Grab current city
    self.currentCity = self.todayModel.forecastModel.city;
}

-(void)setWeatherLocationType:(int)authType{
    // if(self.userAuthorizationStatus == 99){
    //     NSLog(@"XenInfoTest auth1 %d", self.userAuthorizationStatus);
    //     /* Store user state so we can set it back */
    //     self.userAuthorizationStatus = [objc_getClass("CLLocationManager") authorizationStatusForBundleIdentifier:@"com.apple.weather"];
    //     NSLog(@"XenInfoTest auth2 %d", self.userAuthorizationStatus);
    // }
    /*
        2:Never 0:AskNextTime 4:While Using App
        3:Always (only shown < iOS13 to the user)
     
        When this is called [CLLocationManager location] is also called which is getting updated location info.
        Tested by logging -(id)location{} and calling setAuthorizationStatusByType after you've moved location.
        This would be like setting location services > weather > always I do believe.
        Works iOS8-13
    */
    [objc_getClass("CLLocationManager") setAuthorizationStatusByType:authType forBundleIdentifier:@"com.apple.weather"];
}

- (WATodayAutoupdatingLocationModel*)_loadLocationModel {
    WeatherPreferences *preferences = [objc_getClass("WeatherPreferences") sharedPreferences];
    WATodayAutoupdatingLocationModel *todayModel = [objc_getClass("WATodayModel") autoupdatingLocationModelWithPreferences:preferences effectiveBundleIdentifier:@"com.apple.weather"];
    
    // Override here to kickstart location manager when services are disabled after a respring
    [todayModel setLocationServicesActive:YES];
    [todayModel setIsLocationTrackingEnabled:YES];
    [todayModel executeModelUpdateWithCompletion:^(BOOL arg1, NSError *arg2) {}];
    [todayModel addObserver:self];
    return todayModel;
}

- (void)_updateTimerFired:(NSTimer*)timer {
    [self requestRefresh];
}

- (void)_locationTrackingTimeoutFired:(NSTimer*)timer {
    [timer invalidate];
    
    // Grab final update just-in-case of new location data
    [self.todayModel executeModelUpdateWithCompletion:^(BOOL arg1, NSError *arg2) {
        if (!arg2 || [self _date:self.todayModel.forecastModel.city.updateTime isNewerThanDate:self.lastUpdateTime]) {
            // Notify widgets if needed
            [self.delegate didUpdateCity:self.todayModel.forecastModel.city];
            
            // Update last updated time
            self.lastUpdateTime = self.todayModel.forecastModel.city.updateTime;
        }
        
        // Turn off location tracking
        _ignoreUpdateFlag = YES; // No need to run an update for this battery management change
        [self.todayModel setIsLocationTrackingEnabled:NO];
        
    }];
}

-(void)updateWeatherForLocation:(WFLocation *)location withCity:(City *) city{
    TWCLocationUpdater* updater = [objc_getClass("TWCLocationUpdater") sharedLocationUpdater];
    CLLocation* cLLocation = [location geoLocation];
    [updater updateWeatherForLocation:cLLocation city:city isFromFrameworkClient:NO withCompletionHandler:^(City* city){

        // Notify widgets
        [self.delegate didUpdateCity:city];

        // Update last updated time
        self.lastUpdateTime = city.updateTime;
        //[self setWeatherLocationType:self.userAuthorizationStatus]; //set location services weather back to the user defined auth type.
    }];
}

- (void)_updateModel:(WATodayAutoupdatingLocationModel*)todayModel {
    // Updating setIsLocationTrackingEnabled: will cause the today model to request an update
    // Need to start location updates if available to get accurate data
    _ignoreUpdateFlag = YES;
    [todayModel setIsLocationTrackingEnabled:YES];
    
    // Not exactly the most deterministic way to ensure a new location has arrived!
    // We just want to ensure there's sufficient time for location services to get new locations.
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1.5);
    dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        // Request new data
        [todayModel executeModelUpdateWithCompletion:^(BOOL arg1, NSError *arg2) {
            /*
                The today model isn't getting the updated weather on iOS13 and I believe 12.5 up.
                iOS13 the today model is updating location, but is not updating weather info.
                updateWeatherForLocation takes the today model info (location and city)
                and updates through TWCLocationUpdater
            */
            if([UIDevice currentDevice].systemVersion.floatValue >= 12.5){
                if (!arg2 || [self _date:[[NSDate date] dateByAddingTimeInterval:UPDATE_INTERVAL] isNewerThanDate:self.lastUpdateTime]) {
                    WFLocation* todayModelLocation = [self.todayModel location];
                    if(todayModelLocation){
                        [self updateWeatherForLocation:todayModelLocation withCity:self.todayModel.forecastModel.city];
                    }
                }
            }else{
                if (!arg2 || [self _date:todayModel.forecastModel.city.updateTime isNewerThanDate:self.lastUpdateTime]) {
                    // Notify widgets
                    [self.delegate didUpdateCity:todayModel.forecastModel.city];
                    // Update last updated time
                    self.lastUpdateTime = todayModel.forecastModel.city.updateTime; 
                }
            }
        }];
        
        // Start location tracking timeout - in the event of location being improved.
        // Improvements will be reported to todayModel:forecastWasUpdated:
        [self.locationTrackingTimeoutTimer invalidate];
        self.locationTrackingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:LOCATION_TIMEOUT_INTERVAL
                                                                             target:self
                                                                           selector:@selector(_locationTrackingTimeoutFired:)
                                                                           userInfo:nil
                                                                            repeats:NO];
    });
}

-(void)todayModelWantsUpdate:(WATodayAutoupdatingLocationModel*)todayModel {
    if (YES == _ignoreUpdateFlag) {
        // Just ignore this request from the model
        _ignoreUpdateFlag = NO;
    } else {
        // Only want this called whenever location services is turned off or on, not for internal
        // battery management updates.
        [self _updateModel:todayModel];
    }
}

-(void)todayModel:(WATodayModel*)todayModel forecastWasUpdated:(WAForecastModel*)forecastModel {
    // Stop timeout if needed
    //[self.locationTrackingTimeoutTimer invalidate];
    
    // Handle this update - not stopping the timeout
    [self.delegate didUpdateCity:forecastModel.city];
    
    // Start location tracking timeout
    /*self.locationTrackingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:LOCATION_TIMEOUT_INTERVAL
                                                                         target:self
                                                                       selector:@selector(_locationTrackingTimeoutFired:)
                                                                       userInfo:nil
                                                                        repeats:NO];*/
}

- (BOOL)_date:(NSDate*)newDate isNewerThanDate:(NSDate*)oldDate {
    if (!oldDate) {
        return YES;
    }
    
    return [newDate compare:oldDate] == NSOrderedDescending;
}

@end
