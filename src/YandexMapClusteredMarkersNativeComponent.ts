import {
  codegenNativeComponent,
  type ViewProps,
  type ColorValue,
  type CodegenTypes,
} from 'react-native';

type PointShape = Readonly<{
  lat: CodegenTypes.Double;
  lon: CodegenTypes.Double;
}>;

type ClusterPressEvent = Readonly<{
  size: CodegenTypes.Int32;
  lat: CodegenTypes.Double;
  lon: CodegenTypes.Double;
  // Bounding box around every placemark inside the cluster — lets callers
  // animate the camera to fit the cluster contents on tap instead of guessing
  // a target zoom level.
  swLat: CodegenTypes.Double;
  swLon: CodegenTypes.Double;
  neLat: CodegenTypes.Double;
  neLon: CodegenTypes.Double;
}>;

export interface NativeProps extends ViewProps {
  points: ReadonlyArray<PointShape>;
  // Per-point label, baked into each placemark's bitmap. Length must match
  // `points`; empty string falls back to the generic photo badge. Native
  // caches bitmaps by label so 110 placemarks with ~25 unique labels still
  // only renders ~25 bitmaps.
  pointLabels?: ReadonlyArray<string>;
  markerIconUri?: string;
  clusterColor?: ColorValue;
  clusterTextColor?: ColorValue;
  clusterRadius?: CodegenTypes.Float;
  clusterMinZoom?: CodegenTypes.Float;
  onClusterPress?: CodegenTypes.DirectEventHandler<ClusterPressEvent>;
}

export default codegenNativeComponent<NativeProps>('YandexMapClusteredMarkers');
