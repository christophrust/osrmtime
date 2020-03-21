# osrmtime

Stata command for computing travel time and distance with OpenStreetMap data using the Open Source Routing Machine (OSRM).

## Prerequisites

In order to make this command work, you have to install OSRM locally. This stata package provides an automatic install script for windows users.

### Windows

Please download the [release archive](https://github.com/christophrust/osrmtime/releases/download/v1.3.3/osrmtime_release1.3.3.zip) and unpack it at a location of your choice. Then in stata type (of course, replace the path to the location where you unpacked the content of the release archive)

```stata
net describe osrmtime, from("/path/to/extracted/files")
```

and follow the instructions available there.


### Linux/Mac

Of course, OSRM also runs very well on Linux and should also be available on mac-os. Please follow the installation instructions given in the [OSRM Wiki](https://github.com/Project-OSRM/osrm-backend/wiki). Remark: I tested these ados up tp version 5.22 which is the current release version at the time of writing.

Afer copying the `ado` files and the `sthlp` file into one of stata's sysdir folders (preferrably `HOME_DIR/ado/plus/o/`, this command should work.


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

## Contact

In case something doesn't work, please feel free to contact me at christoph[dot]rust[at]ur[dot]de.
