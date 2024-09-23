#!/bin/bash

# Mysql istemcisini kur
apt-get install default-mysql-client -y

# MySQL sunucusunun IP adresi ve portu
MYSQL_HOST=db_mysql
MYSQL_PORT=3306

# MySQL kullanıcı adı ve şifresi
MYSQL_USER=root
MYSQL_PASSWORD=admin

# Veritabanı adı
DATABASE="redmine"

# MySQL sunucusuna bağlanma denemesi yapacak fonksiyon
check_mysql_connection() {

    # mysqladmin ping -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD &> /dev/null
    
    # Bağlantı başarılıysa
    #if [ $? -eq 0 ]; then
    #    echo "MySQL sunucusuna başarılı bir şekilde bağlandı."
    #else
    #    # MySQL sunucusuna bağlanma denemesi yap
    #    echo "MySQL sunucusuna bağlanılamadı, bekleniyor..."
    #    sleep 5
    #    check_mysql_connection;
    #fi
    if mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
        echo "MySQL sunucusuna başarılı bir şekilde bağlandı."
    else
        # MySQL sunucusuna bağlanma denemesi yap
        echo "MySQL sunucusuna bağlanılamadı, bekleniyor..."
        sleep 5
        check_mysql_connection;
    fi
}

echo -e "\n\n----------------------------- CHECK IF MySQL SERVER IS UP ---------------------------------------------"
check_mysql_connection;

run_redmine(){
    if  pgrep -f puma; then
        echo "Puma sunucusu zaten çalışıyor."
    else
        echo "Puma sunucusu başlatılıyor..."
        cd /usr/src/redmine
        /docker-entrypoint.sh rails server -b 0.0.0.0 &
    fi
}
run_redmine;

check_redmine_isup(){
    # -s parametresi, curl komutunun sessiz modda çalışmasını sağlar, yani çıktıya hiçbir şey yazdırmaz.
    # -o /dev/null, curl çıktısını null aygıtına (yani, çıktıyı atar) yönlendirir.
    # -w '%{http_code}', curl komutunun sadece HTTP durum kodunu (http_code) çıktı olarak yazmasını sağlar.
    # ! işareti, curl komutunun çıktısının başarısız olduğunu (yani, HTTP durum kodunun başarısız olduğunu) kontrol eder.
    # Bu döngü, HTTP isteğinin başarılı olana kadar bekler ve bir saniye aralıklarla tekrarlar (sleep 1).

    while ! curl -s -o /dev/null -w '%{http_code}' http://localhost:3000; do 
        echo "Redmine için PUMA sunucusuna bağlanılamadı, 4sn bekleyip tekrar denenecek..."
        sleep 4; 
    done;
}

echo -e "\n\n----------------------------- CHECK IF REDMINE SERVER IS UP -------------------------------------------"
check_redmine_isup;

# ------------------------------------------------------------------------------------------------------------

# REST Web servisini etkinleştirmek için veritabanında aşağıdaki komutla 
# settings tablosunda name alanı rest_api_enabled olan kaydın value alanı true olarak güncellenir

aktivateRestAPI() {
    # Redmine -> Ayarlar -> API sekmesinde rest_api_enabled ve jsonp_enabled aktif edilecek
    # updated_on değeri şimdi olsun
    CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")

    # REST_API name,value değerleri
    REST_API_NAME="rest_api_enabled"
    REST_API_VALUE="1"

    # JSONP name,value değerleri
    JSONP_NAME="jsonp_enabled"
    JSONP_VALUE="1"

    # settings Tablosu normalde boş olur ta ki sayfadan checkbox işaretlendikten sonra kayıtlar oluşuyor.
    # Bu yüzden önce "rest_api_enabled" isimli kayıt var mı kontrolü yapılıyor yoksa kayıt yaratılıyor
    rest_api_count=$(mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -sN -e "SELECT COUNT(*) FROM settings WHERE name='${REST_API_NAME}'")
    if [[ rest_api_count -eq 0 ]]; then
        echo "Inserting new record for ${REST_API_NAME}"
        sql="INSERT INTO settings (name, value, updated_on) VALUES ('${REST_API_NAME}', '${REST_API_VALUE}', '${CURRENT_TIME}');"
        mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "${sql}"
    fi

    # İkinci kayıtı kontrol etme ve ekleme veya güncelleme
    jsonp_count=$(mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -sN -e "SELECT COUNT(*) FROM settings WHERE name='${JSONP_NAME}'")
    if [[ jsonp_count -eq 0 ]]; then
        echo "Inserting new record for ${JSONP_NAME}"
        sql="INSERT INTO settings (name, value, updated_on) VALUES ('${JSONP_NAME}', '${JSONP_VALUE}', '${CURRENT_TIME}');"
        mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "${sql}"
    fi

    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "UPDATE settings SET value='${REST_API_VALUE}', updated_on='${CURRENT_TIME}' WHERE name='${REST_API_NAME}';"
    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "UPDATE settings SET value='${JSONP_VALUE}', updated_on='${CURRENT_TIME}' WHERE name='${JSONP_NAME}';"

    # Tracker'lar yoksa ekleniyor
    # sql="INSERT IGNORE INTO ${DATABASE}.trackers 
    #             (name      , description, position, is_in_roadmap, fields_bits, default_status_id) 
    #      VALUES ('Epic'    ,     '',        11,             1,           8,          1),
    #             ('Story'   ,     '',        12,             1,           0,          1),
    #             ('Task'    ,     '',        8 ,             1,           0,          1),
    #             ('Sub-task',     '',        9 ,             1,           0,          1),
    #             ('Bug'     ,     '',        10,             1,           0,          1),
    #             ('Feature' ,     '',        13,             1,           0,          1);"

    # mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "${sql}"

    # Sadece belirtilen tracker isimleri yoksa ekliyor
    sql="
    INSERT INTO ${DATABASE}.trackers 
        (name, description, position, is_in_roadmap, fields_bits, default_status_id)
    SELECT * FROM (
        SELECT 'Epic' AS name, '' AS description, 11 AS position, 1 AS is_in_roadmap, 8 AS fields_bits, 1 AS default_status_id
        UNION ALL SELECT 'Story', '', 12, 1, 0, 1
        UNION ALL SELECT 'Task', '', 8, 1, 0, 1
        UNION ALL SELECT 'Sub-task', '', 9, 1, 0, 1
        UNION ALL SELECT 'Bug', '', 10, 1, 0, 1
        UNION ALL SELECT 'Feature', '', 13, 1, 0, 1
    ) AS new_trackers
    WHERE new_trackers.name NOT IN (SELECT name FROM ${DATABASE}.trackers);
    "
    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "${sql}"

    # Sadece belirtilen issue durumları yoksa ekliyor
    sql="
    INSERT INTO ${DATABASE}.issue_statuses 
        (name, is_closed, position, default_done_ratio)
    SELECT * FROM (
        SELECT 'Open' AS name, 0 AS is_closed, 2 AS position, NULL AS default_done_ratio
        UNION ALL SELECT 'Closed', 1, 14, NULL
        UNION ALL SELECT 'Done', 1, 12, NULL
        UNION ALL SELECT 'In Review', 0, 6, NULL
        UNION ALL SELECT 'In Progress', 0, 5, NULL
        UNION ALL SELECT 'Pending', 0, 9, NULL
        UNION ALL SELECT 'Reopened', 0, 13, NULL
        UNION ALL SELECT 'Rejected', 0, 3, NULL
        UNION ALL SELECT 'Deferred', 0, 4, NULL
        UNION ALL SELECT 'Resolved', 0, 10, NULL
        UNION ALL SELECT 'Blocked', 0, 8, NULL
        UNION ALL SELECT 'In Test', 0, 11, NULL
        UNION ALL SELECT 'Needs Identified', 0, 7, NULL
        UNION ALL SELECT 'TO DO', 0, 1, NULL
    ) AS new_statuses
    WHERE new_statuses.name NOT IN (SELECT name FROM ${DATABASE}.issue_statuses);
    "

    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "${sql}"

    # Redmine rollerinin optimize edilmiş eklenmesi
    sql="INSERT INTO redmine.roles (name,`position`,assignable,builtin,permissions,issues_visibility,users_visibility,time_entries_visibility,all_roles_managed,settings) VALUES
	 ('Non member',0,1,1,'---
- :view_issues
- :view_news
- :view_messages
','default','all','all',1,NULL),
('Anonymous',0,1,2,'---
- :view_issues
- :view_news
- :view_messages
','default','all','all',1,NULL),
('Developer',1,1,0,'---
- :view_messages
- :view_issues
- :add_issues
- :edit_issues
- :edit_own_issues
- :copy_issues
- :manage_issue_relations
- :manage_subtasks
- :add_issue_notes
- :edit_issue_notes
- :edit_own_issue_notes
- :mention_users
- :add_issue_watchers
- :view_news
- :view_time_entries
- :log_time
- :edit_own_time_entries
- :view_wiki_pages
- :edit_wiki_pages
- :rename_wiki_pages
','default','all','all',1,'--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
permissions_all_trackers: !ruby/hash:ActiveSupport::HashWithIndifferentAccess
  view_issues: ''1''
  add_issues: ''1''
  edit_issues: ''1''
  add_issue_notes: ''1''
  delete_issues: ''1''
permissions_tracker_ids: !ruby/hash:ActiveSupport::HashWithIndifferentAccess
  view_issues: []
  add_issues: []
  edit_issues: []
  add_issue_notes: []
  delete_issues: []
'),
('Manager',2,1,0,'---
- :add_project
- :edit_project
- :manage_members
- :manage_versions
- :add_subprojects
- :save_queries
- :view_messages
- :view_documents
- :add_documents
- :edit_documents
- :delete_documents
- :view_files
- :manage_files
- :edit_issue_templates
- :show_issue_templates
- :manage_issue_templates
- :view_issues
- :add_issues
- :edit_issues
- :edit_own_issues
- :copy_issues
- :manage_issue_relations
- :manage_subtasks
- :set_issues_private
- :set_own_issues_private
- :add_issue_notes
- :edit_issue_notes
- :edit_own_issue_notes
- :view_private_notes
- :set_notes_private
- :delete_issues
- :mention_users
- :view_issue_watchers
- :add_issue_watchers
- :delete_issue_watchers
- :import_issues
- :manage_categories
- :view_news
- :manage_news
- :comment_news
- :view_changesets
- :browse_repository
- :commit_access
- :manage_related_issues
- :manage_repository
- :view_time_entries
- :log_time
- :edit_time_entries
- :edit_own_time_entries
- :manage_project_activities
- :log_time_for_other_users
- :import_time_entries
- :view_wiki_pages
- :view_wiki_edits
- :export_wiki_pages
- :edit_wiki_pages
- :rename_wiki_pages
- :delete_wiki_pages
- :delete_wiki_pages_attachments
- :view_wiki_page_watchers
- :add_wiki_page_watchers
- :delete_wiki_page_watchers
- :protect_wiki_pages
- :manage_wiki
','default','all','all',1,'--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
permissions_all_trackers: !ruby/hash:ActiveSupport::HashWithIndifferentAccess
  view_issues: ''1''
  add_issues: ''1''
  edit_issues: ''1''
  add_issue_notes: ''1''
  delete_issues: ''1''
permissions_tracker_ids: !ruby/hash:ActiveSupport::HashWithIndifferentAccess
  view_issues: []
  add_issues: []
  edit_issues: []
  add_issue_notes: []
  delete_issues: []
');"

    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "${sql}"
}

echo -e "\n\n----------------------------- ACTIVATE REST API WITH JSONP --------------------------------------------"
aktivateRestAPI;

# admin Kullanıcısının şifresini (admin) değiştirmek zorunda kalmayalım 
keepAdminPasswordAdmin() {
    sql="UPDATE users SET must_change_passwd=0 WHERE login='admin';"
    # İlk kez giriş yaparken kullanıcı adı admin ve şifresi admin ancak ilk girişte şifreyi değiştirmem isteniyor
    # bunun önüne geçmek için users tablosunda must_change_passwd alanı admin kullanıcısı için 0 yapılır:
    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -v -e "${sql}"
}

echo -e "\n\n----------------------------- ADMIN PASSWORD WILL BE KEPT AS IT IS ------------------------------------"
keepAdminPasswordAdmin;

# ------------------------------------------------------------------------------------------------------------

createNewProject() {
    # Başlangıç projesini oluşturuyorum
    # Kullanıcı adı ve şifre değişkenleri
    REDMINE_ADMIN_USERNAME="admin"
    REDMINE_ADMIN_PASSWORD="admin"

    # Curl komutunu kullanarak POST isteği gönderme
    curl -vvv \
        -H "Content-Type: application/json" \
        --user "${REDMINE_ADMIN_USERNAME}:${REDMINE_ADMIN_PASSWORD}" \
        -X POST \
        -d '{"project":{"name":"YENI_PROJE_ISMI","identifier":"yeni_proje","description":"Proje açıklaması"}}' \
        http://localhost:3000/projects.json
}

echo -e "\n\n----------------------------- CREATE NEW PROJECT USING BY API -----------------------------------------"
createNewProject;

# ------------------------------------------------------------------------------------------------------------

install_dev_debug_packages(){
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
}

echo -e "\n\n----------------------------- INSTALL RUBY DEBUG & IDE PACKAGES ---------------------------------------"
install_dev_debug_packages;

# ------------------------------------------------------------------------------------------------------------

create_symlink_of_plugin(){
    # Kodu geliştireceğimiz dizin konteynere "/workspace" ismiyle bağlanacak.
    # "/workspace" dizini içinde "./ornek_eklenti" ismindeki klasörü "/usr/src/redmine/plugins" dizininin altına soft link ile bağlıyoruz
    # launch.json içinde `"program": "/usr/src/redmine/bin/rails",` ile kodumuzu başlatabiliyoruz.
    # Farklı isimlerde eklentiler için docker-compose.yml içinde mount edilmi "/workspace/volume/redmine/redmine-plugins" dizini içinde yaratarak kodlayabilirsiniz
    ln -s -v /workspace/ornek_eklenti /usr/src/redmine/plugins/ornek_eklenti  && echo "link created" || echo "link creation failed"
}

# echo -e "\n\n----------------------------- CREATE SYMBOLIC LINK FOR REDMINE PLUGIN ---------------------------------"
# create_symlink_of_plugin;

# echo -e "\n\n----------------------------- .bashrc & aliases ---------------------------------"
echo "alias ll='ls -al --color=auto'" >> ~/.bashrc
source ~/.bashrc

# ------------------------------------------------------------------------------------------------------------
exit 0
