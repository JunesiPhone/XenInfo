///////////////////////////////////////////////////////////////
#pragma mark Headers
///////////////////////////////////////////////////////////////

#import "Internal/XIWidgetManager.h"

#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@class WebView;
@class WebScriptObject;

@interface WebFrame : NSObject
- (id)dataSource;
@end

@interface WKWebView (Additions)
@property (nonatomic, assign) id<WKNavigationDelegate> hijackedNavigationDelegate;
@end

@interface UIWebView (Additions)
@property (nonatomic, assign) id<UIWebViewDelegate> hijackedDelegate;
@end

///////////////////////////////////////////////////////////////
#pragma mark Internal Hooks
///////////////////////////////////////////////////////////////

#pragma mark Add any webviews to our widget manager as required.

// WKWebView handling
%hook WKWebView

- (void)_didFinishLoadForMainFrame {
    %orig;

    // Loading has ended; add to manager if required.

    NSString *url = [self.URL absoluteString];
    
    if (![url isEqualToString:@""] && ![url isEqualToString:@"about:blank"]) {
        Xlog(@"Registering widget (WKWebView) for URL: %@", url);
        [[XIWidgetManager sharedInstance] registerWidget:self];
    }
}

- (void)removeFromSuperview {
    // Not a great hook, but should work!
    NSString *href = [self. URL absoluteString];
    
    Xlog(@"Unregistering widget (WKWebView) for URL: %@", href);
    [[XIWidgetManager sharedInstance] unregisterWidget:self];
    
    %orig;
}

%end

%hook WKContentView

- (void)_webViewDestroyed {
    // Catch destroyed event from WKContentView
    WKWebView *webView = MSHookIvar<WKWebView*>(self, "_webView");
    if (webView) {
        NSString *url = [webView.URL absoluteString];
        Xlog(@"Unregistering widget (WKWebView) for URL: %@", url);
        [[XIWidgetManager sharedInstance] unregisterWidget:webView];
    }
    
    %orig;
}

%end

// UIWebView handling
%hook UIWebView

- (void)webView:(WebView *)webview didClearWindowObject:(WebScriptObject *)window forFrame:(WebFrame *)frame {
    %orig;
    
    NSString *href = [[[[frame dataSource] request] URL] absoluteString];
    
    if (href && ![href isEqualToString:@""] && ![href isEqualToString:@"about:blank"]) {
        Xlog(@"Registering widget (UIWebView) for href: %@", href);
        [[XIWidgetManager sharedInstance] registerWidget:self];
    }
}

- (void)removeFromSuperview {
    // Not a great hook, but should work!
    NSString *href = [[self.request URL] absoluteString];
    
    Xlog(@"Unregistering widget (UIWebView) for href: %@", href);
    [[XIWidgetManager sharedInstance] unregisterWidget:self];
    
    %orig;
}

%end

#pragma mark Handle when a webview is deciding to navigate to a new page

// The idea is that we force the WKWebView to become its own navigationDelegate.
// Therefore, we can then intercept any incoming delegate calls as required, then
// forward them to the actual navigationDelegate we hijacked.

%hook WKWebView

%property (nonatomic, assign) id hijackedNavigationDelegate;

- (instancetype)initWithFrame:(CGRect)arg1 configuration:(id)arg2 {
    WKWebView *orig = %orig;
    
    if (orig) {
        // Set the navigationDelegate initially.
        orig.navigationDelegate = (id<WKNavigationDelegate>)orig;
    }
    
    return orig;
}

// Override the navigationDelegate if updated
- (void)setNavigationDelegate:(id)delegate {
    if (![delegate isEqual:self])
        self.hijackedNavigationDelegate = delegate;
        
    %orig((id<WKNavigationDelegate>)self);
}

// Add appropriate delegate methods, forwarding back to the hijacked navigationDelegate as
// required.

%new
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURLRequest *request = navigationAction.request;
    NSString *url = [[request URL] absoluteString];
    
    if ([url hasPrefix:@"xeninfo:"]) {
        NSArray *components = [url componentsSeparatedByString:@":"];

        NSString *function = [components objectAtIndex:1];
        
        // Pass through the function and parameters through to the widget manager.
        NSString *parameter = components.count > 2 ? [components objectAtIndex:2] : @"";
        
        Xlog(@"Recieved a command: '%@' with parameter '%@'", function, parameter);
        
        // Send to widget manager.
        [[XIWidgetManager sharedInstance] widget:self didRequestAction:function withParameter:parameter];
        
        // Make sure to cancel this navigation!
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

%new
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (self.hijackedNavigationDelegate) {
        [(id<WKNavigationDelegate>)self.hijackedNavigationDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

%new
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (self.hijackedNavigationDelegate) {
        [(id<WKNavigationDelegate>)self.hijackedNavigationDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}

%new
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    if (self.hijackedNavigationDelegate) {
        [(id<WKNavigationDelegate>)self.hijackedNavigationDelegate webView:webView didCommitNavigation:navigation];
    }
}

%new
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (self.hijackedNavigationDelegate) {
        [(id<WKNavigationDelegate>)self.hijackedNavigationDelegate webView:webView didFinishNavigation:navigation];
    }
}

%new
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (self.hijackedNavigationDelegate) {
        [(id<WKNavigationDelegate>)self.hijackedNavigationDelegate webView:webView didFailNavigation:navigation withError:error];
    }
}

%new
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    if (self.hijackedNavigationDelegate) {
        [(id<WKNavigationDelegate>)self.hijackedNavigationDelegate webViewWebContentProcessDidTerminate:webView];
    }
}

%end

%hook UIWebView

%property (nonatomic, assign) id hijackedDelegate;

- (id)initWithFrame:(CGRect)arg1 {
    UIWebView *orig = %orig;
    
    if (orig) {
        // Set the delegate initially.
        orig.delegate = (id<UIWebViewDelegate>)orig;
    }
    
    return orig;
}

- (void)setDelegate:(id<UIWebViewDelegate>)delegate {
    // Update the hijacked delegate
    if (![delegate isEqual:self])
        self.hijackedDelegate = delegate;
        
    %orig((id<UIWebViewDelegate>)self);
}

%new
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    NSString *url = [[request URL] absoluteString];
    
    if ([url hasPrefix:@"xeninfo:"]) {
        NSArray *components = [url componentsSeparatedByString:@":"];
        
        NSString *function = [components objectAtIndex:1];
        
        // Pass through the function and parameters through to the widget manager.
        NSString *parameter = components.count > 2 ? [components objectAtIndex:2] : @"";
        
        Xlog(@"Recieved a command: '%@' with parameter '%@'", function, parameter);
        
        // Send to widget manager.
        [[XIWidgetManager sharedInstance] widget:self didRequestAction:function withParameter:parameter];
        
        // Make sure to cancel this navigation!
        return NO;
    } else {
        return YES;
    }
}

%new
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (self.hijackedDelegate)
        [self.hijackedDelegate webViewDidStartLoad:webView];
}

%new
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (self.hijackedDelegate)
        [self.hijackedDelegate webViewDidFinishLoad:webView];
}

%new
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (self.hijackedDelegate)
        [self.hijackedDelegate webView:webView didFailLoadWithError:error];
}

%end

///////////////////////////////////////////////////////////////
#pragma mark Battery Information Hooks
///////////////////////////////////////////////////////////////

#import "Battery/XIInfoStats.h"

%hook SBUIController

- (void)updateBatteryState:(id)arg1{
    %orig;
    
    // Forward message that new data is available
    [[XIWidgetManager sharedInstance] requestRefreshForDataProviderTopic:[XIInfoStats topic]];
}

%end

///////////////////////////////////////////////////////////////
#pragma mark Music Hooks
///////////////////////////////////////////////////////////////

#import "Music/XIMusicHeaders.h"
#import "Music/XIMusic.h"

static MPUNowPlayingController *globalMPUNowPlaying;

%hook SBMediaController

- (void)_nowPlayingInfoChanged{
    %orig;
    
    // Forward message that new data is available
    [[XIWidgetManager sharedInstance] requestRefreshForDataProviderTopic:[XIMusic topic]];
}

- (void)_mediaRemoteNowPlayingInfoDidChange:(id)arg1 {
    %orig;
    
    // Forward message that new data is available
    [[XIWidgetManager sharedInstance] requestRefreshForDataProviderTopic:[XIMusic topic]];
}

%end

%hook MPUNowPlayingController

- (id)init {
    id orig = %orig;
    
    if (orig) {
        globalMPUNowPlaying = orig;
    }
    
    return orig;
}

%new
+(id)_xeninfo_currentNowPlayingInfo {
    return [globalMPUNowPlaying currentNowPlayingInfo];
}

%new
+(id)_xeninfo_albumArt {
    if (!globalMPUNowPlaying){
        MPUNowPlayingController *nowPlayingController = [[objc_getClass("MPUNowPlayingController") alloc] init];
        [nowPlayingController startUpdating];
        return [nowPlayingController currentNowPlayingArtwork];
    }
    
    return [globalMPUNowPlaying currentNowPlayingArtwork];
}

%end

///////////////////////////////////////////////////////////////
#pragma mark Statusbar state
///////////////////////////////////////////////////////////////

#import "Statusbar/XIStatusBar.h"

%hook SBStatusBarStateAggregator

- (void)_notifyItemChanged:(int)arg1{
    %orig;
    
    [[XIWidgetManager sharedInstance] requestRefreshForDataProviderTopic:[XIStatusBar topic]];
}

-(void)_updateDataNetworkItem{
    %orig;
    
    [[XIWidgetManager sharedInstance] requestRefreshForDataProviderTopic:[XIStatusBar topic]];
}

%end

///////////////////////////////////////////////////////////////
#pragma mark Display state
///////////////////////////////////////////////////////////////

// iOS 9
%hook SBLockScreenViewController

-(void)_handleDisplayTurnedOff {
    %orig;
    
    [[XIWidgetManager sharedInstance] noteDeviceDidEnterSleep];
}

// When in a phone call, this code is not run.
- (void)_handleDisplayTurnedOnWhileUILocked:(id)locked {
    [[XIWidgetManager sharedInstance] noteDeviceDidExitSleep];
    
    %orig;
}

%end

// iOS 10
%hook SBLockScreenManager

- (void)_handleBacklightLevelChanged:(NSNotification*)arg1 {
    %orig;
    
    if ([UIDevice currentDevice].systemVersion.floatValue >= 10.0) {
        NSDictionary *userInfo = arg1.userInfo;
        
        CGFloat newBacklight = [[userInfo objectForKey:@"SBBacklightNewFactorKey"] floatValue];
        CGFloat oldBacklight = [[userInfo objectForKey:@"SBBacklightOldFactorKey"] floatValue];
        
        if (newBacklight == 0.0) {
            [[XIWidgetManager sharedInstance] noteDeviceDidEnterSleep];
        } else if (oldBacklight == 0.0 && newBacklight > 0.0) {
            [[XIWidgetManager sharedInstance] noteDeviceDidExitSleep];
        }
    }
}

%end

// iOS 11
%hook SBScreenWakeAnimationController

- (void)_handleAnimationCompletionIfNecessaryForWaking:(_Bool)wokeLS {
    if (!wokeLS) {
        [[XIWidgetManager sharedInstance] noteDeviceDidEnterSleep];
    }
    
    %orig;
}

- (void)_startWakeAnimationsForWaking:(_Bool)arg1 animationSettings:(id)arg2 {
    if (arg1) {
        [[XIWidgetManager sharedInstance] noteDeviceDidExitSleep];
    }
    
    %orig;
}

%end

///////////////////////////////////////////////////////////////
#pragma mark Constructor
///////////////////////////////////////////////////////////////

%ctor {
    Xlog(@"Injecting...");
    
    %init;
}
