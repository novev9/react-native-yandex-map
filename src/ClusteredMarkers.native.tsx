import type {
  ColorValue,
  ImageSourcePropType,
  NativeSyntheticEvent,
  ViewProps,
} from 'react-native';
// @ts-ignore — internal RN helper
import resolveAssetSource from 'react-native/Libraries/Image/resolveAssetSource';
import NativeYandexMapClusteredMarkers from './YandexMapClusteredMarkersNativeComponent';
import type { BoundingBox, Point } from './types';

export interface ClusterPressInfo {
  size: number;
  lat: number;
  lon: number;
  /** Bounding box around all placemarks inside the cluster. */
  bounds: BoundingBox;
}

export interface ClusteredMarkersProps extends Omit<ViewProps, 'style'> {
  points: readonly Point[];
  /**
   * Per-point text label baked into the placemark bitmap. Length must equal
   * `points.length`; an empty string yields the generic "PHOTO" badge.
   * Native caches one bitmap per unique label string, so repeated values
   * cost ~nothing.
   */
  pointLabels?: readonly string[];
  markerSource?: ImageSourcePropType;
  clusterColor?: ColorValue;
  clusterTextColor?: ColorValue;
  clusterRadius?: number;
  clusterMinZoom?: number;
  onClusterPress?: (info: ClusterPressInfo) => void;
}

function resolveIconUri(source?: ImageSourcePropType): string | undefined {
  if (source == null) return undefined;
  const resolved = resolveAssetSource(source);
  return resolved ? resolved.uri : undefined;
}

export function ClusteredMarkers({
  points,
  pointLabels,
  markerSource,
  onClusterPress,
  ...rest
}: ClusteredMarkersProps) {
  return (
    <NativeYandexMapClusteredMarkers
      {...rest}
      points={points.map((p) => ({ lat: p.lat, lon: p.lon }))}
      pointLabels={pointLabels}
      markerIconUri={resolveIconUri(markerSource)}
      onClusterPress={
        onClusterPress
          ? (
              event: NativeSyntheticEvent<{
                size: number;
                lat: number;
                lon: number;
                swLat: number;
                swLon: number;
                neLat: number;
                neLon: number;
              }>
            ) => {
              const { size, lat, lon, swLat, swLon, neLat, neLon } =
                event.nativeEvent;
              onClusterPress({
                size,
                lat,
                lon,
                bounds: {
                  southWest: { lat: swLat, lon: swLon },
                  northEast: { lat: neLat, lon: neLon },
                },
              });
            }
          : undefined
      }
    />
  );
}
