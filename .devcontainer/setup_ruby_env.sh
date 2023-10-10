#!/bin/bash


# Kodu geliştireceğimiz dizin konteynere "/workspace" ismiyle bağlanacak.
# "/workspace" dizini içinde "./ornek_eklenti" ismindeki klasörü "/usr/src/redmine/plugins" dizininin altına soft link ile bağlıyoruz
# launch.json içinde `"program": "/usr/src/redmine/bin/rails",` ile kodumuzu başlatabiliyoruz.
# Farklı isimlerde eklentiler için docker-compose.yml içinde mount edilmi "/workspace/volume/redmine/redmine-plugins" dizini içinde yaratarak kodlayabilirsiniz
ln -s -v /workspace/ornek_eklenti /usr/src/redmine/plugins/ornek_eklenti  && echo "link created" || echo "link creation failed"

# Redmine docker içinde aşağıdaki compose.yml ile çalışıyor ve içine VS Code ile debug için eklenti kuruyoruz.
gem install ruby-debug-ide --conservative

# Kod içinde gezinme, intellisense, yardım pencereleri sağlayacak alt yapı
gem install solargraph --conservative

# RUFO : RUby FOrmatter
gem install rufo --conservative  

# Ruby Formatter olarak rubocop da kullanılabilir
# gem install rubocop --conservative

# Aşağıdaki hata için çalıştırılacak:
# Missing `secret_key_base` for 'production' environment, set this string with `bin/rails credentials
# EDITOR="nano --wait" /usr/src/redmine/bin/rails credentials:edit