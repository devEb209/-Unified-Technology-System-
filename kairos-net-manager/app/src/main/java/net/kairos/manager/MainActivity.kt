package net.kairos.manager

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.delay
import net.kairos.manager.core.Auth
import net.kairos.manager.core.KairosMonitorService
import net.kairos.manager.core.KairosVM
import net.kairos.manager.ui.*

class MainActivity : ComponentActivity() {

    private val perms = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {}

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestPerms()
        setContent { KairosTheme { KairosApp() } }
    }

    private fun requestPerms() {
        val list = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        if (Build.VERSION.SDK_INT >= 33) {
            list += Manifest.permission.POST_NOTIFICATIONS
            list += Manifest.permission.NEARBY_WIFI_DEVICES
        }
        if (Build.VERSION.SDK_INT >= 31) {
            list += Manifest.permission.BLUETOOTH_SCAN
            list += Manifest.permission.BLUETOOTH_CONNECT
        }
        perms.launch(list.toTypedArray())
    }

    override fun onPause() { super.onPause(); }
}

@Composable
fun KairosApp() {
    var unlocked by remember { mutableStateOf(Auth.isUnlocked) }
    if (!unlocked) { LockScreen { unlocked = true }; return }

    val vm: KairosVM = viewModel()
    val ctx = androidx.compose.ui.platform.LocalContext.current
    var tab by remember { mutableStateOf(0) }
    val toast by vm.toast.collectAsState()
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(Unit) { KairosMonitorService.start(ctx) }
    LaunchedEffect(toast) { toast?.let { snackbar.showSnackbar(it); vm.clearToast() } }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            vm.refreshSnapshot()
            if (!Auth.isUnlocked) unlocked = false
        }
    }

    val tabs = listOf(
        Triple("Painel", Icons.Default.Dashboard, 0),
        Triple("Aparelhos", Icons.Default.Devices, 1),
        Triple("Histórico", Icons.Default.History, 2),
        Triple("Sistemas", Icons.Default.GridView, 3),
        Triple("Ajustes", Icons.Default.Settings, 4)
    )

    KairosBackground {
        Scaffold(
            containerColor = androidx.compose.ui.graphics.Color.Transparent,
            snackbarHost = { SnackbarHost(snackbar) },
            topBar = {
                Column(Modifier.padding(start = 18.dp, top = 38.dp, bottom = 6.dp)) {
                    Text("KÄIRŌS", color = KText, fontSize = 26.sp, fontWeight = FontWeight.Black)
                    Text("NET MANAGER", color = KBlue, fontSize = 10.sp, letterSpacing = 5.sp)
                }
            },
            bottomBar = {
                NavigationBar(containerColor = KSurf) {
                    tabs.forEach { (label, icon, idx) ->
                        NavigationBarItem(
                            selected = tab == idx,
                            onClick = { tab = idx; Auth.touch() },
                            icon = { Icon(icon, null) },
                            label = { Text(label, fontSize = 10.sp) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = KCyan, selectedTextColor = KCyan,
                                unselectedIconColor = KMuted, unselectedTextColor = KMuted,
                                indicatorColor = KSurf2
                            )
                        )
                    }
                }
            }
        ) { pad ->
            Box(Modifier.padding(pad)) {
                when (tab) {
                    0 -> DashboardScreen(vm)
                    1 -> DevicesScreen(vm)
                    2 -> HistoryScreen(vm)
                    3 -> SystemsScreen(vm)
                    else -> SettingsScreen(vm) { Auth.lock(); unlocked = false }
                }
            }
        }
    }
}
