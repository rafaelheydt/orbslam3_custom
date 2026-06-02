# ORB-SLAM3 Custom Docker
## Aprimoramento de SLAM Monocular com Estimação de Profundidade Baseada em Aprendizado Profundo

Docker com ORB-SLAM3 original, viewer desabilitado, EVO instalado e pipeline de experimentos automatizado para avaliação em datasets TUM RGB-D.

---

## Estrutura

```
orbslam3_custom/
├── Dockerfile
├── docker-compose.yml
└── scripts/
    ├── config.sh   ← edite aqui para configurar o experimento
    └── run.sh      ← pipeline automático (não editar)
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
```

---

## Depth sintético (MiDaS / DAV2)

Os depth maps sintéticos são gerados no Google Colab usando o notebook disponível no projeto.
Após geração, coloque os arquivos na pasta do dataset:

```
~/datasets/tum/rgbd_dataset_freiburg1_desk/
├── depth_midas/               ← gerado no Colab
├── depth_dav2_vitl/           ← gerado no Colab
├── associations_midas.txt     ← gerado no Colab
└── associations_dav2_vitl.txt ← gerado no Colab
```

---

## Como usar

### 1. Editar o config

```bash
nano scripts/config.sh
```

```bash
DATASET="fr1_desk"      # fr1_desk | fr2_xyz | fr3_office | custom
MODE="rgbd_baseline"    # rgbd_baseline | monocular | midas | dav2_vitl | dav2_vitb | dav2_vits
N_RUNS=1                # número de runs
RUN_EVO=true            # avaliar com EVO automaticamente
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
ls ~/orbslam3_results/fr1_desk/rgbd_baseline/
```

---

## Datasets suportados

| `DATASET` | Sequência TUM | Frames |
|---|---|---|
| `fr1_desk` | freiburg1/desk | 573 |
| `fr2_xyz` | freiburg2/xyz | 3669 |
| `fr3_office` | freiburg3/long_office | 2585 |
| `custom` | qualquer | — |

Para dataset customizado, preencha as variáveis `CUSTOM_*` no `config.sh`.

---

## Modos disponíveis

| `MODE` | Sensor de profundidade |
|---|---|
| `rgbd_baseline` | Depth real do sensor RGB-D |
| `monocular` | Câmera monocular (sem depth) |
| `midas` | Depth sintético MiDaS |
| `dav2_vitl` | Depth sintético DAV2 Large |
| `dav2_vitb` | Depth sintético DAV2 Base |
| `dav2_vits` | Depth sintético DAV2 Small |

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

## Volumes montados

| Host | Container |
|---|---|
| `~/datasets` | `/root/datasets` |
| `~/orbslam3_results` | `/root/results` |
| `~/orbslam3_custom/scripts` | `/root/scripts` |

---

## Licença

Este projeto usa o [ORB-SLAM3](https://github.com/UZ-SLAMLab/ORB_SLAM3) sob licença GPLv3.
