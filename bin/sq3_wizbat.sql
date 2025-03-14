#!/usr/bin/env sqlite3
-- SQLite3 script
-- create a table `storage` for HomeWizard battery state data
-- ref: https://api-documentation.homewizard.com/docs/v2/measurement#plug-in-battery-hwe-bat

DROP TABLE IF EXISTS storage;


CREATE TABLE storage (
  sample_time   datetime NOT NULL PRIMARY KEY,
  sample_epoch  integer,
  bat_id        text,
  soc           float,
  cycles        float,
  power         float,
  voltage       float,
  current       float,
  frequency     float,
  import        float,
  export        float,
  );

CREATE INDEX storage_sample_epoch ON storage(sample_epoch);
CREATE INDEX storage_bat_id ON storage(bat_id);

-- example:
-- https/1.1 200 OK
-- Content-Type: application/json

-- {
--    "energy_import_kwh": 123.456,
--    "energy_export_kwh": 123.456,
--    "power_w": 123,
--    "voltage_l1_v": 230,
--    "current_a": 1.5,
--    "frequency_hz": 50,
--    "state_of_charge_pct": 50,
--    "cycles": 123
-- }
