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
  fillColor?: ColorValue;
  strokeColor?: ColorValue;
  strokeWidth?: CodegenTypes.Float;
  placemarkZIndex?: CodegenTypes.Float;
  onPolygonPress?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}

export default codegenNativeComponent<NativeProps>('YandexMapPolygon');
