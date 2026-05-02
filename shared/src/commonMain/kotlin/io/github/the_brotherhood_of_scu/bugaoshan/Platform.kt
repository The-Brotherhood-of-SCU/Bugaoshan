package io.github.the_brotherhood_of_scu.bugaoshan

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform