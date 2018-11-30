//
//  XIWidgetManager.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "XIWidgetDataProvider-Protocol.h"

#if defined __cplusplus
extern "C" {
#endif
    
    void XenInfoLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...);
    
#if defined __cplusplus
};
#endif

#define Xlog(args...) XenInfoLog(__FILE__,__LINE__,__PRETTY_FUNCTION__,args);

@interface XIWidgetManager : NSObject <XIWidgetManagerDelegate>

@property (nonatomic, strong) NSMutableArray *registeredWidgets;
@property (nonatomic, strong) NSDictionary *widgetDataProviders;

+ (instancetype)sharedInstance;

// Called when a WKWebView navigates to a page other than about:blank
- (void)registerWidget:(id)widget;
// Called when navigated to about:blank
- (void)unregisterWidget:(id)widget;

// Called when a widget attempts navigation to a location prefixed by "xeninfo:"
- (void)widget:(id)widget didRequestAction:(NSString*)action withParameter:(NSString*)parameter;

// Called to request an update for a data provider from a hooked method.
- (void)requestRefreshForDataProviderTopic:(NSString*)topic;

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep;
// Called when the device exits sleep mode
- (void)noteDeviceDidExitSleep;

@end
