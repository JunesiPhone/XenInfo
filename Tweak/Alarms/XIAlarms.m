//
//  XIAlarms.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIAlarms.h"
#import "XIAlarmsHeaders.h"
#import <objc/runtime.h>

@interface XIAlarms ()
@property (nonatomic, strong) NSArray *alarms;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSDateFormatter *weekdayFormatter;
@end

@implementation XIAlarms

#pragma mark Delegate methods

+ (NSString*)topic {
    return @"alarm";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {}

// Called on the reverse
- (void)noteDeviceDidExitSleep {}

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
    // Called for new information being available.
    
    ClockManager *manager = [objc_getClass("ClockManager") sharedManager];
    
    if ([manager respondsToSelector:@selector(refreshScheduledLocalNotificationsCache)]) {
        [manager refreshScheduledLocalNotificationsCache];
    }
    
    NSArray *alarms = [manager scheduledLocalNotificationsCache];
    if (!alarms) {
        self.alarms = @[];
        
        // And then send the data through to the widgets
        [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIAlarms topic]];
    } else {
        NSMutableArray *parsedAlarms = [NSMutableArray array];
        
        for (UIConcreteLocalNotification *notification in alarms) {
            NSDate *fireDate = [notification nextFireDateAfterDate:[NSDate date] localTimeZone:notification.timeZone];
            
            NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitHour | NSCalendarUnitWeekday | NSCalendarUnitMinute fromDate:fireDate];
            int weekday = components.weekday - 1;
            int hour = components.hour;
            int minute = components.minute;
            
            NSString *weekdayStr = [NSString stringWithFormat:@"%d", weekday];
            NSString *hourStr = hour < 10 ? [NSString stringWithFormat:@"0%d", hour] : [NSString stringWithFormat:@"%d", hour];
            NSString *minuteStr = minute < 10 ? [NSString stringWithFormat:@"0%d", minute] : [NSString stringWithFormat:@"%d", minute];
            
            NSString *body = notification.alertBody ? notification.alertBody : @"";
            if ([body isEqualToString:@"ALARM_DEFAULT_TITLE"]) {
                body = @"Alarm"; // TODO: Translate me!
            }
            
            NSDictionary *parsedAlarm = @{
                                          @"title": notification.alertTitle ? notification.alertTitle : @"",
                                          @"body": body,
                                          @"nextFireDateTimestamp": [NSNumber numberWithDouble:[fireDate timeIntervalSince1970]],
                                          @"nextFireDateTimeParsed": [self _parseDateToTimeString:fireDate],
                                          @"nextFireDateDayParsed": [self _parseDateToDayString:fireDate],
                                          @"allowSnooze": [NSNumber numberWithBool:notification.allowSnooze],
                                          @"repeatingFromSnoozed": [NSNumber numberWithBool:[notification isFromSnooze]],
                                          @"legacyFireDateMinute": minuteStr,
                                          @"legacyFireDateHour": hourStr,
                                          @"legacyFireDateDay": weekdayStr,
                                          };
            
            [parsedAlarms addObject:parsedAlarm];
        }
        
        self.alarms = parsedAlarms;
        
        // And then send the data through to the widgets
        [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIAlarms topic]];
    }
}

- (NSString*)_parseDateToTimeString:(NSDate*)date {
    return [self.timeFormatter stringFromDate:date];
}

- (NSString*)_parseDateToDayString:(NSDate*)date {
    return [self.weekdayFormatter stringFromDate:date];
}

- (NSString*)_variablesToJSString {
    // Generate legacy stuff first
    NSDictionary *firstAlarm = self.alarms.count > 0 ? self.alarms[0] : nil;
    NSString *legacyUpdate = @"";
    
    if (firstAlarm) {
        legacyUpdate = [NSString stringWithFormat:@"var alarmString = '%@', alarmTime = '%@', alarmHour = '%@', alarmMinute = '%@', alarmDay = '%@';", firstAlarm[@"nextFireDateTimeParsed"], firstAlarm[@"nextFireDateTimeParsed"], firstAlarm[@"legacyFireDateHour"], firstAlarm[@"legacyFireDateMinute"], firstAlarm[@"legacyFireDateDay"]];
    }
    
    NSString *jsonObj = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self.alarms
                                                                                        options:0
                                                                                          error:nil]
                                               encoding:NSUTF8StringEncoding];
    NSString *fullDatasetUpdate = [NSString stringWithFormat:@"var alarms = JSON.parse('%@');", jsonObj];
    
    return [NSString stringWithFormat:@"%@ %@", legacyUpdate, fullDatasetUpdate];
}

- (NSString*)_escapeString:(NSString*)input {
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    
    return input;
}

#pragma mark Provider specific methods

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.alarms = @[];
        
        self.timeFormatter = [[NSDateFormatter alloc] init];
        self.timeFormatter.timeStyle = NSDateFormatterShortStyle;
        self.timeFormatter.dateStyle = NSDateFormatterNoStyle;
        
        self.weekdayFormatter = [[NSDateFormatter alloc] init];
        [self.weekdayFormatter setDateFormat:@"EEEE"];
        
        // Get initial data after a delay
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 5.0);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [self requestRefresh];
        });
    }
    
    return self;
}

@end
