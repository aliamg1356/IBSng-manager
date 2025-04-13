📡 Ushkaya Net - IBSng Docker Management Script

<p align="center"> <strong>یک راه‌حل جامع برای مدیریت IBSng در محیط داکر با قابلیت‌های پیشرفته</strong> </p>




|    🔴 توجه: عملیات نصب در سرورهای ایران به علت تحریم‌ها و نیاز به استفاده از DNS شکن            

|        ممکن است نسبت به اینترنت سرور و ساعت استفاده، زمان‌گیر باشد.                         

|    🟢 لطفاً در حین نصب صبور باشید و از قطع کردن فرآیند خودداری نمایید.                         

|    🟠 پیشنهاد می‌شود در ساعات کم‌ترافیک (شبانه‌روز) اقدام به نصب نمایید.                       
|                                                                                               

🌟 ویژگی‌های کلیدی


🚀 نصب خودکار با تشخیص هوشمند پیش‌نیازها

🔄 مدیریت کامل چرخه حیات (نصب، پشتیبان‌گیری، بازیابی، حذف)

🛡️ حل خودکار مشکلات تحریم با سیستم DNS شکن

📊 نمایش گرافیکی وضعیت و اطلاعات دسترسی

⚡ بهینه‌سازی شده برای سرورهای ایرانی

## 🛠️ نحوه استفاده

```bash
bash <(curl -s https://raw.githubusercontent.com/aliamg1356/IBSng-manager/refs/heads/main/ibsng.sh --ipv4)

```

یوزر و پسورد پیش فرض

username: system

Pssword:admin
## 🖥️ منوهای اصلی

1. **نصب IBSng**: 
   - بررسی و نصب خودکار داکر
   - دریافت پیکربندی‌های لازم
   - راه‌اندازی کانتینر

2. **پشتیبان‌گیری**: 
   - ایجاد دامپ از دیتابیس
   - فشرده‌سازی و ذخیره پشتیبان
   - پاکسازی لاگ‌های قدیمی

3. **بازیابی**: 
   - بازیابی دیتابیس از فایل پشتیبان
   - بازگردانی کامل سرویس

4. **حذف**: 
   - توقف و حذف کانتینر
   - پاکسازی ایمیج‌های استفاده شده

## 🛡️ امنیت و قابلیت اطمینان

- استفاده از مکانیزم‌های اعتبارسنجی در هر مرحله
- حفظ امنیت اطلاعات حساس
- امکان بازگردانی تغییرات در صورت بروز خطا
- ثبت لاگ کامل از عملیات انجام شده

## 📌 نکات فنی

- سازگار با سیستم‌های مبتنی بر لینوکس
- پشتیبانی از Docker و Docker Compose
- قابلیت اجرا روی سرورهای اختصاصی و مجازی


ریستور بکاپ از IBSng 

اگر بکاپی از خود ibsng  دارین برای ریستور به این دارک اول فایل دامپ رو به IBSng.bak تغییر نام داده و در /root کپی کنید بعد دستورات زیر رو به ترتیب وارد کنید
```
docker cp /root/IBSng.bak ibsng:/var/lib/pgsql/IBSng.bak

docker exec -it ibsng /bin/bash
service IBSng stop
su - postgres
dropdb IBSng
createdb IBSng
createlang plpgsql IBSng
psql IBSng < IBSng.bak
exit
service IBSng start
```
بعد با ctrl+d از محیط کانتینر خارج شوید


## 💰 حمایت مالی

ما از حمایت شما برای توسعه و بهبود مستمر پروژه قدردانی می‌کنیم:

<div align="center">

| شبکه         | نوع ارز       | آدرس کیف پول                              | آیکون       |
|--------------|--------------|------------------------------------------|------------|
| **Tron**     | TRX (TRC20)  | `TMXRpCsbz8PKzqN4koXiErawdLXzeinWbQ`     | <img src="https://cryptologos.cc/logos/tron-trx-logo.png" width="20"> |
| **Ethereum** | USDT (ERC20) | `0xD4cEBA0cFf6769Fb9EFE4606bE59C363Ff85BF76` | <img src="https://cryptologos.cc/logos/tether-usdt-logo.png" width="20"> |

</div>

<div align="center" style="margin-top: 20px;">
  <p>🙏 از اعتماد و حمایت ارزشمند شما سپاسگزاریم</p>
  <p>هر میزان کمک مالی، انگیزه‌ای برای توسعه و ارتقای پروژه خواهد بود</p>
</div>




## 📞 پشتیبانی

برای گزارش مشکلات یا پیشنهادات:
- ایمیل: support@ushkaya-net.ir
- تلگرام: https://t.me/freegate2tab_bot
- 
<p align="center"> <img src="https://img.shields.io/badge/Made%20with-❤️-red" alt="Made with love"> <img src="https://img.shields.io/badge/Powered%20by-Ushkaya%20Net-blue" alt="Powered by Ushkaya Net"> </p>
