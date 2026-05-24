import type { TurboModule, CodegenTypes } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  suggest(
    query: string,
    viewport: CodegenTypes.UnsafeObject,
    options: CodegenTypes.UnsafeObject | null
  ): Promise<CodegenTypes.UnsafeObject[]>;

  reset(): Promise<void>;
}

let cached: Spec | null = null;

export function getYandexSuggestModule(): Spec {
  if (cached == null) {
    cached = TurboModuleRegistry.getEnforcing<Spec>('YandexSuggestModule');
  }
  return cached;
}

export default { getYandexSuggestModule };
