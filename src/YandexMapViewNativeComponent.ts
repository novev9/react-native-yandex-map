import {
  codegenNativeComponent,
  codegenNativeCommands,
  type ViewProps,
  type CodegenTypes,
} from 'react-native';
import type * as React from 'react';

type RegionShape = Readonly<{
  lat: CodegenTypes.Double;
  lon: CodegenTypes.Double;
  zoom?: CodegenTypes.Float;
  azimuth?: CodegenTypes.Float;
  tilt?: CodegenTypes.Float;
}>;

type PointEvent = Readonly<{
  lat: CodegenTypes.Double;
  lon: CodegenTypes.Double;
}>;

type CameraPositionEvent = Readonly<{
  zoom: CodegenTypes.Double;
  tilt: CodegenTypes.Double;
  azimuth: CodegenTypes.Double;
  lat: CodegenTypes.Double;
  lon: CodegenTypes.Double;
  reason: string;
  finished: boolean;
}>;

type MapLoadedEvent = Readonly<{
  renderObjectCount: CodegenTypes.Double;
  curZoomModelsLoaded: CodegenTypes.Double;
  curZoomPlacemarksLoaded: CodegenTypes.Double;
  curZoomLabelsLoaded: CodegenTypes.Double;
  curZoomGeometryLoaded: CodegenTypes.Double;
  tileMemoryUsage: CodegenTypes.Double;
  delayedGeometryLoaded: CodegenTypes.Double;
  fullyAppeared: CodegenTypes.Double;
  fullyLoaded: CodegenTypes.Double;
}>;

export interface NativeProps extends ViewProps {
  initialRegion?: RegionShape;
  showUserPosition?: boolean;
  nightMode?: boolean;
  mapStyle?: string;
  scrollGesturesEnabled?: boolean;
  zoomGesturesEnabled?: boolean;
  tiltGesturesEnabled?: boolean;
  rotateGesturesEnabled?: boolean;
  fastTapEnabled?: boolean;

  onMapPress?: CodegenTypes.DirectEventHandler<PointEvent>;
  onMapLongPress?: CodegenTypes.DirectEventHandler<PointEvent>;
  onMapLoaded?: CodegenTypes.DirectEventHandler<MapLoadedEvent>;
  onCameraPositionChange?: CodegenTypes.DirectEventHandler<CameraPositionEvent>;
  onCameraPositionChangeEnd?: CodegenTypes.DirectEventHandler<CameraPositionEvent>;
}

interface NativeCommands {
  setCenter: (
    viewRef: React.ElementRef<HostComponent>,
    lat: CodegenTypes.Double,
    lon: CodegenTypes.Double,
    zoom: CodegenTypes.Float,
    azimuth: CodegenTypes.Float,
    tilt: CodegenTypes.Float,
    duration: CodegenTypes.Float,
    animated: boolean
  ) => void;
  setZoom: (
    viewRef: React.ElementRef<HostComponent>,
    zoom: CodegenTypes.Float,
    duration: CodegenTypes.Float,
    animated: boolean
  ) => void;
  fitBoundingBox: (
    viewRef: React.ElementRef<HostComponent>,
    swLat: CodegenTypes.Double,
    swLon: CodegenTypes.Double,
    neLat: CodegenTypes.Double,
    neLon: CodegenTypes.Double
  ) => void;
  setTrafficVisible: (
    viewRef: React.ElementRef<HostComponent>,
    visible: boolean
  ) => void;
}

type HostComponent = ReturnType<typeof codegenNativeComponent<NativeProps>>;

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: [
    'setCenter',
    'setZoom',
    'fitBoundingBox',
    'setTrafficVisible',
  ],
});

export default codegenNativeComponent<NativeProps>('YandexMapView');
