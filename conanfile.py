from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout, CMakeDeps


class starterkit_libRecipe(ConanFile):
    name = "starterkit"
    version = "0.0.1"
    package_type = "library"

    # Optional metadata
    license = "<Put the package license here>"
    author = "<Put your name here> <And your email here>"
    url = "<Package recipe repository url here, for issues about the package>"
    description = "<Description of starterkit package here>"
    topics = ("<Put some tag here>", "<here>", "<and here>")

    # Binary configuration
    settings = "os", "compiler", "build_type", "arch"
    options = {"shared": [True, False], "fPIC": [True, False]}
    default_options = {"shared": False, "fPIC": True}

    requires = "fmt/11.0.2", "cxxopts/3.1.1"
    test_requires = "doctest/2.4.11"

    # Sources are located in the same place as this recipe, copy them to the recipe
    exports_sources = "CMakeLists.txt", "src/*", "include/*", "cli/*", "tests/*", "cmake/*"

    def config_options(self) -> None:
        """config_options"""
        if self.settings.os == "Windows":
            self.options.rm_safe("fPIC")

    def configure(self) -> None:
        """configure"""
        if self.options.shared:
            self.options.rm_safe("fPIC")

    def layout(self) -> None:
        """layout"""
        cmake_layout(self)

    def generate(self) -> None:
        """generate"""
        deps = CMakeDeps(self)
        deps.generate()
        tc = CMakeToolchain(self)
        tc.generate()

    def build(self) -> None:
        """build"""
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self) -> None:
        """package"""
        cmake = CMake(self)
        cmake.install()

    def package_info(self) -> None:
        """package_info"""
        self.cpp_info.libs = ["starterkit"]
