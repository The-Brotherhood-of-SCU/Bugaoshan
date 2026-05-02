package io.github.the_brotherhood_of_scu.bugaoshan.model

import kotlinx.serialization.Serializable

@Serializable
data class ReleaseInfo(
    val version: String,
    val tag: String,
    val description: String,
    val downloadUrl: String,
    val publishedAt: String,
    val isPrerelease: Boolean = false,
)
