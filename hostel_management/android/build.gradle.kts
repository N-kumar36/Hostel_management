allprojects {
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}



// Inside your android/build.gradle.kts
subprojects {
    if (project.name == "upi_india") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                namespace = "com.az.upi_india"
            }
        }
    }
}