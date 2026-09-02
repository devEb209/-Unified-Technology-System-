package net.kairos.manager.net

import android.annotation.SuppressLint
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import java.net.Inet4Address
import java.net.NetworkInterface

data class WifiSnapshot(
    val ssid: String,
    val bssid: String,
    val ip: String,
    val gateway: String,
    val rssi: Int,
    val linkSpeedMbps: Int,
    val frequency: Int,
    val prefix: String,          // ex: 192.168.0.
    val connectedWifi: Boolean
)

object NetInfo {

    @SuppressLint("MissingPermission")
    fun snapshot(ctx: Context): WifiSnapshot {
        val wm = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = cm.getNetworkCapabilities(cm.activeNetwork)
        val isWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true

        val info = try { wm.connectionInfo } catch (e: Exception) { null }
        val ssid = (info?.ssid ?: "").replace("\"", "")
        val bssid = info?.bssid ?: ""
        val ip = localIpv4() ?: intToIp(info?.ipAddress ?: 0)
        val gw = gateway(ctx, ip)
        val prefix = ip.substringBeforeLast(".", "") + "."

        return WifiSnapshot(
            ssid = ssid,
            bssid = bssid,
            ip = ip,
            gateway = gw,
            rssi = info?.rssi ?: 0,
            linkSpeedMbps = info?.linkSpeed ?: 0,
            frequency = try { info?.frequency ?: 0 } catch (e: Exception) { 0 },
            prefix = prefix,
            connectedWifi = isWifi
        )
    }

    @Suppress("DEPRECATION")
    private fun gateway(ctx: Context, ip: String): String {
        return try {
            val wm = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val g = wm.dhcpInfo?.gateway ?: 0
            if (g != 0) intToIp(g) else ip.substringBeforeLast(".") + ".1"
        } catch (e: Exception) {
            ip.substringBeforeLast(".") + ".1"
        }
    }

    private fun intToIp(i: Int): String =
        "${i and 0xff}.${i shr 8 and 0xff}.${i shr 16 and 0xff}.${i shr 24 and 0xff}"

    fun localIpv4(): String? {
        try {
            for (nif in NetworkInterface.getNetworkInterfaces()) {
                if (!nif.isUp || nif.isLoopback) continue
                for (addr in nif.inetAddresses) {
                    if (addr is Inet4Address && !addr.isLoopbackAddress) return addr.hostAddress
                }
            }
        } catch (e: Exception) { }
        return null
    }
}
