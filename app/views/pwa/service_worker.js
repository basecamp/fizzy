self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return

  if (event.request.destination === 'document') {
    event.respondWith(
      fetch(event.request, { cache: 'no-cache' })
        .catch(() => caches.match(event.request))
    )
  }
})

self.addEventListener("push", async (event) => {
  const data = await event.data.json()
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

  const url = new URL(event.notification.data.path, self.location.origin).href
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

self.addEventListener("pushsubscriptionchange", (event) => {
  event.waitUntil(resubscribe(event))
})

async function resubscribe(event) {
  const oldSubscription = event.oldSubscription
  const applicationServerKey = oldSubscription?.options?.applicationServerKey

  if (!applicationServerKey) return

  const newSubscription = await self.registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: applicationServerKey
  })

  await syncSubscriptionWithServer(newSubscription)
}

async function syncSubscriptionWithServer(subscription) {
  const { endpoint, keys: { p256dh, auth } } = subscription.toJSON()
  const clients = await self.clients.matchAll({ type: "window" })
  const client = clients[0]

  if (client) {
    client.postMessage({
      type: "pushsubscriptionchange",
      subscription: { endpoint, p256dh_key: p256dh, auth_key: auth }
    })
  }
}
