import type { ReactNode } from 'react';
import type { ImageSourcePropType, ViewProps } from 'react-native';
import type { Point } from './types';

export interface MarkerProps extends ViewProps {
  point: Point;
  source?: ImageSourcePropType;
  /** Requires explicit `style={{ width, height }}` when used. */
  children?: ReactNode;
  anchor?: { x: number; y: number };
  placemarkZIndex?: number;
  scale?: number;
  visible?: boolean;
  onPress?: () => void;
}

export function Marker(_props: MarkerProps): never {
  throw new Error(
    "'react-native-yandex-map' Marker is only supported on native platforms."
  );
}
