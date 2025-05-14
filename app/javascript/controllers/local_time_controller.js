import { Controller } from "@hotwired/stimulus"
import { differenceInDays, signedDifferenceInDays } from "helpers/date_helpers"

export default class extends Controller {
  static targets = [ "time", "date", "datetime", "shortdate", "ago", "indays", "daysago", "agoorweekday", "closingsoonbubble" ]
  static values = { refreshInterval: Number }
  static classes = [ "local-time-value"]

  #timer

  initialize() {
    this.timeFormatter = new Intl.DateTimeFormat(undefined, { timeStyle: "short" })
    this.dateFormatter = new Intl.DateTimeFormat(undefined, { dateStyle: "long" })
    this.shortdateFormatter = new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" })
    this.datetimeFormatter = new Intl.DateTimeFormat(undefined, { timeStyle: "short", dateStyle: "short" })
    this.agoFormatter = new AgoFormatter()
    this.daysagoFormatter = new DaysAgoFormatter()
    this.datewithweekdayFormatter = new Intl.DateTimeFormat(undefined, { weekday: "long", month: "long", day: "numeric" })
    this.datewithweekdayFormatter = new Intl.DateTimeFormat(undefined, { weekday: "long", month: "long", day: "numeric" })
    this.indaysFormatter = new InDaysFormatter()
    this.agoorweekdayFormatter = new DaysAgoOrWeekdayFormatter()
    this.closingsoonbubbleFormatter = new ClosingSoonBubbleFormatter()
  }

  connect() {
    this.#timer = setInterval(() => this.#refreshRelativeTimes(), 30_000)
  }

  disconnect() {
    clearInterval(this.#timer)
  }

  refreshAll() {
    this.constructor.targets.forEach(targetName => {
      this.targets.findAll(targetName).forEach(target => {
        this.#formatTime(this[`${targetName}Formatter`], target)
      })
    })
  }

  refreshTarget(event) {
    const target = event.target;
    const targetName = target.dataset.localTimeTarget
    this.#formatTime(this[`${targetName}Formatter`], target)
  }

  timeTargetConnected(target) {
    this.#formatTime(this.timeFormatter, target)
  }

  dateTargetConnected(target) {
    this.#formatTime(this.dateFormatter, target)
  }

  datetimeTargetConnected(target) {
    this.#formatTime(this.datetimeFormatter, target)
  }

  shortdateTargetConnected(target) {
    this.#formatTime(this.shortdateFormatter, target)
  }

  agoTargetConnected(target) {
    this.#formatTime(this.agoFormatter, target)
  }

  indaysTargetConnected(target) {
    this.#formatTime(this.indaysFormatter, target)
  }

  daysagoTargetConnected(target) {
    this.#formatTime(this.daysagoFormatter, target)
  }

  agoorweekdayTargetConnected(target) {
    this.#formatTime(this.agoorweekdayFormatter, target)
  }

  closingsoonbubbleTargetConnected(target) {
    this.#formatTime(this.closingsoonbubbleFormatter, target)
  }

  #refreshRelativeTimes() {
    this.agoTargets.forEach(target => {
      this.#formatTime(this.agoFormatter, target)
    })
  }

  #formatTime(formatter, target) {
    const dt = new Date(target.getAttribute("datetime"))
    const within = target.getAttribute("within")

    if (within && differenceInDays(new Date(), dt) > within) {
      target.innerHTML = ``
    } else {
      target.innerHTML = formatter.format(dt)
    }
    target.title = this.datetimeFormatter.format(dt)
  }
}

class AgoFormatter {
  format(dt) {
    const now = new Date()
    const seconds = (now - dt) / 1000
    const minutes = seconds / 60
    const hours = minutes / 60
    const days = hours / 24
    const weeks = days / 7
    const months = days / (365 / 12)
    const years = days / 365

    if (years >= 1) return this.#pluralize("year", years)
    if (months >= 1) return this.#pluralize("month", months)
    if (weeks >= 1) return this.#pluralize("week", weeks)
    if (days >= 1) return this.#pluralize("day", days)
    if (hours >= 1) return this.#pluralize("hour", hours)
    if (minutes >= 1) return this.#pluralize("minute", minutes)

    return "Less than a minute ago"
  }

  #pluralize(word, quantity) {
    quantity = Math.floor(quantity)
    const suffix = (quantity === 1) ? "" : "s"
    return `${quantity} ${word}${suffix} ago`
  }
}

class DaysAgoFormatter {
  format(date) {
    const days = differenceInDays(date, new Date())

    if (days <= 0) return styleableValue("today")
    if (days === 1) return styleableValue("yesterday")
    return `${styleableValue(days)} days ago`
  }
}

class DaysAgoOrWeekdayFormatter {
  format(date) {
    const days = differenceInDays(date, new Date())

    if (days <= 1) {
      return new DaysAgoFormatter().format(date)
    } else {
      return new Intl.DateTimeFormat(undefined, { weekday: "long", month: "long", day: "numeric" }).format(date)
    }
  }
}

class InDaysFormatter {
  format(date) {
    const days = differenceInDays(new Date(), date)

    if (days <= 0) return styleableValue("today")
    if (days === 1) return styleableValue("tomorrow")
    return `in ${styleableValue(days)} days`
  }
}

class ClosingSoonBubbleFormatter {
  format(date) {
    const days = signedDifferenceInDays(new Date(), date)
    const top = days < 1 ? "Closes" : "Closes in"
    const value = days < 1 ? styleableValue("!") : styleableValue(days)
    const bottom = days < 1 ? "today" : this.#pluralize("day", days)

    return this.#markup(top, value, bottom)
  }

  #markup(top, value, bottom) {
    return `
<div class="card__bubble">
  <svg viewBox="0 0 200 100">
    <path id="top-half" fill="transparent" d="M 20,100 A 80,80 0 0,1 180,100" />
    <text text-anchor="middle" fill="currentColor">
      <textPath href="#top-half" startOffset="50%" dominant-baseline="middle">${top}</textPath>
    </text>
  </svg>

  <span class="circle-bubble__number">${value}</span>

  <svg viewBox="0 0 200 100">
    <path id="bottom-half" d="M 20,0 A 80,80 0 0,0 180,0" fill="transparent" />
    <text text-anchor="middle" fill="currentColor">
      <textPath href="#bottom-half" startOffset="50%" dominant-baseline="middle">${bottom}</textPath>
    </text>
  </svg>
</div>`
  }

  #pluralize(word, quantity) {
    quantity = Math.floor(quantity)
    const suffix = (quantity === 1) ? "" : "s"
    return `${word}${suffix}`
  }
}

function styleableValue(value) {
  return `<span class="local-time-value">${value}</span>`
}
