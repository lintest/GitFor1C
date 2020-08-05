# GitFor1C - внешняя компонента 1С

Разработана по технологии Native API, использует библиотеку [**libgit2**](https://libgit2.org/).

Сборка библиотеки **libgit2** для Windows. 
```bat
cd libgit2-1.0.1 

mkdir build32
cd build32
cmake .. -DBUILD_CLAR=OFF -DBUILD_SHARED_LIBS=OFF -DEMBED_SSH_PATH="../../libssh2-1.9.0" -A Win32
cmake --build . --config Release
cd ..

mkdir build64
cd build64
cmake .. -DBUILD_CLAR=OFF -DBUILD_SHARED_LIBS=OFF -DEMBED_SSH_PATH="../../libssh2-1.9.0" -A x64
cmake --build . --config Release
cd ..
```