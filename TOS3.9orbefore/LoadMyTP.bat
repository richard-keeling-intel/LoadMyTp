@echo off
REM ^ Tells the script to not display every command and its output in the terminal which is done otherwise by default. However the 'echo off' line will be displayed unless you add a '@' in front. 											

REM Ver1 - Inital rev that loads, inits and does PGmemory dump.
REM Ver2 - Measures and stores load and init times.
REM Ver3 - Autounload at start, ituff auto start, and save ituff at TP unload
REM Ver4 - Stops if your tape fails to init.

REM Set window size to something more sensible
MODE 140,30


REM Let's unload a TP, incase there's already a tape loaded.
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe unloadTP 

REM Create a folder for all console capture output.
if not exist %~dp0PDEdebug mkdir %~dp0PDEdebug

REM Create a dateseed for log file naming, that won't have spaces due to non-24hour numbers.
set hh=%time:~-11,2%
set /a hh=%hh%+100
set hh=%hh:~1%
set dateseed=%date:~10,4%%date:~4,2%%date:~7,2%_%hh%%time:~3,2%%time:~6,2%

REM Let's get the parent directory name in case this is a renamed tape.
for %%a in ("%~dp0\.") do set "parent=%%~nxa"		

REM Store console for storing load and initing.
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe startConsolidatedLogging %~dp0PDEdebug\loadinitlog_%dateseed%.log true
cls

REM get the time and remove whitepsace formating.
set STARTTIME=%time% 
set "STARTTIME=%STARTTIME: =0%"
													
REM Load my test program if it's either named or renamed, and record the load time.						
if exist BaseTestPlan.tpl (
     title LoadMyTP:%parent%
	 echo Loading %~dp0
     echo Started at %STARTTIME% please wait...
	 echo NOTE: Script will exit if there is a TP load fail or init fail. Check HDMT Site Controller console window for more info.
     %HDMTTOS%\Runtime\Release\singlescriptcmd.exe loadTP %~dp0BaseTestPlan.tpl %~dp0PLIST_ALL.xml %~dp0EnvironmentFile_!ENG!.env %~dp0SubTestPlan_SDS_EBG.stpl %~dp0SDX_PCH_X2_12.soc                                        
) else (
     if exist EnvironmentFile_!ENG!.env (
		title LoadMyTP:%parent%
	    echo Loading %~dp0
		echo Started at %STARTTIME% please wait...
		echo NOTE: Script will exit if there is a TP load fail or init fail. Check HDMT Site Controller console window for more info.
		%HDMTTOS%\Runtime\Release\singlescriptcmd.exe loadTP %~dp0%parent%.tpl %~dp0PLIST_ALL.xml %~dp0EnvironmentFile_!ENG!.env %~dp0%parent%.stpl %~dp0SDX_PCH_X2_12.soc
	) else (
		title LoadMyTP:%parent%
	 	echo Loading %~dp0
		echo Started at %STARTTIME% please wait...
		echo NOTE: Script will exit if there is a TP load fail or init fail. Check HDMT Site Controller console window for more info.
		%HDMTTOS%\Runtime\Release\singlescriptcmd.exe loadTP %~dp0%parent%.tpl %~dp0PLIST_ALL.xml %~dp0EnvironmentFile.env %~dp0%parent%.stpl %~dp0SDX_PCH_X2_12.soc
	 )
)
call:WorkOutTimeTaken
REM Record the load time.
echo My Test Program Load Time is %DURATIONH%:%DURATIONM%:%DURATIONS%> %~dp0PDEdebug\LoadandInitTimes_%dateseed%.log

REM Let's init the tape and record the init time..
echo Initing your tape....
set STARTTIME=%time% 
set "STARTTIME=%STARTTIME: =0%"

REM Let's ensure that the TP is initing succesfully. Using the 2nd token after "equal" sign on the last string of the init output log. If it fails to init, exit there and then.
set INITCHECK=
for /f "tokens=2delims==" %%i in ('%HDMTTOS%\Runtime\Release\singlescriptcmd.exe init') do set INITCHECK=%%i
echo test is [%INITCHECK%]
if %INITCHECK%==Pass (
    echo Init did pass.
	) 
else (
	echo Init did not pass.
	msg "%username%" ERROR: TP failed to init. Please check your test program. LoadMyTP.bat will quit.
	pause
	exit
   )
echo .
echo Program is Loaded & inited.
echo .

call:WorkOutTimeTaken
echo My Init Time is %DURATIONH%:%DURATIONM%:%DURATIONS% >> %~dp0PDEdebug\LoadandInitTimes_%dateseed%.log

REM close the console.
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe stopConsolidatedLogging 

:choice
REM Every time we come here we start a new generic log and set the ituff.
set hh=%time:~-11,2%
set /a hh=%hh%+100
set hh=%hh:~1%
Set dateseed=%date:~10,4%%date:~4,2%%date:~7,2%_%hh%%time:~3,2%%time:~6,2%
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe startConsolidatedLogging %~dp0PDEdebug\Console_%dateseed%.log true
REM Update the ituff name and start the lot.
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe setUserVar SCVars SC_SUMMARY_NAME %parent%_%dateseed%.ituff
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe startLot
cls
echo LoadMyTP.bat Ver4 - Stops if your tape fails to init.
echo .
echo Console log file is %~dp0PDEdebug\Console_%dateseed%.log
echo The ituff is started and is at %HDMTTOS%\%parent%_%dateseed%.ituff
echo .
echo Ok your tape %parent% is loaded and inited, enjoy!

REM Leave at a place where  the user can do a PGMemory dump or just unload and exit.
echo .
echo . P to do a PGMemoryDump
echo . U to unload this tape, store ituff to PDEdebug and exit
echo .
set /P c=. Type P or U and enter.
if /I "%c%" EQU "P" goto :PGMemoryDump
if /I "%c%" EQU "U" goto :UnloadMyTape
goto :choice

:WorkOutTimeTaken
set ENDTIME=%time%
set "ENDTIME=%ENDTIME: =0%"
set /A STARTTIME=(1%STARTTIME:~0,2%-100)*360000 + (1%STARTTIME:~3,2%-100)*6000 + (1%STARTTIME:~6,2%-100)*100 + (1%STARTTIME:~9,2%-100)
set /A ENDTIME=(1%ENDTIME:~0,2%-100)*360000 + (1%ENDTIME:~3,2%-100)*6000 + (1%ENDTIME:~6,2%-100)*100 + (1%ENDTIME:~9,2%-100)
set /A DURATION=ENDTIME-STARTTIME
if %ENDTIME% LSS %STARTTIME% set /A DURATION=STARTTIME-ENDTIME
REM now break the centiseconds down to hours, minutes, seconds and the remaining centiseconds
set /A DURATIONH=%DURATION% / 360000
set /A DURATIONM=(%DURATION% - %DURATIONH%*360000) / 6000
set /A DURATIONS=(%DURATION% - %DURATIONH%*360000 - %DURATIONM%*6000) / 100
set /A DURATIONHS=(%DURATION% - %DURATIONH%*360000 - %DURATIONM%*6000 - %DURATIONS%*100)
REM some formatting
if %DURATIONH% LSS 10 set DURATIONH=0%DURATIONH%
if %DURATIONM% LSS 10 set DURATIONM=0%DURATIONM%
if %DURATIONS% LSS 10 set DURATIONS=0%DURATIONS%
if %DURATIONHS% LSS 10 set DURATIONHS=0%DURATIONHS%
goto:eof

:PGMemoryDump
REM Stop the console, and create a file just for the PGMemory dump
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe stopConsolidatedLogging 

echo Creating PGMemoryDump%dateseed%.log
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe startConsolidatedLogging %~dp0PDEdebug\PGMemoryDump_%dateseed%.log true

echo setting init to do a PGMemoryDump
set INIT_TEST=CTRL_X_X_K_INIT_X_X_X_X_INIT
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe setInstanceParam TPI_BASE::%INIT_TEST%  enable_PG_memory_dump TRUE
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe executeTestInstance TPI_BASE::%INIT_TEST%  
REM Give 10s delay as pgmemory takes approx 8s
timeout 10 > NUL
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe setInstanceParam TPI_BASE::%INIT_TEST%  enable_PG_memory_dump FALSE
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe stopConsolidatedLogging 
REM Make sure everything is init'd cleanly after PGmemory dump execution, as test unit B98s have been observed after performing memory dumps.
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe init	
goto :choice

:UnloadMyTape
echo Storing ituff, closing log, and unloading test program.
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe endLot
copy %HDMTTOS%\%parent%_%dateseed%.ituff %~dp0PDEdebug\%parent%_%dateseed%_copied.ituff
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe stopConsolidatedLogging 
%HDMTTOS%\Runtime\Release\singlescriptcmd.exe unloadTP
echo Copied ituff to %~dp0PDEdebug\%parent%_%dateseed%_copied.ituff
echo Closing console, and unloaded test program.
