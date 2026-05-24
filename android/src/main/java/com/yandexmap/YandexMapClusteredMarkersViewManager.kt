package com.yandexmap

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.Event
import com.facebook.react.viewmanagers.YandexMapClusteredMarkersManagerDelegate
import com.facebook.react.viewmanagers.YandexMapClusteredMarkersManagerInterface

@ReactModule(name = YandexMapClusteredMarkersViewManager.NAME)
class YandexMapClusteredMarkersViewManager :
  SimpleViewManager<YandexMapClusteredMarkersView>(),
  YandexMapClusteredMarkersManagerInterface<YandexMapClusteredMarkersView> {

  private val mDelegate: ViewManagerDelegate<YandexMapClusteredMarkersView> =
    YandexMapClusteredMarkersManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<YandexMapClusteredMarkersView> = mDelegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): YandexMapClusteredMarkersView {
    val view = YandexMapClusteredMarkersView(context)
    view.onClusterPress = { size, lat, lon, swLat, swLon, neLat, neLon ->
      UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
        ?.dispatchEvent(ClusterPressEvent(
          context.surfaceId, view.id, size, lat, lon, swLat, swLon, neLat, neLon))
    }
    return view
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topClusterPress" to mapOf("registrationName" to "onClusterPress"),
    )

  @ReactProp(name = "points")
  override fun setPoints(view: YandexMapClusteredMarkersView, value: ReadableArray?) {
    view.pendingPoints = value.toPointList()
    view.scheduleRebuild()
  }

  @ReactProp(name = "pointLabels")
  override fun setPointLabels(view: YandexMapClusteredMarkersView, value: ReadableArray?) {
    if (value == null) {
      view.pendingPointLabels = emptyList()
    } else {
      view.pendingPointLabels = (0 until value.size()).map {
        if (value.isNull(it)) "" else value.getString(it) ?: ""
      }
    }
    view.scheduleRebuild()
  }

  @ReactProp(name = "markerIconUri")
  override fun setMarkerIconUri(view: YandexMapClusteredMarkersView, value: String?) {
    if (view.pendingMarkerIconUri != value) {
      view.pendingMarkerIconUri = value
      view.scheduleRebuild()
    }
  }

  @ReactProp(name = "clusterColor", customType = "Color")
  override fun setClusterColor(view: YandexMapClusteredMarkersView, value: Int?) {
    view.pendingClusterColor = value
    view.scheduleRebuild()
  }

  @ReactProp(name = "clusterTextColor", customType = "Color")
  override fun setClusterTextColor(view: YandexMapClusteredMarkersView, value: Int?) {
    view.pendingClusterTextColor = value
    view.scheduleRebuild()
  }

  @ReactProp(name = "clusterRadius")
  override fun setClusterRadius(view: YandexMapClusteredMarkersView, value: Float) {
    if (value > 0f) {
      view.pendingClusterRadius = value
      view.scheduleRebuild()
    }
  }

  @ReactProp(name = "clusterMinZoom")
  override fun setClusterMinZoom(view: YandexMapClusteredMarkersView, value: Float) {
    if (value > 0f) {
      view.pendingClusterMinZoom = value.toInt()
      view.scheduleRebuild()
    }
  }

  companion object {
    const val NAME = "YandexMapClusteredMarkers"
  }
}

private class ClusterPressEvent(
  surfaceId: Int,
  viewTag: Int,
  private val size: Int,
  private val lat: Double,
  private val lon: Double,
  private val swLat: Double,
  private val swLon: Double,
  private val neLat: Double,
  private val neLon: Double,
) : Event<ClusterPressEvent>(surfaceId, viewTag) {
  override fun getEventName(): String = "topClusterPress"
  override fun getEventData(): WritableMap = Arguments.createMap().apply {
    putInt("size", size)
    putDouble("lat", lat)
    putDouble("lon", lon)
    putDouble("swLat", swLat)
    putDouble("swLon", swLon)
    putDouble("neLat", neLat)
    putDouble("neLon", neLon)
  }
}
