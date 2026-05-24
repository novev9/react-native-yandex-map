package com.yandexmap

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import com.yandex.mapkit.geometry.BoundingBox
import com.yandex.mapkit.geometry.Geometry
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.search.Response
import com.yandex.mapkit.search.SearchFactory
import com.yandex.mapkit.search.SearchManager
import com.yandex.mapkit.search.SearchManagerType
import com.yandex.mapkit.search.SearchOptions
import com.yandex.mapkit.search.SearchType
import com.yandex.mapkit.search.Session
import com.yandex.mapkit.search.ToponymObjectMetadata
import com.yandex.mapkit.uri.UriObjectMetadata
import com.yandex.runtime.Error

@ReactModule(name = YandexSearchModule.NAME)
class YandexSearchModule(reactContext: ReactApplicationContext) :
  NativeYandexSearchModuleSpec(reactContext) {

  private var manager: SearchManager? = null
  private val pending = mutableListOf<Session>()

  override fun getName(): String = NAME

  private fun ensureManager(): SearchManager {
    val existing = manager
    if (existing != null) return existing
    YandexMapModule.ensureInitialisedFromManifest(reactApplicationContext)
    val m = SearchFactory.getInstance()
      .createSearchManager(SearchManagerType.COMBINED)
    manager = m
    return m
  }

  override fun searchByText(
    query: String,
    viewport: ReadableMap?,
    options: ReadableMap?,
    promise: Promise,
  ) {
    if (query.isBlank()) {
      promise.reject("YANDEX_SEARCH_NO_QUERY", "query is empty")
      return
    }
    UiThreadUtil.runOnUiThread {
      try {
        val geometry = geometryFromViewport(viewport)
        val opts = optionsFromMap(options)
        val mgr = ensureManager()
        var session: Session? = null
        session = mgr.submit(query, geometry, opts, object : Session.SearchListener {
          override fun onSearchResponse(response: Response) {
            session?.let { pending.remove(it) }
            promise.resolve(hitsFromResponse(response))
          }
          override fun onSearchError(error: Error) {
            session?.let { pending.remove(it) }
            promise.reject("YANDEX_SEARCH_FAILED", error.toString())
          }
        })
        pending.add(session)
      } catch (e: Throwable) {
        promise.reject("YANDEX_SEARCH_FAILED", e.message ?: "search failed", e)
      }
    }
  }

  override fun resolveUri(uri: String, promise: Promise) {
    if (uri.isBlank()) {
      promise.resolve(null)
      return
    }
    UiThreadUtil.runOnUiThread {
      try {
        val opts = SearchOptions()
        val mgr = ensureManager()
        var session: Session? = null
        session = mgr.resolveURI(uri, opts, object : Session.SearchListener {
          override fun onSearchResponse(response: Response) {
            session?.let { pending.remove(it) }
            val firstHit = firstHitFromResponse(response)
            if (firstHit != null) promise.resolve(firstHit) else promise.resolve(null)
          }
          override fun onSearchError(error: Error) {
            session?.let { pending.remove(it) }
            promise.reject("YANDEX_RESOLVE_URI_FAILED", error.toString())
          }
        })
        pending.add(session)
      } catch (e: Throwable) {
        promise.reject("YANDEX_RESOLVE_URI_FAILED", e.message ?: "resolve uri failed", e)
      }
    }
  }

  override fun geocodePoint(point: ReadableMap, promise: Promise) {
    val lat = if (point.hasKey("lat")) point.getDouble("lat") else 0.0
    val lon = if (point.hasKey("lon")) point.getDouble("lon") else 0.0
    UiThreadUtil.runOnUiThread {
      try {
        val opts = SearchOptions().apply {
          searchTypes = SearchType.GEO.value
          resultPageSize = 1
        }
        val mgr = ensureManager()
        var session: Session? = null
        session = mgr.submit(Point(lat, lon), 18, opts, object : Session.SearchListener {
          override fun onSearchResponse(response: Response) {
            session?.let { pending.remove(it) }
            // Build a single WritableMap directly — getMap() returns
            // ReadableNativeMap which crashes Bridgeless Promise.resolve.
            val firstHit = firstHitFromResponse(response)
            if (firstHit != null) promise.resolve(firstHit) else promise.resolve(null)
          }
          override fun onSearchError(error: Error) {
            session?.let { pending.remove(it) }
            promise.reject("YANDEX_GEOCODE_FAILED", error.toString())
          }
        })
        pending.add(session)
      } catch (e: Throwable) {
        promise.reject("YANDEX_GEOCODE_FAILED", e.message ?: "geocode failed", e)
      }
    }
  }

  private fun firstHitFromResponse(response: Response): WritableMap? {
    for (item in response.collection.children) {
      val obj = item.obj ?: continue
      val point = pickPoint(obj) ?: continue
      return buildHit(obj, point)
    }
    return null
  }

  private fun geometryFromViewport(viewport: ReadableMap?): Geometry {
    if (viewport == null) {
      return Geometry.fromBoundingBox(
        BoundingBox(Point(-85.0, -180.0), Point(85.0, 180.0))
      )
    }
    val sw = viewport.getMap("southWest")
    val ne = viewport.getMap("northEast")
    if (sw == null || ne == null) {
      return Geometry.fromBoundingBox(
        BoundingBox(Point(-85.0, -180.0), Point(85.0, 180.0))
      )
    }
    return Geometry.fromBoundingBox(
      BoundingBox(
        Point(sw.getDouble("lat"), sw.getDouble("lon")),
        Point(ne.getDouble("lat"), ne.getDouble("lon")),
      ),
    )
  }

  private fun optionsFromMap(options: ReadableMap?): SearchOptions {
    val opts = SearchOptions()
    opts.searchTypes = if (options?.hasKey("searchType") == true) {
      options.getInt("searchType")
    } else {
      SearchType.GEO.value
    }
    if (options?.hasKey("resultPageSize") == true) {
      opts.resultPageSize = options.getInt("resultPageSize")
    }
    if (options?.hasKey("disableSpellingCorrection") == true &&
      options.getBoolean("disableSpellingCorrection")) {
      opts.disableSpellingCorrection = true
    }
    val userPos = options?.takeIf { it.hasKey("userPosition") }?.getMap("userPosition")
    if (userPos != null &&
      userPos.hasKey("lat") && userPos.hasKey("lon") &&
      !userPos.isNull("lat") && !userPos.isNull("lon")
    ) {
      opts.userPosition = Point(userPos.getDouble("lat"), userPos.getDouble("lon"))
    }
    return opts
  }

  private fun buildHit(obj: com.yandex.mapkit.GeoObject, point: Point): WritableMap {
    val uri = pickUri(obj) ?: ""
    return Arguments.createMap().apply {
      putString("title", obj.name ?: "")
      putString("subtitle", obj.descriptionText ?: "")
      putString("uri", uri)
      putMap("point", Arguments.createMap().apply {
        putDouble("lat", point.latitude)
        putDouble("lon", point.longitude)
      })
    }
  }

  private fun hitsFromResponse(response: Response): com.facebook.react.bridge.WritableArray {
    val arr = Arguments.createArray()
    for (item in response.collection.children) {
      val obj = item.obj ?: continue
      val point = pickPoint(obj) ?: continue
      val hit = buildHit(obj, point)
      arr.pushMap(hit)
    }
    return arr
  }

  private fun pickPoint(obj: com.yandex.mapkit.GeoObject): Point? {
    val toponym = obj.metadataContainer.getItem(ToponymObjectMetadata::class.java)
    if (toponym != null) return toponym.balloonPoint
    for (g in obj.geometry) {
      if (g.point != null) return g.point
      if (g.boundingBox != null) {
        val sw = g.boundingBox!!.southWest
        val ne = g.boundingBox!!.northEast
        return Point(
          (sw.latitude + ne.latitude) / 2.0,
          (sw.longitude + ne.longitude) / 2.0,
        )
      }
    }
    return null
  }

  private fun pickUri(obj: com.yandex.mapkit.GeoObject): String? {
    val uriMeta = obj.metadataContainer.getItem(UriObjectMetadata::class.java)
      ?: return null
    return uriMeta.uris.firstOrNull()?.value
  }

  companion object {
    const val NAME = "YandexSearchModule"
  }
}
