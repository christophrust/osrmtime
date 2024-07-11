*! version 1.3.4 , 18feb2020
*! now working with OSRM versions 4.9.0 up to 5.22.0
*! osrmtime.ado
*! christoph.rust@wiwi.uni-regensburg.de
*! stephan.huber@wiwi.uni-regensburg.de

// cap program drop osrmtime
program define osrmtime
version 12.0

syntax varlist(min=4 max=4) , ///
		[threads(integer 1) servers(integer 1)  ///
		osrmdir(string) mapfile(string) ports(numlist) ///
		adopath(string) nocleanup progress]


/* output format */

local linelength = max(min(c(linesize),60),40)
di as txt "{hline `linelength'}"
di as res "{hi:Traveltime and Distance with OSRM}"
di


tempname filehandle
local filehandle "osrmtime_fh_`filehandle'"
cap file close `filehandle'
/* checkings */
/* check location of osrm executable */
if "`osrmdir'"=="" {
	if c(os)=="Windows" {
		cap confirm file "C:\osrm\osrm-routed.exe"
		if !_rc local osrmdir "C:\osrm\"
		else {
			di as err "Could not find OSRM executable"
			exit
			}
		}
	// if c(os)=="Unix" {
    else {
        cap confirm file "/usr/local/osrm/osrm-routed"
        if !_rc local osrmdir "/usr/local/osrm/"
        else {
            cap confirm file "~/osrm/osrm-routed"
            if !_rc local osrmdir "~/osrm/"
            else {
		* try to locate it as system executable
		! which osrm-routed > /tmp/stata_osrmpath.tmp
		cap file open `filehandle' using /tmp/stata_osrmpath.tmp , read
		if !_rc {
		    file read `filehandle' file
		    while r(eof)==0 {
		        file read `filehandle' line
		        local file `file' `line'
		    }
                    file close `filehandle'
		    cap erase /tmp/stata_osrmpath.tmp
		    if regexm("`file'", "osrm-routed") {
			local osrmdir = regexr("`file'", "osrm-routed","")
		    }
		    else {
			di as err "Could not find OSRM executable"
			exit
                    } 
		}
            }
        }
    }
}
else {
	if (substr("`osrmdir'",-1,.)=="/" | substr("`osrmdir'",-1,.)=="\") {
		local osrmdir = substr("`osrmdir'",1,length("`osrmdir'")-1)
		}
	if c(os)=="Windows" local exefile ="`osrmdir'\osrm-routed.exe"
	else local exefile ="`osrmdir'/osrm-routed"
	cap confirm file "`exefile'"
	if _rc {
		di in smcl "{p 0 0 4}{err:Provided OSRM directory does not seem to be correct!}{break}{err:Please provide a correct} {inp:osrmdir()}"
		exit
		}
	}


/* adjust path for linux and Mac */
if c(os)!="Windows"{
	local exefile = subinstr("`exefile'"," ","\ ",.)
	local mapfile = subinstr("`mapfile'"," ","\ ",.)
	local pwdir = subinstr("`c(pwd)'"," ","\ ",.)
	}

/* check for running OSRM */
tempfile output
if c(os)=="Windows" shell "`exefile'" -v > `output' 2>&1
else shell `exefile' -v > `output' 2>&1
file open `filehandle' using `output' , read
file read `filehandle' file
while r(eof)==0{
	file read `filehandle' line
	local file `file' `line'
	}
file close `filehandle'
if !regexm("`file'" , "\[info\]") & !regexm("`file'" , "v[0-9]*\.[0-9]*\.[0-9]*") {
    di as err "OSRM does not seem to work!"
    di as err "Is it already installed properly?"
    exit
}
else if regexm("`file'" , "[0-9]*\.[0-9]*\.[0-9]*") {
    local osrm_version = regexs(0)
    tokenize "`osrm_version'" , p(".")
    local osrm_ver = `1'
    local subver = `3'
    if (`osrm_ver'==5 & `subver'>22) | `osrm_ver'>5 {
        di as err "Your OSRM version is `osrm_version'!"
        di as err "osrmtime has been tested only with versions 4.9.0 up to 5.26.0!"
        di as err "If you encounter an error, please use one of the tested versions!"
    }
}


cap confirm var distance
if !_rc {
	di as err "distance already defined"
	exit 110
	}
cap confirm var duration
if !_rc {
	di as err "duration already defined"
	exit 110
	}

cap confirm numeric var `varlist'
if _rc {
	di in smcl "{p 0 0 4}{err:All variables specified in varlist must be of type numeric}"
	di
	exit 108
	}

if "`mapfile'"=="" {
	di as err "You must specify a mapfile"
	exit 197
	}
else {
	cap confirm file "`mapfile'"
	if _rc {
		di as err "File `mapfile' does not exist"
		exit 601
		}
	}
if substr(lower("`mapfile'"),-5,.)!=".osrm" {
	di in smcl "{p 0 0 4}{err:Please specify a prepared map with the .osrm ending}"
	exit
	}

* make path of mapfile absolute
local pwd = c(pwd)
if substr("`pwd'",-1,.)=="/" | substr("`pwd'",-1,.)=="\" {
	local pwd = substr("`pwd'",1,length("`pwd'")-1 )
	}
cap confirm file "`pwd'/`mapfile'"
if !_rc {
	if c(os)=="Windows" local mapfile = "`pwd'/`mapfile'"
	else local mapfile = "`pwdir'/`mapfile'"
	}

if regexm("`mapfile'"," ") &c(os)=="Windows" {
	di in smcl "{p 0 0 4}{err:Path provided for your mapfile contains a space character, OSRM does not work with that. Please provide a path without spaces} {break}{err:This is a known bug....}"
	exit
	}


qui count
local N = r(N)
/* check whether enough obs for partitioning */
if `N' < 10*`threads'*`servers' {
	local threads = 1
	local servers = 1
	}

if `N' < 10*`threads'*`servers' {
	/* this is for a nicer output when only few obs*/
	local progress progress
	}


/* making a subdirectory */
cap mkdir osrm_tempfiles

/* check whether length(numlist)==`servers' */
di as txt "Check for running OSRM:" _continue

set  timeout1 1

if "`ports'"=="" {
	local lastport=4999+`servers'
	numlist "5000/`lastport'"
	local ports = r(numlist)
	}

tokenize `ports'
local sum=0
forvalues l=1/`servers' {
	local port`l' = ``l''
	if _rc==2 | _rc==677 local server`l' = 0
	if _rc==672 {
		local server`l' = 1
		local ++sum
		}
	cap file open `filehandle' using "http://127.0.0.1:`port`l''/route/v1/driving/0.0,0.0;0.0,0.0?overview=false" , r
    cap file close `filehandle'
	}
if `sum'==`servers' di as res "{col 25}running!"
else di as res "{col 25}not running!"


else {
	di as txt "Starting OSRM " _continue

	forvalues l= 1/`servers' {
		if `server`l''==0 {
			if c(os)=="Windows" {
				qui file open `filehandle' using osrm_tempfiles/batch`l'.bat , write replace
				file write `filehandle' `"start /MIN /HIGH "OSRM" "`exefile'" "`mapfile'" -i 127.0.0.1 -p `port`l''"'
				file close `filehandle'
				winexec "`c(pwd)'/osrm_tempfiles/batch`l'.bat"
				}
			// else if c(os)=="Unix" {
			else {
				qui file open `filehandle' using osrm_tempfiles/osrm_serv`l'.sh , write replace
				file write `filehandle' `"`exefile' `mapfile' -i 127.0.0.1 -p `port`l''"'
				file close `filehandle'
				shell chmod +x `pwdir'/osrm_tempfiles/osrm_serv`l'.sh
				winexec `pwdir'/osrm_tempfiles/osrm_serv`l'.sh
				}
			}
		}
	/* checking if all servers are ready for requests */
	sleep 5000
	local check=1
	while (`check'<20 & `check' >0){
		local sum=0
		forvalues l=1/`servers' {
			if _rc==2 local server`l' = 0
			if _rc==672 local server`l' = 1
			cap file open `filehandle' using "http://127.0.0.1:`port`l''/route/v1/driving/0.0,0.0;0.0,0.0?overview=false" , r
			local sum = `sum'+`server`l''
            cap file close `filehandle'
			}
		local ++check
		if `sum'==`servers' {
			local check=0
			di as res "{col 25}now running!"
			}
		else {
			sleep 3000
			if int(`check'/4)==`check'/4 di as txt "." _continue
			}
		}
	if `check' != 0 {
		di in smcl "{p 0 0 4}{err:OSRM did not respond within one minute, if you are loading a very large map, wait until it has loaded and type again:}{break}"
		di `"{stata osrmtime `0'}"'
		exit
		}
	}
set timeout1 30


local parts = `threads'*`servers'

if `parts'>1 {
	/* distributed computing */
	/* write do files and partition dataset, the last partition will be for us */
	di as txt "Writing do-files:" _continue


	local l=1
	while `l'<`parts' {
		/* write do file */
		local portnum = int((`l'-1)/`threads')+1 // portnumber for do file
		qui file open `filehandle' using osrm_tempfiles/temp_instance`l'.do , write replace
		file write `filehandle' "* do file generated by osrmtime" _n _n
		file write `filehandle' `"global S_ADO = `"$S_ADO"'"' _n _n
		file write `filehandle' `"adopath + "`c(pwd)'" "' _n
		file write `filehandle' `"cd "`c(pwd)'/osrm_tempfiles""' _n
		file write `filehandle' "capture noi{" _n
		file write `filehandle' "use temp_package_routing`l'" _n _n
		file write `filehandle' "osrminterface `varlist' , port(`port`portnum'') osrmver(`osrm_version')" _n
		file write `filehandle' "}" _n
		file write `filehandle' "if _rc {" _n
		file write `filehandle' "cap confirm var return_code" _n
		file write `filehandle' "if _rc gen return_code=3" _n
		file write `filehandle' "else replace return_code = 3 if return_code==." _n
		file write `filehandle' "}" _n
		file write `filehandle' "save temp_package_routed`l' , replace" _n _n
		file close `filehandle'
		local ++l
		}
	di as res "{col 25}done!"
	di as txt "Partitioning datasets:" _continue


	local partsize = int(`N'/`parts')
	forvalues l=1/`parts' {
		local u = `l'*`partsize'
		if `l'==`parts' local u=`N'
		local d = (`l'-1)*`partsize'+1
		preserve
		qui keep in `d'/`u'
		qui save osrm_tempfiles/temp_package_routing`l' , replace
		restore
		}

	di as res "{col 25}done!"
	}

/* start calculation */
/* find out how stata executable is called */
if c(os)=="Windows" {
	local flavor = c(flavor)
	local bit = c(bit)
	if "`flavor'"!="IC" local exename smStata
	else {
		if c(MP)==1 local exename StataMP
		else if c(SE)==1 local exename StataSE
		else if c(SE)==0 local exename Stata
		}
	if `bit' == 32 local bit
	else local bit -64
	local stata_executable = "`c(sysdir_stata)'`exename'" + "`bit'.exe"
	}
else {
	if c(MP) local exename stata-mp
	else if c(SE) local exename stata-se
	else if c(flavor) == "Small" local exename stata-sm
	else if c(flavor) == "IC" local exename stata
	local stata_executable = "`c(sysdir_stata)'`exename'"
	}
	*di "`stata_executable'"

local tmpdir = c(tmpdir)
if c(os)=="Windows" {
	if substr("`tmpdir'",-1,.)=="/" {
		local tmpdir = substr("`tmpdir'",1,length("`tmpdir'")-1)+"\"
		}
	if substr("`tmpdir'",-1,.)!="\" {
		local tmpdir = "`tmpdir'" + "\"
		}
	}
// else if c(os)=="Unix" {
else {
	if substr("`tmpdir'",-1,.)!="/" {
		local tmpdir = "`tmpdir'" + "/"
		}
	}
* di "`tmpdir'"

if c(os)=="Windows" {
    qui file open `filehandle' using osrm_tempfiles/__tmp_osrm.bat , write replace
    file write `filehandle' "pushd `c(pwd)'\osrm_tempfiles" _n
    file write `filehandle' "del temp_package_routed*" _n
    local l=1
    while `l'<`parts' {
        local tmpdir`l' = "`tmpdir'" + "_osrm12tmpdir00`l'"
        cap erase temp_package_routed`l'
        file write `filehandle' "mkdir `tmpdir`l''" _n
        file write `filehandle' `"start /MIN /HIGH set STATATMP=`tmpdir`l'' ^& "`stata_executable'" /e /q do temp_instance`l'.do ^&exit"' _n
        local ++l
    }
    file write `filehandle' "popd" _n
    file write `filehandle' "exit" _n
    file close `filehandle'
    /* start subroutines */
    winexec `c(pwd)'/osrm_tempfiles/__tmp_osrm.bat
}
else if c(os)=="Unix" {
    qui file open `filehandle' using osrm_tempfiles/__tmp_osrm.sh , write replace
    file write `filehandle' "cd `pwdir'/osrm_tempfiles" _n
    file write `filehandle' "rm -f temp_package_routed*" _n
    local l=1
    while `l'<`parts' {
        local tmpdir`l' = "`tmpdir'" + "_osrm12tmpdir00`l'"
        cap erase temp_package_routed`l'
        file write `filehandle' "mkdir -p `tmpdir`l''" _n
        file write `filehandle' "export STATATMP=`tmpdir`l''" _n
        file write `filehandle' `"`stata_executable' -b -q do temp_instance`l'.do &"' _n
        local ++l
    }
    file write `filehandle' "cd `pwdir'" _n
    file close `filehandle'
    /* start subroutines */
    shell chmod +x `pwdir'/osrm_tempfiles/__tmp_osrm.sh
    winexec `pwdir'/osrm_tempfiles/__tmp_osrm.sh
}
else if c(os)=="MacOSX" {
    file open `filehandle' using osrm_tempfiles/__tmp_osrm.sh , write replace
    file write `filehandle' "cd `pwdir'/osrm_tempfiles" _n
    file write `filehandle' "rm temp_package_routed*" _n
    local l=1
    while `l'<`parts' {
        local tmpdir`l' = "`tmpdir'" + "_osrm12tmpdir00`l'"
        cap erase temp_package_routed`l'
        file write `filehandle' "mkdir -p `tmpdir`l''" _n
        file write `filehandle' "export STATATMP=`tmpdir`l''" _n
        file write `filehandle' `"`stata_executable' -e -q do temp_instance`l'.do &"' _n
        local ++l
    }
    file write `filehandle' "cd `pwdir'" _n
    file close `filehandle'
    /* start subroutines */
    shell chmod +x `pwdir'/osrm_tempfiles/__tmp_osrm.sh
    winexec `pwdir'/osrm_tempfiles/__tmp_osrm.sh
}

di as txt "Calculating:"
//if "`adopath'" !="" adopath ++ `adopath'
local srvnum = int((`l'-1)/`threads')+1
// di `srvnum'
if "`verbose'"!="" local progress

if `parts' > 1{
    use osrm_tempfiles/temp_package_routing`l' , clear
}
osrminterface `varlist' , port(`port`srvnum'') `verbose' `progress' linewidth(`linelength') osrmver(`osrm_version')
if `parts' > 1 {
    qui save osrm_tempfiles/temp_package_routed`l' , replace

    /* collecting datasets when finished */

    local bool=1
    while `bool' {
        local sum = 0
        forvalues l=1/`parts'{
            cap confirm file osrm_tempfiles/temp_package_routed`l'.dta
            if !_rc local ++sum
        }
        if `sum'==`parts' local bool=0
        else sleep 1000
    }

    use osrm_tempfiles/temp_package_routed1 , clear
    forvalues l=2/`parts' {
        append using osrm_tempfiles/temp_package_routed`l'
    }
}

/* cleanup */
if "`cleanup'"=="" {
    if c(os)=="Windows" {
        shell taskkill /F /IM osrm-routed.exe
        local l = 1
        while `l'<`parts' {
            shell rmdir `tmpdir`l''
            local ++l
        }
        shell rmdir /S /Q osrm_tempfiles
    }
    // else if c(os)=="Unix" {
    // pkill available on macosx?
    else {
        shell pkill -x osrm-routed
        local l = 1
        while `l'<`parts' {
            shell rm -r -f `tmpdir`l''
            local ++l
        }
        shell rm -r -f osrm_tempfiles
    }
}
di
di
label var distance "Distance of shortest route in meters"
label var duration "Duration of shortest route in seconds"
label var jumpdist1 "Jump distance (in meters) of starting point to road network"
label var jumpdist2 "Jump distance (in meters) of ending point to road network"

label define osrmreturncode 0 "OK" 1 "no route found" 2 "OSRM did not respond" 3 "error" , replace
label values return_code osrmreturncode

di "{res:finished calculation!}"
di as txt "{hline `linelength'}"
end
