#import "YandexSuggestModule.h"
#import "YandexMapModule.h"

#import <YandexMapsMobile/YMKSearch.h>
#import <YandexMapsMobile/YMKSearchManager.h>
#import <YandexMapsMobile/YMKSearchSuggestSession.h>
#import <YandexMapsMobile/YMKSuggestResponse.h>
#import <YandexMapsMobile/YMKSuggestOptions.h>
#import <YandexMapsMobile/YMKGeometry.h>
#import <YandexMapsMobile/YMKPoint.h>

@implementation YandexSuggestModule {
  YMKSearchManager *_manager;
  YMKSearchSuggestSession *_session;
}

RCT_EXPORT_MODULE(YandexSuggestModule)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (YMKSearchManager *)manager {
  if (_manager == nil) {
    [YandexMapModule ensureMapKitStartedFromInfoPlist];
    _manager = [[YMKSearchFactory instance]
      createSearchManagerWithSearchManagerType:YMKSearchManagerTypeCombined];
  }
  return _manager;
}

- (YMKSearchSuggestSession *)session {
  if (_session == nil) _session = [[self manager] createSuggestSession];
  return _session;
}

- (void)suggest:(NSString *)query
       viewport:(NSDictionary *)viewport
        options:(nullable NSDictionary *)options
        resolve:(RCTPromiseResolveBlock)resolve
         reject:(RCTPromiseRejectBlock)reject {
  NSDictionary *sw = viewport[@"southWest"] ?: @{};
  NSDictionary *ne = viewport[@"northEast"] ?: @{};
  YMKPoint *swp = [YMKPoint pointWithLatitude:[sw[@"lat"] doubleValue]
                                     longitude:[sw[@"lon"] doubleValue]];
  YMKPoint *nep = [YMKPoint pointWithLatitude:[ne[@"lat"] doubleValue]
                                     longitude:[ne[@"lon"] doubleValue]];

  NSNumber *suggestTypes = options[@"suggestTypes"];
  int suggestTypesValue =
    suggestTypes != nil ? suggestTypes.intValue : (int)YMKSuggestTypeGeo;
  NSNumber *suggestWords = options[@"suggestWords"];
  BOOL suggestWordsValue = suggestWords.boolValue;
  NSNumber *strictBounds = options[@"strictBounds"];
  BOOL strictBoundsValue = strictBounds.boolValue;
  NSDictionary *userPos = options[@"userPosition"];
  YMKPoint *userPositionPoint = nil;
  if ([userPos isKindOfClass:NSDictionary.class] &&
      userPos[@"lat"] != nil && userPos[@"lon"] != nil) {
    userPositionPoint = [YMKPoint pointWithLatitude:[userPos[@"lat"] doubleValue]
                                          longitude:[userPos[@"lon"] doubleValue]];
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    YMKBoundingBox *box = [YMKBoundingBox boundingBoxWithSouthWest:swp northEast:nep];

    YMKSuggestOptions *opts = [[YMKSuggestOptions alloc] init];
    opts.suggestTypes = suggestTypesValue;
    if (suggestWordsValue) opts.suggestWords = YES;
    if (strictBoundsValue) opts.strictBounds = YES;
    if (userPositionPoint != nil) opts.userPosition = userPositionPoint;

    [[self session] suggestWithText:query
                             window:box
                     suggestOptions:opts
                    responseHandler:^(YMKSuggestResponse * _Nullable response,
                                      NSError * _Nullable error) {
      if (error != nil) {
        reject(@"YANDEX_SUGGEST_FAILED",
               error.localizedDescription ?: @"suggest failed",
               error);
        return;
      }
      NSArray<YMKSuggestItem *> *items = response.items ?: @[];
      NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.count];
      for (YMKSuggestItem *it in items) {
        [out addObject:@{
          @"title": it.title.text ?: @"",
          @"subtitle": it.subtitle.text ?: @"",
          @"uri": it.uri ?: @"",
        }];
      }
      resolve(out);
    }];
  });
}

- (void)reset:(RCTPromiseResolveBlock)resolve
       reject:(RCTPromiseRejectBlock)reject {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self->_session reset];
    resolve(nil);
  });
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeYandexSuggestModuleSpecJSI>(params);
}

@end
