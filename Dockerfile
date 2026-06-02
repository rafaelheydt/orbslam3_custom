FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# =============================================================================
# Dependências do sistema
# =============================================================================
RUN apt-get update && apt-get install -y \
    build-essential cmake git wget unzip \
    libglew-dev libpython2.7-dev \
    libboost-all-dev libeigen3-dev \
    libssl-dev libopencv-dev \
    python3-pip \
    libgl1-mesa-glx libgl1-mesa-dri \
    libepoxy-dev \
    nano vim htop \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Pangolin v0.6 — compatível com ORB-SLAM3
# =============================================================================
RUN git clone --depth 1 --branch v0.6 \
    https://github.com/stevenlovegrove/Pangolin.git /opt/Pangolin && \
    cd /opt/Pangolin && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install && ldconfig

# =============================================================================
# ORB-SLAM3 original (UZ-SLAMLab)
# =============================================================================
RUN git clone https://github.com/UZ-SLAMLab/ORB_SLAM3.git /opt/ORB_SLAM3

# Patch OpenCV 4.x
RUN cd /opt/ORB_SLAM3 && \
    find src/ include/ -name "*.cc" -o -name "*.cpp" -o -name "*.h" | \
    xargs grep -l "CV_LOAD_IMAGE_UNCHANGED" 2>/dev/null | \
    xargs -I{} sed -i 's/CV_LOAD_IMAGE_UNCHANGED/cv::IMREAD_UNCHANGED/g' {} ; \
    find src/ include/ -name "*.cc" -o -name "*.cpp" | \
    xargs grep -l "CV_BGR2GRAY" 2>/dev/null | \
    xargs -I{} sed -i 's/CV_BGR2GRAY/cv::COLOR_BGR2GRAY/g' {} ; \
    sed -i '1s/^/#include <unistd.h>\n/' src/System.cc

# Descompimir vocabulário
RUN cd /opt/ORB_SLAM3/Vocabulary && tar -xf ORBvoc.txt.tar.gz

# Compilar ORB-SLAM3 — patch OpenCV 4.2 + forçar C++14
RUN sed -i 's/find_package(OpenCV 4.4/find_package(OpenCV 4/' \
      /opt/ORB_SLAM3/CMakeLists.txt && \
    sed -i 's/OpenCV > 4.4/OpenCV > 4/' \
      /opt/ORB_SLAM3/CMakeLists.txt && \
    sed -i 's/-std=c++11/-std=c++14/g' \
      /opt/ORB_SLAM3/CMakeLists.txt && \
    cd /opt/ORB_SLAM3 && chmod +x build.sh && ./build.sh

# Descomentar executáveis TUM + desabilitar viewer + compilar
RUN cd /opt/ORB_SLAM3 && \
    sed -i '0,/^# add_executable(rgbd_tum/{s/^# add_executable(rgbd_tum/add_executable(rgbd_tum/}' CMakeLists.txt && \
    sed -i '0,/^#         Examples\/RGB-D\/rgbd_tum/{s/^#         Examples\/RGB-D\/rgbd_tum/        Examples\/RGB-D\/rgbd_tum/}' CMakeLists.txt && \
    sed -i '0,/^# target_link_libraries(rgbd_tum/{s/^# target_link_libraries(rgbd_tum/target_link_libraries(rgbd_tum/}' CMakeLists.txt && \
    sed -i '0,/^# add_executable(mono_tum/{s/^# add_executable(mono_tum/add_executable(mono_tum/}' CMakeLists.txt && \
    sed -i '0,/^#         Examples\/Monocular\/mono_tum/{s/^#         Examples\/Monocular\/mono_tum/        Examples\/Monocular\/mono_tum/}' CMakeLists.txt && \
    sed -i '0,/^# target_link_libraries(mono_tum/{s/^# target_link_libraries(mono_tum/target_link_libraries(mono_tum/}' CMakeLists.txt && \
    sed -i 's/System::RGBD,true/System::RGBD,false/' Examples/RGB-D/rgbd_tum.cc && \
    sed -i 's/System::Monocular,true/System::Monocular,false/' Examples/Monocular/mono_tum.cc && \
    cd build && cmake .. && \
    make rgbd_tum mono_tum -j$(nproc)

# =============================================================================
# EVO para avaliação de trajetórias
# =============================================================================
RUN pip3 install evo

# =============================================================================
# Ambiente
# =============================================================================
ENV ORBSLAM3_DIR=/opt/ORB_SLAM3
ENV VOCAB=/opt/ORB_SLAM3/Vocabulary/ORBvoc.txt

RUN echo 'alias rgbd_tum="/opt/ORB_SLAM3/Examples/RGB-D/rgbd_tum"' >> ~/.bashrc && \
    echo 'alias mono_tum="/opt/ORB_SLAM3/Examples/Monocular/mono_tum"' >> ~/.bashrc && \
    echo 'export VOCAB=/opt/ORB_SLAM3/Vocabulary/ORBvoc.txt' >> ~/.bashrc && \
    echo 'export ORBSLAM3_DIR=/opt/ORB_SLAM3' >> ~/.bashrc

WORKDIR /root
CMD ["bash"]