package com.yandexmap

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.PermissionAwareActivity
import com.facebook.react.modules.core.PermissionListener
import com.yandex.mapkit.MapKitFactory
import com.yandex.runtime.i18n.I18nManagerFactory

@ReactModule(name = YandexMapModule.NAME)
class YandexMapModule(reactContext: ReactApplicationContext) :
  NativeYandexMapModuleSpec(reactContext) {

  private var pendingPermissionPromise: Promise? = null

  override fun getName(): String = NAME

  override fun init(apiKey: String, promise: Promise) {
    UiThreadUtil.runOnUiThread {
      try {
        applyApiKey(reactApplicationContext, apiKey)
        promise.resolve(null)
      } catch (e: Throwable) {
        promise.reject("YANDEX_MAP_INIT_FAILED", e.message ?: "init failed", e)
      }
    }
  }

  override fun setLocale(locale: String, promise: Promise) {
    UiThreadUtil.runOnUiThread {
      try {
        MapKitFactory.setLocale(locale)
        promise.resolve(null)
      } catch (e: Throwable) {
        promise.reject("YANDEX_MAP_LOCALE_FAILED", e.message, e)
      }
    }
  }

  override fun resetLocale(promise: Promise) {
    UiThreadUtil.runOnUiThread {
      try {
        I18nManagerFactory.setLocale(null)
        promise.resolve(null)
      } catch (e: Throwable) {
        promise.reject("YANDEX_MAP_LOCALE_FAILED", e.message, e)
      }
    }
  }

  override fun getLocale(promise: Promise) {
    UiThreadUtil.runOnUiThread {
      try {
        promise.resolve(I18nManagerFactory.getLocale() ?: "")
      } catch (e: Throwable) {
        promise.reject("YANDEX_MAP_LOCALE_FAILED", e.message, e)
      }
    }
  }

  override fun requestLocationPermission(promise: Promise) {
    val ctx = reactApplicationContext
    val granted = ContextCompat.checkSelfPermission(
      ctx,
      Manifest.permission.ACCESS_FINE_LOCATION,
    ) == PackageManager.PERMISSION_GRANTED ||
      ContextCompat.checkSelfPermission(
        ctx,
        Manifest.permission.ACCESS_COARSE_LOCATION,
      ) == PackageManager.PERMISSION_GRANTED
    if (granted) {
      promise.resolve("granted")
      return
    }
    // Guard against parallel requests — Android only supports one in-flight
    // permission dialog at a time; the second call would strand the first
    // promise.
    synchronized(this) {
      if (pendingPermissionPromise != null) {
        promise.reject(
          "YANDEX_LOCATION_PERMISSION_IN_PROGRESS",
          "Another location permission request is already in flight",
        )
        return
      }
      pendingPermissionPromise = promise
    }
    UiThreadUtil.runOnUiThread {
      val activity = currentActivity as? PermissionAwareActivity
      if (activity == null) {
        val p = synchronized(this) {
          val q = pendingPermissionPromise; pendingPermissionPromise = null; q
        }
        p?.resolve("unavailable")
        return@runOnUiThread
      }
      val requestCode = LOCATION_REQUEST_CODE
      activity.requestPermissions(
        arrayOf(
          Manifest.permission.ACCESS_FINE_LOCATION,
          Manifest.permission.ACCESS_COARSE_LOCATION,
        ),
        requestCode,
        PermissionListener { code, _, grantResults ->
          if (code != requestCode) return@PermissionListener false
          val ok = grantResults.isNotEmpty() &&
            grantResults.any { it == PackageManager.PERMISSION_GRANTED }
          val p = synchronized(this) {
            val q = pendingPermissionPromise; pendingPermissionPromise = null; q
          }
          p?.resolve(if (ok) "granted" else "denied")
          true
        },
      )
    }
  }

  @SuppressLint("MissingPermission")
  override fun getCurrentLocation(promise: Promise) {
    val ctx = reactApplicationContext
    val fineGranted = ContextCompat.checkSelfPermission(
      ctx, Manifest.permission.ACCESS_FINE_LOCATION,
    ) == PackageManager.PERMISSION_GRANTED
    val coarseGranted = ContextCompat.checkSelfPermission(
      ctx, Manifest.permission.ACCESS_COARSE_LOCATION,
    ) == PackageManager.PERMISSION_GRANTED
    if (!fineGranted && !coarseGranted) {
      promise.reject("YANDEX_LOCATION_PERMISSION", "Location permission not granted")
      return
    }
    val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
    if (lm == null) {
      promise.reject("YANDEX_LOCATION_UNAVAILABLE", "LocationManager unavailable")
      return
    }
    UiThreadUtil.runOnUiThread {
      try {
        // Try last known from any available provider first.
        val providers = lm.getProviders(true)
        var best: Location? = null
        for (p in providers) {
          val loc = lm.getLastKnownLocation(p) ?: continue
          if (best == null || loc.time > best.time) best = loc
        }
        if (best != null) {
          promise.resolve(Arguments.createMap().apply {
            putDouble("lat", best!!.latitude)
            putDouble("lon", best!!.longitude)
          })
          return@runOnUiThread
        }
        val provider = when {
          lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
          lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
          else -> null
        }
        if (provider == null) {
          promise.reject("YANDEX_LOCATION_UNAVAILABLE", "No enabled location provider")
          return@runOnUiThread
        }
        // Single-update with 12s timeout + dedupe (first wins).
        val mainHandler = Handler(Looper.getMainLooper())
        val settled = java.util.concurrent.atomic.AtomicBoolean(false)
        var listenerRef: LocationListener? = null
        val timeoutRunnable = Runnable {
          if (settled.compareAndSet(false, true)) {
            listenerRef?.let { lm.removeUpdates(it) }
            promise.reject("YANDEX_LOCATION_TIMEOUT", "No location fix within 12s")
          }
        }
        val listener = LocationListener { loc ->
          if (settled.compareAndSet(false, true)) {
            mainHandler.removeCallbacks(timeoutRunnable)
            lm.removeUpdates(listenerRef!!)
            promise.resolve(Arguments.createMap().apply {
              putDouble("lat", loc.latitude)
              putDouble("lon", loc.longitude)
            })
          }
        }
        listenerRef = listener
        lm.requestSingleUpdate(provider, listener, Looper.getMainLooper())
        mainHandler.postDelayed(timeoutRunnable, 12_000L)
      } catch (e: Throwable) {
        promise.reject("YANDEX_LOCATION_FAILED", e.message ?: "location failed", e)
      }
    }
  }

  companion object {
    private const val LOCATION_REQUEST_CODE = 8420
    const val NAME = "YandexMapModule"

    @Volatile
    private var initialised: Boolean = false

    @JvmStatic
    fun isInitialised(): Boolean = initialised

    @JvmStatic
    @Synchronized
    fun applyApiKey(context: Context, apiKey: String) {
      if (initialised) return
      try {
        MapKitFactory.setApiKey(apiKey)
      } catch (_: Throwable) {
        // setApiKey throws if called twice. Treat as benign.
      }
      MapKitFactory.initialize(context.applicationContext)
      MapKitFactory.getInstance().onStart()
      // In Yandex MapKit 4.36 Android, SearchFactory.getInstance() is enough —
      // there's no separate SearchFactory.initialize() like older versions.
      initialised = true
    }

    @JvmStatic
    @Synchronized
    fun ensureInitialisedFromManifest(context: Context): Boolean {
      if (initialised) return true
      val appContext = context.applicationContext
      val key = try {
        val ai = appContext.packageManager
          .getApplicationInfo(appContext.packageName, PackageManager.GET_META_DATA)
        ai.metaData?.getString("com.yandex.maps.ApiKey")
      } catch (_: Throwable) {
        null
      }
      if (key.isNullOrBlank()) return false
      applyApiKey(appContext, key)
      return true
    }
  }
}
