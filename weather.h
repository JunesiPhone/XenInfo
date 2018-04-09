/*weather*/

@interface City : NSObject
- (id)temperature;
- (id)updateTime;
@property(nonatomic, getter=isDataCelsius) _Bool dataCelsius;
@property (nonatomic, copy) NSArray *dayForecasts;
@property (nonatomic, copy) NSArray *hourlyForecasts;
@property (readonly) NSDictionary * urlComponents;
@property (assign,nonatomic) BOOL isLocalWeatherCity;
@property (nonatomic,copy) NSString * woeid;
@property (nonatomic,copy) NSString * name;
@property (nonatomic,readonly) NSString * locationID;
@property (nonatomic,copy) NSString * state;
@property (nonatomic,copy) NSString * temperature;
@property (assign,nonatomic) unsigned long long conditionCode;
@property (assign,nonatomic) unsigned long long observationTime;
@property (assign,nonatomic) unsigned long long sunsetTime;
@property (assign,nonatomic) unsigned long long sunriseTime;
@property (assign,nonatomic) unsigned long long moonPhase;
@property (assign,setter=setUVIndex:,nonatomic) unsigned long long uvIndex;
@property (assign,nonatomic) double precipitationPast24Hours;
@property (nonatomic,copy) NSString * link;
@property (nonatomic,copy) NSString * deeplink;
@property (assign,nonatomic) double longitude;
@property (assign,nonatomic) double latitude;
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
@property (assign,nonatomic) float feelsLike;
@property (assign,nonatomic) float heatIndex;
@property (assign,nonatomic) BOOL isDay;
@property (assign,nonatomic) int lastUpdateStatus;
@property (assign,nonatomic) unsigned long long lastUpdateWarning;
@property (assign,nonatomic) BOOL isUpdating;
@property (assign,nonatomic) BOOL isRequestedByFrameworkClient;
@property (assign,nonatomic) BOOL lockedForDemoMode;
@property (nonatomic,copy) NSString * fullName;
@property (assign,nonatomic) int updateInterval;
@property (nonatomic, copy) CLLocation *location;
-(id)updateTimeString;
-(int)precipitationForecast;
- (id)detailedDescription;
- (BOOL)isDay;
-(id)naturalLanguageDescription;
- (unsigned int)bigIcon;
-(void)update;
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
- (float)percentPrecipitation;
@end;

@interface WeatherLocationManager
+ (id)sharedWeatherLocationManager;
- (void)setLocationTrackingActive:(BOOL)arg1;
-(void)setLocationTrackingIsReady:(char)arg1 ;
- (void)setLocationTrackingReady:(BOOL)arg1 activelyTracking:(BOOL)arg2;
- (void)setDelegate:(id)arg1;
- (id)location;
- (BOOL)locationTrackingIsReady;
- (void)setLocationTrackingReady:(bool)arg1 activelyTracking:(bool)arg2 watchKitExtension:(bool)arg3;
@end

@interface LocationUpdater
+ (id)sharedLocationUpdater;
- (void)updateWeatherForLocation:(id)arg1 city:(id)arg2;
- (void)handleCompletionForCity:(id)arg1 withUpdateDetail:(unsigned long long)arg2;
- (void)setWeatherBadge:(id)value;
@end

@interface WeatherPreferences
@property (nonatomic,copy) NSString * yahooWeatherURLString;

@property (readonly) Class superclass;
@property (copy,readonly) NSString * description;
@property (copy,readonly) NSString * debugDescription;

+ (id)sharedPreferences;
- (id)localWeatherCity;
- (void)setLocalWeatherEnabled:(BOOL)arg1;
- (BOOL)isCelsius;
- (id)loadSavedCities;
@end

@interface WeatherHTTPRequest : NSObject <NSURLConnectionDataDelegate> {

    NSMutableData* _rawData;
    NSMutableURLRequest* _request;
    NSURLConnection* _connection;

}
@end

@interface WeatherJSONHTTPRequest : WeatherHTTPRequest
-(void)failWithError:(id)arg1 ;
-(id)aggregateDictionaryDomain;
-(void)willProcessJSONObject;
-(void)processJSONObject:(id)arg1 ;
-(void)didProcessJSONObject;
-(void)request:(id)arg1 receivedResponseData:(id)arg2 ;
@end

@interface TWCUpdater : WeatherJSONHTTPRequest {

    NSMutableArray* _updatingCities;
    NSMutableArray* _pendingCities;
    /*^block*/id _weatherCompletionUpdaterHandler;

}

-(void)failWithError:(id)arg1 ;

-(void)dealloc;
-(id)init;

-(id)aggregateDictionaryDomain;
-(void)processJSONObject:(id)arg1 ;
-(void)didProcessJSONObject;
-(void)runAndClearWeatherCompletionWithDetail:(unsigned long long)arg1 ;
-(void)handleCompletionForCity:(id)arg1 withUpdateDetail:(unsigned long long)arg2 ;
-(void)failCity:(id)arg1 ;
-(id)_ISO8601Calendar;
-(id)_GMTOffsetRegularExpression;
-(id)_ISO8601DateFormatter;
-(void)_failed:(unsigned long long)arg1 ;
-(void)_processHourlyForecasts:(id)arg1 ;
-(void)_processDailyForecasts:(id)arg1 ;
-(void)_processCurrentConditions:(id)arg1 ;
-(void)_processLinks:(id)arg1 ;
-(void)parsedResultCity:(id)arg1 ;
-(void)_updateNextPendingCity;
-(BOOL)isDataValid:(id)arg1 ;
-(void)addCityToPendingQueue:(id)arg1 ;
-(void)handleNilCity;
-(void)loadRequestForURLPortion:(id)arg1 ;
-(BOOL)isUpdatingCity:(id)arg1 ;
-(id)weatherCompletionUpdaterHandler;
-(void)setWeatherCompletionUpdaterHandler:(id)arg1 ;
@end


@interface TWCLocationUpdater : TWCUpdater {

    City* _currentCity;

}
+(id)sharedLocationUpdater;

- (void)_updateWeatherForLocation:(id)arg1 city:(id)arg2 completionHandler:(id /* block */)arg3;
- (id)currentCity;
- (void)enableProgressIndicator:(bool)arg1;
- (void)parsedResultCity:(id)arg1;
- (id)reverseGeocoder;
- (void)setCurrentCity:(id)arg1;
- (void)setReverseGeocoder:(id)arg1;
- (void)updateWeatherForCities:(id)arg1 withCompletionHandler:(id /* block */)arg2;
- (void)updateWeatherForCity:(id)arg1;
- (void)updateWeatherForLocation:(id)arg1 city:(id)arg2;
-(void)updateWeatherForLocation:(id)arg1 city:(id)arg2 withCompletionHandler:(/*^block*/id)arg3 ;

@end
@interface CLApproved : CLLocationManager
+ (int)authorizationStatusForBundleIdentifier:(id)arg1;
@end
@interface WFTemperature : NSObject
@property (nonatomic) double celsius;
@property (nonatomic) double fahrenheit;
@end

@interface WCLocation : NSObject

@property CLLocationCoordinate2D coordinate;
@property CLLocationDistance altitude;
@property (nonatomic, strong) CLFloor *floor;
@property CLLocationAccuracy horizontalAccuracy;
@property CLLocationAccuracy verticalAccuracy;
@property (nonatomic, strong) NSDate *timestamp;
@property CLLocationSpeed speed;
@property CLLocationDirection course;

-(id)copyWithZone:(NSZone *) zone;

@end
/*endweather*/