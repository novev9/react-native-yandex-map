import type { ColorValue, ViewProps } from 'react-native';
import type { Point } from './types';

export interface PolygonProps extends Omit<ViewProps, 'style'> {
  points: readonly Point[];
  fillColor?: ColorValue;
  strokeColor?: ColorValue;
  strokeWidth?: number;
  placemarkZIndex?: number;
  onPress?: () => void;
}

export function Polygon(_props: PolygonProps): never {
  throw new Error(
    "'react-native-yandex-map' Polygon is only supported on native platforms."
  );
}
