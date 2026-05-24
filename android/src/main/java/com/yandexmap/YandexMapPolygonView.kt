package com.yandexmap

import android.content.Context
import android.widget.FrameLayout
import com.yandex.mapkit.geometry.LinearRing
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.geometry.Polygon as YMKPolygonGeom
import com.yandex.mapkit.map.Map as YMKMap
import com.yandex.mapkit.map.MapObjectTapListener
import com.yandex.mapkit.map.PolygonMapObject

class YandexMapPolygonView(context: Context) : FrameLayout(context) {

  init {
    visibility = android.view.View.GONE
  }

  private var pendingPoints: List<Point> = emptyList()
  private var pendingFillColor: Int? = null
  private var pendingStrokeColor: Int? = null
  private var pendingStrokeWidth: Float = 0f
  private var pendingZIndex: Float = 0f

  private var attachedMap: YMKMap? = null
  private var polygon: PolygonMapObject? = null

  private val tapListener = MapObjectTapListener { _, _ ->
    onPolygonPress?.invoke()
    true
  }

  var onPolygonPress: (() -> Unit)? = null

  fun setPolygonPoints(points: List<Point>) {
    pendingPoints = points
    polygon?.let { p ->
      if (points.size >= 3) {
        p.geometry = YMKPolygonGeom(LinearRing(points), emptyList())
      }
    }
  }

  fun setPolygonFillColor(color: Int?) {
    pendingFillColor = color
    color?.let { polygon?.setFillColor(it) }
  }

  fun setPolygonStrokeColor(color: Int?) {
    pendingStrokeColor = color
    color?.let { polygon?.setStrokeColor(it) }
  }

  fun setPolygonStrokeWidth(width: Float) {
    pendingStrokeWidth = width
    if (width > 0f) polygon?.setStrokeWidth(width)
  }

  fun setPolygonZIndex(z: Float) {
    pendingZIndex = z
    polygon?.zIndex = z
  }

  fun attachToMap(map: YMKMap) {
    if (polygon != null) return
    if (pendingPoints.size < 3) return
    attachedMap = map
    polygon = map.mapObjects.addPolygon(
      YMKPolygonGeom(LinearRing(pendingPoints), emptyList()),
    ).apply {
      pendingFillColor?.let { setFillColor(it) }
      pendingStrokeColor?.let { setStrokeColor(it) }
      if (pendingStrokeWidth > 0f) setStrokeWidth(pendingStrokeWidth)
      if (pendingZIndex != 0f) zIndex = pendingZIndex
      addTapListener(tapListener)
    }
  }

  fun detachFromMap() {
    polygon?.let { p ->
      p.removeTapListener(tapListener)
      attachedMap?.mapObjects?.remove(p)
    }
    polygon = null
    attachedMap = null
  }

  override fun onDetachedFromWindow() {
    detachFromMap()
    super.onDetachedFromWindow()
  }
}
