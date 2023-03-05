@echo off
::::::::::::::::::::::::::::::
  :PreCheck
     setlocal
       for /f "tokens=3 delims=\ " %%A in ('whoami /groups^|find "Mandatory Label"') do set LEVEL=%%A
       if not "%LEVEL%"=="High"  goto GETadmin
     goto Execute
  :GETadmin
     endlocal
     echo "%~nx0": elevating self
     echo    Are you OK ?
     del "%temp%\getadmin.vbs"                                    2>NUL
       set vbs=%temp%\getadmin.vbs
       echo Set UAC = CreateObject^("Shell.Application"^)          >> "%vbs%"
       echo Dim stCmd                                              >> "%vbs%"
       echo stCmd = "/c """"%~s0"" " ^& "%~dp0" ^& Chr(34)         >> "%vbs%"
       echo UAC.ShellExecute "cmd.exe", stCmd, "", "runas", 1      >> "%vbs%"
       pause
       "%temp%\getadmin.vbs"
     del "%temp%\getadmin.vbs"
     goto :eof
  :Execute
     endlocal
::::::::::::::::::::::::::::::
::::::::::
set "directory=C:\Windows\System32\DriverStore\FileRepository"
dir /b "%directory%\nv_disp*" /A:-d >NUL 2>&1 || echo "ファイル"は無し : OK
dir /b "%directory%\nv_disp*" /A:d && echo 存在確認 : OK

::::::::::
for /f %%A in ('dir /b ^"%directory%\nv_disp*^" /A:d') do @echo.&&@echo.^<%%A^>&&@dir /b "%directory%\%%A" /A:d
echo.
echo.

::::::::::
set "Dir=%~1"
echo 　コピーするドライバーのバージョン名を入力してください
echo 　例）...version...: 526.98
echo.
set /p "number=...version...: "
echo.
echo.
echo 　コピーするフォルダー名を入力してください（"NVWMI" が含まれるディレクトリを入力）
echo 　例）...nv_dispi～.inf_amd64_～...: nv_dispsig.inf_amd64_3785fc0bbhsid471
echo.
set /p "Folder=...nv_dispi～.inf_amd64_～...: "
set "send=%Dir%Drivers\%number%"
set "send_1=%send%\System32\HostDriverStore\FileRepository\%Folder%"
set "send_2=%send%\System32"

::::::::::
xcopy "%directory%\%Folder%" "%send_1%" /i /c /f /e /s /h /k /r
xcopy "C:\Windows\System32\NV*.*" "%send_2%" /i /c /f /h /k /r

::::::::::
pause
exit
