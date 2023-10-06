FROM redmine:5.0.2

RUN apt update && apt install -y \
    graphviz vim unzip iputils-ping htop net-tools

# /home/redmine/repoScript.sh script'inin cronjob olarak çalışması için gerekli.
# RUN apt install -y cron # buradaki isi cron konteyneri yapacak

#
RUN apt install -y ubuntu-dev-tools

# libreoffice yüklenince dmsf inline editing yapabilecek
RUN apt install -y libreoffice liblibreoffice-java

# dms eklentisinin belgeleri endekleme araclari (indexing tools):
RUN apt-get install -y xapian-omega ruby-xapian libxapian-dev poppler-utils antiword  unzip catdoc libwpd-tools \
libwps-tools gzip unrtf catdvi djview djview3 uuid uuid-dev xz-utils libemail-outlook-message-perl

