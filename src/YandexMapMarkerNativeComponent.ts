import {
  codegenNativeComponent,
  type ViewProps,
  type CodegenTypes,
} from 'react-native';

type PointShape = Readonly<{
  lat: CodegenTypes.Double;
  lon: CodegenTypes.Double;
}>;

type AnchorShape = Readonly<{
  x: CodegenTypes.Float;
  y: CodegenTypes.Float;
}>;

export interface NativeProps extends ViewProps {
  point: PointShape;
  iconUri?: string;
  anchor?: AnchorShape;
  placemarkZIndex?: CodegenTypes.Float;
  scale?: CodegenTypes.Float;
  visible?: boolean;

  onMarkerPress?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>('YandexMapMarker');
