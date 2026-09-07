package com.gutaeho.swifty.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.DirectionsSubway
import androidx.compose.material.icons.filled.Flight
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.ui.graphics.vector.ImageVector
import com.gutaeho.swifty.domain.AppMode
import com.gutaeho.swifty.domain.EstimateSource
import com.gutaeho.swifty.domain.TransportMode

/** Material symbols for the domain enums, so no screen has to render an emoji as text. */
fun AppMode.iconVector(selected: Boolean): ImageVector = when (this) {
    AppMode.MAP -> if (selected) Icons.Filled.Map else Icons.Outlined.Map
    AppMode.GAUGE -> if (selected) Icons.Filled.Speed else Icons.Outlined.Speed
    AppMode.HISTORY -> if (selected) Icons.Filled.History else Icons.Outlined.History
}

val TransportMode.iconVector: ImageVector
    get() = when (this) {
        TransportMode.WALKING -> Icons.AutoMirrored.Filled.DirectionsWalk
        TransportMode.CYCLING -> Icons.AutoMirrored.Filled.DirectionsBike
        TransportMode.CAR -> Icons.Filled.DirectionsCar
        TransportMode.SUBWAY -> Icons.Filled.DirectionsSubway
        TransportMode.TRAIN -> Icons.Filled.Train
        TransportMode.AIRPLANE -> Icons.Filled.Flight
    }

val EstimateSource.iconVector: ImageVector
    get() = when (this) {
        EstimateSource.ROUTE -> Icons.Filled.Navigation
        EstimateSource.CACHED_ROUTE -> Icons.Filled.CloudDownload
        EstimateSource.STRAIGHT_LINE -> Icons.Filled.Straighten
    }
