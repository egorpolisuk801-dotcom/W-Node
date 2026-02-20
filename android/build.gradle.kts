allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Встановлюємо шлях до папки build як стандарт для Flutter
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 🔥 ВИДАЛЕНО evaluationDependsOn — це головний винуватець помилки
subprojects {
    // Тут тепер порожньо, Gradle сам розбереться з чергою
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}