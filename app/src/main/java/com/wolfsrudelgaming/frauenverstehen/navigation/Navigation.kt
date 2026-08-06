package com.wolfsrudelgaming.frauenverstehen.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEmotions
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.wolfsrudelgaming.frauenverstehen.ui.screens.HomeScreen
import com.wolfsrudelgaming.frauenverstehen.ui.screens.QuizScreen
import com.wolfsrudelgaming.frauenverstehen.ui.screens.StimmungskompassScreen
import com.wolfsrudelgaming.frauenverstehen.ui.screens.TippsScreen
import com.wolfsrudelgaming.frauenverstehen.ui.screens.UebersetzerScreen

sealed class Screen(
    val route: String,
    val label: String,
    val icon: ImageVector
) {
    object Home : Screen("home", "Start", Icons.Filled.Home)
    object Uebersetzer : Screen("uebersetzer", "Übersetzer", Icons.Filled.Translate)
    object Stimmung : Screen("stimmung", "Stimmung", Icons.Filled.EmojiEmotions)
    object Tipps : Screen("tipps", "Tipps", Icons.Filled.Favorite)
    object Quiz : Screen("quiz", "Quiz", Icons.Filled.School)
}

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    val screens = listOf(
        Screen.Home,
        Screen.Uebersetzer,
        Screen.Stimmung,
        Screen.Tipps,
        Screen.Quiz
    )

    Scaffold(
        bottomBar = {
            NavigationBar {
                screens.forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.label) },
                        label = { Text(screen.label) },
                        selected = currentRoute == screen.route,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Screen.Home.route) { HomeScreen() }
            composable(Screen.Uebersetzer.route) { UebersetzerScreen() }
            composable(Screen.Stimmung.route) { StimmungskompassScreen() }
            composable(Screen.Tipps.route) { TippsScreen() }
            composable(Screen.Quiz.route) { QuizScreen() }
        }
    }
}
