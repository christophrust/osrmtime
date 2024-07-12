{smcl}
{* * version 1.3.6  11jul2024}
{viewerjumpto "Syntax" "osrmtime##syntax"}{...}
{viewerjumpto "Description" "osrmtime##description"}{...}
{viewerjumpto "Prerequisites" "osrmtime##remarks"}{...}
{viewerjumpto "osrmprepare" "osrmtime##osrmprepare"}{...}
{viewerjumpto "authors" "osrmtime##authors"}{...}
{viewerjumpto "references" "osrmtime##references"}{...}
{smcl}
{* 25jan2016}{...}
{cmd:help osrmtime / osrmprepare}{right: ({browse "https://github.com/christophrust/osrmtime":SJ16-2: dm0088})}
{hline}

Note: Before you test the command, please take a look on the prerequisites below!

{title:Title}

{phang}
{bf:osrmtime} {hline 2} Calculate traveltime and distance using the Open Source Routing Machine (OSRM) based on OpenStreetMap data

{phang}
{bf:osrmprepare} {hline 2} Prepare maps to run {cmd:osrmtime} properly (see Prerequisites)

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:osrmtime}
 {inp:{it:latitude1 longitude1 latitude2 longitude2}}{cmd:,} {cmd:mapfile(}{it:"/path/to/mapfile"}{cmd:)} [{it:options}]

{marker options}{...}
{title:Options}

{synoptset 20 tabbed}{...}
{dlgtab:Main}

{synopt:{opt mapfile()}}declares the location of the map of interest in the *.osrm-file format (e.g.: {it:"C:\mymaps\germany\germany.osrm"}); this file can get extracted by using the {cmd:osrmprepare} command which is explained below{p_end}
{synopt:{opt osrmdir()}}announces the path in which the OSRM executables are located; default is {it:"C:\osrm\" } on a PC using Windows and {it:"/usr/local/osrm/"} on a PC using Linux. On Linux and MacOS, osrmtime will also find the executable if it is in the system path.{p_end}
{synopt:{opt nocleanup}}Setting {cmd:nocleanup} keeps temporary files which are generated during the process, and prevents OSRM from being shut down. This can speed up the calculation if {cmd:osrmtime} is used in a consecutive fashion with the 
   same  map, because {cmd:osrmtime} does not need to shut down and start OSRM over and over again.{p_end}

{dlgtab:Advanced options for parallel computing}

{synopt:{opt threads(#)}}specifies the number of parallel threads per running OSRM-instance, default is 4{p_end}
{synopt:{opt servers(#)}}starts (if your system permits) several instances of OSRM; default is 1{p_end}
{synopt:{opt ports(numlist)}} specify a list of TCP ports where the instance of OSRM shall listen; by default the ports 5000,5001,... are used. However, this might fail if other services have already bound to this port{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:osrmtime} provides an interface to the freely available high-performance routing engine OSRM.
This enables Stata to calculate traveltime and distance from a point of origin (lat1/lon1) to a point of destination (lat2/lon2). 
Provided that OSRM already resides on your system and you already have prepared your map of interest, {cmd:osrmtime} automatically starts OSRM and performs the calculation.
{cmd:osrmtime} already implements parallel computation so depending on your system the time for calculating shortest distances can be reduced significantly.
{inp:{it:latitude1 longitude1, latitude2}} and {inp:{it:longitude2}} must be numeric variables, denoted in decimal degrees (World Geodetic System WGS 84). They contain the starting point (latitude1 longitude1) and the destination (latitude2 longitude2).
{cmd:osrmtime} generates the following variables:

{synoptset 15 tabbed}{...}
{synopt:{opt distance}}distance of the shortest route in meters {p_end}

{synopt:{opt duration:}}traveltime of the shortest route in seconds{p_end}

{synopt:{opt jumpdist1:}}(spheric) distance between specified input location (origin) and matched location to road network in meters {p_end}

{synopt:{opt jumpdist2:}}(spheric) distance between specified input location (destination) and matched location to road network in meters 

{synopt:{opt return_code:}} 
{cmd:0} everything is fine{p_end}
{p 22 4 2}
{cmd:1} no route was found by OSRM with the points specified{p_end}
{p 22 4 2}
{cmd:2} OSRM did not respond{p_end}
{p 22 4 2}
{cmd:3} something else went wrong.{p_end}

{marker prerequisites}{...}
{title:Prerequisites}

    {title:1. Install required dependencies}
{pstd}
The command {cmd:osrmtime} does not only consist of several ado files and depends on some additional software. In order to make this command work, these dependencies have to be installed beforehand.
The command {cmd:osrmtime} uses some libraries from the Microsoft Visual C++ Redistributable, and the routing software OSRM. Both needs to be installed on your 64-bit system in order to run {cmd:osrmtime}.
To facilitate the installation, this stata package ships with an installation script. If that fails, please try to install the dependencies manually.

All files are available for download at {browse "https://github.com/christophrust/osrmtime/releases"}. Extract the zip archive at a location of your choice.

        {title:Automatic via installation script:}
{p 7 7 2}
Run the following command in stata and follow the instructions.

{stata `"net describe osrmtime, from("/path/to/extracted/files")"'}{break}

{p 7 10 2}
Note: osrminstall.cmd is an installation script for Windows users that can be run after downloading ancillary files. Please note that you must have write access on your working directory.

        {title:Manual:}
{p 7 10 2}
1. Copy the ado-files osrmtime.ado, osrmprepare.ado, and osrminterface.ado into your personal ado-folder.

{p 7 10 2}
2. Install the Microsoft Visual C++ Redistributable for Visual Studio 2015, see
{browse "https://www.microsoft.com/en-us/download/details.aspx?id=48145"}

{p 7 10 2}
3. Install the OSRM executables by downloading and unpacking the OSRM executables to a folder of your choice 
in which stata has write access, e.g. {it:"C:\osrm\"}. 
Download here: {browse "http://www.uni-regensburg.de/wirtschaftswissenschaften/vwl-moeller/medien/osrmtime/osrm.zip"}

{pstd}
Please note: For instructions how to build OSRM on Linux MacOS, see: {browse "https://github.com/Project-OSRM/osrm-backend/wiki/Building%20OSRM"}.

    {title:2. Prepare a Map}
{pstd}
In order to use {cmd:osrmtime}, at least one map covering the region of interest must be downloaded and prepared for routing. The following steps explain how to do this:

{p 7 10 2}
1. Download an OpenStreetMap data file in the *.osm.pbf format to a folder of your choice, e.g. C:/mymaps/mymap.osm.pbf. Maps can be downloaded, for instance, here: {browse "http://download.geofabrik.de"}

{p 7 10 2}
2. Prepare your map for routing. In order to make this step easier for the user, we wrote the {cmd:osrmprepare} command.

{p 7 10 2}
{cmd:osrmprepare} extracts from the maps geographic informations which are needed by the command {cmd:osrmtime}. Depending on the size of your map and the capacity of your system this takes some time (for instance, it takes about 27 minutes to extract a map for Germany, sized 2.6 GB, on a system with an Intel i7-2600 3.40GHz CPU).
This preparation is necessary for several reasons. Most importantly, raw OpenStreetMap data also includes information that is not relevant for routing, such as public toilets or memorials. The preparation ensures that only relevant information is extracted, and that this information can be used in an efficient way by the routing machine OSRM. 
Please note that you only have to prepare your map once. The prepared map can be used as often as you like. If you wish to update your map, however, you have to download a more recent map, and prepare it again.


{marker osrmprepare}{...}
    {title:Syntax}

{p 8 17 2}
{cmdab:osrmprepare,} {cmd:mapfile()} [{it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt mapfile()}}declares the location of the downloaded OpenStreetMap in *.osm.pbf format, e.g.: {it:"C:\mymaps\germany\germany.osm.pbf"}{p_end}
{synopt:{opt osrmdir()}}announces the path in which the OSRM executables are saved (the default is "C:\osrm\"){p_end}
{synopt:{opt profile()}}can be either one of the names {cmd:car}, {cmd:bicycle} or {cmd:foot} or the path of a valid profile file. osrmprepare will automatically look up some standard locations of your system to located the file.{p_end}
{synopt:{opt diskspace()}}allows to allocate disk space for preparation, default is 5000 MB. The minimum value you have to allocate depends on the size of your map. The maximum value you can allocate depends on the size of your hard disk.{p_end}
{synoptline}

{marker Example}{...}
{title:Example}

{pstd}
To exemplify how {cmd:osrmtime} and {cmd:osrmprepare} work, we calculate the travel time and distance from Alexanderplatz in Berlin to more than 3000 Restaurants also located in Berlin.

{pstd}    
*download OSM data of Berlin {break}
{stata mkdir mymaps}{break}
{stata `"copy "http://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf" "mymaps/berlin.osm.pbf" , replace"'}{break}

{pstd}
*prepare the map (this takes some time ~5 minutes, depending on your system):{break}
{stata `"osrmprepare , mapfile("mymaps/berlin.osm.pbf") profile(car) osrmdir("C:\osrm\")"'}

{pstd}
*open the latitude and longitude data of the restaurants and add destination Berlin, Alexanderplatz:{break}
{stata `"insheet using "restaurants_berlin.csv" , delimiter(";") clear"'}{break}
{stata gen lat_alex = 52.5219184}{break}
{stata gen lon_alex = 13.4132147}

{pstd}    
*calculate travel time and distances:{break}
{stata `"osrmtime lat lon lat_alex lon_alex , mapfile("mymaps\berlin.osrm") osrmdir("C:\osrm\")"'}

{marker:tech}{...}
{title:Technical remarks}

{pstd}
Maps from OpenStreetMap are usually large datasets. In case you aim to prepare a map with a file size that exceeds the amount of your available RAM, you will probably not be able to prepare the map, because your system does not provide enough RAM. 


{marker authors}{...}
{title:Authors}

Stephan Huber
Email: {browse "mailto:stephan.huber@wiwi.uni-regensburg.de":stephan.huber@wiwi.uni-regensburg.de}

Christoph Rust 
Email: {browse "mailto:christoph.rust@stud.uni-regensburg.de":christoph.rust@stud.uni-regensburg.de}

{marker references}{...}
{title:References}

{p 4 8 2} Huber, Stephan & Christoph Rust (2015): osrmtime: Calculate Travel Time and Distance with OpenStreetMap Data Using the Open Source Routing Machine (OSRM) The Stata Journal, 2016, 16, 416-423

{p 4 8 2}
Luxen, Dennis & Vetter, Christian (2011): Real-time routing with OpenStreetMap data. 
In: Proceedings of the 19th ACM SIGSPATIAL  International  Conference on Advances in 
Geographic Information Systems. ACM, New York, NY, USA.




