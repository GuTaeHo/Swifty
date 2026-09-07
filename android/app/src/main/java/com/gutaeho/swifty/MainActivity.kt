package com.gutaeho.swifty

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.gutaeho.swifty.domain.AppMode
import com.gutaeho.swifty.ui.components.iconVector
import com.gutaeho.swifty.ui.screens.GaugeScreen
import com.gutaeho.swifty.ui.screens.HistoryScreen
import com.gutaeho.swifty.ui.screens.MapScreen
import com.gutaeho.swifty.ui.theme.SwiftyTheme
import org.maplibre.android.MapLibre

class MainActivity : ComponentActivity() {
    private val viewModel: SwiftyViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        MapLibre.getInstance(this)
        setContent {
            SwiftyTheme(
                appearance = viewModel.appearance,
                accent = viewModel.accent,
                dynamicColor = viewModel.dynamicColor,
            ) {
                SwiftyRoot(viewModel)
            }
        }
    }
}

@Composable
private fun SwiftyRoot(viewModel: SwiftyViewModel) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { result ->
        viewModel.onPermissionResult(
            result[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
                result[Manifest.permission.ACCESS_COARSE_LOCATION] == true,
        )
    }
    val requestPermission = {
        permissionLauncher.launch(
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
        )
    }
    val openSettings = {
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)),
        )
    }

    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> viewModel.onResume()
                Lifecycle.Event.ON_PAUSE -> viewModel.onPause()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    SideEffect {
        val window = (context as? ComponentActivity)?.window
        if (viewModel.keepScreenAwake) window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    LaunchedEffect(viewModel.location.clockMillis, viewModel.network.isOnline) {
        viewModel.refreshNavigation()
    }

    BackHandler(enabled = viewModel.selectedRecord != null) { viewModel.selectRecord(null) }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar {
                AppMode.entries.forEach { mode ->
                    val selected = viewModel.mode == mode
                    val recordingBadge = mode == AppMode.HISTORY && viewModel.recorder.isRecording
                    NavigationBarItem(
                        selected = selected,
                        onClick = { viewModel.chooseMode(mode) },
                        icon = {
                            if (recordingBadge) {
                                BadgedBox(badge = { Badge() }) {
                                    Icon(mode.iconVector(selected), contentDescription = null)
                                }
                            } else {
                                Icon(mode.iconVector(selected), contentDescription = null)
                            }
                        },
                        label = { Text(mode.title) },
                    )
                }
            }
        },
    ) { padding ->
        when (viewModel.mode) {
            AppMode.MAP -> MapScreen(viewModel, requestPermission, openSettings, Modifier.fillMaxSize().padding(padding))
            AppMode.GAUGE -> GaugeScreen(viewModel, requestPermission, openSettings, Modifier.fillMaxSize().padding(padding))
            AppMode.HISTORY -> HistoryScreen(viewModel, Modifier.fillMaxSize().padding(padding))
        }
    }
}
