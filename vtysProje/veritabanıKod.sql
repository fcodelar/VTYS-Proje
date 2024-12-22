--
-- PostgreSQL database dump
--

-- Dumped from database version 15.10
-- Dumped by pg_dump version 15.10

-- Started on 2024-12-22 22:34:25

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 261 (class 1255 OID 24748)
-- Name: CalisanDersSayisi(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."CalisanDersSayisi"(p_calisan_id integer) RETURNS integer
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


ALTER FUNCTION public."CalisanDersSayisi"(p_calisan_id integer) OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 24749)
-- Name: DersToplamRezervasyonSayisi(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."DersToplamRezervasyonSayisi"(p_ders_id integer) RETURNS integer
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


ALTER FUNCTION public."DersToplamRezervasyonSayisi"(p_ders_id integer) OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 24750)
-- Name: EtkinlikListesiMetin(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."EtkinlikListesiMetin"() RETURNS text
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


ALTER FUNCTION public."EtkinlikListesiMetin"() OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 24747)
-- Name: UyePlanAdiDondur(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public."UyePlanAdiDondur"(p_uye_id integer) RETURNS character varying
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


ALTER FUNCTION public."UyePlanAdiDondur"(p_uye_id integer) OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 24751)
-- Name: aylik_uye_odeme_hesapla(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.aylik_uye_odeme_hesapla()
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


ALTER PROCEDURE public.aylik_uye_odeme_hesapla() OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 24754)
-- Name: ders_takvimleri_before_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ders_takvimleri_before_update() RETURNS trigger
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


ALTER FUNCTION public.ders_takvimleri_before_update() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 24756)
-- Name: odemeler_before_insert(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.odemeler_before_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW."odeme_tarihi" IS NULL THEN
        NEW."odeme_tarihi" := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.odemeler_before_insert() OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 24758)
-- Name: urunler_before_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.urunler_before_update() RETURNS trigger
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


ALTER FUNCTION public.urunler_before_update() OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 24752)
-- Name: uyeler_before_insert(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.uyeler_before_insert() RETURNS trigger
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


ALTER FUNCTION public.uyeler_before_insert() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 219 (class 1259 OID 24597)
-- Name: CALISANLAR; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."CALISANLAR" (
    calisan_id integer NOT NULL,
    ad character varying(40) NOT NULL,
    soyad character varying(40) NOT NULL,
    gorev character varying(50) NOT NULL,
    ise_giris_tarihi date
);


ALTER TABLE public."CALISANLAR" OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 24596)
-- Name: CALISANLAR_calisan_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."CALISANLAR_calisan_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."CALISANLAR_calisan_id_seq" OWNER TO postgres;

--
-- TOC entry 3486 (class 0 OID 0)
-- Dependencies: 218
-- Name: CALISANLAR_calisan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."CALISANLAR_calisan_id_seq" OWNED BY public."CALISANLAR".calisan_id;


--
-- TOC entry 221 (class 1259 OID 24604)
-- Name: DERSLER; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."DERSLER" (
    ders_id integer NOT NULL,
    ders_adi character varying(100) NOT NULL,
    ders_aciklama character varying(255),
    calisan_id integer NOT NULL
);


ALTER TABLE public."DERSLER" OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 24603)
-- Name: DERSLER_ders_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."DERSLER_ders_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."DERSLER_ders_id_seq" OWNER TO postgres;

--
-- TOC entry 3487 (class 0 OID 0)
-- Dependencies: 220
-- Name: DERSLER_ders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."DERSLER_ders_id_seq" OWNED BY public."DERSLER".ders_id;


--
-- TOC entry 225 (class 1259 OID 24628)
-- Name: DERS_REZERVASYONLARI; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."DERS_REZERVASYONLARI" (
    rezervasyon_id integer NOT NULL,
    takvim_id integer NOT NULL,
    uye_id integer NOT NULL,
    rezervasyon_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    durum character varying(50)
);


ALTER TABLE public."DERS_REZERVASYONLARI" OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 24627)
-- Name: DERS_REZERVASYONLARI_rezervasyon_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."DERS_REZERVASYONLARI_rezervasyon_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."DERS_REZERVASYONLARI_rezervasyon_id_seq" OWNER TO postgres;

--
-- TOC entry 3488 (class 0 OID 0)
-- Dependencies: 224
-- Name: DERS_REZERVASYONLARI_rezervasyon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."DERS_REZERVASYONLARI_rezervasyon_id_seq" OWNED BY public."DERS_REZERVASYONLARI".rezervasyon_id;


--
-- TOC entry 223 (class 1259 OID 24616)
-- Name: DERS_TAKVIMLERI; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."DERS_TAKVIMLERI" (
    takvim_id integer NOT NULL,
    ders_id integer NOT NULL,
    baslama_zamani timestamp without time zone NOT NULL,
    bitis_zamani timestamp without time zone NOT NULL,
    max_katilimci integer NOT NULL
);


ALTER TABLE public."DERS_TAKVIMLERI" OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 24615)
-- Name: DERS_TAKVIMLERI_takvim_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."DERS_TAKVIMLERI_takvim_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."DERS_TAKVIMLERI_takvim_id_seq" OWNER TO postgres;

--
-- TOC entry 3489 (class 0 OID 0)
-- Dependencies: 222
-- Name: DERS_TAKVIMLERI_takvim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."DERS_TAKVIMLERI_takvim_id_seq" OWNED BY public."DERS_TAKVIMLERI".takvim_id;


--
-- TOC entry 229 (class 1259 OID 24659)
-- Name: EKIPMANLAR; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."EKIPMANLAR" (
    ekipman_id integer NOT NULL,
    ekipman_adi character varying(100) NOT NULL,
    ekipman_turu character varying(50) NOT NULL,
    satin_alim_tarihi date,
    calisan_id integer NOT NULL
);


ALTER TABLE public."EKIPMANLAR" OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 24658)
-- Name: EKIPMANLAR_ekipman_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."EKIPMANLAR_ekipman_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."EKIPMANLAR_ekipman_id_seq" OWNER TO postgres;

--
-- TOC entry 3490 (class 0 OID 0)
-- Dependencies: 228
-- Name: EKIPMANLAR_ekipman_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."EKIPMANLAR_ekipman_id_seq" OWNED BY public."EKIPMANLAR".ekipman_id;


--
-- TOC entry 231 (class 1259 OID 24671)
-- Name: EKIPMAN_BAKIMLARI; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."EKIPMAN_BAKIMLARI" (
    bakim_id integer NOT NULL,
    ekipman_id integer NOT NULL,
    bakim_tarihi date NOT NULL,
    bakim_aciklama character varying(255)
);


ALTER TABLE public."EKIPMAN_BAKIMLARI" OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 24670)
-- Name: EKIPMAN_BAKIMLARI_bakim_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."EKIPMAN_BAKIMLARI_bakim_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."EKIPMAN_BAKIMLARI_bakim_id_seq" OWNER TO postgres;

--
-- TOC entry 3491 (class 0 OID 0)
-- Dependencies: 230
-- Name: EKIPMAN_BAKIMLARI_bakim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."EKIPMAN_BAKIMLARI_bakim_id_seq" OWNED BY public."EKIPMAN_BAKIMLARI".bakim_id;


--
-- TOC entry 233 (class 1259 OID 24683)
-- Name: ETKINLIKLER; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ETKINLIKLER" (
    etkinlik_id integer NOT NULL,
    etkinlik_adi character varying(100) NOT NULL,
    etkinlik_tarihi timestamp without time zone NOT NULL,
    konum character varying(100),
    max_katilimci integer
);


ALTER TABLE public."ETKINLIKLER" OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 24682)
-- Name: ETKINLIKLER_etkinlik_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."ETKINLIKLER_etkinlik_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."ETKINLIKLER_etkinlik_id_seq" OWNER TO postgres;

--
-- TOC entry 3492 (class 0 OID 0)
-- Dependencies: 232
-- Name: ETKINLIKLER_etkinlik_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."ETKINLIKLER_etkinlik_id_seq" OWNED BY public."ETKINLIKLER".etkinlik_id;


--
-- TOC entry 235 (class 1259 OID 24690)
-- Name: ETKINLIK_KAYITLARI; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ETKINLIK_KAYITLARI" (
    etkinlik_kayit_id integer NOT NULL,
    etkinlik_id integer NOT NULL,
    uye_id integer NOT NULL,
    kayit_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."ETKINLIK_KAYITLARI" OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 24689)
-- Name: ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq" OWNER TO postgres;

--
-- TOC entry 3493 (class 0 OID 0)
-- Dependencies: 234
-- Name: ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq" OWNED BY public."ETKINLIK_KAYITLARI".etkinlik_kayit_id;


--
-- TOC entry 237 (class 1259 OID 24708)
-- Name: GERIBILDIRIMLER; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."GERIBILDIRIMLER" (
    geribildirim_id integer NOT NULL,
    uye_id integer NOT NULL,
    geribildirim_turu character varying(50) NOT NULL,
    ilgili_id integer,
    yorum text,
    geribildirim_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."GERIBILDIRIMLER" OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 24707)
-- Name: GERIBILDIRIMLER_geribildirim_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."GERIBILDIRIMLER_geribildirim_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."GERIBILDIRIMLER_geribildirim_id_seq" OWNER TO postgres;

--
-- TOC entry 3494 (class 0 OID 0)
-- Dependencies: 236
-- Name: GERIBILDIRIMLER_geribildirim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."GERIBILDIRIMLER_geribildirim_id_seq" OWNED BY public."GERIBILDIRIMLER".geribildirim_id;


--
-- TOC entry 227 (class 1259 OID 24646)
-- Name: ODEMELER; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ODEMELER" (
    odeme_id integer NOT NULL,
    uye_id integer NOT NULL,
    tutar numeric(10,2) NOT NULL,
    odeme_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    odeme_yontemi character varying(50)
);


ALTER TABLE public."ODEMELER" OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 24645)
-- Name: ODEMELER_odeme_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."ODEMELER_odeme_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."ODEMELER_odeme_id_seq" OWNER TO postgres;

--
-- TOC entry 3495 (class 0 OID 0)
-- Dependencies: 226
-- Name: ODEMELER_odeme_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."ODEMELER_odeme_id_seq" OWNED BY public."ODEMELER".odeme_id;


--
-- TOC entry 241 (class 1259 OID 24730)
-- Name: SATIN_ALIMLAR; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."SATIN_ALIMLAR" (
    satin_alim_id integer NOT NULL,
    uye_id integer NOT NULL,
    urun_id integer NOT NULL,
    satin_alim_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    miktar integer NOT NULL
);


ALTER TABLE public."SATIN_ALIMLAR" OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 24729)
-- Name: SATIN_ALIMLAR_satin_alim_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."SATIN_ALIMLAR_satin_alim_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."SATIN_ALIMLAR_satin_alim_id_seq" OWNER TO postgres;

--
-- TOC entry 3496 (class 0 OID 0)
-- Dependencies: 240
-- Name: SATIN_ALIMLAR_satin_alim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."SATIN_ALIMLAR_satin_alim_id_seq" OWNED BY public."SATIN_ALIMLAR".satin_alim_id;


--
-- TOC entry 239 (class 1259 OID 24723)
-- Name: URUNLER; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."URUNLER" (
    urun_id integer NOT NULL,
    urun_adi character varying(100) NOT NULL,
    aciklama character varying(255),
    fiyat numeric(10,2) NOT NULL,
    stok_miktari integer NOT NULL
);


ALTER TABLE public."URUNLER" OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 24722)
-- Name: URUNLER_urun_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."URUNLER_urun_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."URUNLER_urun_id_seq" OWNER TO postgres;

--
-- TOC entry 3497 (class 0 OID 0)
-- Dependencies: 238
-- Name: URUNLER_urun_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."URUNLER_urun_id_seq" OWNED BY public."URUNLER".urun_id;


--
-- TOC entry 217 (class 1259 OID 24585)
-- Name: UYELER; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."UYELER" (
    uye_id integer NOT NULL,
    ad character varying(40) NOT NULL,
    soyad character varying(40) NOT NULL,
    dogum_tarihi date,
    cinsiyet character varying(10),
    iletisim_bilgisi character varying(255),
    plan_id integer
);


ALTER TABLE public."UYELER" OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 24584)
-- Name: UYELER_uye_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."UYELER_uye_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."UYELER_uye_id_seq" OWNER TO postgres;

--
-- TOC entry 3498 (class 0 OID 0)
-- Dependencies: 216
-- Name: UYELER_uye_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."UYELER_uye_id_seq" OWNED BY public."UYELER".uye_id;


--
-- TOC entry 215 (class 1259 OID 24578)
-- Name: UYELIK_PLANLARI; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."UYELIK_PLANLARI" (
    plan_id integer NOT NULL,
    plan_adi character varying(100) NOT NULL,
    ucret numeric(10,2) NOT NULL,
    sure integer NOT NULL,
    aciklama character varying(255)
);


ALTER TABLE public."UYELIK_PLANLARI" OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 24577)
-- Name: UYELIK_PLANLARI_plan_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."UYELIK_PLANLARI_plan_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."UYELIK_PLANLARI_plan_id_seq" OWNER TO postgres;

--
-- TOC entry 3499 (class 0 OID 0)
-- Dependencies: 214
-- Name: UYELIK_PLANLARI_plan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."UYELIK_PLANLARI_plan_id_seq" OWNED BY public."UYELIK_PLANLARI".plan_id;


--
-- TOC entry 3249 (class 2604 OID 24600)
-- Name: CALISANLAR calisan_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CALISANLAR" ALTER COLUMN calisan_id SET DEFAULT nextval('public."CALISANLAR_calisan_id_seq"'::regclass);


--
-- TOC entry 3250 (class 2604 OID 24607)
-- Name: DERSLER ders_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERSLER" ALTER COLUMN ders_id SET DEFAULT nextval('public."DERSLER_ders_id_seq"'::regclass);


--
-- TOC entry 3252 (class 2604 OID 24631)
-- Name: DERS_REZERVASYONLARI rezervasyon_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERS_REZERVASYONLARI" ALTER COLUMN rezervasyon_id SET DEFAULT nextval('public."DERS_REZERVASYONLARI_rezervasyon_id_seq"'::regclass);


--
-- TOC entry 3251 (class 2604 OID 24619)
-- Name: DERS_TAKVIMLERI takvim_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERS_TAKVIMLERI" ALTER COLUMN takvim_id SET DEFAULT nextval('public."DERS_TAKVIMLERI_takvim_id_seq"'::regclass);


--
-- TOC entry 3256 (class 2604 OID 24662)
-- Name: EKIPMANLAR ekipman_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."EKIPMANLAR" ALTER COLUMN ekipman_id SET DEFAULT nextval('public."EKIPMANLAR_ekipman_id_seq"'::regclass);


--
-- TOC entry 3257 (class 2604 OID 24674)
-- Name: EKIPMAN_BAKIMLARI bakim_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."EKIPMAN_BAKIMLARI" ALTER COLUMN bakim_id SET DEFAULT nextval('public."EKIPMAN_BAKIMLARI_bakim_id_seq"'::regclass);


--
-- TOC entry 3258 (class 2604 OID 24686)
-- Name: ETKINLIKLER etkinlik_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ETKINLIKLER" ALTER COLUMN etkinlik_id SET DEFAULT nextval('public."ETKINLIKLER_etkinlik_id_seq"'::regclass);


--
-- TOC entry 3259 (class 2604 OID 24693)
-- Name: ETKINLIK_KAYITLARI etkinlik_kayit_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ETKINLIK_KAYITLARI" ALTER COLUMN etkinlik_kayit_id SET DEFAULT nextval('public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq"'::regclass);


--
-- TOC entry 3261 (class 2604 OID 24711)
-- Name: GERIBILDIRIMLER geribildirim_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."GERIBILDIRIMLER" ALTER COLUMN geribildirim_id SET DEFAULT nextval('public."GERIBILDIRIMLER_geribildirim_id_seq"'::regclass);


--
-- TOC entry 3254 (class 2604 OID 24649)
-- Name: ODEMELER odeme_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ODEMELER" ALTER COLUMN odeme_id SET DEFAULT nextval('public."ODEMELER_odeme_id_seq"'::regclass);


--
-- TOC entry 3264 (class 2604 OID 24733)
-- Name: SATIN_ALIMLAR satin_alim_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SATIN_ALIMLAR" ALTER COLUMN satin_alim_id SET DEFAULT nextval('public."SATIN_ALIMLAR_satin_alim_id_seq"'::regclass);


--
-- TOC entry 3263 (class 2604 OID 24726)
-- Name: URUNLER urun_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."URUNLER" ALTER COLUMN urun_id SET DEFAULT nextval('public."URUNLER_urun_id_seq"'::regclass);


--
-- TOC entry 3248 (class 2604 OID 24588)
-- Name: UYELER uye_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UYELER" ALTER COLUMN uye_id SET DEFAULT nextval('public."UYELER_uye_id_seq"'::regclass);


--
-- TOC entry 3247 (class 2604 OID 24581)
-- Name: UYELIK_PLANLARI plan_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UYELIK_PLANLARI" ALTER COLUMN plan_id SET DEFAULT nextval('public."UYELIK_PLANLARI_plan_id_seq"'::regclass);


--
-- TOC entry 3458 (class 0 OID 24597)
-- Dependencies: 219
-- Data for Name: CALISANLAR; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."CALISANLAR" (calisan_id, ad, soyad, gorev, ise_giris_tarihi) FROM stdin;
1	ALI	DEMIR	egitmen	2020-01-01
2	AYSE	KARA	resepsiyonist	2021-05-15
3	VELI	SARI	yonetici	2019-09-10
4	FATMA	AK	egitmen	2022-02-20
5	Ahmet	Yılmaz	Eğitmen	2023-12-01
6	Murat	Atılgan	Eğitmen	2023-10-11
\.


--
-- TOC entry 3460 (class 0 OID 24604)
-- Dependencies: 221
-- Data for Name: DERSLER; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."DERSLER" (ders_id, ders_adi, ders_aciklama, calisan_id) FROM stdin;
1	Pilates	Esneme ve denge dersi	1
2	Yoga	Ruhsal ve fiziksel denge	4
3	Spinning	Kondisyon artırma dersi	1
\.


--
-- TOC entry 3464 (class 0 OID 24628)
-- Dependencies: 225
-- Data for Name: DERS_REZERVASYONLARI; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."DERS_REZERVASYONLARI" (rezervasyon_id, takvim_id, uye_id, rezervasyon_tarihi, durum) FROM stdin;
23	1	1	2024-12-08 18:24:01.114686	onayli
24	1	2	2024-12-08 18:24:01.114686	onayli
25	2	3	2024-12-08 18:24:01.114686	onayli
26	3	1	2024-12-08 18:24:01.114686	onayli
\.


--
-- TOC entry 3462 (class 0 OID 24616)
-- Dependencies: 223
-- Data for Name: DERS_TAKVIMLERI; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."DERS_TAKVIMLERI" (takvim_id, ders_id, baslama_zamani, bitis_zamani, max_katilimci) FROM stdin;
1	1	2024-12-10 10:00:00	2024-12-10 11:00:00	10
2	1	2024-12-11 10:00:00	2024-12-11 11:00:00	10
3	2	2024-12-10 08:00:00	2024-12-10 09:00:00	8
4	3	2024-12-10 19:00:00	2024-12-10 20:00:00	15
5	1	2024-12-10 10:00:00	2024-12-10 11:00:00	10
6	1	2024-12-11 10:00:00	2024-12-11 11:00:00	10
7	2	2024-12-10 08:00:00	2024-12-10 09:00:00	8
8	3	2024-12-10 19:00:00	2024-12-10 20:00:00	15
\.


--
-- TOC entry 3468 (class 0 OID 24659)
-- Dependencies: 229
-- Data for Name: EKIPMANLAR; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."EKIPMANLAR" (ekipman_id, ekipman_adi, ekipman_turu, satin_alim_tarihi, calisan_id) FROM stdin;
1	Koşu Bandı	Kardiyo	2024-01-05	3
2	Ağırlık Seti	Ağırlık	2024-02-10	3
3	Yoga Matı	Esneme	2024-03-15	3
\.


--
-- TOC entry 3470 (class 0 OID 24671)
-- Dependencies: 231
-- Data for Name: EKIPMAN_BAKIMLARI; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."EKIPMAN_BAKIMLARI" (bakim_id, ekipman_id, bakim_tarihi, bakim_aciklama) FROM stdin;
1	1	2024-03-20	Periyodik bakım
2	2	2024-04-01	Ağırlık denge kontrolü
\.


--
-- TOC entry 3472 (class 0 OID 24683)
-- Dependencies: 233
-- Data for Name: ETKINLIKLER; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ETKINLIKLER" (etkinlik_id, etkinlik_adi, etkinlik_tarihi, konum, max_katilimci) FROM stdin;
1	Yeni Yıl Yoga Etkinliği	2024-12-31 09:00:00	Ana Salon	20
2	Kardiyo Maratonu	2025-01-15 07:00:00	Dış Alan	30
\.


--
-- TOC entry 3474 (class 0 OID 24690)
-- Dependencies: 235
-- Data for Name: ETKINLIK_KAYITLARI; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ETKINLIK_KAYITLARI" (etkinlik_kayit_id, etkinlik_id, uye_id, kayit_tarihi) FROM stdin;
1	1	1	2024-12-08 18:24:47.738956
2	1	2	2024-12-08 18:24:47.738956
3	2	3	2024-12-08 18:24:47.738956
\.


--
-- TOC entry 3476 (class 0 OID 24708)
-- Dependencies: 237
-- Data for Name: GERIBILDIRIMLER; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."GERIBILDIRIMLER" (geribildirim_id, uye_id, geribildirim_turu, ilgili_id, yorum, geribildirim_tarihi) FROM stdin;
1	1	ders	1	Pilates dersi çok verimliydi!	2024-12-08 18:25:04.520368
2	2	etkinlik	1	Yeni yıl etkinliği harikaydı.	2024-12-08 18:25:04.520368
3	3	ekipman	2	Ağırlık seti biraz dağınık duruyor.	2024-12-08 18:25:04.520368
4	1	egitmen	1	Eğitmen Ali Demir çok ilgili ve bilgili.	2024-12-08 18:25:04.520368
\.


--
-- TOC entry 3466 (class 0 OID 24646)
-- Dependencies: 227
-- Data for Name: ODEMELER; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ODEMELER" (odeme_id, uye_id, tutar, odeme_tarihi, odeme_yontemi) FROM stdin;
4	1	100.00	2024-12-08 18:24:09.036949	nakit
5	2	200.00	2024-12-08 18:24:09.036949	kredi_karti
6	3	100.00	2024-12-08 18:24:09.036949	kredi_karti
7	1	100.00	2024-12-08 18:35:23.872118	otomatik_odeme
8	2	200.00	2024-12-08 18:35:23.872118	otomatik_odeme
9	3	100.00	2024-12-08 18:35:23.872118	otomatik_odeme
11	1	100.00	2024-12-08 18:57:37.367689	otomatik_odeme
12	2	200.00	2024-12-08 18:57:37.367689	otomatik_odeme
13	3	100.00	2024-12-08 18:57:37.367689	otomatik_odeme
14	1	100.00	2024-12-08 18:58:33.557084	otomatik_odeme
15	2	200.00	2024-12-08 18:58:33.557084	otomatik_odeme
16	3	100.00	2024-12-08 18:58:33.557084	otomatik_odeme
17	1	100.00	2024-12-08 18:58:35.112937	otomatik_odeme
18	2	200.00	2024-12-08 18:58:35.112937	otomatik_odeme
19	3	100.00	2024-12-08 18:58:35.112937	otomatik_odeme
20	1	100.00	2024-12-08 18:58:37.821063	otomatik_odeme
21	2	200.00	2024-12-08 18:58:37.821063	otomatik_odeme
22	3	100.00	2024-12-08 18:58:37.821063	otomatik_odeme
23	1	100.00	2024-12-08 18:58:38.324063	otomatik_odeme
24	2	200.00	2024-12-08 18:58:38.324063	otomatik_odeme
25	3	100.00	2024-12-08 18:58:38.324063	otomatik_odeme
26	1	100.00	2024-12-08 18:58:39.244226	otomatik_odeme
27	2	200.00	2024-12-08 18:58:39.244226	otomatik_odeme
28	3	100.00	2024-12-08 18:58:39.244226	otomatik_odeme
29	1	100.00	2024-12-08 18:58:40.031979	otomatik_odeme
30	2	200.00	2024-12-08 18:58:40.031979	otomatik_odeme
31	3	100.00	2024-12-08 18:58:40.031979	otomatik_odeme
32	1	100.00	2024-12-08 18:58:49.062547	otomatik_odeme
33	2	200.00	2024-12-08 18:58:49.062547	otomatik_odeme
34	3	100.00	2024-12-08 18:58:49.062547	otomatik_odeme
35	1	100.00	2024-12-08 18:58:49.8125	otomatik_odeme
36	2	200.00	2024-12-08 18:58:49.8125	otomatik_odeme
37	3	100.00	2024-12-08 18:58:49.8125	otomatik_odeme
38	1	100.00	2024-12-08 18:58:50.361869	otomatik_odeme
39	2	200.00	2024-12-08 18:58:50.361869	otomatik_odeme
40	3	100.00	2024-12-08 18:58:50.361869	otomatik_odeme
41	1	100.00	2024-12-22 20:16:45.467632	otomatik_odeme
42	2	200.00	2024-12-22 20:16:45.467632	otomatik_odeme
43	3	100.00	2024-12-22 20:16:45.467632	otomatik_odeme
44	1	100.00	2025-01-01 00:00:00	otomatik_odeme
45	2	200.00	2025-01-01 00:00:00	otomatik_odeme
46	3	100.00	2025-01-01 00:00:00	otomatik_odeme
\.


--
-- TOC entry 3480 (class 0 OID 24730)
-- Dependencies: 241
-- Data for Name: SATIN_ALIMLAR; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."SATIN_ALIMLAR" (satin_alim_id, uye_id, urun_id, satin_alim_tarihi, miktar) FROM stdin;
1	1	1	2024-12-08 18:25:21.655015	2
2	2	2	2024-12-08 18:25:21.655015	1
\.


--
-- TOC entry 3478 (class 0 OID 24723)
-- Dependencies: 239
-- Data for Name: URUNLER; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."URUNLER" (urun_id, urun_adi, aciklama, fiyat, stok_miktari) FROM stdin;
1	Protein Tozu	Antrenman sonrası kullanım	200.00	50
2	Spor Çantası	Su geçirmez	100.00	20
4	Su Şişesi	Su doldurulur	10.00	20
\.


--
-- TOC entry 3456 (class 0 OID 24585)
-- Dependencies: 217
-- Data for Name: UYELER; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."UYELER" (uye_id, ad, soyad, dogum_tarihi, cinsiyet, iletisim_bilgisi, plan_id) FROM stdin;
1	AHMET	YILMAZ	1990-05-05	Erkek	05551112233	1
2	AYSE	DEMIR	1995-10-10	Kadin	05441234567	2
3	MEHMET	AK	1985-03-20	Erkek	05321239876	2
\.


--
-- TOC entry 3454 (class 0 OID 24578)
-- Dependencies: 215
-- Data for Name: UYELIK_PLANLARI; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."UYELIK_PLANLARI" (plan_id, plan_adi, ucret, sure, aciklama) FROM stdin;
1	Standart	100.00	30	Standart plan aylık 100 TL
2	Premium	200.00	30	Daha fazla ders ve ekipman erişimi
3	Yillik	1000.00	365	Yıllık tek sefer ödemeli
\.


--
-- TOC entry 3500 (class 0 OID 0)
-- Dependencies: 218
-- Name: CALISANLAR_calisan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."CALISANLAR_calisan_id_seq"', 6, true);


--
-- TOC entry 3501 (class 0 OID 0)
-- Dependencies: 220
-- Name: DERSLER_ders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."DERSLER_ders_id_seq"', 3, true);


--
-- TOC entry 3502 (class 0 OID 0)
-- Dependencies: 224
-- Name: DERS_REZERVASYONLARI_rezervasyon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."DERS_REZERVASYONLARI_rezervasyon_id_seq"', 26, true);


--
-- TOC entry 3503 (class 0 OID 0)
-- Dependencies: 222
-- Name: DERS_TAKVIMLERI_takvim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."DERS_TAKVIMLERI_takvim_id_seq"', 8, true);


--
-- TOC entry 3504 (class 0 OID 0)
-- Dependencies: 228
-- Name: EKIPMANLAR_ekipman_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."EKIPMANLAR_ekipman_id_seq"', 3, true);


--
-- TOC entry 3505 (class 0 OID 0)
-- Dependencies: 230
-- Name: EKIPMAN_BAKIMLARI_bakim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."EKIPMAN_BAKIMLARI_bakim_id_seq"', 2, true);


--
-- TOC entry 3506 (class 0 OID 0)
-- Dependencies: 232
-- Name: ETKINLIKLER_etkinlik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ETKINLIKLER_etkinlik_id_seq"', 2, true);


--
-- TOC entry 3507 (class 0 OID 0)
-- Dependencies: 234
-- Name: ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ETKINLIK_KAYITLARI_etkinlik_kayit_id_seq"', 3, true);


--
-- TOC entry 3508 (class 0 OID 0)
-- Dependencies: 236
-- Name: GERIBILDIRIMLER_geribildirim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."GERIBILDIRIMLER_geribildirim_id_seq"', 4, true);


--
-- TOC entry 3509 (class 0 OID 0)
-- Dependencies: 226
-- Name: ODEMELER_odeme_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."ODEMELER_odeme_id_seq"', 46, true);


--
-- TOC entry 3510 (class 0 OID 0)
-- Dependencies: 240
-- Name: SATIN_ALIMLAR_satin_alim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."SATIN_ALIMLAR_satin_alim_id_seq"', 3, true);


--
-- TOC entry 3511 (class 0 OID 0)
-- Dependencies: 238
-- Name: URUNLER_urun_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."URUNLER_urun_id_seq"', 4, true);


--
-- TOC entry 3512 (class 0 OID 0)
-- Dependencies: 216
-- Name: UYELER_uye_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."UYELER_uye_id_seq"', 7, true);


--
-- TOC entry 3513 (class 0 OID 0)
-- Dependencies: 214
-- Name: UYELIK_PLANLARI_plan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."UYELIK_PLANLARI_plan_id_seq"', 3, true);


--
-- TOC entry 3271 (class 2606 OID 24602)
-- Name: CALISANLAR CalisanlarPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CALISANLAR"
    ADD CONSTRAINT "CalisanlarPK" PRIMARY KEY (calisan_id);


--
-- TOC entry 3277 (class 2606 OID 24634)
-- Name: DERS_REZERVASYONLARI DersRezervasyonlariPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERS_REZERVASYONLARI"
    ADD CONSTRAINT "DersRezervasyonlariPK" PRIMARY KEY (rezervasyon_id);


--
-- TOC entry 3275 (class 2606 OID 24621)
-- Name: DERS_TAKVIMLERI DersTakvimleriPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERS_TAKVIMLERI"
    ADD CONSTRAINT "DersTakvimleriPK" PRIMARY KEY (takvim_id);


--
-- TOC entry 3273 (class 2606 OID 24609)
-- Name: DERSLER DerslerPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERSLER"
    ADD CONSTRAINT "DerslerPK" PRIMARY KEY (ders_id);


--
-- TOC entry 3283 (class 2606 OID 24676)
-- Name: EKIPMAN_BAKIMLARI EkipmanBakimlariPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."EKIPMAN_BAKIMLARI"
    ADD CONSTRAINT "EkipmanBakimlariPK" PRIMARY KEY (bakim_id);


--
-- TOC entry 3281 (class 2606 OID 24664)
-- Name: EKIPMANLAR EkipmanlarPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."EKIPMANLAR"
    ADD CONSTRAINT "EkipmanlarPK" PRIMARY KEY (ekipman_id);


--
-- TOC entry 3287 (class 2606 OID 24696)
-- Name: ETKINLIK_KAYITLARI EtkinlikKayitlariPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ETKINLIK_KAYITLARI"
    ADD CONSTRAINT "EtkinlikKayitlariPK" PRIMARY KEY (etkinlik_kayit_id);


--
-- TOC entry 3285 (class 2606 OID 24688)
-- Name: ETKINLIKLER EtkinliklerPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ETKINLIKLER"
    ADD CONSTRAINT "EtkinliklerPK" PRIMARY KEY (etkinlik_id);


--
-- TOC entry 3289 (class 2606 OID 24716)
-- Name: GERIBILDIRIMLER GeribildirimlerPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."GERIBILDIRIMLER"
    ADD CONSTRAINT "GeribildirimlerPK" PRIMARY KEY (geribildirim_id);


--
-- TOC entry 3279 (class 2606 OID 24652)
-- Name: ODEMELER OdemelerPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ODEMELER"
    ADD CONSTRAINT "OdemelerPK" PRIMARY KEY (odeme_id);


--
-- TOC entry 3293 (class 2606 OID 24736)
-- Name: SATIN_ALIMLAR SatinAlimlarPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SATIN_ALIMLAR"
    ADD CONSTRAINT "SatinAlimlarPK" PRIMARY KEY (satin_alim_id);


--
-- TOC entry 3291 (class 2606 OID 24728)
-- Name: URUNLER UrunlerPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."URUNLER"
    ADD CONSTRAINT "UrunlerPK" PRIMARY KEY (urun_id);


--
-- TOC entry 3269 (class 2606 OID 24590)
-- Name: UYELER UyelerPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UYELER"
    ADD CONSTRAINT "UyelerPK" PRIMARY KEY (uye_id);


--
-- TOC entry 3267 (class 2606 OID 24583)
-- Name: UYELIK_PLANLARI UyelikPlanlariPK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UYELIK_PLANLARI"
    ADD CONSTRAINT "UyelikPlanlariPK" PRIMARY KEY (plan_id);


--
-- TOC entry 3308 (class 2620 OID 24755)
-- Name: DERS_TAKVIMLERI ders_takvimleri_update_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ders_takvimleri_update_trg BEFORE UPDATE ON public."DERS_TAKVIMLERI" FOR EACH ROW EXECUTE FUNCTION public.ders_takvimleri_before_update();


--
-- TOC entry 3309 (class 2620 OID 24757)
-- Name: ODEMELER odemeler_insert_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER odemeler_insert_trg BEFORE INSERT ON public."ODEMELER" FOR EACH ROW EXECUTE FUNCTION public.odemeler_before_insert();


--
-- TOC entry 3310 (class 2620 OID 24759)
-- Name: URUNLER urunler_update_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER urunler_update_trg BEFORE UPDATE ON public."URUNLER" FOR EACH ROW EXECUTE FUNCTION public.urunler_before_update();


--
-- TOC entry 3307 (class 2620 OID 32952)
-- Name: UYELER uyeler_insert_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER uyeler_insert_trg BEFORE INSERT OR UPDATE ON public."UYELER" FOR EACH ROW EXECUTE FUNCTION public.uyeler_before_insert();


--
-- TOC entry 3297 (class 2606 OID 24635)
-- Name: DERS_REZERVASYONLARI DersRezervasyonlariTakvimFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERS_REZERVASYONLARI"
    ADD CONSTRAINT "DersRezervasyonlariTakvimFK" FOREIGN KEY (takvim_id) REFERENCES public."DERS_TAKVIMLERI"(takvim_id);


--
-- TOC entry 3298 (class 2606 OID 24640)
-- Name: DERS_REZERVASYONLARI DersRezervasyonlariUyeFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERS_REZERVASYONLARI"
    ADD CONSTRAINT "DersRezervasyonlariUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id);


--
-- TOC entry 3296 (class 2606 OID 24622)
-- Name: DERS_TAKVIMLERI DersTakvimleriDersFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERS_TAKVIMLERI"
    ADD CONSTRAINT "DersTakvimleriDersFK" FOREIGN KEY (ders_id) REFERENCES public."DERSLER"(ders_id);


--
-- TOC entry 3295 (class 2606 OID 24610)
-- Name: DERSLER DerslerCalisanFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."DERSLER"
    ADD CONSTRAINT "DerslerCalisanFK" FOREIGN KEY (calisan_id) REFERENCES public."CALISANLAR"(calisan_id);


--
-- TOC entry 3301 (class 2606 OID 24677)
-- Name: EKIPMAN_BAKIMLARI EkipmanBakimlariEkipmanFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."EKIPMAN_BAKIMLARI"
    ADD CONSTRAINT "EkipmanBakimlariEkipmanFK" FOREIGN KEY (ekipman_id) REFERENCES public."EKIPMANLAR"(ekipman_id);


--
-- TOC entry 3300 (class 2606 OID 24665)
-- Name: EKIPMANLAR EkipmanlarCalisanFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."EKIPMANLAR"
    ADD CONSTRAINT "EkipmanlarCalisanFK" FOREIGN KEY (calisan_id) REFERENCES public."CALISANLAR"(calisan_id);


--
-- TOC entry 3302 (class 2606 OID 24697)
-- Name: ETKINLIK_KAYITLARI EtkinlikKayitlariEtkinlikFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ETKINLIK_KAYITLARI"
    ADD CONSTRAINT "EtkinlikKayitlariEtkinlikFK" FOREIGN KEY (etkinlik_id) REFERENCES public."ETKINLIKLER"(etkinlik_id);


--
-- TOC entry 3303 (class 2606 OID 24702)
-- Name: ETKINLIK_KAYITLARI EtkinlikKayitlariUyeFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ETKINLIK_KAYITLARI"
    ADD CONSTRAINT "EtkinlikKayitlariUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id);


--
-- TOC entry 3304 (class 2606 OID 24717)
-- Name: GERIBILDIRIMLER GeribildirimlerUyeFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."GERIBILDIRIMLER"
    ADD CONSTRAINT "GeribildirimlerUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id);


--
-- TOC entry 3299 (class 2606 OID 24760)
-- Name: ODEMELER OdemelerUyeFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ODEMELER"
    ADD CONSTRAINT "OdemelerUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id) ON DELETE CASCADE;


--
-- TOC entry 3305 (class 2606 OID 24765)
-- Name: SATIN_ALIMLAR SatinAlimlarUrunFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SATIN_ALIMLAR"
    ADD CONSTRAINT "SatinAlimlarUrunFK" FOREIGN KEY (urun_id) REFERENCES public."URUNLER"(urun_id) ON DELETE CASCADE;


--
-- TOC entry 3306 (class 2606 OID 24737)
-- Name: SATIN_ALIMLAR SatinAlimlarUyeFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SATIN_ALIMLAR"
    ADD CONSTRAINT "SatinAlimlarUyeFK" FOREIGN KEY (uye_id) REFERENCES public."UYELER"(uye_id);


--
-- TOC entry 3294 (class 2606 OID 24591)
-- Name: UYELER UyelerPlanFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UYELER"
    ADD CONSTRAINT "UyelerPlanFK" FOREIGN KEY (plan_id) REFERENCES public."UYELIK_PLANLARI"(plan_id);


-- Completed on 2024-12-22 22:34:26

--
-- PostgreSQL database dump complete
--

