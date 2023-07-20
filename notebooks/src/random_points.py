import sys
import pathlib
import geopandas as gpd
import numpy as np
from shapely.geometry import Point
import matplotlib.pyplot as plt
from tqdm.notebook import tqdm


class RandomPointsInBounds:
    def __init__(self, input_polygon=None, input_layer_name=None, output_polygon=None, 
                 output_layer_name=None, n_points=None, minimum_distance=None):
        self.infile = input_polygon
        self.inname = input_layer_name
        self.outfile = output_polygon
        self.outname = output_layer_name
        self.num = n_points
        self.mindist = minimum_distance

        infile_ext = pathlib.Path(self.infile).suffix
        self.outfile_ext = pathlib.Path(self.outfile).suffix
        
        if infile_ext == '.gpkg':
            self.polygon = gpd.read_file(self.infile, layer=self.inname)
        else:
            self.polygon = gpd.read_file(self.infile)
        try:
            pts = self.generate_random(self.polygon, self.num, self.mindist)
            self.pts = pts.set_crs(epsg=self.polygon.crs.to_epsg(), inplace=True)
        except Exception as e:
            sys.exit(f"[ERROR]\tSeems you are facing some difficulties...\n{e}\nsystem exit...")
        except KeyboardInterrupt:
            sys.exit("Canceled, system exit...")

    def generate_random(self, polygon, n_points, min_distance):
        """
        Generate random point within polygon.
        """ 
        minx = polygon.bounds.minx
        miny = polygon.bounds.miny
        maxx = polygon.bounds.maxx
        maxy = polygon.bounds.maxy
        
        points = []
        pbar = tqdm(total=n_points)
        while len(points) < n_points:
            random_point = Point(np.random.uniform(minx, maxx), np.random.uniform(miny, maxy))
            if random_point.within(polygon.geometry[0]):
                if all(random_point.distance(point) >= min_distance for point in points):
                    points.append(random_point)
                    pbar.update(1)
        pbar.close()
        
        return gpd.GeoSeries(points)

    def plot(self):
        base = self.polygon.boundary.plot(linewidth=1, edgecolor="black")
        self.pts.plot(ax=base, linewidth=1, color="red", markersize=1)
        plt.show()

        return

    def save(self):
        # print("[INFO]\tSaving random point")
        msg = f"Save as {self.outfile}"
        if self.outfile_ext == '.gpkg':
            layername=f'random_{self.num}' if self.outname is None else self.outname
            self.pts.to_file(self.outfile, layer=layername, driver='GPKG')
            print(msg + f" || layername={layername}")
        elif self.outfile_ext == '.shp':
            self.pts.to_file(self.outfile)
            print(msg)
        elif self.outfile_ext == '.geojson':
            self.pts.to_file(self.outfile, driver='GeoJSON')
            print(msg)
        else:
            print(f"[WARNING]\tFile extension not supported")
            pass
        return