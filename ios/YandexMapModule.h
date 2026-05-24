#import <Foundation/Foundation.h>
#import <YandexMapViewSpec/YandexMapViewSpec.h>

NS_ASSUME_NONNULL_BEGIN

@interface YandexMapModule : NSObject <NativeYandexMapModuleSpec>

+ (BOOL)isMapKitInitialized;
+ (void)ensureMapKitStartedFromInfoPlist;

@end

NS_ASSUME_NONNULL_END
