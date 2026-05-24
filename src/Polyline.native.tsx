import type { ColorValue, ViewProps } from 'react-native';
import NativeYandexMapPolyline from './YandexMapPolylineNativeComponent';
import type { Point } from './types';

export interface PolylineProps extends Omit<ViewProps, 'style'> {
  points: readonly Point[];
  strokeColor?: ColorValue;
  strokeWidth?: number;
  placemarkZIndex?: number;
  onPress?: () => void;
}

export function Polyline({ onPress, points, ...rest }: PolylineProps) {
  return (
    <NativeYandexMapPolyline
      {...rest}
      points={points.map((p) => ({ lat: p.lat, lon: p.lon }))}
      onPolylinePress={onPress ? () => onPress() : undefined}
    />
  );
}
