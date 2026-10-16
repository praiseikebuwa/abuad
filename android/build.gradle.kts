allprojects {
    buildscript {
        configurations.all {
            resolutionStrategy {
                force("com.android.tools.build:gradle:8.9.1")
                force("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
            }
        }
    }
    configurations.all {
        resolutionStrategy {
            force("com.android.tools.build:gradle:8.9.1")
            force("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
        }
    }
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
