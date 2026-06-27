# ORB-SLAM3 Custom Docker
## Aprimoramento de SLAM Monocular com Estimação de Profundidade Baseada em Aprendizado Profundo

Docker com ORB-SLAM3 original, viewer desabilitado, EVO instalado e pipeline de experimentos automatizado para avaliação em datasets TUM RGB-D.

---

## Estrutura

```
orbslam3_custom/
├── Dockerfile
├── docker-compose.yml
├── scripts/
│   ├── config.sh              ← edite aqui para configurar o experimento
│   ├── run.sh                 ← pipeline automático (não editar)
│   ├── TUM2_dav2.yaml         ← yaml calibrado para DAV2 relativo (fr2_xyz)
│   └── calibrar_depth_metrico.py ← calibração affine do depth sintético
└── results/
    ├── fr1_desk/
    ├── fr2_xyz/
    └── fr3_office/
```

---

## Requisitos

- Docker
- docker compose
- GPU NVIDIA (opcional)

---

## Instalação

```bash
git clone https://github.com/rafaelheydt/orbslam3-custom.git
cd orbslam3-custom
xhost +local:docker
docker compose build
```

O build leva ~20 minutos na primeira vez.

---

## Datasets TUM

Baixe os datasets em [https://cvg.cit.tum.de/data/datasets/rgbd-dataset](https://cvg.cit.tum.de/data/datasets/rgbd-dataset) e extraia em `~/datasets/tum/`:

```bash
mkdir -p ~/datasets/tum
cd ~/datasets/tum

# fr1/desk
wget https://cvg.cit.tum.de/rgbd/dataset/freiburg1/rgbd_dataset_freiburg1_desk.tgz
tar -xzf rgbd_dataset_freiburg1_desk.tgz

# fr2/xyz
wget https://cvg.cit.tum.de/rgbd/dataset/freiburg2/rgbd_dataset_freiburg2_xyz.tgz
tar -xzf rgbd_dataset_freiburg2_xyz.tgz

# fr3/office
wget https://cvg.cit.tum.de/rgbd/dataset/freiburg3/rgbd_dataset_freiburg3_long_office_household.tgz
tar -xzf rgbd_dataset_freiburg3_long_office_household.tgz
```

---

## Depth sintético

Os depth maps sintéticos são gerados no Google Colab usando os notebooks disponíveis no projeto:

| Notebook | Descrição |
|---|---|
| `midas_colab.ipynb` | Gera depth MiDaS DPT_Large (relativo) |
| `dav2_metric_colab.ipynb` | Gera depth DAV2 Métrico Hypersim (absoluto) |
| `calibracao_affine_colab.ipynb` | Calibração affine do depth sintético |

Após geração, coloque os arquivos na pasta do dataset:

```
~/datasets/tum/rgbd_dataset_freiburg1_desk/
├── depth_midas/                    ← gerado no Colab
├── depth_midas_affine/             ← gerado no Colab (calibração affine)
├── depth_dav2_metric_vitl/         ← gerado no Colab
├── associations_midas.txt          ← gerado no Colab
├── associations_midas_affine.txt   ← gerado no Colab
└── associations_dav2_metric_vitl.txt ← gerado no Colab
```

---

## Como usar

### 1. Editar o config

```bash
nano scripts/config.sh
```

```bash
DATASET="fr2_xyz"        # fr1_desk | fr2_xyz | fr3_office
MODE="rgbd_baseline"     # ver tabela de modos abaixo
N_RUNS=1                 # número de runs
RUN_EVO=true             # avaliar com EVO automaticamente
```

### 2. Subir o container

```bash
docker compose run orbslam3
```

### 3. Rodar o experimento

```bash
# Dentro do container
bash /root/scripts/run.sh
```

### 4. Ver os resultados

```bash
# No host
ls ~/orbslam3_results/fr2_xyz/rgbd_baseline/
```

---

## Datasets suportados

| `DATASET` | Sequência TUM | Câmera | Frames |
|---|---|---|---|
| `fr1_desk` | freiburg1/desk | freiburg1 | 573 |
| `fr2_xyz` | freiburg2/xyz | freiburg2 | 3669 |
| `fr3_office` | freiburg3/long_office_household | freiburg3 | 2585 |

---

## Modos disponíveis

| `MODE` | Sensor de profundidade | Calibração |
|---|---|---|
| `rgbd_baseline` | Depth real do sensor RGB-D | — |
| `monocular` | Câmera monocular (sem depth) | — |
| `midas` | MiDaS DPT_Large (relativo) | nenhuma |
| `midas_affine` | MiDaS DPT_Large + calibração affine | `s·d+t` global por dataset |
| `dav2_vitl` | DAV2 Large relativo | nenhuma |
| `dav2_metric_vitl` | DAV2 Métrico Hypersim (absoluto) | nenhuma |

---

## Calibração affine do depth sintético

O MiDaS retorna disparidade relativa — sem unidade métrica. Para converter para metros,
utilizamos uma calibração affine global por dataset:

```
d_metros = s × d_sint + t
```

Os parâmetros `(s, t)` são estimados comparando o depth sintético com o depth real do
sensor RGB-D em frames de referência. O script de calibração está em `scripts/calibrar_depth_metrico.py`.

```bash
# No host (venv com scipy e sklearn)
python3 scripts/calibrar_depth_metrico.py \
    --dataset fr2_xyz --modelo midas --metodo affine --aplicar --plot
```

---

## Resultados (ATE RMSE, alinhamento SE3)

| Pipeline | fr2_xyz | fr1_desk | fr3_office |
|---|---|---|---|
| RGB-D Baseline | 0.40cm | 1.69cm | 1.21cm |
| Monocular | 7.91cm | 6.05cm | 121.66cm |
| MiDaS puro | 27.79cm | 28.52cm | 440.88cm |
| **MiDaS + Affine** | **8.15cm** | **21.00cm** | **42.85cm** |
| DAV2 Métrico | 8.75cm | 24.58cm | 31.22cm |

---

## Arquivos de resultado

Gerados automaticamente em `~/orbslam3_results/<dataset>/<mode>/`:

| Arquivo | Descrição |
|---|---|
| `KeyFrameTrajectory_run1.txt` | Trajetória nos keyframes — usar para ATE |
| `CameraTrajectory_run1.txt` | Trajetória em todos os frames |
| `ate_KeyFrameTrajectory_run1.zip` | Resultado EVO com stats.json |
| `params.yaml` | Parâmetros do SLAM usados |
| `run1_meta.txt` | Metadados: dataset, modo, tempo, RMSE |

---

## Avaliação com EVO

```bash
source ~/.venvs/calibracao/bin/activate

# ATE com alinhamento SE(3)
evo_ape tum \
    ~/datasets/tum/rgbd_dataset_freiburg2_xyz/groundtruth.txt \
    ~/orbslam3_results/fr2_xyz/midas_affine/CameraTrajectory_run1.txt \
    --align

# Trajetória comparativa
evo_traj tum \
    ~/orbslam3_results/fr2_xyz/midas_affine/CameraTrajectory_run1.txt \
    --ref ~/datasets/tum/rgbd_dataset_freiburg2_xyz/groundtruth.txt \
    --align --plot
```

---

## Volumes montados

| Host | Container |
|---|---|
| `~/datasets` | `/root/datasets` |
| `~/orbslam3_results` | `/root/results` |
| `~/orbslam3_custom/scripts` | `/root/scripts` |

---

## Referências

- [ORB-SLAM3](https://github.com/UZ-SLAMLab/ORB_SLAM3) — Campos et al., 2021
- [MiDaS](https://github.com/isl-org/MiDaS) — Ranftl et al., 2022
- [Depth Anything V2](https://github.com/DepthAnything/Depth-Anything-V2) — Yang et al., 2024
- [TUM RGB-D Dataset](https://cvg.cit.tum.de/data/datasets/rgbd-dataset) — Sturm et al., 2012
- [EVO](https://github.com/MichaelGrupp/evo) — Grupp, 2017

---

## Licença

Este projeto usa o [ORB-SLAM3](https://github.com/UZ-SLAMLab/ORB_SLAM3) sob licença GPLv3.