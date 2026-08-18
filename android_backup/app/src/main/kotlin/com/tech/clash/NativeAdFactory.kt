package com.tech.clash

import android.content.Context
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class NativeAdFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
            nativeAd: NativeAd,
            customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_layout, null) as NativeAdView

        // Find views
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        val callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)
        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val ratingBar = adView.findViewById<RatingBar>(R.id.ad_stars)
        val advertiserView = adView.findViewById<TextView>(R.id.ad_advertiser)
        val storeView = adView.findViewById<TextView>(R.id.ad_store)
        val priceView = adView.findViewById<TextView>(R.id.ad_price)

        // Register views with NativeAdView
        adView.headlineView = headlineView
        adView.mediaView = mediaView
        adView.bodyView = bodyView
        adView.callToActionView = callToActionView
        adView.iconView = iconView
        adView.starRatingView = ratingBar
        adView.advertiserView = advertiserView
        adView.storeView = storeView
        adView.priceView = priceView

        // Set content
        headlineView.text = nativeAd.headline

        nativeAd.body?.let { body ->
            bodyView.text = body
            bodyView.visibility = View.VISIBLE
        }

        nativeAd.callToAction?.let { cta ->
            callToActionView.text = cta
            callToActionView.visibility = View.VISIBLE
        }

        nativeAd.icon?.let { icon ->
            iconView.setImageDrawable(icon.drawable)
            iconView.visibility = View.VISIBLE
        }

        nativeAd.starRating?.let { rating ->
            ratingBar.rating = rating.toFloat()
            ratingBar.visibility = View.VISIBLE
        }

        nativeAd.advertiser?.let { advertiser ->
            advertiserView.text = advertiser
            advertiserView.visibility = View.VISIBLE
        }

        nativeAd.store?.let { store ->
            storeView.text = store
            storeView.visibility = View.VISIBLE
        }

        nativeAd.price?.let { price ->
            priceView.text = price
            priceView.visibility = View.VISIBLE
        }

        adView.setNativeAd(nativeAd)

        return adView
    }
}