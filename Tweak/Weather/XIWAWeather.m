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

- (void)requestRefresh {
    if (self.deviceIsAsleep) {
        self.refreshQueuedDuringDeviceSleep = YES;
        return;
    }
    
    [self _updateModel:self.todayModel];
}

- (void)_setupTodayModels {
    self.todayModel = [self _loadLocationModel];
    
    // First (delayed) update if needed
    if (![CLLocationManager locationServicesEnabled]) {
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 5.0);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [self requestRefresh];
        });
    }
    
    // Grab current city
    self.currentCity = self.todayModel.forecastModel.city;
}

- (WATodayModel*)_loadLocationModel {
    WeatherPreferences *preferences = [objc_getClass("WeatherPreferences") sharedPreferences];
    
    WATodayAutoupdatingLocationModel *todayModel = [objc_getClass("WATodayModel") autoupdatingLocationModelWithPreferences:preferences effectiveBundleIdentifier:@"com.apple.weather"];
    
    [todayModel setLocationServicesActive:YES];
    [todayModel setIsLocationTrackingEnabled:YES];
    
    [todayModel addObserver:self];
    
    return todayModel;
}

- (void)_updateTimerFired:(NSTimer*)timer {
    [self requestRefresh];
}

- (void)_updateModel:(WATodayModel*)todayModel {
    [todayModel executeModelUpdateWithCompletion:^(BOOL arg1, NSError *arg2) {
        Xlog(@"DEBUG :: executeModelUpdateWithCompletion (block): %d, %@", arg1, arg2);
        if (!arg2) {
            Xlog(@"DEBUG :: Got forecast update (block): %@", todayModel.forecastModel.city);
            [self.delegate didUpdateCity:todayModel.forecastModel.city];
        }
    }];
}

-(void)todayModelWantsUpdate:(WATodayModel*)todayModel {
    [self _updateModel:todayModel];
}

-(void)todayModel:(WATodayModel*)todayModel forecastWasUpdated:(WAForecastModel*)arg2 {
    // Handle this update
    [self.delegate didUpdateCity:arg2.city];
}

@end
