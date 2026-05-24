package com.yandexmap

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.PointF
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.map.IconStyle
import com.yandex.mapkit.map.Map as YMKMap
import com.yandex.mapkit.map.MapObjectTapListener
import com.yandex.mapkit.map.PlacemarkMapObject
import com.yandex.runtime.image.ImageProvider
import java.net.URL

class YandexMapMarkerView(context: Context) : FrameLayout(context) {

  init {
    // We need the host visible (`View.VISIBLE`) so `draw(canvas)` works in the
    // snapshot pipeline. Fabric SurfaceMountingManager overrides `visibility`
    // anyway based on Yoga display, so setting INVISIBLE here would just be
    // reset to VISIBLE. To keep the marker visually invisible we translate it
    // far offscreen — its bitmap snapshot then drives the placemark icon.
    translationX = -100000f
    translationY = -100000f
  }

  private var pendingPoint: Point = Point(0.0, 0.0)
  private var pendingIconUri: String? = null
  private var pendingZIndex: Float = 0f
  private var pendingScale: Float = 1f
  private var pendingAnchorX: Float = 0.5f
  private var pendingAnchorY: Float = 0.5f
  private var pendingVisible: Boolean = true

  private var attachedMap: YMKMap? = null
  private var placemark: PlacemarkMapObject? = null
  private var currentIconUri: String? = null

  private var useSnapshotMode: Boolean = false
  private var snapshotPending: Boolean = false
  private var lastSnapshotW: Int = 0
  private var lastSnapshotH: Int = 0

  private val tapListener = MapObjectTapListener { _, _ ->
    onMarkerPress?.invoke()
    true
  }

  var onMarkerPress: (() -> Unit)? = null

  fun setPoint(lat: Double, lon: Double) {
    pendingPoint = Point(lat, lon)
    placemark?.geometry = pendingPoint
  }

  fun setIconUri(uri: String?) {
    pendingIconUri = uri
    if (!useSnapshotMode) applyIconIfChanged()
  }

  fun setMarkerZIndex(value: Float) {
    pendingZIndex = value
    placemark?.zIndex = value
  }

  fun setScale(value: Float) {
    pendingScale = value
    placemark?.setIconStyle(currentIconStyle())
  }

  fun setAnchor(x: Float, y: Float) {
    pendingAnchorX = x
    pendingAnchorY = y
    placemark?.setIconStyle(currentIconStyle())
  }

  private fun currentIconStyle(): IconStyle = IconStyle().apply {
    anchor = PointF(pendingAnchorX, pendingAnchorY)
    scale = if (pendingScale > 0) pendingScale else 1f
  }

  fun setMarkerVisible(value: Boolean) {
    pendingVisible = value
    placemark?.isVisible = value
  }

  fun attachToMap(map: YMKMap) {
    if (placemark != null) return
    attachedMap = map
    placemark = map.mapObjects.addPlacemark(pendingPoint).apply {
      isVisible = pendingVisible
      zIndex = pendingZIndex
      addTapListener(tapListener)
    }
    if (useSnapshotMode) {
      scheduleSnapshot()
    } else {
      applyIconIfChanged()
    }
  }

  fun detachFromMap() {
    placemark?.let { p ->
      p.removeTapListener(tapListener)
      attachedMap?.mapObjects?.remove(p)
    }
    placemark = null
    attachedMap = null
    currentIconUri = null
    lastSnapshotW = 0
    lastSnapshotH = 0
  }

  // -- Child management ------------------------------------------------------

  override fun onViewAdded(child: View?) {
    super.onViewAdded(child)
    useSnapshotMode = true
    scheduleSnapshot()
  }

  override fun onViewRemoved(child: View?) {
    super.onViewRemoved(child)
    if (childCount == 0) useSnapshotMode = false
  }

  override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    super.onLayout(changed, l, t, r, b)
    // Re-apply offscreen translation — Fabric's SurfaceMountingManager resets
    // translation on each layout pass, so we have to push it back every time.
    translationX = -100000f
    translationY = -100000f
    if (useSnapshotMode) {
      val w = r - l
      val h = b - t
      if (w > 0 && h > 0 && (w != lastSnapshotW || h != lastSnapshotH)) {
        scheduleSnapshot()
      }
    }
  }

  override fun onDetachedFromWindow() {
    detachFromMap()
    super.onDetachedFromWindow()
  }

  // -- Icon pipelines --------------------------------------------------------

  private fun applyIconIfChanged() {
    val uri = pendingIconUri
    if (uri == null || uri == currentIconUri) return
    currentIconUri = uri
    Thread {
      val bitmap = loadBitmap(uri)
      if (bitmap != null) {
        Handler(Looper.getMainLooper()).post {
          if (pendingIconUri == uri && !useSnapshotMode) {
            placemark?.setIcon(ImageProvider.fromBitmap(bitmap), currentIconStyle())
          }
        }
      } else {
        if (pendingIconUri == uri) currentIconUri = null
      }
    }.start()
  }

  private fun scheduleSnapshot() {
    if (snapshotPending) return
    snapshotPending = true
    post {
      snapshotPending = false
      captureSnapshot()
    }
  }

  private fun captureSnapshot() {
    if (!useSnapshotMode) return
    val p = placemark ?: return
    val w = width
    val h = height
    if (w <= 0 || h <= 0) return
    val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    // draw the (invisible) view tree into our canvas
    draw(canvas)
    lastSnapshotW = w
    lastSnapshotH = h
    p.setIcon(ImageProvider.fromBitmap(bitmap), currentIconStyle())
  }

  private fun loadBitmap(uri: String): Bitmap? = try {
    when {
      uri.startsWith("http://") || uri.startsWith("https://") -> {
        URL(uri).openStream().use { BitmapFactory.decodeStream(it) }
      }
      uri.startsWith("file://") -> {
        val path = Uri.parse(uri).path ?: return null
        BitmapFactory.decodeFile(path)
      }
      else -> {
        val resId = context.resources.getIdentifier(
          uri,
          "drawable",
          context.packageName,
        )
        if (resId != 0) BitmapFactory.decodeResource(context.resources, resId) else null
      }
    }
  } catch (_: Throwable) {
    null
  }
}
