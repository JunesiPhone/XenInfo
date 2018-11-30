//
//  XIWeather.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "../Internal/XIWidgetDataProvider-Protocol.h"
#import "XIWeather-Protocol.h"

#import "XITWCWeather.h"
#import "XIWAWeather.h"

@interface XIWeather : NSObject <XIWidgetDataProvider, CLLocationManagerDelegate, XIWeatherDelegate>

// Delegate is stored to communicate data back to widgets
@property (nonatomic, weak) id<XIWidgetManagerDelegate> delegate;

@property (nonatomic, strong) XITWCWeather *twcWeather;
@property (nonatomic, strong) XIWAWeather *waWeather;

@end
