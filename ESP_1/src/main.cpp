#include <Arduino.h>
#include <esp_system.h>
#include <esp_task_wdt.h>
#include <mbedtls/aes.h>
#include <stdlib.h>
#include <string.h>

// Jumper: GPIO25 (DAC) -> GPIO34 (ADC)
// MATLAB: "FS,10000" schimba esantionarea, "FIN,100" frecventa sinusoidei.
#define DAC_PIN 25
#define ADC_PIN 34
#define LED_PIN 2

static const int FS_MIN = 400;
static const int FS_MAX = 10000;
static const int F_MIN = 10;
static const int F_MAX = 1000;
static const int MIN_PER_CYCLE = 8;
static const int MAX_CYCLE = FS_MAX / F_MIN;
static const int CHUNK = 40;
static const float V_OFFSET = 1.5f;
static const float V_PEAK = 1.0f;
static const uint8_t AES_KEY[16] = {
    'E', 'S', 'P', '3', '2', '-', 'A', 'D', 'C', '-', 'K', 'E', 'Y', '-', '0', '1'};
static const char HEX_DIGITS[] = "0123456789abcdef";

static int fs = 10000;
static int fIn = 100;
static int samplesPerCycle = 100;
static int forma = 0;
static uint8_t sineCycle[MAX_CYCLE];
static uint16_t chunk[CHUNK];
static uint32_t ph = 0;

static char cmd[24];
static uint8_t cmdLen = 0;

uint8_t codDinAmplitudine(float y) {
  if (y > 1.0f) {
    y = 1.0f;
  }
  if (y < -1.0f) {
    y = -1.0f;
  }
  const float v = V_OFFSET + V_PEAK * y;
  int code = (int)(v / 3.3f * 255.0f + 0.5f);
  if (code < 0) {
    code = 0;
  }
  if (code > 255) {
    code = 255;
  }
  return (uint8_t)code;
}

void genereazaCiclu() {
  if (forma >= 3) {
    return;
  }
  for (int i = 0; i < samplesPerCycle; i++) {
    const float faza = (float)i / (float)samplesPerCycle;
    float y = 0.0f;
    if (forma == 0) {
      y = sinf(2.0f * PI * faza);
    } else if (forma == 1) {
      if (faza < 0.5f) {
        y = -1.0f + 4.0f * faza;
      } else {
        y = 3.0f - 4.0f * faza;
      }
    } else {
      y = (faza < 0.5f) ? 1.0f : -1.0f;
    }
    sineCycle[i] = codDinAmplitudine(y);
  }
}

uint8_t codAlb() {
  const float u = (float)esp_random() * (1.0f / 4294967295.0f);
  return codDinAmplitudine(-1.0f + 2.0f * u);
}

static float pinkB0 = 0, pinkB1 = 0, pinkB2 = 0, pinkB3 = 0, pinkB4 = 0, pinkB5 = 0, pinkB6 = 0;

void resetRoz() {
  pinkB0 = 0;
  pinkB1 = 0;
  pinkB2 = 0;
  pinkB3 = 0;
  pinkB4 = 0;
  pinkB5 = 0;
  pinkB6 = 0;
}

uint8_t codRoz() {
  const float white = ((float)esp_random() * (2.0f / 4294967295.0f)) - 1.0f;
  pinkB0 = 0.99886f * pinkB0 + white * 0.0555179f;
  pinkB1 = 0.99332f * pinkB1 + white * 0.0750759f;
  pinkB2 = 0.96900f * pinkB2 + white * 0.1538520f;
  pinkB3 = 0.86650f * pinkB3 + white * 0.3104856f;
  pinkB4 = 0.55000f * pinkB4 + white * 0.5329522f;
  pinkB5 = -0.7616f * pinkB5 - white * 0.0168980f;
  const float pink = pinkB0 + pinkB1 + pinkB2 + pinkB3 + pinkB4 + pinkB5 + pinkB6 + white * 0.5362f;
  pinkB6 = white * 0.115926f;
  return codDinAmplitudine(pink * 0.15f);
}

void aplicaFrecvente() {
  if (fIn < F_MIN) {
    fIn = F_MIN;
  }
  if (fIn > F_MAX) {
    fIn = F_MAX;
  }
  int n = (fs + fIn / 2) / fIn;
  if (n < MIN_PER_CYCLE) {
    n = MIN_PER_CYCLE;
  }
  if (n > MAX_CYCLE) {
    n = MAX_CYCLE;
  }
  samplesPerCycle = n;
  fIn = (fs + n / 2) / n;
  genereazaCiclu();
  if (forma < 3) {
    dacWrite(DAC_PIN, sineCycle[ph % (uint32_t)samplesPerCycle]);
  }
}

void seteazaFs(int nou) {
  if (nou < FS_MIN) {
    nou = FS_MIN;
  }
  if (nou > FS_MAX) {
    nou = FS_MAX;
  }
  nou = (nou / 100) * 100;
  if (nou < FS_MIN) {
    nou = FS_MIN;
  }
  fs = nou;
  aplicaFrecvente();
}

void seteazaFin(int nou) {
  fIn = nou;
  aplicaFrecvente();
}

void seteazaForma(int nou) {
  if (nou < 0) {
    nou = 0;
  }
  if (nou > 4) {
    nou = 4;
  }
  forma = nou;
  if (forma == 4) {
    resetRoz();
  }
  genereazaCiclu();
  if (forma < 3) {
    dacWrite(DAC_PIN, sineCycle[ph % (uint32_t)samplesPerCycle]);
  }
}

void aplicaComanda() {
  if (strncmp(cmd, "FS,", 3) == 0) {
    seteazaFs(atoi(cmd + 3));
  } else if (strncmp(cmd, "FIN,", 4) == 0) {
    seteazaFin(atoi(cmd + 4));
  } else if (strncmp(cmd, "WAVE,", 5) == 0) {
    seteazaForma(atoi(cmd + 5));
  }
}

void citesteComanda() {
  while (Serial.available() > 0) {
    const char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (cmdLen > 0) {
        cmd[cmdLen] = '\0';
        aplicaComanda();
        cmdLen = 0;
      }
    } else if (cmdLen < sizeof(cmd) - 1) {
      cmd[cmdLen++] = c;
    }
  }
}

void achizitieChunk() {
  const uint32_t dtUs = 1000000UL / (uint32_t)fs;
  const uint32_t t0 = micros();

  for (int i = 0; i < CHUNK; i++) {
    const uint32_t target = t0 + (uint32_t)i * dtUs;
    while ((int32_t)(micros() - target) < 0) {
    }
    uint8_t cod = 0;
    if (forma == 3) {
      cod = codAlb();
    } else if (forma == 4) {
      cod = codRoz();
    } else {
      cod = sineCycle[ph % (uint32_t)samplesPerCycle];
    }
    dacWrite(DAC_PIN, cod);
    delayMicroseconds(20);
    chunk[i] = (uint16_t)analogRead(ADC_PIN);
    ph++;
  }
}

uint16_t crc16Ccitt(const uint8_t *data, size_t len) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < len; i++) {
    crc ^= (uint16_t)data[i] << 8;
    for (int bit = 0; bit < 8; bit++) {
      if (crc & 0x8000) {
        crc = (uint16_t)((crc << 1) ^ 0x1021);
      } else {
        crc <<= 1;
      }
    }
  }
  return crc;
}

void cripteazaEsantioane(uint8_t *raw, size_t nbytes) {
  mbedtls_aes_context ctx;
  mbedtls_aes_init(&ctx);
  mbedtls_aes_setkey_enc(&ctx, AES_KEY, 128);
  for (size_t off = 0; off < nbytes; off += 16) {
    unsigned char bloc[16];
    mbedtls_aes_crypt_ecb(&ctx, MBEDTLS_AES_ENCRYPT, raw + off, bloc);
    memcpy(raw + off, bloc, 16);
  }
  mbedtls_aes_free(&ctx);
}

void trimiteChunk(uint32_t phStart) {
  uint8_t cadru[12 + CHUNK * 2];
  cadru[0] = (uint8_t)(fs & 0xFF);
  cadru[1] = (uint8_t)((fs >> 8) & 0xFF);
  cadru[2] = (uint8_t)(fIn & 0xFF);
  cadru[3] = (uint8_t)((fIn >> 8) & 0xFF);
  cadru[4] = (uint8_t)(samplesPerCycle & 0xFF);
  cadru[5] = (uint8_t)((samplesPerCycle >> 8) & 0xFF);
  cadru[6] = (uint8_t)(forma & 0xFF);
  cadru[7] = (uint8_t)((forma >> 8) & 0xFF);
  cadru[8] = (uint8_t)(phStart & 0xFF);
  cadru[9] = (uint8_t)((phStart >> 8) & 0xFF);
  cadru[10] = (uint8_t)((phStart >> 16) & 0xFF);
  cadru[11] = (uint8_t)((phStart >> 24) & 0xFF);
  for (int i = 0; i < CHUNK; i++) {
    cadru[12 + 2 * i] = (uint8_t)(chunk[i] & 0xFF);
    cadru[13 + 2 * i] = (uint8_t)((chunk[i] >> 8) & 0xFF);
  }
  cripteazaEsantioane(cadru + 12, CHUNK * 2);
  const uint16_t crc = crc16Ccitt(cadru, sizeof(cadru));

  char linie[320];
  int n = snprintf(linie, sizeof(linie), "W,%d,%d,%d,%d,%lu,%u,", fs, fIn, samplesPerCycle, forma,
                   (unsigned long)phStart, crc);
  if (n < 0 || n + CHUNK * 4 >= (int)sizeof(linie)) {
    return;
  }
  for (int i = 0; i < CHUNK * 2; i++) {
    linie[n++] = HEX_DIGITS[cadru[12 + i] >> 4];
    linie[n++] = HEX_DIGITS[cadru[12 + i] & 0x0F];
  }
  linie[n] = '\0';
  Serial.println(linie);
  esp_task_wdt_reset();
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  analogRead(ADC_PIN);
  aplicaFrecvente();
  digitalWrite(LED_PIN, LOW);
}

void loop() {
  static uint16_t cadre = 0;
  citesteComanda();
  const uint32_t phStart = ph;
  achizitieChunk();
  trimiteChunk(phStart);

  cadre++;
  if (cadre % 25 == 0) {
    digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    if (digitalRead(LED_PIN) == HIGH) {
      Serial.println("led on");
    } else {
      Serial.println("led off");
    }
  }
}
