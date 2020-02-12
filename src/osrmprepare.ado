*! version 1.3.2 , 10nov2017
*! osrmprepare.ado
*! christoph.rust@wiwi.uni-regensburg.de
*! stephan.huber@wiwi.uni-regensburg.de
*! now working with OSRM versions 4.9.0 up to 5.14.0

// cap program drop osrmprepare

program define osrmprepare
version 12.0

syntax , mapfile(string) [ osrmdir(string) diskspace(integer 5000) profile(name) stxxldir(string)]

/* profile */
if "`profile'"=="" local profile car
if !("`profile'"=="car" | "`profile'"=="bicycle" | "`profile'"=="foot") {
	di in smcl "{p 0 0 4}{err:Profile must be either} {inp:car}{err:,} {inp:bicycle} {err:or} {inp:foot.} {break}{err:If you want to specify your own speed profile, please name it either} {inp:car.lua}{err:,} {inp:bycicle.lua} {err:or} {inp:foot.lua}" 
	exit 110
	}

/* mapfile */
if substr("`mapfile'",-8,.)==".osm.pbf" {
	local map=substr("`mapfile'",1,length("`mapfile'")-8)
	}
else if substr("`mapfile'",-8,.)==".osm.bz2"{
	local map=substr("`mapfile'",1,length("`mapfile'")-8)
	}
else if substr("`mapfile'",-4,.)==".osm"{
	local map=substr("`mapfile'",1,length("`mapfile'")-4)
	}
else {
	di in smcl "{p 0 0 4}{err:OSRM is only capable to parse .osm (XML) formatted data and pbf or bzip2 compressed files, please use an appropriate file ending!}"
	di
	exit 198
	}

cap confirm file "`mapfile'"
if _rc {
	di as err "`mapfile' not found"
	exit 198
	}

* make path of mapfile absolute
local pwd = c(pwd)
if substr("`pwd'",-1,.)=="/" | substr("`pwd'",-1,.)=="\" {
	local pwd = substr("`pwd'",1,length("`pwd'")-1 )
	}

cap confirm file "`pwd'/`mapfile'"
if !_rc {
	local mapfile = "`pwd'/`mapfile'"
	local map = "`pwd'/`map'"
	}

if regexm("`mapfile'"," ") &c(os)=="Windows" {
	di in smcl "{p 0 0 4}{err:Path provided for your mapfile contains a space character, OSRM does not work with that. Please provide a path without spaces} {break}{err:This is a known bug....}"
	exit
	}

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
                di as err "Could not find OSRM executable"
                exit
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

/* temp directory for stxxl */
if "`stxxldir'"!="" local tmpdir = "`stxxldir'"
else local tmpdir=c(tmpdir)

if (substr("`tmpdir'",-1,.)=="/" | substr("`tmpdir'",-1,.)=="\") {
	local tmpdir = substr("`tmpdir'",1,length("`tmpdir'")-1)
	}


if c(os)=="Windows" local exefile="`osrmdir'\osrm-routed.exe"
else  local exefile="`osrmdir'/osrm-routed"

/* adjust path for linux and Mac */
if c(os)!="Windows"{
	local exefile = subinstr("`exefile'"," ","\ ",.)
	local mapfile = subinstr("`mapfile'"," ","\ ",.)
	}

/* check if we can write into this directory */
cap file open test using _tmp.test , write replace
if !_rc {
	file close test
	cap erase _tmp.test
	}
else {
	di as err "Stata cannot write into `c(pwd)'"
	exit 603
	}

/* check for running OSRM */
tempfile output
if c(os)=="Windows" shell "`exefile'" -v > `output' 2>&1
else shell `exefile' -v > `output' 2>&1
cap file open testfile using `output' , read
if !_rc {
	file read testfile file
	while r(eof)==0{
		file read testfile line
		local file `file' `line'
		}
	file close testfile
	}
if !regexm("`file'" , "\[info\]") & !regexm("`file'" , "v[0-9]*\.[0-9]*\.[0-9]*") {
	di as err "OSRM does not seem to work!"
	di as err "Did you install properly?"
	di as err "Shell output:"
	di `"{p}{txt:`file'}"'
	exit
	}
else if regexm("`file'" , "[0-9]*\.[0-9]*\.[0-9]*") {
    local osrm_version = regexs(0)
    tokenize "`osrm_version'" , p(".")
    local mainver = `1'
    local subver = `3'
    if "`osrm_version'"!="4.9.0" & ((`mainver'==5 & `subver' >14) | `mainver'>5 ){
        di as err "Your OSRM version is `osrm_version'!"
        di as err "osrmtime has been tested only with versions 4.9.0 up to 5.14.0!"
        di as err "If you encounter an error, please use one of these versions!"

    }
}




	
if c(os)=="Windows" {
	qui file open stxxl using "`osrmdir'\.stxxl.txt" , write replace
	file write stxxl "disk=`tmpdir'\stxxl,`diskspace',wincall" _n
	file close stxxl
	
	qui file open bat using _osrm_prepare.bat , write replace
	file write bat "REM batch file generatet by stata program osrmprepare" _n _n
	file write bat `"pushd "`osrmdir'""' _n
	file write bat `"osrm-extract.exe "`mapfile'" -p `profile'.lua"' _n
	if `mainver'==4 file write bat `"osrm-prepare.exe "`map'.osrm" -p `profile'.lua"' _n
    if `mainver'>=5 file write bat `"osrm-contract.exe "`map'.osrm""' _n
	file write bat "popd" _n
	file close bat
	shell _osrm_prepare.bat
	cap confirm file "`map'.osrm.hsgr"
	if _rc {
		di as err "{p 0 0 4} {err:Preparation was not successful, something went wrong.}{break}{err:Possible reasons:}"
		di
		di "{p 4 8 4} {res:- Your disk does not provide enough space, or your map is to large} {break} {txt: specifiy more space with diskspace(), or enlarge your hard disk} {inp:diskspace().}{break}{txt:If you really need more space you might also specify a directory of your choice for stxxl-swap by specifying} {inp:stxxldir()}"
		di
		di  "{p 4 4 4} {res:- Input (map) file not valid}{break}{res:.}{break}{res:.}{break}{res:.}{break}"
		di
		di `"{p 0 0 4}{txt:In order to find out, what caused the error, you may type the following command in a command-shell (cmd)}{break}{inp:"`pwd'\_osrm_prepare.bat"}"'
		cap erase "`tmpdir'/stxxl"
		exit
		}
	cap erase _osrm_prepare.bat
	}

else {
	qui file open stxxl using "`osrmdir'/.stxxl" , write replace
	file write stxxl "disk=`tmpdir'/stxxl,`diskspace',syscall" _n
	file close stxxl
	
	qui file open shell using _osrm_prepare.sh , write replace
	file write shell "# Shell file generated by stata program osrmprepare" _n
	file write shell `"cd `osrmdir'"'_n
	file write shell `"./osrm-extract `mapfile' -p `profile'.lua"' _n
	if `mainver'==4 file write shell `"./osrm-prepare `map'.osrm -p `profile'.lua"' _n
    else if `mainver'>=5 file write shell `"./osrm-contract `map'.osrm"' _n
	file close shell
	shell chmod +x _osrm_prepare.sh
	shell ./_osrm_prepare.sh
	cap confirm file "`map'.osrm.hsgr"
	if _rc {
		di as err "{p 0 0 4} {err:Preparation was not successful, something went wrong.}{break}{err:Possible reasons:}"
		di
		di "{p 4 8 4} {res:- Your disk does not provide enough space, or your map is to large} {break} {txt: specifiy more space with diskspace(), or enlarge your hard disk} {inp:diskspace().}{break}{txt:If you really need more space you might also specify a directory of your choice for stxxl-swap by specifying} {inp:stxxldir()}"
		di
		di  "{p 4 4 4} {res:- Input (map) file not valid}{break}{res:.}{break}{res:.}{break}{res:.}{break}"
		di
		di in smcl `"{p 0 0 4}{txt:In order to find out, what caused the error, you may type the following command in a shell}{break}{inp:`pwd'/_osrm_prepare.sh}"'
		cap erase "`tmpdir'/stxxl"
		exit
		}
	cap erase _osrm_prepare.sh
	}

cap erase "`tmpdir'/stxxl"
end
