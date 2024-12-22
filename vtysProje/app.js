const express = require('express');
const path = require('path');
const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',       
  host: 'localhost',
  database: 'vtys', 
  password: '123',      
  port: 5432,
});

const app = express();
app.use(express.json());

// Statik dosyaları sunuyoruz (index.html dahil):
app.use(express.static(path.join(__dirname, '.')));

// UYELER CRUD
app.get('/uyeler', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM "UYELER"');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send('Hata!');
  }
});

app.post('/uyeler', async (req, res) => {
  const { ad, soyad, plan_id, dogum_tarihi, cinsiyet, iletisim_bilgisi } = req.body;
  try {
    const result = await pool.query(`
      INSERT INTO "UYELER"("ad","soyad","plan_id","dogum_tarihi","cinsiyet","iletisim_bilgisi")
      VALUES($1,$2,$3,$4,$5,$6) RETURNING *`,
    [ad, soyad, plan_id, dogum_tarihi, cinsiyet, iletisim_bilgisi]);
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});


app.put('/uyeler/:id', async (req, res) => {
  const { id } = req.params;
  const { ad, soyad, plan_id } = req.body;
  try {
    const result = await pool.query(`
      UPDATE "UYELER"
      SET "ad"=$1,"soyad"=$2,"plan_id"=$3
      WHERE "uye_id"=$4 RETURNING *`, [ad, soyad, plan_id, id]);
    if (result.rowCount === 0) return res.status(404).send('Uye bulunamadi');
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});

app.delete('/uyeler/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(`
      DELETE FROM "UYELER"
      WHERE "uye_id"=$1 RETURNING *`, [id]);
    if (result.rowCount === 0) return res.status(404).send('Uye bulunamadi');
    res.send('Silindi');
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});

// URUNLER CRUD
app.get('/urunler', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM "URUNLER"');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send('Hata!');
  }
});

app.post('/urunler', async (req, res) => {
  const { urun_adi, aciklama, fiyat, stok_miktari } = req.body;
  try {
    const result = await pool.query(`
      INSERT INTO "URUNLER"("urun_adi","aciklama","fiyat","stok_miktari")
      VALUES($1,$2,$3,$4) RETURNING *`, [urun_adi, aciklama, fiyat, stok_miktari]);
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});

app.put('/urunler/:id', async (req, res) => {
  const { id } = req.params;
  const { urun_adi, aciklama, fiyat, stok_miktari } = req.body;
  try {
    const result = await pool.query(`
      UPDATE "URUNLER"
      SET "urun_adi"=$1,"aciklama"=$2,"fiyat"=$3,"stok_miktari"=$4
      WHERE "urun_id"=$5 RETURNING *`,
      [urun_adi, aciklama, fiyat, stok_miktari, id]);
    if (result.rowCount === 0) return res.status(404).send('Urun bulunamadi');
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});

app.delete('/urunler/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(`
      DELETE FROM "URUNLER"
      WHERE "urun_id"=$1 RETURNING *`, [id]);
    if (result.rowCount === 0) return res.status(404).send('Urun bulunamadi');
    res.send('Silindi');
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});



// Sakli Yordam cagirma (Aylik Odeme)
app.post('/aylikUyeOdemeHesapla', async (req, res) => {
  try {
    // Saklı yordamı çalıştır
    await pool.query(`CALL public.aylik_uye_odeme_hesapla();`);

    // Sadece bir sonraki ayın ödemelerini getir
    const result = await pool.query(`
      SELECT o."odeme_id", o."uye_id", o."tutar", o."odeme_tarihi", o."odeme_yontemi", u."ad", u."soyad"
      FROM "ODEMELER" o
      JOIN "UYELER" u ON o."uye_id" = u."uye_id"
      WHERE DATE_TRUNC('month', o."odeme_tarihi") = DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
      ORDER BY o."uye_id";
    `);

    res.json(result.rows); // Bir sonraki ayın ödemelerini döndür
  } catch (err) {
    console.error(err);
    res.status(500).send('Hata!');
  }
});

// Fonksiyon cagirma: UyePlanAdiDondur
app.get('/uyeler/:id/plan_adi', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(`SELECT "UyePlanAdiDondur"($1) as plan_adi`, [id]);
    if (result.rows.length === 0) return res.status(404).send('Uye bulunamadi');
    res.json({ plan_adi: result.rows[0].plan_adi });
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});
// Fonksiyon 1: UyePlanAdiDondur
app.get('/fonksiyon/UyePlanAdiDondur/:uye_id', async (req, res) => {
  const { uye_id } = req.params;
  try {
    const result = await pool.query(`SELECT public."UyePlanAdiDondur"($1) AS plan_adi`, [uye_id]);
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});
// Fonksiyon 2: CalisanDersSayisi
app.get('/fonksiyon/CalisanDersSayisi/:calisan_id', async (req, res) => {
  const { calisan_id } = req.params;
  try {
    const result = await pool.query(`SELECT public."CalisanDersSayisi"($1) AS ders_sayisi`, [calisan_id]);
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});

// Fonksiyon 3: DersToplamRezervasyonSayisi
app.get('/fonksiyon/DersToplamRezervasyonSayisi/:ders_id', async (req, res) => {
  const { ders_id } = req.params;
  try {
    const result = await pool.query(`SELECT public."DersToplamRezervasyonSayisi"($1) AS rezervasyon_sayisi`, [ders_id]);
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});

// Fonksiyon 4: EtkinlikListesiMetin
app.get('/fonksiyon/EtkinlikListesiMetin', async (req, res) => {
  try {
    const result = await pool.query(`SELECT public."EtkinlikListesiMetin"() AS etkinlikler`);
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message);
  }
});

app.listen(3000, () => console.log('Sunucu 3000 portunda calisiyor...'));
