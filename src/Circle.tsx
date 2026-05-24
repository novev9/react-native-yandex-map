import type { ColorValue, ViewProps } from 'react-native';
import type { Point } from './types';

export interface CircleProps extends Omit<ViewProps, 'style'> {
  center: Point;
  radius: number;
  fillColor?: ColorValue;
  strokeColor?: ColorValue;
  strokeWidth?: number;
  placemarkZIndex?: number;
  onPress?: () => void;
}

export function Circle(_props: CircleProps): never {
  throw new Error(
    "'react-native-yandex-map' Circle is only supported on native platforms."
  );
}
