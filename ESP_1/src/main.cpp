#include <Arduino.h>
#include <esp_task_wdt.h>

// Jumper: GPIO25 (DAC) -> GPIO34 (ADC)
// Trimite bucati scurte de coduri ADC, ca MATLAB sa poata derula sinusoida.
#define DAC_PIN 25
#define ADC_PIN 34
#define LED_PIN 2

static const int F_HZ = 100;
static const int FS = 4000;
static const int SAMPLES_PER_CYCLE = FS / F_HZ;  // 40
static const int CHUNK = SAMPLES_PER_CYCLE;
static const float V_OFFSET = 1.5f;
static const float V_PEAK = 1.0f;

static uint8_t sineCycle[SAMPLES_PER_CYCLE];
static uint16_t chunk[CHUNK];
static uint32_t ph = 0;

void genereazaCiclulSin() {
  for (int i = 0; i < SAMPLES_PER_CYCLE; i++) {
    const float v = V_OFFSET + V_PEAK * sinf(2.0f * PI * i / SAMPLES_PER_CYCLE);
    int code = (int)(v / 3.3f * 255.0f + 0.5f);
    if (code < 0) {
      code = 0;
    }
    if (code > 255) {
      code = 255;
    }
    sineCycle[i] = (uint8_t)code;
  }
}

void achizitieChunk() {
  const uint32_t dtUs = 1000000UL / FS;
  const uint32_t t0 = micros();

  for (int i = 0; i < CHUNK; i++) {
    const uint32_t target = t0 + (uint32_t)i * dtUs;
    while ((int32_t)(micros() - target) < 0) {
    }
    dacWrite(DAC_PIN, sineCycle[ph % SAMPLES_PER_CYCLE]);
    delayMicroseconds(20);
    chunk[i] = (uint16_t)analogRead(ADC_PIN);
    ph++;
  }
}

void trimiteChunk(uint32_t phStart) {
  char linie[256];
  int n = snprintf(linie, sizeof(linie), "W,%d,%lu", FS, (unsigned long)phStart);
  if (n < 0 || n >= (int)sizeof(linie)) {
    return;
  }
  for (int i = 0; i < CHUNK; i++) {
    const int w = snprintf(linie + n, sizeof(linie) - (size_t)n, ",%u", chunk[i]);
    if (w < 0 || n + w >= (int)sizeof(linie)) {
      return;
    }
    n += w;
  }
  Serial.println(linie);
  esp_task_wdt_reset();
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  analogRead(ADC_PIN);
  genereazaCiclulSin();
  dacWrite(DAC_PIN, sineCycle[0]);
  digitalWrite(LED_PIN, LOW);
}

void loop() {
  static uint16_t cadre = 0;
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
