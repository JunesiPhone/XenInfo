//
//  XIReminders.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIReminders.h"
#import <EventKit/EventKit.h>
#import <objc/runtime.h>

@interface XIReminders ()
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) EKEventStore *store;
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation XIReminders

#pragma mark Delegate methods

+ (NSString*)topic {
    return @"reminders";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    // nop
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    // nop
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
    [self.updateTimer invalidate];
    
    // Called for new information being available.
    NSArray *reminders = [self _reminderEntries];
    
    // Parse the reminders!
    NSDate *nextUpdateTime = [NSDate dateWithTimeInterval:60*60 sinceDate:[NSDate date]]; // In an hour
    NSMutableArray *array = [NSMutableArray array];
    for (EKReminder *reminder in reminders) {
        if (reminder.isCompleted) {
            continue;
        }
        
        NSDictionary *parsed = @{
                                      @"title": [self _escapeString:reminder.title],
                                      @"dueDate": [self.dateFormatter stringFromDate:[self _dueDateFromReminder:reminder]],
                                      @"dueDateTimestamp": [NSNumber numberWithInt:[self _dueDateFromReminder:reminder].timeIntervalSince1970 * 1000],
                                      @"priority": [NSNumber numberWithLong:reminder.priority]
                                      };
    
        [array addObject:parsed];
        
        // Update our next update time if needed.
        /*if ([reminder completionDate].timeIntervalSince1970 < nextUpdateTime.timeIntervalSince1970 && reminder.completed) {
            nextUpdateTime = [reminder dueDate];
        }*/
    }
    
    // Schedule the update timer
    NSTimeInterval interval = nextUpdateTime.timeIntervalSince1970 - [NSDate date].timeIntervalSince1970;
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(requestRefresh)
                                                      userInfo:nil
                                                       repeats:NO];
    
    self.entries = array;
    
    // And then send the data through to the widgets
    [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIReminders topic]];
}

- (NSString*)_variablesToJSString {
    NSString *jsonObj = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self.entries
                                                                                       options:0
                                                                                         error:nil]
                                              encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"var reminders = JSON.parse('%@');", jsonObj];
}

- (NSString*)_escapeString:(NSString*)input {
    if (!input)
        return @"";
    
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    
    return input;
}

#pragma mark Provider specific methods

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.store = [[EKEventStore alloc] init];
        self.entries = @[];
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.dateFormatter.timeStyle = NSDateFormatterNoStyle;
        self.dateFormatter.dateStyle = NSDateFormatterShortStyle;
        
        [self _setupNotificationMonitoring];
        
        // Get initial data after a delay
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 5.0);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [self requestRefresh];
        });
    }
    
    return self;
}

- (void)_setupNotificationMonitoring {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reminderUpdateNotificationRecieved:) name:@"EKEventStoreChangedNotification" object:self.store];
}

- (void)_reminderUpdateNotificationRecieved:(NSNotification*)notification {
    [self requestRefresh];
}

- (NSArray*)_reminderEntries {
    // Search all calendars
    NSMutableArray *searchableCalendars = [[self.store calendarsForEntityType:EKEntityTypeReminder] mutableCopy];
    NSPredicate *predicate = [self.store predicateForRemindersInCalendars:searchableCalendars];
    
    // Fetch all events that match the predicate
    NSMutableArray *reminders = [NSMutableArray arrayWithArray:[self.store eventsMatchingPredicate:predicate]];
    
    return reminders;
}

- (NSDate*)_dueDateFromReminder:(EKReminder*)reminder {
    NSDateComponents *components = reminder.dueDateComponents;
    
    if (!components) {
        components = reminder.startDateComponents;
        
        if (!components) {
            return [NSDate date];
        }
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    return [calendar dateFromComponents:reminder.dueDateComponents];
}

@end
