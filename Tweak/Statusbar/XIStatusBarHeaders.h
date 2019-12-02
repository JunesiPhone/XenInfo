//
//  XIStatusBarHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 28/10/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#ifndef XIStatusBarHeaders_h
#define XIStatusBarHeaders_h


@interface SBTelephonySubscriptionInfo : NSObject
@property (nonatomic,copy,readonly) NSString * SIMLabel;
@property (nonatomic,copy,readonly) NSString * shortSIMLabel;
@property (nonatomic,readonly) unsigned long long signalStrengthBars;
@property (nonatomic,readonly) unsigned long long maxSignalStrengthBars;
@property (nonatomic,copy,readonly) NSString * operatorName;
@property (nonatomic,copy,readonly) NSString * lastKnownNetworkCountryCode;
@end

//iOS13
@interface STTelephonySubscriptionInfo : NSObject
-(NSString *)operatorName;
-(unsigned long long)signalStrengthBars;
-(NSString *)identifier;
@property (nonatomic,readonly) unsigned long long dataConnectionType;
-(unsigned long long)maxSignalStrengthBars;
@end

@interface SBTelephonyManager : NSObject
+ (id)sharedTelephonyManager;
- (int)signalStrengthBars;
- (int)signalStrength;
- (id)operatorName;
-(int)dataConnectionType;

-(SBTelephonySubscriptionInfo*)subscriptionInfo; // iOS 12
-(STTelephonySubscriptionInfo* )_primarySubscriptionInfo; //iOS13
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
