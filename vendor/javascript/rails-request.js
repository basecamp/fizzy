// Patched to use Turbo.fetch. @TODO Upstream this.
class FetchResponse {
  constructor(response) {
    this.response = response;
  }
  get statusCode() {
    return this.response.status;
  }
  get redirected() {
    return this.response.redirected;
  }
  get ok() {
    return this.response.ok;
  }
  get unauthenticated() {
    return this.statusCode === 401;
  }
  get unprocessableEntity() {
    return this.statusCode === 422;
  }
  get authenticationURL() {
    return this.response.headers.get("WWW-Authenticate");
  }
  get contentType() {
    const contentType = this.response.headers.get("Content-Type") || "";
    return contentType.replace(/;.*$/, "");
  }
  get headers() {
    return this.response.headers;
  }
  get html() {
    if (this.contentType.match(/^(application|text)\/(html|xhtml\+xml)$/)) {
      return this.text;
    }
    return Promise.reject(new Error(`Expected an HTML response but got "${this.contentType}" instead`));
  }
  get json() {
    if (this.contentType.match(/^application\/.*json$/)) {
      return this.responseJson || (this.responseJson = this.response.json());
    }
    return Promise.reject(new Error(`Expected a JSON response but got "${this.contentType}" instead`));
  }
  get text() {
    return this.responseText || (this.responseText = this.response.text());
  }
  get isTurboStream() {
    return this.contentType.match(/^text\/vnd\.turbo-stream\.html/);
  }
  get isScript() {
    return this.contentType.match(/\b(?:java|ecma)script\b/);
  }
  async renderTurboStream() {
    if (this.isTurboStream) {
      if (window.Turbo) {
        await window.Turbo.renderStreamMessage(await this.text);
      } else {
        console.warn("You must set `window.Turbo = Turbo` to automatically process Turbo Stream events with request.js");
      }
    } else {
      return Promise.reject(new Error(`Expected a Turbo Stream response but got "${this.contentType}" instead`));
    }
  }
  async activeScript() {
    if (this.isScript) {
      const script = document.createElement("script");
      const metaTag = document.querySelector("meta[name=csp-nonce]");
      if (metaTag) {
        const nonce = metaTag.nonce === "" ? metaTag.content : metaTag.nonce;
        if (nonce) {
          script.setAttribute("nonce", nonce);
        }
      }
      script.innerHTML = await this.text;
      document.body.appendChild(script);
    } else {
      return Promise.reject(new Error(`Expected a Script response but got "${this.contentType}" instead`));
    }
  }
}

class RequestInterceptor {
  static register(interceptor) {
    this.interceptor = interceptor;
  }
  static get() {
    return this.interceptor;
  }
  static reset() {
    this.interceptor = undefined;
  }
}

function getCookie(name) {
  const cookies = document.cookie ? document.cookie.split("; ") : [];
  const prefix = `${encodeURIComponent(name)}=`;
  const cookie = cookies.find((cookie => cookie.startsWith(prefix)));
  if (cookie) {
    const value = cookie.split("=").slice(1).join("=");
    if (value) {
      return decodeURIComponent(value);
    }
  }
}

function compact(object) {
  const result = {};
  for (const key in object) {
    const value = object[key];
    if (value !== undefined) {
      result[key] = value;
    }
  }
  return result;
}

function metaContent(name) {
  const element = document.head.querySelector(`meta[name="${name}"]`);
  return element && element.content;
}

function stringEntriesFromFormData(formData) {
  return [ ...formData ].reduce(((entries, [name, value]) => entries.concat(typeof value === "string" ? [ [ name, value ] ] : [])), []);
}

function mergeEntries(searchParams, entries) {
  for (const [name, value] of entries) {
    if (value instanceof window.File) continue;
    if (searchParams.has(name) && !name.includes("[]")) {
      searchParams.delete(name);
      searchParams.set(name, value);
    } else {
      searchParams.append(name, value);
    }
  }
}

class FetchRequest {
  constructor(method, url, options = {}) {
    this.method = method;
    this.options = options;
    this.originalUrl = url.toString();
  }
  async perform() {
    try {
      const requestInterceptor = RequestInterceptor.get();
      if (requestInterceptor) {
        await requestInterceptor(this);
      }
    } catch (error) {
      console.error(error);
    }
    const fetch = this.responseKind === "turbo-stream" && window.Turbo ? window.Turbo.fetch : window.fetch;
    const response = new FetchResponse(await Turbo.fetch(this.url, this.fetchOptions));
    if (response.unauthenticated && response.authenticationURL) {
      return Promise.reject(window.location.href = response.authenticationURL);
    }
    if (response.isScript) {
      await response.activeScript();
    }
    const responseStatusIsTurboStreamable = response.ok || response.unprocessableEntity;
    if (responseStatusIsTurboStreamable && response.isTurboStream) {
      await response.renderTurboStream();
    }
    return response;
  }
  addHeader(key, value) {
    const headers = this.additionalHeaders;
    headers[key] = value;
    this.options.headers = headers;
  }
  sameHostname() {
    if (!this.originalUrl.startsWith("http:") && !this.originalUrl.startsWith("https:")) {
      return true;
    }
    try {
      return new URL(this.originalUrl).hostname === window.location.hostname;
    } catch (_) {
      return true;
    }
  }
  get fetchOptions() {
    return {
      method: this.method.toUpperCase(),
      headers: this.headers,
      body: this.formattedBody,
      signal: this.signal,
      credentials: this.credentials,
      redirect: this.redirect,
      keepalive: this.keepalive
    };
  }
  get headers() {
    const baseHeaders = {
      "X-Requested-With": "XMLHttpRequest",
      "Content-Type": this.contentType,
      Accept: this.accept
    };
    if (this.sameHostname()) {
      baseHeaders["X-CSRF-Token"] = this.csrfToken;
    }
    return compact(Object.assign(baseHeaders, this.additionalHeaders));
  }
  get csrfToken() {
    return getCookie(metaContent("csrf-param")) || metaContent("csrf-token");
  }
  get contentType() {
    if (this.options.contentType) {
      return this.options.contentType;
    } else if (this.body == null || this.body instanceof window.FormData) {
      return undefined;
    } else if (this.body instanceof window.File) {
      return this.body.type;
    }
    return "application/json";
  }
  get accept() {
    switch (this.responseKind) {
      case "html":
        return "text/html, application/xhtml+xml";

      case "turbo-stream":
        return "text/vnd.turbo-stream.html, text/html, application/xhtml+xml";

      case "json":
        return "application/json, application/vnd.api+json";

      case "script":
        return "text/javascript, application/javascript";

      default:
        return "*/*";
    }
  }
  get body() {
    return this.options.body;
  }
  get query() {
    const originalQuery = (this.originalUrl.split("?")[1] || "").split("#")[0];
    const params = new URLSearchParams(originalQuery);
    let requestQuery = this.options.query;
    if (requestQuery instanceof window.FormData) {
      requestQuery = stringEntriesFromFormData(requestQuery);
    } else if (requestQuery instanceof window.URLSearchParams) {
      requestQuery = requestQuery.entries();
    } else {
      requestQuery = Object.entries(requestQuery || {});
    }
    mergeEntries(params, requestQuery);
    const query = params.toString();
    return query.length > 0 ? `?${query}` : "";
  }
  get url() {
    return this.originalUrl.split("?")[0].split("#")[0] + this.query;
  }
  get responseKind() {
    return this.options.responseKind || "html";
  }
  get signal() {
    return this.options.signal;
  }
  get redirect() {
    return this.options.redirect || "follow";
  }
  get credentials() {
    return this.options.credentials || "same-origin";
  }
  get keepalive() {
    return this.options.keepalive || false;
  }
  get additionalHeaders() {
    return this.options.headers || {};
  }
  get formattedBody() {
    const bodyIsAString = Object.prototype.toString.call(this.body) === "[object String]";
    const contentTypeIsJson = this.headers["Content-Type"] === "application/json";
    if (contentTypeIsJson && !bodyIsAString) {
      return JSON.stringify(this.body);
    }
    return this.body;
  }
}

async function get(url, options) {
  const request = new FetchRequest("get", url, options);
  return request.perform();
}

async function post(url, options) {
  const request = new FetchRequest("post", url, options);
  return request.perform();
}

async function put(url, options) {
  const request = new FetchRequest("put", url, options);
  return request.perform();
}

async function patch(url, options) {
  const request = new FetchRequest("patch", url, options);
  return request.perform();
}

async function destroy(url, options) {
  const request = new FetchRequest("delete", url, options);
  return request.perform();
}

export { FetchRequest, FetchResponse, RequestInterceptor, destroy, get, patch, post, put };
