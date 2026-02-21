self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return

  if (event.request.destination === 'document') {
    event.respondWith(
      fetch(event.request, { cache: 'no-cache' })
        .catch(() => caches.match(event.request))
    )
  }
})

self.addEventListener("push", (event) => {
  const data = event.data.json()
  event.waitUntil(Promise.all([ showNotification(data), updateBadgeCount(data.options) ]))
})

async function showNotification({ title, options }) {
  return self.registration.showNotification(title, options)
}

async function updateBadgeCount({ data: { badge } }) {
  return self.navigator.setAppBadge?.(badge || 0)
}

self.addEventListener("notificationclick", (event) => {
  event.notification.close()

  const url = new URL(event.notification.data.url, self.location.origin).href
  event.waitUntil(openURL(url))
})

async function openURL(url) {
  const clients = await self.clients.matchAll({ type: "window" })
  const focused = clients.find((client) => client.focused)

  if (focused) {
    await focused.navigate(url)
  } else {
    await self.clients.openWindow(url)
  }
}
