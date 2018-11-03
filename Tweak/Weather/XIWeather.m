//
//  XIWeather.m
//  XenInfo
//
//  Created by Matt Clarke on 31/05/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#import "XIWeather.h"
#import "XIWeatherHeaders.h"
#import "../Internal/XIWidgetManager.h"
#import <objc/runtime.h>

#define UPDATE_INTERVAL 30 // minutes

@interface XIWeather ()
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) WeatherLocationManager* weatherLocationManager;
@property (nonatomic, strong) City *currentCity;

@property (nonatomic, strong) NSDateFormatter *cachedFormatter;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation XIWeather

+ (NSString*)topic {
    return @"weather";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    self.deviceIsAsleep = YES;
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    self.deviceIsAsleep = NO;
    
    // Undertake a refresh if one was queued during sleep.
    if (self.refreshQueuedDuringDeviceSleep) {
        [self requestRefresh];
        self.refreshQueuedDuringDeviceSleep = NO;
    }
}

// Register a delegate object to call upon when new data becomes available.
- (void)registerDelegate:(id<XIWidgetManagerDelegate>)delegate {
    self.delegate = delegate;
}

// Called when a new widget is added, and it needs to be provided new data on load.
- (NSString*)requestCachedData {
    return [self _variablesToJSString];
}

- (void)requestRefresh {
    if (self.deviceIsAsleep) {
        self.refreshQueuedDuringDeviceSleep = YES;
        return;
    }
    
    if (!self.currentCity)
        self.currentCity = [self _currentCity];
    
    if ([self _locationServicesAvailable]) {
        [self _refreshWeatherWithCompletion:^(City *city) {
            [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIWeather topic]];
        }];
    } else {
        [self _refreshWeatherNoLocationWithCompletion:^(City *city) {
            [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIWeather topic]];
        }];
    }
}

- (NSString*)_variablesToJSString {
    if (!self.currentCity) {
        NSDictionary *weatherInfo = @{
                                      @"city": @"No Weather",
                                      @"temperature": @0,
                                      @"low": @0,
                                      @"high": @0,
                                      @"feelsLike": @0,
                                      @"chanceofrain": @0,
                                      @"condition": @"",
                                      @"naturalCondition": @"",
                                      @"dayForecasts": @[],
                                      @"hourlyForecasts": @[],
                                      @"latlong": @"0.0,0.0",
                                      @"celsius": @"C",
                                      @"isDay": @YES,
                                      @"conditionCode": @0,
                                      @"updateTimeString": @"",
                                      @"humidity": @0,
                                      @"dewPoint": @0,
                                      @"windChill": @0,
                                      @"windDirection": @0,
                                      @"windSpeed": @0,
                                      @"visibility": @0,
                                      @"sunsetTime": @"00:00",
                                      @"sunriseTime": @"00:00",
                                      @"precipitationForecast": @0,
                                      @"pressure": @0,
                                      @"precipitation24hr": @0,
                                      @"heatIndex": @0,
                                      @"moonPhase": @0,
                                      @"cityState": @""
                                      };
        
        NSString * jsonObj = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:weatherInfo
                                                                                            options:0
                                                                                              error:nil]
                                                   encoding:NSUTF8StringEncoding];
        
        return [NSString stringWithFormat:@"var weather = JSON.parse('%@');", jsonObj];
    }
    
    int temp = [self _convertTemperature:self.currentCity.temperature];
    int feelslike = [self _convertTemperature:self.currentCity.feelsLike];
    
    NSString *conditionString = @"Use weather.conditionCode"; // TODO: Really?
    
    NSString *userTemperatureUnit = [[objc_getClass("WeatherPreferences") sharedPreferences] isCelsius] ? @"C" : @"F";
    
    NSString *naturalCondition;
    if ([self.currentCity respondsToSelector:@selector(naturalLanguageDescription)]) {
        naturalCondition = [self _escapeString:[self.currentCity naturalLanguageDescription]];
        if (!naturalCondition)
            naturalCondition = @"";
    } else {
        naturalCondition = @"Natural condition is not supported on this iOS version";
    }
    
    NSMutableArray *dailyForecasts = [[NSMutableArray alloc] init];
    for (DayForecast *dayForecast in self.currentCity.dayForecasts) {
        int lowTemperature = [self _convertTemperature:dayForecast.low];
        int highTemperature = [self _convertTemperature:dayForecast.high];
        
        [dailyForecasts addObject:@{
                                    @"low": [NSNumber numberWithInt:lowTemperature],
                                    @"high": [NSNumber numberWithInt:highTemperature],
                                    @"dayNumber": [NSNumber numberWithLong:dayForecast.dayNumber],
                                    @"dayOfWeek": [NSNumber numberWithLong:dayForecast.dayOfWeek],
                                    @"icon": [NSNumber numberWithLong:dayForecast.icon]
                                    }];
    }
    
    NSMutableArray *hourlyForecasts = [[NSMutableArray alloc] init];
    for (HourlyForecast *hourForecast in self.currentCity.hourlyForecasts) {
        int temperature = 0;
        
        if ([hourForecast respondsToSelector:@selector(temperature)]) {
            temperature = [self _convertTemperature:hourForecast.temperature];
        } else {
            temperature = [hourForecast.detail intValue];
        }
        
        [hourlyForecasts addObject:@{
                                     @"time": hourForecast.time,
                                     @"conditionCode": [NSNumber numberWithLong:hourForecast.conditionCode],
                                     @"temperature": [NSNumber numberWithInt:temperature],
                                     @"percentPrecipitation": [NSNumber numberWithInt:hourForecast.percentPrecipitation],
                                     @"hourIndex": [NSNumber numberWithInt:hourForecast.hourIndex]
                                     }];
    }
    
    NSDictionary *weatherInfo = @{
                                  @"city": self.currentCity.name != nil ? self.currentCity.name : @"Local Weather",
                                  @"temperature": [NSNumber numberWithInt:temp],
                                  @"low": dailyForecasts.count > 0 ? [dailyForecasts[0] objectForKey:@"low"] : @0,
                                  @"high": dailyForecasts.count > 0 ? [dailyForecasts[0] objectForKey:@"high"] : @0,
                                  @"feelsLike": [NSNumber numberWithInt:feelslike],
                                  @"chanceofrain": hourlyForecasts.count > 0 ? [hourlyForecasts[0] objectForKey:@"percentPrecipitation"] : @0,
                                  @"condition": conditionString,
                                  @"naturalCondition": naturalCondition,
                                  @"dayForecasts": dailyForecasts,
                                  @"hourlyForecasts": hourlyForecasts,
                                  @"latlong": self.currentCity.locationID != nil ? self.currentCity.locationID : @"0.0,0.0",
                                  @"celsius": userTemperatureUnit,
                                  @"isDay": [NSNumber numberWithBool:self.currentCity.isDay],
                                  @"conditionCode": [NSNumber numberWithInt:self.currentCity.conditionCode],
                                  @"updateTimeString": self.currentCity.updateTimeString,
                                  @"humidity": [NSNumber numberWithInt:(int)roundf(self.currentCity.humidity)],
                                  @"dewPoint": [NSNumber numberWithInt:(int)roundf(self.currentCity.dewPoint)],
                                  @"windChill": [NSNumber numberWithInt:(int)roundf(self.currentCity.windChill)],
                                  @"windDirection": [NSNumber numberWithInt:(int)roundf(self.currentCity.windDirection)],
                                  @"windSpeed": [NSNumber numberWithInt:(int)roundf(self.currentCity.windSpeed)],
                                  @"visibility": [NSNumber numberWithInt:(int)roundf(self.currentCity.visibility)],
                                  @"sunsetTime": [self _intTimeToString:self.currentCity.sunsetTime],
                                  @"sunriseTime": [self _intTimeToString:self.currentCity.sunriseTime],
                                  @"precipitationForecast": [NSNumber numberWithInt:self.currentCity.precipitationForecast],
                                  @"pressure": [NSNumber numberWithInt:(int)roundf(self.currentCity.pressure)],
                                  @"precipitation24hr": [NSNumber numberWithFloat:self.currentCity.precipitationPast24Hours],
                                  @"heatIndex": [NSNumber numberWithInt:(int)roundf(self.currentCity.heatIndex)],
                                  @"moonPhase": [NSNumber numberWithInt:(int)roundf(self.currentCity.moonPhase)],
                                  @"cityState": self.currentCity.cityAndState != nil ? self.currentCity.cityAndState : @""
                                  };
    
    NSString * jsonObj = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:weatherInfo
                                                                                        options:0
                                                                                          error:nil]
                                               encoding:NSUTF8StringEncoding];
    
    return [NSString stringWithFormat:@"var weather = JSON.parse('%@');", jsonObj];
}

- (NSString*)_escapeString:(NSString*)input {
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    input = [input stringByReplacingOccurrencesOfString: @"/" withString:@"\\/"];
    
    return input;
}

#pragma mark Provider specific methods

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.refreshQueuedDuringDeviceSleep = YES; // Refresh once device comes online next
        self.cachedFormatter = [NSDateFormatter new];
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL * 60
                                                            target:self
                                                          selector:@selector(requestRefresh)
                                                          userInfo:nil
                                                           repeats:YES];
        
        // Location stuff
        self.locationManager = [[CLLocationManager alloc] init];
        
        self.weatherLocationManager = [objc_getClass("WeatherLocationManager") sharedWeatherLocationManager];
        [self.weatherLocationManager setDelegate:self.locationManager];
        
        self.locationManager.delegate = self;
        
        self.currentCity = [self _currentCity];
        
        // Do an initial update
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 5.0);
        dispatch_after(delay, dispatch_get_main_queue(), ^(void){
            [self requestRefresh];
            
            // Start location tracking in Weather.framework
            if ([self.weatherLocationManager respondsToSelector:@selector(setLocationTrackingReady:activelyTracking:watchKitExtension:)]) {
                [self.weatherLocationManager setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
            }
                
            if ([self.weatherLocationManager respondsToSelector:@selector(setLocationTrackingReady:activelyTracking:watchKitExtension:)]) {
                [self.weatherLocationManager setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
            }
            
            // Set initial tracking active state if possible
            if ([self _locationServicesAvailable]) {
                [self.weatherLocationManager setLocationTrackingActive:YES];
                [[objc_getClass("WeatherPreferences") sharedPreferences] setLocalWeatherEnabled:YES];
            }
        });
    }
    
    return self;
}

- (BOOL)_locationServicesAvailable {
    return [CLLocationManager locationServicesEnabled];
}

- (City*)_currentCity {
    if ([self _locationServicesAvailable]) {
        return [[objc_getClass("WeatherPreferences") sharedPreferences] localWeatherCity];
    } else {
        if (![[objc_getClass("WeatherPreferences") sharedPreferences] respondsToSelector:@selector(loadSavedCityAtIndex:)]) {
            @try {
                return [[[objc_getClass("WeatherPreferences") sharedPreferences] loadSavedCities] firstObject];
            } @catch (NSException *e) {
                Xlog(@"Failed to load first city in Weather.app for reason:\n%@", e);
                return nil;
            }
        } else
            return [[objc_getClass("WeatherPreferences") sharedPreferences] loadSavedCityAtIndex:0];
    }
}

- (int)_convertTemperature:(id)temperature {
    // On iOS 10 and higher, the temperature is of class WFTemperature.
    if ([temperature isKindOfClass:objc_getClass("WFTemperature")]) {
        WFTemperature *temp = (WFTemperature*)temperature;
        return [[objc_getClass("WeatherPreferences") sharedPreferences] isCelsius] ? (int)temp.celsius : (int)temp.fahrenheit;
    } else {
        int temp = [temperature intValue];
        
        // Need to convert to Farenheit ourselves annoyingly
        if (![[objc_getClass("WeatherPreferences") sharedPreferences] isCelsius])
            temp = ((temp*9)/5) + 32;
        
        return temp;
    }
}

- (BOOL)_isDeviceIn24Time {
    [self.cachedFormatter setDateStyle:NSDateFormatterNoStyle];
    [self.cachedFormatter setTimeStyle:NSDateFormatterShortStyle];
    NSString *dateString = [self.cachedFormatter stringFromDate:[NSDate date]];
    NSRange amRange = [dateString rangeOfString:[self.cachedFormatter AMSymbol]];
    NSRange pmRange = [dateString rangeOfString:[self.cachedFormatter PMSymbol]];
    BOOL is24Hour = amRange.location == NSNotFound && pmRange.location == NSNotFound;
    return is24Hour;
}

- (NSString*)_translatedAMString {
    return [self.cachedFormatter AMSymbol];
}

- (NSString*)_translatedPMString {
    return [self.cachedFormatter PMSymbol];
}

- (NSString*)_intTimeToString:(int)input {
    if (input == 0) {
        return @"00:00";
    }
    
    NSString *string = @"";
    if (input < 100) {
        string = [NSString stringWithFormat:@"00%d", input];
    } else if (input < 1000) {
        string = [NSString stringWithFormat:@"0%d", input];
    } else {
        string = [NSString stringWithFormat:@"%d", input];
    }
    
    char one, two, three, four;
    one = [string characterAtIndex:0];
    two = [string characterAtIndex:1];
    three = [string characterAtIndex:2];
    four = [string characterAtIndex:3];
    
    NSString *suffix = @"";
    
    // Convert to 12hr if required by current locale.
    // Yes, I know this is horrid. Oh well.
    if (![self _isDeviceIn24Time]) {
        
        if (one == '1' && two > '2') {
            one = '0';
            two -= 2;
            
            suffix = [self _translatedPMString];
        } else if (one == '2') {
            // Handle 20 and 21 first.
            if (two == '0') {
                one = '0';
                two = '8';
            } else if (two == '1') {
                one = '0';
                two = '9';
            } else {
                one = '1';
                two -= 2;
            }
            
            suffix = [self _translatedPMString];
        } else {
            suffix = [self _translatedAMString];
        }
        
    }
    
    // Split string, and insert :
    string = [NSString stringWithFormat:@"%c%c:%c%c%@", one, two, three, four, suffix];
    
    return string;
}

- (void)_refreshWeatherNoLocationWithCompletion:(void (^)(City*))completionHandler {
    TWCLocationUpdater *locationUpdater = [objc_getClass("TWCLocationUpdater") sharedLocationUpdater];
    
    if ([locationUpdater respondsToSelector:@selector(updateWeatherForLocation:city:withCompletionHandler:)]) {
        [locationUpdater updateWeatherForLocation:self.currentCity.location city:self.currentCity withCompletionHandler:^{
            completionHandler(self.currentCity);
        }];
    } else if ([locationUpdater respondsToSelector:@selector(_updateWeatherForLocation:city:completionHandler:)]) {
        [[objc_getClass("TWCLocationUpdater") sharedLocationUpdater] _updateWeatherForLocation:self.currentCity.location city:self.currentCity completionHandler:^{
            completionHandler(self.currentCity);
        }];
    }
}

- (void)_refreshWeatherWithCompletion:(void (^)(City*))completionHandler {
    TWCLocationUpdater *locationUpdater = [objc_getClass("TWCLocationUpdater") sharedLocationUpdater];
    
    if ([self.weatherLocationManager respondsToSelector:@selector(setLocationTrackingReady:activelyTracking:watchKitExtension:)]) {
            [self.weatherLocationManager setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
    }
    
    if ([self.weatherLocationManager respondsToSelector:@selector(setLocationTrackingReady:activelyTracking:watchKitExtension:)]) {
        [self.weatherLocationManager setLocationTrackingReady:YES activelyTracking:NO watchKitExtension:NO];
    }
    
    if ([locationUpdater respondsToSelector:@selector(updateWeatherForLocation:city:withCompletionHandler:)]) {
        [locationUpdater updateWeatherForLocation:self.currentCity.location city:self.currentCity withCompletionHandler:^{
            completionHandler(self.currentCity);
        }];
    } else if ([locationUpdater respondsToSelector:@selector(_updateWeatherForLocation:city:completionHandler:)]) {
        [[objc_getClass("TWCLocationUpdater") sharedLocationUpdater] _updateWeatherForLocation:self.currentCity.location city:self.currentCity completionHandler:^{
            completionHandler(self.currentCity);
        }];
    }
}

@end
