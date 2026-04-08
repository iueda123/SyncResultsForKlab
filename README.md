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
- `ALL`
  - `NIDPS`, `DMRI`, `SSMRI_NIDP`, `LGI` を順に実行

## 使い方

```bash
./syncRslts.sh \
  --drv-of-subjects-on-proc=/path/to/proc_subjects_root \
  --drv-of-subjects-on-share=/path/to/share_subjects_root
```

単一被験者:

```bash
./syncRslts.sh \
  --subject-id=sub-K2009231730 \
  --drv-of-subjects-on-proc=/path/to/proc_subjects_root \
  --drv-of-subjects-on-share=/path/to/share_subjects_root \
  --mode=LGI \
  --run
```

全モードを一括実行:

```bash
./syncRslts.sh \
  --drv-of-subjects-on-proc=/path/to/proc_subjects_root \
  --drv-of-subjects-on-share=/path/to/share_subjects_root \
  --mode=ALL \
  --run
```

## オプション

- `--subject-id=<SUBJECT_ID>`
  - 指定時は単一被験者だけを処理
- `--drv-of-subjects-on-proc=<PATH>`
  - 同期元の Subjects root
- `--drv-of-subjects-on-share=<PATH>`
  - 同期先の Subjects root
- `--mode=<NIDPS|DMRI|SSMRI_NIDP|LGI|ALL>`
  - 同期対象を指定
- `--keep-structure`
  - `--drv-of-subjects-on-proc` 以下のパス構造を共有先でも保持
- `--run`
  - dry-run ではなく実際に同期
- `--help`
  - ヘルプを表示

## 注意

- `rsync` が必要です。
- 対象が存在しない被験者はスキップされます。
- `ALL` モードでは、一部の対象しか存在しなくても存在するものだけ同期します。
