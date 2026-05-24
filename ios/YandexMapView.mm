#import "YandexMapView.h"
#import "YandexMapModule.h"
#import "YandexMapMarker.h"
#import "YandexMapPolyline.h"
#import "YandexMapPolygon.h"
#import "YandexMapCircle.h"
#import "YandexMapClusteredMarkers.h"

#import <React/RCTConversions.h>

#import <react/renderer/components/YandexMapViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/YandexMapViewSpec/EventEmitters.h>
#import <react/renderer/components/YandexMapViewSpec/Props.h>
#import <react/renderer/components/YandexMapViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#import <YandexMapsMobile/YMKMapKitFactory.h>
#import <YandexMapsMobile/YMKMapView.h>
#import <YandexMapsMobile/YMKMap.h>
#import <YandexMapsMobile/YMKMapWindow.h>
#import <YandexMapsMobile/YMKCameraPosition.h>
#import <YandexMapsMobile/YMKPoint.h>
#import <YandexMapsMobile/YMKMapInputListener.h>
#import <YandexMapsMobile/YMKMapCameraListener.h>
#import <YandexMapsMobile/YMKMapLoadedListener.h>
#import <YandexMapsMobile/YMKMapLoadStatistics.h>
#import <YandexMapsMobile/YMKCameraUpdateReason.h>
#import <YandexMapsMobile/YMKAnimation.h>
#import <YandexMapsMobile/YMKGeometry.h>
#import <YandexMapsMobile/YMKUserLocation.h>

using namespace facebook::react;

@interface YandexMapView () <RCTYandexMapViewViewProtocol, YMKMapInputListener, YMKMapCameraListener, YMKMapLoadedListener>
@end

@implementation YandexMapView {
  YMKMapView * _mapView;
  BOOL _didApplyInitialRegion;
  BOOL _listenersRegistered;
  YMKUserLocationLayer * _userLocationLayer;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<YandexMapViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const YandexMapViewProps>();
    _props = defaultProps;

    // Lazy native-side init from Info.plist (YandexMapKitApiKey). Safe to call
    // multiple times: JS YandexMap.init() takes precedence if it ran first.
    [YandexMapModule ensureMapKitStartedFromInfoPlist];

    _mapView = [[YMKMapView alloc] initWithFrame:self.bounds];
    _mapView.translatesAutoresizingMaskIntoConstraints = YES;
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.contentView = _mapView;

    [self registerMapListeners];
  }
  return self;
}

- (void)registerMapListeners {
  if (_listenersRegistered) return;
  YMKMap *map = _mapView.mapWindow.map;
  [map addInputListenerWithInputListener:self];
  [map addCameraListenerWithCameraListener:self];
  [map setMapLoadedListenerWithMapLoadedListener:self];
  _listenersRegistered = YES;
}

- (void)unregisterMapListeners {
  if (!_listenersRegistered) return;
  YMKMap *map = _mapView.mapWindow.map;
  [map removeInputListenerWithInputListener:self];
  [map removeCameraListenerWithCameraListener:self];
  [map setMapLoadedListenerWithMapLoadedListener:nil];
  _listenersRegistered = NO;
}

- (void)prepareForRecycle {
  [self unregisterMapListeners];
  _didApplyInitialRegion = NO;
  [super prepareForRecycle];
  [self registerMapListeners];
}

- (void)dealloc {
  [self unregisterMapListeners];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &oldVP = *std::static_pointer_cast<YandexMapViewProps const>(_props);
  const auto &newVP = *std::static_pointer_cast<YandexMapViewProps const>(props);

  if (!_didApplyInitialRegion) {
    const auto &r = newVP.initialRegion;
    BOOL hasRegion = (r.lat != 0.0 || r.lon != 0.0 || r.zoom != 0.0);
    if (hasRegion) {
      YMKPoint *target = [YMKPoint pointWithLatitude:r.lat longitude:r.lon];
      float zoom = r.zoom != 0.0 ? (float)r.zoom : 10.0f;
      YMKCameraPosition *pos =
        [YMKCameraPosition cameraPositionWithTarget:target
                                                zoom:zoom
                                             azimuth:(float)r.azimuth
                                                tilt:(float)r.tilt];
      [_mapView.mapWindow.map moveWithCameraPosition:pos];
      _didApplyInitialRegion = YES;
    }
  }

  if (oldVP.showUserPosition != newVP.showUserPosition) {
    [self applyShowUserPosition:newVP.showUserPosition];
  }
  if (oldVP.nightMode != newVP.nightMode) {
    _mapView.mapWindow.map.nightModeEnabled = newVP.nightMode;
  }
  if (oldVP.scrollGesturesEnabled != newVP.scrollGesturesEnabled) {
    _mapView.mapWindow.map.scrollGesturesEnabled = newVP.scrollGesturesEnabled;
  }
  if (oldVP.zoomGesturesEnabled != newVP.zoomGesturesEnabled) {
    _mapView.mapWindow.map.zoomGesturesEnabled = newVP.zoomGesturesEnabled;
  }
  if (oldVP.tiltGesturesEnabled != newVP.tiltGesturesEnabled) {
    _mapView.mapWindow.map.tiltGesturesEnabled = newVP.tiltGesturesEnabled;
  }
  if (oldVP.rotateGesturesEnabled != newVP.rotateGesturesEnabled) {
    _mapView.mapWindow.map.rotateGesturesEnabled = newVP.rotateGesturesEnabled;
  }
  if (oldVP.fastTapEnabled != newVP.fastTapEnabled) {
    _mapView.mapWindow.map.fastTapEnabled = newVP.fastTapEnabled;
  }
  if (oldVP.mapStyle != newVP.mapStyle && !newVP.mapStyle.empty()) {
    NSString *style = RCTNSStringFromString(newVP.mapStyle);
    [_mapView.mapWindow.map setMapStyleWithStyle:style];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)applyShowUserPosition:(BOOL)show {
  if (show) {
    if (_userLocationLayer == nil) {
      _userLocationLayer =
        [[YMKMapKit sharedInstance] createUserLocationLayerWithMapWindow:_mapView.mapWindow];
    }
    [_userLocationLayer setVisibleWithOn:YES];
  } else if (_userLocationLayer != nil) {
    [_userLocationLayer setVisibleWithOn:NO];
  }
}

#pragma mark - Fabric children

- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView
                          index:(NSInteger)index {
  YMKMap *map = _mapView.mapWindow.map;
  if ([childComponentView isKindOfClass:[YandexMapMarker class]]) {
    // Mount as actual subview too so its React children get a layout pass —
    // the Marker view stays hidden and we snapshot its layer into a bitmap.
    [super mountChildComponentView:childComponentView index:index];
    [(YandexMapMarker *)childComponentView attachToMap:map];
    return;
  }
  if ([childComponentView isKindOfClass:[YandexMapPolyline class]]) {
    [(YandexMapPolyline *)childComponentView attachToMap:map];
    return;
  }
  if ([childComponentView isKindOfClass:[YandexMapPolygon class]]) {
    [(YandexMapPolygon *)childComponentView attachToMap:map];
    return;
  }
  if ([childComponentView isKindOfClass:[YandexMapCircle class]]) {
    [(YandexMapCircle *)childComponentView attachToMap:map];
    return;
  }
  if ([childComponentView isKindOfClass:[YandexMapClusteredMarkers class]]) {
    [(YandexMapClusteredMarkers *)childComponentView attachToMap:map];
    return;
  }
  [super mountChildComponentView:childComponentView index:index];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView
                            index:(NSInteger)index {
  if ([childComponentView isKindOfClass:[YandexMapMarker class]]) {
    [(YandexMapMarker *)childComponentView detachFromMap];
    [super unmountChildComponentView:childComponentView index:index];
    return;
  }
  if ([childComponentView isKindOfClass:[YandexMapPolyline class]]) {
    [(YandexMapPolyline *)childComponentView detachFromMap];
    return;
  }
  if ([childComponentView isKindOfClass:[YandexMapPolygon class]]) {
    [(YandexMapPolygon *)childComponentView detachFromMap];
    return;
  }
  if ([childComponentView isKindOfClass:[YandexMapCircle class]]) {
    [(YandexMapCircle *)childComponentView detachFromMap];
    return;
  }
  if ([childComponentView isKindOfClass:[YandexMapClusteredMarkers class]]) {
    [(YandexMapClusteredMarkers *)childComponentView detachFromMap];
    return;
  }
  [super unmountChildComponentView:childComponentView index:index];
}

#pragma mark - Commands

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  RCTYandexMapViewHandleCommand(self, commandName, args);
}

- (void)setCenter:(double)lat
              lon:(double)lon
             zoom:(float)zoom
          azimuth:(float)azimuth
             tilt:(float)tilt
         duration:(float)duration
         animated:(BOOL)animated {
  YMKMap *map = _mapView.mapWindow.map;
  YMKPoint *target = [YMKPoint pointWithLatitude:lat longitude:lon];
  float resolvedZoom = zoom > 0 ? zoom : map.cameraPosition.zoom;
  YMKCameraPosition *pos =
    [YMKCameraPosition cameraPositionWithTarget:target
                                            zoom:resolvedZoom
                                         azimuth:azimuth
                                            tilt:tilt];
  if (animated) {
    YMKAnimation *anim = [YMKAnimation animationWithType:YMKAnimationTypeSmooth
                                                duration:duration];
    [map moveWithCameraPosition:pos animation:anim cameraCallback:nil];
  } else {
    [map moveWithCameraPosition:pos];
  }
}

- (void)setZoom:(float)zoom duration:(float)duration animated:(BOOL)animated {
  YMKMap *map = _mapView.mapWindow.map;
  YMKCameraPosition *current = map.cameraPosition;
  YMKCameraPosition *pos =
    [YMKCameraPosition cameraPositionWithTarget:current.target
                                            zoom:zoom
                                         azimuth:current.azimuth
                                            tilt:current.tilt];
  if (animated) {
    YMKAnimation *anim = [YMKAnimation animationWithType:YMKAnimationTypeSmooth
                                                duration:duration];
    [map moveWithCameraPosition:pos animation:anim cameraCallback:nil];
  } else {
    [map moveWithCameraPosition:pos];
  }
}

- (void)fitBoundingBox:(double)swLat
                 swLon:(double)swLon
                 neLat:(double)neLat
                 neLon:(double)neLon {
  YMKMap *map = _mapView.mapWindow.map;
  YMKPoint *sw = [YMKPoint pointWithLatitude:swLat longitude:swLon];
  YMKPoint *ne = [YMKPoint pointWithLatitude:neLat longitude:neLon];
  YMKBoundingBox *box = [YMKBoundingBox boundingBoxWithSouthWest:sw northEast:ne];
  YMKGeometry *geometry = [YMKGeometry geometryWithBoundingBox:box];
  YMKCameraPosition *pos = [map cameraPositionWithGeometry:geometry];
  [map moveWithCameraPosition:pos];
}

- (void)setTrafficVisible:(BOOL)visible {
  // Traffic layer access in 4.36-full requires YMKTrafficLayer which is fetched
  // via [YMKMapKit createTrafficLayerWithMapWindow:]. Phase 1: deferred.
}

#pragma mark - YMKMapInputListener

- (void)onMapTapWithMap:(YMKMap *)map point:(YMKPoint *)point {
  if (_eventEmitter == nullptr) return;
  auto emitter = std::static_pointer_cast<const YandexMapViewEventEmitter>(_eventEmitter);
  emitter->onMapPress({.lat = point.latitude, .lon = point.longitude});
}

- (void)onMapLongTapWithMap:(YMKMap *)map point:(YMKPoint *)point {
  if (_eventEmitter == nullptr) return;
  auto emitter = std::static_pointer_cast<const YandexMapViewEventEmitter>(_eventEmitter);
  emitter->onMapLongPress({.lat = point.latitude, .lon = point.longitude});
}

#pragma mark - YMKMapCameraListener

- (void)onCameraPositionChangedWithMap:(YMKMap *)map
                        cameraPosition:(YMKCameraPosition *)cameraPosition
                    cameraUpdateReason:(YMKCameraUpdateReason)cameraUpdateReason
                              finished:(BOOL)finished {
  if (_eventEmitter == nullptr) return;
  auto emitter = std::static_pointer_cast<const YandexMapViewEventEmitter>(_eventEmitter);
  std::string reason = cameraUpdateReason == YMKCameraUpdateReasonGestures
                         ? std::string("GESTURES")
                         : std::string("APPLICATION");
  if (finished) {
    emitter->onCameraPositionChangeEnd({
      .zoom = cameraPosition.zoom,
      .tilt = cameraPosition.tilt,
      .azimuth = cameraPosition.azimuth,
      .lat = cameraPosition.target.latitude,
      .lon = cameraPosition.target.longitude,
      .reason = reason,
      .finished = static_cast<bool>(finished),
    });
  } else {
    emitter->onCameraPositionChange({
      .zoom = cameraPosition.zoom,
      .tilt = cameraPosition.tilt,
      .azimuth = cameraPosition.azimuth,
      .lat = cameraPosition.target.latitude,
      .lon = cameraPosition.target.longitude,
      .reason = reason,
      .finished = static_cast<bool>(finished),
    });
  }
}

#pragma mark - YMKMapLoadedListener

- (void)onMapLoadedWithStatistics:(YMKMapLoadStatistics *)statistics {
  if (_eventEmitter == nullptr) return;
  auto emitter = std::static_pointer_cast<const YandexMapViewEventEmitter>(_eventEmitter);
  emitter->onMapLoaded({
    .renderObjectCount = (double)statistics.renderObjectCount,
    .curZoomModelsLoaded = (double)statistics.curZoomModelsLoaded,
    .curZoomPlacemarksLoaded = (double)statistics.curZoomPlacemarksLoaded,
    .curZoomLabelsLoaded = (double)statistics.curZoomLabelsLoaded,
    .curZoomGeometryLoaded = (double)statistics.curZoomGeometryLoaded,
    .tileMemoryUsage = (double)statistics.tileMemoryUsage,
    .delayedGeometryLoaded = (double)statistics.delayedGeometryLoaded,
    .fullyAppeared = (double)statistics.fullyAppeared,
    .fullyLoaded = (double)statistics.fullyLoaded,
  });
}

@end

Class<RCTComponentViewProtocol> YandexMapViewCls(void) {
  return YandexMapView.class;
}
