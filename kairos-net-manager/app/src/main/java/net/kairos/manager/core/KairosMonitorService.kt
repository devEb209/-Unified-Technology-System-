package net.kairos.manager.core

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import net.kairos.manager.MainActivity
import net.kairos.manager.R
import net.kairos.manager.net.NetInfo
import net.kairos.manager.net.Scanner

/** Serviço em primeiro plano: varre a rede a cada 7 minutos. */
class KairosMonitorService : Service() {

    companion object {
        const val CH = "kairos_monitor"
        const val INTERVAL_MS = 7 * 60 * 1000L
        fun start(ctx: Context) {
            val i = Intent(ctx, KairosMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }
        fun stop(ctx: Context) = ctx.stopService(Intent(ctx, KairosMonitorService::class.java))
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(1, notif("Monitorando sua rede", "Ciclo automático de 7 minutos ativo"))
        scope.launch { loop() }
    }

    private suspend fun loop() {
        val store = Store(this)
        while (isActive) {
            try {
                val snap = NetInfo.snapshot(this)
                val owned = store.ownedBssid
                if (snap.connectedWifi && (owned.isBlank() || owned.equals(snap.bssid, true))) {
                    val found = Scanner.scan(this)
                    val known = store.loadDevices()
                    val byId = known.associateBy { it.id }.toMutableMap()
                    val now = System.currentTimeMillis()

                    known.forEach { it.online = false }
                    found.forEach { f ->
                        val ex = byId[f.id]
                        if (ex == null) {
                            byId[f.id] = f
                            store.addHistory(HistoryEntry(now, f.id, "NOVO_DISPOSITIVO", "${f.ip} ${f.vendor}"))
                            notifyEvent("Novo dispositivo", "${f.label} entrou na sua rede")
                        } else {
                            if (!ex.online) store.addHistory(HistoryEntry(now, ex.id, "CONECTOU", f.ip))
                            ex.online = true; ex.ip = f.ip; ex.lastSeen = now; ex.rttMs = f.rttMs
                        }
                    }
                    known.filter { !it.online && now - it.lastSeen < INTERVAL_MS * 2 }
                        .forEach { store.addHistory(HistoryEntry(now, it.id, "DESCONECTOU", it.ip)) }

                    store.saveDevices(byId.values.toList())
                    store.setLong("last_scan", now)
                }
            } catch (e: Exception) { }
            delay(INTERVAL_MS)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(CH, "Käirōs Monitor", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    private fun notif(title: String, text: String) =
        NotificationCompat.Builder(this, CH)
            .setContentTitle(title).setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .setContentIntent(
                android.app.PendingIntent.getActivity(
                    this, 0, Intent(this, MainActivity::class.java),
                    android.app.PendingIntent.FLAG_IMMUTABLE
                )
            ).build()

    private fun notifyEvent(title: String, text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(
            (System.currentTimeMillis() % 100000).toInt(),
            NotificationCompat.Builder(this, CH)
                .setContentTitle(title).setContentText(text)
                .setSmallIcon(android.R.drawable.stat_notify_error)
                .setAutoCancel(true).build()
        )
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            if (Store(context).getBool("autostart", true)) KairosMonitorService.start(context)
        }
    }
}
