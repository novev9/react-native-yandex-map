import { getYandexSuggestModule } from './NativeYandexSuggestModule';
import type { BoundingBox } from './types';

export interface SuggestOptions {
  suggestTypes?: number;
  suggestWords?: boolean;
  /**
   * Hard-filter results to the viewport — drops anything outside. Use only
   * for "search this map area" mode where the viewport is the actual visible
   * bounds of the map. AVOID for country-wide autocomplete: Yandex returns
   * very sparse results for huge boxes and the dropdown ends up empty.
   * For general autocomplete pass `userPosition` instead (bias, not filter).
   */
  strictBounds?: boolean;
  /** User position hint — Yandex biases ranking toward results near it. */
  userPosition?: { lat: number; lon: number };
}

export interface SuggestItem {
  title: string;
  subtitle: string;
  uri: string;
}

/**
 * Bitmask values for `SuggestOptions.suggestTypes`. Compose with `|`. Yandex
 * MapKit 4.36 exposes GEO (toponyms) and BIZ (organisations) — TRANSIT was
 * present in older SDKs but is not honoured here.
 */
export const SuggestType = {
  GEO: 1,
  BIZ: 2,
} as const;

export const Suggest = {
  async suggest(
    query: string,
    viewport: BoundingBox,
    options?: SuggestOptions
  ): Promise<readonly SuggestItem[]> {
    const result = await getYandexSuggestModule().suggest(
      query,
      viewport,
      options ?? null
    );
    return result as unknown as readonly SuggestItem[];
  },

  reset(): Promise<void> {
    return getYandexSuggestModule().reset();
  },
};

export default Suggest;
