package com.yandexmap

import android.content.Context
import android.graphics.Color
import android.widget.FrameLayout
import com.yandex.mapkit.geometry.Circle as YMKCircleGeom
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.map.CircleMapObject
import com.yandex.mapkit.map.Map as YMKMap
import com.yandex.mapkit.map.MapObjectTapListener

class YandexMapCircleView(context: Context) : FrameLayout(context) {

  init {
    visibility = android.view.View.GONE
  }

  private var pendingCenter: Point = Point(0.0, 0.0)
  private var pendingRadius: Float = 0f
  private var pendingFillColor: Int = Color.TRANSPARENT
  private var pendingStrokeColor: Int = Color.BLACK
  private var pendingStrokeWidth: Float = 1f
  private var pendingZIndex: Float = 0f

  private var attachedMap: YMKMap? = null
  private var circle: CircleMapObject? = null

  private val tapListener = MapObjectTapListener { _, _ ->
    onCirclePress?.invoke()
    true
  }

  var onCirclePress: (() -> Unit)? = null

  fun setCircleCenter(lat: Double, lon: Double) {
    pendingCenter = Point(lat, lon)
    refreshGeometry()
  }

  fun setCircleRadius(radius: Float) {
    pendingRadius = radius
    refreshGeometry()
  }

  fun setCircleFillColor(color: Int?) {
    if (color == null) return
    pendingFillColor = color
    circle?.setFillColor(color)
  }

  fun setCircleStrokeColor(color: Int?) {
    if (color == null) return
    pendingStrokeColor = color
    circle?.setStrokeColor(color)
  }

  fun setCircleStrokeWidth(width: Float) {
    if (width > 0f) {
      pendingStrokeWidth = width
      circle?.setStrokeWidth(width)
    }
  }

  fun setCircleZIndex(z: Float) {
    pendingZIndex = z
    circle?.zIndex = z
  }

  fun attachToMap(map: YMKMap) {
    if (circle != null) return
    if (pendingRadius <= 0f) return
    attachedMap = map
    circle = map.mapObjects.addCircle(
      YMKCircleGeom(pendingCenter, pendingRadius),
    ).apply {
      setFillColor(pendingFillColor)
      setStrokeColor(pendingStrokeColor)
      setStrokeWidth(pendingStrokeWidth)
      if (pendingZIndex != 0f) zIndex = pendingZIndex
      addTapListener(tapListener)
    }
  }

  fun detachFromMap() {
    circle?.let { c ->
      c.removeTapListener(tapListener)
      attachedMap?.mapObjects?.remove(c)
    }
    circle = null
    attachedMap = null
  }

  override fun onDetachedFromWindow() {
    detachFromMap()
    super.onDetachedFromWindow()
  }

  private fun refreshGeometry() {
    if (pendingRadius <= 0f) return
    circle?.geometry = YMKCircleGeom(pendingCenter, pendingRadius)
  }
}
