package net.kairos.manager.net

/** Identificação básica de fabricante pelo prefixo MAC (OUI). */
object Oui {
    private val table = mapOf(
        "FC:FB:FB" to "Cisco", "00:1A:11" to "Google", "3C:5A:B4" to "Google",
        "F4:F5:D8" to "Google", "DA:A1:19" to "Google", "00:1C:B3" to "Apple",
        "AC:BC:32" to "Apple", "F0:18:98" to "Apple", "A4:83:E7" to "Apple",
        "D0:81:7A" to "Apple", "00:23:76" to "HTC", "5C:F9:38" to "Apple",
        "00:12:FB" to "Samsung", "00:26:37" to "Samsung", "F4:09:D8" to "Samsung",
        "78:1F:DB" to "Samsung", "C8:14:79" to "Samsung", "E8:50:8B" to "Samsung",
        "00:9A:CD" to "Huawei", "20:F3:A3" to "Huawei", "48:46:FB" to "Huawei",
        "64:09:80" to "Xiaomi", "8C:BE:BE" to "Xiaomi", "F8:A4:5F" to "Xiaomi",
        "50:8F:4C" to "Xiaomi", "AC:C1:EE" to "Xiaomi", "18:59:36" to "Xiaomi",
        "B0:BE:76" to "TP-Link", "50:C7:BF" to "TP-Link", "AC:84:C6" to "TP-Link",
        "C0:25:E9" to "TP-Link", "00:1D:0F" to "TP-Link", "10:FE:ED" to "TP-Link",
        "00:05:CD" to "Denon", "00:04:20" to "Slim Devices", "B8:27:EB" to "Raspberry Pi",
        "DC:A6:32" to "Raspberry Pi", "E4:5F:01" to "Raspberry Pi",
        "00:17:88" to "Philips Hue", "68:C6:3A" to "Espressif", "24:0A:C4" to "Espressif",
        "A0:20:A6" to "Espressif", "84:F3:EB" to "Espressif", "2C:F4:32" to "Espressif",
        "00:24:E4" to "Withings", "00:1E:C2" to "Apple", "70:4F:57" to "Motorola",
        "F8:E0:79" to "Motorola", "00:0C:E7" to "MediaTek", "00:08:22" to "Intel",
        "3C:97:0E" to "Wistron", "00:15:5D" to "Microsoft/Hyper-V",
        "00:50:56" to "VMware", "08:00:27" to "VirtualBox", "00:1B:44" to "SanDisk",
        "D8:5D:E2" to "Roku", "CC:6D:A0" to "Roku", "B8:3E:59" to "LG",
        "00:E0:91" to "LG", "10:68:3F" to "LG", "70:B3:D5" to "IEEE Registry",
        "5C:AA:FD" to "Sonos", "94:9F:3E" to "Sonos", "00:04:F2" to "Polycom"
    )

    fun lookup(mac: String): String {
        if (mac.length < 8) return ""
        val p = mac.uppercase().substring(0, 8)
        return table[p] ?: ""
    }

    /** MAC aleatorizado (bit local administrado) — comum em celulares modernos. */
    fun isRandomized(mac: String): Boolean {
        if (mac.length < 2) return false
        val b = mac.substring(0, 2).toIntOrNull(16) ?: return false
        return (b and 0x02) != 0
    }
}
