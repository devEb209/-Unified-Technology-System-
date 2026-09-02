package net.kairos.manager.core

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/** Persistência local simples e robusta (JSON em SharedPreferences). */
class Store(ctx: Context) {

    private val p: SharedPreferences =
        ctx.getSharedPreferences("kairos_store", Context.MODE_PRIVATE)

    // ---------- Devices ----------
    fun loadDevices(): MutableList<Device> {
        val raw = p.getString("devices", "[]") ?: "[]"
        val arr = JSONArray(raw)
        val out = mutableListOf<Device>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out += Device(
                mac = o.optString("mac"),
                ip = o.optString("ip"),
                name = o.optString("name"),
                vendor = o.optString("vendor"),
                iface = o.optString("iface", "wifi"),
                online = o.optBoolean("online"),
                firstSeen = o.optLong("firstSeen"),
                lastSeen = o.optLong("lastSeen"),
                rttMs = o.optLong("rttMs", -1),
                rssi = o.optInt("rssi"),
                blocked = o.optBoolean("blocked"),
                pausedUntil = o.optLong("pausedUntil"),
                priority = o.optInt("priority", 3),
                bandwidthCapKbps = o.optInt("cap"),
                trusted = o.optBoolean("trusted"),
                favorite = o.optBoolean("favorite"),
                notes = o.optString("notes"),
                rxBytes = o.optLong("rx"),
                txBytes = o.optLong("tx")
            )
        }
        return out
    }

    fun saveDevices(list: List<Device>) {
        val arr = JSONArray()
        list.forEach { d ->
            arr.put(JSONObject().apply {
                put("mac", d.mac); put("ip", d.ip); put("name", d.name)
                put("vendor", d.vendor); put("iface", d.iface); put("online", d.online)
                put("firstSeen", d.firstSeen); put("lastSeen", d.lastSeen)
                put("rttMs", d.rttMs); put("rssi", d.rssi)
                put("blocked", d.blocked); put("pausedUntil", d.pausedUntil)
                put("priority", d.priority); put("cap", d.bandwidthCapKbps)
                put("trusted", d.trusted); put("favorite", d.favorite)
                put("notes", d.notes); put("rx", d.rxBytes); put("tx", d.txBytes)
            })
        }
        p.edit().putString("devices", arr.toString()).apply()
    }

    // ---------- Histórico ----------
    fun addHistory(e: HistoryEntry) {
        val arr = JSONArray(p.getString("history", "[]"))
        arr.put(JSONObject().apply {
            put("ts", e.ts); put("dev", e.deviceId); put("ev", e.event); put("dt", e.detail)
        })
        // mantém no máximo 5000 eventos
        val trimmed = if (arr.length() > 5000) {
            val n = JSONArray()
            for (i in arr.length() - 5000 until arr.length()) n.put(arr.get(i))
            n
        } else arr
        p.edit().putString("history", trimmed.toString()).apply()
    }

    fun history(deviceId: String? = null): List<HistoryEntry> {
        val arr = JSONArray(p.getString("history", "[]"))
        val out = mutableListOf<HistoryEntry>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val h = HistoryEntry(o.optLong("ts"), o.optString("dev"), o.optString("ev"), o.optString("dt"))
            if (deviceId == null || h.deviceId == deviceId) out += h
        }
        return out.asReversed()
    }

    fun clearHistory() = p.edit().remove("history").apply()

    // ---------- Rede confiável (só a MINHA rede) ----------
    var ownedBssid: String
        get() = p.getString("owned_bssid", "") ?: ""
        set(v) = p.edit().putString("owned_bssid", v).apply()

    var ownedSsid: String
        get() = p.getString("owned_ssid", "") ?: ""
        set(v) = p.edit().putString("owned_ssid", v).apply()

    // ---------- Config geral ----------
    fun getBool(k: String, def: Boolean) = p.getBoolean(k, def)
    fun setBool(k: String, v: Boolean) = p.edit().putBoolean(k, v).apply()
    fun getStr(k: String, def: String = "") = p.getString(k, def) ?: def
    fun setStr(k: String, v: String) = p.edit().putString(k, v).apply()
    fun getInt(k: String, def: Int) = p.getInt(k, def)
    fun setInt(k: String, v: Int) = p.edit().putInt(k, v).apply()
    fun getLong(k: String, def: Long) = p.getLong(k, def)
    fun setLong(k: String, v: Long) = p.edit().putLong(k, v).apply()
}
