import { FetchRequest } from "@rails/request.js"

// Persist a form in the background without rendering a response. Auto-save uses this to
// save drafts as you type; it asks for JSON so the server acknowledges the save through
// CardsController#update's `format.json` branch instead of a Turbo Stream. That matters
// because a drafted card's Turbo Stream response morphs the whole card container — which
// *is* the form you're editing — and would clobber keystrokes typed while the save is in
// flight. JSON also clears the original 406: the request no longer defaults to
// `Accept: text/html`, a format #update doesn't serve.
export async function submitForm(form) {
  const request = new FetchRequest(form.method, form.action, {
    body: new FormData(form),
    responseKind: "json"
  })

  return await request.perform()
}
