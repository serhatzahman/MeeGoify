# MeeGoify (v3.0.0) 🎵
### Nokia N9 (MeeGo 1.2 Harmattan) İçin Modern Müzik Çalar ve Akış İstemcisi

[![MeeGo 1.2 Harmattan](https://img.shields.io/badge/Platform-MeeGo%201.2%20Harmattan-00adef.svg)](https://en.wikipedia.org/wiki/MeeGo)
[![Device](https://img.shields.io/badge/Device-Nokia%20N9-black.svg)](https://en.wikipedia.org/wiki/Nokia_N9)
[![Go Version](https://img.shields.io/badge/Go-1.18%2B-00ADD8.svg)](https://golang.org)
[![Python Version](https://img.shields.io/badge/Python-2.6%20%2F%20PySide-3776AB.svg)](https://wiki.qt.io/PySide)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> [🇬🇧 Click here for English Documentation (README.md)](README.md)

**MeeGoify**, efsanevi **Nokia N9 (MeeGo 1.2 Harmattan)** akıllı telefonu için sıfırdan tasarlanmış modern bir müzik dinleme ve yayınlama sistemidir. Bilgisayarınızda veya yerel ağınızda çalışan yüksek performanslı **Go Köprü Sunucusu (Bridge Server)** ile Nokia N9 üzerinde çalışan yerel **PySide / QtQuick QML İstemcisi** bir araya gelerek kusursuz bir müzik deneyimi sunar.

MeeGo Harmattan'ın ödüllü *Blanco (Swipe)* tasarım dilini saf AMOLED siyahıyla birleştiren MeeGoify; albüm kapakları, senkronize şarkı sözleri, kilit ekranı kontrolleri, müzik indirme ve tür filtreleme gibi özellikleri 2011 model N9'da akıcı bir şekilde çalıştırır.

---

## 🌟 Öne Çıkan Özellikler

- **Saf AMOLED Siyah Tema (`#000000`):** Nokia N9'un ClearBlack AMOLED ekranında pikselleri kapatarak maksimum pil tasarrufu ve gerçek siyah derinliği sağlar.
- **Yenilenen Hibrit Ana Sayfa Paneli:**
  - **Hızlı Tür & Kategori Hapları (Pills):** Pop, Rock, Rap, 90'lar, Akustik, Hits, Elektronik ve Chill için özel olarak tasarlanmış 48x48 piksellik net PNG simgeleriyle tek dokunuşla müzik türü keşfi.
  - **Son Aramalar:** Yapılan aramaları etiketler (chips) halinde saklar. Tek dokunuşla aramayı yineler, `×` simgesiyle tekil veya `Temizle` ile topluca silinebilir.
  - **Son Dinlenenler:** Çalınan parçalar albüm kapağı, parça ve sanatçı bilgisiyle listelenir. Dokunulduğunda hemen çalmaya başlar.
- **Çok Kaynaklı Kapak Çözücü (Fallback Resolver):** Spotify CDN'in doğrudan erişim engeli (403) koyduğu durumlarda devreye giren Deezer ve iTunes yedek kapak motoru ile kapaklar her zaman yüklenir.
- **MeeGo D-Bus MPRIS2 Entegrasyonu:** Bekleme (Glance) ekranında ve Kilit Ekranında albüm kapağı, şarkı bilgileri ve 3.5mm kulaklık kumanda tuşlarıyla tam kontrol.
- **Senkronize Şarkı Sözleri (Lyrics):** [LRCLIB](https://lrclib.net/) entegrasyonu sayesinde çalan müzikle eşzamanlı kayan şarkı sözleri; sözlere dokunarak şarkının o saniyesine sarma desteği.
- **Çevrimdışı İndirme Yöneticisi:** Beğendiğiniz parçaları tek tuşla `/home/user/MyDocs/Music/MeeGoify` dizinine MP3 olarak indirip N9'un yerel müzik çalarında dinleme imkanı.
- **Otomatik Sunucu Keşfi (UDP Broadcast):** Telefondan elle IP yazma zahmetini ortadan kaldıran tek tuşla otomatik sunucu bulma (Port 8088).
<img width="480" height="854" alt="Screenshot_20261005_223016" src="https://github.com/user-attachments/assets/4b40b3a7-611d-415e-9d9d-2f81a5a079a7" />
<img width="480" height="854" alt="Screenshot_20261005_223002" src="https://github.com/user-attachments/assets/8cfedfbb-431c-4607-aabf-ac439b33f4ee" />
<img width="480" height="854" alt="Screenshot_20261005_222950" src="https://github.com/user-attachments/assets/dcb2d8f9-94fa-4d48-8774-4b8cf9ca6884" />
<img width="480" height="854" alt="Screenshot_20261005_222819" src="https://github.com/user-attachments/assets/22998020-46aa-4027-a6bc-a30fd561960f" />
<img width="480" height="854" alt="Screenshot_20261005_223156" src="https://github.com/user-attachments/assets/371e31ff-8010-4552-8875-1ae70181dbbe" />
<img width="480" height="854" alt="Screenshot_20261005_223028" src="https://github.com/user-attachments/assets/28327fe7-53c7-4adf-b67c-7275c7d17bf5" />

---

## 📐 Sistem Mimarisi

```text
               +-------------------------------------------+
               |        Nokia N9 (MeeGo Harmattan)         |
               |                                           |
               |   • PySide & QtQuick 1.1 QML Arayüzü      |
               |   • D-Bus MPRIS2 (Kilit & Glance Ekranı)  |
               |   • GStreamer / Phonon Çalma Motoru       |
               |   • Arka Plan İndirme Yöneticisi          |
               +-------------------------------------------+
                                     ▲
                                     │ Düz HTTP / MP3 Akışı
                                     │ Port 8080 (TCP) & 8088 (UDP)
                                     ▼
               +-------------------------------------------+
               |        Go Köprü Sunucusu (PC / Mac)       |
               |                                           |
               |   • Spotify Web API & Arama Motoru        |
               |   • Deezer & iTunes Yedek Çözücüleri      |
               |   • Disk Önbellek & HTTP 206 (Hızlı Sarma)|
               |   • LRCLIB Senkronize Şarkı Sözü Servisi  |
               |   • UDP Otomatik Sunucu Keşif Yayını      |
               +-------------------------------------------+
```

---

## 📁 Proje Dosya Yapısı

```text
meegoify/
├── README.md               # İngilizce Kullanım Kılavuzu
├── README_TR.md            # Türkçe Kullanım Kılavuzu
├── LICENSE                 # MIT Lisansı
├── .gitignore              # Git yapılandırması
├── update_n9.sh            # Nokia N9 Tek Tuşla Kurulum ve Güncelleme Betiği
├── server/                 # Go Köprü Sunucusu
│   ├── .env.example        # Örnek yapılandırma dosyası
│   ├── go.mod              # Go modül tanımı
│   ├── config.go           # Sunucu yapılandırma ve önbellek yönetimi
│   ├── lyrics.go           # LRCLIB şarkı sözü servisi
│   ├── main.go             # Ana HTTP yönlendirici ve sunucu girişi
│   ├── proxy.go            # Kapak proxy'si ve Deezer/iTunes çözücüsü
│   ├── spotify.go          # Spotify API ve alternatif arama motoru
│   └── stream.go           # Ses akışı ve disk önbellek sistemi
└── client/                 # Nokia N9 İstemcisi
    ├── main.py             # PySide başlatıcı, D-Bus servisi, indirme motoru
    ├── harmattan/
    │   ├── meegoify.desktop # MeeGo uygulama menüsü kısayolu
    │   └── meegoify.png     # 80x80 Harmattan uygulama simgesi
    └── qml/                # QML Arayüz Kodları
        ├── main.qml        # Ana pencere, oynatıcı mantığı, bildirimler
        ├── SearchPage.qml  # Ana panel: Tür hapları, arama, geçmiş listeleri
        ├── PlayerPage.qml  # Oynatıcı: Kapak, senkron şarkı sözleri, süre çubuğu
        ├── LibraryPage.qml # Favoriler ve önerilen parçalar
        ├── meegoify_logo.png# MeeGoify dairesel logo
        ├── genre_*.png     # 8 adet 48x48 özel kategori simgesi
        └── components/
            └── TrackDelegate.qml # AMOLED liste öğesi bileşeni
```

---

## 🛠️ Gereksinimler

### 1. Bilgisayar (Sunucu Tarafı)
- **Go 1.18 veya daha yenisi** (Windows, Linux veya macOS).
- **Ağ:** Bilgisayar ve Nokia N9'un aynı Wi-Fi ağına bağlı olması gereklidir.
- **Port:** Güvenlik duvarında `8080` (HTTP) ve `8088` (UDP) portlarına izin verilmelidir.

### 2. Nokia N9 Telefon
- **Nokia N9** (MeeGo 1.2 Harmattan PR 1.3 önerilir).
- **Geliştirici Modu:** Ayarlar > Güvenlik > Geliştirici Modu açık olmalıdır (Terminal ve `devel-su` erişimi için).
- **Gerekli Paketler:** Telefon terminalinde şu komutla kurulabilir:
  ```sh
  devel-su
  # Varsayılan şifre: rootme
  apt-get update
  apt-get install python python-pyside.qtgui python-pyside.qtdeclarative python-dbus
  ```

---

## 🚀 Adım Adım Kurulum Kılavuzu

### 1. Adım: PC Köprü Sunucusunu Başlatma

1. Projeyi bilgisayarınıza indirin veya klonlayın:
   ```bash
   git clone https://github.com/kullanici-adiniz/meegoify.git
   cd meegoify/server
   ```
2. `.env` dosyasını oluşturun:
   ```bash
   cp .env.example .env
   ```
   *(İsteğe bağlı)* Spotify Geliştirici Anahtarlarınızı girebilirsiniz. Girmeseniz bile yerleşik arama motoru çalışacaktır.
3. Sunucuyu başlatın:
   ```bash
   go run .
   ```
   *Konsolda `Nokia N9 Spotify Bridge Server (v3.0.0)` yazısını gördüğünüzde sunucu hazırdır.*

---

### 2. Adım: Nokia N9'a Kurulum

1. **Nokia N9 IP Adresinizi Öğrenin:**
   Telefonda Ayarlar > İnternet bağlantıları > Bağlı olduğunuz Wi-Fi ağına dokunun (Örn: `192.168.8.144`).

2. **Paketi Bilgisayardan Telefona Gönderin (PowerShell veya Terminal):**
   ```powershell
   scp -O -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa MeeGoify-v3.0.0.zip user@<N9-IP>:/home/user/meegoify.zip
   ```

3. **Telefonda Kurulumu Tamamlayın:**
   ```sh
   # PC'den SSH ile bağlanın veya telefon terminalini açın:
   ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa user@<N9-IP>

   # Root yetkisi alın:
   devel-su
   # (şifre: rootme)

   # Paketi /tmp dizininde açıp kurulum betiğini çalıştırın:
   rm -rf /tmp/meegoify_pkg
   python -c "import zipfile; zipfile.ZipFile('/home/user/meegoify.zip').extractall('/tmp/meegoify_pkg')"
   cd /tmp/meegoify_pkg
   sh update_n9.sh
   ```

4. **Uygulamayı Açma:**
   - Nokia N9 uygulama menüsünde oluşan **MeeGoify** simgesine dokunun.
   - Ya da hata ayıklama için terminalden doğrudan çalıştırın:
     ```sh
     /opt/meegoify/main.py
     ```

5. **Sunucuya Bağlanma:**
   - Uygulama ilk açıldığında alt araç çubuğundaki **Ayarlar** simgesine dokunun.
   - Bilgisayarınızın IP adresini girin (Örn: `http://192.168.8.137:8080`) ya da **🔍 Ağda Sunucuyu Otomatik Bul** butonuna basın.

---

## ❓ Sık Karşılaşılan Sorular ve Çözümler

- **`QNetworkReplyImpl::_q_startOperation was called more than once` Uyarısı:**
  - Bu mesaj Qt 4.7'nin eşzamanlı görsel indirmeleri sırasında konsola bastığı dahili bir bilgilendirmedir. Bir hata değildir ve uygulamanın çalışmasını engellemez.
- **`Meego graphics system destroyed` Mesajı:**
  - Uygulama kapatıldığında MeeGo Harmattan pencere sisteminin kaynakları temizlediğini gösteren normal kapanış kaydıdır.
- **Kapaklar Yüklenmiyorsa:**
  - Bilgisayarınızdaki Go sunucusunun çalıştığından ve telefon tarayıcısından `http://<PC-IP>:8080/api/health` adresine erişebildiğinizden emin olun.
  - Sürüm 3.0.0 ile Deezer ve iTunes yedek arama motorları eklenmiştir; Spotify CDN engeli olsa dahi kapaklar otomatik olarak çekilir.
- **SSH Bağlantı Hatası (no matching host key type found):**
  - Modern SSH istemcileri eski RSA anahtarlarını varsayılan olarak devre dışı bırakır. Bağlanırken mutlaka `-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa` parametrelerini ekleyin.

---

## 📜 Lisans

Bu proje [MIT Lisansı](LICENSE) kapsamında lisanslanmıştır.
Nokia, MeeGo, Harmattan ve Spotify ilgili hak sahiplerinin ticari markalarıdır.
