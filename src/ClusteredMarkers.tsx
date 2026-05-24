import type { ColorValue, ImageSourcePropType, ViewProps } from 'react-native';
import type { BoundingBox, Point } from './types';

export interface ClusterPressInfo {
  size: number;
  lat: number;
  lon: number;
  bounds: BoundingBox;
}

export interface ClusteredMarkersProps extends Omit<ViewProps, 'style'> {
  points: readonly Point[];
  pointLabels?: readonly string[];
  markerSource?: ImageSourcePropType;
  clusterColor?: ColorValue;
  clusterTextColor?: ColorValue;
  clusterRadius?: number;
  clusterMinZoom?: number;
  onClusterPress?: (info: ClusterPressInfo) => void;
}

export function ClusteredMarkers(_props: ClusteredMarkersProps): never {
  throw new Error(
    "'react-native-yandex-map' ClusteredMarkers is only supported on native platforms."
  );
}
