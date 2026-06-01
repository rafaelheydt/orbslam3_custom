#!/bin/bash
# =============================================================================
# run.sh — Pipeline de experimentos ORB-SLAM3
# Uso: ./run.sh [config.sh]
# Exemplo: ./run.sh  (usa config.sh padrão)
#          ./run.sh minha_config.sh
# =============================================================================

set -e

# Carregar configurações
CONFIG_FILE="${1:-/root/scripts/config.sh}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERRO: arquivo de configuração não encontrado: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# Cores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# =============================================================================
# RESOLVER CAMINHOS baseado no DATASET e MODE
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
    *)
        echo -e "${RED}ERRO: dataset desconhecido: $DATASET${NC}"
        echo "Opções: fr1_desk | fr2_xyz"
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

[ -f "$VOCAB" ]        || { echo -e "${RED}ERRO: vocabulário não encontrado${NC}"; exit 1; }
[ -d "$DATASET_PATH" ] || { echo -e "${RED}ERRO: dataset não encontrado: $DATASET_PATH${NC}"; exit 1; }
[ -f "$EXE" ]          || { echo -e "${RED}ERRO: executável não encontrado: $EXE${NC}"; exit 1; }

if [ -n "$ASSOC" ]; then
    [ -f "$ASSOC" ] || { echo -e "${RED}ERRO: associations não encontrado: $ASSOC${NC}"; exit 1; }
fi

# =============================================================================
# RODAR N_RUNS VEZES
# =============================================================================
RMSE_VALUES=()

for RUN in $(seq 1 $N_RUNS); do
    echo -e "${CYAN}▶ Run $RUN/$N_RUNS — $MODE_DISPLAY — $DATASET${NC}"

    rm -f /root/KeyFrameTrajectory.txt /root/CameraTrajectory.txt
    START=$(date +%s)

    # Executar SLAM
    if [ "$MODE" = "monocular" ]; then
        DISPLAY= "$EXE" "$VOCAB" "$YAML" "$DATASET_PATH"
    else
        DISPLAY= "$EXE" "$VOCAB" "$YAML" "$DATASET_PATH" "$ASSOC"
    fi

    END=$(date +%s)
    ELAPSED=$((END - START))

    # Salvar trajetórias com sufixo de run
    for TRAJ in KeyFrameTrajectory.txt CameraTrajectory.txt; do
        if [ -f "/root/$TRAJ" ]; then
            POSES=$(wc -l < "/root/$TRAJ")
            DEST="$OUTDIR/${TRAJ%.txt}_run${RUN}.txt"
            cp "/root/$TRAJ" "$DEST"
            echo -e "${GREEN}  ✔ $TRAJ — $POSES poses → $DEST${NC}"
        else
            echo -e "${RED}  ✘ $TRAJ não foi gerado${NC}"
        fi
    done

    # Salvar params yaml usados
    cp "$YAML" "$OUTDIR/params.yaml" 2>/dev/null || true

    # Salvar metadata do run
    cat > "$OUTDIR/run${RUN}_meta.txt" << META
dataset=$DATASET
mode=$MODE
run=$RUN
elapsed_s=$ELAPSED
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
assoc=$ASSOC
yaml=$YAML
META

    echo -e "  Tempo: ${ELAPSED}s"

    # ==========================================================================
    # AVALIAÇÃO EVO
    # ==========================================================================
    if $RUN_EVO && [ -f "$GROUNDTRUTH" ]; then
        echo -e "\n${CYAN}  ▶ Avaliando com EVO...${NC}"

        # Tentar KeyFrameTrajectory primeiro, depois CameraTrajectory
        for TRAJ_NAME in KeyFrameTrajectory CameraTrajectory; do
            TRAJ_FILE="$OUTDIR/${TRAJ_NAME}_run${RUN}.txt"
            if [ -f "$TRAJ_FILE" ] && [ $(wc -l < "$TRAJ_FILE") -gt 5 ]; then
                RESULT_ZIP="$OUTDIR/ate_${TRAJ_NAME}_run${RUN}.zip"

                evo_ape tum "$GROUNDTRUTH" "$TRAJ_FILE" \
                    --align \
                    --save_results "$RESULT_ZIP" 2>/dev/null && \

                # Extrair e exibir RMSE
                RMSE=$(python3 - << PYEOF
import zipfile, json, os
try:
    with zipfile.ZipFile("$RESULT_ZIP") as z:
        with z.open("stats.json") as f:
            s = json.load(f)
    print(f"RMSE={s['rmse']:.6f} Mean={s['mean']:.6f} Max={s['max']:.6f} Poses=$(wc -l < "$TRAJ_FILE")")
except Exception as e:
    print(f"ERRO: {e}")
PYEOF
)
                echo -e "${GREEN}  ✔ $TRAJ_NAME: $RMSE${NC}"
                echo "$RMSE" >> "$OUTDIR/run${RUN}_meta.txt"
                RMSE_VALUES+=("$RMSE")
                break
            fi
        done
    fi

    echo ""
done

# =============================================================================
# RESUMO FINAL
# =============================================================================
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✔ Experimento concluído!${NC}"
echo -e "  Dataset  : $DATASET"
echo -e "  Modo     : $MODE_DISPLAY"
echo -e "  Runs     : $N_RUNS"
echo -e "  Resultados: $OUTDIR"

if [ ${#RMSE_VALUES[@]} -gt 0 ]; then
    echo -e "\n  Resultados EVO:"
    for V in "${RMSE_VALUES[@]}"; do
        echo -e "    $V"
    done
fi

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
