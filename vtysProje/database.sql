PGDMP                          |            vtys    15.10    15.10 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    24576    vtys    DATABASE     y   CREATE DATABASE vtys WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Turkish_T�rkiye.1254';
    DROP DATABASE vtys;
                postgres    false                       1255    24748    CalisanDersSayisi(integer)    FUNCTION     �  CREATE FUNCTION public."CalisanDersSayisi"(p_calisan_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_gorev VARCHAR;
    v_sayi INT;
BEGIN
    -- Calisanin gorevini bulur
    SELECT "gorev" INTO v_gorev
    FROM "CALISANLAR"
    WHERE "calisan_id" = p_calisan_id;

    IF v_gorev = 'egitmen' THEN
        SELECT COUNT(*)
        INTO v_sayi
        FROM "DERSLER"
        WHERE "calisan_id" = p_calisan_id;
        RETURN v_sayi;
    ELSE
        RETURN 0;
    END IF;
END;
$$;
 @   DROP FUNCTION public."CalisanDersSayisi"(p_calisan_id integer);
       public          postgres    false            �            1255    24749 $   DersToplamRezervasyonSayisi(integer)    FUNCTION     Y  CREATE FUNCTION public."DersToplamRezervasyonSayisi"(p_ders_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_sayi INT;
BEGIN
    SELECT COUNT(*)
    INTO v_sayi
    FROM "DERS_REZERVASYONLARI" r
    JOIN "DERS_TAKVIMLERI" t ON r."takvim_id" = t."takvim_id"
    WHERE t."ders_id" = p_ders_id;

    RETURN v_sayi;
END;
$$;
 G   DROP FUNCTION public."DersToplamRezervasyonSayisi"(p_ders_id integer);
       public          postgres    false            �            1255    24750    EtkinlikListesiMetin()    FUNCTION     �  CREATE FUNCTION public."EtkinlikListesiMetin"() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
    v_sonuc TEXT := '';
BEGIN
    FOR rec IN SELECT "etkinlik_id", "etkinlik_adi", "max_katilimci" FROM "ETKINLIKLER" ORDER BY "etkinlik_id"
    LOOP
        v_sonuc := v_sonuc || rec."etkinlik_id" || E'\t' || rec."etkinlik_adi" || E'\t' || COALESCE(rec."max_katilimci"::TEXT, 'NULL') || E'\r\n';
    END LOOP;
    RETURN v_sonuc;
END;
$$;
 /   DROP FUNCTION public."EtkinlikListesiMetin"();
       public          postgres    false            �            1255    24747    UyePlanAdiDondur(integer)    FUNCTION     U  CREATE FUNCTION public."UyePlanAdiDondur"(p_uye_id integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_plan_adi VARCHAR;
BEGIN
    SELECT "plan_adi"
    INTO v_plan_adi
    FROM "UYELER" u
    JOIN "UYELIK_PLANLARI" p ON u."plan_id" = p."plan_id"
    WHERE u."uye_id" = p_uye_id;

    RETURN v_plan_adi;
END;
$$;
 ;   DROP FUNCTION public."UyePlanAdiDondur"(p_uye_id integer);
       public          postgres    false                       1255    24751    aylik_uye_odeme_hesapla() 	   PROCEDURE     �  CREATE PROCEDURE public.aylik_uye_odeme_hesapla()
    LANGUAGE plpgsql
    AS $$DECLARE
    rec RECORD;
    v_tutar NUMERIC(10,2);
    v_bir_sonraki_ay DATE;
    v_odemeler_count INT;
BEGIN
    -- Her üyenin bir sonraki ay için ödemesini hesaplanır
    FOR rec IN
        SELECT u."uye_id", p."ucret"
        FROM "UYELER" u
        JOIN "UYELIK_PLANLARI" p ON u."plan_id" = p."plan_id"
    LOOP
        v_tutar := rec.ucret;
        v_bir_sonraki_ay := DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'; -- Bir sonraki ayın ilk günü

        -- Aynı üye için bir sonraki ay ödemesi zaten var mı kontrol eder
        SELECT COUNT(*) INTO v_odemeler_count
        FROM "ODEMELER"
        WHERE "uye_id" = rec."uye_id" AND DATE_TRUNC('month', "odeme_tarihi") = v_bir_sonraki_ay;

        -- Eğer ödeme kaydı yoksa ekler
        IF v_odemeler_count = 0 THEN
            INSERT INTO "ODEMELER"(
                "uye_id",
                "tutar",
                "odeme_tarihi",
                "odeme_yontemi"
            ) VALUES (
                rec."uye_id",
                v_tutar,
                v_bir_sonraki_ay,
                'otomatik_odeme'
            );
        END IF;
    END LOOP;
END;$$;
 1   DROP PROCEDURE public.aylik_uye_odeme_hesapla();
       public          postgres    false            �            1255    24754    ders_takvimleri_before_update()    FUNCTION     [  CREATE FUNCTION public.ders_takvimleri_before_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_mevcut_rezervasyon_sayisi INT;
BEGIN
    IF NEW."max_katilimci" IS NOT NULL AND OLD."max_katilimci" <> NEW."max_katilimci" THEN
        SELECT COUNT(*) INTO v_mevcut_rezervasyon_sayisi
        FROM "DERS_REZERVASYONLARI" r
        WHERE r."takvim_id" = OLD."takvim_id";

        IF NEW."max_katilimci" < v_mevcut_rezervasyon_sayisi THEN
            RAISE EXCEPTION 'Maksimum katilimci sayisi mevcut rezervasyon sayisindan az olamaz';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
 6   DROP FUNCTION public.ders_takvimleri_before_update();
       public          postgres    false            �            1255    24756    odemeler_before_insert()    FUNCTION     �   CREATE FUNCTION public.odemeler_before_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW."odeme_tarihi" IS NULL THEN
        NEW."odeme_tarihi" := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$;
 /   DROP FUNCTION public.odemeler_before_insert();
       public          postgres    false            �            1255    24758    urunler_before_update()    FUNCTION     ]  CREATE FUNCTION public.urunler_before_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW."fiyat" <> OLD."fiyat" THEN
        INSERT INTO "URUN_FIYAT_LOG"("urun_id", "eski_fiyat", "yeni_fiyat", "degisiklik_tarihi")
        VALUES(OLD."urun_id", OLD."fiyat", NEW."fiyat", CURRENT_TIMESTAMP);
    END IF;
    RETURN NEW;
END;
$$;
 .   DROP FUNCTION public.urunler_before_update();
       public          postgres    false            �            1255    24752    uyeler_before_insert()    FUNCTION     �  CREATE FUNCTION public.uyeler_before_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Ad ve soyad alanlarini buyuk harfe cevir
    NEW."ad" := UPPER(NEW."ad");
    NEW."soyad" := UPPER(NEW."soyad");

    -- Plan_id kontrolu
    IF NEW."plan_id" IS NULL THEN
        RAISE EXCEPTION 'Uye kaydi yapilirken plan_id bos birakilamaz';
    END IF;

    RETURN NEW;
END;
$$;
 -   DROP FUNCTION public.uyeler_before_insert();
       public          postgres    false            �            1259    24597 
   CALISANLAR    TABLE     �   CREATE TABLE public."CALISANLAR" (
    calisan_id integer NOT NULL,
    ad character varying(40) NOT NULL,
    soyad character varying(40) NOT NULL,
    gorev character varying(50) NOT NULL,
    ise_giris_tarihi date
);
     DROP TABLE public."CALISANLAR";
       public         heap    postgres    false            �            1259    24596    CALISANLAR_calisan_id_seq    SEQUENCE     �   CREATE SEQUENCE public."CALISANLAR_calisan_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public."CALISANLAR_calisan_id_seq";
       public          postgres    false    219            �           0    0    CALISANLAR_calisan_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public."CALISANLAR_calisan_id_seq" OWNED BY public."CALISANLAR".calisan_id;
          public          postgres    false    218            �            1259    24604    DERSLER    TABLE     �   CREATE TABLE public."DERSLER" (
    ders_id integer NOT NULL,
    ders_adi character varying(100) NOT NULL,
    ders_aciklama character varying(255),
    calisan_id integer NOT NULL
);
    DROP TABLE public."DERSLER";
       public         heap    postgres    false            �            1259    24603    DERSLER_ders_id_seq    SEQUENCE     �   CREATE SEQUENCE public."DERSLER_ders_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public."DERSLER_ders_id_seq";
       public          postgres    false    221            �           0    0    DERSLER_ders_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE public."DERSLER_ders_id_seq" OWNED BY public."DERSLER".ders_id;
          public          postgres    false    220            �            1259    24628    DERS_REZERVASYONLARI    TABLE        CREATE TABLE public."DERS_REZERVASYONLARI" (
    rezervasyon_id integer NOT NULL,
    takvim_id integer NOT NULL,
    uye_id integer NOT NULL,
    rezervasyon_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    durum character varying(50)
);
 *   DROP TABLE public."DERS_REZERVASYONLARI";
       public         heap    postgres    false            �            1259    24627 '   DERS_REZERVASYONLARI_rezervasyon_id_seq    SEQUENCE     �   CREATE SEQUENCE public."DERS_REZERVASYONLARI_rezervasyon_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 @   DROP SEQUENCE public."DERS_REZERVASYONLARI_rezervasyon_id_seq";
       public          postgres    false    225            �           0    0 '   DERS_REZERVASYONLARI_rezervasyon_id_seq    SEQUENCE OWNED BY     w   ALTER SEQUENCE public."DERS_REZERVASYONLARI_rezervasyon_id_seq" OWNED BY public."DERS_REZERVASYONLARI".rezervasyon_id;
          public          postgres    false    224            �            1259    24616    DERS_TAKVIMLERI    TABLE     �   CREATE TABLE public."DERS_TAKVIMLERI" (
    takvim_id integer NOT NULL,
    ders_id integer NOT NULL,
    baslama_zamani timestamp without time zone NOT NULL,
    bitis_zamani timestamp without time zone NOT NULL,
    max_katilimci integer NOT NULL
);
 %   DROP TABLE public."DERS_TAKVIMLERI";
       public         heap    postgres    false            �            1259    24615    DERS_TAKVIMLERI_takvim_id_seq    SEQUENCE     �   CREATE SEQUENCE public."DERS_TAKVIMLERI_takvim_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public."DERS_TAKVIMLERI_takvim_id_seq";
       public          postgres    false    223            �           0    0    DERS_TAKVIMLERI_takvim_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public."DERS_TAKVIMLERI_takvim_id_seq" OWNED BY public."DERS_TAKVIMLERI".takvim_id;
          public          postgres    false    222            �            1259    24659 
   EKIPMANLAR    TABLE     �   CREATE TABLE public."EKIPMANLAR" (
    ekipman_id integer NOT NULL,
    ekipman_adi character varying(100) NOT NULL,
    ekipman_turu character varying(50) NOT NULL,
    satin_alim_tarihi date,
    calisan_id integer NOT NULL
);
     DROP TABLE public."EKIPMANLAR";
       public         heap    postgres    false            �            1259    24658    EKIPMANLAR_ekipman_id_seq    SEQUENCE     �   CREATE SEQUENCE public."EKIPMANLAR_ekipman_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public."EKIPMANLAR_ekipman_id_seq";
       public          postgres    false    229            �           0    0    EKIPMANLAR_ekipman_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public."EKIPMANLAR_ekipman_id_seq" OWNED BY public."EKIPMANLAR".ekipman_id;
          public          postgres    false    228            �            1259    24671    EKIPMAN_BAKIMLARI    TABLE     �   CREATE TABLE public."EKIPMAN_BAKIMLARI" (
    bakim_id integer NOT NULL,
    ekipman_id integer NOT NULL,
    bakim_tarihi date NOT NULL,
    bakim_aciklama character varying(255)
);
 '   DROP TABLE public."EKIPMAN_BAKIMLARI";
       public         heap    postgres    false            �            1259    24670    EKIPMAN_BAKIMLARI_bakim_id_seq    SEQUENCE     �   CREATE SEQUENCE public."EKIPMAN_BAKIMLARI_bakim_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public."EKIPMAN_BAKIMLARI_bakim_id_seq";
       public          postgres    false    231            �           0    0    EKIPMAN_BAKIMLARI_bakim_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public."EKIPMAN_BAKIMLARI_bakim_id_seq" OWNED BY public."EKIPMAN_BAKIMLARI".bakim_id;
          public          postgres    false    230            �            1259    24683    ETKINLIKLER    TABLE     �   CREATE TABLE public."ETKINLIKLER" (
    etkinlik_id integer NOT NULL,
    etkinlik_adi character varying(100) NOT NULL,
    etkinlik_tarihi timestamp without time zone NOT NULL,
    konum character varying(100),
    max_katilimci integer
);
 !   DROP TABLE public."ETKINLIKLER";
       public         heap    postgres    false            �            1259    24682    ETKINLIKLER_etkinlik_id_seq    SEQUENCE     �   CREATE SEQUENCE public."ETKINLIKLER_etkinlik_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public."ETKINLIKLER_etkinlik_id_seq";
       public          postgres    false    233            �           0    0    ETKINLIKLER_etkinlik_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public."ETKINLIKLER_etkinlik_id_seq" OWNED BY public."ETKINLIKLER".etkinlik_id;
          public          postgres    false    232            �            1259    24690    ETKINLIK_KAYITLARI    TABLE     �   CREATE TABLE public."ETKINLIK_KAYITLARI" (
    etkinlik_kayit_id integer NOT NULL,
    etkinlik_id integer NOT NULL,
    uye_id integer NOT NULL,
    kayit_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);
 (   DROP TABLE public."ETKINLIK_KAYITLARI";
       public         heap    postgres    false            �            1259    24689 (   ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq    SEQUENCE     �   CREATE SEQUENCE public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq";
       public          postgres    false    235            �           0    0 (   ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq    SEQUENCE OWNED BY     y   ALTER SEQUENCE public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq" OWNED BY public."ETKINLIK_KAYITLARI".etkinlik_kayit_id;
          public          postgres    false    234            �            1259    24708    GERIBILDIRIMLER    TABLE       CREATE TABLE public."GERIBILDIRIMLER" (
    geribildirim_id integer NOT NULL,
    uye_id integer NOT NULL,
    geribildirim_turu character varying(50) NOT NULL,
    ilgili_id integer,
    yorum text,
    geribildirim_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);
 %   DROP TABLE public."GERIBILDIRIMLER";
       public         heap    postgres    false            �            1259    24707 #   GERIBILDIRIMLER_geribildirim_id_seq    SEQUENCE     �   CREATE SEQUENCE public."GERIBILDIRIMLER_geribildirim_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public."GERIBILDIRIMLER_geribildirim_id_seq";
       public          postgres    false    237            �           0    0 #   GERIBILDIRIMLER_geribildirim_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public."GERIBILDIRIMLER_geribildirim_id_seq" OWNED BY public."GERIBILDIRIMLER".geribildirim_id;
          public          postgres    false    236            �            1259    24646    ODEMELER    TABLE     �   CREATE TABLE public."ODEMELER" (
    odeme_id integer NOT NULL,
    uye_id integer NOT NULL,
    tutar numeric(10,2) NOT NULL,
    odeme_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    odeme_yontemi character varying(50)
);
    DROP TABLE public."ODEMELER";
       public         heap    postgres    false            �            1259    24645    ODEMELER_odeme_id_seq    SEQUENCE     �   CREATE SEQUENCE public."ODEMELER_odeme_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public."ODEMELER_odeme_id_seq";
       public          postgres    false    227            �           0    0    ODEMELER_odeme_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public."ODEMELER_odeme_id_seq" OWNED BY public."ODEMELER".odeme_id;
          public          postgres    false    226            �            1259    24730    SATIN_ALIMLAR    TABLE     �   CREATE TABLE public."SATIN_ALIMLAR" (
    satin_alim_id integer NOT NULL,
    uye_id integer NOT NULL,
    urun_id integer NOT NULL,
    satin_alim_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    miktar integer NOT NULL
);
 #   DROP TABLE public."SATIN_ALIMLAR";
       public         heap    postgres    false            �            1259    24729    SATIN_ALIMLAR_satin_alim_id_seq    SEQUENCE     �   CREATE SEQUENCE public."SATIN_ALIMLAR_satin_alim_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE public."SATIN_ALIMLAR_satin_alim_id_seq";
       public          postgres    false    241            �           0    0    SATIN_ALIMLAR_satin_alim_id_seq    SEQUENCE OWNED BY     g   ALTER SEQUENCE public."SATIN_ALIMLAR_satin_alim_id_seq" OWNED BY public."SATIN_ALIMLAR".satin_alim_id;
          public          postgres    false    240            �            1259    24723    URUNLER    TABLE     �   CREATE TABLE public."URUNLER" (
    urun_id integer NOT NULL,
    urun_adi character varying(100) NOT NULL,
    aciklama character varying(255),
    fiyat numeric(10,2) NOT NULL,
    stok_miktari integer NOT NULL
);
    DROP TABLE public."URUNLER";
       public         heap    postgres    false            �            1259    24722    URUNLER_urun_id_seq    SEQUENCE     �   CREATE SEQUENCE public."URUNLER_urun_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public."URUNLER_urun_id_seq";
       public          postgres    false    239            �           0    0    URUNLER_urun_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE public."URUNLER_urun_id_seq" OWNED BY public."URUNLER".urun_id;
          public          postgres    false    238            �            1259    24585    UYELER    TABLE       CREATE TABLE public."UYELER" (
    uye_id integer NOT NULL,
    ad character varying(40) NOT NULL,
    soyad character varying(40) NOT NULL,
    dogum_tarihi date,
    cinsiyet character varying(10),
    iletisim_bilgisi character varying(255),
    plan_id integer
);
    DROP TABLE public."UYELER";
       public         heap    postgres    false            �            1259    24584    UYELER_uye_id_seq    SEQUENCE     �   CREATE SEQUENCE public."UYELER_uye_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public."UYELER_uye_id_seq";
       public          postgres    false    217            �           0    0    UYELER_uye_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public."UYELER_uye_id_seq" OWNED BY public."UYELER".uye_id;
          public          postgres    false    216            �            1259    24578    UYELIK_PLANLARI    TABLE     �   CREATE TABLE public."UYELIK_PLANLARI" (
    plan_id integer NOT NULL,
    plan_adi character varying(100) NOT NULL,
    ucret numeric(10,2) NOT NULL,
    sure integer NOT NULL,
    aciklama character varying(255)
);
 %   DROP TABLE public."UYELIK_PLANLARI";
       public         heap    postgres    false            �            1259    24577    UYELIK_PLANLARI_plan_id_seq    SEQUENCE     �   CREATE SEQUENCE public."UYELIK_PLANLARI_plan_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public."UYELIK_PLANLARI_plan_id_seq";
       public          postgres    false    215            �           0    0    UYELIK_PLANLARI_plan_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public."UYELIK_PLANLARI_plan_id_seq" OWNED BY public."UYELIK_PLANLARI".plan_id;
          public          postgres    false    214            �           2604    24600    CALISANLAR calisan_id    DEFAULT     �   ALTER TABLE ONLY public."CALISANLAR" ALTER COLUMN calisan_id SET DEFAULT nextval('public."CALISANLAR_calisan_id_seq"'::regclass);
 F   ALTER TABLE public."CALISANLAR" ALTER COLUMN calisan_id DROP DEFAULT;
       public          postgres    false    218    219    219            �           2604    24607    DERSLER ders_id    DEFAULT     v   ALTER TABLE ONLY public."DERSLER" ALTER COLUMN ders_id SET DEFAULT nextval('public."DERSLER_ders_id_seq"'::regclass);
 @   ALTER TABLE public."DERSLER" ALTER COLUMN ders_id DROP DEFAULT;
       public          postgres    false    220    221    221            �           2604    24631 #   DERS_REZERVASYONLARI rezervasyon_id    DEFAULT     �   ALTER TABLE ONLY public."DERS_REZERVASYONLARI" ALTER COLUMN rezervasyon_id SET DEFAULT nextval('public."DERS_REZERVASYONLARI_rezervasyon_id_seq"'::regclass);
 T   ALTER TABLE public."DERS_REZERVASYONLARI" ALTER COLUMN rezervasyon_id DROP DEFAULT;
       public          postgres    false    225    224    225            �           2604    24619    DERS_TAKVIMLERI takvim_id    DEFAULT     �   ALTER TABLE ONLY public."DERS_TAKVIMLERI" ALTER COLUMN takvim_id SET DEFAULT nextval('public."DERS_TAKVIMLERI_takvim_id_seq"'::regclass);
 J   ALTER TABLE public."DERS_TAKVIMLERI" ALTER COLUMN takvim_id DROP DEFAULT;
       public          postgres    false    222    223    223            �           2604    24662    EKIPMANLAR ekipman_id    DEFAULT     �   ALTER TABLE ONLY public."EKIPMANLAR" ALTER COLUMN ekipman_id SET DEFAULT nextval('public."EKIPMANLAR_ekipman_id_seq"'::regclass);
 F   ALTER TABLE public."EKIPMANLAR" ALTER COLUMN ekipman_id DROP DEFAULT;
       public          postgres    false    228    229    229            �           2604    24674    EKIPMAN_BAKIMLARI bakim_id    DEFAULT     �   ALTER TABLE ONLY public."EKIPMAN_BAKIMLARI" ALTER COLUMN bakim_id SET DEFAULT nextval('public."EKIPMAN_BAKIMLARI_bakim_id_seq"'::regclass);
 K   ALTER TABLE public."EKIPMAN_BAKIMLARI" ALTER COLUMN bakim_id DROP DEFAULT;
       public          postgres    false    231    230    231            �           2604    24686    ETKINLIKLER etkinlik_id    DEFAULT     �   ALTER TABLE ONLY public."ETKINLIKLER" ALTER COLUMN etkinlik_id SET DEFAULT nextval('public."ETKINLIKLER_etkinlik_id_seq"'::regclass);
 H   ALTER TABLE public."ETKINLIKLER" ALTER COLUMN etkinlik_id DROP DEFAULT;
       public          postgres    false    232    233    233            �           2604    24693 $   ETKINLIK_KAYITLARI etkinlik_kayit_id    DEFAULT     �   ALTER TABLE ONLY public."ETKINLIK_KAYITLARI" ALTER COLUMN etkinlik_kayit_id SET DEFAULT nextval('public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq"'::regclass);
 U   ALTER TABLE public."ETKINLIK_KAYITLARI" ALTER COLUMN etkinlik_kayit_id DROP DEFAULT;
       public          postgres    false    235    234    235            �           2604    24711    GERIBILDIRIMLER geribildirim_id    DEFAULT     �   ALTER TABLE ONLY public."GERIBILDIRIMLER" ALTER COLUMN geribildirim_id SET DEFAULT nextval('public."GERIBILDIRIMLER_geribildirim_id_seq"'::regclass);
 P   ALTER TABLE public."GERIBILDIRIMLER" ALTER COLUMN geribildirim_id DROP DEFAULT;
       public          postgres    false    236    237    237            �           2604    24649    ODEMELER odeme_id    DEFAULT     z   ALTER TABLE ONLY public."ODEMELER" ALTER COLUMN odeme_id SET DEFAULT nextval('public."ODEMELER_odeme_id_seq"'::regclass);
 B   ALTER TABLE public."ODEMELER" ALTER COLUMN odeme_id DROP DEFAULT;
       public          postgres    false    227    226    227            �           2604    24733    SATIN_ALIMLAR satin_alim_id    DEFAULT     �   ALTER TABLE ONLY public."SATIN_ALIMLAR" ALTER COLUMN satin_alim_id SET DEFAULT nextval('public."SATIN_ALIMLAR_satin_alim_id_seq"'::regclass);
 L   ALTER TABLE public."SATIN_ALIMLAR" ALTER COLUMN satin_alim_id DROP DEFAULT;
       public          postgres    false    240    241    241            �           2604    24726    URUNLER urun_id    DEFAULT     v   ALTER TABLE ONLY public."URUNLER" ALTER COLUMN urun_id SET DEFAULT nextval('public."URUNLER_urun_id_seq"'::regclass);
 @   ALTER TABLE public."URUNLER" ALTER COLUMN urun_id DROP DEFAULT;
       public          postgres    false    238    239    239            �           2604    24588    UYELER uye_id    DEFAULT     r   ALTER TABLE ONLY public."UYELER" ALTER COLUMN uye_id SET DEFAULT nextval('public."UYELER_uye_id_seq"'::regclass);
 >   ALTER TABLE public."UYELER" ALTER COLUMN uye_id DROP DEFAULT;
       public          postgres    false    217    216    217            �           2604    24581    UYELIK_PLANLARI plan_id    DEFAULT     �   ALTER TABLE ONLY public."UYELIK_PLANLARI" ALTER COLUMN plan_id SET DEFAULT nextval('public."UYELIK_PLANLARI_plan_id_seq"'::regclass);
 H   ALTER TABLE public."UYELIK_PLANLARI" ALTER COLUMN plan_id DROP DEFAULT;
       public          postgres    false    214    215    215            �          0    24597 
   CALISANLAR 
   TABLE DATA           V   COPY public."CALISANLAR" (calisan_id, ad, soyad, gorev, ise_giris_tarihi) FROM stdin;
    public          postgres    false    219   ��       �          0    24604    DERSLER 
   TABLE DATA           Q   COPY public."DERSLER" (ders_id, ders_adi, ders_aciklama, calisan_id) FROM stdin;
    public          postgres    false    221   ��       �          0    24628    DERS_REZERVASYONLARI 
   TABLE DATA           n   COPY public."DERS_REZERVASYONLARI" (rezervasyon_id, takvim_id, uye_id, rezervasyon_tarihi, durum) FROM stdin;
    public          postgres    false    225   &�       �          0    24616    DERS_TAKVIMLERI 
   TABLE DATA           l   COPY public."DERS_TAKVIMLERI" (takvim_id, ders_id, baslama_zamani, bitis_zamani, max_katilimci) FROM stdin;
    public          postgres    false    223   |�       �          0    24659 
   EKIPMANLAR 
   TABLE DATA           l   COPY public."EKIPMANLAR" (ekipman_id, ekipman_adi, ekipman_turu, satin_alim_tarihi, calisan_id) FROM stdin;
    public          postgres    false    229   �       �          0    24671    EKIPMAN_BAKIMLARI 
   TABLE DATA           a   COPY public."EKIPMAN_BAKIMLARI" (bakim_id, ekipman_id, bakim_tarihi, bakim_aciklama) FROM stdin;
    public          postgres    false    231   ^�       �          0    24683    ETKINLIKLER 
   TABLE DATA           i   COPY public."ETKINLIKLER" (etkinlik_id, etkinlik_adi, etkinlik_tarihi, konum, max_katilimci) FROM stdin;
    public          postgres    false    233   ��       �          0    24690    ETKINLIK_KAYITLARI 
   TABLE DATA           d   COPY public."ETKINLIK_KAYITLARI" (etkinlik_kayit_id, etkinlik_id, uye_id, kayit_tarihi) FROM stdin;
    public          postgres    false    235   E�       �          0    24708    GERIBILDIRIMLER 
   TABLE DATA           ~   COPY public."GERIBILDIRIMLER" (geribildirim_id, uye_id, geribildirim_turu, ilgili_id, yorum, geribildirim_tarihi) FROM stdin;
    public          postgres    false    237   ��       �          0    24646    ODEMELER 
   TABLE DATA           Z   COPY public."ODEMELER" (odeme_id, uye_id, tutar, odeme_tarihi, odeme_yontemi) FROM stdin;
    public          postgres    false    227   a�       �          0    24730    SATIN_ALIMLAR 
   TABLE DATA           d   COPY public."SATIN_ALIMLAR" (satin_alim_id, uye_id, urun_id, satin_alim_tarihi, miktar) FROM stdin;
    public          postgres    false    241   ɵ       �          0    24723    URUNLER 
   TABLE DATA           U   COPY public."URUNLER" (urun_id, urun_adi, aciklama, fiyat, stok_miktari) FROM stdin;
    public          postgres    false    239   �       �          0    24585    UYELER 
   TABLE DATA           h   COPY public."UYELER" (uye_id, ad, soyad, dogum_tarihi, cinsiyet, iletisim_bilgisi, plan_id) FROM stdin;
    public          postgres    false    217   ��       ~          0    24578    UYELIK_PLANLARI 
   TABLE DATA           U   COPY public."UYELIK_PLANLARI" (plan_id, plan_adi, ucret, sure, aciklama) FROM stdin;
    public          postgres    false    215   (�       �           0    0    CALISANLAR_calisan_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public."CALISANLAR_calisan_id_seq"', 6, true);
          public          postgres    false    218            �           0    0    DERSLER_ders_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public."DERSLER_ders_id_seq"', 3, true);
          public          postgres    false    220            �           0    0 '   DERS_REZERVASYONLARI_rezervasyon_id_seq    SEQUENCE SET     X   SELECT pg_catalog.setval('public."DERS_REZERVASYONLARI_rezervasyon_id_seq"', 26, true);
          public          postgres    false    224            �           0    0    DERS_TAKVIMLERI_takvim_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public."DERS_TAKVIMLERI_takvim_id_seq"', 8, true);
          public          postgres    false    222            �           0    0    EKIPMANLAR_ekipman_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public."EKIPMANLAR_ekipman_id_seq"', 3, true);
          public          postgres    false    228            �           0    0    EKIPMAN_BAKIMLARI_bakim_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public."EKIPMAN_BAKIMLARI_bakim_id_seq"', 2, true);
          public          postgres    false    230            �           0    0    ETKINLIKLER_etkinlik_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public."ETKINLIKLER_etkinlik_id_seq"', 2, true);
          public          postgres    false    232            �           0    0 (   ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq    SEQUENCE SET     X   SELECT pg_catalog.setval('public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq"', 3, true);
          public          postgres    false    234            �           0    0 #   GERIBILDIRIMLER_geribildirim_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public."GERIBILDIRIMLER_geribildirim_id_seq"', 4, true);
          public          postgres    false    236            �           0    0    ODEMELER_odeme_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public."ODEMELER_odeme_id_seq"', 46, true);
          public          postgres    false    226            �           0    0    SATIN_ALIMLAR_satin_alim_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public."SATIN_ALIMLAR_satin_alim_id_seq"', 3, true);
          public          postgres    false    240            �           0    0    URUNLER_urun_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public."URUNLER_urun_id_seq"', 4, true);
          public          postgres    false    238            �           0    0    UYELER_uye_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public."UYELER_uye_id_seq"', 7, true);
          public          postgres    false    216            �           0    0    UYELIK_PLANLARI_plan_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public."UYELIK_PLANLARI_plan_id_seq"', 3, true);
          public          postgres    false    214            �           2606    24602    CALISANLAR CalisanlarPK 
   CONSTRAINT     a   ALTER TABLE ONLY public."CALISANLAR"
    ADD CONSTRAINT "CalisanlarPK" PRIMARY KEY (calisan_id);
 E   ALTER TABLE ONLY public."CALISANLAR" DROP CONSTRAINT "CalisanlarPK";
       public            postgres    false    219            �           2606    24634 *   DERS_REZERVASYONLARI DersRezervasyonlariPK 
   CONSTRAINT     x   ALTER TABLE ONLY public."DERS_REZERVASYONLARI"
    ADD CONSTRAINT "DersRezervasyonlariPK" PRIMARY KEY (rezervasyon_id);
 X   ALTER TABLE ONLY public."DERS_REZERVASYONLARI" DROP CONSTRAINT "DersRezervasyonlariPK";
       public            postgres    false    225            �           2606    24621     DERS_TAKVIMLERI DersTakvimleriPK 
   CONSTRAINT     i   ALTER TABLE ONLY public."DERS_TAKVIMLERI"
    ADD CONSTRAINT "DersTakvimleriPK" PRIMARY KEY (takvim_id);
 N   ALTER TABLE ONLY public."DERS_TAKVIMLERI" DROP CONSTRAINT "DersTakvimleriPK";
       public            postgres    false    223            �           2606    24609    DERSLER DerslerPK 
   CONSTRAINT     X   ALTER TABLE ONLY public."DERSLER"
    ADD CONSTRAINT "DerslerPK" PRIMARY KEY (ders_id);
 ?   ALTER TABLE ONLY public."DERSLER" DROP CONSTRAINT "DerslerPK";
       public            postgres    false    221            �           2606    24676 $   EKIPMAN_BAKIMLARI EkipmanBakimlariPK 
   CONSTRAINT     l   ALTER TABLE ONLY public."EKIPMAN_BAKIMLARI"
    ADD CONSTRAINT "EkipmanBakimlariPK" PRIMARY KEY (bakim_id);
 R   ALTER TABLE ONLY public."EKIPMAN_BAKIMLARI" DROP CONSTRAINT "EkipmanBakimlariPK";
       public            postgres    false    231            �           2606    24664    EKIPMANLAR EkipmanlarPK 
   CONSTRAINT     a   ALTER TABLE ONLY public."EKIPMANLAR"
    ADD CONSTRAINT "EkipmanlarPK" PRIMARY KEY (ekipman_id);
 E   ALTER TABLE ONLY public."EKIPMANLAR" DROP CONSTRAINT "EkipmanlarPK";
       public            postgres    false    229            �           2606    24696 &   ETKINLIK_KAYITLARI EtkinlikKayitlariPK 
   CONSTRAINT     w   ALTER TABLE ONLY public."ETKINLIK_KAYITLARI"
    ADD CONSTRAINT "EtkinlikKayitlariPK" PRIMARY KEY (etkinlik_kayit_id);
 T   ALTER TABLE ONLY public."ETKINLIK_KAYITLARI" DROP CONSTRAINT "EtkinlikKayitlariPK";
       public            postgres    false    235            �           2606    24688    ETKINLIKLER EtkinliklerPK 
   CONSTRAINT     d   ALTER TABLE ONLY public."ETKINLIKLER"
    ADD CONSTRAINT "EtkinliklerPK" PRIMARY KEY (etkinlik_id);
 G   ALTER TABLE ONLY public."ETKINLIKLER" DROP CONSTRAINT "EtkinliklerPK";
       public            postgres    false    233            �           2606    24716 !   GERIBILDIRIMLER GeribildirimlerPK 
   CONSTRAINT     p   ALTER TABLE ONLY public."GERIBILDIRIMLER"
    ADD CONSTRAINT "GeribildirimlerPK" PRIMARY KEY (geribildirim_id);
 O   ALTER TABLE ONLY public."GERIBILDIRIMLER" DROP CONSTRAINT "GeribildirimlerPK";
       public            postgres    false    237            �           2606    24652    ODEMELER OdemelerPK 
   CONSTRAINT     [   ALTER TABLE ONLY public."ODEMELER"
    ADD CONSTRAINT "OdemelerPK" PRIMARY KEY (odeme_id);
 A   ALTER TABLE ONLY public."ODEMELER" DROP CONSTRAINT "OdemelerPK";
       public            postgres    false    227            �           2606    24736    SATIN_ALIMLAR SatinAlimlarPK 
   CONSTRAINT     i   ALTER TABLE ONLY public."SATIN_ALIMLAR"
    ADD CONSTRAINT "SatinAlimlarPK" PRIMARY KEY (satin_alim_id);
 J   ALTER TABLE ONLY public."SATIN_ALIMLAR" DROP CONSTRAINT "SatinAlimlarPK";
       public            postgres    false    241            �           2606    24728    URUNLER UrunlerPK 
   CONSTRAINT     X   ALTER TABLE ONLY public."URUNLER"
    ADD CONSTRAINT "UrunlerPK" PRIMARY KEY (urun_id);
 ?   ALTER TABLE ONLY public."URUNLER" DROP CONSTRAINT "UrunlerPK";
       public            postgres    false    239            �           2606    24590    UYELER UyelerPK 
   CONSTRAINT     U   ALTER TABLE ONLY public."UYELER"
    ADD CONSTRAINT "UyelerPK" PRIMARY KEY (uye_id);
 =   ALTER TABLE ONLY public."UYELER" DROP CONSTRAINT "UyelerPK";
       public            postgres    false    217            �           2606    24583     UYELIK_PLANLARI UyelikPlanlariPK 
   CONSTRAINT     g   ALTER TABLE ONLY public."UYELIK_PLANLARI"
    ADD CONSTRAINT "UyelikPlanlariPK" PRIMARY KEY (plan_id);
 N   ALTER TABLE ONLY public."UYELIK_PLANLARI" DROP CONSTRAINT "UyelikPlanlariPK";
       public            postgres    false    215            �           2620    24755 *   DERS_TAKVIMLERI ders_takvimleri_update_trg    TRIGGER     �   CREATE TRIGGER ders_takvimleri_update_trg BEFORE UPDATE ON public."DERS_TAKVIMLERI" FOR EACH ROW EXECUTE FUNCTION public.ders_takvimleri_before_update();
 E   DROP TRIGGER ders_takvimleri_update_trg ON public."DERS_TAKVIMLERI";
       public          postgres    false    223    246            �           2620    24757    ODEMELER odemeler_insert_trg    TRIGGER     �   CREATE TRIGGER odemeler_insert_trg BEFORE INSERT ON public."ODEMELER" FOR EACH ROW EXECUTE FUNCTION public.odemeler_before_insert();
 7   DROP TRIGGER odemeler_insert_trg ON public."ODEMELER";
       public          postgres    false    227    247            �           2620    24759    URUNLER urunler_update_trg    TRIGGER     �   CREATE TRIGGER urunler_update_trg BEFORE UPDATE ON public."URUNLER" FOR EACH ROW EXECUTE FUNCTION public.urunler_before_update();
 5   DROP TRIGGER urunler_update_trg ON public."URUNLER";
       public          postgres    false    248    239            �           2620    32952    UYELER uyeler_insert_trg    TRIGGER     �   CREATE TRIGGER uyeler_insert_trg BEFORE INSERT OR UPDATE ON public."UYELER" FOR EACH ROW EXECUTE FUNCTION public.uyeler_before_insert();
 3   DROP TRIGGER uyeler_insert_trg ON public."UYELER";
       public          postgres    false    245    217            �           2606    24635 0   DERS_REZERVASYONLARI DersRezervasyonlariTakvimFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."DERS_REZERVASYONLARI"
    ADD CONSTRAINT "DersRezervasyonlariTakvimFK" FOREIGN KEY (takvim_id) REFERENCES public."DERS_TAKVIMLERI"(takvim_id);
 ^   ALTER TABLE ONLY public."DERS_REZERVASYONLARI" DROP CONSTRAINT "DersRezervasyonlariTakvimFK";
       public          postgres    false    225    223    3275            �           2606    24640 -   DERS_REZERVASYONLARI DersRezervasyonlariUyeFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."DERS_REZERVASYONLARI"
    ADD CONSTRAINT "DersRezervasyonlariUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id);
 [   ALTER TABLE ONLY public."DERS_REZERVASYONLARI" DROP CONSTRAINT "DersRezervasyonlariUyeFK";
       public          postgres    false    3269    225    217            �           2606    24622 $   DERS_TAKVIMLERI DersTakvimleriDersFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."DERS_TAKVIMLERI"
    ADD CONSTRAINT "DersTakvimleriDersFK" FOREIGN KEY (ders_id) REFERENCES public."DERSLER"(ders_id);
 R   ALTER TABLE ONLY public."DERS_TAKVIMLERI" DROP CONSTRAINT "DersTakvimleriDersFK";
       public          postgres    false    223    3273    221            �           2606    24610    DERSLER DerslerCalisanFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."DERSLER"
    ADD CONSTRAINT "DerslerCalisanFK" FOREIGN KEY (calisan_id) REFERENCES public."CALISANLAR"(calisan_id);
 F   ALTER TABLE ONLY public."DERSLER" DROP CONSTRAINT "DerslerCalisanFK";
       public          postgres    false    221    3271    219            �           2606    24677 +   EKIPMAN_BAKIMLARI EkipmanBakimlariEkipmanFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."EKIPMAN_BAKIMLARI"
    ADD CONSTRAINT "EkipmanBakimlariEkipmanFK" FOREIGN KEY (ekipman_id) REFERENCES public."EKIPMANLAR"(ekipman_id);
 Y   ALTER TABLE ONLY public."EKIPMAN_BAKIMLARI" DROP CONSTRAINT "EkipmanBakimlariEkipmanFK";
       public          postgres    false    3281    229    231            �           2606    24665    EKIPMANLAR EkipmanlarCalisanFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."EKIPMANLAR"
    ADD CONSTRAINT "EkipmanlarCalisanFK" FOREIGN KEY (calisan_id) REFERENCES public."CALISANLAR"(calisan_id);
 L   ALTER TABLE ONLY public."EKIPMANLAR" DROP CONSTRAINT "EkipmanlarCalisanFK";
       public          postgres    false    3271    229    219            �           2606    24697 .   ETKINLIK_KAYITLARI EtkinlikKayitlariEtkinlikFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."ETKINLIK_KAYITLARI"
    ADD CONSTRAINT "EtkinlikKayitlariEtkinlikFK" FOREIGN KEY (etkinlik_id) REFERENCES public."ETKINLIKLER"(etkinlik_id);
 \   ALTER TABLE ONLY public."ETKINLIK_KAYITLARI" DROP CONSTRAINT "EtkinlikKayitlariEtkinlikFK";
       public          postgres    false    3285    233    235            �           2606    24702 )   ETKINLIK_KAYITLARI EtkinlikKayitlariUyeFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."ETKINLIK_KAYITLARI"
    ADD CONSTRAINT "EtkinlikKayitlariUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id);
 W   ALTER TABLE ONLY public."ETKINLIK_KAYITLARI" DROP CONSTRAINT "EtkinlikKayitlariUyeFK";
       public          postgres    false    217    235    3269            �           2606    24717 $   GERIBILDIRIMLER GeribildirimlerUyeFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."GERIBILDIRIMLER"
    ADD CONSTRAINT "GeribildirimlerUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id);
 R   ALTER TABLE ONLY public."GERIBILDIRIMLER" DROP CONSTRAINT "GeribildirimlerUyeFK";
       public          postgres    false    237    217    3269            �           2606    24760    ODEMELER OdemelerUyeFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."ODEMELER"
    ADD CONSTRAINT "OdemelerUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id) ON DELETE CASCADE;
 D   ALTER TABLE ONLY public."ODEMELER" DROP CONSTRAINT "OdemelerUyeFK";
       public          postgres    false    3269    217    227            �           2606    24765     SATIN_ALIMLAR SatinAlimlarUrunFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."SATIN_ALIMLAR"
    ADD CONSTRAINT "SatinAlimlarUrunFK" FOREIGN KEY (urun_id) REFERENCES public."URUNLER"(urun_id) ON DELETE CASCADE;
 N   ALTER TABLE ONLY public."SATIN_ALIMLAR" DROP CONSTRAINT "SatinAlimlarUrunFK";
       public          postgres    false    3291    241    239            �           2606    24737    SATIN_ALIMLAR SatinAlimlarUyeFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."SATIN_ALIMLAR"
    ADD CONSTRAINT "SatinAlimlarUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id);
 M   ALTER TABLE ONLY public."SATIN_ALIMLAR" DROP CONSTRAINT "SatinAlimlarUyeFK";
       public          postgres    false    3269    217    241            �           2606    24591    UYELER UyelerPlanFK    FK CONSTRAINT     �   ALTER TABLE ONLY public."UYELER"
    ADD CONSTRAINT "UyelerPlanFK" FOREIGN KEY (plan_id) REFERENCES public."UYELIK_PLANLARI"(plan_id);
 A   ALTER TABLE ONLY public."UYELER" DROP CONSTRAINT "UyelerPlanFK";
       public          postgres    false    215    217    3267            �   �   x�]�A
�@�ur�H2�B�G(��V���"��*����x�Ѓ9݈�����mk[�������ab����-Z)nt��?��Ì�HIRL`ocI�U1u�}�%#�H���]����!6dS�s�4��ҵO���k3����>�4Dtj��$��"~ �8�      �   h   x�3���I,I-�t-�K�MU(KUHI�K�Eř��\F���鉜A�ŉ9 �̪�����:N.c���̼�̼tN��������<�Ģ�#�r����qqq �$�      �   F   x�32�4B##]C#]C+#+C=CC33����ʜL.#�2b���ЌӘ(�c���� a#      �   \   x����	�0��] Er�6�,��RH!&���t��J�%b#.�qGG��8p:<��Kh�:����}��Zc�GL��������fA�      �   f   x�3���?:�T�)1/��FN�Ģ���|N##]C]SNc.#N�#�l,�9�1[!8�$�Ui�kh Ti�������X4˵8/57��X�dT� �$�      �   Q   x�3�4�4202�50�52�H-ʬ�O��VHJ�>�1�ˈ�*D���G��X�sdc�BJj^z�Bv~^IQ~��=\1z\\\ �\	      �   v   x�3�L��T�<�1G!2?=Q��$;3/'���LN##]C#]cCK+ �t�KTN����rqz'�dV�+�&%��畂�����*�C���xt��cNb��W� j�!�      �   7   x�3�4B##]C#]C+#+s=scKS3.#�4>�@ic|
b���� � e      �   �   x�}�1�0E��� �ڴ��	vV$��X�4�� ��td���H�������]�Bh�m{X�qK�
z�����X�!sY��L�z-��ʖ2/Wu"��8Ev�>���0���0��a��T�(��t�0zFC-w��z�Vv�w�~VY�J|Fװ�i�L�6����*��<8��Y�1K��1`�      �   X  x���͊�0��u{ހ����ZD�E)� �&3���|
]Iymb�M<1Q ��Ď,G*.M�Q��Z�����q������q�,���ؖ9M��������DC��\��v���e=�/��u.^B�kC��당i�r*uP�B�^!T����!�L���-T��B��񯊁Y��A�����H	���0%�BW	*t���TlO*tUD��J��1���UeT誂
]UA����k�_J��W
}%��ߟI��W��P��".,�OϫI�o�d\�k
h���O.i|�Թ���jg����f1X���xU;���3M>P��$��s jϰ�y��]�<?�-�
�<� ���      �   6   x�3�4B##]C#]C+#S+#C=3SSCSN#.#N0ĭĐ+F��� ��      �   �   x�3�(�/I��Sɯ*�t�+)J��M�S(��+J,>�Q!�4''1���\N#=NS.#����"���y% E���
驇�g�VqB�p��$���<:?�8�N��I)-*�)-��*����� �-�      �   x   x�=�1�0�������rm3<h�Yԥ�"�P
�������/��ͮX�S�7P))&�`��ڐT���E@�Q���hm:�FJ��s}�͙X�v=8���uv:�S"��V�i����B� (�      ~   �   x�=�A
�@E��)r�2m��t!��&0)�ɔ2�
z�Ѝ��˪����_�1s�9e(�+��ڭ�����)Ђ��
I������S�wc��
I�>.�$}?4*�Ш������n��'��g	4H+�^O/QL�\ �N�2�     