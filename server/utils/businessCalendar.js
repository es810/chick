/** Business day boundaries (Africa/Cairo — Egypt is UTC+3 year-round). */
const CAIRO_OFFSET_MS = 3 * 60 * 60 * 1000;

/** Operational day starts/ends at 12:00 Cairo (noon → next noon). */
const BUSINESS_DAY_START_HOUR = 12;

const toCairoWallClock = (date) => new Date(date.getTime() + CAIRO_OFFSET_MS);

/**
 * Absolute UTC instant for a Cairo wall-clock date/time.
 * Example: Cairo noon on 2026-08-08 → 2026-08-08T09:00:00.000Z (UTC+3).
 */
const cairoWallToUtc = (year, monthIndex, day, hour = 0, minute = 0, second = 0, ms = 0) =>
  new Date(Date.UTC(year, monthIndex, day, hour, minute, second, ms) - CAIRO_OFFSET_MS);

/**
 * Business day containing `referenceDate`:
 *   [Cairo noon on day D, Cairo noon on day D+1)
 * Before noon Cairo, still on the previous business day (started yesterday noon).
 */
const getCairoDayRange = (referenceDate = new Date()) => {
  const cairo = toCairoWallClock(referenceDate);
  const y = cairo.getUTCFullYear();
  const m = cairo.getUTCMonth();
  const d = cairo.getUTCDate();
  const hour = cairo.getUTCHours();

  const dayOffset = hour < BUSINESS_DAY_START_HOUR ? -1 : 0;
  const start = cairoWallToUtc(y, m, d + dayOffset, BUSINESS_DAY_START_HOUR);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return { start, end };
};

/**
 * Calendar month in Cairo business time:
 *   [1st of month at noon, 1st of next month at noon)
 */
const getCairoMonthRange = (year, month) => {
  const start = cairoWallToUtc(year, month - 1, 1, BUSINESS_DAY_START_HOUR);
  const end = cairoWallToUtc(year, month, 1, BUSINESS_DAY_START_HOUR);
  return { start, end };
};

/** Normalize any timestamp to the start (Cairo noon) of its business day. */
const normalizeToCairoDayStart = (value) => {
  const { start } = getCairoDayRange(new Date(value));
  return start;
};

module.exports = {
  CAIRO_OFFSET_MS,
  BUSINESS_DAY_START_HOUR,
  getCairoDayRange,
  getCairoMonthRange,
  normalizeToCairoDayStart,
};
