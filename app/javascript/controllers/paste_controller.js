import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  pasteFiles(event) {
    const editor = event.target.closest("house-md")
    if (!editor) return
    
    const files = event.clipboardData?.files
    if (!files?.length) return

    event.preventDefault()

    for (const file of files) {
      const uploadEvent = new CustomEvent("house-md:before-upload", { 
        cards: true, 
        detail: { file },
        cancelable: true 
      })
      
      if (editor.dispatchEvent(uploadEvent)) {
        const upload = document.createElement("house-md-upload")
        upload.file = file
        upload.uploadsURL = editor.dataset.uploadsUrl
        editor.appendChild(upload)
      }
    }
  }
}