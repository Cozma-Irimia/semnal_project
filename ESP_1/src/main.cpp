#include <Arduino.h>

#define LED_PIN 2
#define DAC_PIN 25   // DAC1 — leaga cu un jumper la ADC_PIN
#define ADC_PIN 34   // ADC1_CH6 (doar input)
#define N_SAMPLES 100
#define SAMPLE_US 10000  // 10 ms intre esantioane (1 perioada = 1 s)

static uint8_t triunghiDac[N_SAMPLES];
static uint32_t sampleIndex = 0;
static unsigned long t0 = 0;

void genereazaTabelaTriunghi() {
  const int jumate = N_SAMPLES / 2;
  for (int i = 0; i < N_SAMPLES; i++) {
    int val;
    if (i < jumate) {
      val = 1 + (254 * i) / (jumate - 1);
    } else {
      val = 255 - (254 * (i - jumate)) / (jumate - 1);
    }
    triunghiDac[i] = (uint8_t)val;
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  analogReadResolution(12);
  analogSetPinAttenuation(ADC_PIN, ADC_11db);
  genereazaTabelaTriunghi();
  dacWrite(DAC_PIN, 128);
  digitalWrite(LED_PIN, LOW);
  Serial.println("led off");
  t0 = micros();
}

void loop() {
  const unsigned long tinta = t0 + sampleIndex * (unsigned long)SAMPLE_US;
  while ((long)(micros() - tinta) < 0) {
  }

  if (sampleIndex % N_SAMPLES == 0 && sampleIndex > 0) {
    digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    if (digitalRead(LED_PIN) == HIGH) {
      Serial.println("led on");
    } else {
      Serial.println("led off");
    }
  }

  dacWrite(DAC_PIN, triunghiDac[sampleIndex % N_SAMPLES]);
  delayMicroseconds(50);
  const int adc = analogRead(ADC_PIN);

  const float tSec = sampleIndex * (SAMPLE_US / 1000000.0f);
  Serial.print(tSec, 5);
  Serial.print(',');
  Serial.println(adc);

  sampleIndex++;
}
