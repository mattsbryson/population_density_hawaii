#thanks to this for the right projection. https://bl.ocks.org/mbostock/5629120 - albers
PROJECTION='d3.geoAlbers().parallels([8, 18]).rotate([157, 0])'
#PROJECTION='d3.geoAlbers().parallels([12, 16]).rotate([157, 0])'
#.rotate([158,-21])
# The state FIPS code.
STATE=15

# The ACS 5-Year Estimate vintage.
YEAR=2014

# The display size.
WIDTH=660
HEIGHT=600

# Download the census tract boundaries.
# Extract the shapefile (.shp) and dBASE (.dbf).
if [ ! -f cb_${YEAR}_${STATE}_tract_500k.shp ]; then
  curl -o cb_${YEAR}_${STATE}_tract_500k.zip \
    "https://www2.census.gov/geo/tiger/GENZ${YEAR}/shp/cb_${YEAR}_${STATE}_tract_500k.zip"
  unzip -o \
    cb_${YEAR}_${STATE}_tract_500k.zip \
    cb_${YEAR}_${STATE}_tract_500k.shp \
    cb_${YEAR}_${STATE}_tract_500k.dbf
fi

# Download the census tract population estimates.
if [ ! -f cb_${YEAR}_${STATE}_tract_B01003.json ]; then
  curl -o cb_${YEAR}_${STATE}_tract_B01003.json \
    "https://api.census.gov/data/${YEAR}/acs5?get=B01003_001E&for=tract:*&in=state:${STATE}"
fi

geo2topo -n \
  tracts=<(ndjson-join 'd.id' \
    <(shp2json cb_${YEAR}_${STATE}_tract_500k.shp \
      | geoproject "${PROJECTION}.fitExtent([[10, 10], [${WIDTH} - 10, ${HEIGHT} - 10]], d)" \
      | ndjson-split 'd.features' \
      | ndjson-map 'd.id = d.properties.GEOID.slice(2), d') \
    <(ndjson-cat cb_${YEAR}_${STATE}_tract_B01003.json \
      | ndjson-split 'd.slice(1)' \
      | ndjson-map '{id: d[2] + d[3], B01003: +d[0]}') \
    | ndjson-map 'd[0].properties = {density: Math.floor(d[1].B01003 / d[0].properties.ALAND * 2589975.2356)}, d[0]') \
  | toposimplify -p 1 -f \
  | topomerge -k 'd.id.slice(0, 1)' states=tracts \
  | topomerge -k 'd.id.slice(0, 3)' counties=tracts \
  | topomerge --mesh -f 'a !== b' counties=counties \
  | topomerge --mesh -f 'a == b' states=states \
  | topoquantize 1e5 \
  > topo.json