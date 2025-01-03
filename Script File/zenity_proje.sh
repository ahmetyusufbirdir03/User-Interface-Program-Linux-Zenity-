#!/bin/bash

# Veritabanı dosyaları
DATABASE="users.csv"
LOGFILE="log.csv"
DEPOFILE="depo.csv"
LOCKED_USERS="locked_users.csv"

y1=0
# Dosyaların oluşturulması
for file in "$DATABASE" "$DEPOFILE" "$LOGFILE" "$LOCKED_USERS"; do
    if [ ! -f "$file" ]; then
        touch "$file"
        if [ $file == $DATABASE ];then # veri tabanı dosyası zaten var ise yöneticiyi bir daha eklememek için kontrol
        	y1="+"
       	fi
       	
    else
        echo "$file zaten mevcut." > /dev/null
    fi
done

last_line=$(tail -n 1 "$LOGFILE")
if [ -n "$last_line" ];then
    errors=$(echo "$last_line" | cut -d',' -f2) # en son hatanın hata numarasını al
else
    errors=0 # hata yok ise 0 dan başlat
fi

system_user_info="" # sistemi aktif kullanan kişinin anlık bilgilerini tutacak değişken

# Varsayılan yönetici hesabı ekleme (veritabanına ekliyoruz)
if [ "$y1" == "+" ];then
   echo "1,yonetici,ad,soyad,admin,111" >> "$DATABASE" # İlk yöneticiyi ekle
fi


#----------------------------Login Functions Start-------------------------------------------------------
# Yönetici girişi fonksiyonu
admin_login() {
    # Yönetici giriş işlemini başlatır.
    system_user="$system_user_info"
    date=$(date)
    
    # Zenity ile kullanıcıdan yönetici adı ve parola alır.
    result=$(zenity --forms --title="Yönetici Giriş Ekranı" --text="Yönetici Girişi" \
        --add-entry="Yönetici Adı" \
        --add-password="Parola")
    
    # Eğer kullanıcı pencereyi kapatırsa, işlev sonlanır.
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Alınan giriş verisini yönetici adı ve parolaya ayırır.
    admin_name=$(echo "$result" | cut -d'|' -f1 | xargs)
    password=$(echo "$result" | cut -d'|' -f2 | xargs)
    
    # Yönetici bilgilerinin veritabanından kontrolünü yapar.
    admin_info=$(grep "$admin_name," "$DATABASE")
    admin_name_check=$(echo "$admin_info" | cut -d',' -f2)
    admin_role_check=$(echo "$admin_info" | cut -d',' -f5)
    
    # Eğer yönetici adı bulunamazsa hata mesajı gösterir.
    if [ "$admin_name" != "$admin_name_check" ]; then
        ((errors+=1))
        echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Yönetici adı bulunamadı!" >> "$LOGFILE"
        zenity --error --text="Hata: Yönetici bulunamadı."
        return
    fi
    
    # Eğer giriş yapan kullanıcı "admin" değilse, hata mesajı gösterir.
    if [ "$admin_role_check" != "admin" ]; then
        ((errors+=1))
        echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Wrong login screen usage!" >> "$LOGFILE"
        zenity --error --text="Hata: Kullanıcılar kullanıcı giriş ekranı kullanmalı!"
        return
    fi
    
    # Yönetici parolasını ve rolünü doğrular.
    stored_password=$(echo "$admin_info" | cut -d',' -f6)
    role=$(echo "$admin_info" | cut -d',' -f5)
    
    # Eğer parola yanlışsa hata mesajı gösterir.
    if [ "$password" != "$stored_password" ] || [ "$role" != "admin" ]; then
        ((errors+=1))
        echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Yönetici parola yanlış!" >> "$LOGFILE"
        zenity --error --text="Hata: Parola yanlış. Geri dönülüyor..."
        return
    fi
    
    # Başarılı giriş mesajı gösterir ve ana menüye yönlendirir.
    zenity --info --text="Yönetici girişi başarılı! Hoş geldiniz, $admin_name."
    system_user_info=$admin_info
    program_menu
}


#kullanıcı adı ve parolası hata kontrolü yapan fonksiyon
user_info_check() {
    # Kullanıcı giriş işlemini başlatır.
    system_user="$system_user_info"
    date=$(date)
    try_flag=0 # Parola kontrolü için deneme sayacı
    
    # Kullanıcı giriş kontrol döngüsü (3 deneme hakkı)
    while [ "$try_flag" -lt 3 ]; do
        # Zenity ile kullanıcıdan giriş bilgileri alınır.
        result=$(zenity --forms --title="Kullanıcı Giriş Ekranı" --text="Kullanıcı Girişi" \
            --add-entry="Kullanıcı Adı" \
            --add-password="Parola")
        
        # Kullanıcı pencereyi kapatırsa işlemi sonlandırır.
        if [ $? -ne 0 ]; then
            return
        fi
        
        # Kullanıcı adı ve parola bilgilerini ayırır.
        username=$(echo "$result" | cut -d'|' -f1 | xargs)
        password=$(echo "$result" | cut -d'|' -f2 | xargs)
        
        # Boş bilgi girişlerini kontrol eder.
        if [ -z "$username" ] || [ -z "$password" ]; then
            ((errors+=1))
            echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user , Bilgilendirme: Boş bilgi girdisi!" >> "$LOGFILE"
            zenity --error --text="Kullanıcı bilgileri boş bırakılamaz!"
        else
            # Kullanıcı ve kilitli kullanıcı bilgilerini kontrol eder.
            user_info=$(grep "$username," "$DATABASE")
            locked_user_info=$(grep "$username," "$LOCKED_USERS")
            
            username_check=$(echo "$user_info" | cut -d',' -f2)
            user_role_check=$(echo "$user_info" | cut -d',' -f5)
            locked_username_check=$(echo "$locked_user_info" | cut -d',' -f2)
            
            # Hesabın kilitli olup olmadığını kontrol eder.
            if [ "$username" == "$locked_username_check" ]; then
                zenity --error --text="Hesabınız kilitli durumda! Açılması için yöneticinize başvurabilirsiniz."
                return 0
            fi 
            
            # Admin giriş ekranı yanlış kullanımı kontrolü.
            if [ "$user_role_check" == "admin" ]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user , Bilgilendirme: Wrong login screen usage" >> "$LOGFILE"
                zenity --error --text="Admin hesabı admin girişi kullanmalı!"
            # Kullanıcı adının bulunamaması durumu.
            elif [ "$username" != "$username_check" ]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Kullanıcı adı bulunamadı!" >> "$LOGFILE"
                zenity --error --text="Hata: Kullanıcı bulunamadı!"
            else
                # Parola doğrulama işlemi.
                stored_password=$(echo "$user_info" | cut -d',' -f6)
                role=$(echo "$user_info" | cut -d',' -f5)
                
                if [ "$password" != "$stored_password" ] || [ "$role" != "user" ]; then
                    ((try_flag++))
                    zenity --error --text="Hata: Parola yanlış. ($try_flag/3)"
                else
                    # Başarılı giriş.
                    system_user_info=$user_info
                    return 2
                fi
            fi  
        fi
    done

    # 3 kez yanlış parola girilirse hesabı kilitler.
    ((errors+=1))
    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$user_info, Bilgilendirme: Hatalı parola deneme sınırı aşıldı!" >> "$LOGFILE"
    echo "$user_info" >> "$LOCKED_USERS"
    return 1
}


# Kullanıcı girişi fonksiyonu
user_login() {
    # Kullanıcı giriş kontrol fonksiyonunu çağırır.
    user_info_check
    
    # user_info_check fonksiyonunun dönüş değerine göre işlem yapar.
    case $? in
        0) 
            # Kullanıcı giriş ekranını iptal etti.
            return ;;
        1) 
            # Hatalı giriş sınırı aşıldı, hesap kilitlendi.
            zenity --error --text="Hatalı giriş sayınız 3'e ulaştı ve hesabınız kilitlendi. Hesabınızı açması için yöneticinize başvurun!"
            ;;
        2) 
            # Başarılı giriş.
            temp=$(echo "$system_user_info" | cut -d',' -f2)
            zenity --info --text="Kullanıcı girişi başarılı! Hoş geldiniz, $temp."
            program_menu ;;
        *)
            # Beklenmeyen bir hata durumunda mesaj gösterir.
            zenity --error --text="Beklenmeyen bir hata oluştu."
            ;;
    esac
}
#----------------------------Login Functions End-------------------------------------------------------

#--------------------------------------Menu Functions Start-------------------------------------------
# Kullanıcı ve yönetici giriş seçeneklerini sunan ana menü fonksiyonu
sign_in_func() {
    # Ana menü döngüsü
    while true; do
        # Kullanıcıdan giriş türünü seçmesini ister
        choice=$(zenity --list --title="Giriş Yapın" --column="Seçenekler" \
        "Yönetici Girişi" \
        "Kullanıcı Girişi" \
        "Geri Dön")

        # Kullanıcı pencereyi kapatırsa ana menüden çıkılır
        if [ $? -ne 0 ]; then
            break
        fi

        # Kullanıcının seçimine göre ilgili giriş fonksiyonları çağrılır
        case $choice in
        "Yönetici Girişi") admin_login ;;
        "Kullanıcı Girişi") user_login ;;
        "Geri Dön") zenity --info --text="Geri Dönülüyor..."; break ;;
        *) zenity --error --text="Geçersiz seçim." ;;
        esac
    done
}

# Yönetici menüsünü sunar ve yöneticinin yetkilerini kontrol eder
program_menu() {
    system_user="$system_user_info"
    date=$(date)
    
    while true; do
        # Yönetici paneli seçeneklerini sunar
        choice=$(zenity --list --title="Yönetim Paneli" --column="Seçenekler" \
            "Ürün Yönetimi" \
            "Kullanıcı Yönetimi" \
            "Program Yönetimi" \
            "Çıkış" \
            --width=400 \
            --height=300 )

        # Kullanıcı pencereyi kapatırsa çıkılır
        if [ $? -ne 0 ]; then
            system_user_info=""
            break
        fi
        role=$(echo "$system_user_info" | cut -d',' -f5)

        # Seçime göre ilgili yönetim fonksiyonları çağrılır
        case $choice in
            "Ürün Yönetimi") product_management ;;
            "Kullanıcı Yönetimi") 
                # Eğer kullanıcı admin değilse, yetkisiz erişim hatası verir
                if [ "$role" != "admin" ]; then
                    ((errors+=1))
                    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: İzinsiz erişim denemesi" >> "$LOGFILE"
                    zenity --error --text="Bu panele yalnızca yönetici erişebilir."
                else
                    user_management
                fi
                ;;
            "Program Yönetimi") 
                # Eğer kullanıcı admin değilse, yetkisiz erişim hatası verir
                if [ "$role" != "admin" ]; then
                    ((errors+=1))
                    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: İzinsiz erişim denemesi" >> "$LOGFILE"
                    zenity --error --text="Bu panele yalnızca yönetici erişebilir."
                else
                    program_management
                fi
                ;;
            "Çıkış") zenity --info --text="Çıkış Yapılıyor..."
                     system_user_info=""; break ;;
            *) zenity --error --text="Geçersiz seçim." ;;
        esac
    done
}

# Ürün yönetim işlemlerini sunar
product_management() {
    system_user="$system_user_info"
    date=$(date)
    
    while true; do
        # Ürün yönetimi seçeneklerini sunar
        choice=$(zenity --list --title="Ürün Yönetimi" --column="Seçenekler" \
            "Ürün Ekle" \
            "Ürün Listele" \
            "Ürün Güncelle" \
            "Ürün Sil" \
            "Rapor Al" \
            "Geri Dön" \
            --width=400 \
            --height=300)

        # Kullanıcı pencereyi kapatırsa bir önceki menüye dönülür
        if [ $? -ne 0 ]; then
            break
        fi

        # Seçime göre ilgili işlemi çağırır
        case $choice in
            "Ürün Ekle")
                # Eğer kullanıcı admin değilse, izin verilmez
                if [ "$role" != "admin" ]; then
                    ((errors+=1))
                    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: İzinsiz erişim denemesi." >> "$LOGFILE"
                    zenity --error --text="Bu panele yalnızca yönetici erişebilir."
                else
                    add_product
                fi
                ;;
            "Ürün Listele") list_products ;;
            "Ürün Güncelle")
                # Eğer kullanıcı admin değilse, izin verilmez
                if [ "$role" != "admin" ]; then
                    ((errors+=1))
                    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: İzinsiz erişim denemesi." >> "$LOGFILE"
                    zenity --error --text="Bu panele yalnızca yönetici erişebilir."
                else
                    update_product
                fi
                ;;
            "Ürün Sil")
                # Eğer kullanıcı admin değilse, izin verilmez
                if [ "$role" != "admin" ]; then
                    ((errors+=1))
                    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: İzinsiz erişim denemesi." >> "$LOGFILE"
                    zenity --error --text="Bu panele yalnızca yönetici erişebilir."
                else
                    delete_product
                fi
                ;;
            "Rapor Al") generate_report ;;
            "Geri Dön") break ;;
            *) zenity --error --text="Geçersiz seçim." ;;
        esac
    done
}

# Kullanıcı yönetimi işlemleri
user_management() {
    while true; do
        # Kullanıcı yönetimi seçeneklerini sunar
        choice=$(zenity --list --title="Kullanıcı Yönetimi" --column="Seçenekler" \
            "Kullanıcı Ekle" \
            "Kullanıcı Kilit Kaldır" \
            "Kullanıcıları Listele" \
            "Kullanıcı Güncelle" \
            "Kullanıcı Sil" \
            "Geri Dön" \
            --width=400 \
            --height=300)

        # Kullanıcı pencereyi kapatırsa veya "Geri Dön" seçilirse çıkılır
        if [ $? -ne 0 ] || [ "$choice" == "Geri Dön" ]; then
            break
        fi

        # Seçime göre ilgili kullanıcı işlemi çağrılır
        case $choice in
            "Kullanıcı Ekle") add_user ;;
            "Kullanıcı Kilit Kaldır") unlock_user ;;
            "Kullanıcıları Listele") list_users ;;
            "Kullanıcı Güncelle") update_user ;;
            "Kullanıcı Sil") delete_user ;;
            "Geri Dön") zenity --info --text="Geri dönülüyor..."; break ;;
            *) echo "Geçersiz seçim." ;;
        esac
    done
}

# Program yönetimi işlemleri
program_management() {
    while true; do
        # Kullanıcıya program yönetimi seçeneklerini sunar
        result=$(zenity --list --title="Program Yönetimi" --column="Seçenekler" \
            "Disk Alanını Göster" \
            "Diske Yedek Al" \
            "Hata Dosyasını Göster" \
            --width=400 --height=200)

        # Kullanıcı pencereyi kapatırsa çıkılır
        if [ $? -ne 0 ]; then
            return
        fi

        # Seçime göre ilgili işlemi çağırır
        case $result in
            "Disk Alanını Göster")
                show_disk_usage
                ;;
            "Diske Yedek Al")
                backup_to_disk
                ;;
            "Hata Dosyasını Göster")
                show_error_log
                ;;
        esac
    done
}

#--------------------------------------Menu Functions End-------------------------------------------


#-------------------------------------Product Functions Start--------------------------------------
# Ürün ekleme işlemi
add_product() {
    system_user="$system_user_info"
    date=$(date)
    
    while true; do
        # Ürün bilgilerini al
        result=$(zenity --forms --title="Ürün Ekleme" --text="Ürün Bilgileri" \
            --add-entry="Ürün Adı" \
            --add-entry="Ürün Miktarı" \
            --add-entry="Ürün Birim Fiyatı" \
            --add-entry="Ürün Kategorisi" \
            --width=400 --height=300)
        
        # Eğer kullanıcı pencereyi kapatmışsa döngüyü kır
        if [ $? -ne 0 ]; then
            return
        fi
        
        # Bilgileri ayır
        product_name=$(echo "$result" | cut -d'|' -f1 | xargs)
        product_amount=$(echo "$result" | cut -d'|' -f2 | xargs)
        product_price=$(echo "$result" | cut -d'|' -f3 | xargs)
        product_category=$(echo "$result" | cut -d'|' -f4 | xargs)
    
        # Depo dosyasındaki son ürünü kontrol et, ürün numarasını al
        depo_fill_check=$(tail -n 1 "$DEPOFILE")
        if [ -n "$depo_fill_check" ]; then
            product_no=$(echo "$depo_fill_check" | cut -d',' -f1)  # En son ürün numarasını al
        else
            product_no=0  # Eğer depo boşsa, ürün numarasını 0'dan başlat
        fi
        
        # İsim kontrolü: Ürün adı sadece harflerden oluşmalı
        if [[ ! "$product_name" =~ ^[a-zA-ZçÇğĞıİöÖşŞüÜi]+$ ]]; then
            ((errors+=1))
            echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Geçersiz ürün adı." >> "$LOGFILE"
            zenity --error --text="Geçersiz giriş: Ürün adı sadece harflerden oluşmalı!" --title="Hata"
            continue
        fi
        
        # Ürün adı zaten var mı kontrolü
        product_exists=false
        while read -r line; do
            existing_product_name=$(echo "$line" | cut -d',' -f2)
            if [[ "$existing_product_name" == "$product_name" ]]; then
                product_exists=true
                break
            fi
        done < "$DEPOFILE"
    
        # Eğer ürün adı zaten varsa, kullanıcıyı bilgilendir
        if [ "$product_exists" = true ]; then
            ((errors+=1))
            echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Var olan ürün adı kullanma!" >> "$LOGFILE"
            zenity --error --text="Hata: Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz."
            continue
        fi
    
        # Miktar kontrolü: Ürün miktarı sadece rakamlardan oluşmalı
        if [[ ! "$product_amount" =~ ^[0-9]+$ ]]; then
            ((errors+=1))
            echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Geçersiz ürün miktarı." >> "$LOGFILE"
            zenity --error --text="Geçersiz giriş: Ürün miktarı sadece rakamlardan oluşmalı!" --title="Hata"
            continue
        fi

        # Fiyat kontrolü: Ürün fiyatı sadece rakamlardan oluşmalı
        if [[ ! "$product_price" =~ ^[0-9]+$ ]]; then
            ((errors+=1))
            echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Geçersiz ürün fiyatı." >> "$LOGFILE"
            zenity --error --text="Geçersiz giriş: Ürün fiyatı sadece rakamlardan oluşmalı!" --title="Hata"
            continue
        fi

        # Kategori kontrolü: Ürün kategorisi sadece harflerden oluşmalı
        if [[ ! "$product_category" =~ ^[a-zA-ZçÇğĞıİöÖşŞüÜi]+$ ]]; then
            ((errors+=1))
            echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Geçersiz ürün kategorisi." >> "$LOGFILE"
            zenity --error --text="Geçersiz giriş: Ürün kategorisi sadece harflerden oluşmalı!" --title="Hata"
            continue
        fi

        # Tüm kontroller başarılı, döngüden çık
        break
    done
    
    ((product_no++))  # Ürün numarasını bir arttır
    # Ürün bilgilerini depoya kaydet
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5 ; echo "50"; sleep 0.5 ; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Ekleme İşlemi" --text="Ürün ekleniyor..." --percentage=0
    echo "$product_no,$product_name,$product_amount,$product_price,$product_category" >> "$DEPOFILE"
    zenity --info --text="Ürün başarıyla eklendi!" --title="Başarılı"
}

# Ürün listeleme
list_products() {
    # Verileri tutacak bir array (liste)
    data=()

    # Dosyayı oku ve her satırı uygun formata sok
    while IFS=',' read -r product_no product_name product_amount product_price product_category; do
        # Boş satırları atla
        if [ -z "$product_no" ]; then
            continue
        fi
        # Her satırın verilerini doğru sırada ve formatta ekliyoruz
        data+=("$product_no" "$product_name" "$product_amount" "$product_price" "$product_category")
    done < "$DEPOFILE"

    # Eğer veri yoksa hata göster
    if [ ${#data[@]} -eq 0 ]; then
        zenity --error --text="Depoda ürün bulunamadı!" --title="Hata"
        return
    fi
    # Verileri listelemek için bir ilerleme çubuğu göster
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Listeleme İşlemi" --text="Ürünler getiriliyor..." --percentage=0
    # Zenity ile verileri listele
    zenity --list --title="Ürün Listesi" \
        --column="No" \
        --column="Ürün Adı" \
        --column="Ürün Miktarı" \
        --column="Ürün Birim Fiyatı" \
        --column="Ürün Kategori" \
        "${data[@]}" \
        --width=500 \
        --height=500
}

# Ürün güncelleme işlemi
update_product() {
    system_user="$system_user_info"
    date=$(date)

    while true; do
        # Güncellenecek ürünü sor
        product_to_update=$(zenity --entry --title="Ürün Güncelleme" --text="Güncellemek istediğiniz ürünün adını girin:" --width=400 --height=200)
        
        # Eğer kullanıcı pencereyi kapatmışsa döngüyü kır
        if [ $? -ne 0 ]; then
            return
        fi

        # Dosyada ürünü ara ve bilgileri ayır
        product_found=false
        while IFS= read -r line; do
            product_name=$(echo "$line" | cut -d',' -f2 | xargs)
            if [ "$product_name" = "$product_to_update" ]; then
                product_found=true
                product_no=$(echo "$line" | cut -d',' -f1 | xargs)
                product_amount=$(echo "$line" | cut -d',' -f3 | xargs)
                product_price=$(echo "$line" | cut -d',' -f4 | xargs)
                product_category=$(echo "$line" | cut -d',' -f5 | xargs)
                old_line="$line"
                break
            fi
        done < "$DEPOFILE"
        
        # Eğer ürün bulunamazsa hata ver
        if [ "$product_found" = false ]; then
            zenity --error --text="Hata: Ürün bulunamadı. Lütfen doğru bir ürün adı girin." --title="Hata"
            continue
        fi

        is_valid=true # Döngü kontrol değişkeni
        
        while $is_valid; do
            error_control=false
            # Zenity --forms ile yeni bilgileri al
            form_result=$(zenity --forms --title="Ürün Güncelle" \
                --text="Ürün bilgilerini güncelleyin:" \
                --add-entry="Ürün Adı (mevcut: $product_name)" \
                --add-entry="Ürün Miktarı (mevcut: $product_amount)" \
                --add-entry="Ürün Birim Fiyatı (mevcut: $product_price)" \
                --add-entry="Ürün Kategorisi (mevcut: $product_category)" \
                --width=400 --height=300)
            
            # Eğer kullanıcı pencereyi kapatmışsa döngüyü kır
            if [ $? -ne 0 ]; then
                return
            fi

            # Bilgileri ayır
            new_product_name=$(echo "$form_result" | cut -d'|' -f1 | xargs)
            new_product_amount=$(echo "$form_result" | cut -d'|' -f2 | xargs)
            new_product_price=$(echo "$form_result" | cut -d'|' -f3 | xargs)
            new_product_category=$(echo "$form_result" | cut -d'|' -f4 | xargs)

            # Kontroller
            if [[ ! "$new_product_name" =~ ^[a-zA-ZçÇğĞıİöÖşŞüÜ]+$ ]]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Geçersiz ürün adı." >> "$LOGFILE"
                zenity --error --text="Geçersiz giriş: Ürün adı sadece harflerden oluşmalı!" --title="Hata"
                error_control=true
            fi
            
            # Mevcut ürün adlarıyla eşleşme kontrolü 
            if [ "$new_product_name" != "$product_name" ]; then 
                while IFS= read -r line; do 
                     existing_product_name=$(echo "$line" | cut -d',' -f2 | xargs) 
                     if [ "$existing_product_name" = "$new_product_name" ]; then 
                     ((errors+=1)) 
                     echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Mevcut ürün adı." >> "$LOGFILE" 
                     zenity --error --text="Hata: Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz." 
                     error_control=true 
                     break 
                     fi 
                done < "$DEPOFILE" 
            fi

            # Ürün miktarı kontrolü
            if [[ ! "$new_product_amount" =~ ^[0-9]+$ ]]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Geçersiz ürün miktarı." >> "$LOGFILE"
                zenity --error --text="Geçersiz giriş: Ürün miktarı sadece rakamlardan oluşmalı!" --title="Hata"
                error_control=true
            fi

            # Ürün fiyatı kontrolü
            if [[ ! "$new_product_price" =~ ^[0-9]+$ ]]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Geçersiz ürün fiyatı." >> "$LOGFILE"
                zenity --error --text="Geçersiz giriş: Ürün fiyatı sadece rakamlardan oluşmalı!" --title="Hata"
                error_control=true
            fi

            # Ürün kategorisi kontrolü
            if [[ ! "$new_product_category" =~ ^[a-zA-ZçÇğĞıİöÖşŞüÜ]+$ ]]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Geçersiz ürün kategorisi." >> "$LOGFILE"
                zenity --error --text="Geçersiz giriş: Ürün kategorisi sadece harflerden oluşmalı!" --title="Hata"
                error_control=true
            fi

            # Eğer hata yoksa döngüyü kır
            if [ "$error_control" = false ]; then
                is_valid=false
            fi
        done
        
        # İlerleme çubuğunu göster
        ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Listeleme İşlemi" --text="Ürün güncelleniyor..." --percentage=0
        
        # Yeni satırı oluştur
        new_line="$product_no,$new_product_name,$new_product_amount,$new_product_price,$new_product_category"

        # Eski satırı yeni satırla değiştir
        sed -i "s/^$old_line\$/$new_line/" "$DEPOFILE"
        
        # Başarılı güncelleme mesajı
        zenity --info --text="Ürün bilgileri başarıyla güncellendi!" --title="Başarılı"
        return
    done
}

# Ürün silme işlemi
delete_product() {
    system_user="$system_user_info"
    date=$(date)

    while true; do
        # Silinecek ürünü sor
        product_input=$(zenity --entry --title="Ürün Silme" --text="Silmek istediğiniz ürünün adını veya numarasını girin:" --width=400 --height=200)
        
        # Eğer kullanıcı pencereyi kapatmışsa döngüyü kır
        if [ $? -ne 0 ]; then
            return
        fi

        # Dosyada ürünü ara ve bilgileri ayır
        product_found=false
        while IFS= read -r line; do
            product_no=$(echo "$line" | cut -d',' -f1 | xargs)
            product_name=$(echo "$line" | cut -d',' -f2 | xargs)
            if [ "$product_name" = "$product_input" ] || [ "$product_no" = "$product_input" ]; then
                product_found=true
                product_line="$line"
                break
            fi
        done < "$DEPOFILE"
        
        # Eğer ürün bulunamazsa hata ver
        if [ "$product_found" = false ]; then
            zenity --error --text="Hata: Ürün bulunamadı. Lütfen doğru bir ürün adı veya numarası girin." --title="Hata"
            continue
        fi

        # Silme işlemi için onay al
        zenity --question --title="Ürün Silme" --text="Ürün bilgileri:\n\nAdı: $product_name\nNumarası: $product_no\n\nBu ürünü silmek istediğinize emin misiniz?"

        # Eğer kullanıcı onaylamazsa döngüyü kır
        if [ $? -ne 0 ]; then
            return
        fi
        
        # Progres bar gösterimi
        ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5 ; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Silme İşlemi" --text="Ürün siliniyor..." --percentage=0

        # Ürünü dosyadan sil
        sed -i "/^$product_line$/d" "$DEPOFILE"
        
        # Ürün silindikten sonra ürün numaralarını yeniden düzenle
        ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5 ; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Silme İşlemi" --text="Ürün numaraları güncelleniyor..." --percentage=0
        temp_file=$(mktemp)
        product_no=1
        while IFS=',' read -r old_product_no old_product_name old_product_amount old_product_price old_product_category; do
            if [ -n "$old_product_no" ]; then
                echo "$product_no,$old_product_name,$old_product_amount,$old_product_price,$old_product_category" >> "$temp_file"
                ((product_no++))
            fi
        done < "$DEPOFILE"
        mv "$temp_file" "$DEPOFILE"
        
        # Başarılı silme işlemi mesajı
        zenity --info --text="Ürün başarıyla silindi ve ürün numaraları yeniden düzenlendi!" --title="Başarılı"
        return
    done
}

# Rapor oluşturma işlemi
generate_report() {
    while true; do
        # Kullanıcıya iki seçenek sun
        result=$(zenity --list --title="Rapor Seçimi" --column="Seçenekler" \
            "Stokta Azalan Ürünler" \
            "En Yüksek Stok Miktarına Sahip Ürünler" \
            --width=400 --height=200)

        # Eğer kullanıcı pencereyi kapatmışsa döngüyü kır
        if [ $? -ne 0 ]; then
            return
        fi

        # Kullanıcı seçimi işlemine göre fonksiyon çağrısı
        case $result in
            "Stokta Azalan Ürünler")
                low_stock_report
                ;;
            "En Yüksek Stok Miktarına Sahip Ürünler")
                high_stock_report
                ;;
        esac
    done
}

# Stokta azalan ürünler raporu
low_stock_report() {
    # Verileri tutacak bir array (liste)
    data=()

    # Dosyayı oku ve her satırı uygun formata sok
    while IFS=',' read -r product_no product_name product_amount product_price product_category; do
        # Boş satırları atla
        if [ -z "$product_no" ]; then
            continue
        fi
        # Eşik miktarın altındaki ürünleri ekliyoruz
        if [ "$product_amount" -lt 20 ]; then
            data+=("$product_no" "$product_name" "$product_amount" "$product_price" "$product_category")
        fi
    done < "$DEPOFILE"
    
    # Eğer veri yoksa hata göster
    if [ ${#data[@]} -eq 0 ]; then
        zenity --error --text="Stokta azalan ürün bulunamadı!" --title="Hata"
        return
    fi
    
    # Progres bar gösterimi
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5 ; echo "50"; sleep 0.5 ; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Listeleme İşlemi" --text="Ürünler getiriliyor..." --percentage=0

    # Zenity ile verileri listele
    zenity --list --title="Stokta Azalan Ürünler" \
        --column="No" \
        --column="Ürün Adı" \
        --column="Ürün Miktarı" \
        --column="Ürün Birim Fiyatı" \
        --column="Ürün Kategori" \
        "${data[@]}" \
        --width=600 \
        --height=500
}

# Yüksek stok miktarına sahip ürünler raporu
high_stock_report() {
    # Verileri tutacak bir array (liste)
    data=()

    # Dosyayı oku ve her satırı uygun formata sok
    while IFS=',' read -r product_no product_name product_amount product_price product_category; do
        # Boş satırları atla
        if [ -z "$product_no" ]; then
            continue
        fi
        # Eşik miktarın üstündeki ürünleri ekliyoruz
        if [ "$product_amount" -gt 100 ]; then
            data+=("$product_no" "$product_name" "$product_amount" "$product_price" "$product_category")
        fi
    done < "$DEPOFILE"

    # Eğer veri yoksa hata göster
    if [ ${#data[@]} -eq 0 ]; then
        zenity --error --text="Stokta yeterli miktarda ürün bulunamadı!" --title="Hata"
        return
    fi
    
    # Progres bar gösterimi
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5 ; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Listeleme İşlemi" --text="Ürünler getiriliyor..." --percentage=0

    # Zenity ile verileri listele
    zenity --list --title="Yüksek Stok Miktarına Sahip Ürünler" \
        --column="No" \
        --column="Ürün Adı" \
        --column="Ürün Miktarı" \
        --column="Ürün Birim Fiyatı" \
        --column="Ürün Kategori" \
        "${data[@]}" \
        --width=600 \
        --height=500
}

#--------------------------------Product Functions End----------------------------------------


#--------------------------------User Functions Start-------------------------------------------
# Kullanıcı Ekleme Fonksiyonu
add_user() {
    system_user="$system_user_info"
    date=$(date)
    
    # Kullanıcı bilgilerini GUI ile al
    result=$(zenity --forms --title="Kullanıcı Ekleme Ekranı" --text="Kullanıcı Bilgileri" \
        --add-entry="Numara " \
        --add-entry="Kullanıcı Adı" \
        --add-entry="Kullanıcı İsim" \
        --add-entry="Kullanıcı Soyadı" \
        --add-entry="Kullanıcı Rol (admin/user)"\
        --add-password="Parola")
    	
    # Kullanıcı pencereyi kapattıysa çık
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Kullanıcı bilgilerini ayıkla
    user_no=$(echo "$result" | cut -d'|' -f1 | xargs)
    username=$(echo "$result" | cut -d'|' -f2 | xargs)
    user_first_name=$(echo "$result" | cut -d'|' -f3 | xargs)
    user_last_name=$(echo "$result" | cut -d'|' -f4 | xargs)
    user_role=$(echo "$result" | cut -d'|' -f5 | xargs)
    password=$(echo "$result" | cut -d'|' -f6 | xargs)

    # Kullanıcı bilgisi geçerli değilse hata ver
    vars=( "$user_no" "$username" "$user_first_name" "$user_last_name" "$password" )
    for var in "${vars[@]}"; do
        if [ "$var" == "admin" ] || [ "$var" == "user" ]; then
            ((errors+=1))
            zenity --error --text="Role dışında bir bilgi 'admin' veya 'user' olamaz!" --title="Hata"
            return
        fi
    done
    
    # Boş alan kontrolü
    for var in "${vars[@]}"; do
        if [ -z "$var" ]; then
            ((errors+=1))
            zenity --error --text="Bir bilginin değeri boş bırakılamaz!" --title="Hata"
            return
        fi
    done
    
    # Kullanıcı numarası zaten varsa hata ver
    user_info=$(grep "^$user_no" "$DATABASE")
    if [ -n "$user_info" ]; then
        ((errors++))
        zenity --error --text="Hata: Böyle bir numara var!"
        return	
    fi
    
    # Kullanıcı adı zaten varsa hata ver
    user_info=$(grep "$username," "$DATABASE")
    if [ "$user_role" != "admin" ] && [ "$user_role" != "user" ]; then
        ((errors+=1))
        zenity --error --text="Rol sadece 'admin' veya 'user' olabilir!" --title="Hata"
        return
    elif [ -n "$user_info" ]; then
        ((errors+=1))
        zenity --error --text="Hata: Böyle bir giriş adı var!"
        return	
    fi  
    
    # Kullanıcıyı veri tabanına ekle
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Kullanıcı Ekleme" --text="Kullanıcı ekleniyor..." --percentage=0
    echo "$user_no,$username,$user_first_name,$user_last_name,$user_role,$password" >> "$DATABASE"
    zenity --info --text="$username kullanıcısı başarıyla eklendi."
}

# Kullanıcı Kilit Kaldırma Fonksiyonu
unlock_user() {
    system_user="$system_user_info"
    date=$(date)
    flag=0

    # Kullanıcı bilgilerini al
    while true; do
        result=$(zenity --forms --title="Kilit Kaldırma Ekranı" \
            --add-entry="Kullanıcı Numara" \
            --add-entry="Kullanıcı Adı")
         
        if [ $? -ne 0 ]; then
            break
        fi 
        
        locked_user_no=$(echo "$result" | cut -d'|' -f1 | xargs)
        locked_username=$(echo "$result" | cut -d'|' -f2 | xargs)
    
        # Kullanıcı numarası ve adı boş olmamalı
        if [ -z "$locked_username" ] || [ -z "$locked_user_no" ]; then
            ((errors+=1))
            zenity --error --text="Hata: Boş bilgi girilemez!"
        else
            user_info=$(grep "$locked_user_no,$locked_username," "$DATABASE")
            if [ -z "$user_info" ]; then
                ((errors+=1))
                zenity --error --text="Hata: Böyle bir kullanıcı kilitli değil!"
            else
                # Kilit kaldırma onayı al
                if zenity --question --title="Kilit Kaldırma Onayı" --text="Kullanıcı bilgileri:\n\nKullanıcı Numarası: $locked_user_no\nKullanıcı Adı: $locked_username\n\nBu kullanıcının kilidini kaldırmak istediğinize emin misiniz?"; then
                    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Kullanıcı Kilit kaldırma" --text="Kullanıcı kilidi kaldırılıyor..." --percentage=0
                    grep -v "$locked_user_no,$locked_username" "$LOCKED_USERS" > temp_locked_users.csv 
                    mv temp_locked_users.csv "$LOCKED_USERS"
                    zenity --info --text="'$locked_username' kullanıcısının kilidi başarıyla kaldırıldı."
                    return
                else
                    zenity --info --text="İşlem iptal edildi."
                    return
                fi
            fi   
        fi
    done
}

# Kullanıcı Listeleme Fonksiyonu
list_users() {
	# Verileri tutacak bir array (liste)
	data=()

	# CSV dosyasını oku ve verileri array'e ekle
	while IFS=',' read -r no username name surname role password; do
	    data+=("$no" "$username" "$name" "$surname" "$role" "$password")
	done < "$DATABASE"

	# Zenity ile verileri listele
	zenity --list --title="Kullanıcılar" \
	    --column="No" \
	    --column="Kullanıcı Adı" \
	    --column="İsim" \
	    --column="Soyisim" \
	    --column="Rol" \
	    --column="Parola" \
	    "${data[@]}" \
	    --width=500 \
	    --height=500 
}

# Kullanıcı Güncelleme Fonksiyonu
update_user() {
    system_user="$system_user_info"
    date=$(date)
    
    # Güncellenecek kullanıcıyı seç
    selected_user=$(zenity --forms --title="Kullanıcı Güncelleme" \
        --add-entry="Kullanıcı Numara" \
        --add-entry="Kullanıcı Adı")
    
    # Kullanıcı pencereyi kapattıysa geri dön
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Seçilen kullanıcı bilgilerini ayır
    selected_user_no=$(echo "$selected_user" | cut -d'|' -f1)
    selected_username=$(echo "$selected_user" | cut -d'|' -f2)
    
    # Kullanıcı bilgisi boş girildiyse hata ver
    if [ -z "$selected_username" ] || [ -z "$selected_user_no" ]; then
        ((errors+=1))
        echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Boş bilgi girişi!" >> "$LOGFILE"
        zenity --error --text="Hata: Bilgiler boş girilemez."
        return
    fi

    # Kullanıcıyı CSV dosyasından ara
    user_info=$(grep "^$selected_user_no,$selected_username" "$DATABASE")

    # Kullanıcı bulunamadıysa hata ver
    if [ -z "$user_info" ]; then
        ((errors+=1))
        echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Var olmayan kullanıcı araması!" >> "$LOGFILE"
        zenity --error --text="Hata: Kullanıcı bulunamadı."
        return
    fi
    
    # Mevcut bilgileri ayır
    username=$(echo "$user_info" | cut -d',' -f2)
    ad=$(echo "$user_info" | cut -d',' -f3)
    soyad=$(echo "$user_info" | cut -d',' -f4)
    rol=$(echo "$user_info" | cut -d',' -f5)
    parola=$(echo "$user_info" | cut -d',' -f6)
    
    # Kullanıcı bilgilerini güncelleme penceresi
    while true; do
        is_valid=true # Geçerlilik kontrolü
        error_control=false # Hata kontrolü
	    
        form_result=$(zenity --forms --title="Kullanıcı Güncelle" \
            --text="Kullanıcı bilgilerini güncelleyin:" \
            --add-entry="Username (mevcut: $username)" \
            --add-entry="Ad (mevcut: $ad)" \
            --add-entry="Soyad (mevcut: $soyad)" \
            --add-entry="Rol (mevcut: $rol)" \
            --add-password="Parola (mevcut: $parola)" \
            --width=400 --height=300)

        # Kullanıcı pencereyi kapattıysa geri dön
        if [ $? -ne 0 ]; then
            return
        fi
        
        # Yeni bilgileri ayır
        new_username=$(echo "$form_result" | cut -d'|' -f1 | xargs)
        new_ad=$(echo "$form_result" | cut -d'|' -f2 | xargs)
        new_soyad=$(echo "$form_result" | cut -d'|' -f3 | xargs)
        new_rol=$(echo "$form_result" | cut -d'|' -f4 | xargs)
        new_parola=$(echo "$form_result" | cut -d'|' -f5 | xargs)
        
        # Yeni bilgilerin geçerliliğini kontrol et
        vars=( "$new_username" "$new_ad" "$new_soyad" "$new_rol" "$new_parola" )
        
        # Boş giriş kontrolü
        if [ "$error_control" == false ]; then
            for var in "${vars[@]}"; do
                if [ -z "$var" ]; then
                    ((errors+=1))
                    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Boş bilgi girişi!" >> "$LOGFILE"
                    zenity --error --text="Bir bilginin değeri boş bırakılamaz!" --title="Hata"
                    is_valid=false
                    error_control=true
                    break
                fi
            done
        fi
        
        # Kullanıcı adı kontrolü (varsa hata)
        if [ "$error_control" == false ]; then
            for line in $(cat "$DATABASE"); do
                username_check=$(echo "$line" | cut -d',' -f2)
                if [ "$username_check" == "$new_username" ]; then
                    ((errors+=1))
                    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Var olan kullanıcı ekleme!" >> "$LOGFILE"
                    zenity --error --text="Böyle bir kullanıcı adı var!" --title="Hata"
                    is_valid=false
                    error_control=true
                fi
            done
        fi
        
        # Rol kontrolü (sadece 'admin' veya 'user')
        if [ "$error_control" == false ]; then
            for var in "${vars[@]}"; do
                if [ "$var" != "$new_rol" ] && { [ "$var" == "admin" ] || [ "$var" == "user" ]; }; then
                    ((errors+=1))
                    echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Yasaklı bilgi girişi" >> "$LOGFILE"
                    zenity --error --text="Rol dışında bir bilgi 'admin' veya 'user' olamaz!" --title="Hata"
                    is_valid=false
                    error_control=true
                    break
                fi
            done
        fi
        
        # Rol kısmına sadece 'admin' veya 'user' yazılabilir
        if [ "$error_control" == false ]; then
            if [ "$new_rol" != "admin" ] && [ "$new_rol" != "user" ]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Kullanıcı bilgileri:,$system_user, Bilgilendirme: Rol girdi hatası!" >> "$LOGFILE"
                zenity --error --text="Rol sadece 'admin' veya 'user' olabilir!" --title="Hata"
                is_valid=false
            fi
        fi
        
        # Geçerli bilgileri aldıysak döngüden çık
        if [ "$is_valid" == true ]; then
            break
        fi
    done
    
    # Kilitli kullanıcıları kontrol et ve sil
    for line in $(cat "$LOCKED_USERS"); do
        locked_username_check=$(echo "$line" | cut -d',' -f2)
        if [ "$locked_username_check" == "$username" ]; then
            sed -i "/^$line\$/d" "$LOCKED_USERS"
        fi
    done
    
    # Yeni kullanıcı bilgilerini oluştur
    new_line="$selected_user_no,$new_username,$new_ad,$new_soyad,$new_rol,$new_parola"
    
    # İlerleme çubuğu ile kullanıcıyı güncelle
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Kullanıcı Güncelleme" --text="Kullanıcı güncelleniyor..." --percentage=0
    
    # Eski satırı yeni satırla değiştir
    sed -i "s/^$user_info\$/$new_line/" "$DATABASE"

    zenity --info --text="Kullanıcı bilgileri başarıyla güncellendi!"
}

# Kullanıcı Silme Fonksiyonu
delete_user() {
    system_user="$system_user_info"
    date=$(date)
    flag=0
    while true; do
        # Kullanıcı bilgilerini al
        result=$(zenity --forms --title="Kullanıcı Silme" \
            --add-entry="Kullanıcı Numara" \
            --add-entry="Kullanıcı Adı")
        
        # Pencereyi kapattıysa işlemi sonlandır
        if [ $? -ne 0 ]; then
            return
        fi
        
        # Kullanıcı bilgilerini ayır
        delete_user_no=$(echo "$result" | cut -d'|' -f1 | xargs)
        delete_username=$(echo "$result" | cut -d'|' -f2 | xargs)
        
        # Boş giriş kontrolü
        if [ -z "$delete_username" ] || [ -z "$delete_user_no" ]; then
            ((errors+=1))
            echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Boş bilgi girişi!" >> "$LOGFILE"
            zenity --error --text="Hata: Boş bilgi girilemez!"
        else
            # Kullanıcıyı veritabanında ara
            user_info=$(grep "$delete_user_no,$delete_username," "$DATABASE")
            
            # Sistemdeki kullanıcıyı silme işlemi engelle
            if [ "$user_info" == "$system_user_info" ]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Sistem kullanıcısı silinemaz!" >> "$LOGFILE"
                zenity --error --text="Hata: Kendinizi silemezsiniz!"
            # Kullanıcı bulunamadıysa hata ver
            elif [ -z "$user_info" ]; then
                ((errors+=1))
                echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Bulunmayan kullanıcı silinmeye çalışıldı!" >> "$LOGFILE"
                zenity --error --text="Hata: Böyle bir kullanıcı yok!"
            else
                # Kullanıcıdan silme onayı al
                zenity --question --title="Kullanıcı Silme Onayı" --text="Kullanıcı bilgileri:\n\nKullanıcı Numarası: $delete_user_no\nKullanıcı Adı: $delete_username\n\nBu kullanıcıyı silmek istediğinize emin misiniz?"

                # Kullanıcı onaylamazsa işlem iptal edilir
                if [ $? -ne 0 ]; then
                    zenity --info --text="İşlem iptal edildi."
                    return
                fi

                # Kilitli kullanıcıyı LOCKED_USERS dosyasından sil
                ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Kullanıcı Silme" --text="Kullanıcı siliniyor..." --percentage=0
                # Kullanıcıyı veritabanından sil
                grep -v "$delete_user_no,$delete_username" "$DATABASE" > temp_deleted_users.csv 
                mv temp_deleted_users.csv "$DATABASE"
                
                zenity --info --text="'$delete_username' kullanıcısı başarıyla silindi."
                
                # Kullanıcı numaralarını güncelle renumber_users
                renumber_users
                
                return
            fi
        fi
    done
}

renumber_users() { # kullanıcı numaralarını güncelle
    temp_file=$(mktemp)
    count=1
    while IFS=',' read -r user_no username other_info; do
        echo "$count,$username,$other_info" >> "$temp_file"
        ((count++))
    done < "$DATABASE"
    
    mv "$temp_file" "$DATABASE"
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Kullanıcı Silme" --text="Kullanıcı numaraları güncelleniyor..." --percentage=0
    zenity --info --text="Kullanıcı numaraları başarıyla güncellendi."
}


#----------------------------------User Functions End---------------------------------------


#----------------------------------Disc Functions Start-----------------------------------------
# Disk kullanımını gösteren fonksiyon
show_disk_usage() {
    # Disk kullanımını al ve sıralı şekilde düzenle
    disk_usage=$(df -h | awk 'NR==1; NR > 1 {print $0 | "sort -k6"}')

    # Disk bilgilerini tutacak array (liste)
    data=()

    # Her satırı işleyip array'e ekle
    while IFS= read -r line; do
        filesystem=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        avail=$(echo "$line" | awk '{print $4}')
        use_percent=$(echo "$line" | awk '{print $5}')
        mounted_on=$(echo "$line" | awk '{print $6}')

        # Başlık satırını atla
        if [ "$filesystem" = "Filesystem" ]; then
            continue
        fi

        data+=("$filesystem" "$size" "$used" "$avail" "$use_percent" "$mounted_on")
    done <<< "$disk_usage"
    
    # Kullanıcıya işlem ilerlemesini göster
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Kullanıcı Silme" --text="Program alanı hesaplanıyor..." --percentage=0

    # Zenity ile disk kullanım bilgilerini göster
    zenity --list --title="Disk Alanı" \
        --column="Dosya Sistemi" \
        --column="Toplam Boyut" \
        --column="Kullanılan" \
        --column="Kullanılabilir" \
        --column="Kullanım %" \
        --column="Bağlı Olduğu Yer" \
        "${data[@]}" \
        --width=700 \
        --height=400
}

# Diske yedek alan fonksiyon
backup_to_disk() {
    # Yedek dosyasının adını oluştur
    backup_file="backup_$(date +%Y%m%d%H%M%S).tar.gz"
    
    # Eksik dosyaları kontrol et
    missing_files=()
    for file in "$DEPOFILE" "$LOGFILE" "$DATABASE" "$LOCKED_USERS"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done

    # Eğer eksik dosya varsa hata mesajı göster
    if [ ${#missing_files[@]} -gt 0 ]; then
        ((errors+=1))
        echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Yedekleme hatası/dosya bulunamadı!" >> "$LOGFILE"
        zenity --error --title="Yedekleme Hatası" --text="Aşağıdaki dosyalar bulunamadı ve yedekleme işlemi yapılamadı:\n\n$(printf '%s\n' "${missing_files[@]}")"
        return
    fi
    
    # Yedekleme işlemine başla
    ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Kullanıcı Silme" --text="Sistem dosyaları yedekleniyor..." --percentage=0

    # Dosyalar varsa yedekleme işlemi yap
    tar -czf "$backup_file" "$DEPOFILE" "$LOGFILE" "$DATABASE" "$LOCKED_USERS"
    zenity --info --title="Yedekleme İşlemi" --text="Yedekleme başarıyla tamamlandı.\nYedek dosyası: $backup_file"
}

# Hata dosyasını gösteren fonksiyon
show_error_log() {
    # Hata dosyası varsa göster
    if [ -f "$LOGFILE" ]; then
        ( echo "0" ; sleep 0.5 ; echo "25"; sleep 0.5; echo "50"; sleep 0.5; echo "75" ; sleep 0.5 ; echo "100" ) | zenity --progress --title="Kullanıcı Silme" --text="Hata dosyası getiriliyor..." --percentage=0
        zenity --text-info --title="Hata Dosyası" --filename="$LOGFILE" --width=600 --height=400
    else
        ((errors+=1))
        echo "Hata:,$errors,Tarih: $date,Yönetici bilgileri:,$system_user, Bilgilendirme: Hata dosyası bulunamadı!" >> "$LOGFILE"
        zenity --error --title="Hata" --text="Hata dosyası bulunamadı."
    fi
}

#----------------------------------Disc Functions End----------------------------------------

# Program başı döngüsü, buradan çıkış yapıldı mı program biter
while true; do
    # Kullanıcıya seçenekler sunuluyor
    CHOICE=$(zenity --list --title="HOŞGELDİNİZ" --column="Seçenekler" \
        "Giriş Yap" \
        "Çıkış Yap")

    # Eğer kullanıcı pencereyi kapatmışsa, çıkış yap
    if [ $? -ne 0 ]; then
        exit 0  # Programı sonlandır
    fi

    # Seçilen seçeneğe göre işlemi gerçekleştir
    case $CHOICE in
        "Giriş Yap") 
            sign_in_func  # Giriş yapma fonksiyonunu çağır
            ;;
        "Çıkış Yap") 
            zenity --info --text="Çıkış yapılıyor ..."  # Çıkış yapıldığını belirten bilgi mesajı
            break  # Döngüden çık
            ;;
        *) 
            zenity --error --text="Geçersiz seçim."  # Geçersiz seçim yapıldıysa hata mesajı
            ;;
    esac
done

