```bat
cd libgit2-1.0.1 

mkdir build32
cd build32
cmake .. -DBUILD_CLAR=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DEMBED_SSH_PATH="C:/Cpp/libssh2-1.9.0" -A Win32
cmake --build . --config Release--config Release
cd ..

mkdir build64
cd build64
cmake .. -DBUILD_CLAR=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DEMBED_SSH_PATH="C:/Cpp/libssh2-1.9.0" -A x64
cmake --build . --config Release--config Release
cd ..
```