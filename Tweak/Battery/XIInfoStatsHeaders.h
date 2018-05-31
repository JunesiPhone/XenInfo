//
//  XIInfoStatsHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

@interface SBUIController : NSObject
+(instancetype)sharedInstanceIfExists;
-(BOOL)isOnAC;
-(int)batteryCapacityAsPercentage;
@end
