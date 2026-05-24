package com.yandexmap

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.yandex.mapkit.Animation
import com.yandex.mapkit.MapKitFactory
import com.yandex.mapkit.geometry.BoundingBox
import com.yandex.mapkit.geometry.Geometry
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.map.CameraListener
import com.yandex.mapkit.map.CameraPosition
import com.yandex.mapkit.map.CameraUpdateReason
import com.yandex.mapkit.map.InputListener
import com.yandex.mapkit.map.Map as YMKMap
import com.yandex.mapkit.map.MapLoadedListener
import com.yandex.mapkit.map.MapLoadStatistics
import com.yandex.mapkit.mapview.MapView as YMKMapView
import com.yandex.mapkit.user_location.UserLocationLayer

class YandexMapView(context: Context) :
  FrameLayout(context),
  InputListener,
  CameraListener,
  MapLoadedListener {

  val nativeMap: YMKMapView

  private var didApplyInitialRegion: Boolean = false
  private val reactContext: ThemedReactContext? = context as? ThemedReactContext
  private var userLocationLayer: UserLocationLayer? = null

  init {
    YandexMapModule.ensureInitialisedFromManifest(context)
    nativeMap = YMKMapView(context, null)
    addView(
      nativeMap,
      LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
    )
    registerMapListeners()
  }

  private fun registerMapListeners() {
    val map = nativeMap.mapWindow.map
    map.addInputListener(this)
    map.addCameraListener(this)
    map.setMapLoadedListener(this)
  }

  private fun unregisterMapListeners() {
    val map = nativeMap.mapWindow.map
    map.removeInputListener(this)
    map.removeCameraListener(this)
    map.setMapLoadedListener(null)
  }

  override fun addView(child: View, index: Int, params: ViewGroup.LayoutParams?) {
    super.addView(child, index, params)
    val map = nativeMap.mapWindow.map
    when (child) {
      is YandexMapMarkerView -> child.attachToMap(map)
      is YandexMapPolylineView -> child.attachToMap(map)
      is YandexMapPolygonView -> child.attachToMap(map)
      is YandexMapCircleView -> child.attachToMap(map)
      is YandexMapClusteredMarkersView -> child.attachToMap(map)
    }
  }

  override fun removeViewAt(index: Int) {
    val child = getChildAt(index)
    when (child) {
      is YandexMapMarkerView -> child.detachFromMap()
      is YandexMapPolylineView -> child.detachFromMap()
      is YandexMapPolygonView -> child.detachFromMap()
      is YandexMapCircleView -> child.detachFromMap()
      is YandexMapClusteredMarkersView -> child.detachFromMap()
    }
    super.removeViewAt(index)
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    nativeMap.onStart()
  }

  override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    // Fabric (SurfaceMountingManager) lays out RN-managed children itself via
    // updateLayout(). If we call FrameLayout's super.onLayout(), it would
    // re-position those children based on FrameLayout.LayoutParams — which for
    // null params defaults to MATCH_PARENT, blowing up marker views to fill
    // the entire map. So we only lay out our own native Yandex MapView here.
    nativeMap.layout(0, 0, r - l, b - t)
  }

  override fun onDetachedFromWindow() {
    nativeMap.onStop()
    unregisterMapListeners()
    super.onDetachedFromWindow()
  }

  fun applyInitialRegion(
    lat: Double,
    lon: Double,
    zoom: Float,
    azimuth: Float,
    tilt: Float,
  ) {
    if (didApplyInitialRegion) return
    didApplyInitialRegion = true
    val targetZoom = if (zoom > 0f) zoom else 10f
    nativeMap.mapWindow.map.move(
      CameraPosition(Point(lat, lon), targetZoom, azimuth, tilt),
    )
  }

  fun applyShowUserPosition(show: Boolean) {
    if (show) {
      if (userLocationLayer == null) {
        userLocationLayer = MapKitFactory.getInstance()
          .createUserLocationLayer(nativeMap.mapWindow)
      }
      userLocationLayer?.isVisible = true
    } else {
      userLocationLayer?.isVisible = false
    }
  }

  fun setNightMode(enabled: Boolean) {
    nativeMap.mapWindow.map.isNightModeEnabled = enabled
  }

  fun setScrollGestures(enabled: Boolean) {
    nativeMap.mapWindow.map.isScrollGesturesEnabled = enabled
  }

  fun setZoomGestures(enabled: Boolean) {
    nativeMap.mapWindow.map.isZoomGesturesEnabled = enabled
  }

  fun setTiltGestures(enabled: Boolean) {
    nativeMap.mapWindow.map.isTiltGesturesEnabled = enabled
  }

  fun setRotateGestures(enabled: Boolean) {
    nativeMap.mapWindow.map.isRotateGesturesEnabled = enabled
  }

  fun setFastTap(enabled: Boolean) {
    nativeMap.mapWindow.map.isFastTapEnabled = enabled
  }

  fun setMapStyleJson(style: String?) {
    if (!style.isNullOrEmpty()) {
      nativeMap.mapWindow.map.setMapStyle(style)
    }
  }

  // -- Commands --------------------------------------------------------------

  fun moveCamera(
    lat: Double,
    lon: Double,
    zoom: Float,
    azimuth: Float,
    tilt: Float,
    duration: Float,
    animated: Boolean,
  ) {
    val map = nativeMap.mapWindow.map
    val resolvedZoom = if (zoom > 0f) zoom else map.cameraPosition.zoom
    val pos = CameraPosition(Point(lat, lon), resolvedZoom, azimuth, tilt)
    if (animated) {
      map.move(pos, Animation(Animation.Type.SMOOTH, duration), null)
    } else {
      map.move(pos)
    }
  }

  fun setZoomTo(zoom: Float, duration: Float, animated: Boolean) {
    val map = nativeMap.mapWindow.map
    val current = map.cameraPosition
    val pos = CameraPosition(current.target, zoom, current.azimuth, current.tilt)
    if (animated) {
      map.move(pos, Animation(Animation.Type.SMOOTH, duration), null)
    } else {
      map.move(pos)
    }
  }

  fun fitBoundingBox(swLat: Double, swLon: Double, neLat: Double, neLon: Double) {
    val map = nativeMap.mapWindow.map
    val box = BoundingBox(Point(swLat, swLon), Point(neLat, neLon))
    val pos = map.cameraPosition(Geometry.fromBoundingBox(box))
    map.move(pos)
  }

  fun setTrafficVisible(visible: Boolean) {
    // Traffic layer access in 4.36-full requires MapKitFactory.getInstance().createTrafficLayer(mapWindow).
    // Phase 1: deferred.
  }

  // -- InputListener ---------------------------------------------------------

  override fun onMapTap(map: YMKMap, point: Point) {
    dispatchEvent("topMapPress", pointPayload(point))
  }

  override fun onMapLongTap(map: YMKMap, point: Point) {
    dispatchEvent("topMapLongPress", pointPayload(point))
  }

  // -- CameraListener --------------------------------------------------------

  override fun onCameraPositionChanged(
    map: YMKMap,
    cameraPosition: CameraPosition,
    cameraUpdateReason: CameraUpdateReason,
    finished: Boolean,
  ) {
    val payload = cameraPayload(cameraPosition, cameraUpdateReason, finished)
    if (finished) {
      dispatchEvent("topCameraPositionChangeEnd", payload)
    } else {
      dispatchEvent("topCameraPositionChange", payload)
    }
  }

  // -- MapLoadedListener -----------------------------------------------------

  override fun onMapLoaded(statistics: MapLoadStatistics) {
    val payload = Arguments.createMap().apply {
      putDouble("renderObjectCount", statistics.renderObjectCount.toDouble())
      putDouble("curZoomModelsLoaded", statistics.curZoomModelsLoaded.toDouble())
      putDouble("curZoomPlacemarksLoaded", statistics.curZoomPlacemarksLoaded.toDouble())
      putDouble("curZoomLabelsLoaded", statistics.curZoomLabelsLoaded.toDouble())
      putDouble("curZoomGeometryLoaded", statistics.curZoomGeometryLoaded.toDouble())
      putDouble("tileMemoryUsage", statistics.tileMemoryUsage.toDouble())
      putDouble("delayedGeometryLoaded", statistics.delayedGeometryLoaded.toDouble())
      putDouble("fullyAppeared", statistics.fullyAppeared.toDouble())
      putDouble("fullyLoaded", statistics.fullyLoaded.toDouble())
    }
    dispatchEvent("topMapLoaded", payload)
  }

  // -- Helpers ---------------------------------------------------------------

  private fun pointPayload(point: Point): WritableMap = Arguments.createMap().apply {
    putDouble("lat", point.latitude)
    putDouble("lon", point.longitude)
  }

  private fun cameraPayload(
    pos: CameraPosition,
    reason: CameraUpdateReason,
    finished: Boolean,
  ): WritableMap = Arguments.createMap().apply {
    putDouble("zoom", pos.zoom.toDouble())
    putDouble("tilt", pos.tilt.toDouble())
    putDouble("azimuth", pos.azimuth.toDouble())
    putDouble("lat", pos.target.latitude)
    putDouble("lon", pos.target.longitude)
    putString(
      "reason",
      if (reason == CameraUpdateReason.GESTURES) "GESTURES" else "APPLICATION",
    )
    putBoolean("finished", finished)
  }

  private fun dispatchEvent(eventName: String, payload: WritableMap) {
    val rc = reactContext ?: return
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(rc, id) ?: return
    dispatcher.dispatchEvent(MapEvent(rc.surfaceId, id, eventName, payload))
  }
}

private class MapEvent(
  surfaceId: Int,
  viewTag: Int,
  private val name: String,
  private val payload: WritableMap,
) : Event<MapEvent>(surfaceId, viewTag) {
  override fun getEventName(): String = name
  override fun getEventData(): WritableMap = payload
}
