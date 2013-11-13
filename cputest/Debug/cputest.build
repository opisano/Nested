set PATH=C:\D\dmd2\windows\bin;C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\\bin;%PATH%
set DMD_LIB=;D:\documents\GitHub\Derelict3\lib

echo ..\nested\common.d >Debug\cputest.build.rsp
echo ..\nested\console.d >>Debug\cputest.build.rsp
echo ..\nested\controller.d >>Debug\cputest.build.rsp
echo ..\nested\cpu.d >>Debug\cputest.build.rsp
echo ..\nested\file\ines.d >>Debug\cputest.build.rsp
echo main.d >>Debug\cputest.build.rsp
echo ..\nested\memory.d >>Debug\cputest.build.rsp
echo ..\nested\ppu.d >>Debug\cputest.build.rsp
echo ..\nested\file\rom.d >>Debug\cputest.build.rsp

dmd -g -debug -X -Xf"Debug\cputest.json" -I"D:\documents\GitHub\Nested\nested" -ID:\documents\GitHub\Derelict3\import -deps="Debug\cputest.dep" -c -of"Debug\cputest.obj" @Debug\cputest.build.rsp
if errorlevel 1 goto reportError

set LIB="C:\D\dmd2\windows\bin\..\lib"
echo. > Debug\cputest.build.lnkarg
echo "Debug\cputest.obj","Debug\cputest.exe_cv","Debug\cputest.map",DerelictSDL2.lib+ >> Debug\cputest.build.lnkarg
echo DerelictUtil.lib+ >> Debug\cputest.build.lnkarg
echo user32.lib+ >> Debug\cputest.build.lnkarg
echo kernel32.lib+ >> Debug\cputest.build.lnkarg
echo D:\documents\GitHub\Derelict3\lib\/NOMAP/CO/NOI >> Debug\cputest.build.lnkarg

"C:\Program Files (x86)\VisualD\pipedmd.exe" -deps Debug\cputest.lnkdep C:\D\dmd2\windows\bin\link.exe @Debug\cputest.build.lnkarg
if errorlevel 1 goto reportError
if not exist "Debug\cputest.exe_cv" (echo "Debug\cputest.exe_cv" not created! && goto reportError)
echo Converting debug information...
"C:\Program Files (x86)\VisualD\cv2pdb\cv2pdb.exe" "Debug\cputest.exe_cv" "Debug\cputest.exe"
if errorlevel 1 goto reportError
if not exist "Debug\cputest.exe" (echo "Debug\cputest.exe" not created! && goto reportError)

goto noError

:reportError
echo Building Debug\cputest.exe failed!

:noError
