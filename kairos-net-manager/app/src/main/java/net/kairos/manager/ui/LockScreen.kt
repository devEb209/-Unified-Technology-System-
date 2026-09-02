package net.kairos.manager.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import net.kairos.manager.core.Auth

@Composable
fun LockScreen(onUnlock: () -> Unit) {
    var pass by remember { mutableStateOf("") }
    var show by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    var lockLeft by remember { mutableStateOf(0L) }

    LaunchedEffect(Unit) {
        while (true) { lockLeft = Auth.lockoutRemainingSec(); delay(1000) }
    }

    KairosBackground {
        Column(
            Modifier.fillMaxSize().padding(28.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(Icons.Default.Lock, null, tint = KCyan, modifier = Modifier.size(64.dp))
            Spacer(Modifier.height(18.dp))
            Text("KÄIRŌS", fontSize = 40.sp, fontWeight = FontWeight.Black, color = KText)
            Text("NET MANAGER", fontSize = 15.sp, letterSpacing = 6.sp, color = KBlue)
            Spacer(Modifier.height(6.dp))
            Text("CONTROLE TOTAL. SEM LIMITES.",
                fontSize = 10.sp, letterSpacing = 3.sp, color = KMuted)
            Spacer(Modifier.height(42.dp))

            OutlinedTextField(
                value = pass,
                onValueChange = { pass = it; error = "" },
                label = { Text("Senha secreta do app") },
                singleLine = true,
                enabled = lockLeft == 0L,
                visualTransformation = if (show) VisualTransformation.None else PasswordVisualTransformation(),
                trailingIcon = {
                    IconButton({ show = !show }) {
                        Icon(if (show) Icons.Default.VisibilityOff else Icons.Default.Visibility, null, tint = KMuted)
                    }
                },
                keyboardOptions = KeyboardOptions.Default,
                shape = RoundedCornerShape(14.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = KCyan, unfocusedBorderColor = Color(0x3300D4FF),
                    focusedLabelColor = KCyan, unfocusedLabelColor = KMuted,
                    focusedTextColor = KText, unfocusedTextColor = KText
                ),
                modifier = Modifier.fillMaxWidth()
            )

            if (error.isNotBlank()) {
                Spacer(Modifier.height(10.dp))
                Text(error, color = KRed, fontSize = 13.sp, textAlign = TextAlign.Center)
            }
            if (lockLeft > 0) {
                Spacer(Modifier.height(10.dp))
                Text("Bloqueado por ${lockLeft}s (muitas tentativas)", color = KAmber, fontSize = 13.sp)
            }

            Spacer(Modifier.height(20.dp))
            Button(
                onClick = {
                    if (Auth.check(pass)) onUnlock() else error = "Senha incorreta"
                    pass = ""
                },
                enabled = lockLeft == 0L && pass.isNotEmpty(),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = KBlue),
                modifier = Modifier.fillMaxWidth().height(52.dp)
            ) { Text("DESBLOQUEAR", fontWeight = FontWeight.Bold, letterSpacing = 2.sp) }

            Spacer(Modifier.height(24.dp))
            Text("Acesso exclusivo do proprietário da rede.",
                color = KMuted, fontSize = 11.sp, textAlign = TextAlign.Center)
        }
    }
}
