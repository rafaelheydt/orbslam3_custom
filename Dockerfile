FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo

ARG USE_VIEWER=0

# =============================================================================
# Dependencias do sistema
# =============================================================================
RUN apt-get update && apt-get install -y \
    git cmake build-essential \
    libopencv-dev python3-opencv \
    libeigen3-dev \
    libssl-dev \
    libglew-dev \
    libepoxy-dev \
    libgl1-mesa-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libgtk2.0-dev \
    libboost-all-dev \
    libboost-serialization-dev \
    pkg-config \
    libjpeg-dev libpng-dev libtiff-dev \
    libavcodec-dev libavformat-dev libswscale-dev \
    python3-pip python3-dev \
    curl wget unzip nano vim htop \
    locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8

# =============================================================================
# ROS 2 Humble
# =============================================================================
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu jammy main" > /etc/apt/sources.list.d/ros2.list && \
    apt-get update && apt-get install -y \
    ros-humble-ros-base \
    ros-humble-cv-bridge \
    ros-humble-image-transport \
    ros-humble-sensor-msgs \
    ros-humble-nav-msgs \
    ros-humble-geometry-msgs \
    ros-humble-visualization-msgs \
    ros-humble-rosbag2 \
    ros-humble-rosbag2-storage-default-plugins \
    ros-humble-image-tools \
    ros-humble-camera-info-manager \
    python3-colcon-common-extensions \
    python3-rosdep \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init && rosdep update

# =============================================================================
# Pangolin — compilar do source (necessario para Ubuntu 22.04)
# =============================================================================
RUN git clone --depth 1 https://github.com/stevenlovegrove/Pangolin.git /opt/Pangolin && \
    cd /opt/Pangolin && \
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_PANGOLIN_PYTHON=OFF \
          -DBUILD_EXAMPLES=OFF && \
    cmake --build build -j$(nproc) && \
    cmake --install build && ldconfig

# =============================================================================
# ORB-SLAM3 — fork corrigido para Ubuntu 22.04 / ROS 2 Humble
# Referencia: https://github.com/zang09/ORB-SLAM3-STEREO-FIXED
# =============================================================================
RUN git clone https://github.com/zang09/ORB-SLAM3-STEREO-FIXED.git /opt/ORB_SLAM3 && \
    cd /opt/ORB_SLAM3 && chmod +x build.sh && ./build.sh

# Patch viewer condicional
RUN if [ "$USE_VIEWER" = "0" ]; then \
        echo "Viewer DESABILITADO" && \
        sed -i 's/System::RGBD,true/System::RGBD,false/' \
            /opt/ORB_SLAM3/Examples/RGB-D/rgbd_tum.cc 2>/dev/null || true && \
        sed -i 's/System::MONOCULAR,true/System::MONOCULAR,false/' \
            /opt/ORB_SLAM3/Examples/Monocular/mono_tum.cc 2>/dev/null || true && \
        cd /opt/ORB_SLAM3/build && make rgbd_tum mono_tum -j$(nproc) 2>/dev/null || true ; \
    else \
        echo "Viewer HABILITADO" ; \
    fi

# Patch TUM3.yaml
RUN grep -q "DepthMapFactor" /opt/ORB_SLAM3/Examples/RGB-D/TUM3.yaml || \
    echo "RGBD.DepthMapFactor: 5000.0" >> /opt/ORB_SLAM3/Examples/RGB-D/TUM3.yaml

# =============================================================================
# ROS 2 Wrapper para ORB-SLAM3
# Referencia: https://gitlab.com/akbedaka/orb_slam3_ros2
# =============================================================================
RUN mkdir -p /opt/orb_slam3_ros2_ws/src && \
    cd /opt/orb_slam3_ros2_ws/src && \
    git clone https://gitlab.com/akbedaka/orb_slam3_ros2.git orbslam3_ros2

RUN cd /opt/orb_slam3_ros2_ws && \
    /bin/bash -c "source /opt/ros/humble/setup.bash && colcon build --symlink-install"

# =============================================================================
# EVO + rosbags
# =============================================================================
RUN pip3 install evo rosbags

# =============================================================================
# Ambiente
# =============================================================================
ENV ORBSLAM3_DIR=/opt/ORB_SLAM3
ENV VOCAB=/opt/ORB_SLAM3/Vocabulary/ORBvoc.txt
ENV USE_VIEWER=${USE_VIEWER}

RUN echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc && \
    echo 'source /opt/orb_slam3_ros2_ws/install/setup.bash' >> ~/.bashrc && \
    echo 'export VOCAB=/opt/ORB_SLAM3/Vocabulary/ORBvoc.txt' >> ~/.bashrc && \
    echo 'export ORBSLAM3_DIR=/opt/ORB_SLAM3' >> ~/.bashrc

WORKDIR /root
CMD ["bash"]