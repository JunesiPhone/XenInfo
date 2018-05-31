//
//  XIWeather.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Internal/XIWidgetDataProvider-Protocol.h"

@interface XIWeather : NSObject <XIWidgetDataProvider>

// Delegate is stored to communicate data back to widgets
@property (nonatomic, weak) id<XIWidgetManagerDelegate> delegate;

// Cached variables between refreshes.

// Provider-specific variables
@property (nonatomic, readwrite) BOOL deviceIsAsleep;
@property (nonatomic, readwrite) BOOL refreshQueuedDuringDeviceSleep;

@end
