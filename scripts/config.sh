#!/bin/bash
# =============================================================================
# config.sh — Configurações dos experimentos
# Edite apenas este arquivo para rodar novos experimentos
# =============================================================================

DATASET="fr3_office"      # fr1_desk | fr2_xyz | fr3_office | custom
MODE="monocular"            # rgbd_baseline | monocular | midas | dav2_vitl | dav2_vitb | dav2_vits
N_RUNS=1                # quantas vezes rodar
RUN_EVO=true            # avaliar com EVO automaticamente

# Caminhos (não altere)
ORBSLAM3_DIR="/opt/ORB_SLAM3"
VOCAB="$ORBSLAM3_DIR/Vocabulary/ORBvoc.txt"
DATASETS_DIR="/root/datasets/tum"
RESULTS_DIR="/root/results"