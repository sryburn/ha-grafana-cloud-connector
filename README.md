# Grafana Cloud Connector

A Home Assistant addon that uses official Grafana Alloy component to forward your Prometheus metrics to Grafana Cloud. 

## Installation

### Automatic

1. Add the repository.

   [![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fsryburn%2Fha-grafana-cloud-connector)

### Manual

1. Open the Add-ons panel in Home Assistant by going to `Settings-->Add-ons-->Add-on Store`.
1. Click the menu icon in the top-right, then click "Repositories".
1. Add this URL `https://github.com/sryburn/ha-grafana-cloud-connector`

## Prerequisites

### Configure Prometheus in Home Assistant

Add [Prometheus](https://www.home-assistant.io/integrations/prometheus/) to your `configuration.yaml`, for example:

```yaml
prometheus:
  # Optional: disable authentication (alternatively a long-lived access token is required)
  requires_auth: false

  # Optional: configure which entities to export
  filter:
    include_entities:
      - sensor.temperature_living_room
      - sensor.humidity_bedroom
      # Add your entities here
```
Restart Home Assistant.

## Getting Grafana Cloud Credentials

1. **Log into [Grafana Cloud](https://grafana.com)**
2. **Navigate to**: Connections → Collector → Configure
3. **Create an access token**
4. **Copy these values** from the generated install command:
   - `GCLOUD_HOSTED_METRICS_URL` → `grafana_cloud_url`
   - `GCLOUD_HOSTED_METRICS_ID` → `grafana_cloud_username`
   - `GCLOUD_RW_API_KEY` → `grafana_cloud_password`

## Getting a long-lived access token
1. Click on your Home Assistant user profile, then  **Security → Long-lived access tokens**
2. Click **Create Token**
3. Give it a name like "Grafana Cloud Connector"
4. Copy the token and enter it in the `ha_access_token` field

## Configuration

### Required Settings

| Option | Description | Example |
|--------|-------------|---------|
| `grafana_cloud_url` | Your Grafana Cloud remote write URL | `https://prometheus-prod-13-prod-us-east-0.grafana.net/api/prom/push` |
| `grafana_cloud_username` | Your Grafana Cloud metrics ID | `1234567` |
| `grafana_cloud_password` | Your Grafana Cloud API key | `glc_eyJ...` |

### Optional Settings

| Option | Description | Default |
|--------|-------------|---------|
| `ha_access_token` | Home Assistant token (only if auth enabled) | `"ey..."` |
| `scrape_interval` | How often to scrape metrics | `60s` |
| `enable_self_monitoring` | Include Alloy's own metrics | `true` |
| `log_level` | Logging level | `info` |

## Usage

1. **Configure the addon** with your Grafana Cloud credentials
2. **Start the addon**
3. **In Grafana Cloud**: Go back to Connections → Collector → Configure
4. **Click "Test Alloy connection"** to verify everything is working
5. **Access Web UI** at `http://your-ha-ip:12345` to monitor scrape status

## Viewing Your Data

Once connected, your Home Assistant metrics will be available in Grafana Cloud:

1. **Go to**: Connections → Data Sources → `grafanacloud-[username]-prom` → Explore
2. **Search for**: `homeassistant_` (all HA metrics are prefixed with this)
3. **Try these example queries**:
   ```promql
   # All Home Assistant metrics
   {__name__=~"homeassistant_.*"}

   # Temperature sensors
   homeassistant_sensor_temperature_celsius

   # Entity availability
   homeassistant_entity_available
   ```

## Troubleshooting

### Connection Issues

**"Authentication failed" errors:**
- **If using tokens**: Check your Home Assistant long-lived access token is correct
- **If no auth**: Ensure `prometheus: requires_auth: false` is in your `configuration.yaml`

**"Grafana Cloud authentication error":**
- Verify your Grafana Cloud credentials from the install command
- API key should start with `glc_`
- Ensure the URL matches exactly (including region)

**No metrics appearing in Grafana Cloud:**
1. **Check addon logs** for errors
2. **Visit Alloy Web UI** at `http://your-ha-ip:12345`:
   - `prometheus.scrape.home_assistant` should show "Health: up"
   - Check recent scrape times and sample counts
3. **In Grafana Cloud**: Use "Test Alloy connection" button
4. **Verify HA Prometheus** is enabled in your `configuration.yaml`