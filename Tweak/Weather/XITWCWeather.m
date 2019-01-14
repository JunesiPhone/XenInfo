//
//  XITWCWeather.m
//  XenInfo
//
//  Created by Matt Clarke on 03/11/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XITWCWeather.h"
#import "XIWeatherHeaders.h"
#import "../Internal/XIWidgetManager.h"
#import <objc/runtime.h>

@interface XITWCWeather ()
@property (nonatomic, strong) WeatherLocationManager* weatherLocationManager;
@property (nonatomic, strong) NSTimer *updateTimer;

@property (nonatomic, readwrite) BOOL deviceIsAsleep;
@property (nonatomic, readwrite) BOOL refreshQueuedDuringDeviceSleep;
@property (nonatomic, readwrite) BOOL networkIsDisconnected;
@property (nonatomic, readwrite) BOOL refreshQueuedDuringNetworkDisconnected;

@property (nonatomic, retain) NSDate *nextUpdateTime;
@end

#define UPDATE_INTERVAL 15 // minutes

@implementation XITWCWeather

- (instancetype)init {
    self = [super init];
    
    if (self) {
        Xlog(@"Init XITWCWeather");
        
        // Location stuff
        // XXX: Since iOS 8, cannot actually use CLLocationManager to track the user's location.
        // XXX: Realistically, this needs either a background daemon with the com.apple.locationd.preauthorized
        // XXX: entitlement, or a hook into locationd to force-allow SpringBoard only. As a result... we won't
        // XXX: have Weather.framework auto-updating data for location changes.
        self.weatherLocationManager = [objc_getClass("WeatherLocationManager") sharedWeatherLocationManager];
        [self.weatherLocationManager setDelegate:self];
        self.weatherLocationManager.updateInterval = UPDATE_INTERVAL * 60;
        
        self.currentCity = [self _currentCity];
        
        // Do an initial update
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 5.0);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            
            // Start location tracking in Weather.framework
            if ([self.weatherLocationManager respondsToSelector:@selector(setLocationTrackingReady:activelyTracking:watchKitExtension:)]) {
                [self.weatherLocationManager setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
            }
            
            // Set initial tracking active state if possible
            if ([self _locationServicesAvailable]) {
                [self.weatherLocationManager setLocationTrackingActive:YES];
                [[objc_getClass("WeatherPreferences") sharedPreferences] setLocalWeatherEnabled:YES];
                
                // Force a new location update if possible
                [self.weatherLocationManager forceLocationUpdate];
            }
            
            [self requestRefresh];
        });
        
        // Start the update timer with the full interval
        [self _restartTimerWithInterval:UPDATE_INTERVAL * 60];
    }
    
    return self;
}

- (void)noteDeviceDidEnterSleep {
    self.deviceIsAsleep = YES;
    
    // Stopping timer. If it fires when off, well, likely nothing happens due to be being in deep sleep
    [self.updateTimer invalidate];
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    self.deviceIsAsleep = NO;
    
    // Restarting timer as needed.
    {
        NSTimeInterval nextFireInterval = [self.nextUpdateTime timeIntervalSinceDate:[NSDate date]];
        
        if (nextFireInterval <= 5) { // seconds
            [self requestRefresh];
        } else {
            // Restart the timer for this remaining interval
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
    if (self.deviceIsAsleep) {
        self.refreshQueuedDuringDeviceSleep = YES;
        return;
    }
    
    if (self.networkIsDisconnected) {
        self.refreshQueuedDuringNetworkDisconnected = YES;
        return;
    }
    
    [self _refreshWeather];
    
    // And restart the update timer with the full interval
    [self _restartTimerWithInterval:UPDATE_INTERVAL * 60];
}

- (void)_restartTimerWithInterval:(NSTimeInterval)interval {
    if (self.updateTimer)
        [self.updateTimer invalidate];
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(_updateTimerFired:)
                                                      userInfo:nil
                                                       repeats:NO];
    
    self.nextUpdateTime = [[NSDate date] dateByAddingTimeInterval:interval];
}

- (void)_updateTimerFired:(NSTimer*)timer {
    [self requestRefresh];
}

- (BOOL)_locationServicesAvailable {
    return [CLLocationManager locationServicesEnabled];
}

- (City*)_currentCity {
    if ([self _locationServicesAvailable]) {
        return [[objc_getClass("WeatherPreferences") sharedPreferences] localWeatherCity];
    } else {
        NSArray *savedCities = [[objc_getClass("WeatherPreferences") sharedPreferences] loadSavedCities];
        City *result;
        
        for (City *city in savedCities) {
            if (!city.isLocalWeatherCity) {
                result = city;
                break;
            }
        }
        
        // if city is nil, then substitute for Cupertino.
        if (!result) {
            NSMutableDictionary *newCity = [NSMutableDictionary dictionary];
            
            [newCity setObject:[NSNumber numberWithFloat:37.323] forKey:@"Lat"];
            [newCity setObject:[NSNumber numberWithFloat:-122.0322] forKey:@"Lon"];
            [newCity setObject:@"Cupertino" forKey:@"Name"];
            
            result = [[objc_getClass("WeatherPreferences") sharedPreferences] cityFromPreferencesDictionary:newCity];
        }
        
        return result;
    }
}

- (void)_refreshWeather {
    [self _refreshWeatherWithLocation:self.currentCity.location];
}

- (void)_refreshWeatherWithLocation:(CLLocation*)location {
    // Set update delegate
    if ([self.currentCity respondsToSelector:@selector(associateWithDelegate:)]) {
        [self.currentCity associateWithDelegate:self];
    } else if ([self.currentCity respondsToSelector:@selector(addUpdateObserver:)]) {
        [self.currentCity addUpdateObserver:self];
    }
    
    TWCLocationUpdater *locationUpdater = [objc_getClass("TWCLocationUpdater") sharedLocationUpdater];
    [locationUpdater updateWeatherForLocation:location city:self.currentCity];
}

#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray*)locations {
    if (locations.count > 0) {
        CLLocation *newestLocation = [locations lastObject];
        
        // Get an update for this change!
        [self _refreshWeatherWithLocation:newestLocation];
    }
}

#pragma mark City delegate methods

-(void)cityDidStartWeatherUpdate:(id)city {
    // Nothing to do here currently.
}

-(void)cityDidFinishWeatherUpdate:(City*)city {
    // New data, so update!
    self.currentCity = city;

    [self.delegate didUpdateCity:city];
}

@end
