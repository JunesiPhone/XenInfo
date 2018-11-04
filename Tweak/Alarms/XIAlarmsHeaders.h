//
//  XIAlarmsHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 04/11/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#ifndef XIAlarmsHeaders_h
#define XIAlarmsHeaders_h

@interface ClockManager : NSObject
+ (instancetype)sharedManager;
- (NSArray *)scheduledLocalNotificationsCache;
- (void)refreshScheduledLocalNotificationsCache;
- (void)resetUpdatesToLocalNotificationsCache;
@end

@interface UIConcreteLocalNotification : NSObject
@property (nonatomic,copy) NSString *alertBody;
@property (nonatomic,copy) NSString *alertTitle;
@property (nonatomic,copy) NSTimeZone *timeZone;
@property (assign, nonatomic) BOOL allowSnooze;

- (BOOL)isFromSnooze;
- (id)nextFireDateAfterDate:(id)arg1 localTimeZone:(id)arg2;
- (id)userInfo;
@end

#endif /* XIAlarmsHeaders_h */
