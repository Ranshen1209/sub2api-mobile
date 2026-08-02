package com.sakrylle.admin.data

import org.junit.Assert.assertEquals
import org.junit.Test

class AdminRepositoryTest {
    @Test
    fun normalizesServerAddress() {
        assertEquals("https://admin.example.com", AdminRepository.normalizeBaseUrl(" admin.example.com/ "))
        assertEquals("http://localhost:8787", AdminRepository.normalizeBaseUrl("http://localhost:8787/"))
    }

    @Test
    fun usesSecondLevelDomainAsServerLabel() {
        assertEquals("sakrylle", AdminRepository.serverLabel("https://ai1.sakrylle.com"))
        assertEquals("example", AdminRepository.serverLabel("admin.example.com/"))
        assertEquals("localhost", AdminRepository.serverLabel("http://localhost:8787"))
        assertEquals("192.168.1.8", AdminRepository.serverLabel("http://192.168.1.8:8787"))
    }
}
