//
//  XIWeatherHeaders.h
//  XenInfo
//
//  Created by Matt Clarke on 28/10/2018.
//  Copyright © 2018 Matt Clarke. All rights reserved.
//

#ifndef XIWeatherHeaders_h
#define XIWeatherHeaders_h

#import <CoreLocation/CoreLocation.h>

@interface CLPlacemark (Private)
  @property (nonatomic, readonly, copy) NSString *subThoroughfare;
  @property (nonatomic, readonly, copy) NSString *thoroughfare;
  @property (nonatomic, readonly, copy) NSString *subLocality;
  @property (nonatomic, readonly, copy) NSString *locality;
  @property (nonatomic, readonly, copy) NSString *postalCode;
  @property (nonatomic, readonly, copy) NSString *subAdministrativeArea;
  @property (nonatomic, readonly, copy) NSString *administrativeArea;
  @property (nonatomic, readonly, copy) NSString *country;
  @property (nonatomic, readonly, copy) NSString *ISOcountryCode;
@end

@interface CLLocationManager (Private)
+ (int)authorizationStatusForBundleIdentifier:(id)arg1;
@end

@interface WeatherPreferences : NSObject
+ (instancetype)sharedPreferences;
- (id)localWeatherCity;
- (BOOL)isCelsius;
- (id)loadSavedCities;
- (id)loadSavedCityAtIndex:(int)index;
- (void)setLocalWeatherEnabled:(BOOL)enabled;
- (id)cityFromPreferencesDictionary:(id)arg1;
@end

@interface TWCLocationUpdater : NSObject
+ (instancetype)sharedLocationUpdater;
- (void)updateWeatherForLocation:(id)arg1 city:(id)arg2;
@end

@interface WFTemperature : NSObject
@property (nonatomic) double celsius;
@property (nonatomic) double fahrenheit;
@end

@interface WeatherLocationManager : NSObject
@property (assign,nonatomic) unsigned long long updateInterval;
+ (instancetype)sharedWeatherLocationManager;
- (void)setLocationTrackingActive:(BOOL)arg1;
- (void)setLocationTrackingIsReady:(char)arg1 ;
- (void)setLocationTrackingReady:(BOOL)arg1 activelyTracking:(BOOL)arg2;
- (void)setDelegate:(id)arg1;
- (void)setLocationTrackingReady:(bool)arg1 activelyTracking:(bool)arg2 watchKitExtension:(bool)arg3;

- (void)forceLocationUpdate;
@end

@interface City : NSObject
@property (nonatomic, copy) NSArray *dayForecasts;
@property (nonatomic, copy) NSArray *hourlyForecasts;
@property (assign,nonatomic) BOOL isLocalWeatherCity;
@property (nonatomic,retain) id wfLocation;
@property (nonatomic,copy) NSString * woeid;
@property (nonatomic,copy) NSString * name;
@property (nonatomic,copy) NSString * state;
@property (nonatomic,copy) NSString * temperature;
@property (assign,nonatomic) unsigned long long conditionCode;
@property (assign,nonatomic) unsigned long long observationTime;
@property (assign,nonatomic) unsigned long long sunsetTime;
@property (assign,nonatomic) unsigned long long sunriseTime;
@property (assign,nonatomic) unsigned long long moonPhase;
@property (assign,setter=setUVIndex:,nonatomic) unsigned long long uvIndex;
@property (assign,nonatomic) double precipitationPast24Hours;
@property (assign,nonatomic) double longitude;
@property (assign,nonatomic) double latitude;
@property (nonatomic,readonly) NSString * locationID;
@property (assign,nonatomic) long long secondsFromGMT;
@property (nonatomic,retain) NSTimeZone * timeZone;
@property (nonatomic,retain) NSDate * timeZoneUpdateDate;
@property (assign,nonatomic) BOOL isHourlyDataCelsius;
@property (assign,nonatomic) unsigned long long lastUpdateDetail;
@property (nonatomic,retain) NSDate * updateTime;
@property (assign,nonatomic) float windChill;
@property (assign,nonatomic) float windDirection;
@property (assign,nonatomic) float windSpeed;
@property (assign,nonatomic) float humidity;
@property (assign,nonatomic) float visibility;
@property (assign,nonatomic) float pressure;
@property (assign,nonatomic) long long pressureRising;
@property (assign,nonatomic) float dewPoint;
@property (assign,nonatomic) id feelsLike;
@property (assign,nonatomic) float heatIndex;
@property (assign,nonatomic) BOOL isDay;
@property (assign,nonatomic) int lastUpdateStatus;
@property (nonatomic,copy) NSString * updateTimeString;
@property (nonatomic,copy) NSString * fullName;
@property (nonatomic, copy) CLLocation *location;
- (int)precipitationForecast;
- (id)detailedDescription;
- (BOOL)isDay;
- (id)naturalLanguageDescription;
- (unsigned int)bigIcon;
- (id)displayName;
- (void)update;
- (id)cityAndState;
- (id)temperature;
- (id)updateTime;

- (void)associateWithDelegate:(id)delegate;
- (void)addUpdateObserver:(id)delegate;
@end

@interface DayForecast : NSObject
@property (nonatomic,copy) NSString * high;
@property (nonatomic,copy) NSString * low;
@property (assign,nonatomic) unsigned long long icon;
@property (assign,nonatomic) unsigned long long dayOfWeek;
@property (assign,nonatomic) unsigned long long dayNumber;
@end

@interface HourlyForecast : NSObject
@property (nonatomic) float percentPrecipitation;
@property (assign,nonatomic) unsigned long long eventType;
@property (nonatomic,copy) NSString * time;
@property (assign,nonatomic) long long hourIndex;
@property (nonatomic,retain) NSString * temperature;
@property (nonatomic,copy) NSString * forecastDetail;
@property (nonatomic, copy) NSString *detail;
@property (assign,nonatomic) long long conditionCode;
- (float)percentPrecipitation;
@end;

// iOS 11+ only

@interface WACurrentForecast : NSObject
@property (nonatomic,retain) WFTemperature *temperature;
@property (nonatomic,retain) WFTemperature *feelsLike;
@property (assign,nonatomic) float windSpeed;
@property (assign,nonatomic) float windDirection;
@property (assign,nonatomic) float humidity;
@property (assign,nonatomic) float dewPoint;
@property (assign,nonatomic) float visibility;
@property (assign,nonatomic) float pressure;
@property (assign,nonatomic) unsigned long long pressureRising;
@property (assign,nonatomic) unsigned long long UVIndex;
@property (assign,nonatomic) float precipitationPast24Hours;
@property (assign,nonatomic) long long conditionCode;
@property (assign,nonatomic) unsigned long long observationTime;
@end

@interface WFLocation : NSObject
@end

@interface WAForecastModel : NSObject
@property (nonatomic,retain) City *city;
@property (nonatomic,retain) WFLocation *location;
@end

@class WATodayModel;
@protocol WATodayModelObserver <NSObject>
@required
- (void)todayModelWantsUpdate:(WATodayModel*)arg1;
- (void)todayModel:(WATodayModel*)arg1 forecastWasUpdated:(WAForecastModel*)arg2;
@end

@interface WATodayModel : NSObject
@property (nonatomic,retain) WAForecastModel *forecastModel;
+ (instancetype)autoupdatingLocationModelWithPreferences:(id)arg1 effectiveBundleIdentifier:(NSString*)arg2;
+ (instancetype)modelWithLocation:(WFLocation*)arg1;
- (void)addObserver:(id<WATodayModelObserver>)arg1;
- (void)removeObserver:(id<WATodayModelObserver>)arg1;
- (BOOL)executeModelUpdateWithCompletion:(/*^block*/id)arg1 ;
@end

@interface WATodayAutoupdatingLocationModel : WATodayModel
-(void)setLocationServicesActive:(BOOL)arg1;
-(void)setIsLocationTrackingEnabled:(BOOL)arg1;
-(void)_teardownLocationManager;
-(void)_kickstartLocationManager;
@end

#endif /* XIWeatherHeaders_h */
