package com.yandexmap

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

class YandexMapViewPackage : BaseReactPackage() {
  override fun createViewManagers(
    reactContext: ReactApplicationContext,
  ): List<ViewManager<*, *>> = listOf(
    YandexMapViewManager(),
    YandexMapMarkerViewManager(),
    YandexMapPolylineViewManager(),
    YandexMapPolygonViewManager(),
    YandexMapCircleViewManager(),
    YandexMapClusteredMarkersViewManager(),
  )

  override fun getModule(
    name: String,
    reactContext: ReactApplicationContext,
  ): NativeModule? = when (name) {
    YandexMapModule.NAME -> YandexMapModule(reactContext)
    YandexSearchModule.NAME -> YandexSearchModule(reactContext)
    YandexSuggestModule.NAME -> YandexSuggestModule(reactContext)
    else -> null
  }

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider =
    ReactModuleInfoProvider {
      mapOf(
        YandexMapModule.NAME to turboModuleInfo(YandexMapModule.NAME, YandexMapModule::class.java),
        YandexSearchModule.NAME to turboModuleInfo(YandexSearchModule.NAME, YandexSearchModule::class.java),
        YandexSuggestModule.NAME to turboModuleInfo(YandexSuggestModule.NAME, YandexSuggestModule::class.java),
      )
    }

  private fun turboModuleInfo(name: String, cls: Class<*>) = ReactModuleInfo(
    name,
    cls.name,
    false, // canOverrideExistingModule
    false, // needsEagerInit
    false, // isCxxModule
    true, // isTurboModule
  )
}
