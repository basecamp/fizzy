import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "notification", "hiddenNotifications" ]
  static classes = [ "grouped" ]

  connect() {
    this.group()
  }

  group() {
    const notificationsByCardId = this.#groupNotificationsByCardId()

    for (const cardId in notificationsByCardId) {
      const notifications = notificationsByCardId[cardId]
      if (notifications.length > 1) {
        this.#renderGroup(notifications)
      }
    }

    this.grouped = true
  }

  notificationTargetConnected(notification) {
    if (this.grouped && notification.parentElement !== this.hiddenNotificationsTarget) {
      this.#groupNotification(notification)
    }
  }

  #groupNotificationsByCardId() {
    const notificationsByCardId = {}

    this.notificationTargets.forEach(notification => {
      const cardId = notification.dataset.cardId
      notificationsByCardId[cardId] ||= []
      notificationsByCardId[cardId].push(notification)
    })

    return notificationsByCardId
  }

  #groupNotification(notification) {
    const groupedNotifications = this.#groupedNotificationsFor(notification)

    if (groupedNotifications.length > 1) {
      this.#renderGroup(groupedNotifications)
    }
  }

  #groupedNotificationsFor(notification) {
    const cardId = notification.dataset.cardId
    return this.notificationTargets
      .filter(notification => notification.dataset.cardId === cardId)
  }

  #renderGroup(groupedNotifications) {
    groupedNotifications.sort((notification_1, notification_2) => parseInt(notification_1.dataset.timestamp) - parseInt(notification_2.dataset.timestamp))

    this.#showAsGrouped(groupedNotifications[0], groupedNotifications.length)
    groupedNotifications.slice(1).forEach(notification => this.#hideInGroup(notification))
  }

  #showAsGrouped(notification, size) {
    notification.classList.add(this.groupedClass)
    this.#showGroupedNotification(notification)
    this.#setGroupCount(notification, size)
  }

  #hideInGroup(notification) {
    this.#hideGroupedNotification(notification)
    this.#setGroupCount(notification, "")
  }

  // We use a hidden container instead of hiding the notifications directly so that the CSS that sort the
  // tray element indexes doesn't get messed up with the child positions changing.
  #showGroupedNotification(notification) {
    if (notification.parentElement === this.hiddenNotificationsTarget) {
      this.hiddenNotificationsTarget.parentElement.insertBefore(notification, this.hiddenNotificationsTarget)
    }
  }

  #hideGroupedNotification(notification) {
    this.hiddenNotificationsTarget.appendChild(notification)
  }

  #setGroupCount(notification, count) {
    notification.querySelector("[data-group-count]").textContent = count
  }
}
