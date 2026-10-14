// Lexxy highlights a code block only when Prism has a grammar for its language.
import "lexxy"
import "prismjs/components/prism-mermaid"

// Lexxy's code language picker has a fixed list of languages, so Mermaid is added to it here.
// Editors without rich text have no picker, and an editor restored from Turbo's cache reuses
// the picker it had.
document.addEventListener("lexxy:initialize", ({ target }) => {
  const picker = target.querySelector("lexxy-code-language-picker select")

  if (picker && !picker.querySelector("option[value=mermaid]")) {
    const followingOption = [ ...picker.options ].find(option => option.value !== "plain" && option.text.localeCompare("Mermaid") > 0)
    picker.add(new Option("Mermaid", "mermaid"), followingOption)
  }
})
