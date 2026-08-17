package com.sorli.app

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureSystemNavigation()
    }

    private fun configureSystemNavigation() {
        // Safe launch color matching the default rendered background bottom.
        // Flutter replaces it with the selected theme's exact final tone.
        window.navigationBarColor = Color.rgb(29, 8, 18)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.setSystemBarsAppearance(
                0,
                WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
            )
        }
    }
}
