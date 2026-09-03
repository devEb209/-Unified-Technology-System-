package net.kairos.manager.net

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/** Ferramentas de diagnóstico de rede usadas pelas telas do app. */
object Tools {

    /** Ping ICMP real via binário do sistema, com fallback TCP. */
    suspend fun ping(host: String, count: Int = 4): String = withContext(Dispatchers.IO) {
        try {
            val p = ProcessBuilder("/system/bin/ping", "-c", count.toString(), "-W", "2", host)
                .redirectErrorStream(true).start()
            val out = BufferedReader(InputStreamReader(p.inputStream)).readText()
            p.waitFor()
            if (out.isNotBlank()) return@withContext out
        } catch (e: Exception) { }
        // fallback: mede tempo de handshake TCP
        val sb = StringBuilder("ping ICMP indisponível — usando TCP\n")
        repeat(count) { i ->
            val t0 = System.nanoTime()
            val ok = try {
                Socket().use { it.connect(InetSocketAddress(host, 80), 2000); true }
            } catch (e: Exception) { false }
            val ms = (System.nanoTime() - t0) / 1_000_000
            sb.append(if (ok) "resposta ${i + 1}: ${ms}ms\n" else "resposta ${i + 1}: tempo esgotado\n")
        }
        sb.toString()
    }

    /** Traceroute por TTL crescente usando ping do sistema. */
    suspend fun traceroute(host: String, maxHops: Int = 15): String = withContext(Dispatchers.IO) {
        val sb = StringBuilder()
        for (ttl in 1..maxHops) {
            try {
                val p = ProcessBuilder("/system/bin/ping", "-c", "1", "-t", ttl.toString(), "-W", "2", host)
                    .redirectErrorStream(true).start()
                val out = BufferedReader(InputStreamReader(p.inputStream)).readText()
                p.waitFor()
                val hop = Regex("""From ([\d.]+)""").find(out)?.groupValues?.get(1)
                    ?: Regex("""from ([\d.]+)""").find(out)?.groupValues?.get(1)
                    ?: Regex("""(\d+\.\d+\.\d+\.\d+)""").find(out)?.groupValues?.get(1)
                sb.append("%2d  %s\n".format(ttl, hop ?: "* * *"))
                if (hop != null && out.contains("bytes from") && !out.contains("Time to live")) {
                    sb.append("destino alcançado\n"); break
                }
            } catch (e: Exception) {
                sb.append("%2d  erro\n".format(ttl))
            }
        }
        sb.toString()
    }

    /** Resolução DNS com tempo de resposta. */
    suspend fun dns(host: String): String = withContext(Dispatchers.IO) {
        try {
            val t0 = System.currentTimeMillis()
            val addrs = InetAddress.getAllByName(host)
            val ms = System.currentTimeMillis() - t0
            "Resolvido em ${ms}ms\n" + addrs.joinToString("\n") { "  ${it.hostAddress}" }
        } catch (e: Exception) {
            "Falha ao resolver \"$host\": ${e.message}"
        }
    }

    /** Wake-on-LAN: magic packet para o MAC informado. */
    suspend fun wakeOnLan(mac: String, broadcast: String): String = withContext(Dispatchers.IO) {
        try {
            val clean = mac.replace("[:\\-]".toRegex(), "")
            require(clean.length == 12) { "MAC inválido" }
            val bytes = ByteArray(6) { clean.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
            val packet = ByteArray(102)
            for (i in 0 until 6) packet[i] = 0xFF.toByte()
            for (i in 6 until 102) packet[i] = bytes[(i - 6) % 6]
            DatagramSocket().use { s ->
                s.broadcast = true
                s.send(DatagramPacket(packet, packet.size, InetAddress.getByName(broadcast), 9))
            }
            "Magic packet enviado para $mac"
        } catch (e: Exception) {
            "Falha no Wake-on-LAN: ${e.message}"
        }
    }

    /** Teste de velocidade de download aproximado. */
    suspend fun speedTest(onProgress: (String) -> Unit = {}): String = withContext(Dispatchers.IO) {
        val url = "https://speed.cloudflare.com/__down?bytes=10000000"
        try {
            onProgress("Baixando 10 MB...")
            val t0 = System.currentTimeMillis()
            val conn = (URL(url).openConnection() as HttpsURLConnection).apply {
                connectTimeout = 8000; readTimeout = 30000
            }
            var total = 0L
            conn.inputStream.use { ins ->
                val buf = ByteArray(32 * 1024)
                while (true) {
                    val n = ins.read(buf)
                    if (n < 0) break
                    total += n
                    if (total % (1024 * 1024) < buf.size) onProgress("${total / 1_000_000} MB...")
                }
            }
            val secs = (System.currentTimeMillis() - t0) / 1000.0
            val mbps = (total * 8 / 1_000_000.0) / secs
            "Download: %.2f Mbps\n%.1f MB em %.1fs".format(mbps, total / 1e6, secs)
        } catch (e: Exception) {
            "Teste falhou: ${e.message}"
        }
    }

    /** Gera senha Wi-Fi forte. */
    fun generatePassword(len: Int = 20): String {
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%&*-_=+"
        val rnd = java.security.SecureRandom()
        return (1..len).map { chars[rnd.nextInt(chars.length)] }.joinToString("")
    }

    /** String padrão de QR code de rede Wi-Fi. */
    fun wifiQrPayload(ssid: String, pass: String, hidden: Boolean = false) =
        "WIFI:T:WPA;S:${ssid.replace(";", "\\;")};P:${pass.replace(";", "\\;")};H:$hidden;;"
}
