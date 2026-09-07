package com.gutaeho.swifty.location

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class NetworkMonitor(context: Context) {
    private val manager = context.getSystemService(ConnectivityManager::class.java)
    private val mainHandler = Handler(Looper.getMainLooper())

    var isOnline by mutableStateOf(currentlyOnline())
        private set
    var isExpensive by mutableStateOf(false)
        private set

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = refresh()
        override fun onLost(network: Network) = refresh()
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) = refresh()
    }

    init {
        runCatching {
            manager.registerNetworkCallback(
                NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(),
                callback,
            )
        }
        refresh()
    }

    fun close() {
        runCatching { manager.unregisterNetworkCallback(callback) }
    }

    private fun refresh() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post(::refresh)
            return
        }
        val capabilities = manager.activeNetwork?.let(manager::getNetworkCapabilities)
        isOnline = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        isExpensive = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false
    }

    private fun currentlyOnline(): Boolean {
        val capabilities = manager.activeNetwork?.let(manager::getNetworkCapabilities) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
}
