package com.yandexmap

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.module.annotations.ReactModule
import com.yandex.mapkit.geometry.BoundingBox
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.search.SearchFactory
import com.yandex.mapkit.search.SearchManager
import com.yandex.mapkit.search.SearchManagerType
import com.yandex.mapkit.search.SuggestItem
import com.yandex.mapkit.search.SuggestOptions
import com.yandex.mapkit.search.SuggestResponse
import com.yandex.mapkit.search.SuggestSession
import com.yandex.mapkit.search.SuggestType
import com.yandex.runtime.Error

@ReactModule(name = YandexSuggestModule.NAME)
class YandexSuggestModule(reactContext: ReactApplicationContext) :
  NativeYandexSuggestModuleSpec(reactContext) {

  private var manager: SearchManager? = null
  private var session: SuggestSession? = null

  override fun getName(): String = NAME

  private fun ensureSession(): SuggestSession {
    val existing = session
    if (existing != null) return existing
    YandexMapModule.ensureInitialisedFromManifest(reactApplicationContext)
    if (manager == null) {
      manager = SearchFactory.getInstance()
        .createSearchManager(SearchManagerType.COMBINED)
    }
    val s = manager!!.createSuggestSession()
    session = s
    return s
  }

  override fun suggest(
    query: String,
    viewport: ReadableMap,
    options: ReadableMap?,
    promise: Promise,
  ) {
    val sw = viewport.getMap("southWest")
    val ne = viewport.getMap("northEast")
    if (sw == null || ne == null) {
      promise.reject("YANDEX_SUGGEST_NO_VIEWPORT", "viewport is required")
      return
    }
    val box = BoundingBox(
      Point(sw.getDouble("lat"), sw.getDouble("lon")),
      Point(ne.getDouble("lat"), ne.getDouble("lon")),
    )
    val opts = SuggestOptions().apply {
      suggestTypes = if (options?.hasKey("suggestTypes") == true) {
        options.getInt("suggestTypes")
      } else {
        SuggestType.GEO.value
      }
      if (options?.hasKey("suggestWords") == true &&
        options.getBoolean("suggestWords")) {
        suggestWords = true
      }
      if (options?.hasKey("strictBounds") == true &&
        options.getBoolean("strictBounds")) {
        strictBounds = true
      }
      val userPos = options?.takeIf { it.hasKey("userPosition") }?.getMap("userPosition")
      if (userPos != null &&
        userPos.hasKey("lat") && userPos.hasKey("lon") &&
        !userPos.isNull("lat") && !userPos.isNull("lon")
      ) {
        userPosition = Point(userPos.getDouble("lat"), userPos.getDouble("lon"))
      }
    }

    UiThreadUtil.runOnUiThread {
      try {
        ensureSession().suggest(query, box, opts, object : SuggestSession.SuggestListener {
          override fun onResponse(response: SuggestResponse) {
            val arr = Arguments.createArray()
            for (item in response.items) {
              arr.pushMap(itemToMap(item))
            }
            promise.resolve(arr)
          }
          override fun onError(error: Error) {
            promise.reject("YANDEX_SUGGEST_FAILED", error.toString())
          }
        })
      } catch (e: Throwable) {
        promise.reject("YANDEX_SUGGEST_FAILED", e.message ?: "suggest failed", e)
      }
    }
  }

  override fun reset(promise: Promise) {
    UiThreadUtil.runOnUiThread {
      try {
        session?.reset()
        promise.resolve(null)
      } catch (e: Throwable) {
        promise.reject("YANDEX_SUGGEST_RESET_FAILED", e.message ?: "reset failed", e)
      }
    }
  }

  private fun itemToMap(item: SuggestItem) = Arguments.createMap().apply {
    putString("title", item.title.text ?: "")
    putString("subtitle", item.subtitle?.text ?: "")
    putString("uri", item.uri ?: "")
  }

  companion object {
    const val NAME = "YandexSuggestModule"
  }
}
