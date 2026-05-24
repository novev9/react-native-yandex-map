import {
  forwardRef,
  useImperativeHandle,
  useRef,
  type ComponentRef,
} from 'react';
import type { NativeSyntheticEvent, ViewProps } from 'react-native';
import NativeYandexMapView, { Commands } from './YandexMapViewNativeComponent';
import type {
  Animation,
  CameraPosition,
  InitialRegion,
  MapLoaded,
  Point,
} from './types';

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

type RawPointEvent = NativeSyntheticEvent<{ lat: number; lon: number }>;
type RawCameraEvent = NativeSyntheticEvent<{
  zoom: number;
  tilt: number;
  azimuth: number;
  lat: number;
  lon: number;
  reason: string;
  finished: boolean;
}>;
type RawMapLoadedEvent = NativeSyntheticEvent<MapLoaded>;

function wrapPoint(handler?: (p: Point) => void) {
  if (!handler) return undefined;
  return (event: RawPointEvent) => {
    const { lat, lon } = event.nativeEvent;
    handler({ lat, lon });
  };
}

function wrapCamera(handler?: (p: CameraPosition) => void) {
  if (!handler) return undefined;
  return (event: RawCameraEvent) => {
    const { zoom, tilt, azimuth, lat, lon, reason, finished } =
      event.nativeEvent;
    handler({
      zoom,
      tilt,
      azimuth,
      point: { lat, lon },
      reason: reason as 'GESTURES' | 'APPLICATION',
      finished,
    });
  };
}

function wrapLoaded(handler?: (e: MapLoaded) => void) {
  if (!handler) return undefined;
  return (event: RawMapLoadedEvent) => handler(event.nativeEvent);
}

export const YandexMapView = forwardRef<YandexMapRef, YandexMapProps>(
  function YandexMapView(
    {
      onMapPress,
      onMapLongPress,
      onMapLoaded,
      onCameraPositionChange,
      onCameraPositionChangeEnd,
      ...rest
    },
    ref
  ) {
    const nativeRef = useRef<ComponentRef<typeof NativeYandexMapView>>(null);

    useImperativeHandle(
      ref,
      () => ({
        setCenter(point, options = {}) {
          if (nativeRef.current == null) return;
          Commands.setCenter(
            nativeRef.current,
            point.lat,
            point.lon,
            options.zoom ?? 0,
            options.azimuth ?? 0,
            options.tilt ?? 0,
            options.duration ?? 0,
            options.duration ? options.duration > 0 : false
          );
        },
        setZoom(zoom, options = {}) {
          if (nativeRef.current == null) return;
          Commands.setZoom(
            nativeRef.current,
            zoom,
            options.duration ?? 0,
            options.duration ? options.duration > 0 : false
          );
        },
        fitMarkers(points) {
          if (nativeRef.current == null || points.length === 0) return;
          let minLat = points[0]!.lat;
          let maxLat = points[0]!.lat;
          let minLon = points[0]!.lon;
          let maxLon = points[0]!.lon;
          for (const p of points) {
            if (p.lat < minLat) minLat = p.lat;
            if (p.lat > maxLat) maxLat = p.lat;
            if (p.lon < minLon) minLon = p.lon;
            if (p.lon > maxLon) maxLon = p.lon;
          }
          Commands.fitBoundingBox(
            nativeRef.current,
            minLat,
            minLon,
            maxLat,
            maxLon
          );
        },
        setTrafficVisible(visible) {
          if (nativeRef.current == null) return;
          Commands.setTrafficVisible(nativeRef.current, visible);
        },
      }),
      []
    );

    return (
      <NativeYandexMapView
        ref={nativeRef}
        {...rest}
        onMapPress={wrapPoint(onMapPress)}
        onMapLongPress={wrapPoint(onMapLongPress)}
        onMapLoaded={wrapLoaded(onMapLoaded)}
        onCameraPositionChange={wrapCamera(onCameraPositionChange)}
        onCameraPositionChangeEnd={wrapCamera(onCameraPositionChangeEnd)}
      />
    );
  }
);
