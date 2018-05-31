//
//  XIWeather.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIWeather.h"

@implementation XIWeather

+ (NSString*)topic {
    return @"weather";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    self.deviceIsAsleep = YES;
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    self.deviceIsAsleep = NO;
    
    // Undertake a refresh if one was queued during sleep.
    if (self.refreshQueuedDuringDeviceSleep) {
        [self requestRefresh];
    }
}

// Register a delegate object to call upon when new data becomes available.
- (void)registerDelegate:(id<XIWidgetManagerDelegate>)delegate {
    self.delegate = delegate;
}

// Called when a new widget is added, and it needs to be provided new data on load.
- (NSString*)requestCachedData {
    return @"";
}

- (void)requestRefresh {
    
}

@end
