# TODO: should build third party libray directly by gradle. Not make them by running this script.

# Lists cpu architecture of android.
android_abi=("x86" "x86_64" "arm64-v8a" "armeabi-v7a")

# Downloads third party source code.
if [ -z "${ANDROID_SDK_PATH}" ] ;then
   echo "\$ANDROID_SDK_PATH is empty, please export SDK path to \$ANDROID_SDK_PATH"
   exit 1
fi

NDK_PATH="${ANDROID_SDK_PATH}"/ndk-bundle/;
if [ ! -d "${NDK_PATH}" ] ;then
  echo "NDK bundle not found at location ${NDK_PATH}"
  exit 1
fi

for ((i=0; i < ${#android_abi[@]}; i++));
do
  mkdir -p ../libogg/lib/${android_abi[$i]}
  mkdir -p ../libopus/lib/${android_abi[$i]}
  mkdir -p ../opus_tools/lib/${android_abi[$i]}
done

# Executes cmake command in third_party/CMakeLists.txt.in for all cpu architecture.
for ((i=0; i < ${#android_abi[@]}; i++))
do
  if [ ! -d ../out ]; then
    mkdir ../out
  fi
  cd ../out
  cmake -DCMAKE_TOOLCHAIN_FILE="${NDK_PATH}"/build/cmake/android.toolchain.cmake -DANDROID_ABI=${android_abi[$i]} ..
  make
  cd ../build
  rm -rf ../out
done
