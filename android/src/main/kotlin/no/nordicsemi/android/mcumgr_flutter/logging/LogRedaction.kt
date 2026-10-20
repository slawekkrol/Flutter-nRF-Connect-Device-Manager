package no.nordicsemi.android.mcumgr_flutter.logging

private const val REDACTED = "\"***\""

/** The password a protected write carries next to its value. */
private val passwordField = Regex("\"pwd\"\\s*:\\s*\"[^\"]*\"")

/** A setting whose name has a password segment, such as `pwd` or `password`. */
private val passwordSettingName = Regex("\"name\"\\s*:\\s*\"([^\"]*/)?(pwd|password)(/|\")", RegexOption.IGNORE_CASE)

/** The written value, quoted or not, up to the next field. */
private val valueField = Regex("\"val\"\\s*:\\s*(\"[^\"]*\"|[^,}\\]]+)")

/**
 * Masks secrets in a transport log line before it leaves the plugin: the
 * `pwd` field of a protected write, and the value written to a password
 * setting.
 */
internal fun redactSecrets(message: String): String {
    val withoutPassword = passwordField.replace(message, "\"pwd\":$REDACTED")
    if (!passwordSettingName.containsMatchIn(withoutPassword)) {
        return withoutPassword
    }
    return valueField.replace(withoutPassword, "\"val\":$REDACTED")
}
