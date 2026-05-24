#import "YandexMapClusteredMarkers.h"

#import <React/RCTConversions.h>
#import <react/renderer/components/YandexMapViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/YandexMapViewSpec/EventEmitters.h>
#import <react/renderer/components/YandexMapViewSpec/Props.h>
#import <react/renderer/components/YandexMapViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

#import <YandexMapsMobile/YMKMap.h>
#import <YandexMapsMobile/YMKMapObject.h>
#import <YandexMapsMobile/YMKMapObjectCollection.h>
#import <YandexMapsMobile/YMKClusterizedPlacemarkCollection.h>
#import <YandexMapsMobile/YMKClusterListener.h>
#import <YandexMapsMobile/YMKCluster.h>
#import <YandexMapsMobile/YMKClusterTapListener.h>
#import <YandexMapsMobile/YMKPlacemark.h>
#import <YandexMapsMobile/YMKIconStyle.h>
#import <YandexMapsMobile/YMKPoint.h>

using namespace facebook::react;

@interface YandexMapClusteredMarkers () <
  RCTYandexMapClusteredMarkersViewProtocol,
  YMKClusterListener,
  YMKClusterTapListener
>
@end

@implementation YandexMapClusteredMarkers {
  __weak YMKMap *_map;
  YMKClusterizedPlacemarkCollection *_collection;
  UIImage *_markerImage;
  NSString *_currentMarkerUri;
  NSMutableDictionary<NSString *, UIImage *> *_labelIconCache;
  // nil → use count-based palette; non-nil → user-supplied override.
  UIColor *_clusterColorOverride;
  UIColor *_clusterTextColorOverride;
  float _clusterRadius;
  float _clusterMinZoom;
  BOOL _scheduledRebuild;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<YandexMapClusteredMarkersComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const YandexMapClusteredMarkersProps>();
    _props = defaultProps;
    _clusterRadius = 60.0f;
    _clusterMinZoom = 15.0f;
    _labelIconCache = [NSMutableDictionary dictionary];
    self.hidden = YES;
  }
  return self;
}

- (void)attachToMap:(YMKMap *)map {
  if (_collection != nil) return;
  _map = map;
  _collection = [map.mapObjects addClusterizedPlacemarkCollectionWithClusterListener:self];
  [self rebuildPlacemarks];
}

- (void)detachFromMap {
  if (_collection == nil) return;
  YMKMap *map = _map;
  if (map != nil) {
    [map.mapObjects removeWithMapObject:_collection];
  }
  _collection = nil;
  _map = nil;
  _markerImage = nil;
  _currentMarkerUri = nil;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &oldP = *std::static_pointer_cast<YandexMapClusteredMarkersProps const>(_props);
  const auto &newP = *std::static_pointer_cast<YandexMapClusteredMarkersProps const>(props);

  _clusterColorOverride = RCTUIColorFromSharedColor(newP.clusterColor);
  _clusterTextColorOverride = RCTUIColorFromSharedColor(newP.clusterTextColor);
  if (newP.clusterRadius > 0) _clusterRadius = newP.clusterRadius;
  if (newP.clusterMinZoom > 0) _clusterMinZoom = newP.clusterMinZoom;

  BOOL pointsChanged = (oldP.points.size() != newP.points.size());
  if (!pointsChanged) {
    for (size_t i = 0; i < newP.points.size(); i++) {
      if (oldP.points[i].lat != newP.points[i].lat || oldP.points[i].lon != newP.points[i].lon) {
        pointsChanged = YES;
        break;
      }
    }
  }

  BOOL labelsChanged = (oldP.pointLabels.size() != newP.pointLabels.size());
  if (!labelsChanged) {
    for (size_t i = 0; i < newP.pointLabels.size(); i++) {
      if (oldP.pointLabels[i] != newP.pointLabels[i]) {
        labelsChanged = YES;
        break;
      }
    }
  }

  BOOL iconChanged = (oldP.markerIconUri != newP.markerIconUri);
  if (iconChanged) {
    _markerImage = nil;
    _currentMarkerUri = nil;
  }

  BOOL clusteringChanged = (oldP.clusterRadius != newP.clusterRadius ||
                            oldP.clusterMinZoom != newP.clusterMinZoom);

  if (_collection != nil &&
      (pointsChanged || labelsChanged || iconChanged || clusteringChanged)) {
    [self scheduleRebuild];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle {
  [self detachFromMap];
  [super prepareForRecycle];
}

#pragma mark - Build

- (void)scheduleRebuild {
  if (_scheduledRebuild) return;
  _scheduledRebuild = YES;
  dispatch_async(dispatch_get_main_queue(), ^{
    self->_scheduledRebuild = NO;
    [self rebuildPlacemarks];
  });
}

- (void)rebuildPlacemarks {
  if (_collection == nil) return;
  [_collection clear];

  const auto &p = *std::static_pointer_cast<YandexMapClusteredMarkersProps const>(_props);
  NSString *uri = p.markerIconUri.empty() ? nil : [NSString stringWithUTF8String:p.markerIconUri.c_str()];

  // Snapshot labels into a strong-referenced NSArray to keep them alive in
  // the async block (props can change before the URI loader fires).
  NSMutableArray<NSString *> *labels = [NSMutableArray arrayWithCapacity:p.pointLabels.size()];
  for (const auto &l : p.pointLabels) {
    [labels addObject:[NSString stringWithUTF8String:l.c_str()]];
  }
  size_t pointCount = p.points.size();

  void (^addPoints)(UIImage *) = ^(UIImage *image) {
    if (self->_collection == nil) return;
    if (image != nil) self->_markerImage = image;

    BOOL hasLabels = labels.count == pointCount && pointCount > 0;
    NSMutableArray<YMKPoint *> *pts = [NSMutableArray arrayWithCapacity:pointCount];
    for (const auto &pt : p.points) {
      [pts addObject:[YMKPoint pointWithLatitude:pt.lat longitude:pt.lon]];
    }

    if (hasLabels) {
      // Per-placemark icon — render a pill bitmap for each label (cached by
      // label string) and add one placemark at a time. For 110 placemarks
      // with ~25 unique labels this stays under 1ms total.
      NSUInteger i = 0;
      for (YMKPoint *pp in pts) {
        NSString *label = labels[i++];
        UIImage *icon = [self pillIconForLabel:label];
        YMKPlacemarkMapObject *pl = [self->_collection addPlacemarkWithPoint:pp];
        [pl setIconWithImage:icon];
      }
    } else if (self->_markerImage != nil) {
      [self->_collection addPlacemarksWithPoints:pts image:self->_markerImage style:[YMKIconStyle new]];
    } else {
      [self->_collection addPlacemarksWithPoints:pts image:[self defaultDotIcon] style:[YMKIconStyle new]];
    }
    [self->_collection clusterPlacemarksWithClusterRadius:self->_clusterRadius
                                                   minZoom:(NSUInteger)self->_clusterMinZoom];
  };

  if (_markerImage != nil || uri == nil) {
    addPoints(nil);
    return;
  }
  _currentMarkerUri = uri;
  [self loadImageFromUri:uri completion:^(UIImage *image) {
    if (![uri isEqualToString:self->_currentMarkerUri]) return;
    addPoints(image);
  }];
}

- (void)loadImageFromUri:(NSString *)uri completion:(void (^)(UIImage *))completion {
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

#pragma mark - Cluster icon drawing

// Count-aware cluster icon: bigger + warmer color for denser clusters,
// rendered on a transparent canvas with shadow + white ring for contrast on
// satellite/dark map themes.
- (UIImage *)renderClusterIconForSize:(NSUInteger)size {
  CGFloat diameter;
  UIColor *fillColor;
  if (size < 8) {
    diameter = 44; fillColor = [UIColor colorWithRed:0.22 green:0.74 blue:0.43 alpha:1]; // green
  } else if (size < 20) {
    diameter = 52; fillColor = [UIColor colorWithRed:0.15 green:0.39 blue:0.92 alpha:1]; // blue
  } else if (size < 40) {
    diameter = 62; fillColor = [UIColor colorWithRed:0.96 green:0.55 blue:0.10 alpha:1]; // orange
  } else {
    diameter = 72; fillColor = [UIColor colorWithRed:0.91 green:0.30 blue:0.24 alpha:1]; // red
  }
  // User-supplied `clusterColor` overrides the count-based palette but keeps
  // the count-based size so denser clusters still read larger.
  if (_clusterColorOverride != nil) fillColor = _clusterColorOverride;
  UIColor *textColor = _clusterTextColorOverride ?: [UIColor whiteColor];

  CGFloat shadow = 6.0;
  CGFloat canvas = diameter + shadow * 2;
  UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
  fmt.opaque = NO;
  UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(canvas, canvas) format:fmt];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef c = ctx.CGContext;
    CGRect circleRect = CGRectMake(shadow, shadow, diameter, diameter);

    // Soft drop shadow underneath the circle.
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c,
                                CGSizeMake(0, 2),
                                shadow,
                                [UIColor colorWithWhite:0 alpha:0.35].CGColor);
    CGContextSetFillColorWithColor(c, fillColor.CGColor);
    CGContextFillEllipseInRect(c, circleRect);
    CGContextRestoreGState(c);

    // White ring on top for separation from map content.
    CGContextSetStrokeColorWithColor(c, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(c, 3.0);
    CGContextStrokeEllipseInRect(c, CGRectInset(circleRect, 1.5, 1.5));

    NSString *text = [NSString stringWithFormat:@"%lu", (unsigned long)size];
    UIFont *font = [UIFont systemFontOfSize:diameter * 0.34 weight:UIFontWeightBold];
    NSDictionary *attrs = @{
      NSFontAttributeName: font,
      NSForegroundColorAttributeName: textColor,
    };
    CGSize textSize = [text sizeWithAttributes:attrs];
    CGRect textRect = CGRectMake(circleRect.origin.x + (diameter - textSize.width) / 2.0,
                                  circleRect.origin.y + (diameter - textSize.height) / 2.0,
                                  textSize.width,
                                  textSize.height);
    [text drawInRect:textRect withAttributes:attrs];
  }];
}

// Width-aware pill icon for a specific label string. Cached per label so
// repeated values share a single bitmap. Empty label → generic "PHOTO" pill.
- (UIImage *)pillIconForLabel:(NSString *)label {
  if (label.length == 0) return [self defaultDotIcon];
  UIImage *cached = _labelIconCache[label];
  if (cached != nil) return cached;
  UIImage *icon = [self renderPillIconWithLabel:label uppercase:NO];
  _labelIconCache[label] = icon;
  return icon;
}

// Generic blue "PHOTO" pill — used when no per-point label is supplied.
- (UIImage *)defaultDotIcon {
  static UIImage *cached;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    cached = [self renderPillIconWithLabel:@"PHOTO" uppercase:YES];
  });
  return cached;
}

// Renders the photo-pill bitmap with the given label text. `uppercase=YES`
// applies extra letter-spacing (looks right for short ALL-CAPS like "PHOTO");
// `NO` keeps text natural for human-readable labels like "Большой театр".
// Pill auto-sizes to fit label width up to ~180pt (truncates if longer).
- (UIImage *)renderPillIconWithLabel:(NSString *)label uppercase:(BOOL)uppercase {
  CGFloat height = 36;
  CGFloat shadow = 5;
  CGFloat iconWidth = 30; // camera glyph + padding
  CGFloat textPadding = 12; // right padding inside pill

  UIFont *font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
  NSDictionary *attrs = @{
    NSFontAttributeName: font,
    NSForegroundColorAttributeName: UIColor.whiteColor,
    NSKernAttributeName: uppercase ? @0.5 : @0.0,
  };
  CGSize textSize = [label sizeWithAttributes:attrs];
  CGFloat maxTextWidth = 140; // truncation budget
  CGFloat usedTextWidth = MIN(textSize.width, maxTextWidth);
  CGFloat width = iconWidth + usedTextWidth + textPadding;

  CGFloat canvasW = width + shadow * 2;
  CGFloat canvasH = height + shadow * 2;
  UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
  fmt.opaque = NO;
  UIGraphicsImageRenderer *r =
    [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(canvasW, canvasH) format:fmt];
  return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef c = ctx.CGContext;
    CGRect pill = CGRectMake(shadow, shadow, width, height);
    CGFloat radius = height / 2.0;

    UIColor *top = [UIColor colorWithRed:0.23 green:0.51 blue:0.96 alpha:1.0];
    UIColor *bottom = [UIColor colorWithRed:0.11 green:0.31 blue:0.85 alpha:1.0];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:pill cornerRadius:radius];

    // Drop shadow.
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c,
                                CGSizeMake(0, 2),
                                shadow,
                                [UIColor colorWithWhite:0 alpha:0.28].CGColor);
    [bottom setFill];
    [path fill];
    CGContextRestoreGState(c);

    // Vertical gradient fill clipped to pill.
    CGContextSaveGState(c);
    [path addClip];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)top.CGColor, (__bridge id)bottom.CGColor];
    CGFloat locations[] = {0.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace,
      (__bridge CFArrayRef)colors, locations);
    CGContextDrawLinearGradient(c, gradient,
      CGPointMake(CGRectGetMidX(pill), CGRectGetMinY(pill)),
      CGPointMake(CGRectGetMidX(pill), CGRectGetMaxY(pill)),
      0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(c);

    // White border.
    CGContextSetStrokeColorWithColor(c, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(c, 2.0);
    CGContextAddPath(c, path.CGPath);
    CGContextStrokePath(c);

    // Camera glyph on the left.
    CGPoint iconCenter = CGPointMake(CGRectGetMinX(pill) + 17, CGRectGetMidY(pill));
    CGContextSetStrokeColorWithColor(c, [UIColor whiteColor].CGColor);
    CGContextSetFillColorWithColor(c, [UIColor whiteColor].CGColor);
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineWidth(c, 1.7);
    UIBezierPath *camera = [UIBezierPath bezierPathWithRoundedRect:
      CGRectMake(iconCenter.x - 8, iconCenter.y - 5.5, 16, 12) cornerRadius:3];
    CGContextAddPath(c, camera.CGPath);
    CGContextStrokePath(c);
    CGContextFillEllipseInRect(c,
      CGRectMake(iconCenter.x - 3.2, iconCenter.y - 3.2, 6.4, 6.4));
    CGContextFillEllipseInRect(c,
      CGRectMake(iconCenter.x + 4.8, iconCenter.y - 3.6, 2.5, 2.5));

    // Label text, truncated to maxTextWidth.
    NSStringDrawingOptions opts = NSStringDrawingUsesLineFragmentOrigin |
                                  NSStringDrawingTruncatesLastVisibleLine;
    CGRect textRect = CGRectMake(CGRectGetMinX(pill) + iconWidth,
                                 CGRectGetMidY(pill) - textSize.height / 2.0,
                                 usedTextWidth,
                                 textSize.height);
    [label drawWithRect:textRect options:opts attributes:attrs context:nil];
  }];
}

// Built-in photo-pin marker — used when caller doesn't provide markerSource.
// Teardrop shape with a white camera glyph in the lens area. Cached on first
// use; recompute would be wasteful since the bitmap is identical for every
// placemark.
- (UIImage *)defaultPhotoPinIcon {
  static UIImage *cached;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    CGFloat width = 36, height = 46;
    CGFloat shadow = 5;
    CGFloat canvasW = width + shadow * 2, canvasH = height + shadow * 2;
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
    fmt.opaque = NO;
    UIGraphicsImageRenderer *r =
      [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(canvasW, canvasH) format:fmt];
    cached = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
      CGContextRef c = ctx.CGContext;
      UIColor *accent = [UIColor colorWithRed:0.15 green:0.39 blue:0.92 alpha:1];
      CGFloat radius = width / 2.0;
      CGPoint center = CGPointMake(shadow + radius, shadow + radius);

      // Teardrop path: circle on top + triangle pointing down.
      UIBezierPath *path = [UIBezierPath bezierPath];
      [path addArcWithCenter:center
                      radius:radius
                  startAngle:M_PI * 1.25
                    endAngle:M_PI * -0.25
                   clockwise:YES];
      [path addLineToPoint:CGPointMake(shadow + width / 2.0, shadow + height)];
      [path closePath];

      CGContextSaveGState(c);
      CGContextSetShadowWithColor(c,
                                  CGSizeMake(0, 2),
                                  shadow,
                                  [UIColor colorWithWhite:0 alpha:0.35].CGColor);
      [accent setFill];
      [path fill];
      CGContextRestoreGState(c);

      [[UIColor whiteColor] setStroke];
      path.lineWidth = 2.5;
      [path stroke];

      // Tiny camera glyph centred on the circle.
      CGRect bodyRect = CGRectMake(center.x - 9, center.y - 6, 18, 12);
      UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:bodyRect cornerRadius:2.5];
      [[UIColor whiteColor] setFill];
      [body fill];
      [accent setFill];
      UIBezierPath *lens = [UIBezierPath bezierPathWithOvalInRect:
        CGRectMake(center.x - 3, center.y - 3, 6, 6)];
      [lens fill];
    }];
  });
  return cached;
}

#pragma mark - YMKClusterListener

- (void)onClusterAddedWithCluster:(nonnull YMKCluster *)cluster {
  UIImage *icon = [self renderClusterIconForSize:cluster.size];
  [cluster.appearance setIconWithImage:icon];
  [cluster addClusterTapListenerWithClusterTapListener:self];
}

#pragma mark - YMKClusterTapListener

- (BOOL)onClusterTapWithCluster:(YMKCluster *)cluster {
  if (_eventEmitter == nullptr) return YES;
  auto emitter = std::static_pointer_cast<const YandexMapClusteredMarkersEventEmitter>(_eventEmitter);
  YMKPoint *p = cluster.appearance.geometry;

  // Compute bounding box from every placemark inside the cluster so JS can
  // fit the camera precisely to the cluster contents instead of guessing.
  double swLat = p.latitude, swLon = p.longitude;
  double neLat = p.latitude, neLon = p.longitude;
  for (YMKPlacemarkMapObject *pl in cluster.placemarks) {
    YMKPoint *g = pl.geometry;
    if (g.latitude < swLat) swLat = g.latitude;
    if (g.longitude < swLon) swLon = g.longitude;
    if (g.latitude > neLat) neLat = g.latitude;
    if (g.longitude > neLon) neLon = g.longitude;
  }

  emitter->onClusterPress({
    .size = (int)cluster.size,
    .lat = p.latitude,
    .lon = p.longitude,
    .swLat = swLat,
    .swLon = swLon,
    .neLat = neLat,
    .neLon = neLon,
  });
  return YES;
}

@end

Class<RCTComponentViewProtocol> YandexMapClusteredMarkersCls(void) {
  return YandexMapClusteredMarkers.class;
}
