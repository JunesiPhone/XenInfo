//
//  XIStatusBar.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIStatusBar.h"
#import "XIStatusBarHeaders.h"
#import <objc/runtime.h>

@interface XIStatusBar ()
@property (nonatomic, strong) NSNumber *signalStrengthRSSI;
@property (nonatomic, strong) NSNumber *signalStrengthBars;
@property (nonatomic, strong) NSString *operatorName;
@property (nonatomic, strong) NSNumber *wifiStrengthRSSI;
@property (nonatomic, strong) NSNumber *wifiStrengthBars;
@property (nonatomic, strong) NSString *wifiNetworkName;
@property (nonatomic, readwrite) BOOL bluetoothConnected;
@end

@implementation XIStatusBar

#pragma mark Delegate methods

+ (NSString*)topic {
    return @"statusbar";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    // Not needed
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    // Not needed
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
    [self _updateData];
    
    // And then send the data through to the widgets
    [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIStatusBar topic]];
}

- (void)_updateData {
    // Handle telephony first.
    SBTelephonyManager *telephonyManager = [objc_getClass("SBTelephonyManager") sharedTelephonyManager];
    
    // RSSI
    if ([telephonyManager respondsToSelector:@selector(signalStrength)])
        self.signalStrengthRSSI = [NSNumber numberWithInt:[telephonyManager signalStrength]];
    else
        self.signalStrengthRSSI = [NSNumber numberWithInt:0];
    
    // Bars
    if ([telephonyManager respondsToSelector:@selector(signalStrengthBars)])
        self.signalStrengthBars = [NSNumber numberWithInt:[telephonyManager signalStrengthBars]];
    else if ([telephonyManager respondsToSelector:@selector(subscriptionInfo)])
        self.signalStrengthBars = [NSNumber numberWithInt:[telephonyManager subscriptionInfo].signalStrengthBars];
    else
        self.signalStrengthBars = [NSNumber numberWithInt:0];
    
    // Operator name
    if ([telephonyManager respondsToSelector:@selector(operatorName)])
        self.operatorName = [self _escapeString:[telephonyManager operatorName]];
    else if ([telephonyManager respondsToSelector:@selector(subscriptionInfo)])
        self.operatorName = [self _escapeString:[telephonyManager subscriptionInfo].operatorName];
    else
        self.operatorName = @"";
    
    if (!self.operatorName || [self.operatorName isEqualToString:@"(null)"] || [self.operatorName isEqualToString:@""])
        self.operatorName = @"NA";
    
    // Wifi
    SBWiFiManager *wifiManager = [objc_getClass("SBWiFiManager") sharedInstance];
    
    self.wifiStrengthRSSI = [NSNumber numberWithInt:[wifiManager signalStrengthRSSI]];
    self.wifiStrengthBars = [NSNumber numberWithInt:[wifiManager signalStrengthBars]];
    self.wifiNetworkName = [self _escapeString:[wifiManager currentNetworkName]];
    if (!self.wifiNetworkName || [self.wifiNetworkName isEqualToString:@"(null)"] || [self.wifiNetworkName isEqualToString:@""])
        self.wifiNetworkName = @"NA";
    
    // Bluetooth
    BluetoothManager *bluetoothManager = [objc_getClass("BluetoothManager") sharedInstance];
    self.bluetoothConnected = [bluetoothManager enabled];
}

- (NSString*)_variablesToJSString {
    return [NSString stringWithFormat:@"var signalStrength = '%@', signalBars = '%@', signalName = '%@', wifiStrength = '%@', wifiBars = '%@', wifiName = '%@', bluetoothOn = '%@';", self.signalStrengthRSSI, self.signalStrengthBars,
            self.operatorName, self.wifiStrengthRSSI, self.wifiStrengthBars, self.wifiNetworkName, [NSNumber numberWithBool:self.bluetoothConnected]];
}

- (NSString*)_escapeString:(NSString*)input {
    if (!input)
        return @"";
    
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    
    return input;
}

@end
