#import "YandexMapPolyline.h"

#import <React/RCTConversions.h>
#import <react/renderer/components/YandexMapViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/YandexMapViewSpec/EventEmitters.h>
#import <react/renderer/components/YandexMapViewSpec/Props.h>
#import <react/renderer/components/YandexMapViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#import <YandexMapsMobile/YMKMap.h>
#import <YandexMapsMobile/YMKMapObject.h>
#import <YandexMapsMobile/YMKMapObjectCollection.h>
#import <YandexMapsMobile/YMKPolyline.h>
#import <YandexMapsMobile/YMKPoint.h>
#import <YandexMapsMobile/YMKMapObjectTapListener.h>

using namespace facebook::react;

@interface YandexMapPolyline () <RCTYandexMapPolylineViewProtocol, YMKMapObjectTapListener>
@end

@implementation YandexMapPolyline {
  __weak YMKMap *_map;
  YMKPolylineMapObject *_polyline;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<YandexMapPolylineComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const YandexMapPolylineProps>();
    _props = defaultProps;
    self.hidden = YES;
  }
  return self;
}

- (void)attachToMap:(YMKMap *)map {
  if (_polyline != nil) return;
  _map = map;
  const auto &p = *std::static_pointer_cast<YandexMapPolylineProps const>(_props);
  YMKPolyline *geom = [self polylineFromProps:p];
  if (geom.points.count < 2) return;
  _polyline = [map.mapObjects addPolylineWithPolyline:geom];
  [self applyVisualProps:p];
  [_polyline addTapListenerWithTapListener:self];
}

- (void)detachFromMap {
  if (_polyline == nil) return;
  [_polyline removeTapListenerWithTapListener:self];
  YMKMap *map = _map;
  if (map != nil) {
    [map.mapObjects removeWithMapObject:_polyline];
  }
  _polyline = nil;
  _map = nil;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &newP = *std::static_pointer_cast<YandexMapPolylineProps const>(props);
  if (_polyline != nil) {
    YMKPolyline *geom = [self polylineFromProps:newP];
    if (geom.points.count >= 2) {
      [_polyline setGeometry:geom];
    }
    [self applyVisualProps:newP];
  }
  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle {
  [self detachFromMap];
  [super prepareForRecycle];
}

- (YMKPolyline *)polylineFromProps:(const YandexMapPolylineProps &)p {
  NSMutableArray<YMKPoint *> *pts = [NSMutableArray arrayWithCapacity:p.points.size()];
  for (const auto &pt : p.points) {
    [pts addObject:[YMKPoint pointWithLatitude:pt.lat longitude:pt.lon]];
  }
  return [YMKPolyline polylineWithPoints:pts];
}

- (void)applyVisualProps:(const YandexMapPolylineProps &)p {
  if (_polyline == nil) return;
  UIColor *stroke = RCTUIColorFromSharedColor(p.strokeColor);
  if (stroke != nil) [_polyline setStrokeColorWithColor:stroke];
  if (p.strokeWidth > 0) _polyline.strokeWidth = p.strokeWidth;
  _polyline.zIndex = p.placemarkZIndex;
}

- (BOOL)onMapObjectTapWithMapObject:(YMKMapObject *)mapObject point:(YMKPoint *)point {
  if (_eventEmitter != nullptr) {
    auto emitter = std::static_pointer_cast<const YandexMapPolylineEventEmitter>(_eventEmitter);
    emitter->onPolylinePress({});
  }
  return YES;
}

@end

Class<RCTComponentViewProtocol> YandexMapPolylineCls(void) {
  return YandexMapPolyline.class;
}
