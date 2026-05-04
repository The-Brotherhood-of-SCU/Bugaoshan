package io.github.the_brotherhood_of_scu.bugaoshan.di

import com.russhwolf.settings.Settings
import io.github.the_brotherhood_of_scu.bugaoshan.platform.createSettings
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AppConfigViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.AuthViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CampusViewModel
import io.github.the_brotherhood_of_scu.bugaoshan.viewmodel.CourseViewModel
import org.koin.core.module.dsl.factoryOf
import org.koin.dsl.module

val viewModelModule = module {
    single<Settings> { createSettings() }

    factoryOf(::AppConfigViewModel)
    factory { AuthViewModel(get(), get()) }
    factoryOf(::CourseViewModel)
    factory { CampusViewModel(get(), get(), get(), get(), get()) }
}
