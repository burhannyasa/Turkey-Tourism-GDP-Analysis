# ==============================================================================
# Türkiye Turizm Gelirleri ve Ekonomik Büyüme (GSYİH) Analizi (2012-2024)
# Metodoloji: Kantitatif Zaman Serisi Analizi ve ARDL Modelleme
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Kütüphanelerin Yüklenmesi
# ------------------------------------------------------------------------------
library(readxl)    # Excel verilerini okumak için
library(ggplot2)   # Profesyonel görselleştirme
library(tidyverse) # Veri manipülasyonu (dplyr, tidyr vb.)
library(dplyr)     # Veri filtreleme ve özetleme
library(scales)    # Grafik eksen formatlamaları
library(corrplot)  # Korelasyon matrisi görselleştirme
library(tseries)   # Zaman serisi testleri (ADF, PP)
library(dynlm)     # Dinamik doğrusal modeller
library(urca)      # Birim kök ve eşbütünleşme testleri
library(MASS)      # Box-Cox dönüşümleri için

# ------------------------------------------------------------------------------
# 2. Veri Setlerinin Hazırlanması
# ------------------------------------------------------------------------------
# NOT: GitHub için yerel dosya yolları temizlenmiş, göreceli yollar eklenmiştir.
gelirveri   <- read.csv("data/Gelir.csv", sep = ",")
giderveri   <- read.csv("data/Gider.csv", sep = ",")
gdp_current <- read.csv("data/yeni_gdpm.csv")
gdp_cepita  <- read.csv("data/gdp_cepita.csv")

# Sütun İsimlerinin Standardizasyonu
colnames(gelirveri) <- c("Year", "Month", "Tourism_Income", "Number_of_Visitors", "Avg_Expenditure_Per_Capita")
colnames(giderveri) <- c("Year", "Month", "Tourism_Expenditures", "Number_of_Citizen_Visitors", "Avg_Expenditure_Per_Capita")
colnames(gdp_current) <- c("Year", "GDP")
colnames(gdp_cepita) <- c("Year", "GDP_per_cepita")

# ------------------------------------------------------------------------------
# 3. Tanımlayıcı İstatistikler (Descriptive Statistics)
# ------------------------------------------------------------------------------
# Veri setlerinin genel dağılım ve merkezi eğilim ölçülerini hesaplıyoruz.
summary(gelirveri)

# Spesifik özet tabloları oluşturma
income_summary <- gelirveri %>%
  summarise(
    Avg_Income = mean(Tourism_Income, na.rm = TRUE),
    Med_Income = median(Tourism_Income, na.rm = TRUE),
    Sd_Income  = sd(Tourism_Income, na.rm = TRUE),
    Min_Income = min(Tourism_Income, na.rm = TRUE),
    Max_Income = max(Tourism_Income, na.rm = TRUE)
  )
print(income_summary)

# ------------------------------------------------------------------------------
# 4. Keşifsel Veri Analizi (EDA) ve Görselleştirme
# ------------------------------------------------------------------------------

# 4.1. Turizm Gelirleri Zaman Serisi (Alan Grafiği)
yillik_gelir <- gelirveri %>%
  group_by(Year) %>%
  summarise(Total_Tourism_Income = sum(Tourism_Income, na.rm = TRUE))

ggplot(yillik_gelir, aes(x = Year, y = Total_Tourism_Income)) +
  geom_area(fill = "lightblue", alpha = 0.4) +
  geom_line(color = "navy", size = 1.2) +
  geom_point(color = "red", size = 2) +
  labs(title = "Türkiye Turizm Gelirleri Trend Analizi (2012-2024)", 
       x = "Yıl", y = "Toplam Gelir ($)") +
  scale_y_continuous(labels = dollar_format(scale = 1e-6, suffix = "M")) +
  theme_minimal()

# 4.2. GSYİH (GDP) Zaman Serisi Analizi
ggplot(gdp_current, aes(x = Year, y = GDP)) +
  geom_line(color = "purple", size = 1) +
  geom_point(color = "orange", size = 1.5) +
  labs(title = "Türkiye GSYİH Zaman Serisi (Cari Fiyatlarla)", x = "Yıl", y = "GDP (USD)") +
  scale_y_continuous(labels = scales::comma) +
  theme_minimal()

# 4.3. Dağılım Kontrolü (Histogram & Boxplot)
# Verideki çarpıklığı (skewness) ve aykırı değerleri (outliers) kontrol ediyoruz.
ggplot(gelirveri, aes(x = Tourism_Income)) +
  geom_histogram(binwidth = 500000, fill = "skyblue", color = "black", alpha = 0.7) +
  labs(title = "Turizm Gelirleri Dağılımı", x = "Gelir", y = "Frekans") +
  theme_minimal()

# ------------------------------------------------------------------------------
# 5. İlişki ve Korelasyon Analizi
# ------------------------------------------------------------------------------
# Bağımsız değişkenlerin gelir üzerindeki etkisini ölçmek için matris oluşturma
correlation_matrix_gelir <- cor(gelirveri[, c("Tourism_Income", "Number_of_Visitors", "Avg_Expenditure_Per_Capita")], 
                                use = "complete.obs")

# Korelasyon Matrisinin Görselleştirilmesi
corrplot(correlation_matrix_gelir, method = "circle", type = "lower", 
         tl.col = "black", tl.cex = 0.9, title = "Gelir-Ziyaretçi-Harcama Korelasyonu", mar=c(0,0,1,0))

# ------------------------------------------------------------------------------
# 6. Durağanlık (Stationarity) Analizleri
# ------------------------------------------------------------------------------
# Zaman serisi modelleri için I(0) veya I(1) seviyelerini belirliyoruz.

# ADF Testleri (Seviye Değerleri)
# Rapor sonucuna göre seriler seviyede durağan değildir (p > 0.05).
adf_tourism  <- adf.test(gelirveri$Tourism_Income)
adf_gdp      <- adf.test(gdp_current$GDP)
print(adf_tourism)

# Birinci Farkların Alınması (Durağanlaştırma İşlemi)
tourism_diff_clean <- na.omit(diff(gelirveri$Tourism_Income))
gdp_diff_clean     <- na.omit(diff(gdp_current$GDP))

# Fark Alınmış Serilerde ADF Testi
# Rapor sonucuna göre seriler I(1) seviyesinde durağanlaşmıştır.
adf_tourism_diff <- adf.test(tourism_diff_clean, alternative = "stationary")
print(adf_tourism_diff)

# ------------------------------------------------------------------------------
# 7. Ekonometrik Modelleme (ARDL)
# ------------------------------------------------------------------------------

# Analiz için Konsolide Veri Çerçevesi
yontemveri <- data.frame(
  Year = 2012:2024,
  TourismRevenue = c(35717336, 40186327, 41316834, 37700923, 26539007, 31253835, 35920910, 42851777, 36580750, 30309721, 49857029, 55874175, 62506762),
  TotalTourists  = c(36463920, 39226225, 41415070, 41617530, 31365329, 38620345, 45628672, 51860042, 40608752, 29357463, 51369025, 57077440, 58208631),
  GDP            = c(880.56, 957.80, 938.93, 864.31, 869.68, 858.99, 778.97, 761.01, 720.34, 819.87, 907.12, 1108.02, 872.13)
)

# ARDL Modelinin Kurulması
# Bağımlı: Turizm Geliri, Bağımsız: GSYİH ve Toplam Ziyaretçi Sayısı
ardl_model <- dynlm(TourismRevenue ~ L(TourismRevenue, 1) + L(TotalTourists, 1) + L(GDP, 1), 
                    data = yontemveri)

summary(ardl_model)

# ------------------------------------------------------------------------------
# 8. Model Tanısal Testleri ve Hata Düzeltme (ECM)
# ------------------------------------------------------------------------------

# Bounds Test (Eşbütünleşme Kontrolü)
# Değişkenler arasında uzun dönemli bir ilişki olup olmadığını test eder.
bounds_test <- ur.df(ardl_model$residuals, type = "none", selectlags = "AIC")
summary(bounds_test)

# Error Correction Model (ECM)
# Kısa dönem sapmaların dengeye dönüş hızını analiz eder.
ecm_model <- dynlm(diff(TourismRevenue) ~ L(diff(TourismRevenue), 1) + 
                     L(diff(TotalTourists), 1) + L(diff(GDP), 1), 
                   data = yontemveri)

summary(ecm_model)

# ==============================================================================
