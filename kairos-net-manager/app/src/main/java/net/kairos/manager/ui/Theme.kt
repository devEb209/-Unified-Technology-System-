package net.kairos.manager.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

val KBlue = Color(0xFF1E90FF)
val KCyan = Color(0xFF00D4FF)
val KBg = Color(0xFF05070D)
val KSurf = Color(0xFF0C1220)
val KSurf2 = Color(0xFF131C2E)
val KRed = Color(0xFFFF3B5C)
val KAmber = Color(0xFFFFB020)
val KGreen = Color(0xFF00E676)
val KText = Color(0xFFE8F1FF)
val KMuted = Color(0xFF8598B8)

private val scheme = darkColorScheme(
    primary = KBlue, onPrimary = Color.White,
    secondary = KCyan, background = KBg, onBackground = KText,
    surface = KSurf, onSurface = KText, error = KRed
)

@Composable
fun KairosTheme(content: @Composable () -> Unit) =
    MaterialTheme(colorScheme = scheme, content = content)

@Composable
fun KairosBackground(content: @Composable () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(
            Brush.verticalGradient(listOf(Color(0xFF05070D), Color(0xFF081326), Color(0xFF05070D)))
        )
    ) { content() }
}

@Composable
fun KCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = KSurf,
        shape = RoundedCornerShape(18.dp),
        tonalElevation = 2.dp,
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0x2200D4FF))
    ) { Column(Modifier.padding(14.dp), content = content) }
}
