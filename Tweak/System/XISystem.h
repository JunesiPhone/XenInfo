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

@property (nonatomic, weak) id<XIWidgetManagerDelegate> delegate;

@end
