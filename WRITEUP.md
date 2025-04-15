# SEPTA Station Finder API Writeup

### Development Approach

The project was developed between dates of April 7-15, 2025 with a
focus on creating a highly scalable and
maintainable API. My approach centered around API-First Design,
focusing on user experience and data format standardization while ensuring
comprehensive documentation.

I made progressive enhancements throughout my development, adding the
core functionality first before incorporating performance optimizations
and other improvements like caching. Containerization with Docker was embraced
from day one to ensure consistent environments, while multi-stage builds
enabled optimization of my deployment artifacts.

### Technical Architecture Decisions

**FastAPI Framework Selection**

I used the FastAPI framework for its type annotations,
integrated OpenAPI support, and high-performance request handling.
These features aligned with my needs as a developer, but also
ensured I could create a robust and scalable API for the project's requirements.

**Database ORM (SQLModel)**

I chose SQLModel for its support for asynchronous database operations and
seamless integration with SQLAlchemy's powerful ORM features. This combination
gave me both the performance benefits and the productivity of a mature ORM.

**Geospatial Processing**

My geospatial strategy centers around the BallTree implementation from the scikit-learn package.
My implementation provides a space-time complexity of O(log n) for nearest-neighbor searches.
This is complemented using the Haversine distance metric for spherical distance
calculations and efficient data structure pre-computation. Together, my
implementation ensures optimal performance for location-based queries.

GeoPandas and Geopy are the packages I choose for spatial data operations, enabling complex
geospatial analyses beyond simple distance calculations. Additionally, I integrated
the OpenStreetMap Routing Machine (OSRM) to generate detailed walking directions
from the user's location to the nearest SEPTA station, enhancing the user
experience with practical navigation guidance.

**Caching Architecture**

The caching system uses coordinate-based keys for location-aware cache management,
enabling efficient spatial lookups. Request deduplication prevents redundant processing of
identical location queries, significantly reducing computational load during peak
usage periods. My asynchronous Redis implementation provides
high-performance caching, ensuring the application remains responsive
despite high load while minimizing redundant geospatial calculations.

**Security Features**

The application implements comprehensive security features to protect user data
and prevent abuse. All user passwords are securely hashed using bcrypt,
ensuring that even if database contents are exposed, passwords remain protected.
API access is secured through JWT-based authentication, providing a stateless
authentication mechanism with configurable expiration times to limit the impact
of token compromise.

A rate-limiting system based on the SlowAPI package prevents API abuse and potential
denial-of-service attacks by limiting request frequency from individual clients.
The system enforces a global rate limit of 60 requests per minute by default,
using client IP addresses as identifiers.

**Production Deployment Addition**

I utilized Terraform to manage infrastructure as code, ensuring consistent and
reproducible deployments on AWS. I decided to choose Fargate Spot instances
for non-critical workloads, taking advantage of reduced pricing while maintaining
functionality.

Where applicable, services are configured to make optimal use of AWS Free Tier
offerings, minimizing costs during the development and testing phases. For predictable
workloads, I implement a reserved instances strategy for Redis and RDS databases,
providing significant cost savings compared to on-demand pricing.


### Metrics and Monitoring

While the instructions for the coding challenge did not explicitly include
metrics and monitoring, I am outlining what I would have built if I were to implement
a comprehensive system to track both operational performance and customer satisfaction
without impacting response times.

This proposal implementation leverages Prometheus for efficient metrics collection
and asynchronous processing to ensure minimal performance impact.

For operational monitoring, I would track request latency, throughput, error rates, and
cache hit ratio to ensure the system functions efficiently. These metrics provide
immediate insight into system health and help identify bottlenecks or service degradation.

```python
# Non-blocking metrics collection via FastAPI middleware
from fastapi import FastAPI, Request
import time
from prometheus_client import Counter, Histogram

REQUEST_LATENCY = Histogram('request_latency_seconds', 'Request latency', ['endpoint'])
REQUEST_COUNT = Counter('request_count', 'Request count', ['endpoint', 'status_code'])

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    REQUEST_LATENCY.labels(endpoint=request.url.path).observe(time.time() - start_time)
    REQUEST_COUNT.labels(endpoint=request.url.path, status_code=response.status_code).inc()
    return response
```

I would measure satisfaction by analyzing the time to first station result,
geocoding success rate, walking directions provided, and patterns of repeated
searches within sessions to help assess the user experience and identify pain points.

```python
# Endpoint instrumentation for customer satisfaction metrics
@router.post("/find-nearest-station")
async def find_nearest_station(location: LocationInput, redis: Redis = Depends(get_redis_client)):
    geocoding_start = time.time()
    If location.address:
        geo_result = geolocator.geocode(location.address)
        GEOCODING_TIME.observe(time.time() - geocoding_start)
        geo_result and GEOCODING_SUCCESS.inc() or GEOCODING_FAILURE.inc()

    # Track cache performance213
    cache_key = f"septa_nearest_station_{location.latitude}_{location.longitude}"
    redis.get(cache_key) and CACHE_HITS.inc() or CACHE_MISSES.inc()
```


Beyond the API itself, I monitor critical external dependencies through background tasks
that collects metrics without impacting request handling.

Key external metrics include: OSRM service for walking directions, database health,
Redis memory usage, and network performance.

```python
# Background task for monitoring external dependencies
@asynccontextmanager
async def lifespan(app_: FastAPI):
    monitoring_task = asyncio.create_task(collect_external_metrics())
    yield
    monitoring_task.cancel()

async def collect_external_metrics():
    while True:
        # Monitor OSRM service
        Async with httpx.AsyncClient() as client:
            try:
                response = await client.get("http://router.project-osrm.org/health")
                OSRM_AVAILABILITY.set(response.status_code == 200 and 1 or 0)
            except Exception:
                OSRM_AVAILABILITY.set(0)

        # Monitor Redis and DB health
        REDIS_MEMORY_USED.set(redis_client.info()['used_memory'])
        DB_CONNECTIONS.set(len(await db_pool.get_connections()))

        await asyncio.sleep(60)  # Check every minute
```


## Conclusion

The SEPTA Station Finder API demonstrates a modern approach to geospatial web
service development. By utilizing BallTree algorithms and proper distance
metrics, the application provides a fast and accurate nearest-station search API that scales.

My containerized approach with infrastructure-as-code supports modern CI/CD
pipelines and cloud deployment scenarios, while performance optimizations ensure efficient operation benefits.
The project successfully balances development speed, code quality, and performance
considerations, creating a maintainable and extensible system that provides
