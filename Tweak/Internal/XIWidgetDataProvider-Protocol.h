//
//  XIWidgetDataProvider-Protocol.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

@protocol XIWidgetManagerDelegate
// Call to update the delegate with new data on a topic.
- (void)updateWidgetsWithNewData:(NSString*)javascriptString onTopic:(NSString*)topic;
@end

@protocol XIWidgetDataProvider

// The data topic provided by the data provider
+ (NSString*)topic;

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep;
// Called on the reverse
- (void)noteDeviceDidExitSleep;

// Register a delegate object to call upon when new data becomes available.
- (void)registerDelegate:(id<XIWidgetManagerDelegate>)delegate;

// Called when a new widget is added, and it needs to be provided new data on load.
- (NSString*)requestCachedData;

// Called to refresh the data in the provider.
- (void)requestRefresh;
@end
