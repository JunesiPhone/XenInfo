///////////////////////////////////////////////////////////////
#pragma mark Headers
///////////////////////////////////////////////////////////////

#import "Internal/XIWidgetManager.h"

#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface WKWebView (Additions)
@property (nonatomic, assign) id<WKNavigationDelegate> hijackedNavigationDelegate;
@end

///////////////////////////////////////////////////////////////
#pragma mark Internal Hooks
///////////////////////////////////////////////////////////////

#pragma mark Add any webviews to our widget manager as required.

%hook WKWebView

- (void)_didFinishLoadForMainFrame {
    %orig;

    // Loading has ended; add to manager if required.

    NSString *url = [self.URL absoluteString];
    
    if (![url isEqualToString:@""] && ![url isEqualToString:@"about:blank"]) {
        Xlog(@"Registering widget for URL: %@", url);
        [[XIWidgetManager sharedInstance] registerWidget:self];
    }
}

-(id)loadHTMLString:(NSString*)arg1 baseURL:(id)arg2 {
    NSString *url = [self.URL absoluteString];
    
    if ([arg1 isEqualToString:@""] && ![url isEqualToString:@"about:blank"]) {
        Xlog(@"Unregistering widget for URL: %@", url);
        [[XIWidgetManager sharedInstance] unregisterWidget:self];
    }
    
    return %orig;
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
#pragma mark Constructor
///////////////////////////////////////////////////////////////

%ctor {
    Xlog(@"Injecting...");
    
    %init;
}
