HMM Project
---

Model deployment is handled by building an OCI image, `jsks/hmm`, that gets pushed to ghcr.io. Running the script `submit.sh` pulls the image to the HPC, converts it to [apptainer](https://apptainer.org/), and submits a model run job via Slurm.

```sh
$ make build && make push
$ scripts/submit.sh
```

Results are stored on the HPC under `~/storage/` and need to be fetched via `scp`. Once the posterior `fit.rds` is avalable locally, the manuscript PDF, `paper.pdf`, can be built via the default rule to `Make`.

```sh
$ make
```
