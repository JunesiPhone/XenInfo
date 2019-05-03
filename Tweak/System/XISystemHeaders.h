//
//  XISystemHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 21/12/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

@interface SBSearchGesture
+ (instancetype)sharedInstance; // < iOS 11
- (void)revealAnimated:(BOOL)animated;
@end

@interface SBIconController
+ (instancetype)sharedInstance;
- (SBSearchGesture*)searchGesture;
@end

/* Build with 9.2 to support armv7 and armv7s */
@interface UIApplication (Additions)
-(void)openURL:arg1 options:arg2 completionHandler:arg3;
@end
