package com.gutaeho.swifty.ui.components

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.BrightnessHigh
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.gutaeho.swifty.SwiftyViewModel
import com.gutaeho.swifty.domain.AccentPalette
import com.gutaeho.swifty.domain.AppearanceMode
import com.gutaeho.swifty.domain.UnitSystem
import com.gutaeho.swifty.ui.theme.accentSwatch
import com.gutaeho.swifty.ui.theme.isDarkScheme
import com.gutaeho.swifty.ui.theme.supportsDynamicColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsSheet(viewModel: SwiftyViewModel, onDismiss: () -> Unit) {
    val dark = isDarkScheme()
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 32.dp),
        ) {
            Text(
                "설정",
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.padding(start = 24.dp, end = 24.dp, bottom = 12.dp),
            )

            SectionTitle("단위", Icons.Filled.Straighten)
            UnitSystem.entries.forEach { item ->
                ChoiceRow(item.title, item == viewModel.unitSystem) { viewModel.chooseUnitSystem(item) }
            }

            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            SectionTitle("화면 모드", Icons.Filled.DarkMode)
            AppearanceMode.entries.forEach { item ->
                ChoiceRow(item.title, item == viewModel.appearance) { viewModel.chooseAppearance(item) }
            }

            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            SectionTitle("강조 색상", Icons.Filled.Palette)
            if (supportsDynamicColor) {
                ToggleRow(
                    "시스템 색상 사용",
                    "배경화면에서 뽑아낸 Material You 색상을 씁니다.",
                    Icons.Filled.AutoAwesome,
                    viewModel.dynamicColor,
                    viewModel::updateDynamicColor,
                )
            }
            if (!viewModel.dynamicColor || !supportsDynamicColor) {
                AccentSwatchRow(viewModel, dark)
            }

            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            ToggleRow(
                "촉각 피드백",
                "속도 구간과 주요 동작을 진동으로 알립니다.",
                Icons.Filled.Vibration,
                viewModel.hapticsEnabled,
                viewModel::updateHapticsEnabled,
            )
            ToggleRow(
                "화면 자동 꺼짐 방지",
                "주행 중 화면이 계속 켜져 있습니다.",
                Icons.Filled.BrightnessHigh,
                viewModel.keepScreenAwake,
                viewModel::updateKeepScreenAwake,
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String, icon: ImageVector) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
        Text(text, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
private fun ChoiceRow(label: String, selected: Boolean, onClick: () -> Unit) {
    ListItem(
        modifier = Modifier.selectable(selected = selected, role = Role.RadioButton, onClick = onClick),
        headlineContent = { Text(label) },
        trailingContent = { RadioButton(selected = selected, onClick = null) },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    )
}

@Composable
private fun ToggleRow(
    label: String,
    detail: String,
    icon: ImageVector,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
) {
    ListItem(
        modifier = Modifier.toggleable(value = checked, role = Role.Switch, onValueChange = onChange),
        headlineContent = { Text(label) },
        supportingContent = { Text(detail) },
        leadingContent = { Icon(icon, contentDescription = null) },
        trailingContent = { Switch(checked = checked, onCheckedChange = null) },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    )
}

/** Accent choice shown as Material 3 colour swatches rather than a list of radio buttons. */
@Composable
private fun AccentSwatchRow(viewModel: SwiftyViewModel, dark: Boolean) {
    Row(
        Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        AccentPalette.entries.forEach { item ->
            val selected = item == viewModel.accent
            val swatch = accentSwatch(item, dark)
            Surface(
                modifier = Modifier
                    .size(44.dp)
                    .selectable(selected = selected, role = Role.RadioButton) { viewModel.chooseAccent(item) },
                shape = CircleShape,
                color = swatch,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    if (selected) {
                        Icon(
                            Icons.Filled.Check,
                            contentDescription = item.title,
                            Modifier.size(22.dp),
                            tint = if (swatch.luminance() > 0.5f) Color.Black else Color.White,
                        )
                    }
                }
            }
        }
    }
}
