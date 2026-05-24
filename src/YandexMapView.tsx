import type { ColorValue, ViewProps } from 'react-native';

type Props = ViewProps & {
  color?: ColorValue;
};

export function YandexMapView(_props: Props): never {
  throw new Error(
    "'react-native-yandex-map' is only supported on native platforms."
  );
}
