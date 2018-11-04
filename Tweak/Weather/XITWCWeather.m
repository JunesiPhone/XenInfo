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
@end

#define UPDATE_INTERVAL 30 // minutes

@implementation XITWCWeather

- (instancetype)init {
    self = [super init];
    
    if (self) {
        Xlog(@"Init XITWCWeather");
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL * 60
                                                            target:self
                                                          selector:@selector(requestRefresh)
                                                          userInfo:nil
                                                           repeats:YES];
        
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
            [self requestRefresh];
            
            // Start location tracking in Weather.framework
            if ([self.weatherLocationManager respondsToSelector:@selector(setLocationTrackingReady:activelyTracking:watchKitExtension:)]) {
                [self.weatherLocationManager setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
            }
            
            if ([self.weatherLocationManager respondsToSelector:@selector(setLocationTrackingReady:activelyTracking:watchKitExtension:)]) {
                [self.weatherLocationManager setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
            }
            
            // Set initial tracking active state if possible
            if ([self _locationServicesAvailable]) {
                [self.weatherLocationManager setLocationTrackingActive:YES];
                [[objc_getClass("WeatherPreferences") sharedPreferences] setLocalWeatherEnabled:YES];
                
                // Force a new location update
                [self.weatherLocationManager forceLocationUpdate];
            }
        });
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

- (void)requestRefresh {
    if (self.deviceIsAsleep) {
        self.refreshQueuedDuringDeviceSleep = YES;
        return;
    }
    
    if ([self _locationServicesAvailable]) {
        [self _refreshWeatherWithCompletion:^(City *city) {
            [self.delegate didUpdateCity:city];
        }];
    } else {
        [self _refreshWeatherNoLocationWithCompletion:^(City *city) {
            [self.delegate didUpdateCity:city];
        }];
    }
}

- (BOOL)_locationServicesAvailable {
    return [CLLocationManager locationServicesEnabled];
}

- (City*)_currentCity {
    if ([self _locationServicesAvailable]) {
        return [[objc_getClass("WeatherPreferences") sharedPreferences] localWeatherCity];
    } else {
        if (![[objc_getClass("WeatherPreferences") sharedPreferences] respondsToSelector:@selector(loadSavedCityAtIndex:)]) {
            @try {
                return [[[objc_getClass("WeatherPreferences") sharedPreferences] loadSavedCities] firstObject];
            } @catch (NSException *e) {
                Xlog(@"Failed to load first city in Weather.app for reason:\n%@", e);
                return nil;
            }
        } else
            return [[objc_getClass("WeatherPreferences") sharedPreferences] loadSavedCityAtIndex:0];
    }
}

- (void)_refreshWeatherNoLocationWithCompletion:(void (^)(City*))completionHandler {
    TWCLocationUpdater *locationUpdater = [objc_getClass("TWCLocationUpdater") sharedLocationUpdater];
    
    if ([locationUpdater respondsToSelector:@selector(updateWeatherForLocation:city:withCompletionHandler:)]) {
        [locationUpdater updateWeatherForLocation:self.currentCity.location city:self.currentCity withCompletionHandler:^{
            completionHandler(self.currentCity);
        }];
    } else if ([locationUpdater respondsToSelector:@selector(_updateWeatherForLocation:city:completionHandler:)]) {
        [[objc_getClass("TWCLocationUpdater") sharedLocationUpdater] _updateWeatherForLocation:self.currentCity.location city:self.currentCity completionHandler:^{
            completionHandler(self.currentCity);
        }];
    }
}

- (void)_refreshWeatherWithCompletion:(void (^)(City*))completionHandler {
    [self _refreshWeatherWithLocation:self.currentCity.location andCompletion:(void (^)(City*))completionHandler];
}

- (void)_refreshWeatherWithLocation:(CLLocation*)location andCompletion:(void (^)(City*))completionHandler {
    TWCLocationUpdater *locationUpdater = [objc_getClass("TWCLocationUpdater") sharedLocationUpdater];
    
    if ([locationUpdater respondsToSelector:@selector(updateWeatherForLocation:city:withCompletionHandler:)]) {
        [locationUpdater updateWeatherForLocation:location city:self.currentCity withCompletionHandler:^{
            completionHandler(self.currentCity);
        }];
    } else if ([locationUpdater respondsToSelector:@selector(_updateWeatherForLocation:city:completionHandler:)]) {
        [[objc_getClass("TWCLocationUpdater") sharedLocationUpdater] _updateWeatherForLocation:location city:self.currentCity completionHandler:^{
            completionHandler(self.currentCity);
        }];
    }
}

#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray*)locations {
    if (locations.count > 0) {
        CLLocation *newestLocation = [locations lastObject];
        
        // Get an update for this change!
        [self _refreshWeatherWithLocation:newestLocation andCompletion:^(City *city) {
            [self.delegate didUpdateCity:city];
        }];
    }
}

@end
