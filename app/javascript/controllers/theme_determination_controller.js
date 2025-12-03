import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme-determination"
export default class extends Controller {
  static targets = ['body']
  connect() {
    document.documentElement.removeAttribute("data-theme");

    let cookie_value = this.getCookie('theme');
    console.log(cookie_value)
    if (cookie_value && cookie_value == "dark") {
      document.documentElement.setAttribute("data-theme", "dark");
    }
    else if(cookie_value == undefined) {
      if(!window.matchMedia) {
        return false;
      } else if(window.matchMedia("(prefers-color-scheme: dark)").matches) {
        document.documentElement.setAttribute("data-theme", "dark");
        this.setCookie('theme', 'dark');
      }
    }

  }

 getCookie(name) {
    const value = `; ${document.cookie}`;
    const parts = value.split(`; ${name}=`);
    if (parts.length === 2) return parts.pop().split(';').shift();
  }
  setCookie(name, value, days = 365 * 10) {
    const date = new Date();
    date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
    const expires = "expires=" + date.toUTCString();
    document.cookie = name + "=" + value + ";" + expires + ";path=/;SameSite=Strict";  }
}
