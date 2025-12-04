export default class Cookie {
  static DEFAULT_EXPIRATION = 20 * 365 * 24 * 60 * 60 * 1000

  static find(name) {
    const value = document.cookie
      .split("; ")
      .find(row => row.startsWith(`${name}=`))
      ?.split("=")[1]

    if (!value) return null

    try {
      const data = JSON.parse(decodeURIComponent(value))
      return new Cookie(name, data)
    } catch {
      return new Cookie(name, { value: decodeURIComponent(value) })
    }
  }

  constructor(name, data = {}, options = {}) {
    this.name = name
    this.data = data
    this.options = options
  }

  get(key) {
    return this.data[key]
  }

  set(key, value) {
    this.data[key] = value
    this.save()
  }

  increment(key, amount = 1) {
    const currentValue = this.data[key] || 0

    try {
      this.set(key, currentValue + amount)
    } catch {
      this.set(key, amount)
    }
  }

  save() {
    const value = encodeURIComponent(JSON.stringify(this.data))
    const defaultExpires = new Date(Date.now() + this.constructor.DEFAULT_EXPIRATION)
    const expires = `; expires=${(this.options.expires || defaultExpires).toUTCString()}`
    const path = `; path=${this.options.path || "/"}`
    const sameSite = this.options.sameSite ? `; SameSite=${this.options.sameSite}` : "; SameSite=Lax"

    document.cookie = `${this.name}=${value}${expires}${path}${sameSite}`
  }

  delete() {
    document.cookie = `${this.name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/`
  }
}
