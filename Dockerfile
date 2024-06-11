FROM python:3.8.17-slim-bullseye

LABEL maintainer="Lerry William Seling"

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and clean up
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        build-essential \
        wget \
        perl \
        tar \
        gzip \
        libgdal-dev \
        libproj-dev \
        libgeos-dev \
        gdal-data \
        gdal-bin \
        pandoc \
    && apt clean \
    && apt autoremove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install latex
WORKDIR /tmp

# Download and extract TeX Live installer
RUN set -eux && wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz \
    && tar -xzvf install-tl-unx.tar.gz \
    && cd install-tl-* \
    && perl ./install-tl --no-interaction --scheme=small --no-doc-install --no-src-install --lang=en

# Set TeX Live binary path
ENV PATH="/usr/local/texlive/2024/bin/x86_64-linux:$PATH"

# Install additional TeX packages using tlmgr
RUN set -eux && tlmgr install adjustbox caption collectbox enumitem environ eurosym etoolbox jknapltx parskip \
    pdfcol pgf rsfs tcolorbox titling trimspaces ucs ulem upquote \
    ltxcmds infwarerr iftex kvoptions kvsetkeys float geometry amsmath fontspec \
    unicode-math fancyvrb grffile hyperref booktabs soul ec \
    && rm -rf /tmp/* \
    && tex --version && tlmgr list --only-installed

# Set environment variables
ENV PROJ_DIR=/usr
ENV PROJ_LIBDIR=/usr/lib
ENV PROJ_INCDIR=/usr/include
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

# Add user 'geo' and set home directory
RUN useradd -m -s /bin/bash geo

# Install pip packages as the 'geo' user
USER geo
WORKDIR /home/geo
ENV PATH=/home/geo/.local/bin:$PATH

# Install pip packages
RUN set -eux && python3 -m pip install --no-cache-dir --upgrade pip
RUN set -eux \
    && export GDAL_VERSION=$(gdal-config --version) \
    && python3 -m pip install --no-cache \
        wheel \
        numpy \
        pandas \
        GDAL==${GDAL_VERSION} \
        scipy \
        fiona \
        pyproj \
        pygeos \
        shapely \
        rtree \
        tqdm \
        geopy \
        matplotlib \
        descartes \
        jupyterlab \
        geopandas \
        geodatasets \
        cartopy \
        folium \
        geemap \
        scikit-learn \
        seaborn \
        rasterio \
        netCDF4 \
        xarray \
        zarr \
        rioxarray

# Test installations
RUN set -eux \
    && gdalinfo --version \
    && python3 -c "import numpy;print(numpy.__version__)" \
    && python3 -c "import pandas;print(pandas.__version__)" \
    && python3 -c "import pyproj;print(pyproj.__version__)" \
    && python3 -c "from osgeo import gdal;print(gdal.__version__)"

# Switch back to root to setup the filesystem and Tini
USER root

# Setup File System
ENV WORKDIR=/notebooks
RUN mkdir -p ${WORKDIR} && mkdir -p /data

# Add Tini
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

# switch to geo to run application
USER geo
WORKDIR ${WORKDIR}

# Expose JupyterLab port
EXPOSE 8888

# Default command to start JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--NotebookApp.token=''", "--NotebookApp.password=''"]
