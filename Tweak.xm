#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>
#import <EventKit/EventKit.h>
#include <mach/mach.h>
#import <mach/mach_host.h>
#include <sys/sysctl.h>
#import "headers.h"
#import "substrate.h"
#import "weather.h"
#import <WebKit/WebKit.h>

@interface XENHWebViewController : UIViewController <WKNavigationDelegate, UIWebViewDelegate> {

    NSString* _baseString;
    BOOL _usingFallback;
    NSDictionary* _metadata;
    BOOL _isFullscreen;
    int _variant;
    WKWebView* _webView;
    UIWebView* _fallbackWebView;

}
@property (nonatomic,retain) WKWebView * webView;
@end


static float deviceVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
static NSMutableArray* _webviews = nil;
static MPUNowPlayingController *globalMPUNowPlaying;
static bool loaded = NO;
static bool deviceON = YES;
static bool hasWebview = NO;
static bool firstLoad = false;
static int lastWeatherUpdate = 1;
//static NSMutableArray* signedInfo = [[NSMutableArray alloc] init];

static void update(NSString* values, NSString* type){
	for (WKWebView* webview in _webviews) {
		if([[NSString stringWithFormat:@"%@", webview.URL] isEqualToString:@"about:blank"]){
			//do nothing it's blank.
		}else{
			[webview evaluateJavaScript:values completionHandler:^(id object, NSError *error) {}];
	        NSString* function = [NSString stringWithFormat:@"mainUpdate('%@')", type];
	        [webview evaluateJavaScript:function completionHandler:^(id object, NSError *error) {}];
		}
	}
}

/*
	iOS10 changed temp type. What a mess. This will convert C or F
	depending on what the user has selected in the weather.app
*/

static int getIntFromWFTemp(WFTemperature* temp, City *city){
	if([[[UIDevice currentDevice] systemVersion] floatValue] >= 10.0f){
        return [[objc_getClass("WeatherPreferences") sharedPreferences] isCelsius] ? (int)temp.celsius : (int)temp.fahrenheit;
    }else{
        NSString *tempInt =  [NSString stringWithFormat:@"%@", temp];
        int temp = (int)[tempInt integerValue];
        if (![[objc_getClass("WeatherPreferences") sharedPreferences] isCelsius]){
            temp = ((temp * 9)/5) + 32;
        }
        return temp;
    }
}

/*
    credit Andrew Wiik & Matchstic
    https://github.com/Matchstic/InfoStats2/blob/cd31d7a9ec266afb10ea3576b06399f5900c2c1e/InfoStats2/IS2Weather.m

    oh boy iOS11 doesn't like this one. iP7 is the worst.

    4 - Location services on but weather set to While Using
    2 - Location services off or weather set to off
    3 - Location services on and weather set to always

*/

static NSString* nameForCondition(int condition){
    if([objc_getClass("CLLocationManager") authorizationStatusForBundleIdentifier:@"com.apple.weather"] == 2 || [objc_getClass("CLLocationManager") authorizationStatusForBundleIdentifier:@"com.apple.weather"] == 4){
        return @"Set weather location to Always";
    }else{
        MSImageRef weather = MSGetImageByName("/System/Library/PrivateFrameworks/Weather.framework/Weather");
        if(weather){
            CFStringRef *_weatherDescription = (CFStringRef*)MSFindSymbol(weather, "_WeatherDescription") + condition;
            NSString *cond = (__bridge id)*_weatherDescription;
            return [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Weather.framework"] localizedStringForKey:cond value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        }else{
            return @"Weather condition not found";
        }
    }
}

static void sendWeather(City* city){

    if(city){
        firstLoad = true;
        NSMutableDictionary *weatherInfo =[[NSMutableDictionary alloc] init];
        int temp = getIntFromWFTemp([city valueForKey:@"temperature"], city);
        int feelslike = getIntFromWFTemp([city valueForKey:@"feelsLike"], city);

        NSString *conditionString = nameForCondition(city.conditionCode);

        NSString *naturalCondition;

        NSString *celsius = [[objc_getClass("WeatherPreferences") sharedPreferences] isCelsius] ? @"C" : @"F";

        if ([city respondsToSelector:@selector(naturalLanguageDescription)]) {
            naturalCondition = [city naturalLanguageDescription];
            NSMutableString *s = [NSMutableString stringWithString:naturalCondition];
            [s replaceOccurrencesOfString:@"\'" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
            [s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
            [s replaceOccurrencesOfString:@"/" withString:@"\\/" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
            [s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
            [s replaceOccurrencesOfString:@"\b" withString:@"\\b" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
            [s replaceOccurrencesOfString:@"\f" withString:@"\\f" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
            [s replaceOccurrencesOfString:@"\r" withString:@"\\r" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
            [s replaceOccurrencesOfString:@"\t" withString:@"\\t" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
            naturalCondition = [NSString stringWithString:s];
        } else {
            naturalCondition = @"No condition";
        }

        NSMutableDictionary *dayForecasts;
        NSMutableArray *fcastArray = [[NSMutableArray alloc] init];

        for (DayForecast *day in city.dayForecasts) {
            int lowForcast = getIntFromWFTemp([day valueForKey:@"low"], city);
            int highForecast = getIntFromWFTemp([day valueForKey:@"high"], city);
            NSString *icon = [NSString stringWithFormat:@"%llu",day.icon];
            dayForecasts = [[NSMutableDictionary alloc] init];
            [dayForecasts setValue:[NSNumber numberWithInt:lowForcast] forKey:@"low"];
            [dayForecasts setValue:[NSNumber numberWithInt:highForecast] forKey:@"high"];
            [dayForecasts setValue:[NSString stringWithFormat:@"%llu",day.dayNumber] forKey:@"dayNumber"];
            [dayForecasts setValue:[NSString stringWithFormat:@"%llu",day.dayOfWeek] forKey:@"dayOfWeek"];
            [dayForecasts setValue:icon forKey:@"icon"];
            [fcastArray addObject:dayForecasts];
        }


        [weatherInfo setValue:city.name forKey:@"city"];
        [weatherInfo setValue:[NSNumber numberWithInt:temp] forKey:@"temperature"];
        [weatherInfo setValue:[NSNumber numberWithInt:feelslike] forKey:@"feelsLike"];
        [weatherInfo setValue:conditionString forKey:@"condition"];
        [weatherInfo setValue:naturalCondition forKey:@"naturalCondition"];

        [weatherInfo setValue:fcastArray forKey:@"dayForecasts"];

        [weatherInfo setValue:city.locationID forKey:@"latlong"];
        [weatherInfo setValue:celsius forKey:@"celsius"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%llu",city.conditionCode] forKey:@"conditionCode"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%@",city.updateTimeString] forKey:@"updateTimeString"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d",(int)roundf(city.humidity)] forKey:@"humidity"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d",(int)roundf(city.dewPoint)] forKey:@"dewPoint"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d",(int)roundf(city.windChill)] forKey:@"windChill"];
        [weatherInfo setValue:[NSNumber numberWithInt:feelslike] forKey:@"feelsLike"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d",(int)roundf(city.windDirection)] forKey:@"windDirection"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d",(int)roundf(city.windSpeed)] forKey:@"windSpeed"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d",(int)roundf(city.visibility)] forKey:@"visibility"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%llu",city.sunsetTime] forKey:@"sunsetTime"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%llu",city.sunriseTime] forKey:@"sunriseTime"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d", city.precipitationForecast] forKey:@"precipitationForecast"];

        if([[city hourlyForecasts] count] > 0){
            HourlyForecast* precip = [city hourlyForecasts][0];
            [weatherInfo setValue:[NSString stringWithFormat:@"%d", (int)roundf(precip.percentPrecipitation)] forKey:@"chanceofrain"];
        }

        NSData * dictData = [NSJSONSerialization dataWithJSONObject:weatherInfo options:0 error:nil];
        NSString * jsonObj = [[NSString alloc] initWithData:dictData encoding:NSUTF8StringEncoding];
        NSString* finalObj = [NSString stringWithFormat:@"var weather = JSON.parse('%@');", jsonObj];

        //too much extra code was needed to support low and high on multiple firmwares.
        //It was much easier to do it javascript side, reason for this.

        NSString* lowHiBS = [NSString stringWithFormat:@"weather.low = weather.dayForecasts[0].low; weather.high = weather.dayForecasts[0].high;"];

        update(finalObj, @"weather");

        update(lowHiBS, @"weather");
    }
}

/* 
    Get city object
*/

static City* getCity(){
    City *currentCity = nil;
    if([[objc_getClass("WeatherPreferences") sharedPreferences]localWeatherCity]){
        currentCity = [[objc_getClass("WeatherPreferences") sharedPreferences]localWeatherCity];
    }else{
        if([[[objc_getClass("WeatherPreferences") sharedPreferences]loadSavedCities] count] > 0){
            currentCity = [[objc_getClass("WeatherPreferences") sharedPreferences]loadSavedCities][0];
        }
    }
    return currentCity;
}

/* 
    load Weather from city with no update
*/

static void loadCurrentWeather(){
    sendWeather(getCity());
}


/* 
    Attempt to refresh weather without location services.
*/

static void loadWeatherNoLocationServices(){
    City* testCity = nil;
    if([[[objc_getClass("WeatherPreferences") sharedPreferences]loadSavedCities] count] > 0){

         testCity = [[objc_getClass("WeatherPreferences") sharedPreferences]loadSavedCities][0];

        if([testCity.name isEqualToString:@"Local Weather"]){
            if([[[objc_getClass("WeatherPreferences") sharedPreferences]loadSavedCities] count] > 1){
                testCity = [[objc_getClass("WeatherPreferences") sharedPreferences]loadSavedCities][1];
            }
        }

        if(deviceVersion < 10.0f){
            [[objc_getClass("TWCLocationUpdater") sharedLocationUpdater] updateWeatherForLocation:testCity.location city:testCity withCompletionHandler:^{
                sendWeather(testCity);
            }];
        }else{
            [[objc_getClass("TWCLocationUpdater") sharedLocationUpdater] _updateWeatherForLocation:testCity.location city:testCity completionHandler:^{
                sendWeather(testCity);
            }];
        }

    }
}


/* 
    Reload weather with location services.
*/

static void loadWeatherWithLocationServices(){
    City *currentCity = getCity();

    WeatherLocationManager* WLM = [objc_getClass("WeatherLocationManager")sharedWeatherLocationManager];
    TWCLocationUpdater *TWCLU = [objc_getClass("TWCLocationUpdater") sharedLocationUpdater];

    CLLocationManager *CLM = [[CLLocationManager alloc] init];
    [WLM setDelegate:CLM];

    if([[[UIDevice currentDevice] systemVersion] floatValue] > 8.3f){
        [WLM setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
    }

    [WLM setLocationTrackingActive:YES];
    [[objc_getClass("WeatherPreferences") sharedPreferences] setLocalWeatherEnabled:YES];

    if(deviceVersion < 10.0f){
        [TWCLU updateWeatherForLocation:[WLM location] city:currentCity];
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.2);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            sendWeather(currentCity);
        });
    }else{
        [TWCLU _updateWeatherForLocation:[WLM location] city:currentCity completionHandler:^{
            sendWeather(currentCity);
        }];
    }
    [WLM setLocationTrackingActive:NO];
    [WLM setLocationTrackingIsReady:NO];
    [CLM release];
    WLM = nil;
    TWCLU = nil;
}

/*
    Check to see what user has enabled. (recommended the user has location services on and weather set to always)
*/

static void refreshWeather(){
	if(![CLLocationManager locationServicesEnabled] || [objc_getClass("CLLocationManager") authorizationStatusForBundleIdentifier:@"com.apple.weather"] == 2 || [objc_getClass("CLLocationManager") authorizationStatusForBundleIdentifier:@"com.apple.weather"] == 4){
        loadWeatherNoLocationServices();
	}else{
		loadWeatherWithLocationServices();
	}
}

/*
	well. this is what I ended up with. I needed some way of stopping the update for a period of time.
	This was the most reliable throughout the things I tired.
*/

static void getWeather(){
	if(lastWeatherUpdate > 0){
		lastWeatherUpdate = 0;
		dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1200.0);
		dispatch_after(delay, dispatch_get_main_queue(), ^(void){
			lastWeatherUpdate = 1;
		});
		refreshWeather();
	}else{
        loadCurrentWeather();
    }
}


static void getEvents(){
    EKEventStore *store = nil;

    if(!store){
        store = [[EKEventStore alloc] init];
    }

     NSDate *start = [NSDate date];
     NSDate *end = [NSDate dateWithTimeInterval:25920000 sinceDate:start];


     NSPredicate* predicate = [store predicateForEventsWithStartDate:start endDate:end calendars:nil];
     NSArray *events = [store eventsMatchingPredicate:predicate];

     NSMutableDictionary *dateDict;
     NSMutableArray *dateDictArray = [[NSMutableArray alloc] init];
     NSString *dupeCatch = @"";

    for (EKEvent *object in events) {
        NSString* info = [NSString stringWithFormat:@"%@", object.title];
        NSCharacterSet *cs = [NSCharacterSet characterSetWithCharactersInString:@"!~`@#$%^&*-+();:=_{}[],.<>?\\/|\"\'"];

        NSString *filtered = [[info componentsSeparatedByCharactersInSet:cs] componentsJoinedByString:@""];
        NSMutableString *finalString = [NSMutableString stringWithString:filtered];
        [finalString replaceOccurrencesOfString:@"gmail" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [finalString length])];
        [finalString replaceOccurrencesOfString:@"coms" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [finalString length])];
        [finalString replaceOccurrencesOfString:@"yahoo" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [finalString length])];
        [finalString replaceOccurrencesOfString:@"couk" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [finalString length])];
        filtered = [NSString stringWithString:finalString];

        if (!([dupeCatch rangeOfString:filtered].location == NSNotFound)) {
            dateDict = [[NSMutableDictionary alloc]init];
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            [dateFormat setDateFormat:@"MM-dd-YYYY"];
            NSString* date = [dateFormat stringFromDate:object.startDate];

            date = [date stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
            date = [date stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            date = [date stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
            date = [date stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
            date = [date stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
            date = [date stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];

            [dateDict setValue:date forKey:@"date"];

            [dateDict setValue:filtered forKey:@"title"];
            [dateDictArray addObject:dateDict];
        }
        dupeCatch = [NSString stringWithFormat:@"%@", filtered];
    }
    NSData * dictData = [NSJSONSerialization dataWithJSONObject:dateDictArray options:0 error:nil];
    NSString * jsonObj = [[NSString alloc] initWithData:dictData encoding:NSUTF8StringEncoding];
    NSString* eventStr = [NSString stringWithFormat:@"var events = %@;", jsonObj];
    update(eventStr, @"events");

    dateDict = nil;
    dateDictArray = nil;
    dictData = nil;
    jsonObj = nil;
    eventStr = nil;


    //Reminders
    // [store requestAccessToEntityType:EKEntityTypeReminder completion:^(BOOL granted, NSError *error) {
    //     NSLog(@"CalTest acces to §Reminder granded %i ",granted);
    // }];

    NSPredicate *predicate2 = [store predicateForRemindersInCalendars:nil];
    [store fetchRemindersMatchingPredicate:predicate2 completion:^(NSArray *reminders) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *eventsDictArray = [[NSMutableArray alloc] init];
            NSMutableDictionary *eventsDict;
            for (EKReminder *object in reminders) {
                //NSLog(@"CalTest eventes %@", object);
                //NSLog(@"CalTest evernt %@", object.dueDate);
                if(!object.completionDate){
                    eventsDict = [[NSMutableDictionary alloc]init];
                    [eventsDict setValue:object.title forKey:@"title"];
                    //[eventsDict setValue:object.dueDate forKey:@"date"];
                    [eventsDictArray addObject:eventsDict];
                }
            }

            NSData * eventData = [NSJSONSerialization dataWithJSONObject:eventsDictArray options:0 error:nil];
            NSString * eventObj = [[NSString alloc] initWithData:eventData encoding:NSUTF8StringEncoding];
            NSString* remindersStr = [NSString stringWithFormat:@"var reminders = %@;", eventObj];
            update(remindersStr, @"reminders");
            eventsDict = nil;
            eventsDictArray = nil;
            eventData = nil;
            eventObj = nil;
            remindersStr = nil;

            });
    }];

    store = nil;
}

/*
    credit Matchstic
    https://github.com/Matchstic/InfoStats2/blob/cd31d7a9ec266afb10ea3576b06399f5900c2c1e/InfoStats2/IS2System.m
*/

static int getSysInfo(uint typeSpecifier){
	size_t size = sizeof(int);
    int results;
    int mib[2] = {CTL_HW, typeSpecifier};
    sysctl(mib, 2, &results, &size, NULL, 0);
    return (int) results;
}
static int ramDataForType(int type){
	mach_port_t host_port;
    mach_msg_type_number_t host_size;
    vm_size_t pagesize;

    host_port = mach_host_self();
    host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);

    vm_statistics_data_t vm_stat;

    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS)
        NSLog(@"Failed to fetch vm statistics");

    /* Stats in bytes */
    NSUInteger giga = 1024*1024;

    if (type == 0) {
        return (int)getSysInfo(HW_USERMEM) / giga;
    } else if (type == -1) {
        return (int)getSysInfo(HW_PHYSMEM) / giga;
    }

    natural_t wired = vm_stat.wire_count * (natural_t)pagesize / (1024 * 1024);
    natural_t active = vm_stat.active_count * (natural_t)pagesize / (1024 * 1024);
    natural_t inactive = vm_stat.inactive_count * (natural_t)pagesize / (1024 * 1024);
    if (type == 1) {
        return vm_stat.free_count * (natural_t)pagesize / (1024 * 1024) + inactive; // Inactive is treated as free by iOS
    } else {
        return active + wired;
    }
}
//end

static void getStatusbar(){
    SBWiFiManager *WM = [objc_getClass("SBWiFiManager") sharedInstance];
    SBTelephonyManager *TM = [objc_getClass("SBTelephonyManager") sharedTelephonyManager];
    BluetoothManager *BM = [objc_getClass("BluetoothManager") sharedInstance];

    //NSNumber *signalStrength = [NSNumber numberWithInt:[TM signalStrength]]; NA
    NSNumber *signalStrength = 0;
    NSNumber *signalBars = [NSNumber numberWithInt:[TM signalStrengthBars]];
    NSString *signalName = [TM operatorName];

    NSNumber *wifiStrength = [NSNumber numberWithInt:[WM signalStrengthRSSI]];
    NSNumber *wifiBars = [NSNumber numberWithInt:[WM signalStrengthBars]];
    NSString *wifiName = [WM currentNetworkName];

    NSNumber *blueTooth = [NSNumber numberWithBool: [BM enabled]];

    NSString *freakinWifi = [NSString stringWithFormat:@"%@",wifiName];
    freakinWifi = [[NSString stringWithFormat:@"%@",wifiName] stringByReplacingOccurrencesOfString:@"'" withString:@""];

    if([freakinWifi isEqualToString:@"(null)"]){
        freakinWifi = @"NA";
    }
    if([signalName isEqualToString:@""]){
        signalName = @"NA";
    }

    NSString* statusbar = [NSString stringWithFormat:@"var signalStrength = '%@', signalBars = '%@', signalName = '%@', wifiStrength = '%@', wifiBars = '%@', wifiName = '%@', bluetoothOn = '%@';", signalStrength, signalBars, signalName, wifiStrength, wifiBars, freakinWifi, blueTooth];
    update(statusbar, @"statusbar");
}

static void getBattery(){
	SBUIController *SB = [objc_getClass("SBUIController") sharedInstanceIfExists];
    int batteryCharging = [SB isOnAC];
    int batteryPercent = [SB batteryCapacityAsPercentage];
    int ramFree = ramDataForType(1);
    int ramUsed = ramDataForType(2);
    int ramAvailable = ramDataForType(0);
    int ramPhysical = ramDataForType(-1);
    NSString* battery = [NSString stringWithFormat:@"var batteryPercent = %d, batteryCharging = %d, ramFree = %d, ramUsed = %d, ramAvailable = %d, ramPhysical = %d;", batteryPercent, batteryCharging, ramFree, ramUsed, ramAvailable, ramPhysical];
    update(battery, @"battery");
    //getWeather();
    battery = nil;
}

// static void getSigningInfo(){
//      NSString* infoForSignedApps = @"NA";
//     if(signedInfo){
//         NSData * dictData = [NSJSONSerialization dataWithJSONObject:signedInfo options:0 error:nil];
//         infoForSignedApps = [[NSString alloc] initWithData:dictData encoding:NSUTF8StringEncoding];
//     }
//     NSString* info = [NSString stringWithFormat:@"var signedInfo = '%@';", infoForSignedApps];
//     update(info, @"signinginfo");
// }

/*
	 delay again. Seems to be my new best friend
	 I use the delay as sometime the artwork takes a second to load
	 from 3rd party music players.
*/

// static NSString* removeQuote(NSString* strings){
//     NSString* stripped = [strings stringByReplacingOccurrencesOfString:@"'" withString:@""];
//     return stripped;
// }

static void getMusic(){
	dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1.0);
	dispatch_after(delay, dispatch_get_main_queue(), ^(void){
		NSDictionary *info = [objc_getClass("MPUNowPlayingController") _xeninfo_currentNowPlayingInfo];
        NSString *artist = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoArtist"]];
        NSString *album = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoAlbum"]];
        NSString *title = [NSString stringWithFormat:@"%@",[info objectForKey:@"kMRMediaRemoteNowPlayingInfoTitle"]];

        if ([album containsString:@"Listening on"]) {
            NSArray* arArray = [title componentsSeparatedByString:@"•"];
            if([arArray count] > 1){
                 artist = arArray[1];
                 title = arArray[0];
            }
        }

        //title = removeQuote(title);
        //album = removeQuote(album);
        //artist = removeQuote(artist);

        int isplaying = [[objc_getClass("SBMediaController") sharedInstance] isPlaying];
	    UIImage *uiimage = nil;

	    if([objc_getClass("MPUNowPlayingController") _xeninfo_albumArt]){
	        uiimage = [objc_getClass("MPUNowPlayingController") _xeninfo_albumArt];
	        [UIImagePNGRepresentation(uiimage) writeToFile:@"var/mobile/Documents/Artwork.jpg" atomically:YES];
	    }

    	NSString* music = [NSString stringWithFormat:@"var artist = '%@', album = '%@', title = '%@', isplaying = %d;", artist, album, title, isplaying];
    	update(music, @"music");

    	info = nil;
    	artist = nil;
    	album = nil;
    	title = nil;
    	isplaying = nil;
    	uiimage = nil;
    	music = nil;
	});
}

%hook MPUNowPlayingController
- (id)init {
    id orig = %orig;
    globalMPUNowPlaying = orig;
    return orig;
}

%new
+(id)_xeninfo_currentNowPlayingInfo {
    return [globalMPUNowPlaying currentNowPlayingInfo];
}

%new
+(id)_xeninfo_albumArt{
	if([globalMPUNowPlaying currentNowPlayingArtwork] == NULL){
		MPUNowPlayingController *nowPlayingController=[[objc_getClass("MPUNowPlayingController") alloc] init];
		[nowPlayingController startUpdating];
		return [nowPlayingController currentNowPlayingArtwork];
	}
	return [globalMPUNowPlaying currentNowPlayingArtwork];
}
%end

%hook SBStatusBarStateAggregator
- (void)_notifyItemChanged:(int)arg1{
    if(loaded && deviceON && hasWebview){
        getStatusbar();
    }
    %orig;
}

-(void)_updateDataNetworkItem{
    if(loaded && deviceON && hasWebview){
        getStatusbar();
    }
    %orig;
}
 %end

%hook SBUIController
- (void)updateBatteryState:(id)arg1{
    if(loaded && deviceON && hasWebview){
        getBattery();
    }
	%orig;
}
%end

%hook SBMediaController
- (void)_nowPlayingInfoChanged{
	if(loaded && deviceON && hasWebview){
        getMusic();
    }
	return %orig;
}
- (void)_mediaRemoteNowPlayingInfoDidChange:(id)arg1{
    if(loaded && deviceON && hasWebview){
        getMusic();
    }
	%orig;
}
%end

// %hook FBApplicationProvisioningProfile
// - (id)initWithSignerIdentity:(id)arg1 profile:(id)arg2{
//     if(arg2){
//         @try{
//             NSArray *signedApps = [[NSString stringWithFormat:@"%@", arg2]componentsSeparatedByString:@":"];
//             NSArray* splitStr = [signedApps[5] componentsSeparatedByString:@"-"];
//             if((int)[splitStr count] > 1){
//                 NSString * appName = [splitStr[1] componentsSeparatedByString:@"\""][0];
//                 NSArray* words = [appName componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//                 appName = [words componentsJoinedByString:@""];
//                 NSString* appDate = [NSString stringWithFormat:@"%.0f", floor([[%orig expirationDate]timeIntervalSince1970]*1000)];
//                 NSString* appInfo = [NSString stringWithFormat:@"%@ - %@", appName, appDate];
//                 [signedInfo addObject:appInfo];
//             }
//         }@catch(NSException *error){
//             NSLog(@"AneInfo error getting signedInfo %@", error);
//         }
//     }
//     return %orig;
// }
// %end

static void showAlert(){
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"XenInfo" message:@"Hey! XenInfo provides weather from the weather.app which you have deleted. \n\n We will not be giving you any weather information sorry." preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Dangit" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[objc_getClass("SBIconController") sharedInstance] dismissViewControllerAnimated:YES completion:NULL];
    }]];
    [[objc_getClass("SBIconController") sharedInstance] presentViewController:alertController animated:YES completion:NULL];
}

static bool isWeatherInstalled(){
    if([[objc_getClass("SBApplicationController") sharedInstance] applicationWithBundleIdentifier:@"com.apple.weather"]){
        return YES;
    }else{
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ){
            //research this
        }else{
            showAlert();
        }
        return NO;
    }
}

static void loadAllInfo(){
    loaded = YES;
    if(hasWebview){
        dispatch_async(dispatch_get_main_queue(), ^(void){
            getBattery();
            getStatusbar();
            if(isWeatherInstalled()){
                getWeather();
            }
            getEvents();
            getMusic();
        });
    }
}


/* Load after respring */


%hook SBLockScreenManager

/* 
	There is no need to update info when the device is off.
	We should however load new info when it wakes as nothing else is triggered.
*/

- (void)_handleBacklightLevelWillChange:(id)arg1{
		%orig;
		NSConcreteNotification* note = arg1;
		NSString* val = [NSString stringWithFormat:@"%@", [note.userInfo objectForKey:@"SBBacklightNewFactorKey"]];
		if([val isEqualToString:@"1"]){
			deviceON = YES;
            loadAllInfo();			
		}else if([val isEqualToString:@"0"]){
			deviceON = NO;
		}
	}
%end


// /* After respring load info with delay to give time for XenHTML to load it's webviews */
// static id sbObserver;

// %ctor {
// 	sbObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
// 		object:nil queue:[NSOperationQueue mainQueue]
// 		usingBlock:^(NSNotification *notification) {
// 			dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 3.0);
// 			dispatch_after(delay, dispatch_get_main_queue(), ^(void){
// 			    //loadAllInfo();
// 			    //NSLog(@"JINFO test2");
// 			});
// 		}
// 	];
// }

// %dtor {
// 	[[NSNotificationCenter defaultCenter] removeObserver:sbObserver];
// }

%hook XENHWebViewController

	/*
		Detects when a webview did finish loading completely.
		This will inject info multiple times. Not very efficient
		Delay 0.5s to load info immediately after respring.
	*/
	-(void)webView:(id)arg1 didFinishNavigation:(id)arg2{
		%orig;
		WKWebView* wb = arg1;
		if(!wb.isLoading){
			dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.5);
			dispatch_after(delay, dispatch_get_main_queue(), ^(void){
			    loadAllInfo();
			});
		}
	}

	/*
		Called when widget is deselected in XenHTML settings also called when screen is unlocked.
		We need to update our array so it doesn't pass info to it.
	*/
	-(void)unloadWKWebView{
		%orig;
		if(_webviews && self.webView){
			if([_webviews containsObject:self.webView]){
				NSUInteger index = [_webviews indexOfObject:self.webView];
				[_webviews removeObjectAtIndex:index];
			}
		}
        if([_webviews count] == 0){
            hasWebview = NO;
        }
	}

	/*
		Store the webviews Xen has placed.
	*/
	-(void)setWebView:(WKWebView *)arg1{
		%orig;
        hasWebview = YES;
		if(!_webviews){
			_webviews=[[NSMutableArray array] retain];
		}
		if(![_webviews containsObject:arg1]){
		     [_webviews addObject:arg1];
		}
	}
%end