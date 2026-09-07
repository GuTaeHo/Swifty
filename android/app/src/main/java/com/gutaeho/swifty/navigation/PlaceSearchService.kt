package com.gutaeho.swifty.navigation

import android.content.Context
import android.location.Geocoder
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.gutaeho.swifty.domain.Coordinate
import com.gutaeho.swifty.domain.Destination
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

class PlaceSearchService(
    context: Context,
    private val scope: CoroutineScope,
) {
    private val geocoder = Geocoder(context, Locale.getDefault())
    private var searchJob: Job? = null

    var query by mutableStateOf("")
    var results by mutableStateOf<List<Destination>>(emptyList())
        private set
    var isSearching by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set

    fun search() {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return
        searchJob?.cancel()
        searchJob = scope.launch {
            isSearching = true
            errorMessage = null
            try {
                @Suppress("DEPRECATION")
                val found = withContext(Dispatchers.IO) {
                    if (!Geocoder.isPresent()) emptyList()
                    else geocoder.getFromLocationName(trimmed, 8).orEmpty()
                }
                results = found.map { address ->
                    Destination(
                        name = address.featureName?.takeIf { it.isNotBlank() }
                            ?: address.locality?.takeIf { it.isNotBlank() }
                            ?: trimmed,
                        subtitle = address.getAddressLine(0)?.takeIf { it.isNotBlank() },
                        coordinate = Coordinate(address.latitude, address.longitude),
                    )
                }.distinctBy { it.coordinate }
                if (results.isEmpty()) errorMessage = "검색 결과가 없습니다."
            } catch (_: Exception) {
                results = emptyList()
                errorMessage = "검색에 실패했습니다. 네트워크 연결을 확인하세요."
            } finally {
                isSearching = false
                searchJob = null
            }
        }
    }

    fun reset() {
        searchJob?.cancel()
        searchJob = null
        query = ""
        results = emptyList()
        errorMessage = null
        isSearching = false
    }
}
