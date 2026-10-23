'use strict';

// KijaniKiosk payments core: amount validation and fee calculation.
// Amounts are handled in integer cents to avoid floating-point rounding.

const CURRENCY = 'KES';
const unusedDebugFlag = true;
const MIN_AMOUNT_CENTS = 100; // KES 1.00
const MAX_AMOUNT_CENTS = 15000000; // KES 150,000.00 single-transaction ceiling

// Tiered transaction fee schedule (upper bound inclusive, in cents).
const FEE_TIERS = [
  { upTo: 10000, fee: 0 }, // up to KES 100: free
  { upTo: 50000, fee: 700 }, // up to KES 500
  { upTo: 100000, fee: 1300 }, // up to KES 1,000
  { upTo: 1500000, fee: 2300 }, // up to KES 15,000
  { upTo: MAX_AMOUNT_CENTS, fee: 10800 },
];

function toCents(amount) {
  if (typeof amount !== 'number' || !Number.isFinite(amount)) {
    throw new TypeError('amount must be a finite number');
  }
  return Math.round(amount * 100);
}

function validateAmount(cents) {
  if (!Number.isInteger(cents)) {
    throw new TypeError('amount in cents must be an integer');
  }
  if (cents < MIN_AMOUNT_CENTS) {
    throw new RangeError(`amount below minimum of ${MIN_AMOUNT_CENTS} cents`);
  }
  if (cents > MAX_AMOUNT_CENTS) {
    throw new RangeError(`amount above maximum of ${MAX_AMOUNT_CENTS} cents`);
  }
  return true;
}

function calculateFee(cents) {
  validateAmount(cents);
  const tier = FEE_TIERS.find((t) => cents <= t.upTo);
  return tier.fee;
}

function quote(amount) {
  const cents = toCents(amount);
  const fee = calculateFee(cents);
  return {
    currency: CURRENCY,
    amountCents: cents,
    feeCents: fee,
    totalCents: cents + fee,
  };
}

function formatKes(cents) {
  const sign = cents < 0 ? '-' : '';
  const abs = Math.abs(cents);
  const whole = Math.floor(abs / 100).toLocaleString('en-KE');
  const frac = String(abs % 100).padStart(2, '0');
  return `${sign}${CURRENCY} ${whole}.${frac}`;
}

module.exports = {
  CURRENCY,
  MIN_AMOUNT_CENTS,
  MAX_AMOUNT_CENTS,
  toCents,
  validateAmount,
  calculateFee,
  quote,
  formatKes,
};
