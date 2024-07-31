#syntax=docker/dockerfile:1
#escape=\

# 以上はパーサーディレクティブ。ファイル先頭に書くと機能する。2行目以降に書くと無視される #dsc
# #syntax　=> Dockerfileの構文バージョンを指定できる。 #dsc
# #escape  => Dockerfile内のエスケープ文字を変更できる。デフォルトはescape=\\だが、\\をパス区切りに使うwindows環境などでは #escape='などに変更する #dsc

# ベースとなるイメージを宣言 #tmp
#FROM scratch #tmp
################## <変更> #####################
#　Ubuntu20.04に変更。エミュレータが18.04で動作しなくなったため #chg
FROM ubuntu:20.04
#FROM ubuntu:18.04 #chg
################## </変更> ####################


# イメージ作成者の情報、連絡先などを記載 参考:<https://label-schema.org/rc1/>　#tmp
LABEL test name <test@example.com>
# シェルを指定(デフォルトはbash) #tmp
# SHELL ["/bin/bash", "-c"] #tmp

# すべてのRUNコマンドに付与する引数を指定(Docker Build時のみ有効な変数として使用できる)　#tmp
## 今回は、ユーザー名を変数として指定。　#dsc
ARG USER=android

# 作業ディレクトリを指定(`RUN cd`と同じだが、余計な容量増加を起こさない)　#tmp
#WORKDIR /　#tmp

# あまり記述が変化しないであろう処理は初めの方に置くとキャッシュが効いてビルドが早くなる。 #dsc
# ソフトウェアアップデート & インストール。 #tmp
## バージョンを指定することで再現性を高められる。バージョンを指定しないと最新版が入るが、キャッシュをリセットしないと更新はされない。 #dsc
### パッケージの名前はアルファベット順にすると保守性が上がるらしい(何が入っていて何が抜けているか追いやすい) #dsc
# ubuntu20.04に合わせて環境変数指定を追加　#chg
ENV DEBIAN_FRONTEND=noninteractive

################## <変更> #####################
# ubuntu20.04に合わせて差し替え #chg
RUN dpkg --add-architecture i386
RUN apt-get update && apt-get install -y \
			bridge-utils build-essential git \
			lib32z1 libbz2-1.0:i386 libc6:i386 libfreetype6 libglu1 libncurses5:i386 libnotify4 \
			libqt5widgets5 libstdc++6:i386 libvirt-clients libvirt-daemon-system libxft2 libxi6 libxrender1 libxtst6 \
			neovim openjdk-8-jdk openjdk-11-jdk \
			qemu qemu-kvm sudo unzip vim wget xvfb xz-utils \
		&& \
		apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*	
#RUN dpkg --add-architecture i386
#RUN apt-get update && apt-get install -y \
#			bridge-utils build-essential git \
#			lib32z1 libbz2-1.0:i386 libc6:i386 libfreetype6 libglu1 libncurses5:i386 libnotify4 \
#			libqt5widgets5 libstdc++6:i386 libvirt-bin libxft2 libxi6 libxrender1 libxtst6 \ #chg
#			neovim openjdk-8-jdk openjdk-11-jdk \
#			qemu qemu-kvm sudo ubuntu-vm-builder unzip vim wget xvfb xz-utils \ #chg
#		&& \
#	apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
################## </変更> ####################
## ユーザー情報作成(非rootユーザーを使用することでrootlessコンテナにできる) #tmp
RUN groupadd -g 1000 -r $USER
RUN useradd -u 1000 -g 1000 --create-home -r $USER
# ユーザーを必要なグループに追加 #tmp
RUN adduser $USER libvirt
RUN adduser $USER kvm
### パスワード変更 #tmp
#以下のようにコメントを書くとその次の行でhadolintの警告を一時的に除外する
#hadolint ignore=DL4006
RUN echo "$USER:$USER" | chpasswd
### sudoをパスワード無しで使用できるように #tmp
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
RUN usermod -aG sudo $USER
RUN usermod -aG plugdev $USER
### 必要なフォルダを作成 #tmp
RUN mkdir -p /androidstudio-data
VOLUME /androidstudio-data
RUN chown $USER:$USER /androidstudio-data
### 実機Androidを読み込めるように #dsc
RUN usermod -aG plugdev $USER

## 永続化フォルダの設定 #tmp
RUN mkdir -p /androidstudio-data
VOLUME /androidstudio-data
RUN chown $USER:$USER /androidstudio-data
## Android Studioの保存用フォルダ作成 #dsc
RUN mkdir -p /studio-data/Android/Sdk && \
	chown -R $USER:$USER /studio-data/Android

RUN mkdir -p /studio-data/profile/android && \
	chown -R $USER:$USER /studio-data/profile
################## <追加> #####################
## Project永続化用のフォルダ作成 #chg
RUN mkdir -p /AndroidStudioProjects && \
	chown -R $USER:$USER /AndroidStudioProjects
################## </追加> ####################

# たまに記述修正が入る処理を中くらいの位置に置く #dsc
# 指定されたビルドコンテキスト(普通は、Dockerfileがおいてあるフォルダにする)のデータを、イメージ内のWORKDIR上にコピー #tmp
## ADDコマンドはtarファイルを自動展開して中にあるフォルダをイメージに追加できるが、その分処理が遅い。 #dsc
#ADD testfolder/testfile /tmp/testfile #tmp
## COPYコマンドはファイルのコピーのみ。 #dsc
### ビルドキャッシュに注意。ファイルの変化は読み取ってくれないので、キャッシュクリアするかDockerfile上の記述が変化するまでshの変化は反映されない #dsc
COPY provisioning/docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
COPY provisioning/ndkTests.sh /usr/local/bin/ndkTests.sh
RUN chmod +x /usr/local/bin/*
# 実機Androidを自動認識するためのudev設定 #dsc
COPY provisioning/51-android.rules /etc/udev/rules.d/51-android.rules

# 頻繁に変化する処理は後の方に置く #dsc
# イメージのログインユーザーを変更(これにより、適切な権限でコンテナを実行できる) #tmp
USER $USER
WORKDIR /home/$USER

# 指定のログインユーザー下で処理を行う　#tmp
################## <追加> #####################
## Android Studioのインストール 参考1:<https://qiita.com/keicha_hrs/items/070b8f32fc98157541b2> 参考2:<https://developer.android.com/studio/install#linux> #dsc
### <変更点>Android Studioのバージョンを最新に変更 #chg
ARG ANDROID_STUDIO_URL=https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2024.1.1.12/android-studio-2024.1.1.12-linux.tar.gz
ARG ANDROID_STUDIO_VERSION=2024.1.1.12
#ARG ANDROID_STUDIO_URL=https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2022.3.1.20/android-studio-2022.3.1.20-linux.tar.gz
#ARG ANDROID_STUDIO_VERSION=2022.3.1.20 #chg
################## </追加> ####################


RUN wget "$ANDROID_STUDIO_URL" -O android-studio.tar.gz
RUN tar xzvf android-studio.tar.gz
RUN rm android-studio.tar.gz

RUN ln -s /studio-data/profile/AndroidStudio$ANDROID_STUDIO_VERSION .AndroidStudio$ANDROID_STUDIO_VERSION
RUN ln -s /studio-data/Android Android
RUN ln -s /studio-data/profile/android .android
RUN ln -s /studio-data/profile/java .java
RUN ln -s /studio-data/profile/gradle .gradle
################## <追加> #####################
## Project永続化用のフォルダ作成 #chg
RUN ln -s /AndroidStudioProjects AndroidStudioProjects
################## </追加> ####################
### コンテナ内で使う環境変数を設定する #tmp
ENV ANDROID_EMULATOR_USE_SYSTEM_LIBS=1

# その他、今回は使用しないがたまに役立つコマンドなど #dsc
## ベースとなるイメージを複数宣言することができ、その場合はマルチステージビルドとして動作する。
#FROM ubuntu:18.04 as build-image #dsc
## ポートを公開しそうな見た目をしているが、どのポートを公開する意図なのかを使用者に伝えるドキュメントとしての役割しかもたない。#tmp
#EXPOSE 8000

#コンテナ実行時の作業ディレクトリ #tmp
WORKDIR /home/$USER

# dockerコンテナ起動時に実行するコマンド #tmp
ENTRYPOINT [ "/usr/local/bin/docker_entrypoint.sh" ]
## CMDコマンドでENTRYPOINTコマンドに対して引数を付与できる。 #dsc
#CMD ["/app/src/manage.py", "runserver", "0.0.0.0:8000"] #dsc
