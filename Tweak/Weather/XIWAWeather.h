//
//  XIWAWeather.h
//  XenInfo
//
//  Created by Matt Clarke on 03/11/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XIWeatherHeaders.h"
#import "XIWeather-Protocol.h"

@class City;

@interface XIWAWeather : NSObject <WATodayModelObserver> {
    BOOL _ignoreUpdateFlag;
}

@property (nonatomic, strong) City *currentCity;
@property (nonatomic, weak) id<XIWeatherDelegate> delegate;

- (void)noteDeviceDidEnterSleep;
- (void)noteDeviceDidExitSleep;
- (void)networkWasDisconnected;
- (void)networkWasConnected;
- (void)requestRefresh;

@end
