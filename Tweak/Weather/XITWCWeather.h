//
//  XITWCWeather.h
//  XenInfo
//
//  Created by Matt Clarke on 03/11/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XIWeather-Protocol.h"

@class City;

@interface XITWCWeather : NSObject

@property (nonatomic, readwrite) BOOL deviceIsAsleep;
@property (nonatomic, readwrite) BOOL refreshQueuedDuringDeviceSleep;
@property (nonatomic, strong) City *currentCity;

@property (nonatomic, weak) id<XIWeatherDelegate> delegate;

- (void)noteDeviceDidEnterSleep;
- (void)noteDeviceDidExitSleep;
- (void)requestRefresh;

@end
