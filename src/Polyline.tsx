import type { ColorValue, ViewProps } from 'react-native';
import type { Point } from './types';

export interface PolylineProps extends Omit<ViewProps, 'style'> {
  points: readonly Point[];
  strokeColor?: ColorValue;
  strokeWidth?: number;
  placemarkZIndex?: number;
  onPress?: () => void;
}

export function Polyline(_props: PolylineProps): never {
  throw new Error(
    "'react-native-yandex-map' Polyline is only supported on native platforms."
  );
}
