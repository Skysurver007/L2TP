#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$EUID" -ne 0 ]
  then echo "Jalankan script ini sebagai root!"
  exit
fi

# Mengatur password root
echo "root:007putra" | chpasswd

echo "Password root berhasil diubah menjadi: 007putra"
