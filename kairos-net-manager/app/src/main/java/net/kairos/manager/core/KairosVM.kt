package net.kairos.manager.core

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import net.kairos.manager.net.Enforcer
import net.kairos.manager.net.NetInfo
import net.kairos.manager.net.Scanner
import net.kairos.manager.net.WifiSnapshot
import net.kairos.manager.systems.Systems

class KairosVM(app: Application) : AndroidViewModel(app) {

    val store = Store(app)
    private val enforcer = Enforcer(app, store)

    val devices = MutableStateFlow<List<Device>>(store.loadDevices())
    val snapshot = MutableStateFlow(NetInfo.snapshot(app))
    val scanning = MutableStateFlow(false)
    val progress = MutableStateFlow(0)
    val toast = MutableStateFlow<String?>(null)
    val nextScanIn = MutableStateFlow(0L)
    val systems = MutableStateFlow(Systems.all)

    /** Só opera se estiver na rede marcada como sua. */
    val onMyNetwork: StateFlow<Boolean> get() = _onMy
    private val _onMy = MutableStateFlow(false)

    init {
        refreshSnapshot()
        viewModelScope.launch {
            while (true) {
                val last = store.getLong("last_scan", 0L)
                val elapsed = System.currentTimeMillis() - last
                nextScanIn.value = (KairosMonitorService.INTERVAL_MS - elapsed).coerceAtLeast(0)
                releaseExpiredPauses()
                delay(1000)
            }
        }
        viewModelScope.launch {
            while (true) {
                val last = store.getLong("last_scan", 0L)
                if (System.currentTimeMillis() - last >= KairosMonitorService.INTERVAL_MS) scan()
                delay(30_000)
            }
        }
    }

    fun refreshSnapshot() {
        val s = NetInfo.snapshot(getApplication())
        snapshot.value = s
        val owned = store.ownedBssid
        _onMy.value = s.connectedWifi && (owned.isBlank() || owned.equals(s.bssid, true))
    }

    fun claimNetwork() {
        val s = snapshot.value
        store.ownedBssid = s.bssid
        store.ownedSsid = s.ssid
        refreshSnapshot()
        toast.value = "Rede \"${s.ssid}\" registrada como SUA"
    }

    fun forgetNetwork() {
        store.ownedBssid = ""; store.ownedSsid = ""
        refreshSnapshot()
        toast.value = "Rede desvinculada"
    }

    fun scan() {
        if (scanning.value) return
        refreshSnapshot()
        if (!_onMy.value) { toast.value = "Você não está na SUA rede — operação bloqueada"; return }
        scanning.value = true; progress.value = 0
        viewModelScope.launch {
            val found = Scanner.scan(getApplication()) { progress.value = it }
            val known = devices.value.toMutableList()
            val byId = known.associateBy { it.id }.toMutableMap()
            val now = System.currentTimeMillis()
            byId.values.forEach { it.online = false }
            found.forEach { f ->
                val ex = byId[f.id]
                if (ex == null) {
                    byId[f.id] = f
                    store.addHistory(HistoryEntry(now, f.id, "NOVO_DISPOSITIVO", "${f.ip} ${f.vendor}"))
                } else {
                    if (!ex.online) store.addHistory(HistoryEntry(now, ex.id, "CONECTOU", f.ip))
                    ex.online = true; ex.ip = f.ip; ex.lastSeen = now
                    ex.rttMs = f.rttMs; if (ex.vendor.isBlank()) ex.vendor = f.vendor
                }
            }
            val list = byId.values.sortedWith(
                compareByDescending<Device> { it.favorite }
                    .thenByDescending { it.online }
                    .thenBy { it.ip.substringAfterLast(".").toIntOrNull() ?: 999 }
            )
            devices.value = list
            store.saveDevices(list)
            store.setLong("last_scan", now)
            scanning.value = false
            toast.value = "${found.size} dispositivos na rede"
        }
    }

    /** Emite uma nova lista de cópias para o Compose recompor de fato. */
    private fun persist() {
        val snapshotList = devices.value.map { it.copy() }
        store.saveDevices(snapshotList)
        devices.value = snapshotList
    }

    fun byId(id: String): Device? = devices.value.firstOrNull { it.id == id }

    private fun log(d: Device, ev: String, detail: String = "") =
        store.addHistory(HistoryEntry(System.currentTimeMillis(), d.id, ev, detail))

    // ---------------- Ações ----------------

    fun toggleBlock(d: Device) {
        if (d.isPaused) { toast.value = "Pausa blindada ativa — aguarde ${pauseLeft(d)}"; return }
        viewModelScope.launch {
            val wantBlock = !d.blocked
            d.blocked = wantBlock
            log(d, if (wantBlock) "BLOQUEADO" else "DESBLOQUEADO")
            persist()
            val r = if (wantBlock) enforcer.block(d) else enforcer.unblock(d)
            toast.value = r.getOrElse { it.message } ?: "OK"
        }
    }

    /** Pausa blindada: 3 horas e 7 minutos, sem desfazer. */
    fun pauseArmored(d: Device) {
        if (d.isPaused) { toast.value = "Já pausado — faltam ${pauseLeft(d)}"; return }
        val ms = (3 * 60 + 7) * 60 * 1000L
        d.pausedUntil = System.currentTimeMillis() + ms
        d.blocked = true
        log(d, "PAUSA_BLINDADA", "3h07min")
        persist()
        viewModelScope.launch { enforcer.block(d) }
        toast.value = "${d.label} pausado por 3h07 (irreversível)"
    }

    fun pauseLeft(d: Device): String {
        val ms = (d.pausedUntil - System.currentTimeMillis()).coerceAtLeast(0)
        val h = ms / 3600000; val m = (ms % 3600000) / 60000; val s = (ms % 60000) / 1000
        return "%02d:%02d:%02d".format(h, m, s)
    }

    private fun releaseExpiredPauses() {
        var changed = false
        devices.value.forEach { d ->
            if (d.pausedUntil in 1..System.currentTimeMillis()) {
                d.pausedUntil = 0; d.blocked = false; changed = true
                log(d, "PAUSA_EXPIROU")
                viewModelScope.launch { enforcer.unblock(d) }
            }
        }
        if (changed) persist()
    }

    fun setPriority(d: Device, p: Int) {
        d.priority = p.coerceIn(1, 5)
        log(d, "PRIORIDADE", "nível ${d.priority}")
        persist()
        viewModelScope.launch {
            val r = enforcer.setPriority(d, d.priority)
            toast.value = r.getOrElse { it.message }
        }
    }

    fun boost(d: Device) = setPriority(d, d.priority + 1)
    fun throttle(d: Device) = setPriority(d, d.priority - 1)

    fun setBandwidth(d: Device, kbps: Int) {
        d.bandwidthCapKbps = kbps.coerceAtLeast(0)
        log(d, "LIMITE_BANDA", if (kbps == 0) "ilimitado" else "$kbps Kbps")
        persist()
        viewModelScope.launch { enforcer.setBandwidth(d, kbps) }
    }

    fun rename(d: Device, name: String) { d.name = name; log(d, "RENOMEADO", name); persist() }
    fun toggleTrusted(d: Device) { d.trusted = !d.trusted; log(d, if (d.trusted) "CONFIAVEL" else "NAO_CONFIAVEL"); persist() }
    fun toggleFavorite(d: Device) { d.favorite = !d.favorite; persist() }
    fun setNotes(d: Device, n: String) { d.notes = n; persist() }

    fun panic() {
        val me = snapshot.value.ip
        devices.value.filter { it.ip != me && it.iface != "router" }.forEach {
            it.blocked = true; log(it, "PANICO_BLOQUEIO")
            viewModelScope.launch { enforcer.block(it) }
        }
        persist()
        toast.value = "Modo pânico: todos bloqueados exceto você"
    }

    fun unblockAll() {
        devices.value.filter { it.blocked && !it.isPaused }.forEach {
            it.blocked = false; log(it, "DESBLOQUEADO_LOTE")
            viewModelScope.launch { enforcer.unblock(it) }
        }
        persist()
        toast.value = "Todos liberados (exceto pausas blindadas)"
    }

    fun scanPorts(d: Device) {
        viewModelScope.launch {
            toast.value = "Escaneando portas de ${d.label}..."
            val ports = withContext(Dispatchers.IO) { Scanner.openPorts(d.ip) }
            val i = devices.value.indexOfFirst { it.id == d.id }
            if (i >= 0) devices.value = devices.value.toMutableList().also {
                it[i] = it[i].copy(openPorts = ports)
            }
            log(d, "SCAN_PORTAS", ports.joinToString(","))
            toast.value = if (ports.isEmpty()) "Nenhuma porta comum aberta" else "Abertas: ${ports.joinToString(", ")}"
        }
    }

    fun history(d: Device) = store.history(d.id)
    fun allHistory() = store.history()
    fun clearHistory() { store.clearHistory(); toast.value = "Histórico limpo" }

    fun healthScore(): Int {
        val list = devices.value
        if (list.isEmpty()) return 0
        var score = 100
        val unknown = list.count { !it.trusted && it.online }
        score -= unknown * 4
        val avgRtt = list.filter { it.online && it.rttMs > 0 }.map { it.rttMs }.average()
        if (!avgRtt.isNaN()) score -= (avgRtt / 20).toInt()
        val rssi = snapshot.value.rssi
        if (rssi < -75) score -= 15 else if (rssi < -65) score -= 7
        return score.coerceIn(0, 100)
    }

    fun toggleSystem(id: Int) {
        systems.value = systems.value.map { if (it.id == id) it.copy(enabled = !it.enabled) else it }
    }

    fun clearToast() { toast.value = null }
}
