from typing import Dict, Optional
import requests
import geopandas as gpd
from geopandas import GeoDataFrame
import numpy as np
from sklearn.neighbors import BallTree
from sqlmodel import SQLModel
import geopy.geocoders
from geopy.geocoders import Nominatim
from decimal import Decimal

# GEOPY Nominatim Docs: https://geopy.readthedocs.io/en/stable/#geopy.geocoders.options.default_timeout
geopy.geocoders.options.default_user_agent = 'SEPTA_Station_Finder_API'
geopy.geocoders.options.default_timeout = 10
geolocator = Nominatim()
_data :Dict[str, GeoDataFrame] = {}  # Use private variable
_tree: BallTree = None  # Use private variable

def get_tree() -> BallTree:
    """Get the current BallTree instance"""
    return _tree

def get_septa_data() -> GeoDataFrame:
    """Get the current BallTree instance"""
    return _data['septa_data']

async def load_septa_data():
    global _tree  # Ensure we're using the global tree variable
    _data['septa_data'] = gpd.read_file('data/SEPTARegionalRailStations2016/doc.kml', driver='KML')
    # Extract the coordinates for use in BallTree

    coords = np.degrees(np.vstack([
        _data['septa_data'].geometry.y.to_numpy(),
        _data['septa_data'].geometry.x.to_numpy()
    ]).T)

    # Update the global tree variable
    _tree = BallTree(np.radians(coords), metric='haversine')


async def delete_septa_data():
    global _tree
    _data.clear()
    _tree = None  # Better than del which might raise an error if _tree is already None
    print("SEPTA data and tree cleared")

class WalkingDirections(SQLModel):
    distance: Decimal
    duration: Decimal
    steps: list

def get_walking_directions(start_lat: Decimal, start_lon: Decimal, end_lat: Decimal, end_lon: Decimal):
    """Get walking directions using OpenStreetMap Routing Machine (OSRM)"""

    url = f"http://router.project-osrm.org/route/v1/foot/{start_lon},{start_lat};{end_lon},{end_lat}?steps=true"

    try:
        response = requests.get(url)
        data = response.json()
        if data["code"] != "Ok":
            return None
        route = data["routes"][0]
        # Process steps for readable directions
        steps = []
        for leg in route["legs"]:
            for step in leg["steps"]:
                if step['name'] == '':
                    step['name'] = 'continue'

                steps.append({"instruction": step['name'], "distance_meters": step['distance']})

        return WalkingDirections(
            distance=round(route["distance"] / 1000, 2),  # Convert to km
            duration=round(route["duration"] / 60, 1),    # Convert to minutes
            steps=steps
        )
    except Exception as e:
        print(f"Error fetching walking directions: {e}")
        return None


def station_to_geojson(station_series):
    """Convert a GeoDataFrame row to GeoJSON format"""
    # Extract all non-geometry properties
    properties = {col: station_series[col] for col in station_series.index if col != 'geometry'}

    # Create GeoJSON feature
    geojson = {
        "type": "Feature",
        "geometry": {
            "type": "Point",
            "coordinates": [
                station_series.geometry.x,
                station_series.geometry.y
            ]
        },
        "properties": properties
    }

    return geojson
