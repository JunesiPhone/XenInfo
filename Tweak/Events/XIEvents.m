//
//  XIEvents.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIEvents.h"
#import <EventKit/EventKit.h>
#import <objc/runtime.h>

@interface XIEvents () {
    dispatch_source_t _source;
}
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) EKEventStore *store;
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation XIEvents

#pragma mark Delegate methods

+ (NSString*)topic {
    return @"events";
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
    NSDate *startDate = [NSDate date];
    NSDate *endDate = [NSDate dateWithTimeInterval:25920000 sinceDate:startDate];
    NSArray *events = [self _calendarEntriesBetweenStartTime:startDate andEndTime:endDate];
    
    // Parse the events!
    NSDate *nextUpdateTime = endDate;
    NSMutableArray *array = [NSMutableArray array];
    for (EKEvent *event in events) {
        NSDictionary *parsedEvent = @{
                                      @"title": [self _escapeString:event.title],
                                      @"location": [self _escapeString:event.location],
                                      @"isAllDay": [NSNumber numberWithBool:event.allDay],
                                      @"date": event.startDate ? [self.dateFormatter stringFromDate:event.startDate] : @"",
                                      @"startTimeTimestamp": [NSNumber numberWithInt:event.startDate.timeIntervalSince1970 * 1000],
                                      @"endTimeTimestamp": [NSNumber numberWithInt:event.endDate.timeIntervalSince1970 * 1000],
                                      @"associatedCalendarName": [self _escapeString:event.calendar.title],
                                      @"associatedCalendarHexColor": [self _hexStringFromColor:event.calendar.CGColor]
                                      };
        
        [array addObject:parsedEvent];
        
        // Update our next update time if needed.
        if (event.endDate.timeIntervalSince1970 < nextUpdateTime.timeIntervalSince1970) {
            nextUpdateTime = event.endDate;
        }
    }
    
    // Schedule the update timer
    NSTimeInterval interval = nextUpdateTime.timeIntervalSince1970 - startDate.timeIntervalSince1970;
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(requestRefresh)
                                                      userInfo:nil
                                                       repeats:NO];
    
    self.entries = array;
    
    // And then send the data through to the widgets
    [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIEvents topic]];
}

- (NSString*)_variablesToJSString {
    NSString *jsonObj = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self.entries
                                                                                       options:0
                                                                                         error:nil]
                                              encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"var events = JSON.parse('%@');", jsonObj];
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_calendarUpdateNotificationRecieved:) name:@"EKEventStoreChangedNotification" object:self.store];
    [self _monitorPath:@"/var/mobile/Library/Preferences/com.apple.mobilecal.plist"];
}

- (void)_calendarUpdateNotificationRecieved:(NSNotification*)notification {
    [self requestRefresh];
}

// This allows us to fire off a callback when the user changes which calendars to display in-app.
// From: InfoStats 2
- (void)_monitorPath:(NSString*)path {
    
    int descriptor = open([path fileSystemRepresentation], O_EVTONLY);
    if (descriptor < 0) {
        return;
    }
    
    __block XIEvents *blockSelf = self;
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, descriptor,                                                  DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE, dispatch_get_global_queue(0, 0));
    
    dispatch_source_set_event_handler(_source, ^{
        unsigned long flags = dispatch_source_get_data(_source);
        
        if (flags & DISPATCH_VNODE_DELETE) {
            [blockSelf _monitorPath:path];
        } else {
            // Update our data.
            [self requestRefresh];
        }
    });
    
    dispatch_source_set_cancel_handler(_source, ^(void) {
        close(descriptor);
    });
    
    dispatch_resume(_source);
}

- (NSArray*)_calendarEntriesBetweenStartTime:(NSDate*)startTime andEndTime:(NSDate*)endTime {
    // Search all calendars
    NSMutableArray *searchableCalendars = [[self.store calendarsForEntityType:EKEntityTypeEvent] mutableCopy];
    
    NSPredicate *predicate = [self.store predicateForEventsWithStartDate:startTime endDate:endTime calendars:searchableCalendars];
    
    // Fetch all events that match the predicate
    NSMutableArray *events = [NSMutableArray arrayWithArray:[self.store eventsMatchingPredicate:predicate]];
    
    // Grab prefs for disabled calendars
    CFPreferencesAppSynchronize(CFSTR("com.apple.mobilecal"));
    
    NSDictionary *settings;
    CFArrayRef keyList = CFPreferencesCopyKeyList(CFSTR("com.apple.mobilecal"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (!keyList) {
        settings = [NSMutableDictionary dictionary];
    } else {
        CFDictionaryRef dictionary = CFPreferencesCopyMultiple(keyList, CFSTR("com.apple.mobilecal"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        
        settings = [(__bridge NSDictionary *)dictionary copy];
        CFRelease(dictionary);
        CFRelease(keyList);
    }

    NSArray *deselected = settings[@"LastDeselectedCalendars"];
    
    for (EKEvent *event in [events copy]) {
        if ([deselected containsObject:event.calendar.calendarIdentifier]) {
            [events removeObject:event];
        }
    }
    
    return events;
}

- (NSString *)_hexStringFromColor:(CGColorRef)color {
    if (!color) {
        return @"#cccccc";
    }
    
    const CGFloat *components = CGColorGetComponents(color);
    
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
            lroundf(r * 255),
            lroundf(g * 255),
            lroundf(b * 255)];
}

@end
