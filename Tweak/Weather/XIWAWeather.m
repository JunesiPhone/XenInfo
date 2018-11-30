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
 * 4. Start a timeout for locaiton services to improve its fix
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
@property (nonatomic, readwrite) BOOL deviceIsAsleep;
@property (nonatomic, readwrite) BOOL refreshQueuedDuringDeviceSleep;
@property (nonatomic, readwrite) BOOL networkIsDisconnected;
@property (nonatomic, readwrite) BOOL refreshQueuedDuringNetworkDisconnected;

@end

@implementation XIWAWeather

- (instancetype)init {
    self = [super init];
    
    if (self) {
        Xlog(@"Init XIWAWeather");
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL * 60
                                                            target:self
                                                          selector:@selector(_updateTimerFired:)
                                                          userInfo:nil
                                                           repeats:YES];
        
        // Set default values
        _ignoreUpdateFlag = NO;
        self.lastUpdateTime = nil;
        
        [self _setupTodayModels];
    }
    
    return self;
}

- (void)noteDeviceDidEnterSleep {
    self.deviceIsAsleep = YES;
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    self.deviceIsAsleep = NO;
    
    // Undertake a refresh if one was queued during sleep.
    if (self.refreshQueuedDuringDeviceSleep) {
        [self requestRefresh];
        self.refreshQueuedDuringDeviceSleep = NO;
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
    if (self.deviceIsAsleep) {
        self.refreshQueuedDuringDeviceSleep = YES;
        return;
    }
    
    // Queue if no network
    if (self.networkIsDisconnected) {
        self.refreshQueuedDuringNetworkDisconnected = YES;
        return;
    }
    
    // Otherwise, update now!
    [self _updateModel:self.todayModel];
}

- (void)_setupTodayModels {
    self.todayModel = [self _loadLocationModel];
    
    // Get initial data
    [self requestRefresh];
    
    // Grab current city
    self.currentCity = self.todayModel.forecastModel.city;
}

- (WATodayAutoupdatingLocationModel*)_loadLocationModel {
    WeatherPreferences *preferences = [objc_getClass("WeatherPreferences") sharedPreferences];
    
    WATodayAutoupdatingLocationModel *todayModel = [objc_getClass("WATodayModel") autoupdatingLocationModelWithPreferences:preferences effectiveBundleIdentifier:@"com.apple.weather"];
    
    // Override here to kickstart location manager when services are disabled after a respring
    [todayModel setLocationServicesActive:YES];
    [todayModel setIsLocationTrackingEnabled:YES];
    
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

- (void)_updateModel:(WATodayAutoupdatingLocationModel*)todayModel {
    Xlog(@"Updating weather data...");
    
    // Updating setIsLocationTrackingEnabled: will cause the today model to request an update
    // Need to start location updates if available to get accurate data
    _ignoreUpdateFlag = YES;
    [todayModel setIsLocationTrackingEnabled:YES];
    
    // Not exactly the most deterministic way to ensure a new location has arrived!
    // We just want to ensure there's sufficient time for location services to get new locations.
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1.5);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        
        // Request new data
        [todayModel executeModelUpdateWithCompletion:^(BOOL arg1, NSError *arg2) {
            if (!arg2 || [self _date:todayModel.forecastModel.city.updateTime isNewerThanDate:self.lastUpdateTime]) {
                // Notify widgets
                [self.delegate didUpdateCity:todayModel.forecastModel.city];
                
                // Update last updated time
                self.lastUpdateTime = todayModel.forecastModel.city.updateTime;
            
                // Start location tracking timeout - in the event of location being improved.
                // Improvements will be reported to todayModel:forecastWasUpdated:
                [self.locationTrackingTimeoutTimer invalidate];
                self.locationTrackingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:LOCATION_TIMEOUT_INTERVAL
                                                             target:self
                                                           selector:@selector(_locationTrackingTimeoutFired:)
                                                           userInfo:nil
                                                            repeats:NO];
            }
        }];
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
    [self.locationTrackingTimeoutTimer invalidate];
    
    // Handle this update
    [self.delegate didUpdateCity:forecastModel.city];
    
    // Start location tracking timeout
    self.locationTrackingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:LOCATION_TIMEOUT_INTERVAL
                                                                         target:self
                                                                       selector:@selector(_locationTrackingTimeoutFired:)
                                                                       userInfo:nil
                                                                        repeats:NO];
}

- (BOOL)_date:(NSDate*)newDate isNewerThanDate:(NSDate*)oldDate {
    if (!oldDate) {
        return YES;
    }
    
    return [newDate compare:oldDate] == NSOrderedDescending;
}

@end
