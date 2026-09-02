package net.kairos.manager.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import net.kairos.manager.core.Device
import net.kairos.manager.core.KairosVM
import net.kairos.manager.systems.Systems
import java.text.SimpleDateFormat
import java.util.*

private val fmt = SimpleDateFormat("dd/MM HH:mm:ss", Locale("pt", "BR"))

/* ============================ PAINEL ============================ */

@Composable
fun DashboardScreen(vm: KairosVM) {
    val snap by vm.snapshot.collectAsState()
    val devs by vm.devices.collectAsState()
    val mine by vm.onMyNetwork.collectAsState()
    val scanning by vm.scanning.collectAsState()
    val progress by vm.progress.collectAsState()
    val next by vm.nextScanIn.collectAsState()

    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = 14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item { Spacer(Modifier.height(6.dp)) }

        item {
            KCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Wifi, null, tint = if (mine) KGreen else KAmber)
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(snap.ssid.ifBlank { "Sem Wi-Fi" },
                            color = KText, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text(
                            if (mine) "Você está na SUA rede" else "Rede não autorizada — controles travados",
                            color = if (mine) KGreen else KAmber, fontSize = 12.sp
                        )
                    }
                    if (!mine && snap.connectedWifi)
                        TextButton({ vm.claimNetwork() }) { Text("Marcar como minha", color = KCyan) }
                }
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Stat("IP", snap.ip, Modifier.weight(1f))
                    Stat("Gateway", snap.gateway, Modifier.weight(1f))
                }
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Stat("Sinal", "${snap.rssi} dBm", Modifier.weight(1f))
                    Stat("Link", "${snap.linkSpeedMbps} Mbps", Modifier.weight(1f))
                    Stat("Freq", "${snap.frequency} MHz", Modifier.weight(1f))
                }
            }
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                KpiCard("Dispositivos", devs.count { it.online }.toString(), Icons.Default.Devices, Modifier.weight(1f))
                KpiCard("Bloqueados", devs.count { it.blocked }.toString(), Icons.Default.Block, Modifier.weight(1f))
                KpiCard("Saúde", "${vm.healthScore()}", Icons.Default.MonitorHeart, Modifier.weight(1f))
            }
        }

        item {
            KCard {
                Text("CICLO AUTOMÁTICO", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                Spacer(Modifier.height(8.dp))
                val m = next / 60000; val s = (next % 60000) / 1000
                Text("Próxima varredura em %02d:%02d".format(m, s), color = KText, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { if (scanning) progress / 100f else 1f - (next.toFloat() / (7 * 60000f)) },
                    modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
                    color = KCyan, trackColor = Color(0x2200D4FF)
                )
                Spacer(Modifier.height(12.dp))
                Button(
                    { vm.scan() }, enabled = !scanning && mine,
                    colors = ButtonDefaults.buttonColors(containerColor = KBlue),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Default.Radar, null); Spacer(Modifier.width(8.dp))
                    Text(if (scanning) "Escaneando $progress%" else "Escanear agora")
                }
            }
        }

        item {
            KCard {
                Text("AÇÕES RÁPIDAS", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button({ vm.panic() },
                        colors = ButtonDefaults.buttonColors(containerColor = KRed),
                        shape = RoundedCornerShape(12.dp), modifier = Modifier.weight(1f)) {
                        Icon(Icons.Default.Emergency, null); Spacer(Modifier.width(6.dp)); Text("Pânico")
                    }
                    Button({ vm.unblockAll() },
                        colors = ButtonDefaults.buttonColors(containerColor = KGreen),
                        shape = RoundedCornerShape(12.dp), modifier = Modifier.weight(1f)) {
                        Icon(Icons.Default.LockOpen, null, tint = Color.Black); Spacer(Modifier.width(6.dp))
                        Text("Liberar", color = Color.Black)
                    }
                }
            }
        }

        item {
            KCard {
                Text("TOP CONSUMIDORES", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                Spacer(Modifier.height(8.dp))
                val top = devs.sortedByDescending { it.rxBytes + it.txBytes }.take(5)
                if (top.isEmpty()) Text("Sem dados ainda", color = KMuted, fontSize = 13.sp)
                top.forEach {
                    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                        Text(it.label, color = KText, fontSize = 13.sp, modifier = Modifier.weight(1f))
                        Text(fmtBytes(it.rxBytes + it.txBytes), color = KCyan, fontSize = 13.sp)
                    }
                }
            }
        }
        item { Spacer(Modifier.height(80.dp)) }
    }
}

@Composable
private fun Stat(label: String, value: String, mod: Modifier = Modifier) {
    Column(mod) {
        Text(label, color = KMuted, fontSize = 10.sp)
        Text(value, color = KText, fontSize = 14.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun KpiCard(label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, mod: Modifier) {
    Surface(mod, color = KSurf2, shape = RoundedCornerShape(16.dp)) {
        Column(Modifier.padding(12.dp)) {
            Icon(icon, null, tint = KCyan, modifier = Modifier.size(20.dp))
            Spacer(Modifier.height(6.dp))
            Text(value, color = KText, fontSize = 22.sp, fontWeight = FontWeight.Black)
            Text(label, color = KMuted, fontSize = 10.sp)
        }
    }
}

fun fmtBytes(b: Long): String = when {
    b > 1_000_000_000 -> "%.1f GB".format(b / 1e9)
    b > 1_000_000 -> "%.1f MB".format(b / 1e6)
    b > 1000 -> "%.1f KB".format(b / 1e3)
    else -> "$b B"
}

/* ============================ DISPOSITIVOS ============================ */

@Composable
fun DevicesScreen(vm: KairosVM) {
    val devs by vm.devices.collectAsState()
    val mine by vm.onMyNetwork.collectAsState()
    var selected by remember { mutableStateOf<Device?>(null) }
    var query by remember { mutableStateOf("") }

    Column(Modifier.fillMaxSize().padding(horizontal = 14.dp)) {
        OutlinedTextField(
            query, { query = it },
            placeholder = { Text("Buscar por nome, IP ou MAC", color = KMuted) },
            leadingIcon = { Icon(Icons.Default.Search, null, tint = KMuted) },
            singleLine = true, shape = RoundedCornerShape(14.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = KCyan, unfocusedBorderColor = Color(0x2200D4FF),
                focusedTextColor = KText, unfocusedTextColor = KText
            ),
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
        )
        val list = devs.filter {
            query.isBlank() || it.label.contains(query, true) ||
                it.ip.contains(query) || it.mac.contains(query, true)
        }
        if (!mine) {
            KCard { Text("Conecte-se à SUA rede para gerenciar os dispositivos.", color = KAmber) }
            Spacer(Modifier.height(10.dp))
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(list, key = { it.id }) { d -> DeviceRow(vm, d) { selected = d } }
            item { Spacer(Modifier.height(80.dp)) }
        }
    }

    selected?.let { DeviceSheet(vm, it) { selected = null } }
}

@Composable
private fun DeviceRow(vm: KairosVM, d: Device, onOpen: () -> Unit) {
    var tick by remember { mutableStateOf(0) }
    LaunchedEffect(d.pausedUntil) {
        while (d.isPaused) { tick++; kotlinx.coroutines.delay(1000) }
    }
    KCard(Modifier.clickable(onClick = onOpen)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(10.dp).clip(RoundedCornerShape(5.dp))
                    .then(Modifier).background2(if (d.online) KGreen else KMuted)
            )
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(d.label, color = KText, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    if (d.trusted) { Spacer(Modifier.width(6.dp)); Icon(Icons.Default.Verified, null, tint = KCyan, modifier = Modifier.size(14.dp)) }
                    if (d.favorite) { Spacer(Modifier.width(4.dp)); Icon(Icons.Default.Star, null, tint = KAmber, modifier = Modifier.size(14.dp)) }
                }
                Text("${d.ip}  •  ${d.mac.ifBlank { "MAC oculto" }}", color = KMuted, fontSize = 11.sp)
                Text("Prioridade ${d.priority}/5  •  ${if (d.rttMs >= 0) "${d.rttMs}ms" else "—"}", color = KMuted, fontSize = 11.sp)
                if (d.isPaused) Text("PAUSA BLINDADA ${vm.pauseLeft(d)}", color = KAmber, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton({ vm.toggleBlock(d) }) {
                    Icon(
                        if (d.blocked) Icons.Default.Block else Icons.Default.CheckCircle, null,
                        tint = if (d.blocked) KRed else KGreen
                    )
                }
                Text(if (d.blocked) "Bloq." else "Livre", color = if (d.blocked) KRed else KGreen, fontSize = 10.sp)
            }
        }
    }
}

private fun Modifier.background2(c: Color) = this.then(
    androidx.compose.foundation.background(c, RoundedCornerShape(5.dp))
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DeviceSheet(vm: KairosVM, d: Device, onClose: () -> Unit) {
    var name by remember { mutableStateOf(d.name) }
    var cap by remember { mutableStateOf(d.bandwidthCapKbps.toString()) }
    var confirmPause by remember { mutableStateOf(false) }

    ModalBottomSheet(onDismissRequest = onClose, containerColor = KSurf) {
        Column(Modifier.padding(18.dp).fillMaxWidth()) {
            Text(d.label, color = KText, fontSize = 22.sp, fontWeight = FontWeight.Black)
            Text("${d.ip} • ${d.mac.ifBlank { "MAC oculto" }} • ${d.vendor.ifBlank { "fabricante desconhecido" }}",
                color = KMuted, fontSize = 12.sp)
            Spacer(Modifier.height(16.dp))

            OutlinedTextField(name, { name = it }, label = { Text("Apelido") },
                singleLine = true, modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = KCyan, unfocusedBorderColor = Color(0x2200D4FF),
                    focusedTextColor = KText, unfocusedTextColor = KText))
            TextButton({ vm.rename(d, name) }) { Text("Salvar apelido", color = KCyan) }

            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button({ vm.toggleBlock(d) }, enabled = !d.isPaused,
                    colors = ButtonDefaults.buttonColors(containerColor = if (d.blocked) KGreen else KRed),
                    shape = RoundedCornerShape(12.dp), modifier = Modifier.weight(1f)) {
                    Text(if (d.blocked) "Desbloquear" else "Bloquear")
                }
                Button({ confirmPause = true }, enabled = !d.isPaused,
                    colors = ButtonDefaults.buttonColors(containerColor = KAmber),
                    shape = RoundedCornerShape(12.dp), modifier = Modifier.weight(1f)) {
                    Text("Pausar 3h07", color = Color.Black)
                }
            }
            if (d.isPaused) {
                Spacer(Modifier.height(8.dp))
                Text("Pausa blindada ativa: ${vm.pauseLeft(d)} — não pode ser desfeita.",
                    color = KAmber, fontSize = 12.sp)
            }

            Spacer(Modifier.height(16.dp))
            Text("POTÊNCIA / PRIORIDADE DO WI-FI", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton({ vm.throttle(d) }) { Icon(Icons.Default.Remove, null, tint = KRed) }
                Slider(
                    value = d.priority.toFloat(), onValueChange = { vm.setPriority(d, it.toInt()) },
                    valueRange = 1f..5f, steps = 3, modifier = Modifier.weight(1f),
                    colors = SliderDefaults.colors(thumbColor = KCyan, activeTrackColor = KBlue)
                )
                IconButton({ vm.boost(d) }) { Icon(Icons.Default.Add, null, tint = KGreen) }
            }
            Text("Nível ${d.priority} de 5", color = KText, fontSize = 13.sp)

            Spacer(Modifier.height(14.dp))
            OutlinedTextField(cap, { cap = it.filter(Char::isDigit) },
                label = { Text("Limite de banda (Kbps, 0 = ilimitado)") },
                singleLine = true, modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = KCyan, unfocusedBorderColor = Color(0x2200D4FF),
                    focusedTextColor = KText, unfocusedTextColor = KText))
            TextButton({ vm.setBandwidth(d, cap.toIntOrNull() ?: 0) }) { Text("Aplicar limite", color = KCyan) }

            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton({ vm.toggleTrusted(d) }, modifier = Modifier.weight(1f)) {
                    Text(if (d.trusted) "Remover confiança" else "Marcar confiável", color = KCyan, fontSize = 12.sp)
                }
                OutlinedButton({ vm.toggleFavorite(d) }, modifier = Modifier.weight(1f)) {
                    Text(if (d.favorite) "Desfixar" else "Favoritar", color = KCyan, fontSize = 12.sp)
                }
            }
            OutlinedButton({ vm.scanPorts(d) }, modifier = Modifier.fillMaxWidth()) {
                Text("Escanear portas abertas", color = KCyan, fontSize = 12.sp)
            }
            if (d.openPorts.isNotEmpty())
                Text("Portas: ${d.openPorts.joinToString(", ")}", color = KAmber, fontSize = 12.sp)

            Spacer(Modifier.height(16.dp))
            Text("HISTÓRICO DESTE APARELHO", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
            Spacer(Modifier.height(6.dp))
            vm.history(d).take(20).forEach {
                Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                    Text(fmt.format(Date(it.ts)), color = KMuted, fontSize = 11.sp)
                    Spacer(Modifier.width(10.dp))
                    Text(it.event, color = KText, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                    Spacer(Modifier.width(6.dp))
                    Text(it.detail, color = KMuted, fontSize = 11.sp)
                }
            }
            Spacer(Modifier.height(40.dp))
        }
    }

    if (confirmPause) {
        AlertDialog(
            onDismissRequest = { confirmPause = false },
            containerColor = KSurf,
            title = { Text("Pausa blindada", color = KText) },
            text = {
                Text("A internet de ${d.label} ficará cortada por 3 horas e 7 minutos. " +
                    "Não será possível reverter antes do prazo. Confirmar?", color = KMuted)
            },
            confirmButton = {
                TextButton({ vm.pauseArmored(d); confirmPause = false }) { Text("Confirmar", color = KRed) }
            },
            dismissButton = { TextButton({ confirmPause = false }) { Text("Cancelar", color = KMuted) } }
        )
    }
}

/* ============================ HISTÓRICO ============================ */

@Composable
fun HistoryScreen(vm: KairosVM) {
    val devs by vm.devices.collectAsState()
    var refresh by remember { mutableStateOf(0) }
    val entries = remember(refresh) { vm.allHistory() }
    val names = devs.associate { it.id to it.label }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item {
            Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("${entries.size} eventos", color = KMuted, fontSize = 13.sp, modifier = Modifier.weight(1f))
                TextButton({ vm.clearHistory(); refresh++ }) { Text("Limpar", color = KRed) }
            }
        }
        items(entries) { e ->
            KCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(iconFor(e.event), null, tint = colorFor(e.event), modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(names[e.deviceId] ?: e.deviceId, color = KText, fontSize = 14.sp, fontWeight = FontWeight.Medium)
                        Text("${e.event} ${e.detail}", color = KMuted, fontSize = 11.sp)
                    }
                    Text(fmt.format(Date(e.ts)), color = KMuted, fontSize = 10.sp)
                }
            }
        }
        item { Spacer(Modifier.height(80.dp)) }
    }
}

private fun iconFor(ev: String) = when {
    ev.startsWith("BLOQ") || ev.startsWith("PANICO") -> Icons.Default.Block
    ev.startsWith("PAUSA") -> Icons.Default.PauseCircle
    ev.startsWith("NOVO") -> Icons.Default.NewReleases
    ev.startsWith("CONECT") -> Icons.Default.Login
    ev.startsWith("DESCONECT") -> Icons.Default.Logout
    else -> Icons.Default.Info
}

private fun colorFor(ev: String) = when {
    ev.startsWith("BLOQ") || ev.startsWith("PANICO") -> KRed
    ev.startsWith("PAUSA") -> KAmber
    ev.startsWith("NOVO") -> KCyan
    else -> KMuted
}

/* ============================ SISTEMAS ============================ */

@Composable
fun SystemsScreen(vm: KairosVM) {
    val mods by vm.systems.collectAsState()
    var cat by remember { mutableStateOf("Todos") }
    val cats = listOf("Todos") + Systems.categories

    Column(Modifier.fillMaxSize().padding(horizontal = 14.dp)) {
        Text("${mods.size} sistemas • ${mods.count { it.enabled }} ativos",
            color = KMuted, fontSize = 12.sp, modifier = Modifier.padding(vertical = 8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                Row(Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    cats.forEach { c ->
                        FilterChip(cat == c, { cat = c }, { Text(c, fontSize = 12.sp) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = KBlue, labelColor = KMuted,
                                selectedLabelColor = Color.White))
                    }
                }
            }
            items(mods.filter { cat == "Todos" || it.category == cat }) { m ->
                KCard {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("%02d".format(m.id), color = KCyan, fontWeight = FontWeight.Black, fontSize = 16.sp)
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(m.name, color = KText, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text(m.description, color = KMuted, fontSize = 11.sp)
                            Text(m.category, color = KBlue, fontSize = 10.sp)
                        }
                        Switch(m.enabled, { vm.toggleSystem(m.id) },
                            colors = SwitchDefaults.colors(checkedThumbColor = KCyan, checkedTrackColor = KBlue))
                    }
                }
            }
            item { Spacer(Modifier.height(80.dp)) }
        }
    }
}

/* ============================ AJUSTES ============================ */

@Composable
fun SettingsScreen(vm: KairosVM, onLock: () -> Unit) {
    val store = vm.store
    val snap by vm.snapshot.collectAsState()
    var user by remember { mutableStateOf(store.getStr("router_user", "admin")) }
    var pass by remember { mutableStateOf(store.getStr("router_pass", "")) }
    var autostart by remember { mutableStateOf(store.getBool("autostart", true)) }
    var alerts by remember { mutableStateOf(store.getBool("alerts", true)) }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Spacer(Modifier.height(6.dp)) }
        item {
            KCard {
                Text("MINHA REDE", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                Spacer(Modifier.height(8.dp))
                Text("SSID vinculado: ${store.ownedSsid.ifBlank { "nenhum" }}", color = KText, fontSize = 14.sp)
                Text("BSSID: ${store.ownedBssid.ifBlank { "—" }}", color = KMuted, fontSize = 11.sp)
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button({ vm.claimNetwork() }, colors = ButtonDefaults.buttonColors(containerColor = KBlue),
                        modifier = Modifier.weight(1f), shape = RoundedCornerShape(12.dp)) {
                        Text("Vincular atual", fontSize = 12.sp)
                    }
                    OutlinedButton({ vm.forgetNetwork() }, modifier = Modifier.weight(1f)) {
                        Text("Desvincular", color = KRed, fontSize = 12.sp)
                    }
                }
            }
        }
        item {
            KCard {
                Text("PAINEL DO ROTEADOR", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                Text("Necessário para aplicar bloqueios de verdade no roteador (${snap.gateway})",
                    color = KMuted, fontSize = 11.sp)
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(user, { user = it; store.setStr("router_user", it) },
                    label = { Text("Usuário") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = KCyan, unfocusedBorderColor = Color(0x2200D4FF),
                        focusedTextColor = KText, unfocusedTextColor = KText))
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(pass, { pass = it; store.setStr("router_pass", it) },
                    label = { Text("Senha do painel") }, singleLine = true,
                    visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = KCyan, unfocusedBorderColor = Color(0x2200D4FF),
                        focusedTextColor = KText, unfocusedTextColor = KText))
            }
        }
        item {
            KCard {
                Text("COMPORTAMENTO", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                SettingSwitch("Iniciar com o celular", autostart) { autostart = it; store.setBool("autostart", it) }
                SettingSwitch("Alertar dispositivo novo", alerts) { alerts = it; store.setBool("alerts", it) }
            }
        }
        item {
            KCard {
                Text("SEGURANÇA", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
                Spacer(Modifier.height(8.dp))
                Text("Senha secreta exclusiva do app (não é a senha real do Wi-Fi). " +
                    "Sessão expira em 15 min de inatividade; 5 erros travam o app por 5 min.",
                    color = KMuted, fontSize = 12.sp)
                Spacer(Modifier.height(10.dp))
                Button(onLock, colors = ButtonDefaults.buttonColors(containerColor = KRed),
                    shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.Lock, null); Spacer(Modifier.width(8.dp)); Text("Trancar agora")
                }
            }
        }
        item {
            KCard {
                Text("Käirōs Net Manager v1.0.0", color = KText, fontWeight = FontWeight.Bold)
                Text("78 sistemas • uso pessoal na sua própria rede", color = KMuted, fontSize = 11.sp)
            }
        }
        item { Spacer(Modifier.height(80.dp)) }
    }
}

@Composable
private fun SettingSwitch(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = KText, fontSize = 14.sp, modifier = Modifier.weight(1f))
        Switch(checked, onChange, colors = SwitchDefaults.colors(
            checkedThumbColor = KCyan, checkedTrackColor = KBlue))
    }
}
