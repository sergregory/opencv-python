import sys


def main():
    if len(sys.argv) < 2:
        print("Usage: ", sys.argv[0], "bin|lib|include")
        return 1

    if (sys.argv[1] == "bin"):
        print(sys.executable)
    elif (sys.argv[1] == "lib"):
        from skbuild import cmaker
        python_version = cmaker.CMaker.get_python_version()
        python_lib_path = cmaker.CMaker.get_python_library(python_version).replace("\\", "/")
        # FIXME: Wrong extension:
        # import os
        # from sysconfig import get_config_var
        # python_lib_path = os.path.join(get_config_var('LIBDIR'), get_config_var('LIBRARY'))
        print(python_lib_path)
    else:
        from sysconfig import get_paths
        info = get_paths()
        print(info['platinclude'])


if __name__ == "__main__":
    main()
