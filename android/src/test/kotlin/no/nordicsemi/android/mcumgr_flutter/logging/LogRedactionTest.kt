package no.nordicsemi.android.mcumgr_flutter.logging

import org.junit.Assert.assertEquals
import org.junit.Test

class LogRedactionTest {
    @Test
    fun masksThePasswordOfAProtectedWrite() {
        val line = "Sending (53 bytes) CBOR {\"val\":34.0,\"name\":\"sensor/high/val\",\"pwd\":\"1234\"}"

        assertEquals(
            "Sending (53 bytes) CBOR {\"val\":34.0,\"name\":\"sensor/high/val\",\"pwd\":\"***\"}",
            redactSecrets(line),
        )
    }

    @Test
    fun masksTheValueWrittenToAPasswordSetting() {
        val line = "Sending (39 bytes) CBOR {\"val\":\"1234\",\"name\":\"device/pwd/key/val\"}"

        assertEquals(
            "Sending (39 bytes) CBOR {\"val\":\"***\",\"name\":\"device/pwd/key/val\"}",
            redactSecrets(line),
        )
    }

    @Test
    fun masksAnUnquotedValueOfAPasswordSetting() {
        val line = "CBOR {\"name\":\"password\",\"val\":987654}"

        assertEquals("CBOR {\"name\":\"password\",\"val\":\"***\"}", redactSecrets(line))
    }

    @Test
    fun leavesOtherLinesUntouched() {
        val line = "Received CBOR {\"val\":15,\"name\":\"display/contrast/val\"}"

        assertEquals(line, redactSecrets(line))
    }

    @Test
    fun keepsTheNameOfAPasswordSettingReadable() {
        val line = "Received CBOR {\"list\":\"device/pwd/key\"}"

        assertEquals(line, redactSecrets(line))
    }
}
