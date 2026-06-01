#!/bin/bash
# =============================================================================
# run.sh — Pipeline de experimentos ORB-SLAM3
# Uso: ./run.sh [config.sh]
# =============================================================================

set -e

CONFIG_FILE="${1:-/root/scripts/config.sh}"
[ -f "$CONFIG_FILE" ] || { echo "ERRO: config não encontrado: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# =============================================================================
# RESOLVER CAMINHOS
# =============================================================================
case $DATASET in
    fr1_desk)
        DATASET_PATH="$DATASETS_DIR/rgbd_dataset_freiburg1_desk"
        GROUNDTRUTH="$DATASET_PATH/groundtruth.txt"
        YAML_RGBD="$ORBSLAM3_DIR/Examples/RGB-D/TUM1.yaml"
        YAML_MONO="$ORBSLAM3_DIR/Examples/Monocular/TUM1.yaml"
        ASSOC_REAL="$ORBSLAM3_DIR/Examples/RGB-D/associations/fr1_desk.txt"
        ;;
    fr2_xyz)
        DATASET_PATH="$DATASETS_DIR/rgbd_dataset_freiburg2_xyz"
        GROUNDTRUTH="$DATASETS_DIR/rgbd_dataset_freiburg2_xyz-groundtruth.txt"
        YAML_RGBD="$ORBSLAM3_DIR/Examples/RGB-D/TUM2.yaml"
        YAML_MONO="$ORBSLAM3_DIR/Examples/Monocular/TUM2.yaml"
        ASSOC_REAL="$ORBSLAM3_DIR/Examples/RGB-D/associations/fr2_xyz.txt"
        ;;
    fr3_office)
        DATASET_PATH="$DATASETS_DIR/rgbd_dataset_freiburg3_long_office_household"
        GROUNDTRUTH="$DATASET_PATH/groundtruth.txt"
        YAML_RGBD="$ORBSLAM3_DIR/Examples/RGB-D/TUM3.yaml"
        YAML_MONO="$ORBSLAM3_DIR/Examples/Monocular/TUM3.yaml"
        ASSOC_REAL="$ORBSLAM3_DIR/Examples/RGB-D/associations/fr3_office.txt"
        ;;
    custom)
        DATASET_PATH="$CUSTOM_PATH"
        GROUNDTRUTH="$CUSTOM_GROUNDTRUTH"
        YAML_RGBD="$CUSTOM_YAML_RGBD"
        YAML_MONO="$CUSTOM_YAML_MONO"
        ASSOC_REAL="$CUSTOM_ASSOC_REAL"
        ;;
    *)
        echo -e "${RED}ERRO: dataset desconhecido: $DATASET${NC}"
        echo "Opções: fr1_desk | fr2_xyz | fr3_office | custom"
        exit 1
        ;;
esac

case $MODE in
    rgbd_baseline)
        EXE="$ORBSLAM3_DIR/Examples/RGB-D/rgbd_tum"
        ASSOC="$ASSOC_REAL"
        YAML="$YAML_RGBD"
        MODE_DISPLAY="RGB-D Baseline"
        ;;
    monocular)
        EXE="$ORBSLAM3_DIR/Examples/Monocular/mono_tum"
        ASSOC=""
        YAML="$YAML_MONO"
        MODE_DISPLAY="Monocular"
        ;;
    midas)
        EXE="$ORBSLAM3_DIR/Examples/RGB-D/rgbd_tum"
        ASSOC="$DATASET_PATH/associations_midas.txt"
        YAML="$YAML_RGBD"
        MODE_DISPLAY="RGB-D + MiDaS"
        ;;
    dav2_vitl|dav2_vitb|dav2_vits)
        EXE="$ORBSLAM3_DIR/Examples/RGB-D/rgbd_tum"
        ASSOC="$DATASET_PATH/associations_${MODE}.txt"
        YAML="$YAML_RGBD"
        MODE_DISPLAY="RGB-D + DAV2 ${MODE#dav2_}"
        ;;
    *)
        echo -e "${RED}ERRO: modo desconhecido: $MODE${NC}"
        echo "Opções: rgbd_baseline | monocular | midas | dav2_vitl | dav2_vitb | dav2_vits"
        exit 1
        ;;
esac

OUTDIR="$RESULTS_DIR/$DATASET/$MODE"
mkdir -p "$OUTDIR"

# =============================================================================
# VERIFICAÇÕES
# =============================================================================
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Dataset  : ${CYAN}$DATASET${NC}"
echo -e "  Modo     : ${CYAN}$MODE_DISPLAY${NC}"
echo -e "  Runs     : ${CYAN}$N_RUNS${NC}"
echo -e "  EVO      : ${CYAN}$RUN_EVO${NC}"
echo -e "  Output   : ${CYAN}$OUTDIR${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

[ -f "$VOCAB" ]        || { echo -e "${RED}ERRO: vocabulário não encontrado: $VOCAB${NC}"; exit 1; }
[ -d "$DATASET_PATH" ] || { echo -e "${RED}ERRO: dataset não encontrado: $DATASET_PATH${NC}"; exit 1; }
[ -f "$EXE" ]          || { echo -e "${RED}ERRO: executável não encontrado: $EXE${NC}"; exit 1; }
[ -z "$ASSOC" ] || [ -f "$ASSOC" ] || { echo -e "${RED}ERRO: associations não encontrado: $ASSOC${NC}"; exit 1; }

# =============================================================================
# RODAR N_RUNS VEZES
# =============================================================================
RMSE_VALUES=()

for RUN in $(seq 1 $N_RUNS); do
    echo -e "${CYAN}▶ Run $RUN/$N_RUNS — $MODE_DISPLAY — $DATASET${NC}"

    rm -f /root/KeyFrameTrajectory.txt /root/CameraTrajectory.txt
    START=$(date +%s)

    if [ "$MODE" = "monocular" ]; then
        DISPLAY= "$EXE" "$VOCAB" "$YAML" "$DATASET_PATH"
    else
        DISPLAY= "$EXE" "$VOCAB" "$YAML" "$DATASET_PATH" "$ASSOC"
    fi

    END=$(date +%s)
    ELAPSED=$((END - START))

    # Salvar trajetórias
    for TRAJ in KeyFrameTrajectory.txt CameraTrajectory.txt; do
        if [ -f "/root/$TRAJ" ]; then
            POSES=$(wc -l < "/root/$TRAJ")
            DEST="$OUTDIR/${TRAJ%.txt}_run${RUN}.txt"
            cp "/root/$TRAJ" "$DEST"
            echo -e "${GREEN}  ✔ $TRAJ — $POSES poses${NC}"
        else
            echo -e "${YELLOW}  ✘ $TRAJ não gerado${NC}"
        fi
    done

    # Salvar yaml e metadata
    cp "$YAML" "$OUTDIR/params.yaml" 2>/dev/null || true
    cat > "$OUTDIR/run${RUN}_meta.txt" << META
dataset=$DATASET
mode=$MODE
run=$RUN
elapsed_s=$ELAPSED
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
assoc=${ASSOC:-none}
yaml=$YAML
META
    echo -e "  Tempo: ${ELAPSED}s"

    # EVO
    if $RUN_EVO && [ -f "$GROUNDTRUTH" ]; then
        echo -e "\n${CYAN}  ▶ Avaliando com EVO...${NC}"
        for TRAJ_NAME in KeyFrameTrajectory CameraTrajectory; do
            TRAJ_FILE="$OUTDIR/${TRAJ_NAME}_run${RUN}.txt"
            if [ -f "$TRAJ_FILE" ] && [ $(wc -l < "$TRAJ_FILE") -gt 5 ]; then
                RESULT_ZIP="$OUTDIR/ate_${TRAJ_NAME}_run${RUN}.zip"
                evo_ape tum "$GROUNDTRUTH" "$TRAJ_FILE" \
                    --align \
                    --save_results "$RESULT_ZIP" 2>/dev/null && \
                RMSE=$(python3 - << PYEOF
import zipfile, json
try:
    with zipfile.ZipFile("$RESULT_ZIP") as z:
        with z.open("stats.json") as f:
            s = json.load(f)
    poses = sum(1 for _ in open("$TRAJ_FILE"))
    print(f"RMSE={s['rmse']:.6f}m  Mean={s['mean']:.6f}m  Max={s['max']:.6f}m  Poses={poses}")
    with open("$OUTDIR/run${RUN}_meta.txt", "a") as out:
        out.write(f"rmse={s['rmse']:.6f}\nmean={s['mean']:.6f}\nmax={s['max']:.6f}\n")
except Exception as e:
    print(f"ERRO EVO: {e}")
PYEOF
)
                echo -e "${GREEN}  ✔ $TRAJ_NAME: $RMSE${NC}"
                RMSE_VALUES+=("Run$RUN $TRAJ_NAME: $RMSE")
                break
            fi
        done
    elif $RUN_EVO && [ ! -f "$GROUNDTRUTH" ]; then
        echo -e "${YELLOW}  ⚠ Ground truth não encontrado: $GROUNDTRUTH${NC}"
    fi

    echo ""
done

# =============================================================================
# RESUMO FINAL
# =============================================================================
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✔ Experimento concluído!${NC}"
echo -e "  Dataset    : $DATASET"
echo -e "  Modo       : $MODE_DISPLAY"
echo -e "  Resultados : $OUTDIR"

if [ ${#RMSE_VALUES[@]} -gt 0 ]; then
    echo -e "\n  Resultados EVO:"
    for V in "${RMSE_VALUES[@]}"; do
        echo -e "    ${GREEN}$V${NC}"
    done
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"