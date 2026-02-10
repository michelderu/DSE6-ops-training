-- DSE 6.8/6.9 Operations Training - Sample keyspace and table
-- Run after cluster is up: ./scripts/cqlsh.sh -f training/labs/sample-keyspace.cql

CREATE KEYSPACE IF NOT EXISTS training
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'DC1': 3
};

USE training;

CREATE TABLE IF NOT EXISTS sample (
  id uuid PRIMARY KEY,
  name text,
  value int,
  created_at timestamp
);

INSERT INTO sample (id, name, value, created_at)
VALUES (uuid(), 'first', 100, toTimestamp(now()));

INSERT INTO sample (id, name, value, created_at)
VALUES (uuid(), 'second', 200, toTimestamp(now()));

INSERT INTO sample (id, name, value, created_at)
VALUES (uuid(), 'third', 300, toTimestamp(now()));

-- Verify
SELECT * FROM sample;
