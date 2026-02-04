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
}
