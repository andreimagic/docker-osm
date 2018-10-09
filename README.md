# OpenStreetMaps tiles server + Nominatim reverse geocoding

## Previewing OSM tiles

Run this container exposing port 80 to local 8080 (all configurations are made on port 8080)

    docker run -d -p8080:80 --name osm andreimagic/openstreetmaps:v2

You should be able to view the map at: http://localhost:8080/osm/slippymap-lan.html

Tiles are served at this address: http://localhost:8080/osm/${z}/${x}/${y}.png example http://localhost:8080/osm/0/0/0.png 

If the map does not load after 30 ses.: `docker exec -it osm service apache2 restart`
If the tiles are not rendering after 30 sec.: `docker exec -it osm service renderd restart`

## Previewing Nominatim

http://localhost:8080/nominatim/
http://localhost:8080/nominatim/search.php?q=cuba&format=json&addressdetails=1
http://localhost:8080/nominatim/reverse.php?format=json&lat=23.0131338&lon=-80.8328748&zoom=18&addressdetails=1

## Load your own map

### Access the environment
    
    docker exec -it osm bash

This image is based on Ubuntu. Everything is setup under `safemobile` user.

Username: `safemobile` Password: `safemobile`

### Load a new map file for OSM

Download the `*.osm.pbf` map files from http://download.geofabrik.de (use this website to see the available resources).

Start by changing the user: `su safemobile`

    cd /home/safemobile/planet/
    wget http://download.geofabrik.de/europe/cuba-latest.osm.pbf
    osm2pgsql --slim -d gis -C 1000 --number-processes 2 ~/planet/cuba-latest.osm.pbf
    sudo rm -rf /var/lib/mod_tile/default/*
    sudo touch /var/lib/mod_tile/planet-import-complete -t 201701010000

### Load a new map file for Nominatim

*NOTE:* run this as `safemobile` user

*NOTE:* if you need to load a new OSM file you must drop the database before running the commands again

    psql -d postgres --username=safemobile
        drop database nominatim;
        \q

    cd /usr/local/src/Nominatim-2.4.0
    ./utils/setup.php --osm-file /home/safemobile/planet/cuba-latest.osm.pbf --all --osm2pgsql-cache 1024

    sudo ./utils/specialphrases.php --countries > specialphrases_countries.sql
    psql -d nominatim -f specialphrases_countries.sql

    sudo ./utils/specialphrases.php --wiki-import > specialphrases.sql
    psql -d nominatim -f specialphrases.sql


## Customise the address to access from other computers

### OSM tiles preview URL

Edit `/var/www/osm/slippymap.html` (using nano editor), replace `http://localhost:8080/` with your host IP address (from where the tiles are served), you can also change the port number (on which the container will be exposed).

    <html>
    <head>
        <title>OSM Local Tiles</title>
        <link rel="stylesheet" href="style.css" type="text/css" />
        <!-- bring in the OpenLayers javascript library
            (here we bring it from the remote site, but you could
            easily serve up this javascript yourself) -->
        <script src="http://openlayers.org/api/OpenLayers.js"></script>

        <!-- bring in the OpenStreetMap OpenLayers layers.
            Using this hosted file will make sure we are kept up
            to date with any necessary changes -->
        <script src="http://www.openstreetmap.org/openlayers/OpenStreetMap.js"></script>

        <script type="text/javascript">
    // Start position for the map (hardcoded here for simplicity)
            var lat=47.7;
            var lon=7.5;
            var zoom=10;

            var map; //complex object of type OpenLayers.Map

            //Initialise the 'map' object
            function init() {

                map = new OpenLayers.Map ("map", {
                    controls:[
                        new OpenLayers.Control.Navigation(),
                        new OpenLayers.Control.PanZoomBar(),
                        new OpenLayers.Control.Permalink(),
                        new OpenLayers.Control.ScaleLine({geodesic: true}),
                        new OpenLayers.Control.Permalink('permalink'),
                        new OpenLayers.Control.MousePosition(),
                        new OpenLayers.Control.Attribution()],
                    maxExtent: new OpenLayers.Bounds(-20037508.34,-20037508.34,20037508.34,20037508.34),
                    maxResolution: 156543.0339,
                    numZoomLevels: 19,
                    units: 'm',
                    projection: new OpenLayers.Projection("EPSG:900913"),
                    displayProjection: new OpenLayers.Projection("EPSG:4326")
                } );

                // This is the layer that uses the locally stored tiles
                var newLayer = new OpenLayers.Layer.OSM("Local Tiles", "http://localhost:8080/osm/${z}/${x}/${y}.png", {numZoomLevels: 19});
                map.addLayer(newLayer);

                layerMapnik = new OpenLayers.Layer.OSM.Mapnik("Mapnik");
                map.addLayer(layerMapnik);

    // This is the end of the layer

                var switcherControl = new OpenLayers.Control.LayerSwitcher();
                map.addControl(switcherControl);
                switcherControl.maximizeControl();

                if( ! map.getCenter() ){
                    var lonLat = new OpenLayers.LonLat(lon, lat).transform(new OpenLayers.Projection("EPSG:4326"), map.getProjectionObject());
                    map.setCenter (lonLat, zoom);
                }
            }

        </script>
    </head>

    <!-- body.onload is called once the page is loaded (call the 'init' function) -->
    <body onload="init();">

        <!-- define a DIV into which the map will appear. Make it take up the whole window -->
        <div style="width:100%; height:100%" id="map"></div>

    </body>

    </html>

*NOTE:* this does not impact the address at which the tiles will be exposed (localhost or ip) [http://localhost:8080/osm/0/0/0.png](http://localhost:8080/osm/0/0/0.png), only the html files used for previewing.

### Nominatim search URL

*NOTE:* This changes impact the overall search process, preview page and also the search and reverse URLs

    cd /usr/local/src/Nominatim-2.4.0
    sudo nano settings/settings.php
    // replace with localhost or your IP, in our case for production we need 192.168.65.130
    // @define('CONST_Website_BaseURL', 'http://'.php_uname('n').'/');
    @define('CONST_Website_BaseURL', 'http://192.168.65.130/nominatim/');
    sudo ./utils/setup.php --create-website /var/www/nominatim
    sudo service apache2 restart
