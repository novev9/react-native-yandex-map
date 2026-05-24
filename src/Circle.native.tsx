import type { ColorValue, ViewProps } from 'react-native';
import NativeYandexMapCircle from './YandexMapCircleNativeComponent';
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

export function Circle({ onPress, ...rest }: CircleProps) {
  return (
    <NativeYandexMapCircle
      {...rest}
      onCirclePress={onPress ? () => onPress() : undefined}
    />
  );
}
