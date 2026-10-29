import { test } from "node:test";
import assert from "node:assert/strict";
import { afterQuietHours } from "../functions/lib/notification_time.js";
import { resolveLocalMinute } from "../functions/lib/local_time.js";
const quiet = (start = "20:00", end = "08:00") => ({
  enabled: true,
  start,
  end,
});
const instant = (s) => Date.parse(s);
const defer = (s, zone, q = quiet()) =>
  new Date(afterQuietHours(instant(s), zone, q)).toISOString();
test("Quiet hours defer overnight alerts and include start but exclude end", () => {
  assert.equal(
    defer("2026-10-29T12:00:00Z", "Asia/Manila"),
    "2026-10-30T00:00:00.000Z",
  );
  assert.equal(
    defer("2026-10-29T23:59:59Z", "Asia/Manila"),
    "2026-10-30T00:00:00.000Z",
  );
  assert.equal(
    defer("2026-10-30T00:00:00Z", "Asia/Manila"),
    "2026-10-30T00:00:00.000Z",
  );
  assert.equal(
    defer("2026-10-29T10:00:00Z", "Asia/Manila"),
    "2026-10-29T10:00:00.000Z",
  );
});
test("Same-day quiet hours and disabled alerts leave other instants unchanged", () => {
  assert.equal(
    defer("2026-10-29T01:30:00Z", "Asia/Manila", quiet("09:00", "11:00")),
    "2026-10-29T03:00:00.000Z",
  );
  assert.equal(
    defer("2026-10-29T01:30:00Z", "Asia/Manila", {
      ...quiet(),
      enabled: false,
    }),
    "2026-10-29T01:30:00.000Z",
  );
});
test("A repeated quiet end waits through the entire overlap, including the first apparent end", () => {
  for (const value of [
    "2026-11-01T05:15:00Z",
    "2026-11-01T05:45:00Z",
    "2026-11-01T06:15:00Z",
  ]) {
    assert.equal(
      defer(value, "America/New_York", quiet("22:00", "01:30")),
      "2026-11-01T06:30:00.000Z",
    );
  }
  assert.equal(
    defer("2026-11-01T06:30:00Z", "America/New_York", quiet("22:00", "01:30")),
    "2026-11-01T06:30:00.000Z",
  );
  assert.equal(
    new Date(
      resolveLocalMinute("2026-11-01T01:30", "America/New_York").utcMillis,
    ).toISOString(),
    "2026-11-01T05:30:00.000Z",
  );
});
test("Spring gaps delay to the first valid quiet end; collapsed quiet intervals do not expand", () => {
  assert.equal(
    defer("2026-03-08T06:00:00Z", "America/New_York", quiet("22:00", "02:30")),
    "2026-03-08T07:00:00.000Z",
  );
  assert.equal(
    defer("2026-03-08T07:00:00Z", "America/New_York", quiet("02:10", "02:50")),
    "2026-03-08T07:00:00.000Z",
  );
});
test("Half-hour clock overlaps and missing civil days use IANA instants", () => {
  assert.equal(
    defer(
      "2026-04-04T14:50:00Z",
      "Australia/Lord_Howe",
      quiet("20:00", "01:45"),
    ),
    "2026-04-04T15:15:00.000Z",
  );
  assert.equal(
    defer("2011-12-30T10:00:00Z", "Pacific/Apia"),
    "2011-12-30T18:00:00.000Z",
  );
  assert.throws(
    () =>
      afterQuietHours(instant("2026-10-29T12:00:00Z"), "Invalid/Zone", quiet()),
    RangeError,
  );
  assert.throws(
    () =>
      afterQuietHours(
        instant("2026-10-29T12:00:00Z"),
        "Etc/UTC",
        quiet("09:00", "09:00"),
      ),
    RangeError,
  );
});
