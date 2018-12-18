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
#import <substrate.h>

/*
 * General notes:
 *
 * Due to differences in iOS versions, different approaches to updating weather is taken. For iOS 9 users,
 * a port of InfoStats 2's Weather functionality has been made. This however does not handle retrieving
 * new location updates due to a missing entitlement in SpringBoard.
 *
 * iOS 10 and 11 users make use of WATodayModel introduced in 10. This is a much simplier API to request new data
 * with, and supports automatic location updates for iOS 11+ users.
 *
 * Each approach is implemented as a separate class to keep things tidy, XITWCWeather and XIWAWeather. This current
 * class acts as a proxy to those implementations, forwarding info like device sleep/wake state to them, and new
 * City objects back again. This class is responsible for the actual parsing of the City object into a JSON string.
 */

@interface XIWeather ()
@property (nonatomic, strong) WeatherLocationManager* weatherLocationManager;
@property (nonatomic, strong) City *currentCity;
@property (nonatomic, strong) NSDictionary *reverseGeocodedAddress;

@property (nonatomic, strong) NSDateFormatter *cachedFormatter;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation XIWeather

+ (NSString*)topic {
    return @"weather";
}

// Called when the device enters sleep mode
- (void)noteDeviceDidEnterSleep {
    // Notify appropriate updater.
    if (self.waWeather)
        [self.waWeather noteDeviceDidEnterSleep];
    else if (self.twcWeather)
        [self.twcWeather noteDeviceDidEnterSleep];
}

// Called on the reverse
- (void)noteDeviceDidExitSleep {
    // Notify appropriate updater.
    if (self.waWeather)
        [self.waWeather noteDeviceDidExitSleep];
    else if (self.twcWeather)
        [self.twcWeather noteDeviceDidExitSleep];
}

// Called when network access is lost
- (void)networkWasDisconnected {
    if (self.waWeather)
        [self.waWeather networkWasDisconnected];
    else if (self.twcWeather)
        [self.twcWeather networkWasDisconnected];
}

// Called when network access is restored
- (void)networkWasConnected {
    if (self.waWeather)
        [self.waWeather networkWasConnected];
    else if (self.twcWeather)
        [self.twcWeather networkWasConnected];
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
    // Request appropriate updater to update.
    if (self.waWeather)
        [self.waWeather requestRefresh];
    else if (self.twcWeather)
        [self.twcWeather requestRefresh];
}

- (NSString*)_variablesToJSString {
    if (!self.currentCity) {
        NSDictionary *weatherInfo = @{
                                      @"city": @"No Weather",
                                      @"address": @{},
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
    int feelslike = 0;
    
    if ([UIDevice currentDevice].systemVersion.floatValue >= 10.0)
        feelslike = [self _convertTemperature:self.currentCity.feelsLike];
    else
        feelslike = [self _convertToFarenheitIfNeeded:(int)self.currentCity.feelsLike]; // iOS 9 is a float for this
    
    // Grabs translated condition string
    NSString *conditionString = [self _conditionNameFromCode:self.currentCity.conditionCode];
    
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
                                     @"time": hourForecast.time != nil ? hourForecast.time : @"00:00",
                                     @"conditionCode": [NSNumber numberWithLong:hourForecast.conditionCode],
                                     @"temperature": [NSNumber numberWithInt:temperature],
                                     @"percentPrecipitation": [NSNumber numberWithInt:hourForecast.percentPrecipitation],
                                     @"hourIndex": [NSNumber numberWithInt:hourForecast.hourIndex]
                                     }];
    }
    
    NSDictionary *weatherInfo = @{
                                  @"city": self.currentCity.name != nil ? self.currentCity.name : @"Local Weather",
                                  @"address": self.reverseGeocodedAddress ? self.reverseGeocodedAddress : @{},
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
                                  @"updateTimeString": self.currentCity.updateTimeString != nil ? self.currentCity.updateTimeString : @"",
                                  @"humidity": [NSNumber numberWithInt:(int)roundf(self.currentCity.humidity)],
                                  @"dewPoint": [NSNumber numberWithInt:(int)roundf(self.currentCity.dewPoint)],
                                  @"windChill": [NSNumber numberWithInt:(int)roundf(self.currentCity.windChill)],
                                  @"windDirection": [NSNumber numberWithInt:(int)roundf(self.currentCity.windDirection)],
                                  @"windSpeed": [NSNumber numberWithInt:(int)roundf(self.currentCity.windSpeed)],
                                  @"visibility": [NSNumber numberWithInt:(int)roundf(self.currentCity.visibility)],
                                  @"sunsetTime": [NSString stringWithFormat:@"%llu",self.currentCity.sunsetTime],
                                  @"sunriseTime": [NSString stringWithFormat:@"%llu",self.currentCity.sunriseTime],
                                  @"sunsetTimeFormatted":[self _intTimeToString:self.currentCity.sunsetTime],
                                  @"sunriseTimeFormatted": [self _intTimeToString:self.currentCity.sunriseTime],
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
    if (!input)
        return @"";
    
    input = [input stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    input = [input stringByReplacingOccurrencesOfString: @"\"" withString:@"\\\""];
    input = [input stringByReplacingOccurrencesOfString: @"/" withString:@"\\/"];
    
    return input;
}

- (NSString*)_conditionNameFromCode:(int)condition {
    MSImageRef weather = MSGetImageByName("/System/Library/PrivateFrameworks/Weather.framework/Weather");
    if (weather && [[UIDevice currentDevice] systemVersion].floatValue < 11.0) {
        CFStringRef *_weatherDescription = (CFStringRef*)MSFindSymbol(weather, "_WeatherDescription") + condition;
        NSString *cond = (__bridge id)*_weatherDescription;
        return [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Weather.framework"] localizedStringForKey:cond value:@"" table:@"WeatherFrameworkLocalizableStrings"];
    } else if (weather && [[UIDevice currentDevice] systemVersion].floatValue >= 11.0) {
        CFStringRef (*WAConditionsLineStringFromConditionCode)() = MSFindSymbol(weather, "_WAConditionsLineStringFromConditionCode");
        
        NSString *cond = (__bridge id)WAConditionsLineStringFromConditionCode(condition);
        if (!cond)
            cond = @"";
        
        return cond;
    }
    
    return @"";
}

#pragma mark Provider specific methods

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.cachedFormatter = [NSDateFormatter new];
        
        // Init appropriate weather updater for iOS version.
        if ([UIDevice currentDevice].systemVersion.floatValue >= 10.0) {
            self.waWeather = [[XIWAWeather alloc] init];
            self.waWeather.delegate = self;
            self.currentCity  = self.waWeather.currentCity; // Initial setting of city
        } else {
            self.twcWeather = [[XITWCWeather alloc] init];
            self.twcWeather.delegate = self;
            self.currentCity  = self.twcWeather.currentCity; // Initial setting of city
        }
    }
    
    return self;
}

- (void)didUpdateCity:(City*)city {
    // City did update, this is now the current city.
    self.currentCity = city;
    
    // Do a reverse geocoding request for this city
    CLGeocoder *geocoder = [CLGeocoder new];
    [geocoder reverseGeocodeLocation:city.location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (error || placemarks.count == 0) {
            // TODO: Handle geocode error!
        } else {
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
            self.reverseGeocodedAddress = @{
                                            @"street": [NSString stringWithFormat:@"%@ %@", placemark.subThoroughfare ? placemark.subThoroughfare : @"", placemark.thoroughfare ? placemark.thoroughfare : @""],
                                            @"neighbourhood": placemark.subLocality ? placemark.subLocality : @"",
                                            @"city": placemark.locality ? placemark.locality : @"",
                                            @"postalCode": placemark.postalCode ? placemark.postalCode : @"",
                                            @"county": placemark.subAdministrativeArea ? placemark.subAdministrativeArea : @"",
                                            @"state": placemark.administrativeArea ? placemark.administrativeArea : @"",
                                            @"country": placemark.country ? placemark.country : @"",
                                            @"countryISOCode": placemark.ISOcountryCode ? placemark.ISOcountryCode : @""
                                            };
            
            Xlog(@"Got new geocoded address: %@", self.reverseGeocodedAddress);
        }
        
        [self.delegate updateWidgetsWithNewData:[self _variablesToJSString] onTopic:[XIWeather topic]];
    }];
}

- (int)_convertTemperature:(id)temperature {
    // On iOS 10 and higher, the temperature is of class WFTemperature.
    if ([temperature isKindOfClass:objc_getClass("WFTemperature")]) {
        WFTemperature *temp = (WFTemperature*)temperature;
        return [[objc_getClass("WeatherPreferences") sharedPreferences] isCelsius] ? (int)temp.celsius : (int)temp.fahrenheit;
    } else {
        return [self _convertToFarenheitIfNeeded:[temperature intValue]];
    }
}

- (int)_convertToFarenheitIfNeeded:(int)temp {
    // Need to convert to Farenheit ourselves annoyingly
    if (![[objc_getClass("WeatherPreferences") sharedPreferences] isCelsius])
        temp = ((temp*9)/5) + 32;
    
    return temp;
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
    if (input < 10) {
        string = [NSString stringWithFormat:@"000%d", input];
    } else if (input < 100) {
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

@end
