SET libgit2v="1.1.0"
SET libssh2v="1.9.0"

if NOT EXIST "%CD%\libgit2-%libgit2v%" bitsadmin /transfer mydownloadjob /download /priority FOREGROUND "https://github.com/libgit2/libgit2/archive/v%libgit2v%.zip" "%CD%\libgit2-%libgit2v%.zip"
if NOT EXIST "%CD%\libgit2-%libgit2v%" powershell Expand-Archive "%CD%\libgit2-%libgit2v%.zip" -DestinationPath "%CD%"

if NOT EXIST "%CD%\libssh2-%libssh2v% " bitsadmin /transfer mydownloadjob /download /priority FOREGROUND "https://github.com/libssh2/libssh2/archive/libssh2-%libssh2v%.zip" "%CD%\libssh2-%libssh2v%.zip"
if NOT EXIST "%CD%\libssh2-%libssh2v%" powershell Expand-Archive "%CD%\libssh2-%libssh2v%.zip" -DestinationPath "%CD%"
ren libssh2-libssh2-1.9.0 libssh2-1.9.0

mkdir build32
cd build32
cmake .. -A Win32 -DMySuffix2=32
cmake --build . --config Release --target GitFor1C
cd ..

mkdir build64
cd build64
cmake .. -A x64 -DMySuffix2=64
cmake --build . --config Release --target GitFor1C
cd ..

oscript .\tools\MakePack.os

mkdir .\Example\Templates\VAEditor
mkdir .\Example\Templates\VAEditor\Ext
copy /b ..\VAEditor\example\VanessaEditorSample\Templates\VanessaEditor\Ext\Template.bin .\Example\Templates\VAEditor\Ext\Template.bin

mkdir .\Example\Templates\GitFor1C
mkdir .\Example\Templates\GitFor1C\Ext
copy /b .\AddIn.zip .\Example\Templates\GitFor1C\Ext\Template.bin

oscript .\tools\Compile.os .\