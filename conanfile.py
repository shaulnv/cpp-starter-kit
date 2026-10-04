import os

from conan import ConanFile
from conan.tools.cmake import CMake, CMakeDeps, CMakeToolchain, cmake_layout
from conan.tools.scm import Git
from packaging.version import Version


class starterkit_libRecipe(ConanFile):
    name = "starterkit"
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
    exports_sources = (
        "CMakeLists.txt",
        "src/*",
        "include/*",
        "cli/*",
        "tests/*",
        "env/*",
    )

    def set_version(self) -> None:
        """Version precedence: command line, STARTERKIT_VERSION, latest vX.Y.Z git tag, 0.0.1."""
        sources = {
            "command line": self.version,
            "environment (STARTERKIT_VERSION)": os.getenv("STARTERKIT_VERSION"),
            "git tag": self._latest_version_tag(),
            "default": "0.0.1",
        }
        self.output.info("Version sources (first set value wins):")
        for name, value in sources.items():
            self.output.info(f"  {name}: {value!r}")
        source, self.version = next((k, v) for k, v in sources.items() if v)
        self.output.success(f"Version set to: {self.version} (taken from {source})")

    def _latest_version_tag(self) -> str | None:
        """Highest vX.Y.Z tag reachable from HEAD, or None outside a git checkout."""
        try:
            git = Git(self, self.recipe_folder)
            tags = git.run(
                'tag --list "v[0-9]*.[0-9]*.[0-9]*" --merged HEAD'
            ).splitlines()
            versions = [Version(t.strip().lstrip("v")) for t in tags if t.strip()]
            return str(max(versions)) if versions else None
        except Exception as e:  # not a git repo, git missing, ...
            self.output.warning(f"Could not derive version from git tags: {e}")
            return None

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
        tc.cache_variables["STARTERKIT_VERSION"] = str(self.version)
        # "--production-version" builds export this to drop git hash/date from the version string.
        production = os.environ.get("STARTERKIT_IS_PRODUCTION_VERSION", "False")
        tc.cache_variables["STARTERKIT_IS_PRODUCTION_VERSION"] = production.lower() in (
            "1",
            "true",
            "on",
        )
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
