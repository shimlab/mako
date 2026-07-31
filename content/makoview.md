---
title: makoview
hide:
  - navigation
---

Mako comes with an interactive application called **_Makoview_** which can be used to visualise the results once the pipeline has finished. You can see an interactive demo of Makoview here: [https://shimlab.github.io/makoview/gene](https://shimlab.github.io/makoview/gene).

![makoview screenshot](./assets/makoview.png)

## Install
Makoview is automatically installed by the Mako pipeline into a virtual environment. Once the execution has completed, run:
```sh
$ <results_dir>/makoview/launch_makoview.sh
```

## Running on HPC

On HPC systems, if you have SSH access, you can port forward the web server from the server to your local machine.

It is recommended that you run Makoview from your HPC system's login node.

### 1. Start Makoview on HPC
```console title="🏢 HPC shell"
[userX@hpc-login-node]$ ./makoview/launch_makoview.sh

INFO:     Started server process [18394]
INFO:     Waiting for application startup.

... abridged ...

============================================================
  Makoview is running on http://127.0.0.1:52348

  Tip: advice on accessing Makoview from other devices
       using SSH port forwarding can be found in the docs:
       https://shimlab.github.io/mako/makoview
============================================================

```

### 2. Port forward the HPC port
Replace "52348" with the port that Makoview is running on. Keep this ssh process running in the background.

```console title="💻 Client device"
[userX@user-client]$ ssh -NL 52348:localhost:52348 userX@hpc-login-node
```

### 3. Open Makoview
Visit a browser on your client device and navigate to localhost:52348, or the correct port.

### Manual installation and usage

!!! warning
    Makoview depends on the output produced by Mako and is automatically installed by the Mako pipeline into a virtual environment. Run Makoview manually at your own risk!

<details>
<summary>Show details</summary>
makoview is a Python package for Python 3.9 — 3.12.12, available on PyPI and downloadable through your preferred Python package manager.

```bash
# with pip:
$ pip install makoview
$ makoview --help

# with pipx:
$ pipx run makoview --help

# using uvx (✅ recommended!!)
$ uvx makoview --help        # or uvx --python 3.12 makoview --help
```

[`pipx`](https://github.com/pypa/pipx) and [`uv`](https://docs.astral.sh/uv/) allow executables to be run within their own isolated environment, preventing dependency resolution issues. They are recommended over `pip install`.

Makoview has three parameters:

```bash
options:
  -h, --help            show this help message and exit
  --differential-results DIFFERENTIAL_RESULTS
                        Path to differential sites database file
  --modification-db MODIFICATION_DB
                        Path to modification database file
  --port PORT           Port for the Shiny application (default: 8000)
```

The default usage is as follows:

```bash
export MAKO_OUTPUT_DIR="/data/gpfs/projects/punim0614/occheng/epi_differential/pipeline/runs/longbench/results"
export MODCALLER="dorado"  # either "dorado" or "m6anet"
export DIFFERENTIAL_MODEL="adaptive_binomial"
makoview \
  --differential-results $MAKO_OUTPUT_DIR/differential/$MODCALLER/${DIFFERENTIAL_MODEL}_fits.tsv \
  --modification-db $MAKO_OUTPUT_DIR/modcall/$MODCALLER/all_sites.duckdb \
  --port 8000
```

This will launch a web server running on port `8000`.

</details>