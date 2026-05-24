import { getYandexSearchModule } from './NativeYandexSearchModule';
import type { BoundingBox, Point } from './types';

export interface SearchOptions {
  searchType?: number;
  resultPageSize?: number;
  disableSpellingCorrection?: boolean;
  /** User position hint for ranking. */
  userPosition?: { lat: number; lon: number };
}

export interface SearchHit {
  title: string;
  subtitle: string;
  uri: string;
  point: Point;
}

/**
 * Bitmask values for `SearchOptions.searchType`. Yandex MapKit 4.36 ships only
 * GEO (= TOPONYM, addresses/places) and BIZ (organisations). TRANSIT and
 * COLLECTIONS were exposed in older SDKs but are not honoured in 4.36.
 */
export const SearchType = {
  GEO: 1,
  TOPONYM: 1,
  BIZ: 2,
} as const;

export const Search = {
  async searchByText(
    query: string,
    options?: { viewport?: BoundingBox } & SearchOptions
  ): Promise<readonly SearchHit[]> {
    const { viewport, ...rest } = options ?? {};
    const result = await getYandexSearchModule().searchByText(
      query,
      viewport ?? null,
      Object.keys(rest).length > 0 ? rest : null
    );
    return result as unknown as readonly SearchHit[];
  },

  async geocodePoint(point: Point): Promise<SearchHit | null> {
    const result = await getYandexSearchModule().geocodePoint(point);
    return result as unknown as SearchHit | null;
  },

  /**
   * Resolve a Yandex URI (typically `item.uri` from a SuggestItem) directly to
   * a concrete hit. Prefer this over `searchByText` for picking a suggestion —
   * the URI already identifies the object so there's no re-ranking that could
   * drift to a different city.
   */
  async resolveUri(uri: string): Promise<SearchHit | null> {
    if (!uri) return null;
    const result = await getYandexSearchModule().resolveUri(uri);
    return result as unknown as SearchHit | null;
  },
};

export default Search;
