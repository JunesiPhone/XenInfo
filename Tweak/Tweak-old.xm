#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>
#import <EventKit/EventKit.h>
#include <mach/mach.h>
#import <mach/mach_host.h>
#include <sys/sysctl.h>
#import "../include/headers.h"
#import "../include/substrate.h"
#import "../include/weather.h"
#import <WebKit/WebKit.h>
#import <UIKit/UIKit.h>
#import <sys/utsname.h> //device models

//old XenHTML
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

//new XenHTML
@interface XENHWidgetController : UIViewController <WKNavigationDelegate, UIWebViewDelegate> {

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
    return @"Use weather.conditionCode";
    // if([objc_getClass("CLLocationManager") authorizationStatusForBundleIdentifier:@"com.apple.weather"] == 2 || [objc_getClass("CLLocationManager") authorizationStatusForBundleIdentifier:@"com.apple.weather"] == 4){
    //     return @"Set weather location to Always";
    // }else{
    //     return @"Use weather.conditionCode";
    //     MSImageRef weather = MSGetImageByName("/System/Library/PrivateFrameworks/Weather.framework/Weather");
    //     if(weather){
    //         CFStringRef *_weatherDescription = (CFStringRef*)MSFindSymbol(weather, "_WeatherDescription") + condition;
    //         NSString *cond = (__bridge id)*_weatherDescription;
    //         return [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Weather.framework"] localizedStringForKey:cond value:@"" table:@"WeatherFrameworkLocalizableStrings"];
    //     }else{
    //         return @"Weather condition not found";
    //     }
    // }
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
        NSString *isDay = city.isDay ? @"true" : @"false";

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

        NSMutableDictionary *hourForecasts;
        NSMutableArray *hfcastArray = [[NSMutableArray alloc] init];

        for (HourlyForecast *hour in city.hourlyForecasts) {
            int temp = 0;

            if(deviceVersion >= 10){ //doesn't exist < iOS 10
                temp = getIntFromWFTemp([hour valueForKey:@"temperature"], city);
            }
            
            hourForecasts = [[NSMutableDictionary alloc] init];
            [hourForecasts setValue:hour.time forKey:@"time"]; //7.0 - 11.1.2
            [hourForecasts setValue:[NSString stringWithFormat:@"%llu",hour.conditionCode] forKey:@"conditionCode"]; //7.0 - 11.1.2
            [hourForecasts setValue:[NSNumber numberWithInt:temp] forKey:@"temperature"]; //10.1.1 - 11.1.2
            [hourForecasts setValue:[NSNumber numberWithInt:hour.percentPrecipitation] forKey:@"percentPrecipitation"]; //6.0 - 11.1.2
            [hourForecasts setValue:[NSNumber numberWithInt:hour.hourIndex] forKey:@"hourIndex"]; //7.0 - 11.1.2
            [hfcastArray addObject:hourForecasts];
        }

        [weatherInfo setValue:city.name forKey:@"city"];
        [weatherInfo setValue:[NSNumber numberWithInt:temp] forKey:@"temperature"];
        [weatherInfo setValue:[NSNumber numberWithInt:feelslike] forKey:@"feelsLike"];
        [weatherInfo setValue:conditionString forKey:@"condition"];
        [weatherInfo setValue:naturalCondition forKey:@"naturalCondition"];

        [weatherInfo setValue:fcastArray forKey:@"dayForecasts"];
        [weatherInfo setValue:hfcastArray forKey:@"hourlyForecasts"];

        [weatherInfo setValue:city.locationID forKey:@"latlong"];
        [weatherInfo setValue:celsius forKey:@"celsius"];
        [weatherInfo setValue:isDay forKey:@"isDay"];
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
        [weatherInfo setValue:[NSString stringWithFormat:@"%d", (int)roundf(city.pressure)] forKey:@"pressure"];
        [weatherInfo setValue:[NSNumber numberWithFloat:city.precipitationPast24Hours] forKey:@"precipitation24hr"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d", (int)roundf(city.heatIndex)] forKey:@"heatIndex"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%d", (int)roundf(city.moonPhase)] forKey:@"moonPhase"];
        [weatherInfo setValue:[NSString stringWithFormat:@"%@",city.cityAndState] forKey:@"cityState"];

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

        dayForecasts = nil;
        hourForecasts = nil;
        fcastArray = nil;
        hfcastArray = nil;
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

    if(deviceVersion >= 8.3f){
        if([[objc_getClass("WeatherLocationManager")sharedWeatherLocationManager] respondsToSelector:@selector(setLocationTrackingReady:activelyTracking:watchKitExtension:)]){
            [WLM setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
        }
    }

    if(deviceVersion >= 8.3f){
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
		dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 600.0);
		dispatch_after(delay, dispatch_get_main_queue(), ^(void){
			lastWeatherUpdate = 1;
		});
        NSLog(@"XenInfo: Weather updating..");
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

     NSMutableArray *searchableCalendars = [[store calendarsForEntityType:EKEntityTypeEvent] mutableCopy];
     NSPredicate* predicate = [store predicateForEventsWithStartDate:start endDate:end calendars:searchableCalendars];
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

//http://theiphonewiki.com/wiki/Models
static id deviceName(){
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machineName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSDictionary *commonNamesDictionary =
    @{
      @"i386":     @"i386 Simulator",
      @"x86_64":   @"x86_64 Simulator",

      @"iPhone1,1":    @"iPhone",
      @"iPhone1,2":    @"iPhone 3G",
      @"iPhone2,1":    @"iPhone 3GS",
      @"iPhone3,1":    @"iPhone 4",
      @"iPhone3,2":    @"iPhone 4",
      @"iPhone3,3":    @"iPhone 4",
      @"iPhone4,1":    @"iPhone 4S",
      @"iPhone5,1":    @"iPhone 5",
      @"iPhone5,2":    @"iPhone 5",
      @"iPhone5,3":    @"iPhone 5c",
      @"iPhone5,4":    @"iPhone 5c",
      @"iPhone6,1":    @"iPhone 5s",
      @"iPhone6,2":    @"iPhone 5s",

      @"iPhone7,1":    @"iPhone 6+",
      @"iPhone7,2":    @"iPhone 6",

      @"iPhone8,1":    @"iPhone 6S",
      @"iPhone8,2":    @"iPhone 6S+",
      @"iPhone8,4":    @"iPhone SE",
      @"iPhone9,1":    @"iPhone 7",
      @"iPhone9,2":    @"iPhone 7+",
      @"iPhone9,3":    @"iPhone 7",
      @"iPhone9,4":    @"iPhone 7+",

      @"iPhone10,1": @"iPhone 8",
      @"iPhone10,4": @"iPhone 8",

      @"iPhone10,2": @"iPhone 8+",
      @"iPhone10,5": @"iPhone 8+",

      @"iPhone10,3": @"iPhone X",
      @"iPhone10,6": @"iPhone X",

      @"iPad1,1":  @"iPad",
      @"iPad2,1":  @"iPad 2",
      @"iPad2,2":  @"iPad 2",
      @"iPad2,3":  @"iPad 2",
      @"iPad2,4":  @"iPad 2",
      @"iPad2,5":  @"iPad Mini 1G ",
      @"iPad2,6":  @"iPad Mini 1G ",
      @"iPad2,7":  @"iPad Mini 1G ",
      @"iPad3,1":  @"iPad 3",
      @"iPad3,2":  @"iPad 3",
      @"iPad3,3":  @"iPad 3",
      @"iPad3,4":  @"iPad 4",
      @"iPad3,5":  @"iPad 4",
      @"iPad3,6":  @"iPad 4",

      @"iPad4,1":  @"iPad Air",
      @"iPad4,2":  @"iPad Air",
      @"iPad4,3":  @"iPad Air",

      @"iPad5,3":  @"iPad Air 2 ",
      @"iPad5,4":  @"iPad Air 2 ",

      @"iPad4,4":  @"iPad Mini 2G ",
      @"iPad4,5":  @"iPad Mini 2G ",
      @"iPad4,6":  @"iPad Mini 2G ",

      @"iPad4,7":  @"iPad Mini 3G ",
      @"iPad4,8":  @"iPad Mini 3G ",
      @"iPad4,9":  @"iPad Mini 3G ",

      @"iPod1,1":  @"iPod 1st Gen",
      @"iPod2,1":  @"iPod 2nd Gen",
      @"iPod3,1":  @"iPod 3rd Gen",
      @"iPod4,1":  @"iPod 4th Gen",
      @"iPod5,1":  @"iPod 5th Gen",
      @"iPod7,1":  @"iPod 6th Gen",
      };

    NSString *deviceName = commonNamesDictionary[machineName];
    if (deviceName == nil) {
        deviceName = machineName;
    }
    commonNamesDictionary = nil;
    return deviceName;
}

static id getAlarm(int info){
    NSString* alarmInfo = @"";
    NSArray *alarms;
    NSString *formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containsA = [formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM = containsA.location != NSNotFound;
    ClockManager *manager = [objc_getClass("ClockManager") sharedManager];
    if(deviceVersion >= 9.0f){
        [manager refreshScheduledLocalNotificationsCache];
    }
    alarms = [manager scheduledLocalNotificationsCache];
    if(alarms){
        for(UIConcreteLocalNotification *alarm in alarms){
            id nextFireDate = [alarm nextFireDateAfterDate:[NSDate date] localTimeZone:alarm.timeZone];
            //NSLog(@"XenInfoS %@", nextFireDate);
            int day = (int)[[NSCalendar currentCalendar] components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitWeekday|NSCalendarUnitMinute fromDate:nextFireDate].weekday;
            //NSLog(@"XenInfoS %d", day);
            int hr = [[alarm.userInfo valueForKey:@"hour"] intValue];
            NSString *mn = [NSString stringWithFormat:@"%@", [alarm.userInfo valueForKey:@"minute"]];
            NSString *pm;
            if([mn isEqualToString:@"0"]){
                mn = @"00";
            }
            if(hasAMPM){
                if(hr > 12){
                    pm = @"PM";
                    hr = hr - 12;
                }else{
                    pm = @"AM";
                }
                if(hr == 0){
                    hr = 12;
                }
            }else{
                pm = @"";
            }
            if(alarm.userInfo){
                switch (info) {
                    case 0:
                        alarmInfo = [NSString stringWithFormat:@"%d:%@ %@", hr, mn, pm];
                        break;
                    case 1:
                        alarmInfo = [NSString stringWithFormat:@"%d:%@", hr, mn];
                        break;
                    case 2:
                        alarmInfo = [NSString stringWithFormat:@"%d", hr];
                        break;
                    case 3:
                        alarmInfo = [NSString stringWithFormat:@"%@", mn];
                        break;
                    case 4:
                        alarmInfo = [NSString stringWithFormat:@"%d", day - 1];
                        break;
                    default:
                        break;
                }
            }
        }
    }
    return alarmInfo;
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

    //system
    NSString *systemVersion = [UIDevice currentDevice].systemVersion;

    NSString *freakinName = [[NSString stringWithFormat:@"%@",[[UIDevice currentDevice] name]] stringByReplacingOccurrencesOfString:@"'" withString:@""];

    NSString *formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containsA = [formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM = containsA.location != NSNotFound;
    NSString *twentyFour;
    
    if(hasAMPM){
        twentyFour = @"no";
    }else{
        twentyFour = @"yes";
    }

    NSString* system = [NSString stringWithFormat:@"var systemVersion = '%@', deviceName = '%@', twentyfourhour = '%@', deviceType = '%@';", systemVersion, freakinName, twentyFour, deviceName()];
    update(system, @"system");

    //alarm
    NSString* alarm = [NSString stringWithFormat:@"var alarmString = '%@', alarmTime = '%@', alarmHour = '%@', alarmMinute = '%@', alarmDay = '%@';", getAlarm(0), getAlarm(1), getAlarm(2), getAlarm(3), getAlarm(4)];
    update(alarm, @"alarm");

    getWeather();
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
            return YES;
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

//new Old XENHTML
%hook XENHWebViewController
    //play and pause window.location = 'xeninfo:playpause';
    %new
    -(void)playpause{
        [[objc_getClass("SBMediaController") sharedInstance] togglePlayPause];
    }
    //next track window.location = 'xeninfo:nextrack';
    %new
    -(void)nexttrack{
         [[objc_getClass("SBMediaController") sharedInstance] changeTrack:1];
    }
    //previous track window.location = 'xeninfo:prevtrack';
    %new
    -(void)prevtrack{
        [[objc_getClass("SBMediaController") sharedInstance] changeTrack:-1];
    }

    //open app from XenHTML widget window.location = 'xeninfo:openapp:com.spotify.client';
    %new
    -(void)openapp:(NSString *)bundle{
        @try{
            [[objc_getClass("UIApplication") sharedApplication] launchApplicationWithIdentifier:bundle suspended:NO];
        }@catch(NSException* err){
            NSLog(@"XenInfo Launch Error %@", err);
        }
    }

    %new
    -(void)openurl:(NSString *)path{
        NSString* address = [NSString stringWithFormat:@"http://%@", path];
        NSURL *urlPath = [NSURL URLWithString:address];
        if ([[UIApplication sharedApplication] canOpenURL:urlPath]){
            [[UIApplication sharedApplication] openURL:urlPath options:@{} completionHandler:nil];
        }
    }

    //pretty strange I must add this, but I did.
    %new
    - (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
        NSURLRequest *request = navigationAction.request;
        NSString *url = [[request URL]absoluteString];
        
        if ([url hasPrefix:@"xeninfo:"]) { //devs will call window.location = 'xeninfo:playpause'; or window.location = 'xeninfo:openapp:com.spotify.client';
            NSArray *components = [url componentsSeparatedByString:@":"];
            NSString *function = [components objectAtIndex:1];
            @try {
                if([components count] > 2){ //check it has more than one component if so pass the parameter, if not just call the method
                    NSString *func = [NSString stringWithFormat:@"%@:",[components objectAtIndex:1]];
                    NSString *param = [NSString stringWithFormat:@"%@",[components objectAtIndex:2]];
                    if([self respondsToSelector:NSSelectorFromString(func)]){
                        [self performSelector:NSSelectorFromString(func)
                                   withObject:param
                                   afterDelay:0];
                    }
                }else{
                    if([self respondsToSelector:NSSelectorFromString(function)]){
                        [self performSelector:NSSelectorFromString(function)
                                   withObject:nil
                                   afterDelay:0];
                    }
                }
            } @catch (NSException *exception) {
                NSLog(@"XenInfo - Error in WKWebView Decide Policy %@",exception);
            }
            //decisionHandler(WKNavigationActionPolicyCancel);
        }
        decisionHandler(WKNavigationActionPolicyAllow);
    }

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
        if(arg1){
            hasWebview = YES;
            if(!_webviews){
                _webviews=[[NSMutableArray array] retain];
            }
            if(![_webviews containsObject:arg1]){
                 [_webviews addObject:arg1];
            }
        }
    }
%end


//new XENHTML
%hook XENHWidgetController

    //play and pause window.location = 'xeninfo:playpause';
    %new
    -(void)playpause{
        [[objc_getClass("SBMediaController") sharedInstance] togglePlayPause];
    }
    //next track window.location = 'xeninfo:nextrack';
    %new
    -(void)nexttrack{
         [[objc_getClass("SBMediaController") sharedInstance] changeTrack:1];
    }
    //previous track window.location = 'xeninfo:prevtrack';
    %new
    -(void)prevtrack{
        [[objc_getClass("SBMediaController") sharedInstance] changeTrack:-1];
    }

    //open app from XenHTML widget window.location = 'xeninfo:openapp:com.spotify.client';
    %new
    -(void)openapp:(NSString *)bundle{
        @try{
            [[objc_getClass("UIApplication") sharedApplication] launchApplicationWithIdentifier:bundle suspended:NO];
        }@catch(NSException* err){
            NSLog(@"XenInfo Launch Error %@", err);
        }
    }

    %new
    -(void)openurl:(NSString *)path{
        NSString* address = [NSString stringWithFormat:@"http://%@", path];
        NSURL *urlPath = [NSURL URLWithString:address];
        if ([[UIApplication sharedApplication] canOpenURL:urlPath]){
            [[UIApplication sharedApplication] openURL:urlPath options:@{} completionHandler:nil];
        }
    }

    //pretty strange I must add this, but I did.
    %new
    - (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
        NSURLRequest *request = navigationAction.request;
        NSString *url = [[request URL]absoluteString];
        
        if ([url hasPrefix:@"xeninfo:"]) { //devs will call window.location = 'xeninfo:playpause'; or window.location = 'xeninfo:openapp:com.spotify.client';
            NSArray *components = [url componentsSeparatedByString:@":"];
            NSString *function = [components objectAtIndex:1];
            @try {
                if([components count] > 2){ //check it has more than one component if so pass the parameter, if not just call the method
                    NSString *func = [NSString stringWithFormat:@"%@:",[components objectAtIndex:1]];
                    NSString *param = [NSString stringWithFormat:@"%@",[components objectAtIndex:2]];
                    if([self respondsToSelector:NSSelectorFromString(func)]){
                        [self performSelector:NSSelectorFromString(func)
                                   withObject:param
                                   afterDelay:0];
                    }
                }else{
                    if([self respondsToSelector:NSSelectorFromString(function)]){
                        [self performSelector:NSSelectorFromString(function)
                                   withObject:nil
                                   afterDelay:0];
                    }
                }
            } @catch (NSException *exception) {
                NSLog(@"XenInfo - Error in WKWebView Decide Policy %@",exception);
            }
            //decisionHandler(WKNavigationActionPolicyCancel);
        }
        decisionHandler(WKNavigationActionPolicyAllow);
    }

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
	-(void)_unloadWebView{
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
        if(arg1){
            hasWebview = YES;
            if(!_webviews){
                _webviews=[[NSMutableArray array] retain];
            }
            if(![_webviews containsObject:arg1]){
                 [_webviews addObject:arg1];
            }
        }
	}
%end
