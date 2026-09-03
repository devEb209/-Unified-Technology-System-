package net.kairos.manager.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import net.kairos.manager.core.KairosVM
import net.kairos.manager.net.Tools

@Composable
fun ToolsScreen(vm: KairosVM) {
    val snap by vm.snapshot.collectAsState()
    val scope = rememberCoroutineScope()
    val clip = LocalClipboardManager.current

    var host by remember { mutableStateOf(snap.gateway) }
    var output by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var wolMac by remember { mutableStateOf("") }
    var genPass by remember { mutableStateOf("") }

    fun run(label: String, block: suspend () -> String) {
        if (busy) return
        busy = true; output = "$label...\n"
        scope.launch {
            output = try { block() } catch (e: Exception) { "Erro: ${e.message}" }
            busy = false
        }
    }

    Column(
        Modifier.fillMaxSize().padding(horizontal = 14.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Spacer(Modifier.height(6.dp))

        KCard {
            Text("DIAGNÓSTICO", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                host, { host = it },
                label = { Text("Host ou IP") }, singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = KCyan, unfocusedBorderColor = Color(0x2200D4FF),
                    focusedTextColor = KText, unfocusedTextColor = KText)
            )
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ToolBtn("Ping", Icons.Default.NetworkPing, Modifier.weight(1f), !busy) {
                    run("Pingando $host") { Tools.ping(host) }
                }
                ToolBtn("Trace", Icons.Default.Route, Modifier.weight(1f), !busy) {
                    run("Traçando rota até $host") { Tools.traceroute(host) }
                }
                ToolBtn("DNS", Icons.Default.Dns, Modifier.weight(1f), !busy) {
                    run("Resolvendo $host") { Tools.dns(host) }
                }
            }
            Spacer(Modifier.height(8.dp))
            ToolBtn("Teste de velocidade", Icons.Default.Speed, Modifier.fillMaxWidth(), !busy) {
                run("Medindo velocidade") { Tools.speedTest { output = it } }
            }
        }

        KCard {
            Text("WAKE-ON-LAN", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                wolMac, { wolMac = it },
                label = { Text("MAC do computador (AA:BB:CC:DD:EE:FF)") }, singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = KCyan, unfocusedBorderColor = Color(0x2200D4FF),
                    focusedTextColor = KText, unfocusedTextColor = KText)
            )
            Spacer(Modifier.height(8.dp))
            ToolBtn("Ligar computador", Icons.Default.PowerSettingsNew, Modifier.fillMaxWidth(), !busy) {
                val bcast = snap.prefix + "255"
                run("Enviando magic packet") { Tools.wakeOnLan(wolMac, bcast) }
            }
        }

        KCard {
            Text("SENHA WI-FI", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
            Spacer(Modifier.height(8.dp))
            if (genPass.isNotBlank())
                Text(genPass, color = KCyan, fontSize = 15.sp,
                    fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ToolBtn("Gerar forte", Icons.Default.Password, Modifier.weight(1f), true) {
                    genPass = Tools.generatePassword()
                }
                ToolBtn("Copiar", Icons.Default.ContentCopy, Modifier.weight(1f), genPass.isNotBlank()) {
                    clip.setText(AnnotatedString(genPass))
                }
            }
        }

        KCard {
            Text("SAÍDA", color = KMuted, fontSize = 11.sp, letterSpacing = 2.sp)
            Spacer(Modifier.height(8.dp))
            if (busy) LinearProgressIndicator(
                Modifier.fillMaxWidth().height(3.dp), color = KCyan, trackColor = Color(0x2200D4FF))
            Spacer(Modifier.height(8.dp))
            Text(
                output.ifBlank { "Nenhum comando executado ainda." },
                color = if (output.isBlank()) KMuted else KText,
                fontSize = 12.sp, fontFamily = FontFamily.Monospace
            )
        }
        Spacer(Modifier.height(80.dp))
    }
}

@Composable
private fun ToolBtn(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    mod: Modifier,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Button(
        onClick, enabled = enabled, modifier = mod,
        shape = RoundedCornerShape(12.dp),
        colors = ButtonDefaults.buttonColors(containerColor = KBlue, disabledContainerColor = KSurf2)
    ) {
        Icon(icon, null, Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, fontSize = 12.sp)
    }
}
