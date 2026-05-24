import type { ReactNode } from 'react';
import type { ImageSourcePropType, ViewProps } from 'react-native';
// @ts-ignore — internal RN helper, no public type export
import resolveAssetSource from 'react-native/Libraries/Image/resolveAssetSource';
import NativeYandexMapMarker from './YandexMapMarkerNativeComponent';
import type { Point } from './types';

export interface MarkerProps extends ViewProps {
  point: Point;
  /**
   * Bitmap-based icon URI (Image source or remote URL). Ignored if `children`
   * are provided — in that case the React tree is snapshotted to a bitmap and
   * used as the icon instead.
   */
  source?: ImageSourcePropType;
  /**
   * Optional React content rendered into the placemark icon. The tree is laid
   * out offscreen and snapshotted to a bitmap on each layout pass.
   *
   * IMPORTANT: when using `children`, the Marker MUST have explicit
   * `style={{ width, height }}` — Fabric Yoga does not auto-size markers
   * based on child intrinsic content, so without explicit dimensions the
   * snapshot bitmap will be 0×0 and nothing will render.
   */
  children?: ReactNode;
  /**
   * Anchor point inside the icon bitmap (both axes 0..1). `{x: 0.5, y: 0.5}`
   * (Yandex default) centres the icon on the geo point. `{x: 0.5, y: 1}`
   * places the bottom of the icon on the point (typical pin behaviour).
   */
  anchor?: { x: number; y: number };
  placemarkZIndex?: number;
  /** Icon scale factor — `1` = native pixel size, `2` = double size, etc. */
  scale?: number;
  visible?: boolean;
  onPress?: () => void;
}

function resolveIconUri(source?: ImageSourcePropType): string | undefined {
  if (source == null) return undefined;
  const resolved = resolveAssetSource(source);
  return resolved ? resolved.uri : undefined;
}

// Yandex defaults — keep parity so callers who don't set anchor/scale get the
// same behaviour as a plain placemark.
const DEFAULT_ANCHOR = { x: 0.5, y: 0.5 };
const DEFAULT_SCALE = 1;

export function Marker({
  source,
  onPress,
  visible = true,
  anchor = DEFAULT_ANCHOR,
  scale = DEFAULT_SCALE,
  children,
  ...rest
}: MarkerProps) {
  return (
    <NativeYandexMapMarker
      {...rest}
      visible={visible}
      anchor={anchor}
      scale={scale}
      iconUri={resolveIconUri(source)}
      onMarkerPress={onPress ? () => onPress() : undefined}
    >
      {children}
    </NativeYandexMapMarker>
  );
}
