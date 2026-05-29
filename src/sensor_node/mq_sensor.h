// =============================================================================
//  mq_sensor.h  --  Analog gas-sensor driver for MQ-2 / MQ-7 on the ESP32
// -----------------------------------------------------------------------------
//  Converts a raw ADC reading into a gas concentration in ppm using the
//  sensor's characteristic resistance curve:
//
//      Rs = RL * (Vc - Vout) / Vout            (sensor resistance)
//      ppm = A * (Rs / R0) ^ B                 (log-log datasheet curve)
//
//  R0 (sensor resistance in clean air) is established at boot during the
//  warm-up window: we average Rs in clean air and divide by the datasheet
//  "clean-air ratio".
//
//  HARDWARE NOTE: only ADC1 pins (GPIO32-39) may be used because ADC2 is
//  reserved by the Wi-Fi radio that ESP-NOW depends on.
// =============================================================================
#pragma once
#include <Arduino.h>

class MQSensor {
 public:
  // adcPin        : ESP32 ADC1 GPIO connected to the divided sensor output
  // rlOhms        : load resistor on the sensor module (ohms)
  // vcVolts       : sensor heater/supply voltage (typically 5.0 V)
  // dividerRatio  : Vout / Vadc of the external divider that scales the
  //                 0-5 V sensor output into the 0-3.3 V ADC range
  // cleanAirRatio : Rs/R0 in clean air, from the datasheet
  // curveA,curveB : coefficients of ppm = A*(Rs/R0)^B for the target gas
  MQSensor(uint8_t adcPin, float rlOhms, float vcVolts, float dividerRatio,
           float cleanAirRatio, float curveA, float curveB);

  void  begin();

  // Instantaneous (averaged) measurements.
  float readAdcVolts();   // volts seen at the ADC pin
  float readVoltage();    // reconstructed sensor output voltage (0-5 V)
  float readRs();         // sensor resistance in ohms

  // Clean-air R0 calibration, driven from the warm-up loop.
  void  resetCalibration();
  void  accumulateCalibration();   // call each sample while in clean air
  void  finishCalibration();       // compute and store R0
  bool  calibrated() const { return _calCount > 0; }
  float r0() const { return _r0; }
  void  setR0(float r0) { _r0 = r0; }

  // Gas concentration in ppm (requires a valid R0).
  float readPpm();

 private:
  uint8_t _pin;
  float   _rl;
  float   _vc;
  float   _divider;
  float   _cleanRatio;
  float   _a;
  float   _b;
  float   _r0 = 10000.0f;
  double  _calSum = 0.0;
  uint32_t _calCount = 0;
};
