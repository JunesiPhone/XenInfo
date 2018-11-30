//
//  XISystem.h
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Internal/XIWidgetDataProvider-Protocol.h"

@interface XISystem : NSObject <XIWidgetDataProvider>

// Delegate is stored to communicate data back to widgets
@property (nonatomic, weak) id<XIWidgetManagerDelegate> delegate;

// Each is called as an action from XIWidgetManager.
-(void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier;
-(void)openURL:(NSString *)path;

// Cached variables between refreshes.
@property (nonatomic, strong) NSString *cachedSystemVersion;
@property (nonatomic, strong) NSString *cachedDeviceName;
@property (nonatomic, strong) NSString *cachedDeviceModel;
@property (nonatomic, readwrite) BOOL cachedUsing24H;

@end
