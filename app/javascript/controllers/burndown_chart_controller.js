import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { data: Array }

  connect() {
    this.drawChart()
  }

  drawChart() {
    const data = this.dataValue
    if (!data || data.length === 0) return

    const container = this.element
    const width = container.clientWidth - 40
    const height = 350
    const padding = { top: 20, right: 20, bottom: 60, left: 60 }

    // Clear any existing content
    container.innerHTML = ''

    // Create SVG
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.setAttribute("width", width)
    svg.setAttribute("height", height)
    svg.style.backgroundColor = "#fff"
    svg.style.borderRadius = "var(--border-radius)"

    // Calculate scales
    const maxHours = Math.max(
      ...data.map(d => Math.max(d.remaining, d.total, d.available))
    )
    const chartHeight = height - padding.top - padding.bottom
    const chartWidth = width - padding.left - padding.right
    const xScale = chartWidth / (data.length - 1)
    const yScale = chartHeight / maxHours

    // Helper function to create path
    const createPath = (points, color, strokeWidth = 2, dashed = false) => {
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
      const d = points.map((p, i) => 
        `${i === 0 ? 'M' : 'L'} ${p.x},${p.y}`
      ).join(' ')
      
      path.setAttribute("d", d)
      path.setAttribute("fill", "none")
      path.setAttribute("stroke", color)
      path.setAttribute("stroke-width", strokeWidth)
      if (dashed) path.setAttribute("stroke-dasharray", "5,5")
      
      return path
    }

    // Y-axis
    const yAxis = document.createElementNS("http://www.w3.org/2000/svg", "line")
    yAxis.setAttribute("x1", padding.left)
    yAxis.setAttribute("y1", padding.top)
    yAxis.setAttribute("x2", padding.left)
    yAxis.setAttribute("y2", height - padding.bottom)
    yAxis.setAttribute("stroke", "#ccc")
    yAxis.setAttribute("stroke-width", "1")
    svg.appendChild(yAxis)

    // X-axis
    const xAxis = document.createElementNS("http://www.w3.org/2000/svg", "line")
    xAxis.setAttribute("x1", padding.left)
    xAxis.setAttribute("y1", height - padding.bottom)
    xAxis.setAttribute("x2", width - padding.right)
    xAxis.setAttribute("y2", height - padding.bottom)
    xAxis.setAttribute("stroke", "#ccc")
    xAxis.setAttribute("stroke-width", "1")
    svg.appendChild(xAxis)

    // Y-axis labels and grid lines
    const ySteps = 5
    for (let i = 0; i <= ySteps; i++) {
      const value = (maxHours / ySteps) * i
      const y = height - padding.bottom - (value * yScale)

      // Grid line
      const grid = document.createElementNS("http://www.w3.org/2000/svg", "line")
      grid.setAttribute("x1", padding.left)
      grid.setAttribute("y1", y)
      grid.setAttribute("x2", width - padding.right)
      grid.setAttribute("y2", y)
      grid.setAttribute("stroke", "#f0f0f0")
      grid.setAttribute("stroke-width", "1")
      svg.appendChild(grid)

      // Label
      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      label.setAttribute("x", padding.left - 10)
      label.setAttribute("y", y + 5)
      label.setAttribute("text-anchor", "end")
      label.setAttribute("font-size", "12")
      label.setAttribute("fill", "#666")
      label.textContent = Math.round(value) + "h"
      svg.appendChild(label)
    }

    // X-axis labels (dates)
    const dateStep = Math.ceil(data.length / 10)
    data.forEach((d, i) => {
      if (i % dateStep === 0 || i === data.length - 1) {
        const x = padding.left + (i * xScale)
        const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
        label.setAttribute("x", x)
        label.setAttribute("y", height - padding.bottom + 20)
        label.setAttribute("text-anchor", "middle")
        label.setAttribute("font-size", "11")
        label.setAttribute("fill", "#666")
        
        const date = new Date(d.date)
        label.textContent = `${date.getMonth() + 1}/${date.getDate()}`
        svg.appendChild(label)
      }
    })

    // Draw lines
    // 1. Available hours (green dashed line)
    const availablePoints = data.map((d, i) => ({
      x: padding.left + (i * xScale),
      y: height - padding.bottom - (d.available * yScale)
    }))
    svg.appendChild(createPath(availablePoints, "#22c55e", 2, true))

    // 2. Total estimate (blue line)
    const totalPoints = data.map((d, i) => ({
      x: padding.left + (i * xScale),
      y: height - padding.bottom - (d.total * yScale)
    }))
    svg.appendChild(createPath(totalPoints, "#3b82f6", 2))

    // 3. Remaining (red line - main burndown)
    const remainingPoints = data.map((d, i) => ({
      x: padding.left + (i * xScale),
      y: height - padding.bottom - (d.remaining * yScale)
    }))
    svg.appendChild(createPath(remainingPoints, "#ef4444", 3))

    // Add interactive hover points
    this.addHoverPoints(svg, data, remainingPoints, padding, height, yScale)

    // Legend
    const legends = [
      { color: "#ef4444", label: "Remaining" },
      { color: "#3b82f6", label: "Total Estimate" },
      { color: "#22c55e", label: "Available Time", dashed: true }
    ]

    legends.forEach((legend, i) => {
      const x = width - 200 + (i * 120)
      const y = 15

      // Line
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
      line.setAttribute("x1", x)
      line.setAttribute("y1", y)
      line.setAttribute("x2", x + 20)
      line.setAttribute("y2", y)
      line.setAttribute("stroke", legend.color)
      line.setAttribute("stroke-width", "2")
      if (legend.dashed) line.setAttribute("stroke-dasharray", "5,5")
      svg.appendChild(line)

      // Label
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
      text.setAttribute("x", x + 25)
      text.setAttribute("y", y + 4)
      text.setAttribute("font-size", "12")
      text.setAttribute("fill", "#333")
      text.textContent = legend.label
      svg.appendChild(text)
    })

    container.appendChild(svg)
  }

  addHoverPoints(svg, data, points, padding, height, yScale) {
    // Create tooltip element
    const tooltip = document.createElement("div")
    tooltip.style.position = "absolute"
    tooltip.style.display = "none"
    tooltip.style.background = "rgba(0, 0, 0, 0.9)"
    tooltip.style.color = "white"
    tooltip.style.padding = "12px 16px"
    tooltip.style.borderRadius = "8px"
    tooltip.style.fontSize = "13px"
    tooltip.style.lineHeight = "1.6"
    tooltip.style.pointerEvents = "none"
    tooltip.style.zIndex = "1000"
    tooltip.style.boxShadow = "0 4px 12px rgba(0,0,0,0.3)"
    tooltip.style.minWidth = "220px"
    this.element.style.position = "relative"
    this.element.appendChild(tooltip)

    // Helper to safely format numbers
    const formatHours = (value) => {
      const num = parseFloat(value) || 0
      return num.toFixed(1)
    }

    // Add invisible hover areas for each data point
    points.forEach((point, i) => {
      const dayData = data[i]
      const prevDayData = i > 0 ? data[i - 1] : null
      
      // Create hover circle
      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      circle.setAttribute("cx", point.x)
      circle.setAttribute("cy", point.y)
      circle.setAttribute("r", "8")
      circle.setAttribute("fill", "transparent")
      circle.setAttribute("stroke", "transparent")
      circle.style.cursor = "pointer"

      // Hover events
      circle.addEventListener("mouseenter", (e) => {
        // Highlight circle
        circle.setAttribute("fill", "#ef4444")
        circle.setAttribute("stroke", "white")
        circle.setAttribute("stroke-width", "2")

        // Calculate metrics - safely parse numbers
        const date = new Date(dayData.date)
        const dayNumber = i + 1
        const remaining = parseFloat(dayData.remaining) || 0
        const total = parseFloat(dayData.total) || 0
        const available = parseFloat(dayData.available) || 0
        const completed = total - remaining
        
        const prevRemaining = prevDayData ? (parseFloat(prevDayData.remaining) || 0) : remaining
        const completedToday = prevRemaining - remaining
        
        const progressPercent = total > 0 ? Math.round((completed / total) * 100) : 0
        const prevTotal = prevDayData ? (parseFloat(prevDayData.total) || 0) : total
        const prevCompleted = prevTotal - prevRemaining
        const prevProgressPercent = prevTotal > 0 ? Math.round((prevCompleted / prevTotal) * 100) : 0

        // Build tooltip content
        let tooltipHTML = `
          <div style="font-weight: bold; margin-bottom: 8px; border-bottom: 1px solid rgba(255,255,255,0.3); padding-bottom: 6px;">
            ${date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })} 
            <span style="opacity: 0.7;">(Day ${dayNumber})</span>
          </div>
          <div style="margin-bottom: 6px;">
            <span style="color: #ef4444;">●</span> Remaining: <strong>${formatHours(remaining)}h</strong>
          </div>
          <div style="margin-bottom: 6px;">
            <span style="color: #3b82f6;">●</span> Total Est: <strong>${formatHours(total)}h</strong>
          </div>
          <div style="margin-bottom: 6px;">
            <span style="color: #22c55e;">●</span> Available: <strong>${formatHours(available)}h</strong>
          </div>
        `

        if (completedToday > 0.1) {
          tooltipHTML += `
            <div style="margin-top: 8px; padding-top: 6px; border-top: 1px solid rgba(255,255,255,0.2);">
              <div style="color: #22c55e; margin-bottom: 4px;">✓ Completed today: <strong>${formatHours(completedToday)}h</strong></div>
            </div>
          `
        }

        if (prevDayData) {
          tooltipHTML += `
            <div style="margin-top: 8px; padding-top: 6px; border-top: 1px solid rgba(255,255,255,0.2); font-size: 12px; opacity: 0.9;">
              Progress: ${prevProgressPercent}% → <strong>${progressPercent}%</strong>
            </div>
          `
        }

        tooltip.innerHTML = tooltipHTML
        tooltip.style.display = "block"
        
        // Position tooltip
        const rect = this.element.getBoundingClientRect()
        const tooltipRect = tooltip.getBoundingClientRect()
        let left = point.x - tooltipRect.width / 2
        let top = point.y - tooltipRect.height - 15

        // Keep tooltip in bounds
        if (left < 0) left = 10
        if (left + tooltipRect.width > rect.width) left = rect.width - tooltipRect.width - 10
        if (top < 0) top = point.y + 15

        tooltip.style.left = left + "px"
        tooltip.style.top = top + "px"
      })

      circle.addEventListener("mouseleave", () => {
        circle.setAttribute("fill", "transparent")
        circle.setAttribute("stroke", "transparent")
        tooltip.style.display = "none"
      })

      svg.appendChild(circle)
    })
  }
}
