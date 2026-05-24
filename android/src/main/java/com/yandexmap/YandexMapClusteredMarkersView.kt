package com.yandexmap

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.net.Uri
import android.text.TextPaint
import android.os.Handler
import android.os.Looper
import android.widget.FrameLayout
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.map.Cluster
import com.yandex.mapkit.map.ClusterListener
import com.yandex.mapkit.map.ClusterTapListener
import com.yandex.mapkit.map.ClusterizedPlacemarkCollection
import com.yandex.mapkit.map.IconStyle
import com.yandex.mapkit.map.Map as YMKMap
import com.yandex.runtime.image.ImageProvider
import java.net.URL

class YandexMapClusteredMarkersView(context: Context) :
  FrameLayout(context),
  ClusterListener,
  ClusterTapListener {

  init {
    visibility = android.view.View.GONE
  }

  var pendingPoints: List<Point> = emptyList()
  var pendingPointLabels: List<String> = emptyList()
  var pendingMarkerIconUri: String? = null
  // null → use count-based palette; non-null → user-supplied override.
  var pendingClusterColor: Int? = null
  var pendingClusterTextColor: Int? = null
  var pendingClusterRadius: Float = 60f
  var pendingClusterMinZoom: Int = 15

  private val labelIconCache = mutableMapOf<String, Bitmap>()

  var onClusterPress: ((
    size: Int,
    lat: Double,
    lon: Double,
    swLat: Double,
    swLon: Double,
    neLat: Double,
    neLon: Double,
  ) -> Unit)? = null

  private var attachedMap: YMKMap? = null
  private var collection: ClusterizedPlacemarkCollection? = null
  private var markerBitmap: Bitmap? = null
  private var markerLoadingUri: String? = null
  private var rebuildScheduled: Boolean = false

  fun attachToMap(map: YMKMap) {
    if (collection != null) return
    attachedMap = map
    collection = map.mapObjects.addClusterizedPlacemarkCollection(this)
    scheduleRebuild()
  }

  fun detachFromMap() {
    collection?.let { c ->
      attachedMap?.mapObjects?.remove(c)
    }
    collection = null
    attachedMap = null
    markerBitmap = null
    markerLoadingUri = null
  }

  fun scheduleRebuild() {
    if (rebuildScheduled) return
    rebuildScheduled = true
    post {
      rebuildScheduled = false
      rebuildPlacemarks()
    }
  }

  override fun onDetachedFromWindow() {
    detachFromMap()
    super.onDetachedFromWindow()
  }

  private fun rebuildPlacemarks() {
    val c = collection ?: return
    c.clear()
    val points = pendingPoints
    val labels = pendingPointLabels
    val uri = pendingMarkerIconUri
    val onReady: (Bitmap?) -> Unit = { bitmap ->
      if (bitmap != null) markerBitmap = bitmap
      val active = collection
      if (active != null) {
        val hasLabels = labels.size == points.size && points.isNotEmpty()
        if (hasLabels) {
          // Per-placemark icon — bitmap cached per label string.
          for (i in points.indices) {
            val label = labels[i]
            val icon = pillBitmapForLabel(label)
            val placemark = active.addPlacemark(points[i])
            placemark.setIcon(ImageProvider.fromBitmap(icon))
          }
        } else {
          val provider = markerBitmap?.let { ImageProvider.fromBitmap(it) }
          if (provider != null) {
            active.addPlacemarks(points, provider, IconStyle())
          } else {
            for (p in points) active.addPlacemark(p)
          }
        }
        active.clusterPlacemarks(pendingClusterRadius.toDouble(), pendingClusterMinZoom)
      }
    }

    if (uri == null) {
      // Tiny default dot — only briefly visible at full zoom-in. Clusters
      // do the heavy lifting for the city view.
      if (markerBitmap == null) markerBitmap = renderDotBitmap()
      onReady(null)
      return
    }
    if (markerBitmap != null) {
      onReady(null)
      return
    }
    markerLoadingUri = uri
    Thread {
      val bitmap = loadBitmap(uri)
      Handler(Looper.getMainLooper()).post {
        if (markerLoadingUri == uri && collection != null) {
          onReady(bitmap)
        }
      }
    }.start()
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
        val resId = context.resources.getIdentifier(uri, "drawable", context.packageName)
        if (resId != 0) BitmapFactory.decodeResource(context.resources, resId) else null
      }
    }
  } catch (_: Throwable) {
    null
  }

  // Count-aware cluster: bigger + warmer color for denser groups, soft shadow
  // + white ring for contrast over light/dark map themes.
  private fun renderClusterBitmap(size: Int): Bitmap {
    val density = context.resources.displayMetrics.density
    val (diameterDp, defaultFill) = when {
      size < 8 -> 44 to Color.parseColor("#39BD6E")   // green
      size < 20 -> 52 to Color.parseColor("#2563EB")  // blue
      size < 40 -> 62 to Color.parseColor("#F58C1A")  // orange
      else -> 72 to Color.parseColor("#E84D3D")        // red
    }
    // User-supplied `clusterColor`/`clusterTextColor` override the count-based
    // palette but keep the count-based size so denser clusters still read big.
    val fillColor = pendingClusterColor ?: defaultFill
    val textColor = pendingClusterTextColor ?: Color.WHITE
    val diameter = diameterDp * density
    val shadow = 6 * density
    val canvasSize = (diameter + shadow * 2).toInt()
    val bitmap = Bitmap.createBitmap(canvasSize, canvasSize, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val cx = canvasSize / 2f
    val cy = canvasSize / 2f
    val r = diameter / 2f

    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = fillColor
      style = Paint.Style.FILL
      setShadowLayer(shadow, 0f, 2 * density, Color.argb(90, 0, 0, 0))
    }
    // setShadowLayer needs SOFTWARE layer on FrameLayout — we draw straight to
    // bitmap so it works.
    canvas.drawCircle(cx, cy, r, fill)

    val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeWidth = 3 * density
    }
    canvas.drawCircle(cx, cy, r - 1.5f * density, ring)

    val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = textColor
      textAlign = Paint.Align.CENTER
      textSize = diameter * 0.34f
      typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    val baseline = cy - (text.descent() + text.ascent()) / 2f
    canvas.drawText(size.toString(), cx, baseline, text)
    return bitmap
  }

  // Cached generic "PHOTO" pill, used when no per-point label is supplied.
  private var cachedDot: Bitmap? = null
  private fun renderDotBitmap(): Bitmap {
    cachedDot?.let { return it }
    val bm = renderPillBitmap("PHOTO", uppercase = true)
    cachedDot = bm
    return bm
  }

  // Per-label pill bitmap with caching. Empty string → generic dot.
  private fun pillBitmapForLabel(label: String): Bitmap {
    if (label.isEmpty()) return renderDotBitmap()
    labelIconCache[label]?.let { return it }
    val bm = renderPillBitmap(label, uppercase = false)
    labelIconCache[label] = bm
    return bm
  }

  // Pill-shaped badge — gradient blue with camera glyph + label text.
  // Auto-sizes pill width to fit the label; uppercase mode applies extra
  // letter-spacing for short ALL-CAPS labels like "PHOTO".
  private fun renderPillBitmap(label: String, uppercase: Boolean): Bitmap {
    val density = context.resources.displayMetrics.density
    val height = 36f * density
    val shadow = 5f * density
    val iconWidth = 30f * density   // camera glyph + padding
    val textPadding = 12f * density  // right padding inside pill

    val text = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      textSize = 11f * density
      typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
      letterSpacing = if (uppercase) 0.08f else 0.0f
    }
    val textWidth = text.measureText(label)
    val maxTextWidth = 140f * density
    val usedTextWidth = minOf(textWidth, maxTextWidth)
    val width = iconWidth + usedTextWidth + textPadding

    val canvasW = (width + shadow * 2).toInt()
    val canvasH = (height + shadow * 2).toInt()
    val bitmap = Bitmap.createBitmap(canvasW, canvasH, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val pill = RectF(shadow, shadow, shadow + width, shadow + height)
    val radius = height / 2f

    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
      shader = LinearGradient(
        0f, pill.top, 0f, pill.bottom,
        Color.parseColor("#3B82F6"),
        Color.parseColor("#1D4ED8"),
        Shader.TileMode.CLAMP,
      )
      setShadowLayer(shadow, 0f, 2f * density, Color.argb(72, 0, 0, 0))
    }
    canvas.drawRoundRect(pill, radius, radius, fill)

    val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeWidth = 2 * density
    }
    canvas.drawRoundRect(pill, radius, radius, border)

    val iconCx = pill.left + 17f * density
    val iconCy = pill.centerY()
    val cameraStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeCap = Paint.Cap.ROUND
      strokeWidth = 1.7f * density
    }
    val cameraBody = RectF(
      iconCx - 8f * density,
      iconCy - 5.5f * density,
      iconCx + 8f * density,
      iconCy + 6.5f * density,
    )
    canvas.drawRoundRect(cameraBody, 3f * density, 3f * density, cameraStroke)

    val whiteFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.FILL
    }
    canvas.drawCircle(iconCx, iconCy, 3.2f * density, whiteFill)
    canvas.drawCircle(iconCx + 5.7f * density, iconCy - 2.7f * density, 1.25f * density, whiteFill)

    // Truncate label if longer than maxTextWidth budget.
    val drawn = if (textWidth > maxTextWidth) {
      val ellipsized = android.text.TextUtils.ellipsize(label, text, maxTextWidth,
        android.text.TextUtils.TruncateAt.END).toString()
      ellipsized
    } else label
    val x = pill.left + iconWidth
    val baseline = pill.centerY() - (text.descent() + text.ascent()) / 2f
    canvas.drawText(drawn, x, baseline, text)

    return bitmap
  }

  // Teardrop pin with white camera glyph — kept for future use, currently not
  // wired (was too "flag-like" in the demo, dots + clusters read cleaner).
  private var cachedPhotoPin: Bitmap? = null
  private fun renderPhotoPinBitmap(): Bitmap {
    cachedPhotoPin?.let { return it }
    val density = context.resources.displayMetrics.density
    val width = 36 * density
    val height = 46 * density
    val shadow = 5 * density
    val canvasW = (width + shadow * 2).toInt()
    val canvasH = (height + shadow * 2).toInt()
    val bitmap = Bitmap.createBitmap(canvasW, canvasH, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val accent = Color.parseColor("#2563EB")
    val radius = width / 2f
    val cx = shadow + radius
    val cy = shadow + radius

    val path = Path().apply {
      val box = RectF(shadow, shadow, shadow + width, shadow + width)
      arcTo(box, 225f, 270f, true)
      lineTo(shadow + width / 2f, shadow + height)
      close()
    }

    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = accent
      style = Paint.Style.FILL
      setShadowLayer(shadow, 0f, 2 * density, Color.argb(90, 0, 0, 0))
    }
    canvas.drawPath(path, fill)

    val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeWidth = 2.5f * density
    }
    canvas.drawPath(path, border)

    // Camera body — rounded white rectangle centred on the pin circle.
    val bodyRect = RectF(cx - 9 * density, cy - 6 * density,
                         cx + 9 * density, cy + 6 * density)
    canvas.drawRoundRect(bodyRect, 2.5f * density, 2.5f * density,
      Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.FILL })
    // Lens dot in accent colour.
    canvas.drawCircle(cx, cy, 3 * density,
      Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent; style = Paint.Style.FILL })

    cachedPhotoPin = bitmap
    return bitmap
  }

  // ClusterListener
  override fun onClusterAdded(cluster: Cluster) {
    val icon = renderClusterBitmap(cluster.size)
    cluster.appearance.setIcon(ImageProvider.fromBitmap(icon))
    cluster.addClusterTapListener(this)
  }

  // ClusterTapListener
  override fun onClusterTap(cluster: Cluster): Boolean {
    val p = cluster.appearance.geometry
    var swLat = p.latitude
    var swLon = p.longitude
    var neLat = p.latitude
    var neLon = p.longitude
    for (placemark in cluster.placemarks) {
      val g = placemark.geometry
      if (g.latitude < swLat) swLat = g.latitude
      if (g.longitude < swLon) swLon = g.longitude
      if (g.latitude > neLat) neLat = g.latitude
      if (g.longitude > neLon) neLon = g.longitude
    }
    onClusterPress?.invoke(
      cluster.size, p.latitude, p.longitude,
      swLat, swLon, neLat, neLon,
    )
    return true
  }
}
