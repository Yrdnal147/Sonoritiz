import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

    afterEvaluate {
        if (hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                    val currentNamespace = getNamespace.invoke(androidExt)
                    if (currentNamespace == null || currentNamespace.toString().isEmpty()) {
                        val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        val newNamespace = project.group.toString()
                        if (newNamespace.isNotEmpty()) {
                            setNamespace.invoke(androidExt, newNamespace)
                        } else {
                            setNamespace.invoke(androidExt, "com.example.namespace." + project.name.replace("-", "_"))
                        }
                    }

                    val compileOptions = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                    val setSourceCompatibility = compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java)
                    val setTargetCompatibility = compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java)
                    setSourceCompatibility.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                    setTargetCompatibility.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
    }

    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
