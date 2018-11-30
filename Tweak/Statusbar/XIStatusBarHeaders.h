//
//  XIStatusBarHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 28/10/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#ifndef XIStatusBarHeaders_h
#define XIStatusBarHeaders_h

@interface SBTelephonyManager : NSObject
+ (id)sharedTelephonyManager;
- (int)signalStrengthBars;
- (int)signalStrength;
- (id)operatorName;
@end

@interface SBWiFiManager : NSObject
+(id)sharedInstance;
- (int)signalStrengthRSSI;
- (int)signalStrengthBars;
- (id)currentNetworkName;
@end

@interface BluetoothManager : NSObject
+ (id)sharedInstance;
- (BOOL)enabled;
@end

#endif /* XIStatusBarHeaders_h */
