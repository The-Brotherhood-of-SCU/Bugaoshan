package io.github.the_brotherhood_of_scu.bugaoshan

class Greeting {
    private val platform = getPlatform()

    fun greet(): String {
        return "Hello, ${platform.name}!"
    }
}