import io
import os
import os.path
import sys
import runpy
import re
import sysconfig
import setuptools


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    minimum_supported_numpy = "1.13.3"
    if sys.version_info[:2] >= (3, 6):
        minimum_supported_numpy = "1.13.3"
    if sys.version_info[:2] >= (3, 7):
        minimum_supported_numpy = "1.14.5"
    if sys.version_info[:2] >= (3, 8):
        minimum_supported_numpy = "1.17.3"
    if sys.version_info[:2] >= (3, 9):
        minimum_supported_numpy = "1.19.3"

    numpy_version = "numpy>=%s" % minimum_supported_numpy

    build_contrib = get_build_env_var_by_name("contrib")
    build_headless = get_build_env_var_by_name("headless")
    build_java = "ON" if get_build_env_var_by_name("java") else "OFF"

    version = {}
    here = os.path.abspath(os.path.dirname(__file__))
    version_file = os.path.join(here, "cv2", "version.py")

    # generate a fresh version.py always when Git repository exists
    if os.path.exists(".git"):
        old_args = sys.argv.copy()
        sys.argv = ["", str(build_contrib), str(build_headless), str(False)]
        runpy.run_path("find_version.py", run_name="__main__")
        sys.argv = old_args

    with open(version_file) as fp:
        exec(fp.read(), version)

    package_version = version["opencv_version"]
    build_contrib = version["contrib"]
    build_headless = version["headless"]

    package_name = "opencv-python"

    if build_contrib and not build_headless:
        package_name = "opencv-contrib-python"

    if build_contrib and build_headless:
        package_name = "opencv-contrib-python-headless"

    if build_headless and not build_contrib:
        package_name = "opencv-python-headless"

    long_description = io.open("README.md", encoding="utf-8").read()

    packages = ["cv2", "cv2.data"]

    package_data = {
        "cv2": ["*%s" % sysconfig.get_config_vars().get("SO"), "version.py"]
        + (["*.dll"] if os.name == "nt" else [])
        + ["LICENSE.txt", "LICENSE-3RD-PARTY.txt"],
        "cv2.data": ["*.xml"],
    }

    setuptools.setup(
        name=package_name,
        version=package_version,
        url="https://github.com/skvark/opencv-python",
        license="MIT",
        description="Wrapper package for OpenCV python bindings.",
        long_description=long_description,
        long_description_content_type="text/markdown",
        packages=packages,
        package_data=package_data,
        include_package_data=True,
        maintainer="Olli-Pekka Heinisuo",
        ext_modules=EmptyListWithLength(),
        install_requires=numpy_version,
        python_requires=">=3.6",
        classifiers=[
            "Development Status :: 5 - Production/Stable",
            "Environment :: Console",
            "Intended Audience :: Developers",
            "Intended Audience :: Education",
            "Intended Audience :: Information Technology",
            "Intended Audience :: Science/Research",
            "License :: OSI Approved :: MIT License",
            "Operating System :: MacOS",
            "Operating System :: Microsoft :: Windows",
            "Operating System :: POSIX",
            "Operating System :: Unix",
            "Programming Language :: Python",
            "Programming Language :: Python :: 3",
            "Programming Language :: Python :: 3 :: Only",
            "Programming Language :: Python :: 3.6",
            "Programming Language :: Python :: 3.7",
            "Programming Language :: Python :: 3.8",
            "Programming Language :: Python :: 3.9",
            "Programming Language :: C++",
            "Programming Language :: Python :: Implementation :: CPython",
            "Topic :: Scientific/Engineering",
            "Topic :: Scientific/Engineering :: Image Recognition",
            "Topic :: Software Development",
        ],
    )


def get_build_env_var_by_name(flag_name):
    flag_set = False

    try:
        flag_set = bool(int(os.getenv("ENABLE_" + flag_name.upper(), None)))
    except Exception:
        pass

    if not flag_set:
        try:
            flag_set = bool(int(open(flag_name + ".enabled").read(1)))
        except Exception:
            pass

    return flag_set


# This creates a list which is empty but returns a length of 1.
# Should make the wheel a binary distribution and platlib compliant.
class EmptyListWithLength(list):
    def __len__(self):
        return 1


if __name__ == "__main__":
    main()
