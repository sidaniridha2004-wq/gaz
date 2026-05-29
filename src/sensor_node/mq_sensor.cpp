// =============================================================================
//  mq_sensor.cpp  --  Implementation of the MQ gas-sensor driver
// =============================================================================
#include "mq_sensor.h"

// Number of ADC samples averaged per measurement to suppress noise.
static const uint8_t ADC_OVERSAMPLE = 16;

MQSensor::MQSensor(uint8_t adcPin, float rlOhms, float vcVolts,
                   float dividerRatio, float cleanAirRatio, float curveA,
                   float curveB)
    : _pin(adcPin),
      _rl(rlOhms),
      _vc(vcVolts),
      _divider(dividerRatio),
      _cleanRatio(cleanAirRatio),
      _a(curveA),
      _b(curveB) {}

void MQSensor::begin() {
  // 11 dB attenuation -> full-scale ~3.3 V, matching the external divider.
  analogSetPinAttenuation(_pin, ADC_11db);
  pinMode(_pin, INPUT);
}

float MQSensor::readAdcVolts() {
  // analogReadMilliVolts() applies the per-chip eFuse calibration, which is
  // far more accurate than scaling the raw 0-4095 count by hand.
  uint32_t accum_mv = 0;
  for (uint8_t i = 0; i < ADC_OVERSAMPLE; ++i) {
    accum_mv += analogReadMilliVolts(_pin);
  }
  return (accum_mv / (float)ADC_OVERSAMPLE) / 1000.0f;
}

float MQSensor::readVoltage() {
  // Undo the external resistor divider to recover the true sensor output.
  return readAdcVolts() * _divider;
}

float MQSensor::readRs() {
  float vout = readVoltage();
  // Guard against divide-by-zero / disconnected sensor (Vout ~ 0).
  if (vout < 0.01f) {
    return 1.0e9f;  // effectively infinite resistance -> ~0 ppm
  }
  float rs = _rl * (_vc - vout) / vout;
  if (rs < 0.0f) rs = 0.0f;  // can happen on noise when Vout > Vc
  return rs;
}

void MQSensor::resetCalibration() {
  _calSum = 0.0;
  _calCount = 0;
}

void MQSensor::accumulateCalibration() {
  _calSum += readRs();
  _calCount++;
}

void MQSensor::finishCalibration() {
  if (_calCount == 0) return;
  float rsClean = (float)(_calSum / (double)_calCount);
  _r0 = rsClean / _cleanRatio;
  if (_r0 < 1.0f) _r0 = 1.0f;  // sanity floor
}

float MQSensor::readPpm() {
  float ratio = readRs() / _r0;
  if (ratio <= 0.0f) return 0.0f;
  float ppm = _a * powf(ratio, _b);
  if (ppm < 0.0f || isnan(ppm) || isinf(ppm)) ppm = 0.0f;
  return ppm;
}
