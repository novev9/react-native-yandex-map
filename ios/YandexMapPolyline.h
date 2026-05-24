#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

@class YMKMap;

NS_ASSUME_NONNULL_BEGIN

@interface YandexMapPolyline : RCTViewComponentView
- (void)attachToMap:(YMKMap *)map;
- (void)detachFromMap;
@end

NS_ASSUME_NONNULL_END
