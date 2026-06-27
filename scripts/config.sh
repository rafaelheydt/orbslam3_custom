#!/bin/bash
# =============================================================================
# config.sh — Configurações dos experimentos
# Edite apenas este arquivo para rodar novos experimentos
# =============================================================================

DATASET="fr3_office"           # fr1_desk | fr2_xyz | fr3_office | custom
MODE="midas_affine"     # rgbd_baseline | monocular | midas | midas_affine | dav2_metric_vitl 
N_RUNS=1                # quantas vezes rodar
RUN_EVO=true            # avaliar com EVO automaticamente

# Caminhos 
ORBSLAM3_DIR="/opt/ORB_SLAM3"
VOCAB="$ORBSLAM3_DIR/Vocabulary/ORBvoc.txt"
DATASETS_DIR="/root/datasets/tum"
RESULTS_DIR="/root/results"