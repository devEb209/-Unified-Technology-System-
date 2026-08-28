// UTS :: core/clock — Simulated time. Drives day/night, processes and schedulers.
// Fully serializable: persistence preserves the timeline (D-3 Temporal).

export class Clock {
  constructor({ tickRate = 20, dayLengthSec = 600, startAtSec = 60 * 7 } = {}) {
    this.tickRate = tickRate;   // sim ticks per simulated second
    this.dayLengthSec = dayLengthSec;
    this.time = startAtSec;     // simulated seconds since epoch
    this.tick = 0;
  }

  advance(dt) {
    this.time += dt;
    this.tick++;
  }

  /** 0..1 within a day (0 = midnight, 0.5 = noon) */
  get timeOfDay() {
    return (this.time % this.dayLengthSec) / this.dayLengthSec;
  }

  /** sun elevation proxy in [-1, 1]: <0 means night */
  get sunElevation() {
    return Math.sin((this.timeOfDay - 0.25) * Math.PI * 2);
  }

  get isNight() {
    return this.sunElevation < 0;
  }

  get dt() {
    return 1 / this.tickRate;
  }

  snapshot() {
    return { tickRate: this.tickRate, dayLengthSec: this.dayLengthSec, time: this.time, tick: this.tick };
  }

  restore(s) {
    this.tickRate = s.tickRate;
    this.dayLengthSec = s.dayLengthSec;
    this.time = s.time;
    this.tick = s.tick;
  }
}
