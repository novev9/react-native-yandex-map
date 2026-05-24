package com.yandexmap

import android.content.Context
import android.graphics.Color
import android.widget.FrameLayout
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.geometry.Polyline as YMKPolylineGeom
import com.yandex.mapkit.map.Map as YMKMap
import com.yandex.mapkit.map.MapObject
import com.yandex.mapkit.map.MapObjectTapListener
import com.yandex.mapkit.map.PolylineMapObject

class YandexMapPolylineView(context: Context) : FrameLayout(context) {

  init {
    visibility = android.view.View.GONE
  }

  private var pendingPoints: List<Point> = emptyList()
  private var pendingStrokeColor: Int? = null
  private var pendingStrokeWidth: Float = 0f
  private var pendingZIndex: Float = 0f

  private var attachedMap: YMKMap? = null
  private var polyline: PolylineMapObject? = null

  private val tapListener = MapObjectTapListener { _, _ ->
    onPolylinePress?.invoke()
    true
  }

  var onPolylinePress: (() -> Unit)? = null

  fun setPolylinePoints(points: List<Point>) {
    pendingPoints = points
    if (points.size >= 2) {
      polyline?.geometry = YMKPolylineGeom(points)
    }
  }

  fun setPolylineStrokeColor(color: Int?) {
    pendingStrokeColor = color
    color?.let { polyline?.setStrokeColor(it) }
  }

  fun setPolylineStrokeWidth(width: Float) {
    pendingStrokeWidth = width
    if (width > 0f) polyline?.setStrokeWidth(width)
  }

  fun setPolylineZIndex(z: Float) {
    pendingZIndex = z
    polyline?.zIndex = z
  }

  fun attachToMap(map: YMKMap) {
    if (polyline != null) return
    if (pendingPoints.size < 2) return
    attachedMap = map
    polyline = map.mapObjects.addPolyline(YMKPolylineGeom(pendingPoints)).apply {
      pendingStrokeColor?.let { setStrokeColor(it) }
      if (pendingStrokeWidth > 0f) setStrokeWidth(pendingStrokeWidth)
      if (pendingZIndex != 0f) zIndex = pendingZIndex
      addTapListener(tapListener)
    }
  }

  fun detachFromMap() {
    polyline?.let { p ->
      p.removeTapListener(tapListener)
      attachedMap?.mapObjects?.remove(p)
    }
    polyline = null
    attachedMap = null
  }

  override fun onDetachedFromWindow() {
    detachFromMap()
    super.onDetachedFromWindow()
  }
}
