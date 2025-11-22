# Example Usage

This document provides concrete examples of how to use the differential RNA modifications pipeline.

## Example 1: Basic Analysis with Dorado

This example shows how to analyze direct RNA-seq data using Dorado for modification calling and LMER for differential analysis.

### Input Data Structure

```
/data/my_experiment/
├── control_rep1/
│   ├── sample1.pod5
│   ├── sample2.pod5
│   └── sample3.pod5
├── control_rep2/
│   ├── sample1.pod5
│   ├── sample2.pod5
│   └── sample3.pod5
├── treatment_rep1/
│   ├── sample1.pod5
│   ├── sample2.pod5
│   └── sample3.pod5
└── treatment_rep2/
    ├── sample1.pod5
    ├── sample2.pod5
    └── sample3.pod5
```

### Sample Sheet (samples.csv)

```csv
name,group,path_dorado,path_m6anet,path_pod5
ctrl_rep1,control,,,/data/my_experiment/control_rep1/
ctrl_rep2,control,,,/data/my_experiment/control_rep2/
treat_rep1,treatment,,,/data/my_experiment/treatment_rep1/
treat_rep2,treatment,,,/data/my_experiment/treatment_rep2/
```

### Command

```bash
nextflow run main.nf \
  --samples samples.csv \
  --method dorado \
  --diffanalysis lmer \
  --transcriptome /ref/transcriptome.fasta \
  --outdir results \
  --dataset_name my_experiment \
  -profile docker
```

### Expected Output

```
results/
├── dorado/
│   ├── basecall_align/
│   │   ├── ctrl_rep1/
│   │   │   ├── ctrl_rep1_aligned.bam
│   │   │   └── ctrl_rep1_aligned.bam.bai
│   │   └── ...
│   ├── pileup/
│   │   ├── ctrl_rep1/
│   │   │   ├── ctrl_rep1_pileup.bed.gz
│   │   │   └── ctrl_rep1_pileup.bed.gz.tbi
│   │   └── ...
│   └── extract/
│       ├── ctrl_rep1/
│       │   └── ctrl_rep1_reads.tsv
│       └── ...
├── dataprep/
│   ├── prep_from_dorado/
│   │   └── combined_data.db
│   └── site_selection/
│       └── selected_sites.tsv
└── differential/
    └── lmer/
        └── differential_results.csv
```

## Example 2: Using Pre-basecalled Data

If you already have basecalled BAM files from Dorado, you can skip the basecalling step.

### Sample Sheet (samples_prebascalled.csv)

```csv
name,group,path_dorado,path_m6anet,path_pod5
ctrl_rep1,control,/data/bam_files/ctrl_rep1_dorado.bam,,
ctrl_rep2,control,/data/bam_files/ctrl_rep2_dorado.bam,,
treat_rep1,treatment,/data/bam_files/treat_rep1_dorado.bam,,
treat_rep2,treatment,/data/bam_files/treat_rep2_dorado.bam,,
```

### Command

```bash
nextflow run main.nf \
  --samples samples_prebascalled.csv \
  --method dorado \
  --diffanalysis lmer \
  --outdir results_prebascalled \
  -profile docker
```

## Example 3: m6Anet Analysis

This example uses m6Anet for modification detection instead of Dorado.

### Sample Sheet (samples_m6anet.csv)

```csv
name,group,path_dorado,path_m6anet,path_pod5
ctrl_rep1,control,,/data/m6anet_results/ctrl_rep1_data.index,
ctrl_rep2,control,,/data/m6anet_results/ctrl_rep2_data.index,
treat_rep1,treatment,,/data/m6anet_results/treat_rep1_data.index,
treat_rep2,treatment,,/data/m6anet_results/treat_rep2_data.index,
```

### Command

```bash
nextflow run main.nf \
  --samples samples_m6anet.csv \
  --method m6anet \
  --diffanalysis lmer \
  --outdir results_m6anet \
  -profile docker
```

## Example 4: Multiple Methods Comparison

You can run both Dorado and m6Anet methods and compare results.

### Command

```bash
nextflow run main.nf \
  --samples samples.csv \
  --method '[\"dorado\", \"m6anet\"]' \
  --diffanalysis '[\"lmer\", \"modkit\"]' \
  --outdir results_comparison \
  -profile docker
```

This will run all combinations:
- Dorado + LMER
- Dorado + modkit
- m6Anet + LMER
- m6Anet + modkit

## Example 5: HPC Cluster Execution

For running on a SLURM cluster with GPU support:

### Command

```bash
nextflow run main.nf \
  --samples samples.csv \
  --method dorado \
  --diffanalysis lmer \
  --outdir results_hpc \
  -profile spartan \
  -resume
```

### Monitoring Progress

```bash
# Check job status
squeue -u $USER

# Monitor Nextflow log
tail -f .nextflow.log

# View resource usage
nextflow log -t template.html
```

## Example 6: Testing Pipeline

Before running with real data, test the pipeline:

```bash
# Quick test with stub processes
nextflow run main.nf -profile testing

# Test with small dataset
nextflow run main.nf \
  --samples test_samples.csv \
  --method dorado \
  --diffanalysis lmer \
  --outdir test_results \
  --min_reads 5 \
  --batch_size 10 \
  -profile docker
```

## Parameter Optimization

### Common Parameter Adjustments

1. **Increase minimum read coverage for higher confidence**:
   ```bash
   --min_reads 50
   ```

2. **Adjust probability threshold**:
   ```bash
   --prob_threshold 0.7
   ```

3. **Optimize for memory usage**:
   ```bash
   --batch_size 25  # Reduce batch size if memory limited
   ```

4. **Increase parallelization**:
   ```bash
   --n_threads 32
   ```

## Troubleshooting Common Issues

### Issue 1: Out of Memory

**Error**: Process runs out of memory during basecalling

**Solution**:
```bash
# Reduce batch size
nextflow run main.nf --batch_size 10 ...

# Or increase memory allocation in nextflow.config
process.memory = '64.GB'
```

### Issue 2: GPU Not Detected

**Error**: Dorado cannot find GPU

**Solution**:
```bash
# Check GPU availability
nvidia-smi

# Ensure Docker has GPU access
docker run --gpus all nvidia/cuda:11.0-base nvidia-smi

# Use CPU-only profile if no GPU
nextflow run main.nf -profile docker_cpu ...
```

### Issue 3: File Not Found

**Error**: Cannot find input files

**Solution**:
- Check file paths in sample sheet are absolute paths
- Verify file permissions
- Ensure Docker/Singularity can access file locations

```bash
# Example fix - use absolute paths
/full/path/to/data/sample1.pod5  # Good
./data/sample1.pod5              # May cause issues in containers
```

## Performance Expectations

### Processing Times (approximate)

| Data Size | Method | Time | Resources |
|-----------|--------|------|-----------|
| 1GB POD5 | Dorado (GPU) | 1-2 hours | 1 GPU, 16GB RAM |
| 1GB POD5 | Dorado (CPU) | 8-12 hours | 16 cores, 32GB RAM |
| Pre-basecalled | Either | 30-60 min | 8 cores, 16GB RAM |

### Storage Requirements

- POD5 files: Original size
- BAM files: ~2-3x POD5 size
- Intermediate files: ~1x BAM size
- Final results: <100MB typically

Plan for ~5-6x original POD5 size for total storage during processing.