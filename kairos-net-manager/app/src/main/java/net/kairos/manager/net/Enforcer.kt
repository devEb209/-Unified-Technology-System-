package net.kairos.manager.net

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import net.kairos.manager.core.Device
import net.kairos.manager.core.Store
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * Camada de aplicação (enforcement) de bloqueio/pausa/QoS.
 *
 * Estratégias, em ordem de tentativa:
 *  1) API/painel do roteador (login + endpoints de MAC filter / parental control / QoS)
 *  2) Modo local: o app mantém o estado e re-aplica a cada ciclo
 *
 * O roteador é o único ponto que pode realmente cortar o tráfego de terceiros,
 * por isso as credenciais do painel são configuráveis na aba "Roteador".
 */
class Enforcer(private val ctx: Context, private val store: Store) {

    private val http = OkHttpClient.Builder()
        .connectTimeout(6, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()

    private fun gateway() = NetInfo.snapshot(ctx).gateway
    private fun user() = store.getStr("router_user", "admin")
    private fun pass() = store.getStr("router_pass", "")

    suspend fun block(d: Device): Result<String> = apply(d, true)
    suspend fun unblock(d: Device): Result<String> = apply(d, false)

    private suspend fun apply(d: Device, block: Boolean): Result<String> =
        withContext(Dispatchers.IO) {
            if (d.mac.isBlank()) return@withContext Result.failure(
                IllegalStateException("MAC desconhecido — não é possível aplicar no roteador")
            )
            val gw = gateway()
            val attempts = listOf(
                "http://$gw/cgi-bin/luci/admin/network/firewall/rules",
                "http://$gw/goform/MacFilter",
                "http://$gw/userRpm/WlanMacFilterRpm.htm",
                "http://$gw/api/device/blocklist"
            )
            var lastErr: String = "sem resposta"
            for (url in attempts) {
                try {
                    val body = FormBody.Builder()
                        .add("mac", d.mac)
                        .add("action", if (block) "block" else "allow")
                        .add("username", user())
                        .add("password", pass())
                        .build()
                    val req = Request.Builder().url(url).post(body).build()
                    http.newCall(req).execute().use { r ->
                        if (r.isSuccessful) return@withContext Result.success("Aplicado via $url")
                        lastErr = "HTTP ${r.code} em $url"
                    }
                } catch (e: Exception) {
                    lastErr = e.message ?: "erro"
                }
            }
            // fallback: estado local (o app segue marcando e avisando)
            Result.failure(IllegalStateException("Roteador não aceitou ($lastErr). Estado salvo localmente."))
        }

    /** Ajuste de prioridade/QoS (potência relativa de uso do Wi-Fi). */
    suspend fun setPriority(d: Device, priority: Int): Result<String> =
        withContext(Dispatchers.IO) {
            val gw = gateway()
            try {
                val body = FormBody.Builder()
                    .add("mac", d.mac)
                    .add("priority", priority.toString())
                    .add("username", user()).add("password", pass())
                    .build()
                val req = Request.Builder().url("http://$gw/api/qos/priority").post(body).build()
                http.newCall(req).execute().use { r ->
                    if (r.isSuccessful) return@withContext Result.success("QoS $priority aplicado")
                }
            } catch (e: Exception) { }
            Result.failure(IllegalStateException("QoS salvo apenas localmente"))
        }

    /** Limite de banda em Kbps (0 = ilimitado). */
    suspend fun setBandwidth(d: Device, kbps: Int): Result<String> =
        withContext(Dispatchers.IO) {
            val gw = gateway()
            try {
                val body = FormBody.Builder()
                    .add("mac", d.mac).add("down", kbps.toString()).add("up", kbps.toString())
                    .add("username", user()).add("password", pass()).build()
                val req = Request.Builder().url("http://$gw/api/qos/limit").post(body).build()
                http.newCall(req).execute().use { r ->
                    if (r.isSuccessful) return@withContext Result.success("Limite aplicado")
                }
            } catch (e: Exception) { }
            Result.failure(IllegalStateException("Limite salvo apenas localmente"))
        }

    suspend fun reachRouterPanel(): Boolean = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder().url("http://${gateway()}/").get().build()
            http.newCall(req).execute().use { it.isSuccessful || it.code < 500 }
        } catch (e: Exception) { false }
    }
}
