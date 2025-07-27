# 📄 PRD – Budgeting App

## 🧱 1. Overview

**Nama Proyek:** Moneo
**Platform:** Flutter (Multiplatform – Android, iOS, Desktop, Web)
**Offline-first:** Pakai Drift (SQLite)
**Cloud Sync Opsional:** Supabase (email-password login)
**Export/Import:** JSON
**Use Case Utama:**

* Personal finance tracker yang bisa dipakai tanpa login
* Budgeting multi-wallet dan multi-kategori
* Mudah diakses, ringan, dan user-friendly

---

## 📌 2. Fitur Utama

### 🔹 2.1 Dashboard

* Greetings (berdasarkan waktu)
* Total uang tersedia = total saldo dari semua wallet
* Pinned Wallets (Card style, 2 column 2 row max to pin(4 wallet))

  * Info: nama + saldo
  * Titik tiga (popup: edit / delete)
  * Klik → halaman detail wallet
* Add Wallet button, All Wallet Button(akan mengarahkan user ke halaman yang berisi daftar semua wallet yang user punya)
* Recent Transactions (max 10)

  * Tampilkan: kategori, nominal, wallet, notes, timestamp

### 🔹 2.2 Transactions

* Tampilkan semua transaksi dari semua wallet
* Tampilkan: kategori, nominal, notes, wallet, timestamp
* FAB (Floating Action Button): Tambah transaksi

  * Input:

    * Nominal
    * Tipe: Income / Expense
    * Kategori
    * Wallet
    * Catatan (optional)
    * Tanggal & waktu
* Filter opsional: kategori, wallet, rentang tanggal

### 🔹 2.3 Budget

#### 🔸 Expense Categories

* Tambah/edit/delete kategori
* Set budget bulanan per kategori

#### 🔸 Recurring Expense

* Buat expense otomatis (weekly / monthly)
* Contoh: langganan Netflix, listrik
* Pilih wallet + kategori + nominal + frekuensi

#### 🔸 Savings

* Free Saving: nabung manual ke kategori tabungan
* Recurring Saving: target mingguan/bulanan otomatis
* Tampilkan progress tabungan

### 🔹 2.4 Wallet

* Multi-wallet support
* Halaman wallet detail:

  * Nama Wallet + Total saldo
  * Edit / Delete
  * Tabel semua histori transaksi wallet ini

### 🔹 2.5 Settings

* Export data (JSON file)
* Import data (JSON file)
* Login / Signup via Supabase

  * Sync lokal → cloud
  * Cloud → replace lokal
  * Opsional merge
* Reset app data (clear Drift)
* Dark Mode toggle (optional)

---

## ☁️ 3. Supabase Sync

### Login/Signup

* Email + password via Supabase Auth

### Sync Flow

* Jika user login:

  * Jika belum ada data cloud: upload dari Drift
  * Jika sudah ada data cloud: tawarkan opsi

    1. **Sync local → cloud**
    2. **Replace local ← cloud**
    3. **Merge manual (opsional nanti)**

---

## 🔄 4. Export/Import JSON

### Export

* Semua data Drift → JSON → simpan ke file

### Import

* Load file JSON → overwrite semua tabel Drift

---

## 🎨 5. Desain & UI

### Gaya Desain:

* Modern, bersih, fokus usability
* Warna primary biru
* Font: Inter
* Icon: Phosphor Icons

### Navigasi:

* BottomNavigationBar 4 menu:

  1. Dashboard
  2. Transactions
  3. Budget
  4. Settings

---