# Build as jupyterhub/singleuser
# Run with the DockerSpawner in JupyterHub

FROM jupyter/scipy-notebook

# no need for singleuser Dockerfile anymore,
# all scripts have been ported to jupyter/base-notebook docker image

USER root

RUN apt-get update \
    && apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o DPkg::Options::="--force-confold" \
    && apt-get install -y \
    curl \
    libzmq3-dev \
    hdf5-tools \
    gettext \
    pdf2svg \
    libpangocairo-1.0 \
    octave \
    texlive-luatex \
    g++

RUN conda install -y conda-build jupyterlab rise nodejs && conda build purge-all && fix-permissions $CONDA_DIR

RUN jupyter serverextension enable jupyterlab --py --sys-prefix

USER root

# Extra latex packages
RUN apt-get update \
    && apt-get install -y \
    texlive-science

USER $NB_USER

RUN mkdir /home/$NB_USER/work/coursefiles

ENV NOTEBOOK_DIR="/home/${NB_USER}/work"

############# Julia 1.6 #####################
USER root
RUN rm -rf /opt/julia-1.6

RUN mkdir -p /opt/julia-1.6 && \
    curl -s -L https://julialang-s3.julialang.org/bin/linux/x64/1.6/julia-1.6.0-linux-x86_64.tar.gz | tar -C /opt/julia-1.6 -x -z --strip-components=1 -f -

COPY install-packages.jl /opt/julia-1.6/
COPY sysimage-precompile.jl /opt/julia-1.6/

USER $NB_USER

ENV JULIA_DEPOT_PATH="/home/${NB_USER}/.julia"
ENV JULIA_DEFAULT_ENV="${JULIA_DEPOT_PATH}/environments/v1.6"

RUN mkdir -p $JULIA_DEFAULT_ENV

COPY Project.toml $JULIA_DEFAULT_ENV
COPY Manifest.toml $JULIA_DEFAULT_ENV

USER root
RUN chown -R $NB_USER $JULIA_DEFAULT_ENV /opt/julia-1.6
USER $NB_USER

RUN /opt/julia-1.6/bin/julia --threads 80 /opt/julia-1.6/install-packages.jl
RUN /opt/julia-1.6/bin/julia -e "using WebIO; WebIO.install_jupyter_serverextension()"

RUN /opt/julia-1.6/bin/julia -e "using Pkg; Pkg.build(\"IJulia\")"
RUN /opt/julia-1.6/bin/julia -e 'using PackageCompiler; create_sysimage([:Archimedes, :Plots, :Luxor, :NLsolve, :Unitful, :CoolProp, :BoundaryValueDiffEq, :PGFPlotsX, :LaTeXStrings, :TikzPictures, :IJulia, :Pluto]; precompile_statements_file="/opt/julia-1.6/sysimage-precompile.jl", replace_default=true)'

RUN mkdir -p $JULIA_DEPOT_PATH/config
COPY startup.jl $JULIA_DEPOT_PATH/config

ENV JULIA_DEPOT_PATH="${NOTEBOOK_DIR}/.julia_depot:${JULIA_DEPOT_PATH}"
RUN /opt/julia-1.6/bin/julia -e "using Pkg; Pkg.status(); display(DEPOT_PATH)"

RUN echo "c.MappingKernelManager.cull_idle_timeout = 1800" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py
RUN echo "c.NotebookApp.shutdown_no_activity_timeout = 1800" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py

RUN git clone https://github.com/pankgeorg/pluto-on-jupyterlab.git; \
    pushd pluto-on-jupyterlab; \
    pip3 install .; \
    sed 's!julia!/opt/julia-1.6/bin/julia!' runpluto.sh | sed 's!import Pluto;!cd(joinpath(ENV[\\"HOME\\"], \\"work\\"));\nimport Pluto;!' > ../runpluto.sh; \
    popd; \
    rm -rf pluto-on-jupyterlab; \
    echo PATH=/opt/julia-1.6/bin:$PATH >> .profile;

RUN jupyter labextension install @jupyterlab/server-proxy
RUN jupyter lab build

# smoke test that it's importable at least
RUN bash /usr/local/bin/start-singleuser.sh -h
CMD ["bash", "/usr/local/bin/start-singleuser.sh"]
