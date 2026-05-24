package com.yandexmap

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.YandexMapPolygonManagerDelegate
import com.facebook.react.viewmanagers.YandexMapPolygonManagerInterface

@ReactModule(name = YandexMapPolygonViewManager.NAME)
class YandexMapPolygonViewManager :
  SimpleViewManager<YandexMapPolygonView>(),
  YandexMapPolygonManagerInterface<YandexMapPolygonView> {

  private val mDelegate: ViewManagerDelegate<YandexMapPolygonView> =
    YandexMapPolygonManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<YandexMapPolygonView> = mDelegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): YandexMapPolygonView {
    val view = YandexMapPolygonView(context)
    view.onPolygonPress = {
      UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
        ?.dispatchEvent(PressEvent(context.surfaceId, view.id, "topPolygonPress"))
    }
    return view
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topPolygonPress" to mapOf("registrationName" to "onPolygonPress"),
    )

  @ReactProp(name = "points")
  override fun setPoints(view: YandexMapPolygonView, value: ReadableArray?) {
    view.setPolygonPoints(value.toPointList())
  }

  @ReactProp(name = "fillColor", customType = "Color")
  override fun setFillColor(view: YandexMapPolygonView, value: Int?) {
    view.setPolygonFillColor(value)
  }

  @ReactProp(name = "strokeColor", customType = "Color")
  override fun setStrokeColor(view: YandexMapPolygonView, value: Int?) {
    view.setPolygonStrokeColor(value)
  }

  @ReactProp(name = "strokeWidth")
  override fun setStrokeWidth(view: YandexMapPolygonView, value: Float) {
    view.setPolygonStrokeWidth(value)
  }

  @ReactProp(name = "placemarkZIndex")
  override fun setPlacemarkZIndex(view: YandexMapPolygonView, value: Float) {
    view.setPolygonZIndex(value)
  }

  companion object {
    const val NAME = "YandexMapPolygon"
  }
}
