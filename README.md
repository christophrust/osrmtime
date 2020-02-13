# osrmtime

Stata command for computing travel time and distance with OpenStreetMap data using the Open Source Routing Machine (OSRM).

## Prerequisites

In order to make this command work, you have to install OSRM locally. This stata package provides an automatic install script for windows users.

### Windows

Please download the release archive and unpack it at a location of your choice. Then in stata type (of course, replace the path to the location where you unpacked the content of the release archive)

```stata
net describe osrmtime, from("/path/to/extracted/files")
```

and follow the instructions available there.


### Linux/Mac

Of course, OSRM also runs on linux and mac-os. Please follow the installation instructions given in the [OSRM Wiki](https://github.com/Project-OSRM/osrm-backend/wiki).

Afer copying the `ado` files into one of stata's sysdir folders, this command should work.


## Happy routing:

```stata
// download a map of berlin
mkdir mymaps
copy "http://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf" "mymaps/berlin.osm.pbf" , replace

// prepare the map (this takes some time ~5 minutes, depending on your system):
osrmprepare , mapfile("mymaps/berlin.osm.pbf") profile(car) osrmdir("/path/to/osrm/")

// open the latitude and longitude data of the restaurants (file available in
// release archvei) and add destination Berlin, Alexanderplatz:
insheet using "restaurants_berlin.csv" , delimiter(";") clear
gen lat_alex = 52.5219184
gen lon_alex = 13.4132147

// calculate travel time and distances:
osrmtime lat lon lat_alex lon_alex , mapfile("mymaps/berlin.osrm") osrmdir("/path/to/osrm/")
```
