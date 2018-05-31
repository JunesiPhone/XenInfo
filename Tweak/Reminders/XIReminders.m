//
//  XIReminders.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIReminders.h"

@implementation XIReminders

#pragma mark Delegate methods

+ (NSString*)topic {
    return @"reminders";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    
}

// Register a delegate object to call upon when new data becomes available.
// *** This is important for sending data back to widgets!
- (void)registerDelegate:(id<XIWidgetManagerDelegate>)delegate {
    self.delegate = delegate;
}

// Called when a new widget is added, and it needs to be provided new data on load.
- (NSString*)requestCachedData {
    return @"";
}

- (void)requestRefresh {
    // Called for new information being available.
}

@end
