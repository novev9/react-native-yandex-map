#import "YandexSearchModule.h"
#import "YandexMapModule.h"

#import <YandexMapsMobile/YMKSearch.h>
#import <YandexMapsMobile/YMKSearchManager.h>
#import <YandexMapsMobile/YMKSearchOptions.h>
#import <YandexMapsMobile/YMKSearchSession.h>
#import <YandexMapsMobile/YMKSearchResponse.h>
#import <YandexMapsMobile/YMKGeoObjectCollection.h>
#import <YandexMapsMobile/YMKGeoObject.h>
#import <YandexMapsMobile/YMKGeometry.h>
#import <YandexMapsMobile/YMKPoint.h>
#import <YandexMapsMobile/YMKSearchToponymObjectMetadata.h>
#import <YandexMapsMobile/YMKUriObjectMetadata.h>

@implementation YandexSearchModule {
  YMKSearchManager *_manager;
  NSMutableArray<YMKSearchSession *> *_pending;
}

RCT_EXPORT_MODULE(YandexSearchModule)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (instancetype)init {
  if (self = [super init]) {
    _pending = [NSMutableArray array];
  }
  return self;
}

- (YMKSearchManager *)manager {
  if (_manager == nil) {
    // Search API should work even if no YandexMapView has been mounted yet —
    // initialise MapKit from Info.plist (or earlier YandexMap.init JS call)
    // before instantiating the search manager.
    [YandexMapModule ensureMapKitStartedFromInfoPlist];
    _manager = [[YMKSearchFactory instance]
      createSearchManagerWithSearchManagerType:YMKSearchManagerTypeCombined];
  }
  return _manager;
}

- (void)searchByText:(NSString *)query
            viewport:(nullable NSDictionary *)viewport
             options:(nullable NSDictionary *)options
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject {
  if (query.length == 0) {
    reject(@"YANDEX_SEARCH_NO_QUERY", @"query is empty", nil);
    return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    YMKGeometry *geometry = [self geometryFromViewport:viewport];
    YMKSearchOptions *opts = [self optionsFromDictionary:options];

    __block YMKSearchSession *session;
    NSMutableArray<YMKSearchSession *> *pending = self->_pending;
    session = [[self manager] submitWithText:query
                                    geometry:geometry
                               searchOptions:opts
                             responseHandler:^(YMKSearchResponse * _Nullable response,
                                               NSError * _Nullable error) {
      [pending removeObject:session];
      if (error != nil) {
        reject(@"YANDEX_SEARCH_FAILED",
               error.localizedDescription ?: @"search failed",
               error);
        return;
      }
      resolve([YandexSearchModule hitsFromResponse:response]);
    }];
    if (session != nil) [pending addObject:session];
  });
}

- (void)resolveUri:(NSString *)uri
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
  if (uri.length == 0) {
    resolve([NSNull null]);
    return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    YMKSearchOptions *opts = [[YMKSearchOptions alloc] init];

    __block YMKSearchSession *session;
    NSMutableArray<YMKSearchSession *> *pending = self->_pending;
    session = [[self manager] resolveURIWithUri:uri
                                  searchOptions:opts
                                responseHandler:^(YMKSearchResponse * _Nullable response,
                                                  NSError * _Nullable error) {
      [pending removeObject:session];
      if (error != nil) {
        reject(@"YANDEX_RESOLVE_URI_FAILED",
               error.localizedDescription ?: @"resolve uri failed",
               error);
        return;
      }
      NSArray *hits = [YandexSearchModule hitsFromResponse:response];
      resolve(hits.count > 0 ? hits.firstObject : (id)[NSNull null]);
    }];
    if (session != nil) [pending addObject:session];
  });
}

- (void)geocodePoint:(NSDictionary *)point
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject {
  double lat = [point[@"lat"] doubleValue];
  double lon = [point[@"lon"] doubleValue];
  YMKPoint *target = [YMKPoint pointWithLatitude:lat longitude:lon];
  dispatch_async(dispatch_get_main_queue(), ^{
    YMKSearchOptions *opts = [[YMKSearchOptions alloc] init];
    opts.searchTypes = YMKSearchTypeGeo;
    opts.resultPageSize = @(1);

    __block YMKSearchSession *session;
    NSMutableArray<YMKSearchSession *> *pending = self->_pending;
    session = [[self manager] submitWithPoint:target
                                          zoom:@(18)
                                 searchOptions:opts
                               responseHandler:^(YMKSearchResponse * _Nullable response,
                                                 NSError * _Nullable error) {
      [pending removeObject:session];
      if (error != nil) {
        reject(@"YANDEX_GEOCODE_FAILED",
               error.localizedDescription ?: @"geocode failed",
               error);
        return;
      }
      NSArray *hits = [YandexSearchModule hitsFromResponse:response];
      resolve(hits.count > 0 ? hits.firstObject : (id)[NSNull null]);
    }];
    if (session != nil) [pending addObject:session];
  });
}

- (YMKGeometry *)geometryFromViewport:(nullable NSDictionary *)viewport {
  if (viewport == nil) {
    YMKPoint *sw = [YMKPoint pointWithLatitude:-85 longitude:-180];
    YMKPoint *ne = [YMKPoint pointWithLatitude:85 longitude:180];
    YMKBoundingBox *box = [YMKBoundingBox boundingBoxWithSouthWest:sw northEast:ne];
    return [YMKGeometry geometryWithBoundingBox:box];
  }
  NSDictionary *sw = viewport[@"southWest"] ?: @{};
  NSDictionary *ne = viewport[@"northEast"] ?: @{};
  YMKPoint *swp = [YMKPoint pointWithLatitude:[sw[@"lat"] doubleValue]
                                     longitude:[sw[@"lon"] doubleValue]];
  YMKPoint *nep = [YMKPoint pointWithLatitude:[ne[@"lat"] doubleValue]
                                     longitude:[ne[@"lon"] doubleValue]];
  YMKBoundingBox *box = [YMKBoundingBox boundingBoxWithSouthWest:swp northEast:nep];
  return [YMKGeometry geometryWithBoundingBox:box];
}

- (YMKSearchOptions *)optionsFromDictionary:(nullable NSDictionary *)options {
  YMKSearchOptions *opts = [[YMKSearchOptions alloc] init];
  NSNumber *searchType = options[@"searchType"];
  opts.searchTypes = searchType != nil ? searchType.intValue : (int)YMKSearchTypeGeo;
  NSNumber *resultPageSize = options[@"resultPageSize"];
  if (resultPageSize != nil) opts.resultPageSize = resultPageSize;
  NSNumber *disable = options[@"disableSpellingCorrection"];
  if (disable.boolValue) opts.disableSpellingCorrection = YES;
  NSDictionary *userPos = options[@"userPosition"];
  if ([userPos isKindOfClass:NSDictionary.class] &&
      userPos[@"lat"] != nil && userPos[@"lon"] != nil) {
    opts.userPosition = [YMKPoint pointWithLatitude:[userPos[@"lat"] doubleValue]
                                          longitude:[userPos[@"lon"] doubleValue]];
  }
  return opts;
}

+ (NSArray<NSDictionary *> *)hitsFromResponse:(nullable YMKSearchResponse *)response {
  if (response == nil) return @[];
  NSMutableArray *out = [NSMutableArray array];
  for (YMKGeoObjectCollectionItem *item in response.collection.children) {
    YMKGeoObject *obj = item.obj;
    if (obj == nil) continue;
    YMKPoint *point = [self pickPointFromObject:obj];
    if (point == nil) continue;
    NSString *uri = [self pickUriFromObject:obj] ?: @"";
    [out addObject:@{
      @"title": obj.name ?: @"",
      @"subtitle": obj.descriptionText ?: @"",
      @"uri": uri,
      @"point": @{@"lat": @(point.latitude), @"lon": @(point.longitude)},
    }];
  }
  return out;
}

+ (nullable YMKPoint *)pickPointFromObject:(YMKGeoObject *)obj {
  YMKSearchToponymObjectMetadata *toponym =
    (YMKSearchToponymObjectMetadata *)[obj.metadataContainer
      getItemOfClass:YMKSearchToponymObjectMetadata.class];
  if (toponym != nil) return toponym.balloonPoint;
  for (YMKGeometry *g in obj.geometry) {
    if (g.point != nil) return g.point;
    if (g.boundingBox != nil) {
      YMKPoint *sw = g.boundingBox.southWest;
      YMKPoint *ne = g.boundingBox.northEast;
      return [YMKPoint pointWithLatitude:(sw.latitude + ne.latitude) / 2.0
                                longitude:(sw.longitude + ne.longitude) / 2.0];
    }
  }
  return nil;
}

+ (nullable NSString *)pickUriFromObject:(YMKGeoObject *)obj {
  YMKUriObjectMetadata *uriMeta =
    (YMKUriObjectMetadata *)[obj.metadataContainer
      getItemOfClass:YMKUriObjectMetadata.class];
  if (uriMeta == nil || uriMeta.uris.count == 0) return nil;
  return uriMeta.uris.firstObject.value;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeYandexSearchModuleSpecJSI>(params);
}

@end
