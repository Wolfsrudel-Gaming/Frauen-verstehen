package com.wolfsrudelgaming.frauenverstehen

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.wolfsrudelgaming.frauenverstehen.navigation.AppNavigation
import com.wolfsrudelgaming.frauenverstehen.ui.theme.FrauenVerstehenTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            FrauenVerstehenTheme {
                AppNavigation()
            }
        }
    }
}
