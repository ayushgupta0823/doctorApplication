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

// file_picker 11.0.2's own build.gradle skips applying the Kotlin Android
// plugin on AGP 9+ (assuming Flutter's built-in-Kotlin support will compile
// its .kt sources instead) — but Flutter's own auto-apply heuristic is a
// text scan that's fooled by the literal (never-executed-here) "apply
// plugin: 'org.jetbrains.kotlin.android'" string still present in that
// file's source, so it thinks the plugin is already applied and skips its
// own auto-apply too. Net result: file_picker's Kotlin sources never
// compile ("cannot find symbol: class FilePickerPlugin"). Apply it here
// explicitly until file_picker ships a fix.
subprojects {
    if (project.name == "file_picker") {
        project.pluginManager.apply("org.jetbrains.kotlin.android")
        // That same skipped AGP9 branch also carries the jvmTarget = 17
        // setting for Kotlin — without it Kotlin defaults to a newer JVM
        // target than the Java sources (17), which Gradle rejects as
        // "Inconsistent JVM Target Compatibility".
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
