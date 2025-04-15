from typing import Annotated, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import field_validator
from redis import Redis
from sqlmodel import SQLModel
from app.api.dependencies import authenticated_user
from app.core.config import get_database_client, get_redis_client
from app.api.utils import WalkingDirections, get_septa_data, geolocator, get_walking_directions, get_tree, station_to_geojson
from geopy.distance import geodesic
import numpy as np
from decimal import Decimal

# Define the center of SEPTA service area (Philadelphia City Hall coordinates)
SEPTA_CENTER_LAT = 39.9526
SEPTA_CENTER_LON = -75.1652

# Define maximum service radius in kilometers
# This covers the entire SEPTA Regional Rail network with some buffer
MAX_SERVICE_RADIUS_KM = 80  # SEPTA Regional Rail extends ~40-50 miles from center city


class LocationInput(SQLModel):
    address: Optional[str] = None
    latitude: Decimal = Decimal('0.0')
    longitude: Decimal = Decimal('0.0')
    @field_validator('latitude')
    def validate_latitude(cls, v:Decimal):
        if v is not None and (v < -90.0 or v > 90.0):
            raise ValueError('Latitude must be between -90 and 90')
        return v

    @field_validator('longitude')
    def validate_longitude(cls, v:Decimal):
        if v is not None and (v < -180.0 or v > 180.0):
            raise ValueError('Longitude must be between -180 and 180')
        return v

class StationResponse(SQLModel):
    station_name: str
    distance_km: float
    geojson: dict
    walking_directions: Optional[WalkingDirections]

router = APIRouter(
    prefix="/septa", tags=["septa"], dependencies=[Depends(get_database_client), Depends(get_redis_client), Depends(authenticated_user)]
)

@router.post("/find-nearest-station")
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
    if (location.latitude is None or location.longitude is None) and location.address is None:
        raise HTTPException(status_code=400, detail="Either an address or latitude/longitude must be provided")

    # If address is provided, geocode it
    if location.address:
        geo_result = geolocator.geocode(location.address)
        if geo_result:
            location.latitude = geo_result.latitude # type: ignore
            location.longitude = geo_result.longitude # type: ignore
        else:
            raise HTTPException(status_code=400, detail="Could not geocode the provided address")

    # Check if location is within service area
    distance_to_center = geodesic(
        (location.latitude, location.longitude),
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
    cache_key = f"septa_nearest_station_{location.latitude}_{location.longitude}"
    cached_result = redis.get(cache_key)
    if cached_result:
        return cached_result

    # Find nearest station
    user_location = np.array([[location.latitude, location.longitude]])
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
        location.latitude, location.longitude,
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

    redis.set(cache_key, response.model_dump_json())
    return response
