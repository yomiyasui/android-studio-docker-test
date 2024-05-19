# 以下、利便性のためのオプション。環境変数経由で挙動を変える。
AOSP_ARGS=""
if [ "$NO_TTY" = "" ]; then
AOSP_ARGS="${AOSP_ARGS} -t"
fi
# dockerコンテナにはIPアドレスを割り当てることができるが、固定IPの場合とdockerデーモンの自動割当(DHCPみたいな)の場合がある。
# 自動割当の場合は、通信相手をIP指定できないので(DNSみたいな)ホスト解決をdockerデーモンが行う。
if [ "$DOCKERHOSTNAME" != "" ]; then
AOSP_ARGS="${AOSP_ARGS} -h $DOCKERHOSTNAME"
fi
# ホストPCのusbデバイスファイルに直結させる
if [ "$HOST_USB" != "" ]; then
AOSP_ARGS="${AOSP_ARGS} -v /dev/bus/usb:/dev/bus/usb"
fi
# ホストPCのネットワークに直結させる。デフォルトは--net=bridge
# 参考 <https://docs.docker.jp/network/index.html#id4>
if [ "$HOST_NET" != "" ]; then
AOSP_ARGS="${AOSP_ARGS} --net=host"
fi
# ホストPCのXサーバーに直結させる。
if [ "$HOST_DISPLAY" != "" ]; then
AOSP_ARGS="${AOSP_ARGS} --env=DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix"
fi

#Make sure prerequisite directories exist in studio-data dir
mkdir -p studio-data/profile/AndroidStudio2023.3.1.18
mkdir -p studio-data/profile/android
mkdir -p studio-data/profile/gradle
mkdir -p studio-data/profile/java
################## <追加> #####################
##Android Studioのデフォルト保存ディレクトリとリンクさせるホストのディレクトリを作成 ===
mkdir -p AndroidStudioProjects
################## </追加> ####################
docker volume create --name=android_studio
# vオプションでディレクトリをホストディレクトリやdocker volumeにマッピング
# previlagedはコンテナに特権を与えるフラグです。セキュリティを気にするならば、これをやめてdeviceオプションによるオプトイン形式に変更できる
# group-add plugdevを設定することで、udevで設定したとおりにAndroid実機のPnPを有効にする
################## <変更> #####################
# ホストのAndroidStudioProjectsフォルダをイメージ内のディレクトリとリンクさせるオプションを追加
# -v `pwd`/AndroidStudioProjects:/home/android/AndroidStudioProjects
docker run -i $AOSP_ARGS -v `pwd`/studio-data:/studio-data -v `pwd`/AndroidStudioProjects:/home/android/AndroidStudioProjects -v android_studio:/androidstudio-data --privileged --group-add plugdev deadolus/android-studio $@
################## </変更> ####################
