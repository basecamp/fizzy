import { Turbo } from "@hotwired/turbo-rails"

Turbo.offline.start("/service-worker.js", { 
  scope: "/", 
  native: true 
})
