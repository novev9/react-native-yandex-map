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

export interface NativeProps extends ViewProps {
  points: ReadonlyArray<PointShape>;
  strokeColor?: ColorValue;
  strokeWidth?: CodegenTypes.Float;
  placemarkZIndex?: CodegenTypes.Float;
  onPolylinePress?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>('YandexMapPolyline');
