package net.kairos.manager.core

data class Device(
    val mac: String,
    val ip: String,
    var name: String = "",
    var vendor: String = "",
    var iface: String = "wifi",       // wifi | eth | bt | unknown
    var online: Boolean = true,
    var firstSeen: Long = System.currentTimeMillis(),
    var lastSeen: Long = System.currentTimeMillis(),
    var rttMs: Long = -1,
    var rssi: Int = 0,
    var blocked: Boolean = false,
    var pausedUntil: Long = 0L,
    var priority: Int = 3,            // 1..5 (potência/QoS relativa)
    var bandwidthCapKbps: Int = 0,    // 0 = ilimitado
    var trusted: Boolean = false,
    var favorite: Boolean = false,
    var notes: String = "",
    var rxBytes: Long = 0,
    var txBytes: Long = 0,
    var openPorts: List<Int> = emptyList()
) {
    val isPaused: Boolean get() = System.currentTimeMillis() < pausedUntil
    val id: String get() = mac.ifBlank { ip }
    val label: String get() = name.ifBlank { vendor.ifBlank { ip } }
}

data class HistoryEntry(
    val ts: Long,
    val deviceId: String,
    val event: String,
    val detail: String = ""
)

data class SystemModule(
    val id: Int,
    val name: String,
    val category: String,
    val description: String,
    var enabled: Boolean = true
)
