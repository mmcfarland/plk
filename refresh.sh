#! /bin/bash

DB="parcel_lookup"

./load_dor.sh
./load_pwd.sh

# Create the lookup date, base on PWD and supplement basereg
# from that
psql -d $DB << EOF

CREATE TABLE plk AS 
SELECT p.brt_id, p.parcelid, p.address, d.basereg, d.mapreg, 
       p.geom as pwd_geom, d.geom as dor_geom 
       FROM pwd_parcels as p 
       LEFT JOIN dor_parcels as d on ST_Contains(d.geom, p.pos);

CREATE index mapreg_idx on plk (mapreg);
CREATE index pwd_geom_idx on plk using gist (pwd_geom);
create index opa_idx on plk (brt_id);
EOF
