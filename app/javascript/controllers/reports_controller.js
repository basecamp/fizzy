import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tableBody", "timelineContainer", "tableView", "timelineView",
    "tableTab", "timelineTab",
    "assigneeChip", "assigneeChipValue", "assigneeChipX", "assigneePopover",
    "dateChip", "dateChipValue", "dateChipX", "datePopover",
    "clearFilters",
    "kpiScope", "kpiCompleted", "kpiCompletedSub", "kpiInFlight", "kpiCycle",
    "tableFoot", "exportBtn", "exportBtnLabel"
  ]

  static values = {
    cards: Array,
    events: Array,
    assignees: Array
  }

  connect() {
    this.selectedAssignees = []
    this.datePreset = "all"
    this.dateFrom = null
    this.dateTo = null
    this.sortCol = "completedAt"
    this.sortDir = "desc"
    this.activeView = "table"
    this.render()
  }

  // ── Tab switching ──────────────────────────────────────────────

  switchToTable() {
    this.activeView = "table"
    this.tableTabTarget.classList.add("is-active")
    this.timelineTabTarget.classList.remove("is-active")
    this.tableViewTarget.hidden = false
    this.timelineViewTarget.hidden = true
  }

  switchToTimeline() {
    this.activeView = "timeline"
    this.timelineTabTarget.classList.add("is-active")
    this.tableTabTarget.classList.remove("is-active")
    this.tableViewTarget.hidden = true
    this.timelineViewTarget.hidden = false
    this.renderTimeline(this.filteredEvents())
  }

  // ── Assignee filter ────────────────────────────────────────────

  toggleAssigneePopover() {
    const popover = this.assigneePopoverTarget
    if (popover.hidden) {
      popover.hidden = false
      this.closeDatePopover()
    } else {
      popover.hidden = true
    }
  }

  toggleAssignee(event) {
    const name = event.currentTarget.dataset.name
    if (this.selectedAssignees.includes(name)) {
      this.selectedAssignees = this.selectedAssignees.filter(n => n !== name)
    } else {
      this.selectedAssignees = [...this.selectedAssignees, name]
    }
    event.currentTarget.classList.toggle("is-active", this.selectedAssignees.includes(name))
    const check = event.currentTarget.querySelector(".rp-check")
    if (check) check.hidden = !this.selectedAssignees.includes(name)
    this.applyFilters()
  }

  clearAssignees() {
    this.selectedAssignees = []
    this.assigneePopoverTarget.querySelectorAll(".rp-popover__row").forEach(r => {
      r.classList.remove("is-active")
      const check = r.querySelector(".rp-check")
      if (check) check.hidden = true
    })
    this.closeAssigneePopover()
    this.applyFilters()
  }

  closeAssigneePopover() {
    if (this.hasAssigneePopoverTarget) this.assigneePopoverTarget.hidden = true
  }

  // ── Date filter ────────────────────────────────────────────────

  toggleDatePopover() {
    const popover = this.datePopoverTarget
    if (popover.hidden) {
      popover.hidden = false
      this.closeAssigneePopover()
    } else {
      popover.hidden = true
    }
  }

  setPreset(event) {
    this.datePreset = event.currentTarget.dataset.preset
    this.dateFrom = null
    this.dateTo = null
    this.datePopoverTarget.querySelectorAll(".rp-popover__row").forEach(r => {
      r.classList.toggle("is-active", r.dataset.preset === this.datePreset)
      const check = r.querySelector(".rp-check")
      if (check) check.hidden = r.dataset.preset !== this.datePreset
    })
    this.closeDatePopover()
    this.applyFilters()
  }

  setCustomFrom(event) {
    this.datePreset = "custom"
    this.dateFrom = event.target.value
    this.applyFilters()
  }

  setCustomTo(event) {
    this.datePreset = "custom"
    this.dateTo = event.target.value
    this.applyFilters()
  }

  clearDate() {
    this.datePreset = "all"
    this.dateFrom = null
    this.dateTo = null
    this.closeDatePopover()
    this.applyFilters()
  }

  closeDatePopover() {
    if (this.hasDatePopoverTarget) this.datePopoverTarget.hidden = true
  }

  // ── Click outside ──────────────────────────────────────────────

  closePopovers(event) {
    if (this.hasAssigneePopoverTarget && !this.element.querySelector("[data-reports-target='assigneeChip']").contains(event.target)) {
      this.closeAssigneePopover()
    }
    if (this.hasDatePopoverTarget && !this.element.querySelector("[data-reports-target='dateChip']").contains(event.target)) {
      this.closeDatePopover()
    }
  }

  // ── Sorting ────────────────────────────────────────────────────

  sort(event) {
    const col = event.currentTarget.dataset.col
    if (this.sortCol === col) {
      this.sortDir = this.sortDir === "asc" ? "desc" : "asc"
    } else {
      this.sortCol = col
      this.sortDir = "desc"
    }
    this.element.querySelectorAll("th[data-col]").forEach(th => {
      th.classList.toggle("is-sorted", th.dataset.col === this.sortCol)
      const indicator = th.querySelector(".rp-th-sort")
      if (indicator) {
        if (th.dataset.col === this.sortCol) {
          indicator.textContent = this.sortDir === "asc" ? "▲" : "▼"
        } else {
          indicator.textContent = "↕"
        }
      }
    })
    this.renderTable(this.filteredCards())
  }

  // ── Clear all ──────────────────────────────────────────────────

  clearAll() {
    this.selectedAssignees = []
    this.datePreset = "all"
    this.dateFrom = null
    this.dateTo = null
    this.assigneePopoverTarget.querySelectorAll(".rp-popover__row").forEach(r => {
      r.classList.remove("is-active")
      const check = r.querySelector(".rp-check")
      if (check) check.hidden = true
    })
    this.datePopoverTarget.querySelectorAll(".rp-popover__row[data-preset]").forEach(r => {
      r.classList.toggle("is-active", r.dataset.preset === "all")
      const check = r.querySelector(".rp-check")
      if (check) check.hidden = r.dataset.preset !== "all"
    })
    this.applyFilters()
  }

  // ── Export ─────────────────────────────────────────────────────

  async exportXlsx() {
    const XLSX = (await import("xlsx")).default || (await import("xlsx"))
    const cards = this.filteredCards()
    const events = this.filteredEvents()

    const cardRows = cards.map(c => ({
      "ID":           c.number,
      "Card":         c.title,
      "Completed On": c.closedAt ? this.fmtDate(new Date(c.closedAt)) : "",
      "Created On":   this.fmtDate(new Date(c.createdAt)),
      "Created by":   c.createdBy,
      "Story Points": c.points || "",
      "Assignees":    c.assignees.map(a => a.name).join(", "),
      "Status":       c.status,
      "Current tab":  c.currentTab,
      "Tags":         c.tags.join(", ")
    }))

    const activityRows = events.map(e => ({
      "Timestamp": this.fmtDate(new Date(e.at)),
      "Actor":     e.actor,
      "Event":     e.kind,
      "Destination": e.destination || "",
      "Working time spent": this.fmtWorkingTime(e.workingMinutes),
      "Card #":    e.cardNumber,
      "Card":      e.cardTitle
    }))

    const closed = cards.filter(c => c.closedAt)
    const inFlight = cards.filter(c => !c.closedAt)
    const summaryRows = [
      ["Dayzy — Reports export"],
      ["Generated", this.fmtDate(new Date())],
      [],
      ["Filters"],
      ["Assignees", this.selectedAssignees.length ? this.selectedAssignees.join(", ") : "All"],
      ["Date range", this.datePresetLabel()],
      [],
      ["Totals"],
      ["Cards in scope", cards.length],
      ["Completed", closed.length],
      ["In flight", inFlight.length],
      ["Activity events", events.length]
    ]

    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(summaryRows), "Summary")
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(cardRows), "Cards")
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(activityRows), "Activity")

    const stamp = new Date().toISOString().slice(0, 16).replace(/[:T]/g, "-")
    XLSX.writeFile(wb, `dayzy-reports-${stamp}.xlsx`)

    this.exportBtnLabelTarget.textContent = "Exported"
    this.exportBtnTarget.classList.add("is-flash")
    setTimeout(() => {
      this.exportBtnLabelTarget.textContent = "Export"
      this.exportBtnTarget.classList.remove("is-flash")
    }, 1400)
  }

  // ── Filtering logic ────────────────────────────────────────────

  filteredCards() {
    let cards = this.cardsValue

    if (this.selectedAssignees.length) {
      cards = cards.filter(c => c.assignees.some(a => this.selectedAssignees.includes(a.name)))
    }

    if (this.datePreset !== "all") {
      const cutoff = this.dateCutoff()
      const to = this.dateTo ? new Date(this.dateTo + "T23:59:59") : null
      cards = cards.filter(c => {
        const ref = c.closedAt ? new Date(c.closedAt) : new Date(c.createdAt)
        if (cutoff && ref < cutoff) return false
        if (to && ref > to) return false
        return true
      })
    }

    return this.sortCards(cards)
  }

  filteredEvents() {
    let events = this.eventsValue

    if (this.selectedAssignees.length) {
      events = events.filter(e =>
        this.selectedAssignees.includes(e.actor) ||
        (e.cardAssignees || []).some(a => this.selectedAssignees.includes(a))
      )
    }

    if (this.datePreset !== "all") {
      const cutoff = this.dateCutoff()
      const to = this.dateTo ? new Date(this.dateTo + "T23:59:59") : null
      events = events.filter(e => {
        const ref = new Date(e.at)
        if (cutoff && ref < cutoff) return false
        if (to && ref > to) return false
        return true
      })
    }

    return events
  }

  sortCards(cards) {
    const sorters = {
      completedAt: c => c.closedAt ? new Date(c.closedAt).getTime() : -Infinity,
      createdAt:   c => new Date(c.createdAt).getTime(),
      title:       c => c.title.toLowerCase(),
      createdBy:   c => c.createdBy,
      points:      c => c.points || 0,
      assignees:   c => c.assignees[0]?.name || "",
      status:      c => c.status,
      currentTab:  c => c.currentTab
    }
    const fn = sorters[this.sortCol] || sorters.createdAt
    const sorted = [...cards].sort((a, b) => {
      const av = fn(a), bv = fn(b)
      return av < bv ? -1 : av > bv ? 1 : 0
    })
    return this.sortDir === "desc" ? sorted.reverse() : sorted
  }

  dateCutoff() {
    const days = { "7": 7, "14": 14, "30": 30, "90": 90, "sprint": 14 }[this.datePreset]
    if (days) return new Date(Date.now() - days * 86400 * 1000)
    if (this.datePreset === "custom" && this.dateFrom) return new Date(this.dateFrom)
    return null
  }

  datePresetLabel() {
    const labels = {
      all: "All time", "7": "Last 7 days", "14": "Last 14 days",
      "30": "Last 30 days", "90": "Last 90 days", sprint: "This sprint"
    }
    if (this.datePreset === "custom") {
      return `${this.dateFrom || "—"} → ${this.dateTo || "—"}`
    }
    return labels[this.datePreset] || "All time"
  }

  // ── Rendering ──────────────────────────────────────────────────

  applyFilters() {
    const cards = this.filteredCards()
    const events = this.filteredEvents()
    this.updateChips()
    this.updateKpis(cards)
    this.renderTable(cards)
    if (this.activeView === "timeline") this.renderTimeline(events)
    this.updateClearLink(cards, events)
  }

  render() {
    this.applyFilters()
  }

  updateChips() {
    const hasAssignees = this.selectedAssignees.length > 0
    this.assigneeChipTarget.classList.toggle("rp-chip--active", hasAssignees)
    this.assigneeChipValueTarget.textContent = hasAssignees
      ? (this.selectedAssignees.length === 1 ? this.selectedAssignees[0] : `${this.selectedAssignees.length} assignees`)
      : "Any assignee"
    if (this.hasAssigneeChipXTarget) this.assigneeChipXTarget.hidden = !hasAssignees

    const hasDate = this.datePreset !== "all"
    this.dateChipTarget.classList.toggle("rp-chip--active", hasDate)
    this.dateChipValueTarget.textContent = this.datePresetLabel()
    if (this.hasDateChipXTarget) this.dateChipXTarget.hidden = !hasDate
  }

  updateClearLink(cards, events) {
    const active = this.selectedAssignees.length > 0 || this.datePreset !== "all"
    if (this.hasClearFiltersTarget) this.clearFiltersTarget.hidden = !active
  }

  updateKpis(cards) {
    const closed = cards.filter(c => c.closedAt)
    const inFlight = cards.length - closed.length
    const cycleHours = closed
      .filter(c => c.closedAt && c.createdAt)
      .map(c => (new Date(c.closedAt) - new Date(c.createdAt)) / 3600000)
    const avg = cycleHours.length ? cycleHours.reduce((a, b) => a + b, 0) / cycleHours.length : null

    this.kpiScopeTarget.textContent = cards.length
    this.kpiCompletedTarget.textContent = closed.length
    this.kpiCompletedSubTarget.textContent = cards.length
      ? `${Math.round(closed.length / cards.length * 100)}% of scope`
      : "—"
    this.kpiInFlightTarget.textContent = inFlight
    this.kpiCycleTarget.textContent = avg === null ? "—"
      : avg < 24 ? `${avg.toFixed(1)}h` : `${(avg / 24).toFixed(1)}d`
  }

  renderTable(cards) {
    if (!this.hasTableBodyTarget) return

    if (cards.length === 0) {
      this.tableBodyTarget.innerHTML = `<tr><td colspan="9" class="rp-empty">No cards match these filters.</td></tr>`
      this.tableFootTarget.innerHTML = `<span>0 cards</span><span class="rp-muted">No results</span>`
      return
    }

    this.tableBodyTarget.innerHTML = cards.map(c => `
      <tr>
        <td class="rp-td-mono">${c.closedAt ? this.fmtDate(new Date(c.closedAt)) : '<span class="rp-muted">—</span>'}</td>
        <td class="rp-td-mono">${this.fmtDate(new Date(c.createdAt))}</td>
        <td class="rp-td-card">
          <div class="rp-td-card__id">#${c.number}</div>
          <div class="rp-td-card__title"><a href="${c.url}" style="color:inherit;text-decoration:none">${this.esc(c.title)}</a></div>
        </td>
        <td>${this.esc(c.createdBy)}</td>
        <td>${c.points ? `<span class="rp-sp-tag">${c.points}</span>` : '<span class="rp-muted">—</span>'}</td>
        <td>
          <div class="rp-assignee-cell">
            ${c.assignees.map(a => this.avatarHtml(a)).join("")}
            <span class="rp-assignee-cell__name">${c.assignees.map(a => this.esc(a.name)).join(", ") || '<span class="rp-muted">—</span>'}</span>
          </div>
        </td>
        <td>${this.statusPill(c.status)}</td>
        <td>${this.currentTabPill(c)}</td>
        <td>${c.tags.map(t => `<span class="rp-tag-pill">${this.esc(t)}</span>`).join(" ") || '<span class="rp-muted">—</span>'}</td>
      </tr>
    `).join("")

    const colLabel = { completedAt: "completed on", createdAt: "created on", title: "title", createdBy: "created by", points: "story points", assignees: "assignee", status: "status", currentTab: "current tab" }
    this.tableFootTarget.innerHTML = `
      <span>${cards.length} card${cards.length === 1 ? "" : "s"}</span>
      <span class="rp-muted">Sorted by ${colLabel[this.sortCol] || this.sortCol} · ${this.sortDir === "asc" ? "ascending" : "descending"}</span>
    `
  }

  renderTimeline(events) {
    if (!this.hasTimelineContainerTarget) return

    if (events.length === 0) {
      this.timelineContainerTarget.innerHTML = `<div class="rp-empty">No activity matches these filters.</div>`
      return
    }

    const groups = new Map()
    for (const ev of events) {
      const key = new Date(ev.at).toDateString()
      if (!groups.has(key)) groups.set(key, { date: new Date(ev.at), events: [] })
      groups.get(key).events.push(ev)
    }

    const now = new Date()
    const today = now.toDateString()
    const yesterday = new Date(now.getTime() - 86400000).toDateString()

    this.timelineContainerTarget.innerHTML = [...groups.entries()].map(([key, { date, events: evs }]) => {
      const label = key === today ? "Today"
        : key === yesterday ? "Yesterday"
        : date.toLocaleDateString(undefined, { weekday: "long", day: "2-digit", month: "short", year: "numeric" })

      return `
        <div class="rp-tl-day">
          <div class="rp-tl-day__head">
            <span class="rp-tl-day__label">${label}</span>
            <span class="rp-tl-day__rule"></span>
            <span class="rp-tl-day__count">${evs.length} event${evs.length === 1 ? "" : "s"}</span>
          </div>
          <div class="rp-tl-day__body">
            ${evs.map(ev => this.activityRowHtml(ev)).join("")}
          </div>
        </div>
      `
    }).join("")
  }

  activityRowHtml(ev) {
    const iconCls = { created: "rp-act-icon--created", moved: "rp-act-icon--created", completed: "rp-act-icon--completed" }[ev.kind] || "rp-act-icon--commented"
    const glyph = { created: "+", moved: "→", completed: "✓" }[ev.kind] || "·"
    const verb = { created: "created", moved: "moved", completed: "moved" }[ev.kind] || ev.kind
    const destination = ev.destination ? ` to <strong>${this.esc(ev.destination)}</strong>` : ""

    const closedAt = ev.cardClosedAt ? new Date(ev.cardClosedAt) : null
    const createdAt = ev.cardCreatedAt ? new Date(ev.cardCreatedAt) : null
    const cycle = (ev.kind === "completed" && closedAt && createdAt)
      ? ` · cycle ${((closedAt - createdAt) / 3600000).toFixed(1)}h`
      : ""

    return `
      <div class="rp-act-row">
        <span class="rp-act-icon ${iconCls}">${glyph}</span>
        <div class="rp-act-body">
          <div class="rp-act-line">
            <span class="rp-act-actor">${this.esc(ev.actor)}</span>
            <span class="rp-act-verb">${verb}</span>
            <span class="rp-act-card-id">#${ev.cardNumber}</span>
            <span>${this.esc(ev.cardTitle)}</span>
            ${destination}
          </div>
          <div class="rp-act-meta">${this.fmtDate(new Date(ev.at))}${cycle ? `<span class="rp-act-cycle">${cycle}</span>` : ""}</div>
        </div>
        <div class="rp-act-hours">
          <span class="rp-act-hours__label">Working time spent</span>
          <strong>${this.fmtWorkingTime(ev.workingMinutes)}</strong>
        </div>
      </div>
    `
  }

  // ── Helpers ────────────────────────────────────────────────────

  fmtDate(d) {
    return d.toLocaleString(undefined, { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" })
  }

  fmtWorkingTime(minutes) {
    if (minutes === null || minutes === undefined) return "—"

    const hours = Math.floor(minutes / 60)
    const remainingMinutes = minutes % 60
    if (hours === 0) return `${remainingMinutes}m`
    if (remainingMinutes === 0) return `${hours}h`
    return `${hours}h ${remainingMinutes}m`
  }

  esc(str) {
    return String(str).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;")
  }

  avatarHtml(a) {
    const hue = a.hue || 32
    const initial = a.name ? a.name[0].toUpperCase() : "?"
    return `<span class="rp-avatar" style="width:22px;height:22px;font-size:9px;background:radial-gradient(circle at 30% 25%,hsl(${hue} 70% 78%) 0%,hsl(${hue} 55% 55%) 55%,hsl(${hue} 60% 40%) 100%)" title="${this.esc(a.name)}">${initial}</span>`
  }

  statusPill(status) {
    const cls = { "Closed": "rp-pill--closed", "Open": "rp-pill--open", "Postponed": "rp-pill--postponed" }[status] || "rp-pill--open"
    return `<span class="rp-pill ${cls}">${status}</span>`
  }

  currentTabPill(card) {
    const cls = card.currentTab === "Done" ? "rp-pill--closed"
      : card.currentTab === "Not Now" ? "rp-pill--postponed"
      : "rp-pill--open"
    return `<span class="rp-pill ${cls}">${this.esc(card.currentTab)}</span>`
  }
}
