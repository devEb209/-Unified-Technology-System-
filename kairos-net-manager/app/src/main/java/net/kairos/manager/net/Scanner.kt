package net.kairos.manager.net

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.withContext
import net.kairos.manager.core.Device
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Descoberta de dispositivos na SUA rede local:
 *  - varredura ICMP/TCP paralela de /24
 *  - leitura da tabela ARP (/proc/net/arp) para obter MAC
 *  - fingerprint de portas abertas
 */
object Scanner {

    private val COMMON_PORTS = listOf(80, 443, 22, 445, 139, 8080, 5555, 62078, 9100, 1900, 53)

    suspend fun scan(ctx: Context, onProgress: (Int) -> Unit = {}): List<Device> =
        withContext(Dispatchers.IO) {
            val snap = NetInfo.snapshot(ctx)
            if (snap.prefix.length < 4) return@withContext emptyList()

            val alive = mutableListOf<Pair<String, Long>>()
            var done = 0
            val jobs = (1..254).map { host ->
                async {
                    val ip = snap.prefix + host
                    val t0 = System.currentTimeMillis()
                    val ok = reachable(ip)
                    val rtt = System.currentTimeMillis() - t0
                    done++
                    if (done % 12 == 0) onProgress(done * 100 / 254)
                    if (ok) synchronized(alive) { alive += ip to rtt }
                }
            }
            jobs.awaitAll()
            onProgress(100)

            val arp = arpTable()
            alive.map { (ip, rtt) ->
                val mac = arp[ip] ?: ""
                Device(
                    mac = mac,
                    ip = ip,
                    vendor = Oui.lookup(mac),
                    iface = if (ip == snap.gateway) "router" else "wifi",
                    rttMs = rtt,
                    online = true
                )
            }.sortedBy { it.ip.substringAfterLast(".").toIntOrNull() ?: 0 }
        }

    private fun reachable(ip: String, timeout: Int = 320): Boolean {
        try {
            if (InetAddress.getByName(ip).isReachable(timeout)) return true
        } catch (e: Exception) { }
        for (p in listOf(80, 443, 22, 445, 8080)) {
            try {
                Socket().use { s ->
                    s.connect(InetSocketAddress(ip, p), 180)
                    return true
                }
            } catch (e: Exception) { }
        }
        return false
    }

    fun openPorts(ip: String): List<Int> =
        COMMON_PORTS.filter { p ->
            try { Socket().use { it.connect(InetSocketAddress(ip, p), 220); true } }
            catch (e: Exception) { false }
        }

    fun arpTable(): Map<String, String> {
        val map = mutableMapOf<String, String>()
        try {
            val f = File("/proc/net/arp")
            if (f.exists()) {
                BufferedReader(FileReader(f)).useLines { lines ->
                    lines.drop(1).forEach { l ->
                        val t = l.split(Regex("\\s+")).filter { it.isNotBlank() }
                        if (t.size >= 4 && t[3] != "00:00:00:00:00:00") map[t[0]] = t[3].uppercase()
                    }
                }
            }
        } catch (e: Exception) { }
        return map
    }
}
