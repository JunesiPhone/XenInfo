//
//  XISystem.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XISystem.h"
#import "XISystemHeaders.h"

#import <UIKit/UIKit.h>
#import <sys/utsname.h> //device models

#import <objc/runtime.h>

//ipaddress
#include <ifaddrs.h>
#include <arpa/inet.h>

@interface SpringBoard : UIApplication
- (void)launchApplicationWithIdentifier:(NSString*)identifier suspended:(BOOL)suspended;
@end

@implementation XISystem

#pragma mark Delegate methods

+ (NSString*)topic {
    return @"system";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    // Not required.
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    // Not required.
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
    // Not required for system; widgets are updated on load with this information.
}

- (NSString*)_variablesToJSString {
    return [NSString stringWithFormat:@"var systemVersion = '%@', deviceName = '%@', twentyfourhour = '%@', deviceType = '%@', ipAddress = '%@';", self.cachedSystemVersion, self.cachedDeviceName, self.cachedUsing24H ? @"yes" : @"no", self.cachedDeviceModel, self.cachedIPAddress];
}

- (NSString*)_escapeString:(NSString*)input {
    if (!input)
        return @"";
    
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    
    return input;
}

#pragma mark Actions callable by widgets

-(void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier {
    @try {
        [(SpringBoard*)[UIApplication sharedApplication] launchApplicationWithIdentifier:bundleIdentifier suspended:NO];
    } @catch(NSException* err) {
        NSLog(@"XenInfo :: Error launching application: %@", err);
    }
}

-(void)openURL:(NSString *)path {
    NSString* address = [NSString stringWithFormat:@"http://%@", path];
    NSURL *urlPath = [NSURL URLWithString:address];
    
    if ([[UIApplication sharedApplication] canOpenURL:urlPath]) {
        // Handle deprecated openURL: for lower iOS versions.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(openURL:)]) {
            [[UIApplication sharedApplication] openURL:urlPath];
        } else {
            [[UIApplication sharedApplication] openURL:urlPath options:@{} completionHandler:nil];
        }
    }
#pragma clang diagnostic pop
}

- (void)openSpotlight {
    if ([UIDevice currentDevice].systemVersion.floatValue >= 11.0) {
        [[[objc_getClass("SBIconController") sharedInstance] searchGesture] revealAnimated:YES];
    } else {
        [[objc_getClass("SBSearchGesture") sharedInstance] revealAnimated:YES];
    }
}

- (void)logMessage:(NSString*)message {
    NSLog(@"*** XenInfo :: WIDGET :: %@", message);
}

#pragma mark Provider specific methods

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Set our cached variables - they're static for the time SpringBoard runs
        self.cachedSystemVersion = [self _systemVersion];
        self.cachedDeviceName = [self _deviceName];
        self.cachedDeviceModel = [self _deviceModel];
        self.cachedUsing24H = [self _using24h];
        self.cachedIPAddress = [self _ipAddress];
    }
    
    return self;
}

-(NSString *)_ipAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}

// From: http://theiphonewiki.com/wiki/Models
- (NSString*)_deviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machineName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSDictionary *commonNamesDictionary =
    @{
      @"i386":     @"i386 Simulator",
      @"x86_64":   @"x86_64 Simulator",
      
      @"iPhone1,1":    @"iPhone",
      @"iPhone1,2":    @"iPhone 3G",
      @"iPhone2,1":    @"iPhone 3GS",
      @"iPhone3,1":    @"iPhone 4",
      @"iPhone3,2":    @"iPhone 4",
      @"iPhone3,3":    @"iPhone 4",
      @"iPhone4,1":    @"iPhone 4S",
      @"iPhone5,1":    @"iPhone 5",
      @"iPhone5,2":    @"iPhone 5",
      @"iPhone5,3":    @"iPhone 5c",
      @"iPhone5,4":    @"iPhone 5c",
      @"iPhone6,1":    @"iPhone 5s",
      @"iPhone6,2":    @"iPhone 5s",
      @"iPhone7,1":    @"iPhone 6+",
      @"iPhone7,2":    @"iPhone 6",
      @"iPhone8,1":    @"iPhone 6S",
      @"iPhone8,2":    @"iPhone 6S+",
      @"iPhone8,4":    @"iPhone SE",
      @"iPhone9,1":    @"iPhone 7",
      @"iPhone9,2":    @"iPhone 7+",
      @"iPhone9,3":    @"iPhone 7",
      @"iPhone9,4":    @"iPhone 7+",
      @"iPhone10,1":   @"iPhone 8",
      @"iPhone10,4":   @"iPhone 8",
      @"iPhone10,2":   @"iPhone 8+",
      @"iPhone10,5":   @"iPhone 8+",
      @"iPhone10,3":   @"iPhone X",
      @"iPhone10,6":   @"iPhone X",
      @"iPhone11,2":   @"iPhone XS",
      @"iPhone11,4":   @"iPhone XS Max",
      @"iPhone11,6":   @"iPhone XS Max",
      @"iPhone11,8":   @"iPhone XR",
      
      @"iPad1,1":  @"iPad",
      @"iPad2,1":  @"iPad 2",
      @"iPad2,2":  @"iPad 2",
      @"iPad2,3":  @"iPad 2",
      @"iPad2,4":  @"iPad 2",
      @"iPad3,1":  @"iPad 3",
      @"iPad3,2":  @"iPad 3",
      @"iPad3,3":  @"iPad 3",
      @"iPad3,4":  @"iPad 4",
      @"iPad3,5":  @"iPad 4",
      @"iPad3,6":  @"iPad 4",
      @"iPad4,1":  @"iPad Air",
      @"iPad4,2":  @"iPad Air",
      @"iPad4,3":  @"iPad Air",
      @"iPad5,3":  @"iPad Air 2",
      @"iPad5,4":  @"iPad Air 2",
      
      @"iPad2,5":  @"iPad mini",
      @"iPad2,6":  @"iPad mini",
      @"iPad2,7":  @"iPad mini",
      @"iPad4,4":  @"iPad mini 2",
      @"iPad4,5":  @"iPad mini 2",
      @"iPad4,6":  @"iPad mini 2",
      @"iPad4,7":  @"iPad mini 3",
      @"iPad4,8":  @"iPad mini 3",
      @"iPad4,9":  @"iPad mini 3",
      @"iPad5,1":  @"iPad mini 4",
      @"iPad5,2":  @"iPad mini 4",
      
      @"iPod1,1":  @"iPod 1st Gen",
      @"iPod2,1":  @"iPod 2nd Gen",
      @"iPod3,1":  @"iPod 3rd Gen",
      @"iPod4,1":  @"iPod 4th Gen",
      @"iPod5,1":  @"iPod 5th Gen",
      @"iPod7,1":  @"iPod 6th Gen",
      };
    
    NSString *deviceName = commonNamesDictionary[machineName];
    
    if (deviceName == nil) {
        deviceName = machineName;
    }
    
    return deviceName;
}

- (NSString*)_systemVersion {
    return [UIDevice currentDevice].systemVersion;
}

- (NSString*)_deviceName {
    return [self _escapeString:[[UIDevice currentDevice] name]];
}

- (BOOL)_using24h {
    NSString *formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containsA = [formatStringForHours rangeOfString:@"a"];
    
    return containsA.location == NSNotFound;
}

@end
