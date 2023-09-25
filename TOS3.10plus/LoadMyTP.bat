@echo off
REM ^ Tells the script to not display every command and its output in the terminal which is done otherwise by default. However the 'echo off' line will be displayed unless you add a '@' in front. 											

Set CURRENT_TP_DIR=%cd%
REM Let's hard code the TP inputs, if it can't find these files, it will find the closest match.
SET TP_TPL=BaseTestPlan.tpl
SET TP_PLIST=PLIST_ALL.plist.xml
SET TP_STPL=SubTestPlan.stpl
SET TP_SOCKET=SDX.soc

REM Set window size to something more sensible
MODE 140,30

REM Let's kill any existing running TPload batch scripts by calling our script dontcloseme, task killing any LoadMyTP windows, and then renaming ours back to LoadMyTP
title dontcloseme
taskkill /FI "WINDOWTITLE eq Administrator:  LoadMyTP" /T /F
title LoadMyTP

REM Let's restart a TP, incase there's already a tape loaded.
SET /P restartSelection="Do you want to restart HDMT TOS? (<Enter> will also restart HDMT TOS) (Y/N): " || SET restartSelection=Y
IF "%restartSelection%" == "Y" (
	ECHO Please wait for HDMT TOS to restart
	hdmttosctrl restarttos
)

REM Create a folder for all console capture output.
SET PDEdebug=%cd%\\Reports\PDEdebug
if not exist %PDEdebug% mkdir %PDEdebug%

REM Create a dateseed for log file naming, that won't have spaces due to non-24hour numbers.
set hh=%time:~-11,2%
set /a hh=%hh%+100
set hh=%hh:~1%
set dateseed=%date:~10,4%%date:~4,2%%date:~7,2%_%hh%%time:~3,2%%time:~6,2%

REM Store console for storing load and initing.
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe startConsolidatedLogging %PDEdebug%\loadinitlog_%dateseed%.log true
cls

REM get the time and remove whitepsace formating.
set STARTTIME=%time% 
set "STARTTIME=%STARTTIME: =0%"

:: Search tpl/stpl/env/soc
:: Target for SORT TP after CAKE rename
IF NOT EXIST "%CURRENT_TP_DIR%\%TP_TPL%" (
	FOR %%T IN (%CURRENT_TP_DIR%\*.tpl) DO (
		SET TP_TPL=%%~nxT
		GOTO TPL_FOUND
	)
	:TPL_FOUND
	ECHO Found TPL: %TP_TPL%
)

IF NOT EXIST "%CURRENT_TP_DIR%\%TP_STPL%" (
	FOR %%S IN (%CURRENT_TP_DIR%\*.stpl) DO (
		SET TP_STPL=%%~nxS
		GOTO STPL_FOUND
	)
	:STPL_FOUND
	ECHO Found STPL: %TP_STPL%
)

if not exist %TP_PLIST% SET TP_PLIST=PLIST_ALL.xml

IF NOT EXIST "%CURRENT_TP_DIR%\%TP_SOCKET%" (
	FOR %%X IN (%CURRENT_TP_DIR%\*.soc) DO (
		SET TP_SOCKET=%%~nxX
		GOTO SOCKET_FOUND
	)
	:SOCKET_FOUND
	ECHO Found SOC: %TP_SOCKET%
)
													
REM Load my test program if it's either named or renamed, and record the load time.						
 if exist EnvironmentFile_!ENG!.env (
	echo Loading %cd%\
	echo Started at %STARTTIME% please wait...
	echo NOTE: Script will exit if there is a TP load fail or init fail. Check HDMT Site Controller console window for more info.
	%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe loadTP "%CURRENT_TP_DIR%" "%TP_TPL%" "%TP_PLIST%" EnvironmentFile_!ENG!.env "%TP_STPL%" "%TP_SOCKET%" 
) else (
	echo Loading %cd%\
	echo Started at %STARTTIME% please wait...
	echo NOTE: Script will exit if there is a TP load fail or init fail. Check HDMT Site Controller console window for more info.
	%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe loadTP "%CURRENT_TP_DIR%" "%TP_TPL%" "%TP_PLIST%" EnvironmentFile.env "%TP_STPL%" "%TP_SOCKET%" 
 )

call:WorkOutTimeTaken
REM Record the load time.
echo My Test Program Load Time is %DURATIONH%:%DURATIONM%:%DURATIONS%> %PDEdebug%\LoadandInitTimes_%dateseed%.log

REM Let's init the tape and record the init time..
echo Initing your tape....
set STARTTIME=%time% 
set "STARTTIME=%STARTTIME: =0%"

REM Let's ensure that the TP is initing succesfully. Using the 2nd token after "equal" sign on the last string of the init output log. If it fails to init, exit there and then.
set INITCHECK=
for /f "tokens=2delims==" %%i in ('%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe init') do set INITCHECK=%%i
echo test is [%INITCHECK%]
if %INITCHECK%==Pass (
    echo Init did pass.
) else (
	echo Init did not pass.
	msg "%username%" ERROR: TP failed to init. Please check your test program. LoadMyTP.bat will quit.
	pause
	exit
   )
echo .
echo Program is Loaded & inited.
echo .

call:WorkOutTimeTaken
echo My Init Time is %DURATIONH%:%DURATIONM%:%DURATIONS% >> %PDEdebug%\LoadandInitTimes_%dateseed%.log

REM close the console.
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe stopConsolidatedLogging 

:choice
REM Every time we come here we start a new generic log and set the ituff.
set hh=%time:~-11,2%
set /a hh=%hh%+100
set hh=%hh:~1%
Set dateseed=%date:~10,4%%date:~4,2%%date:~7,2%_%hh%%time:~3,2%%time:~6,2%
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe startConsolidatedLogging %PDEdebug%\Console_%dateseed%.log true
REM Update the ituff name and start the lot.
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe setUserVar SCVars SC_SUMMARY_NAME %CURRENT_TP_DIR%_%dateseed%.ituff
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe startLot
cls
echo LoadMyTP.bat Ver39 - Stops if your tape fails to init.
echo .
echo Console log file is %PDEdebug%\Console_%dateseed%.log
echo The ituff is started and is at %HDMTTOS%\%CURRENT_TP_DIR%_%dateseed%.ituff
echo .
echo Ok your tape %CURRENT_TP_DIR% is loaded and inited, enjoy!

REM Leave at a place where  the user can do a PGMemory dump or just unload and exit.
echo .
echo . P to do a PGMemoryDump
echo . U to store ituff to PDEdebug and restart TOS.
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
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe stopConsolidatedLogging 

echo Creating PGMemoryDump%dateseed%.log
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe startConsolidatedLogging %PDEdebug%\PGMemoryDump_%dateseed%.log true

echo setting init to do a PGMemoryDump
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe setInstanceParam TPI_BASE::CTRL_X_X_K_INIT_X_X_X_X_INIT enable_PG_memory_dump TRUE
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe executeTestInstance TPI_BASE::CTRL_X_X_K_INIT_X_X_X_X_INIT 
REM Give 10s delay as pgmemory takes approx 8s
timeout 10 > NUL
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe setInstanceParam TPI_BASE::CTRL_X_X_K_INIT_X_X_X_X_INIT enable_PG_memory_dump FALSE
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe stopConsolidatedLogging 
REM Make sure everything is init'd cleanly after PGmemory dump execution, as test unit B98s have been observed after performing memory dumps.
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe init	
goto :choice

:UnloadMyTape
echo Storing ituff, closing log, and unloading test program.
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe endLot
copy %HDMTTOS%\%CURRENT_TP_DIR%_%dateseed%.ituff %PDEdebug%\%CURRENT_TP_DIR%_%dateseed%_copied.ituff
%HDMTTOS%\Runtime\Release\SingleScriptCmd.exe stopConsolidatedLogging 
echo Copied ituff to %cd%\PDEdebug\%CURRENT_TP_DIR%_%dateseed%_copied.ituff
echo Closing console, and doing a  restart
hdmttosctrl restarttos
