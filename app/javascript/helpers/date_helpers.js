import { getMetaContent } from "helpers/meta_helpers"

export function differenceInDays(fromDate, toDate) {
  return Math.round(Math.abs((beginningOfDay(toDate) - beginningOfDay(fromDate)) / (1000 * 60 * 60 * 24)))
}

export function signedDifferenceInDays(fromDate, toDate) {
  return Math.round((beginningOfDay(toDate) - beginningOfDay(fromDate)) / (1000 * 60 * 60 * 24))
}

export function beginningOfDay(date) {
  const { year, month, day } = datePartsInTimezone(date)
  return new Date(Date.UTC(year, month - 1, day))
}

export function secondsToDate(seconds) {
  return new Date(seconds * 1000)
}

// Snap a timestamp to midnight using the timezone the server rendered with (the
// `timezone` meta tag), so client day boundaries match the server's instead of
// following the browser's resolved timezone, which can differ in a PWA.
function datePartsInTimezone(date) {
  return dateFormatter().formatToParts(date).reduce((parts, { type, value }) => {
    if (type !== "literal") parts[type] = parseInt(value, 10)
    return parts
  }, {})
}

let dateFormatterCache
let dateFormatterTimezone

function dateFormatter() {
  const timezone = getMetaContent("timezone")

  if (!dateFormatterCache || dateFormatterTimezone !== timezone) {
    dateFormatterTimezone = timezone
    dateFormatterCache = buildDateFormatter(timezone)
  }

  return dateFormatterCache
}

function buildDateFormatter(timezone) {
  const options = { year: "numeric", month: "2-digit", day: "2-digit" }

  try {
    return new Intl.DateTimeFormat("en-US", { ...options, timeZone: timezone })
  } catch {
    return new Intl.DateTimeFormat("en-US", options)
  }
}
