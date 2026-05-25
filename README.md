# SyncResultsForKlab

被験者フォルダ配下の成果物を `rsync` で共有先へ同期するためのスクリプト集です。

現在のメインスクリプトは [syncRslts.sh](./syncRslts.sh) です。

## 概要

`syncRslts.sh` は、処理サーバー側の Subjects root から共有先の Subjects root へ、被験者単位で成果物を同期します。

デフォルトは dry-run です。実際に転送する場合だけ `--run` を付けます。

## 対応モード

- `NIDPS`
  - `${SUBJECT_ID}/NIDPs/` を同期
- `DMRI`
  - `${SUBJECT_ID}/T1w/Diffusion/`
  - `${SUBJECT_ID}/Diffusion/`
  - `${SUBJECT_ID}/T1w/T1w_acpc_dc_restore_1.50.nii.gz`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_DataSNR_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_DataSNR_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_DataSNR_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_DataSNR_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_FA_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_FA_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_FA_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_FA_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_FICVF_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_FICVF_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_FICVF_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_FICVF_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_Kappa_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_Kappa_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_Kappa_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_Kappa_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_MD_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_MD_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_MD_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_MD_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_ODI_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_ODI_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_ODI_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_ODI_MSMSulc.pscalar.nii`
- `SSMRI_NIDP`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_CT_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_CT_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_CT_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_CT_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_CV_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_CV_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_CV_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_CV_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_MM_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_MM_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_MM_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_MM_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_NSA_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_NSA_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_NSA_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_NSA_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_SA_MSMAll.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_SA_MSMAll.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_SA_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_SA_MSMSulc.pscalar.nii`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_SubV.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_aseg.stats`
- `LGI`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_LGI_MSMSulc.csv`
  - `${SUBJECT_ID}/NIDPs/${SUBJECT_ID}_LGI_MSMAll.csv`
  - `${SUBJECT_ID}/T1w/${SUBJECT_ID}/stats/lh.mean.pial_lgi.stats`
  - `${SUBJECT_ID}/T1w/${SUBJECT_ID}/stats/rh.mean.pial_lgi.stats`
  - `${SUBJECT_ID}/T1w/${SUBJECT_ID}/stats/lh.aparc.pial_lgi.stats`
  - `${SUBJECT_ID}/T1w/${SUBJECT_ID}/stats/rh.aparc.pial_lgi.stats`
  - `${SUBJECT_ID}/T1w/${SUBJECT_ID}/surf/lh.pial_lgi`
  - `${SUBJECT_ID}/T1w/${SUBJECT_ID}/surf/rh.pial_lgi`
  - `${SUBJECT_ID}/T1w/${SUBJECT_ID}/stats/lh.aparc.a2009s.pial_lgi.stats`
  - `${SUBJECT_ID}/T1w/${SUBJECT_ID}/stats/rh.aparc.a2009s.pial_lgi.stats`
- `ALL`
  - `NIDPS`, `DMRI`, `SSMRI_NIDP`, `LGI` を順に実行

## 使い方

### dry-run（デフォルト）

`--run` を省くと常に dry-run になります。転送前の確認に使います。

```bash
./syncRslts.sh \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=NIDPS
```

---

### NIDPS

NIDPs フォルダ全体を同期します。

全被験者:

```bash
./syncRslts.sh \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=NIDPS \
  --run
```

単一被験者:

```bash
./syncRslts.sh \
  --subject-id=sub-EXAMPLE001 \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=NIDPS \
  --run
```

複数被験者をリストで指定:

```bash
subjects=()
subjects+=("sub-EXAMPLE001")
subjects+=("sub-EXAMPLE002")
subjects+=("sub-EXAMPLE003")

for sbjid in "${subjects[@]}"; do
  ./syncRslts.sh \
    --subject-id="${sbjid}" \
    --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
    --drv-of-subjects-on-dst=/path/to/share/ext_project \
    --mode=NIDPS \
    --run
done
```

---

### DMRI

拡散 MRI の成果物（Diffusion/ フォルダ、T1w_acpc_dc_restore、dMRI 系 NIDPs）を同期します。

全被験者:

```bash
./syncRslts.sh \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=DMRI \
  --run
```

単一被験者:

```bash
./syncRslts.sh \
  --subject-id=sub-EXAMPLE001 \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=DMRI \
  --run
```

複数被験者をリストで指定:

```bash
subjects=()
subjects+=("sub-EXAMPLE001")
subjects+=("sub-EXAMPLE002")
subjects+=("sub-EXAMPLE003")

for sbjid in "${subjects[@]}"; do
  ./syncRslts.sh \
    --subject-id="${sbjid}" \
    --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
    --drv-of-subjects-on-dst=/path/to/share/ext_project \
    --mode=DMRI \
    --run
done
```

---

### SSMRI_NIDP

構造 MRI の NIDPs（皮質厚・体積・面積など）を同期します。

全被験者:

```bash
./syncRslts.sh \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=SSMRI_NIDP \
  --run
```

単一被験者:

```bash
./syncRslts.sh \
  --subject-id=sub-EXAMPLE001 \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=SSMRI_NIDP \
  --run
```

複数被験者をリストで指定:

```bash
subjects=()
subjects+=("sub-EXAMPLE001")
subjects+=("sub-EXAMPLE002")
subjects+=("sub-EXAMPLE003")

for sbjid in "${subjects[@]}"; do
  ./syncRslts.sh \
    --subject-id="${sbjid}" \
    --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
    --drv-of-subjects-on-dst=/path/to/share/ext_project \
    --mode=SSMRI_NIDP \
    --run
done
```

---

### LGI

局所脳回指数（LGI）の統計ファイルとサーフェスを同期します。

全被験者:

```bash
./syncRslts.sh \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=LGI \
  --run
```

単一被験者:

```bash
./syncRslts.sh \
  --subject-id=sub-EXAMPLE001 \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=LGI \
  --run
```

複数被験者をリストで指定:

```bash
subjects=()
subjects+=("sub-EXAMPLE001")
subjects+=("sub-EXAMPLE002")
subjects+=("sub-EXAMPLE003")

for sbjid in "${subjects[@]}"; do
  ./syncRslts.sh \
    --subject-id="${sbjid}" \
    --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
    --drv-of-subjects-on-dst=/path/to/share/ext_project \
    --mode=LGI \
    --run
done
```

---

### ALL

NIDPS・DMRI・SSMRI_NIDP・LGI を順にまとめて実行します。

全被験者:

```bash
./syncRslts.sh \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=ALL \
  --run
```

単一被験者:

```bash
./syncRslts.sh \
  --subject-id=sub-EXAMPLE001 \
  --drv-of-subjects-on-src=/path/to/proc/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share/ext_project \
  --mode=ALL \
  --run
```

---

### パス構造の保持（デフォルト動作）

同期元のパス構造を同期先でも保持します（デフォルト）。\
`/path/to/proc/project/derivatives` のように渡すと、同期先に `project/derivatives/` 以下として展開されます。

```bash
./syncRslts.sh \
  --drv-of-subjects-on-src=/path/to/proc/project/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share \
  --mode=NIDPS \
  --run
```

### --flatten

同期先のパス構造を平坦化したい場合に使います。\
`--drv-of-subjects-on-dst` 直下に被験者フォルダを配置します。

```bash
./syncRslts.sh \
  --drv-of-subjects-on-src=/path/to/proc/project/derivatives/HCPpipeline \
  --drv-of-subjects-on-dst=/path/to/share \
  --mode=NIDPS \
  --flatten \
  --run
```

## オプション

- `--subject-id=<SUBJECT_ID>`
  - 指定時は単一被験者だけを処理
- `--drv-of-subjects-on-src=<PATH>`
  - 同期元の Subjects root
- `--drv-of-subjects-on-dst=<PATH>`
  - 同期先の Subjects root
- `--mode=<NIDPS|DMRI|SSMRI_NIDP|LGI|ALL>`
  - 同期対象を指定
- `--flatten`
  - 同期先のパス構造を平坦化（デフォルトは構造保持）
- `--run`
  - dry-run ではなく実際に同期
- `--help`
  - ヘルプを表示

## 注意

- `rsync` が必要です。
- 対象が存在しない被験者はスキップされます。
- `ALL` モードでは、一部の対象しか存在しなくても存在するものだけ同期します。
