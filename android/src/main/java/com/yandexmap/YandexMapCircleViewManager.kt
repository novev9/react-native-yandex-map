package com.yandexmap

import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.YandexMapCircleManagerDelegate
import com.facebook.react.viewmanagers.YandexMapCircleManagerInterface

@ReactModule(name = YandexMapCircleViewManager.NAME)
class YandexMapCircleViewManager :
  SimpleViewManager<YandexMapCircleView>(),
  YandexMapCircleManagerInterface<YandexMapCircleView> {

  private val mDelegate: ViewManagerDelegate<YandexMapCircleView> =
    YandexMapCircleManagerDelegate(this)

  override fun getDelegate(): ViewManagerDelegate<YandexMapCircleView> = mDelegate

  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): YandexMapCircleView {
    val view = YandexMapCircleView(context)
    view.onCirclePress = {
      UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
        ?.dispatchEvent(PressEvent(context.surfaceId, view.id, "topCirclePress"))
    }
    return view
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "topCirclePress" to mapOf("registrationName" to "onCirclePress"),
    )

  @ReactProp(name = "center")
  override fun setCenter(view: YandexMapCircleView, value: ReadableMap?) {
    if (value == null) return
    val lat = if (value.hasKey("lat")) value.getDouble("lat") else return
    val lon = if (value.hasKey("lon")) value.getDouble("lon") else return
    view.setCircleCenter(lat, lon)
  }

  @ReactProp(name = "radius")
  override fun setRadius(view: YandexMapCircleView, value: Float) {
    view.setCircleRadius(value)
  }

  @ReactProp(name = "fillColor", customType = "Color")
  override fun setFillColor(view: YandexMapCircleView, value: Int?) {
    view.setCircleFillColor(value)
  }

  @ReactProp(name = "strokeColor", customType = "Color")
  override fun setStrokeColor(view: YandexMapCircleView, value: Int?) {
    view.setCircleStrokeColor(value)
  }

  @ReactProp(name = "strokeWidth")
  override fun setStrokeWidth(view: YandexMapCircleView, value: Float) {
    view.setCircleStrokeWidth(value)
  }

  @ReactProp(name = "placemarkZIndex")
  override fun setPlacemarkZIndex(view: YandexMapCircleView, value: Float) {
    view.setCircleZIndex(value)
  }

  companion object {
    const val NAME = "YandexMapCircle"
  }
}
