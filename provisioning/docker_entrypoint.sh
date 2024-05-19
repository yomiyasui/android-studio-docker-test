#!/bin/bash

#Change permissions of /dev/kvm for Android Emulator
echo "`whoami`" | sudo -S chmod 777 /dev/kvm > /dev/null 2>&1

export PATH=$PATH:/studio-data/platform-tools/

# Ensure the Android directory exists and has the correct permissions
################## <追加> #####################
# フォルダパーミッションが正しくならない場合があったので追加
if [ ! -d "/studio-data" ]; then
  mkdir -p /studio-data
fi
sudo chown -R android:android /studio-data
################## </追加> #####################

if [ ! -d "/studio-data/Android" ]; then
  mkdir -p /studio-data/Android
fi
sudo chown -R android:android /studio-data/Android
################## <追加> #####################
# Dockerfileにこれを書かない理由は、起動時に毎回動く処理にしたいため。運用上、起動時にホストに当該ディレクトリがなかったときに強制的に作成したいので。
## Project永続化用のフォルダ作成 #chg
if [ ! -d "/AndroidStudioProjects" ]; then
  mkdir -p /AndroidStudioProjects
fi
sudo chown -R android:android /AndroidStudioProjects
################## </追加> #####################
# Default to 'bash' if no arguments are provided
# 実行するスクリプトを引数でオーバーライドさせている。DockerfileのCMDコマンドからコントロールできるようにする意図?
args="$@"
if [ -z "$args" ]; then
  #Android Studioは以下のディレクトリを叩いて実行するように公式サイトでアナウンスされています
  args="~/android-studio/bin/studio.sh"
fi

exec $args
