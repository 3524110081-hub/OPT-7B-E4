CREATE TABLE IF NOT EXISTS telemetry_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    
    metric VARCHAR(100) NOT NULL CHECK (metric <> ''),
    value NUMERIC NOT NULL,
    unit VARCHAR(30) NOT NULL CHECK (unit <> ''),
    
    observed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT valid_cpu_range CHECK (
        (metric = 'cpu_usage' AND value >= 0 AND value <= 100) OR 
        (metric != 'cpu_usage')
    )
);