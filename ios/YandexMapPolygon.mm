#import "YandexMapPolygon.h"

#import <React/RCTConversions.h>
#import <react/renderer/components/YandexMapViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/YandexMapViewSpec/EventEmitters.h>
#import <react/renderer/components/YandexMapViewSpec/Props.h>
#import <react/renderer/components/YandexMapViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#import <YandexMapsMobile/YMKMap.h>
#import <YandexMapsMobile/YMKMapObject.h>
#import <YandexMapsMobile/YMKMapObjectCollection.h>
#import <YandexMapsMobile/YMKPolygon.h>
#import <YandexMapsMobile/YMKPoint.h>
#import <YandexMapsMobile/YMKMapObjectTapListener.h>

using namespace facebook::react;

@interface YandexMapPolygon () <RCTYandexMapPolygonViewProtocol, YMKMapObjectTapListener>
@end

@implementation YandexMapPolygon {
  __weak YMKMap *_map;
  YMKPolygonMapObject *_polygon;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<YandexMapPolygonComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const YandexMapPolygonProps>();
    _props = defaultProps;
    self.hidden = YES;
  }
  return self;
}

- (void)attachToMap:(YMKMap *)map {
  if (_polygon != nil) return;
  _map = map;
  const auto &p = *std::static_pointer_cast<YandexMapPolygonProps const>(_props);
  YMKPolygon *geom = [self polygonFromProps:p];
  if (geom == nil) return;
  _polygon = [map.mapObjects addPolygonWithPolygon:geom];
  [self applyVisualProps:p];
  [_polygon addTapListenerWithTapListener:self];
}

- (void)detachFromMap {
  if (_polygon == nil) return;
  [_polygon removeTapListenerWithTapListener:self];
  YMKMap *map = _map;
  if (map != nil) {
    [map.mapObjects removeWithMapObject:_polygon];
  }
  _polygon = nil;
  _map = nil;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &newP = *std::static_pointer_cast<YandexMapPolygonProps const>(props);
  if (_polygon != nil) {
    YMKPolygon *geom = [self polygonFromProps:newP];
    if (geom != nil) [_polygon setGeometry:geom];
    [self applyVisualProps:newP];
  }
  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle {
  [self detachFromMap];
  [super prepareForRecycle];
}

- (nullable YMKPolygon *)polygonFromProps:(const YandexMapPolygonProps &)p {
  if (p.points.size() < 3) return nil;
  NSMutableArray<YMKPoint *> *outerPoints = [NSMutableArray arrayWithCapacity:p.points.size()];
  for (const auto &pt : p.points) {
    [outerPoints addObject:[YMKPoint pointWithLatitude:pt.lat longitude:pt.lon]];
  }
  YMKLinearRing *outer = [YMKLinearRing linearRingWithPoints:outerPoints];
  return [YMKPolygon polygonWithOuterRing:outer innerRings:@[]];
}

- (void)applyVisualProps:(const YandexMapPolygonProps &)p {
  if (_polygon == nil) return;
  UIColor *fill = RCTUIColorFromSharedColor(p.fillColor);
  if (fill != nil) _polygon.fillColor = fill;
  UIColor *stroke = RCTUIColorFromSharedColor(p.strokeColor);
  if (stroke != nil) _polygon.strokeColor = stroke;
  if (p.strokeWidth > 0) _polygon.strokeWidth = p.strokeWidth;
  _polygon.zIndex = p.placemarkZIndex;
}

- (BOOL)onMapObjectTapWithMapObject:(YMKMapObject *)mapObject point:(YMKPoint *)point {
  if (_eventEmitter != nullptr) {
    auto emitter = std::static_pointer_cast<const YandexMapPolygonEventEmitter>(_eventEmitter);
    emitter->onPolygonPress({});
  }
  return YES;
}

@end

Class<RCTComponentViewProtocol> YandexMapPolygonCls(void) {
  return YandexMapPolygon.class;
}
