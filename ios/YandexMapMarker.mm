#import "YandexMapMarker.h"

#import <react/renderer/components/YandexMapViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/YandexMapViewSpec/EventEmitters.h>
#import <react/renderer/components/YandexMapViewSpec/Props.h>
#import <react/renderer/components/YandexMapViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#import <React/RCTMountingTransactionObserving.h>
#import <YandexMapsMobile/YMKMap.h>
#import <YandexMapsMobile/YMKMapObject.h>
#import <YandexMapsMobile/YMKMapObjectCollection.h>
#import <YandexMapsMobile/YMKPlacemark.h>
#import <YandexMapsMobile/YMKIconStyle.h>
#import <YandexMapsMobile/YMKMapObjectTapListener.h>
#import <YandexMapsMobile/YMKPoint.h>

using namespace facebook::react;

@interface YandexMapMarker () <RCTYandexMapMarkerViewProtocol,
                               YMKMapObjectTapListener,
                               RCTMountingTransactionObserving>
@end

@implementation YandexMapMarker {
  __weak YMKMap *_map;
  YMKPlacemarkMapObject *_placemark;
  UIImage *_uriIcon;
  NSString *_currentIconUri;
  BOOL _snapshotPending;
  CGSize _lastSnapshotSize;
  BOOL _useSnapshotMode;
  NSInteger _snapshotRetryCount;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<YandexMapMarkerComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const YandexMapMarkerProps>();
    _props = defaultProps;
    // We need the host view drawable (NOT hidden / NOT alpha=0) so the snapshot
    // pipeline can actually composite its layer. To keep it visually invisible
    // we translate it far offscreen via CALayer transform — Fabric still sets
    // the Yoga-computed frame, but the transform moves what user sees away.
    self.userInteractionEnabled = NO;
    self.layer.transform = CATransform3DMakeTranslation(-100000, -100000, 0);
    _lastSnapshotSize = CGSizeZero;
  }
  return self;
}

#pragma mark - Lifecycle from parent map

- (void)attachToMap:(YMKMap *)map {
  if (_placemark != nil) {
    return;
  }
  _map = map;
  const auto &p = *std::static_pointer_cast<YandexMapMarkerProps const>(_props);
  YMKPoint *point = [YMKPoint pointWithLatitude:p.point.lat longitude:p.point.lon];
  _placemark = [map.mapObjects addPlacemarkWithPoint:point];
  [self applyVisualProps:p];
  [_placemark addTapListenerWithTapListener:self];
  if (_useSnapshotMode) {
    [self scheduleSnapshot];
  }
}

- (void)detachFromMap {
  if (_placemark == nil) {
    return;
  }
  [_placemark removeTapListenerWithTapListener:self];
  YMKMap *map = _map;
  if (map != nil) {
    [map.mapObjects removeWithMapObject:_placemark];
  }
  _placemark = nil;
  _map = nil;
  _uriIcon = nil;
  _currentIconUri = nil;
  _lastSnapshotSize = CGSizeZero;
}

#pragma mark - Fabric

- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView
                          index:(NSInteger)index {
  [super mountChildComponentView:childComponentView index:index];
  _useSnapshotMode = YES;
  [self scheduleSnapshot];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView
                            index:(NSInteger)index {
  [super unmountChildComponentView:childComponentView index:index];
  if (self.subviews.count == 0) {
    _useSnapshotMode = NO;
  }
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &oldP = *std::static_pointer_cast<YandexMapMarkerProps const>(_props);
  const auto &newP = *std::static_pointer_cast<YandexMapMarkerProps const>(props);

  if (_placemark != nil) {
    if (oldP.point.lat != newP.point.lat || oldP.point.lon != newP.point.lon) {
      YMKPoint *newPoint = [YMKPoint pointWithLatitude:newP.point.lat longitude:newP.point.lon];
      [_placemark setGeometry:newPoint];
    }
    [self applyVisualProps:newP];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  if (_useSnapshotMode &&
      !CGSizeEqualToSize(self.bounds.size, CGSizeZero) &&
      !CGSizeEqualToSize(self.bounds.size, _lastSnapshotSize)) {
    [self scheduleSnapshot];
  }
}

- (void)prepareForRecycle {
  [self detachFromMap];
  _useSnapshotMode = NO;
  [super prepareForRecycle];
}

#pragma mark - RCTMountingTransactionObserving

// Fabric doesn't call updateProps/layoutSubviews on a parent when a *descendant*
// re-renders (e.g. text inside <Text> changes but the bounds stay the same).
// We need to re-snapshot the marker bitmap on those cases, so we subscribe to
// the surface-wide mount transaction and check whether any mutation touched a
// node inside our React subtree.
- (void)mountingTransactionDidMount:(const MountingTransaction &)transaction
               withSurfaceTelemetry:(const SurfaceTelemetry &)surfaceTelemetry {
  if (!_useSnapshotMode || _placemark == nil || self.subviews.count == 0) {
    return;
  }
  if ([self mountingTransactionTouchesSnapshotSubtree:transaction]) {
    [self scheduleSnapshot];
  }
}

- (BOOL)mountingTransactionTouchesSnapshotSubtree:
    (const MountingTransaction &)transaction {
  NSMutableSet<NSNumber *> *descendantTags = [NSMutableSet set];
  [self collectReactSubviewTagsFromView:self intoSet:descendantTags];
  if (descendantTags.count == 0) {
    return NO;
  }

  for (const auto &mutation : transaction.getMutations()) {
    // Insert/Remove on a direct child uses parentTag == marker.tag. Nested
    // changes use a parentTag inside our subtree.
    if (mutation.parentTag == self.tag ||
        [descendantTags containsObject:@(mutation.parentTag)]) {
      return YES;
    }
    // Text/style Updates land as Update mutations on the paragraph/component
    // itself — marker doesn't get notified, but the changed tag is already
    // inside our subtree.
    NSNumber *oldTag = @(mutation.oldChildShadowView.tag);
    NSNumber *newTag = @(mutation.newChildShadowView.tag);
    if ([descendantTags containsObject:oldTag] ||
        [descendantTags containsObject:newTag]) {
      return YES;
    }
  }
  return NO;
}

- (void)collectReactSubviewTagsFromView:(UIView *)view
                                intoSet:(NSMutableSet<NSNumber *> *)tags {
  for (UIView *subview in view.subviews) {
    if (subview.tag != 0) {
      [tags addObject:@(subview.tag)];
    }
    [self collectReactSubviewTagsFromView:subview intoSet:tags];
  }
}

#pragma mark - Visual

- (void)applyVisualProps:(const YandexMapMarkerProps &)p {
  if (_placemark == nil) {
    return;
  }

  _placemark.visible = p.visible;
  _placemark.zIndex = p.placemarkZIndex;

  // Apply anchor + scale to whatever icon is currently set — keeps the
  // placemark style in sync with prop changes whether the icon was supplied
  // via `source` or rendered from React children (snapshot mode). JS wrapper
  // defaults match Yandex defaults (0.5, 0.5 anchor; 1.0 scale), so applying
  // always is safe.
  YMKIconStyle *style = [[YMKIconStyle alloc] init];
  style.anchor = [NSValue valueWithCGPoint:CGPointMake(p.anchor.x, p.anchor.y)];
  style.scale = @(p.scale > 0 ? p.scale : 1.0);
  [_placemark setIconStyleWithStyle:style];

  if (_useSnapshotMode) {
    // Children-driven icon — URI ignored when React content present.
    return;
  }

  NSString *iconUri = p.iconUri.empty() ? nil : [NSString stringWithUTF8String:p.iconUri.c_str()];
  if (iconUri == nil || [iconUri isEqualToString:_currentIconUri]) {
    return;
  }
  _currentIconUri = iconUri; // optimistic: prevents repeat fetches
  [self loadImageFromUriAsync:iconUri completion:^(UIImage *image) {
    if (![iconUri isEqualToString:self->_currentIconUri]) return;
    if (image == nil) {
      self->_currentIconUri = nil; // allow retry next prop change
      return;
    }
    self->_uriIcon = image;
    if (self->_placemark != nil && !self->_useSnapshotMode) {
      [self->_placemark setIconWithImage:image];
    }
  }];
}

- (void)loadImageFromUriAsync:(NSString *)uri completion:(void (^)(UIImage *))completion {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    UIImage *image = nil;
    if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
      NSURL *url = [NSURL URLWithString:uri];
      NSData *data = url != nil ? [NSData dataWithContentsOfURL:url] : nil;
      image = data != nil ? [UIImage imageWithData:data] : nil;
    } else if ([uri hasPrefix:@"file://"]) {
      NSURL *url = [NSURL URLWithString:uri];
      image = url != nil ? [UIImage imageWithContentsOfFile:url.path] : nil;
    } else {
      image = [UIImage imageNamed:uri];
    }
    dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
  });
}

#pragma mark - Snapshot pipeline

- (void)scheduleSnapshot {
  if (_snapshotPending) return;
  _snapshotPending = YES;
  dispatch_async(dispatch_get_main_queue(), ^{
    self->_snapshotPending = NO;
    [self captureSnapshotIfNeeded];
  });
}

- (void)captureSnapshotIfNeeded {
  if (!_useSnapshotMode || _placemark == nil) return;
  // Force layout in case children were just mounted and layout hasn't run yet.
  [self layoutIfNeeded];
  CGSize size = self.bounds.size;
  if (size.width <= 0 || size.height <= 0) {
    // Bounds still zero — try once more on the next runloop tick after Yoga.
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self->_useSnapshotMode && self->_placemark != nil &&
          self.bounds.size.width > 0 && self.bounds.size.height > 0) {
        [self captureSnapshotIfNeeded];
      }
    });
    return;
  }
  UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
  fmt.opaque = NO;
  fmt.scale = UIScreen.mainScreen.scale;
  UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];

  // Temporarily reset transform / hidden / alpha so UIKit's drawViewHierarchy
  // sees the view as if it were on-screen. Wrap in CATransaction with disabled
  // animations so the brief swap doesn't actually composite to the screen.
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  CATransform3D oldTransform = self.layer.transform;
  BOOL oldHidden = self.hidden;
  CGFloat oldAlpha = self.alpha;
  self.layer.transform = CATransform3DIdentity;
  self.hidden = NO;
  self.alpha = 1.0;
  [self setNeedsLayout];
  [self layoutIfNeeded];

  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    BOOL ok = [self drawViewHierarchyInRect:(CGRect){CGPointZero, size}
                          afterScreenUpdates:YES];
    if (!ok) {
      [self.layer renderInContext:ctx.CGContext];
    }
  }];

  self.layer.transform = oldTransform;
  self.hidden = oldHidden;
  self.alpha = oldAlpha;
  [CATransaction commit];

  if (image != nil && image.size.width > 0) {
    _lastSnapshotSize = size;
    [_placemark setIconWithImage:image];
  }
}

#pragma mark - YMKMapObjectTapListener

- (BOOL)onMapObjectTapWithMapObject:(nonnull YMKMapObject *)mapObject
                              point:(nonnull YMKPoint *)point {
  if (_eventEmitter != nullptr) {
    auto emitter = std::static_pointer_cast<const YandexMapMarkerEventEmitter>(_eventEmitter);
    emitter->onMarkerPress({});
  }
  return YES;
}

@end

Class<RCTComponentViewProtocol> YandexMapMarkerCls(void) {
  return YandexMapMarker.class;
}
