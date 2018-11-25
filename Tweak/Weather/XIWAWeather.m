//
//  XIWAWeather.m
//  XenInfo
//
//  Created by Matt Clarke on 03/11/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIWAWeather.h"
#import "../Internal/XIWidgetManager.h"
#import <objc/runtime.h>

#define UPDATE_INTERVAL 30 // minutes
#define LOCATION_TIMEOUT_INTERVAL 5 // seconds

@interface XIWAWeather ()

@property (nonatomic,retain) WATodayAutoupdatingLocationModel *todayModel;
@property (nonatomic,retain) NSTimer *updateTimer;
@property (nonatomic,retain) NSTimer *locationTrackingTimeoutTimer;
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
        
        // Set flag to default value
        _ignoreUpdateFlag = NO;
        
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
    
    _ignoreUpdateFlag = YES; // No need to run an update for this battery management change
    [self.todayModel setIsLocationTrackingEnabled:NO];
}

- (void)_updateModel:(WATodayAutoupdatingLocationModel*)todayModel {
    Xlog(@"Updating weather data...");
    
    // Updating setIsLocationTrackingEnabled: will cause the today model to request an update
    // Need to start location updates if available to get accurate data
    _ignoreUpdateFlag = YES;
    [todayModel setIsLocationTrackingEnabled:YES];
    
    // Not exactly the most deterministic way to ensure a new location has arrived!
    // We just want to ensure there's sufficient time for location services to get new locations.
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 3.0);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        
        // Request new data
        [todayModel executeModelUpdateWithCompletion:^(BOOL arg1, NSError *arg2) {
            if (!arg2) {
                // Notify widgets
                [self.delegate didUpdateCity:todayModel.forecastModel.city];
            
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

@end
