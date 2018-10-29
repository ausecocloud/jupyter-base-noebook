#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e

if [[ ! -z "${JUPYTERHUB_API_TOKEN}" ]]; then
  # launched by JupyterHub, use single-user entrypoint
  exec /usr/local/bin/start-singleuser.sh $*
else
  # call jupyter-notebook instead of 'jupyter notebook'
  # jupyter would execvp notebook, but to do so, it will mess
  # with the PATH env var to call the correct notebook script
  if [[ ! -z "${JUPYTER_ENABLE_LAB}" ]]; then
    . /usr/local/bin/start.sh jupyter-lab $*
  else
    . /usr/local/bin/start.sh jupyter-notebook $*
  fi
fi
