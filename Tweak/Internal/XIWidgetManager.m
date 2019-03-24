//
//  XIWidgetManager.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIWidgetManager.h"

/************************************************************/
/*            ADD NEW DATA PROVIDER HEADERS HERE            */
/************************************************************/

#import "../Battery/XIInfoStats.h"
#import "../System/XISystem.h"
#import "../Music/XIMusic.h"
#import "../Weather/XIWeather.h"
#import "../Events/XIEvents.h"
#import "../Reminders/XIReminders.h"
#import "../Alarms/XIAlarms.h"
#import "../Statusbar/XIStatusBar.h"

#import "../../ThirdParty/Reachability/Reachability.h"

static NSString *nsDomainString = @"com.junesiphone.xeninfosettings";
@interface NSUserDefaults (nosblandscape)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end


// Debug logging with nice printing
void XenInfoLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...) {
    // Type to hold information about variable arguments.
    
    va_list ap;
    
    // Initialize a variable argument list.
    va_start (ap, format);
    
    if (![format hasSuffix:@"\n"]) {
        format = [format stringByAppendingString:@"\n"];
    }
    
    NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
    
    // End using variable argument list.
    va_end(ap);
    
    NSString *fileName = [[NSString stringWithUTF8String:file] lastPathComponent];
    
    NSLog(@"XenInfo :: (%s:%d) %s",
          [fileName UTF8String],
          lineNumber, [body UTF8String]);
}

@interface XIWidgetManager ()
@property (nonatomic, strong) NSMutableDictionary *queuedUpdatesWhileDeviceSleeping;
@property (nonatomic, readwrite) BOOL deviceSleepState;
@end

/*
 * This class handles management of widgets added by the user by any tweak, including Xen HTML
 * and AnemoneHTML.
 *
 * You only need to modify it when adding a new data provider, or a new widget command.
 */

@implementation XIWidgetManager

// We use a sharedInstance pattern to provide a singleton to communicate with in hooked methods.
+ (instancetype)sharedInstance {
    static XIWidgetManager *sharedSelf = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedSelf = [[XIWidgetManager alloc] init];
    });
    
    return sharedSelf;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Setup arrays.
        self.registeredWidgets = [NSMutableArray array];
        self.widgetSettings = [self _populateWidgetSettings];
        self.widgetDataProviders = [self _populateWidgetDataProviders];
        
        self.queuedUpdatesWhileDeviceSleeping = [NSMutableDictionary dictionary];
        self.deviceSleepState = NO;
        
        for (id<XIWidgetDataProvider> provider in self.widgetDataProviders.allValues) {
            [provider registerDelegate:self];
        }
        
        // Setup network connectivity notifications
        Reachability* reach = [Reachability reachabilityWithHostname:@"www.google.com"];
        
        reach.reachableBlock = ^(Reachability *reach) {
            for (NSString *topic in self.widgetDataProviders.allKeys) {
                id<XIWidgetDataProvider> provider = [self.widgetDataProviders objectForKey:topic];
                    
                if ([provider respondsToSelector:@selector(networkWasConnected)])
                    [provider networkWasConnected];
            }
        };
        
        reach.unreachableBlock = ^(Reachability *reach) {
            for (NSString *topic in self.widgetDataProviders.allKeys) {
                id<XIWidgetDataProvider> provider = [self.widgetDataProviders objectForKey:topic];
                
                if ([provider respondsToSelector:@selector(networkWasDisconnected)])
                    [provider networkWasDisconnected];
            }
        };
        
        // Start the notifier, retains itself
        [reach startNotifier];
    }
    
    return self;
}

-(NSMutableDictionary*)_populateWidgetSettings{
    NSMutableDictionary *settingsDict = [@{} mutableCopy];
    NSNumber *alarms = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"alarms" inDomain:nsDomainString];
    NSNumber *battery = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"battery" inDomain:nsDomainString];
    NSNumber *events = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"events" inDomain:nsDomainString];
    NSNumber *music = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"music" inDomain:nsDomainString];
    NSNumber *reminders = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"reminders" inDomain:nsDomainString];
    NSNumber *statusbar = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"statusbar" inDomain:nsDomainString];
    NSNumber *system = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"system" inDomain:nsDomainString];
    NSNumber *weather = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"weather" inDomain:nsDomainString];
    
    //set enabled if no value.
    bool alarmBool = (alarms) ? [alarms boolValue] : YES;
    bool batteryBool = (battery) ? [battery boolValue] : YES;
    bool eventsBool = (events) ? [events boolValue] : YES;
    bool musicBool = (music) ? [music boolValue] : YES;
    bool remindersBool = (reminders) ? [reminders boolValue] : YES;
    bool statusbarBool = (statusbar) ? [statusbar boolValue] : YES;
    bool systemBool = (system) ? [system boolValue] : YES;
    bool weatherBool = (weather) ? [weather boolValue] : YES;

    [settingsDict setObject:[NSNumber numberWithBool:alarmBool] forKey:@"alarm"];
    [settingsDict setObject:[NSNumber numberWithBool:batteryBool] forKey:@"battery"];
    [settingsDict setObject:[NSNumber numberWithBool:eventsBool] forKey:@"events"];
    [settingsDict setObject:[NSNumber numberWithBool:musicBool] forKey:@"music"];
    [settingsDict setObject:[NSNumber numberWithBool:remindersBool] forKey:@"reminders"];
    [settingsDict setObject:[NSNumber numberWithBool:statusbarBool] forKey:@"statusbar"];
    [settingsDict setObject:[NSNumber numberWithBool:systemBool] forKey:@"system"];
    [settingsDict setObject:[NSNumber numberWithBool:weatherBool] forKey:@"weather"];

    return settingsDict;
}

- (NSDictionary*)_populateWidgetDataProviders {
    NSMutableDictionary *dict = [@{} mutableCopy];
    NSMutableDictionary* settingsDict = self.widgetSettings;
    
    /*****************************************************/
    /*            ADD NEW DATA PROVIDERS HERE            */
    /*****************************************************/
    
    // InfoStats (battery and RAM)
    if([[settingsDict objectForKey:@"battery"] boolValue]){
        XIInfoStats *isProvider = [[XIInfoStats alloc] init];
        [dict setObject:isProvider forKey:[XIInfoStats topic]];
    }
    
    // System
    if([[settingsDict objectForKey:@"system"] boolValue]){
        XISystem *systemProvider = [[XISystem alloc] init];
        [dict setObject:systemProvider forKey:[XISystem topic]];
    }
    
    // Music
    if([[settingsDict objectForKey:@"music"] boolValue]){
        XIMusic *musicProvider = [[XIMusic alloc] init];
        [dict setObject:musicProvider forKey:[XIMusic topic]];
    }
    
    // Weather
    if([[settingsDict objectForKey:@"weather"] boolValue]){
        XIWeather *weatherProvider = [[XIWeather alloc] init];
        [dict setObject:weatherProvider forKey:[XIWeather topic]];
    }
    
    // Events
    if([[settingsDict objectForKey:@"events"] boolValue]){
        XIEvents *eventsProvider = [[XIEvents alloc] init];
        [dict setObject:eventsProvider forKey:[XIEvents topic]];
    }
    
    // Reminders
    if([[settingsDict objectForKey:@"reminders"] boolValue]){
        XIReminders *remindersProvider = [[XIReminders alloc] init];
        [dict setObject:remindersProvider forKey:[XIReminders topic]];
    }
    
    // Alarms
    if([[settingsDict objectForKey:@"alarm"] boolValue]){
        XIAlarms *alarmsProvider = [[XIAlarms alloc] init];
        [dict setObject:alarmsProvider forKey:[XIAlarms topic]];
    }
    
    // Statusbar
    if([[settingsDict objectForKey:@"statusbar"] boolValue]){
        XIStatusBar *statusbarProvider = [[XIStatusBar alloc] init];
        [dict setObject:statusbarProvider forKey:[XIStatusBar topic]];
    }
    
    return dict;
}

- (void)registerWidget:(id)widget {
    // TODO: Check this widget implements mainUpdate().
    
    [self.registeredWidgets addObject:widget];
    
    // Give this widget all the currently known data!
    [self _updateWidgetWithCachedInformation:widget];
}

- (void)unregisterWidget:(id)widget {
    if ([self.registeredWidgets containsObject:widget])
        [self.registeredWidgets removeObject:widget];
}

- (void)widget:(id)widget didRequestAction:(NSString*)action withParameter:(NSString*)parameter {
    
    /*****************************************************/
    /*           ADD NEW WIDGET COMMANDS HERE            */
    /*****************************************************/
    
    if ([action isEqualToString:@"playpause"]) {
        
        // Handle in Music provider
        XIMusic *musicProvider = [self.widgetDataProviders objectForKey:[XIMusic topic]];
        [musicProvider togglePlayState];
        
    } else if ([action isEqualToString:@"nexttrack"]) {
        
        // Handle in Music provider
        XIMusic *musicProvider = [self.widgetDataProviders objectForKey:[XIMusic topic]];
        [musicProvider advanceTrack];
        
    } else if ([action isEqualToString:@"prevtrack"]) {
        
        // Handle in Music provider
        XIMusic *musicProvider = [self.widgetDataProviders objectForKey:[XIMusic topic]];
        [musicProvider retreatTrack];
        
    } else if ([action isEqualToString:@"toggleShuffle"]){

        // Handle in Music provider
        XIMusic *musicProvider = [self.widgetDataProviders objectForKey:[XIMusic topic]];
        [musicProvider triggerShuffle];

    } else if ([action isEqualToString:@"toggleRepeat"]){

        // Handle in Music provider
        XIMusic *musicProvider = [self.widgetDataProviders objectForKey:[XIMusic topic]];
        [musicProvider triggerRepeat];

    } else if ([action isEqualToString:@"openapp"]) {
        
        // Handle in System provider
        XISystem *systemProvider = [self.widgetDataProviders objectForKey:[XISystem topic]];
        [systemProvider openApplicationWithBundleIdentifier:parameter];
        
    } else if ([action isEqualToString:@"openurl"]) {
        
        // Handle in System provider
        XISystem *systemProvider = [self.widgetDataProviders objectForKey:[XISystem topic]];
        [systemProvider openURL:parameter];
        
    } else if ([action isEqualToString:@"openspotlight"]) {
        
        // Handle in System provider
        XISystem *systemProvider = [self.widgetDataProviders objectForKey:[XISystem topic]];
        [systemProvider openSpotlight];
        
    } else if ([action isEqualToString:@"consolelog"]) {
        
        // Handle in System provider
        XISystem *systemProvider = [self.widgetDataProviders objectForKey:[XISystem topic]];
        [systemProvider logMessage:parameter];
        
    }
    
}

- (void)updateWidgetsWithNewData:(NSString*)javascriptString onTopic:(NSString*)topic {
    if (YES == self.deviceSleepState) {
        // Save this update for when the device wakes, to avoid any weirdness like screen freezes!
        // Only store the latest update
        [self.queuedUpdatesWhileDeviceSleeping setObject:javascriptString forKey:topic];
    } else {
        Xlog(@"Updating with '%@' on '%@'", javascriptString, topic);
    
        [self _updateWidgetsWithNewData:javascriptString onTopic:topic];
    }
}

- (void)_updateWidgetsWithNewData:(NSString*)javascriptString onTopic:(NSString*)topic {
    // NOTE: Scheduling the entire loop below on the main thread is a bad idea
    // This can cause choppiness in animations - better to submit smaller blocks per widget that
    // can be serialised on the main thread around other executions
    
    // Loop over widget array, and call update as required.
    for (id widget in self.registeredWidgets) {
        if ([[widget class] isEqual:[UIWebView class]]) {
            // Update JS variables
            // Ensure we update widgets on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                [widget stringByEvaluatingJavaScriptFromString:javascriptString];
            
                // Notify of new change to variables
                NSString* function = [NSString stringWithFormat:@"mainUpdate('%@')", topic];
                [widget stringByEvaluatingJavaScriptFromString:function];
            });
        } else if ([[widget class] isEqual:[WKWebView class]]) {
            // Update JS variables
            dispatch_async(dispatch_get_main_queue(), ^{
                [widget evaluateJavaScript:javascriptString completionHandler:^(id object, NSError *error) {}];
            
                // Notify of new change to variables
                NSString* function = [NSString stringWithFormat:@"mainUpdate('%@')", topic];
                [widget evaluateJavaScript:function completionHandler:^(id object, NSError *error) {}];
            });
        }
    }
}

- (void)requestRefreshForDataProviderTopic:(NSString*)topic {
    id<XIWidgetDataProvider> provider = [self.widgetDataProviders objectForKey:topic];
    [provider requestRefresh];
}

- (void)_updateWidgetWithCachedInformation:(id)widget {
    // Give this widget the current known data!
    for (NSString *topic in self.widgetDataProviders.allKeys) {
        id<XIWidgetDataProvider> provider = [self.widgetDataProviders objectForKey:topic];
        
        NSString *cachedData = [provider requestCachedData];
        
        if ([[widget class] isEqual:[UIWebView class]]) {
            // Update JS variables
            [widget stringByEvaluatingJavaScriptFromString:cachedData];
            
            // Notify of new change to variables
            NSString* function = [NSString stringWithFormat:@"mainUpdate('%@')", topic];
            [widget stringByEvaluatingJavaScriptFromString:function];
        } else if ([[widget class] isEqual:[WKWebView class]]) {
            // Update JS variables
            [widget evaluateJavaScript:cachedData completionHandler:^(id object, NSError *error) {}];
            
            // Notify of new change to variables
            NSString* function = [NSString stringWithFormat:@"mainUpdate('%@')", topic];
            [widget evaluateJavaScript:function completionHandler:^(id object, NSError *error) {}];
        }
    }
}

- (void)noteDeviceDidEnterSleep {
    self.deviceSleepState = YES;
    
    for (id<XIWidgetDataProvider> provider in self.widgetDataProviders.allValues) {
        [provider noteDeviceDidEnterSleep];
    }
    
    Xlog(@"Device did enter sleep");
}

- (void)noteDeviceDidExitSleep {
    Xlog(@"Device did exit sleep");
    
    self.deviceSleepState = NO;
    
    for (id<XIWidgetDataProvider> provider in self.widgetDataProviders.allValues) {
        [provider noteDeviceDidExitSleep];
    }
    
    // Run any queued data updates
    Xlog(@"Running queued updates. Count: %d", [self.queuedUpdatesWhileDeviceSleeping.allKeys count]);
    for (NSString *topic in [self.queuedUpdatesWhileDeviceSleeping allKeys]) {
        NSString *javascriptString = self.queuedUpdatesWhileDeviceSleeping[topic];
        
        [self updateWidgetsWithNewData:javascriptString onTopic:topic];
        
        [self.queuedUpdatesWhileDeviceSleeping removeObjectForKey:topic];
    }
}

@end
