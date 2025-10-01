#!/usr/bin/env bashio

# Get configuration from Home Assistant
GRAFANA_CLOUD_URL=$(bashio::config 'grafana_cloud_url')
GRAFANA_CLOUD_USERNAME=$(bashio::config 'grafana_cloud_username')
GRAFANA_CLOUD_PASSWORD=$(bashio::config 'grafana_cloud_password')
HA_URL=$(bashio::config 'ha_url')
HA_ACCESS_TOKEN=$(bashio::config 'ha_access_token')
SCRAPE_INTERVAL=$(bashio::config 'scrape_interval')
ENABLE_SELF_MONITORING=$(bashio::config 'enable_self_monitoring')
LOG_LEVEL=$(bashio::config 'log_level')

# Discover Home Assistant host and port dynamically
CORE_INFO=$(curl -s -H "Authorization: Bearer $SUPERVISOR_TOKEN" "http://supervisor/core/info")
if [ $? -eq 0 ] && [ -n "$CORE_INFO" ]; then
    # Extract IP and port from core info
    HA_HOST=$(echo "$CORE_INFO" | grep -o '"ip_address":"[^"]*' | cut -d'"' -f4)
    HA_PORT=$(echo "$CORE_INFO" | grep -o '"port":[0-9]*' | cut -d':' -f2)

    # Fallback to defaults if extraction fails
    if [ -z "$HA_HOST" ]; then
        HA_HOST="homeassistant"
    fi
    if [ -z "$HA_PORT" ]; then
        HA_PORT="8123"
    fi
else
    HA_HOST="homeassistant"
    HA_PORT="8123"
fi

# Set HA endpoint URL
HA_ENDPOINT_URL="http://${HA_HOST}:${HA_PORT}"

# Validate required configuration
if bashio::config.is_empty 'grafana_cloud_url'; then
    bashio::log.fatal "Grafana Cloud URL is required. Get this from: Grafana Cloud → Connections → Collector"
    exit 1
fi

if bashio::config.is_empty 'grafana_cloud_username'; then
    bashio::log.fatal "Grafana Cloud username is required. Usually your instance ID (e.g., '123456')"
    exit 1
fi

if bashio::config.is_empty 'grafana_cloud_password'; then
    bashio::log.fatal "Grafana Cloud API key is required. Generate one with 'Push metrics' permissions"
    exit 1
fi

# Check if HA access token is provided
if bashio::config.is_empty 'ha_access_token'; then
    bashio::log.info "No Home Assistant access token provided - assuming Prometheus authentication is disabled"
    bashio::log.info "Make sure you have 'prometheus: requires_auth: false' in your configuration.yaml"
    HA_ACCESS_TOKEN=""
    USE_AUTH=false
else
    bashio::log.info "Home Assistant access token provided - using authenticated access"
    USE_AUTH=true
fi

# Validate URL format
if ! echo "${GRAFANA_CLOUD_URL}" | grep -q "prometheus.*grafana.net.*api.*prom.*push"; then
    bashio::log.warning "Grafana Cloud URL format may be incorrect. Expected format: https://prometheus-prod-XX-YY-Z.grafana.net/api/prom/push"
fi

# Validate API key format
if ! echo "${GRAFANA_CLOUD_PASSWORD}" | grep -q "^glc_"; then
    bashio::log.warning "Grafana Cloud API key should start with 'glc_'. Make sure you're using the correct key type."
fi

# Configure self-monitoring
if bashio::config.true 'enable_self_monitoring'; then
    SELF_MONITORING_CONFIG="// Alloy self-monitoring
prometheus.exporter.self \"alloy\" {}

prometheus.scrape \"alloy_self\" {
    targets = prometheus.exporter.self.alloy.targets
    forward_to = [prometheus.remote_write.grafana_cloud.receiver]
    scrape_interval = \"${SCRAPE_INTERVAL}\"
}"
else
    SELF_MONITORING_CONFIG="// Self-monitoring disabled"
fi

# Configure authentication for HA scraper
if [ "$USE_AUTH" = true ]; then
    HA_AUTH_CONFIG="bearer_token = \"${HA_ACCESS_TOKEN}\""
else
    HA_AUTH_CONFIG="// No authentication - requires_auth: false in HA config"
fi

# Export environment variables for template substitution
export GRAFANA_CLOUD_URL
export GRAFANA_CLOUD_USERNAME
export GRAFANA_CLOUD_PASSWORD
export SCRAPE_INTERVAL
export SELF_MONITORING_CONFIG
export HA_HOST
export HA_PORT
export HA_AUTH_CONFIG

bashio::log.info "Starting Grafana Cloud Connector"
bashio::log.info "Scrape interval: ${SCRAPE_INTERVAL}"
if [ "$USE_AUTH" = true ]; then
    bashio::log.info "Using authenticated Home Assistant access"
else
    bashio::log.info "Using unauthenticated access - ensure 'prometheus: requires_auth: false' is set"
fi

# Generate config from template
CONFIG_TEMPLATE="/etc/alloy/config.alloy.template"
CONFIG_FILE="/etc/alloy/config.alloy"

bashio::log.info "Generating Alloy configuration..."
envsubst < ${CONFIG_TEMPLATE} > ${CONFIG_FILE}

bashio::log.info "Configuration generated successfully"



# Verify Alloy binary is available
if [ ! -f "/usr/local/bin/alloy" ]; then
    bashio::log.fatal "Alloy binary not found at /usr/local/bin/alloy"
    exit 1
fi

# Start Alloy
bashio::log.info "Starting Alloy..."
exec /usr/local/bin/alloy run \
    --server.http.listen-addr=0.0.0.0:12345 \
    --disable-reporting \
    --storage.path=/data \
    ${CONFIG_FILE}