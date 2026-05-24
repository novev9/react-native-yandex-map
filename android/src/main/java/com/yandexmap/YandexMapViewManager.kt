package com.yandexmap

import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.YandexMapViewManagerDelegate
import com.facebook.react.viewmanagers.YandexMapViewManagerInterface

@ReactModule(name = YandexMapViewManager.NAME)
class YandexMapViewManager :
  ViewGroupManager<YandexMapView>(),
  YandexMapViewManagerInterface<YandexMapView> {

  private val mDelegate: ViewManagerDelegate<YandexMapView> =
    YandexMapViewManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<YandexMapView> = mDelegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): YandexMapView =
    YandexMapView(context)

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topMapPress" to mapOf("registrationName" to "onMapPress"),
      "topMapLongPress" to mapOf("registrationName" to "onMapLongPress"),
      "topMapLoaded" to mapOf("registrationName" to "onMapLoaded"),
      "topCameraPositionChange" to mapOf("registrationName" to "onCameraPositionChange"),
      "topCameraPositionChangeEnd" to mapOf("registrationName" to "onCameraPositionChangeEnd"),
    )

  @ReactProp(name = "initialRegion")
  override fun setInitialRegion(view: YandexMapView, value: ReadableMap?) {
    if (value == null) return
    val lat = if (value.hasKey("lat")) value.getDouble("lat") else 0.0
    val lon = if (value.hasKey("lon")) value.getDouble("lon") else 0.0
    val zoom = if (value.hasKey("zoom")) value.getDouble("zoom").toFloat() else 0f
    val azimuth = if (value.hasKey("azimuth")) value.getDouble("azimuth").toFloat() else 0f
    val tilt = if (value.hasKey("tilt")) value.getDouble("tilt").toFloat() else 0f
    view.applyInitialRegion(lat, lon, zoom, azimuth, tilt)
  }

  @ReactProp(name = "showUserPosition")
  override fun setShowUserPosition(view: YandexMapView, value: Boolean) {
    view.applyShowUserPosition(value)
  }

  @ReactProp(name = "nightMode")
  override fun setNightMode(view: YandexMapView, value: Boolean) {
    view.setNightMode(value)
  }

  @ReactProp(name = "mapStyle")
  override fun setMapStyle(view: YandexMapView, value: String?) {
    view.setMapStyleJson(value)
  }

  @ReactProp(name = "scrollGesturesEnabled")
  override fun setScrollGesturesEnabled(view: YandexMapView, value: Boolean) {
    view.setScrollGestures(value)
  }

  @ReactProp(name = "zoomGesturesEnabled")
  override fun setZoomGesturesEnabled(view: YandexMapView, value: Boolean) {
    view.setZoomGestures(value)
  }

  @ReactProp(name = "tiltGesturesEnabled")
  override fun setTiltGesturesEnabled(view: YandexMapView, value: Boolean) {
    view.setTiltGestures(value)
  }

  @ReactProp(name = "rotateGesturesEnabled")
  override fun setRotateGesturesEnabled(view: YandexMapView, value: Boolean) {
    view.setRotateGestures(value)
  }

  @ReactProp(name = "fastTapEnabled")
  override fun setFastTapEnabled(view: YandexMapView, value: Boolean) {
    view.setFastTap(value)
  }

  override fun setCenter(
    view: YandexMapView,
    lat: Double,
    lon: Double,
    zoom: Float,
    azimuth: Float,
    tilt: Float,
    duration: Float,
    animated: Boolean,
  ) {
    view.moveCamera(lat, lon, zoom, azimuth, tilt, duration, animated)
  }

  override fun setZoom(
    view: YandexMapView,
    zoom: Float,
    duration: Float,
    animated: Boolean,
  ) {
    view.setZoomTo(zoom, duration, animated)
  }

  override fun fitBoundingBox(
    view: YandexMapView,
    swLat: Double,
    swLon: Double,
    neLat: Double,
    neLon: Double,
  ) {
    view.fitBoundingBox(swLat, swLon, neLat, neLon)
  }

  override fun setTrafficVisible(view: YandexMapView, visible: Boolean) {
    view.setTrafficVisible(visible)
  }

  companion object {
    const val NAME = "YandexMapView"
  }
}
