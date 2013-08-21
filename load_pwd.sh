#! /bin/bash

DB="parcel_lookup"

# Download and unzip the pwd parcel shapefile
cd /tmp/
rm -rf pwd_parcels_workspace
mkdir pwd_parcels_workspace && cd pwd_parcels_workspace
wget http://gis.phila.gov/data/PARCELS_PWD.zip
unzip PARCELS_PWD.zip

# Load the shapefile into postgis
shp2pgsql -I -D -s 2272 PARCELS_PWD/PARCELS_PWD.shp pwd_parcels > p.sql
psql -d $DB -c "drop table if exists pwd_parcels;"
psql -d $DB -f p.sql

psql -d $DB << EOF
    create index pwd_parcelid_idx on pwd_parcels (parcelid);
    create index pwd_opaid_idx on pwd_parcels (brt_id);
    alter table pwd_parcels alter column geom set data type geometry(Multipolygon,4326) using ST_Transform(geom, 4326);
    update pwd_parcels set geom = ST_MakeValid(geom) where ST_IsValid(geom) = false;
    alter table pwd_parcels add column pos geometry (Point, 4326);
    update pwd_parcels set pos = ST_PointOnSurface(geom);
EOF

