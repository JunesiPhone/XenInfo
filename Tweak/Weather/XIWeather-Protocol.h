//
//  XIWeather-Protocol.h
//  XenInfo
//
//  Created by Matt Clarke on 03/11/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol XIWeatherDelegate <NSObject>
@required
- (void)didUpdateCity:(id)city;
@end
