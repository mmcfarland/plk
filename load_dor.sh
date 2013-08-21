#! /bin/bash

DB="parcel_lookup"

# Download and unzip the dor parcel shapefile
cd /tmp/
rm -rf dor_parcels_workspace
mkdir dor_parcels_workspace && cd dor_parcels_workspace
wget http://www.pasda.psu.edu/philacity/data/Philadelphia_DOR_Parcels_Active201302.zip 
unzip Philadelphia_DOR_Parcles_Active201302.zip

# Load the shapefile into postgis
shp2pgsql -I -D -s 2272 Philadelphia_DOR_Parcles_Active201302/Philadelphia_DOR_Parcles_Active201302.shp dor_parcels > p.sql
psql -d $DB -c "drop table if exists dor_parcels;"
psql -d $DB -f p.sql

psql -d $DB << EOF
    create index dor_parcelid_idx on dor_parcels (parcelid);
    create index dor_basereg_idx on dor_parcels (basereg);
    alter table dor_parcels alter column geom set data type geometry(Multipolygon,4326) using ST_Transform(geom, 4326);
    update dor_parcels set geom = ST_MakeValid(geom) where ST_IsValid(geom) = false;
    alter table dor_parcels add column pos geometry (Point, 4326);
    update dor_parcels set pos = ST_PointOnSurface(geom);
EOF
