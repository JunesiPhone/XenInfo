//
//  XIInfoStats.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Internal/XIWidgetDataProvider-Protocol.h"

@interface XIInfoStats : NSObject <XIWidgetDataProvider>

// Delegate is stored to communicate data back to widgets
@property (nonatomic, weak) id<XIWidgetManagerDelegate> delegate;

// Cached variables between refreshes.
@property (nonatomic, readwrite) int cachedRamFree;
@property (nonatomic, readwrite) int cachedRamUsed;
@property (nonatomic, readwrite) int cachedRamAvailable;
@property (nonatomic, readwrite) int cachedRamPhysical;
@property (nonatomic, readwrite) int cachedBatteryPercent;
@property (nonatomic, readwrite) BOOL cachedBatteryCharging;

// Provider-specific variables
@property (nonatomic, strong) NSTimer *ramUpdateTimer;

@end
