from typing import Annotated, Optional
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from pydantic import field_validator
from redis import Redis
from sqlmodel import SQLModel
from app.api.dependencies import authenticated_user
from app.core.config import get_database_client, get_redis_client
from app.api.utils import WalkingDirections, get_septa_data, geolocator, get_walking_directions, get_tree, station_to_geojson
from geopandas import GeoDataFrame
from geopy.distance import geodesic
import numpy as np
from decimal import Decimal
from typing import Any
from json import loads

# Define the center of SEPTA service area (Philadelphia City Hall coordinates)
SEPTA_CENTER_LAT = 39.9526
SEPTA_CENTER_LON = -75.1652

# Define maximum service radius in kilometers
# This covers the entire SEPTA Regional Rail network with some buffer
MAX_SERVICE_RADIUS_KM = 80  # SEPTA Regional Rail extends ~40-50 miles from center city


class LocationInput(SQLModel):
    address: str = "1400 John F Kennedy Blvd Philadelphia PA 19107"

class StationResponse(SQLModel):
    station_name: str
    distance_km: Decimal
    geojson: Any
    walking_directions: Optional[WalkingDirections]

router = APIRouter(
    prefix="/septa", tags=["septa"], dependencies=[Depends(get_database_client), Depends(get_redis_client), Depends(authenticated_user)]
)

@router.post("/find-nearest-station", response_model=StationResponse)
async def find_nearest_station(location: LocationInput, redis: Annotated[Redis, Depends(get_redis_client)]):
    """
    Find the nearest SEPTA train station to a given location.

    This endpoint accepts either geographic coordinates (latitude/longitude) or a text address,
    then determines the closest SEPTA Regional Rail station to that location. Results are cached
    in Redis for improved performance on subsequent identical requests.

    Parameters:
    - location: LocationInput object containing either address or lat/long coordinates
    - redis: Redis client (automatically injected)

    Returns:
    - StationResponse: Information about the nearest station including:
      - station_name: Name of the SEPTA station
      - distance_km: Distance to the station in kilometers
      - geojson: GeoJSON representation of the station
      - walking_directions: Step-by-step walking directions to the station

    Raises:
    - 400 Error: If neither address nor coordinates are provided, or if address cannot be geocoded
    """

    # Input validation

    geo_result = geolocator.geocode(location.address)
    if not geo_result:
        raise HTTPException(status_code=400, detail="Could not geocode the provided address")

    latitude = geo_result.latitude # type: ignore
    longitude = geo_result.longitude # type: ignore

    # Check if location is within service area
    distance_to_center = geodesic(
        (latitude, longitude),
        (SEPTA_CENTER_LAT, SEPTA_CENTER_LON)
    ).kilometers

    if distance_to_center > MAX_SERVICE_RADIUS_KM:
        raise HTTPException(
            status_code=422,
            detail={
                "message": "Location is outside of SEPTA's service area",
                "distance_km": round(distance_to_center, 2),
                "max_service_radius_km": MAX_SERVICE_RADIUS_KM,
                "service_center": {
                    "latitude": SEPTA_CENTER_LAT,
                    "longitude": SEPTA_CENTER_LON,
                    "name": "Philadelphia, PA"
                }
            }
        )

    # Check if result is cached in Redis
    cache_key = f"septa_nearest_station_{latitude}_{longitude}"
    cached_result = redis.get(cache_key)
    if cached_result:
        # Parse the JSON string from Redis to a Python object
        print('Your location', [latitude, longitude])
        response = StationResponse.model_validate(loads(cached_result)) # type: ignore
        print('Nearest Station', response.geojson['geometry']['coordinates'])
        return response

    # Find nearest station
    user_location = np.array([[latitude, longitude]])
    user_location_rad = np.radians(user_location)

    # Query the tree for the nearest station
    tree = get_tree()
    distances, indices = tree.query(user_location_rad, k=1)

    # Convert distance from radians to kilometers (Earth radius ≈ 6371 km)
    distance_km = distances[0][0] * 6371.0
    nearest_idx = indices[0][0]

    # Get the nearest station from GeoDataFrame
    septa_data = get_septa_data()
    nearest_station = septa_data.iloc[nearest_idx]

    # Get walking directions
    walking_directions = get_walking_directions(
        latitude, longitude,
        nearest_station.geometry.y, nearest_station.geometry.x
    )

    # Convert station to GeoJSON
    station_geojson = station_to_geojson(nearest_station)

    # Get station name (adjust field name based on your KML structure)
    station_name = nearest_station.get('Name', nearest_station.get('name', f"Station {nearest_idx}"))

    response = StationResponse(
        station_name=station_name,
        distance_km=round(distance_km, 2),
        geojson=station_geojson,
        walking_directions=walking_directions
    )
    print('Your location', [latitude, longitude])
    print('Nearest Station', [nearest_station.geometry.y, nearest_station.geometry.x])

    redis.set(cache_key, response.model_dump_json())
    return response
