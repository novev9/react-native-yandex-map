package com.yandexmap

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.Event
import com.facebook.react.viewmanagers.YandexMapPolylineManagerDelegate
import com.facebook.react.viewmanagers.YandexMapPolylineManagerInterface
import com.yandex.mapkit.geometry.Point

@ReactModule(name = YandexMapPolylineViewManager.NAME)
class YandexMapPolylineViewManager :
  SimpleViewManager<YandexMapPolylineView>(),
  YandexMapPolylineManagerInterface<YandexMapPolylineView> {

  private val mDelegate: ViewManagerDelegate<YandexMapPolylineView> =
    YandexMapPolylineManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<YandexMapPolylineView> = mDelegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): YandexMapPolylineView {
    val view = YandexMapPolylineView(context)
    view.onPolylinePress = {
      UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
        ?.dispatchEvent(PressEvent(context.surfaceId, view.id, "topPolylinePress"))
    }
    return view
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topPolylinePress" to mapOf("registrationName" to "onPolylinePress"),
    )

  @ReactProp(name = "points")
  override fun setPoints(view: YandexMapPolylineView, value: ReadableArray?) {
    view.setPolylinePoints(value.toPointList())
  }

  @ReactProp(name = "strokeColor", customType = "Color")
  override fun setStrokeColor(view: YandexMapPolylineView, value: Int?) {
    view.setPolylineStrokeColor(value)
  }

  @ReactProp(name = "strokeWidth")
  override fun setStrokeWidth(view: YandexMapPolylineView, value: Float) {
    view.setPolylineStrokeWidth(value)
  }

  @ReactProp(name = "placemarkZIndex")
  override fun setPlacemarkZIndex(view: YandexMapPolylineView, value: Float) {
    view.setPolylineZIndex(value)
  }

  companion object {
    const val NAME = "YandexMapPolyline"
  }
}

internal fun ReadableArray?.toPointList(): List<Point> {
  if (this == null || size() == 0) return emptyList()
  val out = ArrayList<Point>(size())
  for (i in 0 until size()) {
    val item = getMap(i) ?: continue
    val lat = if (item.hasKey("lat")) item.getDouble("lat") else continue
    val lon = if (item.hasKey("lon")) item.getDouble("lon") else continue
    out.add(Point(lat, lon))
  }
  return out
}

internal class PressEvent(
  surfaceId: Int,
  viewTag: Int,
  private val name: String,
) : Event<PressEvent>(surfaceId, viewTag) {
  override fun getEventName(): String = name
  override fun getEventData(): com.facebook.react.bridge.WritableMap = Arguments.createMap()
}
