*! version 1.3.6 , 11jul2024
*! osrminterface.ado
*! christoph.rust@wiwi.uni-regenbsburg.de
*! stephan.huber@wiwi.uni-regensburg.de
*! now working with OSRM versions 4.9.0 up to 5.27.0


// cap program drop osrminterface
// clear mata

program osrminterface
version 12.0

syntax varlist(min=4 max=4)  [, verbose port(integer 5000) progress linewidth(integer 60)] osrmver(string) // varlist must be lat1 lon1 lat2 lon2
tokenize `varlist'

if "`verbose'"!="" local vb 1
else local vb 0
if "`progress'"!="" local pg 1
else local pg 2


tokenize "`osrmver'" , p(".")
local osrm_ver = `1'
local subver = `3'
if (`osrm_ver'==5 & `subver'>22) | `osrm_ver'>5  di as txt "OSRM versions higher than 5.26.0 have not been tested yet."

tokenize "`varlist'"
mata: calcdist("`1'" , "`2'" , "`3'" , "`4'","`vb'","`pg'", "`port'",`linewidth' , `osrm_ver')

end


mata
/* sample output
http://localhost:5000/viaroute?loc=52.517037,13.388860&loc=52.523219,13.428555alt=false&geometry=false

{"status":200,
"status_message":"Found route between points",
"hint_data":{"locations":["-YMAAH6zAACYEgAAAAAAABQAAAD-AgAAZwEAAHJHAADUAACAL34fA_eS0QAaAAEB",
"-YMAAH6zAACYEgAAAAAAABQAAAD-AgAAZwEAAHJHAADUAACAL34fA_eS0QAaAAEB"],
"checksum":2166424071},
"route_name":["",""],
"via_indices":[0,1],
"via_points":[[52.395569,13.734647],
[52.395569,13.734647]],
"found_alternative":false,
"route_summary":{"end_point":"Alter Fischerweg",
"start_point":"Alter Fischerweg",
"total_time":0,
"total_distance":0}
}

*/
/* function for OSRM v4.9.0 */
function getdist1(real lat1_num, real lon1_num, real lat2_num, real lon2_num , string port)
{
    lat1 = strofreal(lat1_num)
    lon1 = strofreal(lon1_num)
    lat2 = strofreal(lat2_num)
    lon2 = strofreal(lon2_num)
    url = "http://127.0.0.1:" + port + "/viaroute?loc=" + lat1 + "," + lon1 + "&loc=" + lat2 + "," + lon2 + "alt=false&geometry=false"
    fh = _fopen(url , "r")
    if (fh >= 0 ) {
        file = ""
        while ((line=fget(fh))!=J(0,0,"")) {
            //printf(line)
            file = file+line
        }
        fclose(fh)
        /* parse json file */
        if (regexm(file, ".status.:0") | regexm(file, ".status.:200")) {
            /* distance */
            if (regexm(file, ".total_distance.:[0-9]*")) {
                match = regexs(0)
                if (regexm(match , ":[0-9]*")) dist = substr(regexs(0),2,.)
                else dist=""
            }
            /* duration */
            if (regexm(file, ".total_time.:[0-9]*")) {
                match = regexs(0)
                if (regexm(match , ":[0-9]*")) time = substr(regexs(0),2,.)
                else time=""
            }
            /* start , end place  for jump distance */
            pattern = ".via_points.:\[\[.*\]\]"
            if (regexm(file, pattern )) {
                match = regexs(0)
                if (regexm(match , "\[\[.*\]\]")) {
                    s = regexs(0)
                    rc = regexm(s,"\[\[-*[0-9]*\.[0-9]*")
                    p1lat = strtoreal(substr(regexs(0),3,.))
                    rc = regexm(s,"-*[0-9]*\.[0-9]*\],\[")
                    m = regexs(0)
                    p1lon = strtoreal(substr(m,1,strlen(m)-3))
                    rc = regexm(s,"\],\[-*[0-9]*\.[0-9]*")
                    m = regexs(0)
                    p2lat = strtoreal(substr(m,4,.))
                    rc = regexm(s,"-*[0-9]*\.[0-9]*\]\]")
                    m = regexs(0)
                    p2lon = strtoreal(substr(m,1,strlen(m)-2))
                    d1 = sph_dist(lat1_num,lon1_num,p1lat,p1lon)
                    d2 = sph_dist(lat2_num,lon2_num,p2lat,p2lon)
                }
                else {
                    d1=.
                    d2=.
                }
            }
            else {
                d1=.
                d2=.
            }
            rc = 0
        }
        else {
            time=""
            dist=""
            d1=.
            d2=.
            rc=1
        }
    }
    else if (fh==-672){
        time=""
        dist=""
        d1=.
        d2=.
        rc=1
    }
    else {
        time=""
        dist=""
        d1=.
        d2=.
        rc=2
    }
    if ( eltype(time)=="string" ){
        t = strtoreal(time)
    }
    else {
        if (length(time)> 0) t = time
        else t = .
    }
    if ( eltype(dist)=="string") {
        d = strtoreal(dist)
    }
    else {
        if (length(dist)> 0) d = dist
        else d = .
    }
    result = (d , t, d1, d2, rc)
    return(result)
}

/*
sample output for parsing

http://127.0.0.1:5000/route/v1/driving/13.388860,52.517037;13.428555,52.523219?overview=false

{"code":"Ok",
 "routes":[{"legs":[{"steps":[],"summary":"","duration":294.9,"distance":3791}],"duration":294.9,"distance":3791}],
 "waypoints":[{"hint":"NisKgHDGroqQ_gAAEAAAABgAAAAGAAAAAAAAANnyPAdHUZwDMbUAAP9LzACpWCEDPEzMAK1YIQMBAAEBmDLpJw==","name":"Friedrichstraße","location":[13.388799,52.517033]},
              {"hint":"qAQagP___3_UoAYAGAAAAEAAAAAeAAAAQAAAAJ1xSQeQZvQEMbUAAEnnzADlcCEDS-fMANNwIQMDAAEBmDLpJw==","name":"Platz der Vereinten Nationen","location":[13.428553,52.523237]}]
}
*/

/* 

{"waypoints":[
    {"location":[-74.275309,40.582954],
     "distance":18.071301,
     "hint":"D4UFgBGFBYA-AAAA_AAAAHoCAABBAAAAyOYsQo8VL0MdGNxDgt41Qj4AAAD8AAAAegIAAEEAAADPAgAAE6aS-yo_awJYppL7kD5rAgsAfwT1iKNN",
     "name":""
    },
    {"location":[-74.109219,40.670728],
    "distance":27.200335,
    "hint":"ZZQEgNWVBIAoAAAAJgAAAAAAAAAAAAAARbEPQmQnB0IAAAAAAAAAACgAAAAmAAAAAAAAAAAAAADPAgAA3S6V-wiWbALOLZX7jJZsAgAADwL1iKNN",
    "name":"Avenue E"
    }],
 "routes":[{"distance":27871.4,"duration":1630.5,"weight_name":"routability",
"legs":[{"distance":27871.4,"steps":[],"duration":1630.5,"weight":1630.5,"summary":""}],"weight":1630.5}],
"code":"Ok"}

{"waypoints":[{"location":[-74.275309,40.582954],"distance":18.071301,"hint":"D4UFgBGFBYA-AAAA_AAAAHoCAABBAAAAyOYsQo8VL0MdGNxDgt41Qj4AAAD8AAAAegIAAEEAAADPAgAAE6aS-yo_awJYppL7kD5rAgsAfwT1iKNN","name":""},{"location":[-74.109219,40.670728],"distance":27.200335,"hint":"ZZQEgNWVBIAoAAAAJgAAAAAAAAAAAAAARbEPQmQnB0IAAAAAAAAAACgAAAAmAAAAAAAAAAAAAADPAgAA3S6V-wiWbALOLZX7jJZsAgAADwL1iKNN","name":"Avenue E"}],"routes":[{"distance":27871.4,"duration":1630.5,"weight_name":"routability","legs":[{"distance":27871.4,"steps":[],"duration":1630.5,"weight":1630.5,"summary":""}],"weight":1630.5}],"code":"Ok"}

{"waypoints":[{"location":[-121.90273,37.755246],"name":"Wycliffe Lane","hint":"NBCLgOARi4BAAAAAOAAAAAAAAABJAAAAQAAAADgAAAAAAAAASQAAANsMAAB26bv4bhlAAmjmu_imHUACAADPA-EJNeU="},
{"location":[-121.874456,37.658998],"name":"1st Street","hint":"rd0igLTdIoAWAAAAIQAAAGUAAAAAAAAAFgAAACEAAABlAAAAAAAAANsMAADoV7z4dqE-AoRYvPgKoT4CBADfDeEJNeU="}],
"routes":[{"distance":13132.5,"duration":1069.3,"weight":1069.3,"weight_name":"routability","legs":
[{"distance":13132.5,"duration":1069.3,"weight":1069.3,"summary":"","steps":[]}]}],"code":"Ok"}

*/

/*
{"routes":[{"legs":[{"summary":"","weight":8832.9,"duration":8242.8,"steps":[],"distance":231276.9}],"weight_name":"routability","weight":8832.9,"duration":8242.8,"distance":231276.9}],
"waypoints":[{"hint":"NrkLi2q5C4sOAAAAJgAAAJ4AAAAAAAAADdxBQcsusEFdJWVBAAAAAA4AAAAmAAAAJgAAAAAAAADnpQAAyBuWANGFKAPVG5YA1oUoAwIAnxRP1hQ6","distance":1.035520492454637,"name":"Poststraße","location":[9.837512,52.987345]},{"hint":"XQ7NhoQOzYaeAQAAAAAAAAADAAAAAAAAlAW4QQAAAAAdvCpCAAAAAGcAAAAAAAAAvwAAAAAAAADnpQAATQWQABrpQwNGAZAAOOpDAwMAPxZP1hQ6","distance":73.59232454961926,"name":"","location":[9.438541,54.782234]}],"code":"Ok"}
*/

/* function for OSRM v5.*.* */
function getdist2(real lat1_num, real lon1_num, real lat2_num, real lon2_num , string port)
{
    lat1 = strofreal(lat1_num)
    lon1 = strofreal(lon1_num)
    lat2 = strofreal(lat2_num)
    lon2 = strofreal(lon2_num)
    url = "http://127.0.0.1:" + port + "/route/v1/driving/" + lon1 + "," + lat1 + ";" + lon2 + "," + lat2 + "?overview=false"
    // printf(url)
    fh = _fopen(url , "r")
    if (fh >= 0 ) {
        file = ""
        while ((line=fget(fh))!=J(0,0,"")) {
            // printf(line)
            file = file+line
        }
        fclose(fh)
        /* parse json file */
        if (regexm(file, ".code.:.Ok")){
            /* parse the Route object */
            /* either routes or waypoints object is first, we must only use the routes object */
            if (regexm(file, "routes.*waypoints")){
                route = regexs(0)

                /* distance */
                if (regexm(route, ".distance.:[0-9]*\.?[0-9]*")) {
                    match = regexs(0)
                    if (regexm(match , "[0-9][0-9]*\.?[0-9]*")) {
                        dist = regexs(0)
                    }
                    else dist=""
                }
                /* duration */
                if (regexm(route, ".duration.:[0-9][0-9]*\.?[0-9]*")) {
                    match = regexs(0)
                    if (regexm(match , "[0-9][0-9]*\.?[0-9]*")) {
                        time = regexs(0)
                    }
                    else time=""
                }

            } else if(regexm(file, "routes.*distance.:[0-9]*\.?[0-9]*")){

                /* distance */
                route = regexs(0)
                if (regexm(route, ".distance.:[0-9]*\.?[0-9]*")) {
                    match = regexs(0)
                    if (regexm(match , "[0-9][0-9]*\.?[0-9]*")) {
                        dist = regexs(0)
                    }
                    else dist=""
                }

                /* duration */
                if (regexm(route, ".duration.:[0-9][0-9]*\.?[0-9]*")) {
                    match = regexs(0)
                    if (regexm(match , "[0-9][0-9]*\.?[0-9]*")) {
                        time = regexs(0)
                    }
                    else time=""
                }
            } else {
                dist=""
                time=""
            }

            /* start , end place  for jump distance */
            pattern = ".waypoints.*location.:\[[-0-9]*\.[0-9]*,[-0-9]*\.[0-9]*.*location.:\[[-0-9]*\.[0-9]*,[-0-9]*\.[0-9]*"
            if (regexm(file, pattern )) {
                match = regexs(0)
                if (regexm(match , "[-0-9][0-9]*\.[0-9]*,[-0-9][0-9]*\.[0-9]*")) {
                    s1 = regexs(0)
                    match = regexr(match , "[-0-9][0-9]*\.[0-9]*,[-0-9][0-9]*\.[0-9]*","")
                    if (regexm(match , "[-0-9][0-9]*\.[0-9]*,[-0-9][0-9]*\.[0-9]*")) {
                        s2 = regexs(0)
                    }
                    /* first loc */
                    if ( regexm(s1,",[-0-9][0-9]*\.[0-9]*")) {
                        p1lat = strtoreal(substr(regexs(0),2,.))
                    }
                    s1 = regexr(s1,",[-0-9][0-9]*\.[0-9]*","")
                    if ( regexm(s1,"[-0-9]*\.[0-9]*")) {
                        p1lon = strtoreal(regexs(0))
                    }
                    /* second loc */
					if ( regexm(s2,",[-0-9][0-9]*\.[0-9]*") ) {
                        p2lat = strtoreal(substr(regexs(0),2,.))
                    }
                    s2 = regexr(s2,",[-0-9][0-9]*\.[0-9]*","")
                    if ( regexm(s2,"[-0-9]*\.[0-9]*") ) {
                        p2lon = strtoreal(regexs(0))
                    }
					d1 = sph_dist(lat1_num,lon1_num,p1lat,p1lon)
                    d2 = sph_dist(lat2_num,lon2_num,p2lat,p2lon)
                }
                else {
                    d1=.
                    d2=.
                }
            }
            else {
                d1=.
                d2=.
            }
            rc = 0
        }
        else {
            time=""
            dist=""
            d1=.
            d2=.
            rc=1
        }
    }
    else if (fh==-672){
        time=""
        dist=""
        d1=.
        d2=.
        rc=1
    }
    else {
        time=""
        dist=""
        d1=.
        d2=.
        rc=2
    }
    if ( eltype(time)=="string" ){
        t = strtoreal(time)
    }
    else {
        if (length(time)> 0) t = time
        else t = .
    }
    if ( eltype(dist)=="string") {
        d = strtoreal(dist)
    }
    else {
        if (length(dist)> 0) d = dist
        else d = .
    }
    result = (d , t, d1, d2, rc)
    return(result)
}


function calcdist(string var1, string var2, string var3 , string var4, string vb, string pg, string port, real lw , real osrm_ver)
{
    data = st_data(.,(var1,var2,var3,var4))
    no_obs = rows(data)
    res = J(no_obs,5,.)
    //res
    idx = st_addvar("double",("distance","duration","jumpdist1","jumpdist2","return_code"))
    val = setbreakintr(0)
    lastval = -1
    lastvalp = -1
    for (i=1 ; i<=no_obs ; i++) {
        la1 = data[i,1]
        lo1 = data[i,2]
        la2 = data[i,3]
        lo2 = data[i,4]
        if (osrm_ver==4) {
            result = getdist1(la1,lo1,la2,lo2,port)
        }
        else if (osrm_ver>=5) {
            result = getdist2(la1,lo1,la2,lo2,port)
        }
        // result
        res[i,.] = result
        if (vb=="1") strofreal(i) + " out of " + strofreal(no_obs)
        if (pg=="1") {
            progress = floor(i/no_obs*100)
            if (progress > lastval) {
                "Progress: " + strofreal(progress) + " %"
                lastval = progress
            }
        }
        else if (pg=="2") {
            progress = floor(i/no_obs*(lw-23))
            progressp = floor(i/no_obs*10)
            if (progress > lastval) {
                if (progressp > lastvalp) {
                    msg = strofreal(progressp*10) +"%%"
                    printf(msg)
                    displayflush()
                    lastvalp = progressp
                }
                else {
                    printf("-")
                    displayflush()
                }
                lastval = progress
            }
        }
        if(breakkey()) {
            st_store(.,("distance","duration","jumpdist1","jumpdist2","return_code"),res)
            (void) setbreakintr(val)
            exit
        }
    }
    st_store(.,("distance","duration","jumpdist1","jumpdist2","return_code"),res)
    (void) setbreakintr(val)
}

function sph_dist(real p1lat, real p1lon , real p2lat, real p2lon) {
    p1lat = p1lat * pi()/180
    p1lon = p1lon * pi()/180
    p2lat = p2lat * pi()/180
    p2lon = p2lon * pi()/180
    d = floor( acos( cos(p1lat) * cos(p2lat) * cos(p1lon - p2lon) + sin(p1lat)*sin(p2lat) ) * 6367440 )
    return(d)
}
end

/* testing */
// mata : getdist2(52.517037,13.388860,52.523219,13.428555,"5000")
// mata : getdist1(52.517037,13.388860,52.523219,13.428555,"5000")
// mata : getdist2(37.7563264, -121.9035123, 37.658890, -121.874300, "5000")
