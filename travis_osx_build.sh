function package_name() {
    local name="opencv"
    if [ $ENABLE_CONTRIB -ne 0 ]; then
        name+="_contrib"
    fi
    name+="_python"
    if [ $ENABLE_HEADLESS -ne 0 ]; then
        name+="_headless"
    fi
    wheel_name=$name
}

function pre_build_osx {
    local repo_dir=$(abspath ${1:-$REPO_DIR})
    local build_dir="$repo_dir/opencv/build"
    local num_cpus=$(sysctl -n hw.ncpu)
    num_cpus=${num_cpus:-4}
    local travis_start_time=$(($TRAVIS_TIMER_START_TIME/10**9))
    local time_limit=$((30*60))

    cd "$repo_dir"
    git submodule sync
    git submodule update --init --recursive opencv
    git submodule update --init --recursive opencv_contrib

    pip install scikit-build
    pip install numpy

    if [ ! -d "$build_dir" ]; then
        mkdir "$build_dir"
    fi

    local CMAKE_OPTS=(
        -G "Unix Makefiles"
        -DPYTHON3_EXECUTABLE="$(python "$repo_dir/tools/python_path.py" bin)"
        -DPYTHON3_INCLUDE_DIR="$(python "$repo_dir/tools/python_path.py" include)"
        -DPYTHON3_LIBRARY="$(python "$repo_dir/tools/python_path.py" lib)"
        -DBUILD_opencv_python3=ON
        -DBUILD_opencv_python2=OFF
        -DBUILD_opencv_java=OFF
        -DOPENCV_SKIP_PYTHON_LOADER=ON
        -DOPENCV_PYTHON3_INSTALL_PATH=python
        -DINSTALL_CREATE_DISTRIB=ON
        -DBUILD_opencv_apps=OFF
        -DBUILD_SHARED_LIBS=OFF
        -DBUILD_TESTS=OFF
        -DBUILD_PERF_TESTS=OFF
        -DBUILD_DOCS=OFF
        -DBUILD_LIST=core,imgproc,videoio,python3 # FIXME: experiments
    )
    if [ $ENABLE_CONTRIB -ne 0 ]; then
        CMAKE_OPTS+=(-DOPENCV_EXTRA_MODULES_PATH="$repo_dir/opencv_contrib/modules")
    fi
    if [ $ENABLE_HEADLESS -eq 0 ]; then
        export PKG_CONFIG_PATH="/usr/local/opt/qt/lib/pkgconfig":$PKG_CONFIG_PATH
        export CMAKE_PREFIX_PATH="/usr/local/Cellar/qt/5.15.1"
        CMAKE_OPTS+=(-DWITH_QT=5)
    else
        CMAKE_OPTS+=(
            -DWITH_WIN32UI=OFF
            -DWITH_QT=OFF
            -DWITH_GTK=OFF
            # -DWITH_MSMF=OFF
        )
    fi

    # Clear ccache stats
    ccache -z

    # Configure build
    cd "$build_dir"
    cmake "${CMAKE_OPTS[@]}" ..
    # $ pkg-config --libs opencv4 | sed -e 's| |\n|g' | sed -e 's|^-l||g' | tac
    CV_MODULES=(
        opencv_core
        opencv_imgproc
        opencv_photo
        opencv_xphoto
        opencv_flann
        opencv_features2d
        opencv_imgcodecs
        opencv_calib3d
        opencv_objdetect
        opencv_xobjdetect
        opencv_video
        opencv_ximgproc
        opencv_ml
        opencv_shape
        opencv_xfeatures2d
        opencv_viz
        opencv_videoio
        opencv_videostab
        opencv_plot
        opencv_dnn
        opencv_text
        opencv_datasets
        opencv_tracking
        opencv_surface_matching
        opencv_optflow
        opencv_superres
        opencv_phase_unwrapping
        opencv_structured_light
        opencv_stereo
        opencv_saliency
        opencv_rgbd
        opencv_reg
        opencv_rapid
        opencv_quality
        opencv_mcc
        opencv_line_descriptor
        opencv_intensity_transform
        opencv_img_hash
        opencv_hfs
        opencv_hdf
        opencv_fuzzy
        opencv_freetype
        opencv_face
        opencv_highgui
        opencv_dpm
        opencv_dnn_superres
        opencv_dnn_objdetect
        opencv_cvv
        opencv_ccalib
        opencv_bioinspired
        opencv_bgsegm
        opencv_aruco
        opencv_alphamat
        opencv_stitching
        opencv_gapi
    )
    for m in "${CV_MODULES[@]}"; do
        if make help | grep -w "$m"; then
            # Check time limit (3min should be enough for a module to built)
            local projected_time=$(($(date +%s) - travis_start_time + 3 * 60))
            if [ $projected_time -ge $time_limit ]; then
                echo "*** Not enough time to build $m: $((projected_time/60))m (${projected_time}s)"
                return 1
            fi
            make -j${num_cpus} "$m"
            local elapsed_time=$(($(date +%s) - travis_start_time))
            echo "Elapsed time: "$((elapsed_time/60))"m (${elapsed_time}s)"
        fi
    done
    make -j${num_cpus}
}

function build_osx {
    local repo_dir=$(abspath ${1:-$REPO_DIR})
    local build_dir="$repo_dir/opencv/build"
    package_name

    # Copy compiled python module to package
    cd "$build_dir"
    cp -f lib/python3/cv2*.so "$repo_dir/cv2"

    if [ $ENABLE_HEADLESS -eq 0 ]; then
        if [ ! -d "$repo_dir/cv2/qt/plugins/platforms" ]; then
            mkdir -p "$repo_dir/cv2/qt/plugins/platforms"
        fi
        cp /usr/local/Cellar/qt/5.15.1/plugins/platforms/libqcocoa.dylib "$repo_dir/cv2/qt/plugins/platforms"
    fi

    cp -f "$repo_dir/opencv/data/haarcascades/"*.xml "$repo_dir/cv2/data"
    # Copy licenses
    cp -f "$repo_dir/LICENSE.txt" "$repo_dir/LICENSE-3RD-PARTY.txt" "$repo_dir/cv2"

    cd "$repo_dir"
    export ENABLE_CONTRIB
    export ENABLE_HEADLESS
    export ENABLE_JAVA
    pip wheel --verbose --wheel-dir="$PWD/dist" . $BDIST_PARAMS

    echo 'Built wheels:'
    ls -lh "$PWD/dist/${wheel_name}"*.whl
}

function build_bdist_osx_wheel {
    local repo_dir=$(abspath ${1:-$REPO_DIR})
    [ -z "$repo_dir" ] && echo "repo_dir not defined" && exit 1
    pre_build_osx "$repo_dir" || return $?
    if [ -n "$BUILD_DEPENDS" ]; then
        pip install $(pip_opts) $BUILD_DEPENDS
    fi
    build_osx "$repo_dir"
}
