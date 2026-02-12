package com.example.vertix

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.ImageView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

class SplashActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Fullscreen immersive
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        setContentView(R.layout.activity_splash)

        val logoImage = findViewById<ImageView>(R.id.logo_image)

        // Start animation
        logoImage.post {
            animateLogo(logoImage)
        }

        // Start Flutter immediately - splash closes when Flutter is ready
        startActivity(Intent(this, MainActivity::class.java))
    }

    private fun animateLogo(logo: ImageView) {
        logo.alpha = 0f
        logo.scaleX = 0.6f
        logo.scaleY = 0.6f

        val fadeIn = ObjectAnimator.ofFloat(logo, View.ALPHA, 0f, 1f).apply {
            duration = 600
        }

        val scaleX = ObjectAnimator.ofFloat(logo, View.SCALE_X, 0.6f, 1f).apply {
            duration = 800
            interpolator = OvershootInterpolator(1.5f)
        }

        val scaleY = ObjectAnimator.ofFloat(logo, View.SCALE_Y, 0.6f, 1f).apply {
            duration = 800
            interpolator = OvershootInterpolator(1.5f)
        }

        AnimatorSet().apply {
            playTogether(fadeIn, scaleX, scaleY)
            start()
        }
    }

    override fun onStop() {
        super.onStop()
        finish()
    }
}
