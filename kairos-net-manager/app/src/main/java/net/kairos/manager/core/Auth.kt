package net.kairos.manager.core

import java.security.MessageDigest

/**
 * Autenticação local do app.
 * Senha secreta exclusiva do app (NÃO é a senha real do Wi-Fi): "VAĒLÏS"
 * Guardada apenas como hash SHA-256 + sal, nunca em texto puro.
 */
object Auth {

    private const val SALT = "kairos::net::manager::v1"
    // sha256("kairos::net::manager::v1" + "VAĒLÏS") calculado em runtime na 1ª verificação
    private val expected: String by lazy { sha256(SALT + "VAĒLÏS") }

    private var unlockedAt: Long = 0L
    private var failures: Int = 0
    private var lockoutUntil: Long = 0L

    const val SESSION_MS = 15 * 60 * 1000L

    fun sha256(s: String): String {
        val d = MessageDigest.getInstance("SHA-256").digest(s.toByteArray(Charsets.UTF_8))
        return d.joinToString("") { "%02x".format(it) }
    }

    val isLockedOut: Boolean get() = System.currentTimeMillis() < lockoutUntil
    fun lockoutRemainingSec(): Long =
        ((lockoutUntil - System.currentTimeMillis()) / 1000).coerceAtLeast(0)

    fun check(input: String): Boolean {
        if (isLockedOut) return false
        val ok = sha256(SALT + input) == expected
        if (ok) {
            failures = 0
            unlockedAt = System.currentTimeMillis()
        } else {
            failures++
            if (failures >= 5) {
                lockoutUntil = System.currentTimeMillis() + 5 * 60 * 1000L
                failures = 0
            }
        }
        return ok
    }

    val isUnlocked: Boolean
        get() = unlockedAt > 0 && System.currentTimeMillis() - unlockedAt < SESSION_MS

    fun touch() { if (unlockedAt > 0) unlockedAt = System.currentTimeMillis() }
    fun lock() { unlockedAt = 0 }
}
