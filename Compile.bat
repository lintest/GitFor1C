mkdir build32Win
cd build32Win
cmake .. -A Win32 -DMySuffix2=32
cmake --build . --config Release
cd ..

mkdir build64Win
cd build64Win
cmake .. -A x64 -DMySuffix2=64
cmake --build . --config Release
cd ..

oscript .\tools\MakePack.os

mkdir .\Example\Templates\VAEditor
mkdir .\Example\Templates\VAEditor\Ext
copy /b ..\VAEditor\example\VanessaEditorSample\Templates\VanessaEditor\Ext\Template.bin .\Example\Templates\VAEditor\Ext\Template.bin 

mkdir .\Example\Templates\GitFor1C
mkdir .\Example\Templates\GitFor1C\Ext
copy /b .\AddIn.zip .\Example\Templates\GitFor1C\Ext\Template.bin 

oscript .\tools\Compile.os .\