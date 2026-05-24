package com.yandexmap

import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.Event
import com.facebook.react.viewmanagers.YandexMapMarkerManagerDelegate
import com.facebook.react.viewmanagers.YandexMapMarkerManagerInterface

@ReactModule(name = YandexMapMarkerViewManager.NAME)
class YandexMapMarkerViewManager :
  ViewGroupManager<YandexMapMarkerView>(),
  YandexMapMarkerManagerInterface<YandexMapMarkerView> {

  private val mDelegate: ViewManagerDelegate<YandexMapMarkerView> =
    YandexMapMarkerManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<YandexMapMarkerView> = mDelegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): YandexMapMarkerView {
    val view = YandexMapMarkerView(context)
    view.onMarkerPress = {
      val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(
        context,
        view.id,
      )
      dispatcher?.dispatchEvent(MarkerPressEvent(context.surfaceId, view.id))
    }
    return view
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topMarkerPress" to mapOf("registrationName" to "onMarkerPress"),
    )

  @ReactProp(name = "point")
  override fun setPoint(view: YandexMapMarkerView, value: ReadableMap?) {
    if (value == null) return
    val lat = if (value.hasKey("lat")) value.getDouble("lat") else 0.0
    val lon = if (value.hasKey("lon")) value.getDouble("lon") else 0.0
    view.setPoint(lat, lon)
  }

  @ReactProp(name = "iconUri")
  override fun setIconUri(view: YandexMapMarkerView, value: String?) {
    view.setIconUri(value)
  }

  @ReactProp(name = "anchor")
  override fun setAnchor(view: YandexMapMarkerView, value: ReadableMap?) {
    if (value == null) return
    val x = if (value.hasKey("x")) value.getDouble("x").toFloat() else 0.5f
    val y = if (value.hasKey("y")) value.getDouble("y").toFloat() else 0.5f
    view.setAnchor(x, y)
  }

  @ReactProp(name = "placemarkZIndex")
  override fun setPlacemarkZIndex(view: YandexMapMarkerView, value: Float) {
    view.setMarkerZIndex(value)
  }

  @ReactProp(name = "scale")
  override fun setScale(view: YandexMapMarkerView, value: Float) {
    view.setScale(value)
  }

  @ReactProp(name = "visible")
  override fun setVisible(view: YandexMapMarkerView, value: Boolean) {
    view.setMarkerVisible(value)
  }

  companion object {
    const val NAME = "YandexMapMarker"
  }
}

private class MarkerPressEvent(surfaceId: Int, viewTag: Int) :
  Event<MarkerPressEvent>(surfaceId, viewTag) {
  override fun getEventName(): String = "topMarkerPress"
  override fun getEventData(): com.facebook.react.bridge.WritableMap =
    com.facebook.react.bridge.Arguments.createMap()
}
