import type { TurboModule, CodegenTypes } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  init(apiKey: string): Promise<void>;
  setLocale(locale: string): Promise<void>;
  resetLocale(): Promise<void>;
  getLocale(): Promise<string>;

  /**
   * Prompt user for foreground location permission. Resolves to:
   *  - 'granted'      — permission granted (or already had it)
   *  - 'denied'       — user denied
   *  - 'unavailable'  — service unavailable / no Activity (Android)
   */
  requestLocationPermission(): Promise<string>;

  /**
   * Get a single current location fix via the system location services.
   * Returns {lat, lon}. Rejects if permission denied or no fix available.
   * Tries last-known position first, falls back to a one-shot fresh read.
   */
  getCurrentLocation(): Promise<CodegenTypes.UnsafeObject>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('YandexMapModule');
