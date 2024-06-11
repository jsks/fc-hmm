HMMs & Civil Conflicts Project
---

To compile the current version of the manuscript:

```sh
$ scripts/paper.sh
```

Individual models can be re-run using the `scripts/run.sh` script.

```sh
$ ls -d stan/*/
$ scripts/run.sh --help
```

## Running from scratch

If you'd like to reproduce the entire project from scratch you first
need to build the base image used for running the data clean/merge
pipeline and later compiling the manuscript, `paper.qmd`.

```
$ podman build -t ghcr.io/jsks/fc-hmm/r-image -f podman/r-image .
```

Next, ensure that the following raw data sources are available under `data/raw`.

- UCDP Peace Agreements 22.1 (`data/raw/ucdp-peace-agreements-221.xlsx`)
- UCDP Termination Dataset 3-2021 (`data/raw/ucdp-term-acd-3-2021.xlsx`)
- UCDP Georeference Event Dataset (GED) 23.1 (`data/raw/GEDEvent_v23_1.rds`)
- UCDP/PRIO Armed Conflict Dataset 23.1 (`data/raw/UcdpPrioConflict_v23_1.rds`)
- V-Dem Country-Year Dataset v14 (`data/raw/V-Dem-CY-Full+Others-v14.rds`)
- Third Party Peacekeeping Missions Dataset 3.5 (`data/raw/Third-Party-PKMs-version-3.5.xls`)
- Ceasefires Project Oct 2022 (`data/raw/CFD_oct_2022_id-1.xlsx`)
- SIPRI Arms Transfer Dataset 1950-2023 (`data/raw/import-export-values_1950-2023.csv`)

Each model will need to be built as an OCI image using the
`scripts/build.sh` script and run using `scripts/run.sh`.

```sh
$ scripts/build.sh --help
$ scripts/run.sh --help
```


Finally, the manuscript can be compiled to PDF output using the same script as above.

```sh
$ scripts/paper.sh --help
```


