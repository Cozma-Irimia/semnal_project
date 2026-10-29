#include <Arduino.h>

// Jumper: GPIO25 (DAC) -> GPIO34 (ADC)
#define DAC_PIN 25
#define ADC_PIN 34
#define LED_PIN 2

static const int N = 1000;
static const int F_HZ = 100;
static const int FS = 4000;  // 250 us; Nyquist = 2000 Hz
static const float V_OFFSET = 1.5f;
static const float V_PEAK = 1.0f;

static uint8_t dacCode[N];
static uint16_t dacMv[N];
static uint16_t adcMv[N];

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  analogRead(ADC_PIN);

  const int samplesPerCycle = FS / F_HZ;  // 40
  for (int i = 0; i < N; i++) {
    const float v = V_OFFSET + V_PEAK * sinf(2.0f * PI * (i % samplesPerCycle) / samplesPerCycle);
    int code = (int)(v / 3.3f * 255.0f + 0.5f);
    if (code < 0) {
      code = 0;
    }
    if (code > 255) {
      code = 255;
    }
    dacCode[i] = (uint8_t)code;
    dacMv[i] = (uint16_t)(v * 1000.0f + 0.5f);
  }

  dacWrite(DAC_PIN, dacCode[0]);
  digitalWrite(LED_PIN, LOW);
}

void loop() {
  const uint32_t dtUs = 1000000UL / FS;
  const uint32_t t0 = micros();

  for (int i = 0; i < N; i++) {
    const uint32_t target = t0 + (uint32_t)i * dtUs;
    while ((int32_t)(micros() - target) < 0) {
    }
    dacWrite(DAC_PIN, dacCode[i]);
    delayMicroseconds(20);
    const int raw = analogRead(ADC_PIN);
    adcMv[i] = (uint16_t)((raw * 3300L) / 4095);
  }

  digitalWrite(LED_PIN, !digitalRead(LED_PIN));
  if (digitalRead(LED_PIN) == HIGH) {
    Serial.println("led on");
  } else {
    Serial.println("led off");
  }

  Serial.println("SINE");
  Serial.println(FS);
  for (int i = 0; i < N; i++) {
    Serial.print(dacMv[i]);
    Serial.print(',');
    Serial.println(adcMv[i]);
  }
}
