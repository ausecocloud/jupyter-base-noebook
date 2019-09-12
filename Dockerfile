FROM debian:10-slim

# use AU mirror
#RUN sed -i'' -e 's/archive.ubuntu.com/au.archive.ubuntu.com/' /etc/apt/sources.list

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
#    build-essential \
#    fonts-liberation \
#    gfortran \
#    ffmpeg \
#    lmodern \
#    locales \
#    lsb-release \
#    texlive-fonts-extra \
#    texlive-fonts-recommended \
#    texlive-generic-recommended \
#    texlive-latex-extra \
RUN apt-get update \
 && apt-get -y upgrade \
 && apt-get install -yq --no-install-recommends \
    ca-certificates \
    curl \
    bzip2 \
    git \
    gnupg2 \
    less \
    make \
    procps \
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-generic-recommended \
    pandoc \
    python3 \
    python3-distutils \
    unzip \
    vim-tiny \
    wget \
    zip \
 && curl -sL https://deb.nodesource.com/setup_10.x | bash - \
 && apt-get install -y nodejs \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# generate en_US locale to use
#RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
# && locale-gen

# Install Tini
RUN curl -LO https://github.com/krallin/tini/releases/download/v0.18.0/tini \
 && echo "12d20136605531b09a2c2dac02ccee85e1b874eb322ef6baf7561cd93f93c855 *tini" | sha256sum -c - \
 && mv tini /usr/local/bin/tini \
 && chmod +x /usr/local/bin/tini

# install pip
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
 && python3 get-pip.py \
 && rm get-pip.py \
 && rm -fr ~/.cache/pip 


# install jupyter notebook
# - add some base extensions
# - remove default python kernel from this python environment.
#   we don't want users to run the python kernel for jupyter itself.
# TODO: need tornado < 6 for notebook < 5.7.5
# TODO: jupyterhub upgrade?????
# https://github.com/ausecocloud/jupyter_environment_kernels/archive/13eea335f5945270cdce3cd561a58bc1b4ae0b06.zip \
RUN pip3 install --no-cache-dir \
      notebook==6.0.1 \
      ipywidgets==7.5.1 \
      ipyleaflet==0.11.1 \
      jupyterhub==0.9.4 \
      tornado \
      jupyterlab==1.1.2 \
      jupyter_nbextensions_configurator==0.4.1 \
      jupyter_contrib_nbextensions==0.5.1 \
      https://github.com/ausecocloud/jupyter-server-proxy/archive/145804e0e0d7599c2322599834851483d99d195e.zip \
      https://github.com/Anaconda-Platform/nb_conda_kernels/archive/2.2.2.zip \
      jupyter_conda==3.1.0 \
      https://github.com/ausecocloud/nb_data_ui/archive/ed1c83427faf52cc2c06dbc97897576bbded86a5.zip \
 && jupyter nbextension enable --py --sys-prefix widgetsnbextension \
 && jupyter nbextensions_configurator enable --sys-prefix \
 && jupyter contrib nbextension install --sys-prefix \
 && jupyter serverextension enable --sys-prefix jupyter_server_proxy \
 && jupyter nbextension install --py --sys-prefix nb_data_ui \
 && jupyter nbextension enable --py --sys-prefix nb_data_ui \
 && jupyter serverextension enable --sys-prefix nb_data_ui \
 && jupyter nbextension install --py --sys-prefix jupyter_conda \
 && jupyter nbextension enable --py --sys-prefix jupyter_conda \
 && jupyter serverextension enable --py --sys-prefix jupyter_conda \
 && jupyter kernelspec uninstall -f python3 \
 && rm -fr /root/.cache

# install jupyterlab extensions
# TODO:  jupyterlab-server-proxy@^1.0.0 \  # ... the version we need is not released yet
# TODO: nice to have?  jupyterlab-chart-editor@1.2 \
RUN pip3 install --no-cache-dir \
      jupyterlab-latex==1.0.0 \
      jupyterlab_github==0.7.0 \
 && jupyter serverextension enable --sys-prefix jupyterlab_latex \
 && jupyter serverextension enable --sys-prefix jupyterlab_github \
 && NODE_OPTIONS=--max-old-space-size=4096 jupyter labextension install --no-build \
      @jupyterlab/hub-extension@^1.1.0 \
      @jupyterlab/latex@^1.0.0 \
      @jupyterlab/google-drive@^1.0.0 \
      jupyterlab_bokeh@=1.0.0 \
      @jupyterlab/geojson-extension@^1.0.0 \
      @jupyter-widgets/jupyterlab-manager@1.0 \
      plotlywidget@1.1.1 \
      jupyterlab-plotly@^1.1.2 \
      @jupyterlab/github@^1.0.1 \
      jupyter-leaflet@^0.11.1 \
      jupyterlab_toastify@^2.3.2 \
      jupyterlab_conda@^1.1.0 \
 && echo '{ "hub_prefix": "/hub" }' > /usr/local/share/jupyter/lab/settings/page_config.json \
 && rm -fr /usr/local/share/jupyter/lab/staging \
 && rm -fr /usr/local/share/.cache \
 && rm -fr /root/{.cache,.npm} \
 && rm -fr /tmp/*

# TODO: jupyterlab-server-proxy is not released yet
RUN cd /tmp \
  && git clone --depth 1 https://github.com/jupyterhub/jupyter-server-proxy \
  && cd jupyter-server-proxy/jupyterlab-server-proxy \
  && jlpm install \
  && jlpm run build \
  && jlpm pack \
  && NODE_OPTIONS=--max-old-space-size=4096 jupyter labextension install --no-build jupyterlab-server-proxy-*.tgz \
  && cd \
  && rm -fr /usr/local/share/jupyter/lab/staging \
  && rm -fr /usr/local/share/.cache \
  && rm -fr /root/{.config,.cache,.npm} \
  && rm -fr /tmp/*

# install lab_data_ui, which also builds the final version of lab ui
RUN cd /tmp \
  && REV=e123d17cab8de66bd6f961182f11d03e58c21a20 \
  && curl -LO https://github.com/ausecocloud/lab_data_Ui/archive/${REV}.zip \
  && unzip ${REV}.zip \
  && cd lab_data_ui-${REV} \
  && jlpm install \
  && jlpm run build \
  && jlpm pack \
  && NODE_OPTIONS=--max-old-space-size=4096 jupyter labextension install lab_data_ui-*.tgz \
  && cd /tmp \
  && rm -fr lab_data_ui-${REV} \
  && rm -fr ${REV}.zip \
  && cd \
  && rm -fr /usr/local/share/jupyter/lab/staging \
  && rm -fr /usr/local/share/.cache \
  && rm -fr /root/{.config,.cache,.npm} \
  && rm -fr /tmp/*


# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash
#    LC_ALL=en_US.UTF-8 \
#    LANG=en_US.UTF-8 \
#    LANGUAGE=en_US.UTF-8

# NOTE: these may be overrideable when starting the notebook... no guarantee though
ENV NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100

# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER \
 && mkdir -p ${CONDA_DIR} \
 && chown -R $NB_USER:$NB_GID ${CONDA_DIR}


USER $NB_USER

# Install conda as jovyan and check the md5 sum provided on the download site
# downgrade default python env to 3.5
ENV MINICONDA_VERSION 4.7.10
RUN cd /tmp \
 && curl -LO https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh \
 && echo "1c945f2b3335c7b2b15130b1b2dc5cf4 *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - \
 && /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p ${CONDA_DIR} \
 && rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh \
 && ${CONDA_DIR}/bin/conda config --system --set auto_update_conda false \
 && ${CONDA_DIR}/bin/conda config --system --set show_channel_urls true \
 && ${CONDA_DIR}/bin/conda config --system --set auto_activate_base false \
 && ${CONDA_DIR}/bin/conda config --system --set channel_priority strict \
 && ${CONDA_DIR}/bin/conda update --yes conda \
 && ${CONDA_DIR}/bin/conda update --all --yes \
 && ${CONDA_DIR}/bin/conda clean -tipsy \
 && ${CONDA_DIR}/bin/conda init \
 && rm -fr /home/$NB_USER/{.cache,.conda,.npm}

# add conda data to jupyter path, so that kernel specs for canda env can be managed
# by user
ENV JUPYTER_PATH=${CONDA_DIR}/share/jupyter

# Add start up scripts
COPY files/bin/ /usr/local/bin/
# Add default config file
COPY files/jupyter_notebook_config.py /etc/jupyter/

EXPOSE 8888

ENV HOME=/home/${NB_USER} \
    PATH=${CONDA_DIR}/bin:$PATH

WORKDIR $HOME

# Container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]
