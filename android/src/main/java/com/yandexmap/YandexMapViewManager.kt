package com.yandexmap

import android.graphics.Color
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.YandexMapViewManagerInterface
import com.facebook.react.viewmanagers.YandexMapViewManagerDelegate

@ReactModule(name = YandexMapViewManager.NAME)
class YandexMapViewManager : SimpleViewManager<YandexMapView>(),
  YandexMapViewManagerInterface<YandexMapView> {
  private val mDelegate: ViewManagerDelegate<YandexMapView>

  init {
    mDelegate = YandexMapViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<YandexMapView>? {
    return mDelegate
  }

  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): YandexMapView {
    return YandexMapView(context)
  }

  @ReactProp(name = "color")
  override fun setColor(view: YandexMapView?, color: Int?) {
    view?.setBackgroundColor(color ?: Color.TRANSPARENT)
  }

  companion object {
    const val NAME = "YandexMapView"
  }
}
