//
//  XIAlarmsHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 04/11/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#ifndef XIAlarmsHeaders_h
#define XIAlarmsHeaders_h

// Old style

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

// New style

@interface MTAlarmManager : NSObject
-(id)alarms;
+(void)warmUp;
-(void)checkIn;
-(id)nextAlarmsForDate:(id)arg1 maxCount:(unsigned long long)arg2 includeSleepAlarm:(BOOL)arg3 ;
-(id)alarmsSyncIncludingSleepAlarm:(BOOL)arg1 ;
+(id)xeninfo_alarms;
@end

@interface MTAlarm : NSObject
@property (assign, nonatomic) BOOL allowsSnooze;
@property (getter=isSnoozed,nonatomic,readonly) BOOL snoozed; 
@property (nonatomic, readonly) NSDate *nextFireDate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, readonly) NSString *displayTitle;
@property (assign, getter=isEnabled, nonatomic) BOOL enabled;
@end

@interface MTAlarmServer : NSObject
- (void)getAlarmsWithCompletion:(void (^)(NSArray*))arg1;
- (void)startListening;
@end

@interface MTAlarmStorage : NSObject
-(void)loadAlarmsSync;
@end

@interface MTAgent : NSObject
@property (nonatomic,retain) MTAlarmServer * alarmServer;
+(id)agent;
-(MTAlarmStorage *)alarmStorage;
@end

#endif /* XIAlarmsHeaders_h */
