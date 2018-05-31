//
//  XIInfoStats.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIInfoStats.h"
#import "XIInfoStatsHeaders.h"

#import <objc/runtime.h>

#include <mach/mach.h>
#import <mach/mach_host.h>
#include <sys/sysctl.h>

#define RAM_REFRESH_INTERVAL 5 // In seconds

@implementation XIInfoStats

#pragma mark Delegate methods

+ (NSString*)topic {
    return @"battery";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    // Stop updating RAM information
    [self.ramUpdateTimer invalidate];
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    // Restart updating RAM information
    self.ramUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:RAM_REFRESH_INTERVAL
                                                           target:self
                                                         selector:@selector(_onUpdateRAM:)
                                                         userInfo:nil
                                                          repeats:YES];
}

// Register a delegate object to call upon when new data becomes available.
// *** This is important for sending data back to widgets!
- (void)registerDelegate:(id<XIWidgetManagerDelegate>)delegate {
    self.delegate = delegate;
}

// Called when a new widget is added, and it needs to be provided new data on load.
- (NSString*)requestCachedData {
    return [self _variablesToJSString];
}

- (void)requestRefresh {
    // Called for new battery information being available.
    
    SBUIController *uiController = [objc_getClass("SBUIController") sharedInstance];
    
    self.cachedBatteryPercent = [uiController batteryCapacityAsPercentage];
    self.cachedBatteryCharging = [uiController isOnAC];
    
    // Send the new data through to widgets
    [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIInfoStats topic]];
}

- (NSString*)_variablesToJSString {
    return [NSString stringWithFormat:@"var batteryPercent = %d, batteryCharging = %d, ramFree = %d, ramUsed = %d, ramAvailable = %d, ramPhysical = %d;", self.cachedBatteryPercent, self.cachedBatteryCharging, self.cachedRamFree, self.cachedRamUsed, self.cachedRamAvailable, self.cachedRamPhysical];
}

#pragma mark Provider specific methods

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Initialise the RAM updater.
        self.ramUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:RAM_REFRESH_INTERVAL
                                                               target:self
                                                             selector:@selector(_onUpdateRAM:)
                                                             userInfo:nil
                                                              repeats:YES];
        
        // Do an initial update of battery information
        SBUIController *uiController = [objc_getClass("SBUIController") sharedInstance];
        
        self.cachedBatteryPercent = [uiController batteryCapacityAsPercentage];
        self.cachedBatteryCharging = [uiController isOnAC];
    }
    
    return self;
}

- (void)_onUpdateRAM:(id)sender {
    self.cachedRamFree = [self ramFree];
    self.cachedRamUsed = [self ramUsed];
    self.cachedRamAvailable = [self ramAvailable];
    self.cachedRamPhysical = [self ramPhysical];
    
    // Send the new data through to widgets
    [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIInfoStats topic]];
}

#pragma mark RAM Information

-(int)ramFree {
    return [self ramDataForType:1];
}

-(int)ramUsed {
    return [self ramDataForType:2];
}

-(int)ramAvailable {
    return [self ramDataForType:0];
}

-(int)ramPhysical {
    return [self ramDataForType:-1];
}

-(int)ramDataForType:(int)type {
    mach_port_t host_port;
    mach_msg_type_number_t host_size;
    vm_size_t pagesize;
    
    host_port = mach_host_self();
    host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);
    
    vm_statistics_data_t vm_stat;
    
    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS)
        NSLog(@"Failed to fetch vm statistics");
    
    /* Stats in bytes */
    NSUInteger giga = 1024*1024;
    
    if (type == 0) {
        return (int)[self getSysInfo:HW_USERMEM] / giga;
    } else if (type == -1) {
        return (int)[self getSysInfo:HW_PHYSMEM] / giga;
    }
    
    natural_t wired = vm_stat.wire_count * (natural_t)pagesize / (1024 * 1024);
    natural_t active = vm_stat.active_count * (natural_t)pagesize / (1024 * 1024);
    natural_t inactive = vm_stat.inactive_count * (natural_t)pagesize / (1024 * 1024);
    if (type == 1) {
        return vm_stat.free_count * (natural_t)pagesize / (1024 * 1024) + inactive; // Inactive is treated as free by iOS
    } else {
        return active + wired;
    }
}

-(NSUInteger)getSysInfo:(uint)typeSpecifier {
    size_t size = sizeof(int);
    int results;
    int mib[2] = {CTL_HW, typeSpecifier};
    sysctl(mib, 2, &results, &size, NULL, 0);
    return (NSUInteger) results;
}

@end
