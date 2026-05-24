#import "YandexMapModule.h"

#import <YandexMapsMobile/YMKMapKitFactory.h>
#import <YandexMapsMobile/YRTI18nManager.h>
#import <CoreLocation/CoreLocation.h>

static BOOL sMapKitInitialised = NO;
static dispatch_once_t sInfoPlistOnce;

@interface YandexMapModule () <CLLocationManagerDelegate>
@end

@implementation YandexMapModule {
  CLLocationManager *_locationManager;
  RCTPromiseResolveBlock _locationResolve;
  RCTPromiseRejectBlock _locationReject;
  RCTPromiseResolveBlock _currentLocationResolve;
  RCTPromiseRejectBlock _currentLocationReject;
  // Bumped on every new getCurrentLocation request; the 12s timeout block
  // captures a snapshot, so a stale timer firing after success/failure can
  // detect the mismatch and bail.
  NSUInteger _currentLocationGen;
}

RCT_EXPORT_MODULE(YandexMapModule)

+ (BOOL)isMapKitInitialized {
  return sMapKitInitialised;
}

+ (void)applyApiKey:(NSString *)apiKey {
  if (sMapKitInitialised) {
    return;
  }
  @try {
    [YMKMapKit setApiKey:apiKey];
  } @catch (NSException *exception) {
    // setApiKey throws if called twice in the same process. Treat as benign.
  }
  [[YMKMapKit sharedInstance] onStart];
  sMapKitInitialised = YES;
}

+ (void)ensureMapKitStartedFromInfoPlist {
  dispatch_once(&sInfoPlistOnce, ^{
    if (sMapKitInitialised) {
      return;
    }
    NSString *key = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"YandexMapKitApiKey"];
    if (key.length > 0) {
      [self applyApiKey:key];
    }
  });
}

- (void)init:(NSString *)apiKey
     resolve:(RCTPromiseResolveBlock)resolve
      reject:(RCTPromiseRejectBlock)reject {
  if (apiKey.length == 0) {
    reject(@"YANDEX_MAP_INIT_NO_KEY", @"API key is empty", nil);
    return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    @try {
      [YandexMapModule applyApiKey:apiKey];
      resolve(nil);
    } @catch (NSException *exception) {
      reject(@"YANDEX_MAP_INIT_FAILED",
             exception.reason ?: @"Failed to initialise YMKMapKit",
             nil);
    }
  });
}

// MapKit-managed locale: YMKMapKit owns it once it's the consumer (it is for
// this lib). YRTI18nManagerFactory.setLocale is for apps that *don't* use
// MapKit, per the header comment, and is also a no-op if MapKit set the
// locale first. So we always go through YMKMapKit.setLocale here.
- (void)setLocale:(NSString *)locale
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject {
  dispatch_async(dispatch_get_main_queue(), ^{
    @try {
      [YMKMapKit setLocale:locale];
      resolve(nil);
    } @catch (NSException *e) {
      reject(@"YANDEX_MAP_LOCALE_FAILED", e.reason ?: @"setLocale failed", nil);
    }
  });
}

- (void)resetLocale:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject {
  dispatch_async(dispatch_get_main_queue(), ^{
    @try {
      [YMKMapKit setLocale:nil];
      resolve(nil);
    } @catch (NSException *e) {
      reject(@"YANDEX_MAP_LOCALE_FAILED", e.reason ?: @"resetLocale failed", nil);
    }
  });
}

- (void)getLocale:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject {
  dispatch_async(dispatch_get_main_queue(), ^{
    @try {
      resolve([YRTI18nManagerFactory getLocale] ?: @"");
    } @catch (NSException *e) {
      reject(@"YANDEX_MAP_LOCALE_FAILED", e.reason ?: @"getLocale failed", nil);
    }
  });
}

#pragma mark - Location permission

- (void)requestLocationPermission:(RCTPromiseResolveBlock)resolve
                           reject:(RCTPromiseRejectBlock)reject {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (_locationManager == nil) {
      _locationManager = [[CLLocationManager alloc] init];
      _locationManager.delegate = self;
    }
    CLAuthorizationStatus status = _locationManager.authorizationStatus;
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
        status == kCLAuthorizationStatusAuthorizedAlways) {
      resolve(@"granted");
      return;
    }
    if (status == kCLAuthorizationStatusDenied ||
        status == kCLAuthorizationStatusRestricted) {
      resolve(@"denied");
      return;
    }
    // Reject parallel requests rather than overwriting the previous waiter —
    // iOS only ever shows one auth dialog at a time anyway.
    if (_locationResolve != nil) {
      reject(@"YANDEX_LOCATION_PERMISSION_IN_PROGRESS",
             @"Another location permission request is already in flight",
             nil);
      return;
    }
    _locationResolve = resolve;
    _locationReject = reject;
    [_locationManager requestWhenInUseAuthorization];
  });
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
  if (_locationResolve == nil) return;
  CLAuthorizationStatus status = manager.authorizationStatus;
  if (status == kCLAuthorizationStatusNotDetermined) return; // still waiting
  if (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
      status == kCLAuthorizationStatusAuthorizedAlways) {
    _locationResolve(@"granted");
  } else {
    _locationResolve(@"denied");
  }
  _locationResolve = nil;
  _locationReject = nil;
}

- (void)getCurrentLocation:(RCTPromiseResolveBlock)resolve
                    reject:(RCTPromiseRejectBlock)reject {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (_locationManager == nil) {
      _locationManager = [[CLLocationManager alloc] init];
      _locationManager.delegate = self;
    }
    CLAuthorizationStatus status = _locationManager.authorizationStatus;
    if (status != kCLAuthorizationStatusAuthorizedWhenInUse &&
        status != kCLAuthorizationStatusAuthorizedAlways) {
      reject(@"YANDEX_LOCATION_PERMISSION", @"Location permission not granted", nil);
      return;
    }
    CLLocation *last = _locationManager.location;
    if (last != nil) {
      resolve(@{
        @"lat": @(last.coordinate.latitude),
        @"lon": @(last.coordinate.longitude),
      });
      return;
    }
    if (_currentLocationResolve != nil) {
      reject(@"YANDEX_LOCATION_IN_PROGRESS",
             @"Another getCurrentLocation request is already in flight",
             nil);
      return;
    }
    _currentLocationResolve = resolve;
    _currentLocationReject = reject;
    _currentLocationGen += 1;
    NSUInteger myGen = _currentLocationGen;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [_locationManager startUpdatingLocation];

    // 12s timeout — sim/offline devices may never produce a fix. We use a
    // generation counter rather than dispatch_block_cancel so the timer can't
    // misfire after a successful update (the success path bumps no gen, but
    // sets _currentLocationReject to nil, which is also a guard).
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      if (myGen != self->_currentLocationGen) return;
      if (self->_currentLocationReject == nil) return;
      RCTPromiseRejectBlock r = self->_currentLocationReject;
      self->_currentLocationResolve = nil;
      self->_currentLocationReject = nil;
      [self->_locationManager stopUpdatingLocation];
      r(@"YANDEX_LOCATION_TIMEOUT", @"No location fix within 12s", nil);
    });
  });
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
  if (_currentLocationResolve == nil || locations.count == 0) return;
  CLLocation *loc = locations.lastObject;
  RCTPromiseResolveBlock r = _currentLocationResolve;
  _currentLocationResolve = nil;
  _currentLocationReject = nil;
  // Bump gen so the in-flight timeout block sees a mismatch and bails.
  _currentLocationGen += 1;
  [manager stopUpdatingLocation];
  r(@{
    @"lat": @(loc.coordinate.latitude),
    @"lon": @(loc.coordinate.longitude),
  });
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
  if (_currentLocationReject == nil) return;
  RCTPromiseRejectBlock r = _currentLocationReject;
  _currentLocationResolve = nil;
  _currentLocationReject = nil;
  _currentLocationGen += 1;
  [manager stopUpdatingLocation];
  r(@"YANDEX_LOCATION_FAILED",
    error.localizedDescription ?: @"location failed",
    error);
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeYandexMapModuleSpecJSI>(params);
}

@end
