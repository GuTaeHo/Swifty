package com.gutaeho.swifty.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.GpsOff
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.gutaeho.swifty.SwiftyViewModel
import com.gutaeho.swifty.domain.GaugeStyle
import com.gutaeho.swifty.ui.components.AnalogGauge
import com.gutaeho.swifty.ui.components.DestinationSummary
import com.gutaeho.swifty.ui.components.DigitalGauge
import com.gutaeho.swifty.ui.components.LocationGate
import com.gutaeho.swifty.ui.components.SettingsSheet
import com.gutaeho.swifty.ui.components.StatusBanner
import com.gutaeho.swifty.ui.components.TransportPicker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GaugeScreen(
    viewModel: SwiftyViewModel,
    onRequestPermission: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var showingSettings by remember { mutableStateOf(false) }
    if (showingSettings) SettingsSheet(viewModel) { showingSettings = false }

    if (viewModel.location.needsAuthorization) {
        LocationGate(
            viewModel.location.permissionStatus,
            viewModel.locationPermissionDenied,
            onRequestPermission,
            onOpenSettings,
            modifier.fillMaxSize(),
        )
        return
    }

    val recording = viewModel.recorder.isRecording
    Column(modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("계기판") },
            navigationIcon = {
                IconButton(onClick = { showingSettings = true }) {
                    Icon(Icons.Filled.Settings, contentDescription = "설정")
                }
            },
            actions = {
                IconButton(onClick = viewModel::toggleRecording) {
                    Icon(
                        if (recording) Icons.Filled.Stop else Icons.Filled.FiberManualRecord,
                        contentDescription = if (recording) "측정 종료" else "측정 시작",
                        tint = MaterialTheme.colorScheme.error,
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
        )
        Column(
            Modifier.fillMaxSize().padding(start = 16.dp, end = 16.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                GaugeStyle.entries.forEachIndexed { index, style ->
                    SegmentedButton(
                        selected = style == viewModel.gaugeStyle,
                        onClick = { viewModel.chooseGaugeStyle(style) },
                        shape = SegmentedButtonDefaults.itemShape(index, GaugeStyle.entries.size),
                    ) { Text(style.title) }
                }
            }
            TransportPicker(viewModel, Modifier.fillMaxWidth())
            AnimatedVisibility(visible = viewModel.savedRecordNotice != null) {
                StatusBanner(
                    viewModel.savedRecordNotice.orEmpty(),
                    Icons.Filled.CheckCircle,
                    Modifier.fillMaxWidth(),
                    container = MaterialTheme.colorScheme.tertiaryContainer,
                    onContainer = MaterialTheme.colorScheme.onTertiaryContainer,
                )
            }
            Box(Modifier.fillMaxWidth().weight(1f)) {
                when (viewModel.gaugeStyle) {
                    GaugeStyle.DIGITAL -> DigitalGauge(viewModel, Modifier.fillMaxSize())
                    GaugeStyle.ANALOG -> AnalogGauge(viewModel, Modifier.fillMaxSize())
                }
                if (viewModel.location.isSignalStale) {
                    StatusBanner(
                        "GPS 신호를 기다리는 중",
                        Icons.Filled.GpsOff,
                        Modifier.align(Alignment.TopStart),
                        container = MaterialTheme.colorScheme.errorContainer,
                        onContainer = MaterialTheme.colorScheme.onErrorContainer,
                    )
                }
            }
            if (viewModel.navigation.hasDestination) {
                DestinationSummary(viewModel, compact = true, modifier = Modifier.fillMaxWidth())
            }
        }
    }
}
