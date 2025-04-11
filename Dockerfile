# Build stage
FROM python:3.8.17-slim-bullseye AS builder

LABEL maintainer="Lerry William Seling"

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp

# Install build dependencies and LaTeX
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    && export PATH="/usr/local/texlive/2025/bin/x86_64-linux:$PATH" \
    && tlmgr list --only-installed \
    && tlmgr repository add https://mirror.ctan.org/systems/texlive/tlcontrib \
    && tlmgr pinning add tlcontrib "*" \
    && tlmgr update --self \
    && tlmgr install xetex adjustbox caption collectbox enumitem \
        environ eurosym etoolbox jknapltx parskip \
        pdfcol pgf rsfs tcolorbox titling trimspaces ucs ulem upquote \
        float fontspec unicode-math fancyvrb booktabs soul \
    && rm -rf install-tl-unx.tar.gz install-tl-*

# Create a build user to avoid permission issues
RUN useradd -m -s /bin/bash builduser
USER builduser
ENV PATH="/home/builduser/.local/bin:$PATH"

# Install Python packages
RUN python3 -m pip install --no-cache-dir --upgrade pip \
    && export GDAL_VERSION=$(gdal-config --version) \
    && python3 -m pip install --user --no-cache \
        wheel \
        numpy \
        pandas \
        GDAL==${GDAL_VERSION} \
        scipy \
        fiona \
        pyproj \
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

# Final stage
FROM python:3.8.17-slim-bullseye

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgdal-dev \
        libproj-dev \
        libgeos-dev \
        gdal-data \
        gdal-bin \
        pandoc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy TeX Live from builder
COPY --from=builder /usr/local/texlive /usr/local/texlive

# Copy Python packages from builder
COPY --from=builder /home/builduser/.local /home/geo/.local

# Add Tini
ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# Create user and setup filesystem
RUN useradd -m -s /bin/bash geo \
    && mkdir -p /notebooks /data \
    && chown geo:geo /data /notebooks

# Set environment variables
ENV WORKDIR=/notebooks
ENV PROJ_DIR=/usr
ENV PROJ_LIBDIR=/usr/lib
ENV PROJ_INCDIR=/usr/include
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal
ENV PATH="/usr/local/texlive/2025/bin/x86_64-linux:/home/geo/.local/bin:$PATH"

USER geo
WORKDIR /notebooks

# Expose JupyterLab port
EXPOSE 8888

ENTRYPOINT ["/tini", "--"]
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--NotebookApp.token=''", "--NotebookApp.password=''"]