#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

@class YMKMap;

NS_ASSUME_NONNULL_BEGIN

@interface YandexMapMarker : RCTViewComponentView

/// Called by the parent YandexMapView on mountChildComponentView. The marker
/// creates its YMKPlacemarkMapObject inside the supplied map and applies the
/// current props (point, icon, anchor, etc).
- (void)attachToMap:(YMKMap *)map;

/// Called by the parent YandexMapView on unmountChildComponentView. Removes
/// the placemark from the map.
- (void)detachFromMap;

@end

NS_ASSUME_NONNULL_END
