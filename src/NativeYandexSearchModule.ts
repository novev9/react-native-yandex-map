import type { TurboModule, CodegenTypes } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  searchByText(
    query: string,
    viewport: CodegenTypes.UnsafeObject | null,
    options: CodegenTypes.UnsafeObject | null
  ): Promise<CodegenTypes.UnsafeObject[]>;

  geocodePoint(
    point: CodegenTypes.UnsafeObject
  ): Promise<CodegenTypes.UnsafeObject | null>;

  resolveUri(uri: string): Promise<CodegenTypes.UnsafeObject | null>;
}

// Lazy accessor — defer TurboModuleRegistry.getEnforcing until first call.
// Reduces app-startup blast radius (module construction only happens when
// search is actually used). Top-level getEnforcing also works.
let cached: Spec | null = null;

export function getYandexSearchModule(): Spec {
  if (cached == null) {
    cached = TurboModuleRegistry.getEnforcing<Spec>('YandexSearchModule');
  }
  return cached;
}

export default { getYandexSearchModule };
