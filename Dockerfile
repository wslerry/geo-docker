FROM python:3.8.17-slim-bullseye

LABEL maintainer="Lerry William Seling"

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install latex
WORKDIR /tmp

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
    && wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz \
    && tar -xzvf install-tl-unx.tar.gz \
    && cd install-tl-* \
    && perl ./install-tl --no-interaction --scheme=basic --no-doc-install --no-src-install \
    && export PATH="/usr/local/texlive/2024/bin/x86_64-linux:$PATH" \
    && tex --version \
    && tlmgr list --only-installed \
    && tlmgr repository add https://mirror.ctan.org/systems/texlive/tlcontrib \
    && tlmgr pinning add tlcontrib "*" \
    && tlmgr update --self \
    # install latex packages for jupyter notebook conversion to pdf
    && tlmgr install xetex adjustbox caption collectbox enumitem \
        environ eurosym etoolbox jknapltx parskip \
        pdfcol pgf rsfs tcolorbox titling trimspaces ucs ulem upquote \
        float fontspec unicode-math fancyvrb booktabs soul \
    && apt clean \
    && apt autoremove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && useradd -m -s /bin/bash geo

# Setup File System
ENV WORKDIR=/notebooks
RUN mkdir -p ${WORKDIR} && mkdir -p /data

# Add Tini
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# Set environment variables
ENV PROJ_DIR=/usr
ENV PROJ_LIBDIR=/usr/lib
ENV PROJ_INCDIR=/usr/include
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal
# Set TeX Live binary path
ENV PATH="/usr/local/texlive/2024/bin/x86_64-linux:$PATH"

# Install pip packages as the 'geo' user
USER geo

ENV PATH=/home/geo/.local/bin:$PATH

# Install pip packages
RUN set -eux && python3 -m pip install --no-cache-dir --upgrade pip \
    && export GDAL_VERSION=$(gdal-config --version) \
    && python3 -m pip install --user --no-cache \
        wheel \
        numpy \
        pandas \
        GDAL==${GDAL_VERSION} \
        scipy \
        fiona \
        pyproj \
        # pygeos \
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
        rioxarray \
    # test installed packages
    && gdalinfo --version \
    && python3 -c "import numpy;print(numpy.__version__)" \
    && python3 -c "from osgeo import gdal;print(gdal.__version__)"

# use root user to clean build packages
USER root
RUN set -eux && apt-get remove -y gcc g++ build-essential \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && chown geo:geo /data

# back to geo user
USER geo
WORKDIR ${WORKDIR}

# Expose JupyterLab port
EXPOSE 8888

ENTRYPOINT ["/tini", "--"]
# Default command to start JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--NotebookApp.token=''", "--NotebookApp.password=''"]
