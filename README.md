HMM Project
---

This project uses GNU Make as the taskrunner for all models

```sh
$ make build
$ podman run --bind $PWD:/data jsks/hmm output file=/data/output.csv
```

Model deployment is handled by building an OCI image, `jsks/hmm`, and running the `submit.sh` script to push the image to the HPC, convert it to [apptainer](https://apptainer.org/), and submits a model run job via SLURM.


```sh
$ make build
$ scripts/submit.sh hmm
```

Results are stored on the HPC under `~/storage/` and need to be fetched via `rsync`. Once the posterior `posteriors/output_*.csv` are available locally, the manuscript PDF, `paper.pdf`, can be built via the default rule to `Make`.

```sh
$ make
```
