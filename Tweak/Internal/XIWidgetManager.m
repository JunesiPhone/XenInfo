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
        self.widgetDataProviders = [self _populateWidgetDataProviders];
        
        for (id<XIWidgetDataProvider> provider in self.widgetDataProviders.allValues) {
            [provider registerDelegate:self];
        }
    }
    
    return self;
}

- (NSDictionary*)_populateWidgetDataProviders {
    NSMutableDictionary *dict = [@{} mutableCopy];
    
    /*****************************************************/
    /*            ADD NEW DATA PROVIDERS HERE            */
    /*****************************************************/
    
    // InfoStats
    XIInfoStats *isProvider = [[XIInfoStats alloc] init];
    [dict setObject:isProvider forKey:[XIInfoStats topic]];
    
    // System
    XISystem *systemProvider = [[XISystem alloc] init];
    [dict setObject:systemProvider forKey:[XISystem topic]];
    
    // Music
    XIMusic *musicProvider = [[XIMusic alloc] init];
    [dict setObject:musicProvider forKey:[XIMusic topic]];
    
    // Weather
    XIWeather *weatherProvider = [[XIWeather alloc] init];
    [dict setObject:weatherProvider forKey:[XIWeather topic]];
    
    return dict;
}

- (void)registerWidget:(WKWebView*)widget {
    [self.registeredWidgets addObject:widget];
}

- (void)unregisterWidget:(WKWebView*)widget {
    [self.registeredWidgets removeObject:widget];
}

- (void)widget:(WKWebView*)widget didRequestAction:(NSString*)action withParameter:(NSString*)parameter {
    
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
        
    }
    
    
}

- (void)updateWidgetsWithNewData:(NSString*)javascriptString onTopic:(NSString*)topic {
    Xlog(@"Updating with '%@' on '%@'", javascriptString, topic);
    
    // Loop over widget array, and call update as required.
    for (WKWebView *widget in self.registeredWidgets) {
        // Update JS variables
        [widget evaluateJavaScript:javascriptString completionHandler:^(id object, NSError *error) {}];
        
        // Notify of new change to variables
        NSString* function = [NSString stringWithFormat:@"mainUpdate('%@')", topic];
        [widget evaluateJavaScript:function completionHandler:^(id object, NSError *error) {}];
    }
}

- (void)requestRefreshForDataProviderTopic:(NSString*)topic {
    id<XIWidgetDataProvider> provider = [self.widgetDataProviders objectForKey:topic];
    [provider requestRefresh];
}

- (void)_updateWidgetWithCachedInformation:(WKWebView*)widget {
    // TODO.
}

@end