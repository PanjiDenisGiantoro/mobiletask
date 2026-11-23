# API Push Notification (FCM) — Spesifikasi Backend & Mobile

Base URL: `https://flovig.com/api`  
Header: `Authorization: Bearer <token>`, `Accept: application/json`

---

## 1. Endpoint Device Token

### Simpan / Perbarui FCM Token
Dipanggil mobile otomatis setelah login, restore session, dan saat token dirotasi.

```http
POST /api/device-tokens
Content-Type: application/json

{
  "token": "<fcm_device_token>",
  "platform": "android"
}
```
Response `200` / `201`:
```json
{ "message": "Device token tersimpan." }
```

> Simpan `user_id` dan `company_id` dari user yang login (unique by `token`), agar push selalu terisolasi **per company** dan hanya dikirim ke member yang bergabung di proyek terkait.

### Hapus FCM Token (Saat Logout / Matikan Notifikasi)
```http
DELETE /api/device-tokens
Content-Type: application/json

{ "token": "<fcm_device_token>" }
```
Response `200`: `{ "message": "Device token dihapus." }`

---

## 2. Format Payload FCM dari Backend

Kirim via **FCM HTTP v1** dengan `channel_id: "flovig_high_importance"` (Android) dan field `data` agar saat user mengetuk notifikasi langsung membuka layar tujuan:

```json
{
  "message": {
    "token": "<fcm_device_token>",
    "notification": {
      "title": "Tugas Baru di Proyek Website",
      "body": "Budi menugaskan Anda: Perbaiki halaman checkout"
    },
    "android": {
      "priority": "high",
      "notification": {
        "channel_id": "flovig_high_importance"
      }
    },
    "data": {
      "type": "task",
      "id": "42",
      "project_id": "10"
    }
  }
}
```

Nilai `data.type` yang didukung aplikasi mobile:
- `task` → membuka `/task/{id}`
- `ticket` → membuka `/ticket/{id}`
- `project` → membuka `/project/{id}`
- `dm` / `chat` → membuka `/thread/dm:{id}`
- Atau kirim `data.route` langsung (misal `"/project/10"`).

---

## 3. Langkah Aktivasi Firebase di Android
1. Buat project di [Firebase Console](https://console.firebase.google.com) dan tambahkan aplikasi Android dengan `applicationId` sesuai `android/app/build.gradle.kts` (`com.flovig.app`).
2. Unduh `google-services.json` lalu salin ke `android/app/google-services.json`.
3. Jalankan ulang `flutter build apk --release` (plugin `com.google.gms.google-services` otomatis aktif saat file tersebut ada).
