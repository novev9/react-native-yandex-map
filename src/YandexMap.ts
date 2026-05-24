import NativeYandexMapModule from './NativeYandexMapModule';

/**
 * Singleton entrypoint for non-view Yandex MapKit APIs (init, locale).
 *
 * Native side reads a default API key from Info.plist (`YandexMapKitApiKey`)
 * and AndroidManifest meta-data (`com.yandex.maps.ApiKey`) so this JS init
 * is only required to override that default or when no native default exists.
 */
export const YandexMap = {
  /**
   * Initialise MapKit with an API key. Safe to call once at app start; subsequent
   * calls with the same key are no-ops on iOS and rejected on Android (already-set).
   */
  init(apiKey: string): Promise<void> {
    return NativeYandexMapModule.init(apiKey);
  },
  setLocale(locale: string): Promise<void> {
    return NativeYandexMapModule.setLocale(locale);
  },
  resetLocale(): Promise<void> {
    return NativeYandexMapModule.resetLocale();
  },
  getLocale(): Promise<string> {
    return NativeYandexMapModule.getLocale();
  },
  /**
   * Request foreground location permission from the OS. Must be called
   * before mounting a `<YandexMapView showUserPosition>` for the user
   * location layer to render.
   */
  requestLocationPermission(): Promise<'granted' | 'denied' | 'unavailable'> {
    return NativeYandexMapModule.requestLocationPermission() as Promise<
      'granted' | 'denied' | 'unavailable'
    >;
  },
  async getCurrentLocation(): Promise<{ lat: number; lon: number }> {
    const r = (await NativeYandexMapModule.getCurrentLocation()) as {
      lat: number;
      lon: number;
    };
    return { lat: r.lat, lon: r.lon };
  },
};

export default YandexMap;
