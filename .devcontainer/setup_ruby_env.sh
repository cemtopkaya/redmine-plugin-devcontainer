#!/bin/bash


# Kodu geliştireceğimiz dizin konteynere "/workspace" ismiyle bağlanacak.
# "/workspace" dizini içinde "./ornek_eklenti" ismindeki klasörü "/usr/src/redmine/plugins" dizininin altına soft link ile bağlıyoruz
# launch.json içinde `"program": "/usr/src/redmine/bin/rails",` ile kodumuzu başlatabiliyoruz.
# Farklı isimlerde eklentiler için docker-compose.yml içinde mount edilmi "/workspace/volume/redmine/redmine-plugins" dizini içinde yaratarak kodlayabilirsiniz
ln -s /workspace/ornek_eklenti /usr/src/redmine/plugins/ornek_eklenti

# Redmine docker içinde aşağıdaki compose.yml ile çalışıyor ve içine VS Code ile debug için eklenti kuruyoruz.
gem install ruby-debug-ide

# Aşağıdaki hata için çalıştırılacak:
# Missing `secret_key_base` for 'production' environment, set this string with `bin/rails credentials
# EDITOR="nano --wait" /usr/src/redmine/bin/rails credentials:edit