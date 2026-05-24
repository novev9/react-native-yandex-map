import type { ColorValue, ViewProps } from 'react-native';
import NativeYandexMapPolygon from './YandexMapPolygonNativeComponent';
import type { Point } from './types';

export interface PolygonProps extends Omit<ViewProps, 'style'> {
  points: readonly Point[];
  fillColor?: ColorValue;
  strokeColor?: ColorValue;
  strokeWidth?: number;
  placemarkZIndex?: number;
  onPress?: () => void;
}

export function Polygon({ onPress, points, ...rest }: PolygonProps) {
  return (
    <NativeYandexMapPolygon
      {...rest}
      points={points.map((p) => ({ lat: p.lat, lon: p.lon }))}
      onPolygonPress={onPress ? () => onPress() : undefined}
    />
  );
}
