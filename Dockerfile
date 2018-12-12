FROM python:3.6-slim-stretch

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
    build-essential \
    curl \
    bzip2 \
    git \
    gnupg2 \
    less \
    make \
    procps \
    texlive-xetex \
    unzip \
    vim-tiny \
    wget \
    zip \
 && curl -sL https://deb.nodesource.com/setup_8.x | bash - \
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

# install jupyter notebook
# - add some base extensions
# - remove default python kernel from this python environment.
#   we don't want users to run the python kernel for jupyter itself.
# nbserverproxy==0.8.5
RUN pip3 install --no-cache-dir \
      notebook==5.7.0 \
      ipywidgets==7.4.2 \
      ipyleaflet==0.9.0 \
      jupyterhub==0.9.4 \
      jupyterlab==0.34.12 \
      jupyter_nbextensions_configurator==0.4.0 \
      jupyter_contrib_nbextensions==0.5.0 \
      https://github.com/jupyterhub/nbserverproxy/archive/41d0fae920867d823b958d1c0494f59a850144fc.zip \
      https://github.com/ausecocloud/jupyter_environment_kernels/archive/13eea335f5945270cdce3cd561a58bc1b4ae0b06.zip \
      https://github.com/ausecocloud/nb_data_ui/archive/ed1c83427faf52cc2c06dbc97897576bbded86a5.zip \
 && jupyter nbextension enable --py --sys-prefix widgetsnbextension \
 && jupyter nbextensions_configurator enable --sys-prefix \
 && jupyter contrib nbextension install --sys-prefix \
 && jupyter serverextension enable --sys-prefix nbserverproxy \
 && jupyter nbextension install --py --sys-prefix nb_data_ui \
 && jupyter nbextension enable --py --sys-prefix nb_data_ui \
 && jupyter serverextension enable --sys-prefix nb_data_ui \
 && jupyter kernelspec uninstall -f python3 \
 && rm -fr /root/.cache

# TODO:
# - github extension may need server ext? https://github.com/jupyterlab/jupyterlab-github
# - github extension: we should somehow store the user config? (or maybe not, ... strogin the user token may be a problem)
#                     can we get it in via keycloak?
# - general store / restore user settings for jupyter (and addons)
#   add ons with custom config:
#     - github
#     - google-drive
# - google drive: https://github.com/jupyterlab/jupyterlab-google-drive/blob/master/docs/advanced.md
# - jupyterlab_discovery ... needs patching, as it fails with npm packages that
#     are not publish on npm.org (e.g. rstudio extension)
# - other interesting addons
#     - https://github.com/Microsoft/monaco-editor/
#     - https://github.com/jupyterlab/jupyterlab-git


# install jupyterlab extensions
RUN pip3 install --no-cache-dir \
      jupyterlab-latex==0.4.1 \
      jupyterlab_github==0.7.0 \
 && jupyter serverextension enable --sys-prefix jupyterlab_latex \
 && NODE_OPTIONS=--max-old-space-size=4096 jupyter labextension install --no-build \
      @jupyterlab/hub-extension@^0.11.0 \
      @jupyterlab/latex@^0.5.0 \
      @jupyterlab/google-drive@^0.14.0 \
      jupyterlab_bokeh@=0.6.2 \
      @jupyterlab/geojson-extension@^0.17.1 \
      @jupyterlab/plotly-extension@^0.17.2 \
      @jupyterlab/github@^0.9.0 \
      jupyter-leaflet@^0.9.0 \
      @jupyter-widgets/jupyterlab-manager@^0.37.4 \
 && echo '{ "hub_prefix": "/hub" }' > /usr/local/share/jupyter/lab/settings/page_config.json \
 && rm -fr /usr/local/share/jupyter/lab/staging \
 && rm -fr /usr/local/share/.cache \
 && rm -fr /root/{.cache,.npm}

# install lab_data_ui
RUN cd /tmp \
  && REV=a06d276e353d09f281c1fc603d9318f6a8ef5dc4 \
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
  && rm -fr /root/{.cache,.npm} \
  && chown -R $NB_USER:$NB_GID $HOME


# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash
#    LC_ALL=en_US.UTF-8 \
#    LANG=en_US.UTF-8 \
#    LANGUAGE=en_US.UTF-8

# NOTE: these may be overrideable when starting the notebook... no guarantee though
ENV NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100 \
    PATH=${CONDA_DIR}/bin:$PATH

# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER \
 && mkdir -p ${CONDA_DIR} \
 && chown -R $NB_USER:$NB_GID ${CONDA_DIR}

USER $NB_USER

# Install conda as jovyan and check the md5 sum provided on the download site
# downgrade default python env to 3.5
ENV MINICONDA_VERSION 4.5.4
RUN cd /tmp \
 && curl -LO https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh \
 && echo "a946ea1d0c4a642ddf0c3a26a18bb16d *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - \
 && /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p ${CONDA_DIR} \
 && rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh \
 && conda config --system --set auto_update_conda false \
 && conda config --system --set show_channel_urls true \
 && conda update --yes conda \
 && conda update --all --yes \
 && conda clean -tipsy \
 && rm -fr /home/$NB_USER/{.cache,.conda,.npm}


# add conda data to jupyter path, so that kernel specs for canda env can be managed
# by user
ENV JUPYTER_PATH=${CONDA_DIR}/share/jupyter

# Add start up scripts
COPY files/bin/ /usr/local/bin/
# Add default config file
COPY files/jupyter_notebook_config.py /etc/jupyter/

EXPOSE 8888

ENV HOME=/home/${NB_USER}

# Setup conda environment
RUN echo ". /opt/conda/etc/profile.d/conda.sh" >> $HOME/.bashrc \
 && echo "conda activate" >> $HOME/.bashrc

WORKDIR $HOME

# Container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]
