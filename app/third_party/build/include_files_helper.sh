#!/bin/bash
# To get the third party deps to build, we do some string replacement in the
# headers. In principle, this should be done with include paths, but since
# users of our tool probably have their own means of managing dependencies,
# this is good enough for our purposes.
curdir=$(dirname "$0")/
echo "current dir is $curdir"
if [ ! -d ${curdir}../../src/main/cpp/libogg ]; then
  mkdir ${curdir}../../src/main/cpp/libogg
fi

if [ ! -d ${curdir}../../src/main/cpp/libopus ]; then
mkdir ${curdir}../../src/main/cpp/libopus
fi

if [ ! -d ${curdir}../../src/main/cpp/opus_tools ]; then
  mkdir ${curdir}../../src/main/cpp/opus_tools
fi

# Handles extern c for opus_header.h.
if ! grep -q 'extern "C"' ${curdir}../opus_tools/src/src/opus_header.h ;then
  sed -i 's/#endif/#ifdef __cplusplus\n}\n#endif\n\n#endif/' ${curdir}../opus_tools/src/src/opus_header.h
  sed -i 's/typedef struct {/#ifdef __cplusplus\nextern \"C\" {\n#endif\n\ntypedef struct {/' ${curdir}../opus_tools/src/src/opus_header.h
fi

cp -r ${curdir}../libogg/src/include/ogg/* ${curdir}../../src/main/cpp/libogg/
cp -r ${curdir}../libopus/src/include/* ${curdir}../../src/main/cpp/libopus/
cp ${curdir}../opus_tools/src/src/opus_header.h ${curdir}../../src/main/cpp/opus_tools/

# Replaces include path of os_types.h in include/libogg/ogg.h.
sed -i 's/<ogg\/os_types.h>/\"os_types.h\"/' ${curdir}../../src/main/cpp/libogg/ogg.h
# Replaces include path of config_types.h in include/libogg/os_types.h.
sed -i 's/<ogg\/config_types.h>/\"config_types.h\"/' ${curdir}../../src/main/cpp/libogg/os_types.h
# Replaces include path of ogg.h in src/opus_header.h.
sed -i 's/<ogg\/ogg.h>/\"..\/..\/..\/..\/src\/main\/cpp\/libogg\/ogg.h\"/' ${curdir}../opus_tools/src/src/opus_header.h
# Replaces include path of ogg.h in include/opus_tools/opus_header.h.
sed -i 's/<ogg\/ogg.h>/\"..\/libogg\/ogg.h\"/' ${curdir}../../src/main/cpp/opus_tools/opus_header.h
# Place CMakeLists.txt of opus_tools.
cp ${curdir}./CMakeLists.txt.in ${curdir}../opus_tools/src/CMakeLists.txt
