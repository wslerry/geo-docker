FROM python:3.8.17-slim-bullseye

LABEL maintainer="Lerry William Seling"

#install dependancies
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        pandoc \
        texlive-xetex \
        texlive-fonts-recommended \
        texlive-latex-recommended \
        texlive-plain-generic \
        cm-super \
        gdal-data \
        gdal-bin \
        libgdal-dev \
        libproj-dev \
        libgeos-dev \
        imagemagick \
    # fix the access rights for imagemagick
    && echo "Fixing access rights for imagemagick." \
    && sed -i -e 's/rights="none"/rights="read|write"/g' /etc/ImageMagick-6/policy.xml \
    && sed -i -e 's/<\/policymap>/<policy domain="module" rights="read|write" pattern="{PS,PDF,XPS}" \/>\n<\/policymap>/g' /etc/ImageMagick-6/policy.xml \
    && echo "Performing cleanup." \
    && apt-get clean -y \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/ssh/ssh_host_*

ENV PROJ_DIR=/usr
ENV PROJ_LIBDIR=/usr/lib
ENV PROJ_INCDIR=/usr/include
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal
ENV PATH=${PATH}:/usr/bin/pandoc


# install python package for geospatial analysis
RUN set -eux \
    && python3 -m ensurepip \
    && pip3 install --no-cache numpy pandas \
    && export GDAL_VERSION=$(gdal-config --version); echo ${GDAL_VERSION} \
    && pip3 install --no-cache GDAL==${GDAL_VERSION} \
    && pip3 install --no-cache \
        scipy \
        fiona \
        pyproj \
        shapely \
        rtree \
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
    && pip3 install --no-cache \
        rasterio \
        netCDF4 \
        xarray \
        zarr \
        rioxarray

# last final test
RUN set -eux \
    && gdalinfo --version \
    && pandoc --version \
    && python3 -c "import numpy;print(numpy.__version__)" \
    && python3 -c "import pandas;print(pandas.__version__)" \
    && python3 -c "import pyproj;print(pyproj.__version__)" \
    && python3 -c "from osgeo import gdal;print(gdal.__version__)"

## Setup File System
ENV WORKDIR=/opt/notebooks
RUN mkdir ${WORKDIR}
ENV HOME=${WORKDIR}
ENV SHELL=/bin/bash
VOLUME ${WORKDIR}
WORKDIR ${WORKDIR}

EXPOSE 8888

# Add Tini
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

# this for docker. 
CMD ["jupyter", "lab", "--ip=0.0.0.0","--NotebookApp.token=''","--NotebookApp.password=''","--allow-root"]