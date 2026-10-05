#!/bin/sh
# MeeGoify N9 Tek Tuşla Güncelleme ve Kurulum Betiği
# Nokia N9 üzerinde root (devel-su) ile çalıştırın: sh update_n9.sh

set -e

echo "=== MeeGoify v3.0.0 Nokia N9 Güncellemesi ==="

# 1. Açık olan eski uygulamayı kapat
echo "[1/5] Çalışan eski işlemler kapatılıyor..."
killall -9 python python2.6 2>/dev/null || true

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 2. Eski spotify-n9 kalıntılarını temizle
echo "[2/5] Eski Spotify N9 kalıntıları temizleniyor..."
rm -f /usr/share/applications/spotify-n9.desktop
rm -rf /opt/spotify-n9

# 3. /opt/meegoify dizinine yeni dosyaları kur
echo "[3/5] Yeni MeeGoify dosyaları /opt/meegoify dizinine kopyalanıyor..."
mkdir -p /opt/meegoify/qml
cp -rf "$SCRIPT_DIR/client/main.py" /opt/meegoify/
cp -rf "$SCRIPT_DIR/client/qml/"* /opt/meegoify/qml/

# 4. İkon ve Masaüstü kısayolunu sisteme ekle
echo "[4/5] Yeni menü simgesi ve kısayol kuruluyor..."
if [ -f "$SCRIPT_DIR/client/harmattan/meegoify.png" ]; then
    cp -f "$SCRIPT_DIR/client/harmattan/meegoify.png" /opt/meegoify/meegoify.png
    cp -f "$SCRIPT_DIR/client/harmattan/meegoify.png" /usr/share/icons/hicolor/80x80/apps/meegoify.png 2>/dev/null || true
fi

cp -f "$SCRIPT_DIR/client/harmattan/meegoify.desktop" /usr/share/applications/meegoify.desktop

# 5. Yetkilendirme ve Menü yenileme
echo "[5/5] Yetkiler veriliyor ve menü yenileniyor..."
chmod +x /opt/meegoify/main.py
chmod 644 /usr/share/applications/meegoify.desktop
chmod 644 /opt/meegoify/meegoify.png 2>/dev/null || true
chmod 644 /opt/meegoify/qml/*.png 2>/dev/null || true

killall m-feed 2>/dev/null || true

echo ""
echo "=================================================="
echo "✓ Tebrikler! MeeGoify v3.0.0 başarıyla kuruldu."
echo "Nokia N9 menünüzde 'MeeGoify' simgesini görebilirsiniz."
echo "=================================================="
