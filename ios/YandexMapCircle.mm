#import "YandexMapCircle.h"

#import <React/RCTConversions.h>
#import <react/renderer/components/YandexMapViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/YandexMapViewSpec/EventEmitters.h>
#import <react/renderer/components/YandexMapViewSpec/Props.h>
#import <react/renderer/components/YandexMapViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#import <YandexMapsMobile/YMKMap.h>
#import <YandexMapsMobile/YMKMapObject.h>
#import <YandexMapsMobile/YMKMapObjectCollection.h>
#import <YandexMapsMobile/YMKCircle.h>
#import <YandexMapsMobile/YMKPoint.h>
#import <YandexMapsMobile/YMKMapObjectTapListener.h>

using namespace facebook::react;

@interface YandexMapCircle () <RCTYandexMapCircleViewProtocol, YMKMapObjectTapListener>
@end

@implementation YandexMapCircle {
  __weak YMKMap *_map;
  YMKCircleMapObject *_circle;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<YandexMapCircleComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const YandexMapCircleProps>();
    _props = defaultProps;
    self.hidden = YES;
  }
  return self;
}

- (void)attachToMap:(YMKMap *)map {
  if (_circle != nil) return;
  _map = map;
  const auto &p = *std::static_pointer_cast<YandexMapCircleProps const>(_props);
  YMKCircle *geom = [self circleFromProps:p];
  if (geom == nil) return;
  _circle = [map.mapObjects addCircleWithCircle:geom];
  UIColor *stroke = RCTUIColorFromSharedColor(p.strokeColor) ?: [UIColor blackColor];
  UIColor *fill = RCTUIColorFromSharedColor(p.fillColor) ?: [UIColor clearColor];
  float strokeWidth = p.strokeWidth > 0 ? p.strokeWidth : 1.0f;
  _circle.strokeColor = stroke;
  _circle.fillColor = fill;
  _circle.strokeWidth = strokeWidth;
  _circle.zIndex = p.placemarkZIndex;
  [_circle addTapListenerWithTapListener:self];
}

- (void)detachFromMap {
  if (_circle == nil) return;
  [_circle removeTapListenerWithTapListener:self];
  YMKMap *map = _map;
  if (map != nil) {
    [map.mapObjects removeWithMapObject:_circle];
  }
  _circle = nil;
  _map = nil;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &newP = *std::static_pointer_cast<YandexMapCircleProps const>(props);
  if (_circle != nil) {
    YMKCircle *geom = [self circleFromProps:newP];
    if (geom != nil) [_circle setGeometry:geom];
    UIColor *fill = RCTUIColorFromSharedColor(newP.fillColor);
    if (fill != nil) _circle.fillColor = fill;
    UIColor *stroke = RCTUIColorFromSharedColor(newP.strokeColor);
    if (stroke != nil) _circle.strokeColor = stroke;
    if (newP.strokeWidth > 0) _circle.strokeWidth = newP.strokeWidth;
    _circle.zIndex = newP.placemarkZIndex;
  }
  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle {
  [self detachFromMap];
  [super prepareForRecycle];
}

- (nullable YMKCircle *)circleFromProps:(const YandexMapCircleProps &)p {
  if (p.radius <= 0) return nil;
  YMKPoint *center = [YMKPoint pointWithLatitude:p.center.lat longitude:p.center.lon];
  return [YMKCircle circleWithCenter:center radius:p.radius];
}

- (BOOL)onMapObjectTapWithMapObject:(YMKMapObject *)mapObject point:(YMKPoint *)point {
  if (_eventEmitter != nullptr) {
    auto emitter = std::static_pointer_cast<const YandexMapCircleEventEmitter>(_eventEmitter);
    emitter->onCirclePress({});
  }
  return YES;
}

@end

Class<RCTComponentViewProtocol> YandexMapCircleCls(void) {
  return YandexMapCircle.class;
}
