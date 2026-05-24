import {
  forwardRef,
  type ForwardRefExoticComponent,
  type RefAttributes,
} from 'react';
import type { ViewProps } from 'react-native';
import type {
  Animation,
  CameraPosition,
  InitialRegion,
  MapLoaded,
  Point,
} from './types';

export interface YandexMapRef {
  setCenter: (
    point: Point,
    options?: {
      zoom?: number;
      azimuth?: number;
      tilt?: number;
      duration?: number;
      animation?: Animation;
    }
  ) => void;
  setZoom: (
    zoom: number,
    options?: { duration?: number; animation?: Animation }
  ) => void;
  fitMarkers: (points: readonly Point[]) => void;
  setTrafficVisible: (visible: boolean) => void;
}

export interface YandexMapProps extends ViewProps {
  initialRegion?: InitialRegion;
  showUserPosition?: boolean;
  nightMode?: boolean;
  mapStyle?: string;
  scrollGesturesEnabled?: boolean;
  zoomGesturesEnabled?: boolean;
  tiltGesturesEnabled?: boolean;
  rotateGesturesEnabled?: boolean;
  fastTapEnabled?: boolean;
  onMapPress?: (point: Point) => void;
  onMapLongPress?: (point: Point) => void;
  onMapLoaded?: (event: MapLoaded) => void;
  onCameraPositionChange?: (position: CameraPosition) => void;
  onCameraPositionChangeEnd?: (position: CameraPosition) => void;
}

// Web stub — keeps the same `forwardRef<YandexMapRef, YandexMapProps>` shape
// as the native build so TypeScript callers can pass `ref` without a platform
// guard. Throws at runtime on non-native platforms.
export const YandexMapView: ForwardRefExoticComponent<
  YandexMapProps & RefAttributes<YandexMapRef>
> = forwardRef<YandexMapRef, YandexMapProps>(() => {
  throw new Error(
    "'react-native-yandex-map' is only supported on native platforms."
  );
});
