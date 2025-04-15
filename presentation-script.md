# Gisual Power Outage Intelligence Search API Presentation Script

## Introduction (30 seconds)

Hello everyone! I'm [Your Name] from Gisual, and today I'm excited to introduce you to our Power Outage Intelligence Search API. This presentation is designed for those who are new to Gisual and want to understand what our solution offers and how to integrate with our API.

## What is Gisual? (1 minute)

Gisual is a specialized intelligence platform focused on power outage monitoring, analysis, and prediction. Our platform aggregates, processes, and analyzes power outage data from various utilities across the United States, providing real-time and historical insights into power outage events.

Our Power Outage Intelligence Search API is designed to help developers, data analysts, and organizations easily access and utilize this valuable data for their specific use cases.

## Why Use Gisual's Power Outage Intelligence Search API? (1 minute)

- **Comprehensive Coverage**: Access power outage data from utilities across the entire United States
- **Real-time Updates**: Get the latest outage information as it happens
- **Historical Analysis**: Query historical outage data for trend analysis and planning
- **Geospatial Capabilities**: Filter and analyze outages by various geographic parameters
- **Customizable Queries**: Build specific queries to match your exact data needs
- **Reliable Infrastructure**: High-availability API designed for mission-critical applications

## API Overview (2 minutes)

The Gisual Power Outage Intelligence Search API is a RESTful API that allows you to:

1. **Search for outages** based on multiple parameters including:
   - Geographic location (state, county, city, zip code)
   - Time range (current outages or historical data)
   - Utility provider
   - Outage severity

2. **Retrieve detailed information** about specific outage events including:
   - Number of customers affected
   - Outage start and estimated restoration times
   - Cause of outage (when available)
   - Geographic impact boundaries

3. **Access aggregated statistics** such as:
   - Total outages by region
   - Average outage duration
   - Frequency of outages by utility

## Getting Started with the API (2 minutes)

### Authentication

To use our API, you'll need an API key. Here's how to get started:

1. Create a Gisual account at our developer portal
2. Generate an API key from your dashboard
3. Include this key in the header of every API request:

```
Authorization: Bearer YOUR_API_KEY
```

### Basic Request Structure

Our API uses standard HTTPS requests. The base URL for all API calls is:

```
https://api.gisual.com/v1/outages
```

A typical GET request might look like this:

```
GET https://api.gisual.com/v1/outages?state=CA&start_date=2023-06-01T00:00:00Z&end_date=2023-06-02T00:00:00Z
```

### Response Format

All responses are returned in JSON format. Here's a simplified example response:

```json
{
  "meta": {
    "total_results": 25,
    "page": 1,
    "per_page": 10
  },
  "outages": [
    {
      "id": "out-12345",
      "utility": "Pacific Gas & Electric",
      "state": "CA",
      "county": "Alameda",
      "affected_customers": 1500,
      "start_time": "2023-06-01T14:30:00Z",
      "estimated_restoration": "2023-06-01T18:45:00Z",
      "status": "active",
      "cause": "equipment failure"
    },
    // Additional outage objects...
  ]
}
```

## Common API Endpoints (1.5 minutes)

### Current Outages

```
GET /outages/current
```
Returns all active outages across the country.

### Outages by Location

```
GET /outages?state=FL
```
Returns outages filtered by state (can also filter by county, city, zip).

### Historical Outages

```
GET /outages/historical?start_date=2023-01-01&end_date=2023-01-31
```
Returns outages within a specific date range.

### Outage Details

```
GET /outages/{outage_id}
```
Returns detailed information about a specific outage event.

## Best Practices & Common Issues (2 minutes)

### Rate Limiting

Our API implements rate limiting to ensure fair usage. Standard plans allow:
- 60 requests per minute
- 10,000 requests per day

If you exceed these limits, you'll receive a `429 Too Many Requests` response. Implement exponential backoff in your code to handle rate limiting gracefully.

### Common Issues and Solutions

1. **Authentication Errors**
   - Ensure your API key is valid and properly included in request headers
   - Check that your subscription is active

2. **Invalid Parameters**
   - Verify date formats (we use ISO 8601: YYYY-MM-DDTHH:MM:SSZ)
   - Ensure state codes are valid two-letter abbreviations

3. **Large Result Sets**
   - Use pagination parameters (page, per_page) for large queries
   - Consider narrowing your search criteria for more focused results

4. **Data Latency**
   - Remember that outage data depends on utility reporting
   - Some utilities may have a delay of 5-15 minutes in reporting updates

### Error Handling

Implement proper error handling in your code. Our API returns standard HTTP status codes:
- 200: Success
- 400: Bad Request (check your parameters)
- 401: Unauthorized (check your API key)
- 404: Not Found (resource doesn't exist)
- 429: Too Many Requests (you've hit rate limits)
- 500: Server Error (please contact support)

## Integration Examples (1.5 minutes)

### Python Example

```python
import requests

api_key = "YOUR_API_KEY"
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

# Get current outages in California
response = requests.get(
    "https://api.gisual.com/v1/outages/current",
    headers=headers,
    params={"state": "CA"}
)

if response.status_code == 200:
    outages = response.json()
    print(f"Found {outages['meta']['total_results']} outages in California")
    for outage in outages['outages']:
        print(f"Utility: {outage['utility']}")
        print(f"Affected customers: {outage['affected_customers']}")
        print(f"Start time: {outage['start_time']}")
        print("---")
else:
    print(f"Error: {response.status_code} - {response.text}")
```

### JavaScript Example

```javascript
async function getCurrentOutages(state) {
  try {
    const response = await fetch(
      `https://api.gisual.com/v1/outages/current?state=${state}`,
      {
        headers: {
          'Authorization': 'Bearer YOUR_API_KEY',
          'Content-Type': 'application/json'
        }
      }
    );
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching outage data:', error);
  }
}

// Usage
getCurrentOutages('TX')
  .then(data => {
    console.log(`Found ${data.meta.total_results} outages in Texas`);
    data.outages.forEach(outage => {
      console.log(`${outage.utility}: ${outage.affected_customers} customers affected`);
    });
  });
```

## Conclusion & Next Steps (1 minute)

In this presentation, we've covered:
- What Gisual's Power Outage Intelligence Search API is
- How to authenticate and make requests
- Common endpoints and response formats
- Best practices and potential issues
- Integration examples

For next steps:
1. Visit our developer portal at developer.gisual.com to create an account
2. Check out our comprehensive API documentation
3. Try our interactive API explorer to test queries
4. Reach out to our support team if you have any questions at support@gisual.com

Thank you for your interest in Gisual's Power Outage Intelligence Search API! We're excited to see what you'll build with our data.