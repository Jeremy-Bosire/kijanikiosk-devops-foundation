'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const payments = require('../src/index.js');

test('toCents converts shillings to integer cents', () => {
  assert.equal(payments.toCents(12.34), 1234);
  assert.equal(payments.toCents(0.1 + 0.2), 30);
});

test('toCents rejects non-numeric input', () => {
  assert.throws(() => payments.toCents('100'), TypeError);
  assert.throws(() => payments.toCents(NaN), TypeError);
});

test('validateAmount enforces minimum and maximum', () => {
  assert.throws(() => payments.validateAmount(99), RangeError);
  assert.ok(payments.validateAmount(100));
  assert.ok(payments.validateAmount(payments.MAX_AMOUNT_CENTS));
  assert.throws(() => payments.validateAmount(payments.MAX_AMOUNT_CENTS + 1), RangeError);
});

test('calculateFee applies the correct tier at each boundary', () => {
  assert.equal(payments.calculateFee(10000), 0);
  assert.equal(payments.calculateFee(10001), 700);
  assert.equal(payments.calculateFee(100000), 1300);
  assert.equal(payments.calculateFee(1500001), 10800);
});

test('quote returns amount, fee and total in cents', () => {
  assert.deepEqual(payments.quote(250), {
    currency: 'KES',
    amountCents: 25000,
    feeCents: 700,
    totalCents: 25700,
  });
});

test('formatKes renders human-readable shillings', () => {
  assert.equal(payments.formatKes(123456), 'KES 1,234.56');
  assert.equal(payments.formatKes(5), 'KES 0.05');
});
